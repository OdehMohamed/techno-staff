// settlement-triggers.js — Collector settlement request lifecycle
//
// onSettlementRequested (debt trigger):
//   hasPendingSettlementRequest: false→true  → notify all active admins (Issue 4A)
//   hasPendingSettlementRequest: true→false + rejected + not settled → notify collector (Issue 4C)
//
// approveCollectorSettlementRequest (callable):
//   Atomically: settles debt, increments collector cashOnHand, creates pending_handover
//   payment, updates customer totalOutstandingBalance, sets _customerBalanceSynced=true
//   so onDebtStatusChanged skips the customer balance update. (Issues 2, 3, 4B)

const {onDocumentUpdated} = require("firebase-functions/firestore");
const {onCall, HttpsError} = require("firebase-functions/https");
const admin = require("firebase-admin");
const {createInAppNotification, getFcmToken, getFcmTokensBatch, sendFCMNotification} = require("../shared");
const {formatAgorot} = require("./payment-triggers");

// ─── i18n ─────────────────────────────────────────────────────────────────────

const i18nSettlement = {
  en: {
    settlement_requested_title: "Settlement Request",
    settlement_requested_body: "{collector} requested settlement of {amount} for {customer}",
    settlement_approved_title: "Settlement Approved",
    settlement_approved_body: "Your settlement request for {customer} was approved: {amount}",
    settlement_rejected_title: "Settlement Rejected",
    settlement_rejected_body: "Your settlement request for {customer} was rejected",
  },
  ar: {
    settlement_requested_title: "طلب تسوية",
    settlement_requested_body: "{collector} طلب تسوية بمبلغ {amount} لـ{customer}",
    settlement_approved_title: "تمت الموافقة على التسوية",
    settlement_approved_body: "تمت الموافقة على طلب تسويتك لـ{customer}: {amount}",
    settlement_rejected_title: "تم رفض التسوية",
    settlement_rejected_body: "تم رفض طلب تسويتك لـ{customer}",
  },
};

function localizeSettlement(key, args, languageCode) {
  const lang = languageCode === "ar" ? i18nSettlement.ar : i18nSettlement.en;
  const template = lang[key] || i18nSettlement.en[key] || "";
  return template.replace(/\{(\w+)\}/g, (_, k) => (args && args[k] != null ? args[k] : ""));
}

// ─── onSettlementRequested ────────────────────────────────────────────────────

exports.onSettlementRequested = onDocumentUpdated("debts/{debtId}", async (event) => {
  const before = event.data.before.data();
  const after = event.data.after.data();
  const debtId = event.params.debtId;
  const db = admin.firestore();

  // ── Case A: new request submitted → notify all active admins ────────────────
  if (!before.hasPendingSettlementRequest && after.hasPendingSettlementRequest) {
    const req = after.settlementRequest || {};
    const collectorName = req.requestedByName || "";
    const amountAgorot = req.requestedAmount || 0;
    const amountFormatted = amountAgorot ? formatAgorot(amountAgorot) : "";
    const customerName = after.customerName || "";

    try {
      const adminSnap = await db.collection("users")
          .where("role", "==", "admin")
          .where("isActive", "==", true)
          .get();

      const adminIds = adminSnap.docs.map((d) => d.id);
      const adminDocs = adminSnap.docs.map((d) => d.data());
      const tokenMap = await getFcmTokensBatch(db, adminIds);

      await Promise.all(adminIds.map((adminId, idx) => {
        const langCode = (adminDocs[idx] && adminDocs[idx].languageCode) || "en";
        const title = localizeSettlement("settlement_requested_title", {}, langCode);
        const body = localizeSettlement("settlement_requested_body", {
          collector: collectorName,
          amount: amountFormatted,
          customer: customerName,
        }, langCode);

        const token = tokenMap[adminId];
        const fcmPromise = token ?
          sendFCMNotification({
            token,
            notification: {title, body},
            data: {
              type: "settlement_requested",
              debtId,
              customerId: after.customerId || "",
              click_action: "FLUTTER_NOTIFICATION_CLICK",
            },
            android: {
              priority: "high",
              notification: {channelId: "task_notifications"},
            },
          }) :
          Promise.resolve();

        return Promise.all([
          fcmPromise,
          createInAppNotification({
            userId: adminId,
            type: "settlement_requested",
            data: {
              debtId,
              customerId: after.customerId || "",
              collectorName,
              customerName,
              requestedAmount: amountAgorot || null,
              amountFormatted,
            },
          }),
        ]);
      }));
    } catch (err) {
      console.error("onSettlementRequested: admin notification failed:", err);
    }
    return;
  }

  // ── Case C: request cleared → if rejected (not settled), notify collector ───
  if (
    before.hasPendingSettlementRequest &&
    !after.hasPendingSettlementRequest &&
    after.settlementRequest &&
    after.settlementRequest.status === "rejected" &&
    after.status !== "settled"
  ) {
    const collectorId = after.assignedCollectorId;
    if (!collectorId) return;

    const customerName = after.customerName || "";

    try {
      const [collectorSnap, token] = await Promise.all([
        db.collection("users").doc(collectorId).get(),
        getFcmToken(db, collectorId),
      ]);
      const collectorData = (collectorSnap.exists && collectorSnap.data()) || {};
      const langCode = collectorData.languageCode || "en";
      const title = localizeSettlement("settlement_rejected_title", {}, langCode);
      const body = localizeSettlement("settlement_rejected_body", {customer: customerName}, langCode);

      if (token) {
        await sendFCMNotification({
          token,
          notification: {title, body},
          data: {
            type: "settlement_rejected",
            debtId,
            customerId: after.customerId || "",
            click_action: "FLUTTER_NOTIFICATION_CLICK",
          },
          android: {
            priority: "high",
            notification: {channelId: "task_notifications"},
          },
        });
      }

      await createInAppNotification({
        userId: collectorId,
        type: "settlement_rejected",
        data: {
          debtId,
          customerId: after.customerId || "",
          customerName,
          rejectionReason: (after.settlementRequest && after.settlementRequest.rejectionReason) || null,
        },
      });
    } catch (err) {
      console.error("onSettlementRequested: rejection notification failed:", err);
    }
  }
});

// ─── approveCollectorSettlementRequest (callable) ────────────────────────────
//
// Atomically:
//   1. Validates admin role and debt preconditions
//   2. Settles the debt (status=settled, remainingBalance=0, settlement sub-doc)
//   3. Creates a pending_handover payment for the settled amount
//      (receiptNumber=SETTLEMENT bypasses onPaymentCreated idempotency check)
//   4. Increments collector cashOnHand (mirrors what onPaymentCreated normally does)
//   5. Decrements customer totalOutstandingBalance by the full prior remainingBalance
//   6. Sets _customerBalanceSynced=true so onDebtStatusChanged skips the customer update
//
// Post-transaction: writes collection_log, notifies collector.

exports.approveCollectorSettlementRequest = onCall(async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "User must be logged in");
  }

  const {debtId, settledAmount, collectorId, collectorName, customerId, customerName, adminName} = request.data;

  if (!debtId || typeof settledAmount !== "number" || settledAmount <= 0) {
    throw new HttpsError("invalid-argument", "Invalid debtId or settledAmount");
  }
  if (!collectorId || !customerId) {
    throw new HttpsError("invalid-argument", "Missing collectorId or customerId");
  }

  const db = admin.firestore();

  // Verify caller is admin
  const callerSnap = await db.collection("users").doc(request.auth.uid).get();
  if (!callerSnap.exists || callerSnap.data().role !== "admin") {
    throw new HttpsError("permission-denied", "Admins only");
  }
  const callerName = adminName || callerSnap.data().name || "";

  let originalBalance = 0;

  // Generate the payment ref outside the transaction (just creates a local ID)
  const paymentRef = db.collection("payments").doc();

  await db.runTransaction(async (tx) => {
    const debtRef = db.collection("debts").doc(debtId);
    const collectorRef = db.collection("users").doc(collectorId);
    const customerRef = db.collection("customers").doc(customerId);

    const [debtSnap, customerSnap] = await Promise.all([
      tx.get(debtRef),
      tx.get(customerRef),
    ]);

    if (!debtSnap.exists) {
      throw new HttpsError("not-found", "Debt not found");
    }

    const debt = debtSnap.data();

    if (!debt.hasPendingSettlementRequest) {
      throw new HttpsError("failed-precondition", "No pending settlement request");
    }

    const terminalStatuses = ["settled", "cancelled", "written_off"];
    if (terminalStatuses.includes(debt.status)) {
      throw new HttpsError("failed-precondition", "Debt is already terminal");
    }

    if (settledAmount > debt.remainingBalance) {
      throw new HttpsError("invalid-argument", "settlement_exceeds_balance");
    }

    originalBalance = debt.remainingBalance;
    const forgivenAmount = originalBalance - settledAmount;

    // 1. Settle the debt
    tx.update(debtRef, {
      "status": "settled",
      "remainingBalance": 0,
      "settlementAmount": settledAmount,
      "settlementNotes": "collector_requested",
      "settlement": {
        originalBalance,
        settledAmount,
        forgivenAmount,
        reason: "collector_requested",
        authorizedBy: request.auth.uid,
        authorizedByName: callerName,
        at: admin.firestore.FieldValue.serverTimestamp(),
      },
      "hasPendingSettlementRequest": false,
      "settlementRequest.status": "approved",
      "settlementRequest.reviewedBy": request.auth.uid,
      "settlementRequest.reviewedByName": callerName,
      "settlementRequest.reviewedAt": admin.firestore.FieldValue.serverTimestamp(),
      "_customerBalanceSynced": true,
      "updatedAt": admin.firestore.FieldValue.serverTimestamp(),
    });

    // 2. Create a pending_handover payment for the settled amount.
    //    receiptNumber: 'SETTLEMENT' causes onPaymentCreated to exit early (idempotency guard).
    //    cashOnHand and customer balance are handled here instead.
    tx.set(paymentRef, {
      debtId,
      customerId,
      customerName: customerName || debt.customerName || "",
      collectorId,
      collectorName: collectorName || debt.assignedCollectorName || "",
      recordedById: request.auth.uid,
      recordedByName: callerName,
      amount: settledAmount,
      paymentMethod: "cash",
      collectedAt: admin.firestore.FieldValue.serverTimestamp(),
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      receiptNumber: "SETTLEMENT",
      status: "pending_handover",
      notes: "settlement_approved",
      isCancelled: false,
      isCorrection: false,
      isAdminPayment: false,
      isSettlementPayment: true,
    });

    // 3. Increment collector cashOnHand (mirrors what onPaymentCreated normally does)
    tx.update(collectorRef, {
      cashOnHand: admin.firestore.FieldValue.increment(settledAmount),
    });

    // 4. Decrement customer totalOutstandingBalance by full original remaining balance
    const currentBalance = (customerSnap.exists && customerSnap.data() &&
        customerSnap.data().totalOutstandingBalance) || 0;
    const newBalance = Math.max(0, currentBalance - originalBalance);
    tx.update(customerRef, {
      totalOutstandingBalance: newBalance,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });
  });

  // Write collection_log
  try {
    await db.collection("collection_logs").add({
      entityType: "debt",
      entityId: debtId,
      action: "debt.settled",
      actorId: request.auth.uid,
      actorName: callerName,
      timestamp: admin.firestore.FieldValue.serverTimestamp(),
      customerId: customerId || null,
      debtId,
      collectorId: collectorId || null,
      amount: settledAmount,
      notes: "collector_requested",
    });
  } catch (err) {
    console.error("approveCollectorSettlementRequest: collection_log failed:", err);
  }

  // Notify collector (Issue 4B)
  try {
    const [collectorSnap, token] = await Promise.all([
      db.collection("users").doc(collectorId).get(),
      getFcmToken(db, collectorId),
    ]);
    const collectorData = (collectorSnap.exists && collectorSnap.data()) || {};
    const langCode = collectorData.languageCode || "en";
    const title = localizeSettlement("settlement_approved_title", {}, langCode);
    const body = localizeSettlement("settlement_approved_body", {
      customer: customerName || "",
      amount: formatAgorot(settledAmount),
    }, langCode);

    if (token) {
      await sendFCMNotification({
        token,
        notification: {title, body},
        data: {
          type: "settlement_approved",
          debtId,
          customerId: customerId || "",
          click_action: "FLUTTER_NOTIFICATION_CLICK",
        },
        android: {
          priority: "high",
          notification: {channelId: "task_notifications"},
        },
      });
    }

    await createInAppNotification({
      userId: collectorId,
      type: "settlement_approved",
      data: {
        debtId,
        customerId: customerId || "",
        customerName: customerName || "",
        approvedAmount: settledAmount,
        amountFormatted: formatAgorot(settledAmount),
        adminName: callerName,
      },
    });
  } catch (err) {
    console.error("approveCollectorSettlementRequest: collector notification failed:", err);
  }

  return {success: true};
});
