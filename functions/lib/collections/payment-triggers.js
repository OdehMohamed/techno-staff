// payment-triggers.js — onPaymentCreated / onPaymentCancelled
// All financial writes are atomic (Firestore transaction).
// Balance math is NEVER done on the client — this CF is the sole writer.

const {onDocumentCreated, onDocumentUpdated} = require("firebase-functions/firestore");
const admin = require("firebase-admin");
const {createInAppNotification, getFcmTokensBatch, sendFCMNotification} = require("../shared");
const {applyPaymentToInstallments} = require("./installment-triggers");

// ─── i18n strings for payment push notifications ──────────────────────────────

const i18nPayment = {
  en: {
    payment_recorded_title: "Payment Received",
    payment_recorded_body: "{collector} collected {amount} from {customer}",
  },
  ar: {
    payment_recorded_title: "تم تسجيل الدفع",
    payment_recorded_body: "حصّل {collector} مبلغ {amount} من {customer}",
  },
};

function localizePayment(key, args, langCode) {
  const lang = langCode === "ar" ? i18nPayment.ar : i18nPayment.en;
  const template = lang[key] || i18nPayment.en[key] || "";
  return template.replace(/\{(\w+)\}/g, (_, k) => (args && args[k] != null ? args[k] : ""));
}

// ─── Pure helpers (exported for unit testing) ─────────────────────────────────

// Recompute debt status from current financial state. dueDate is a Firestore Timestamp or null.
function recalculateDebtStatus(paidAmount, remainingBalance, dueDate) {
  if (remainingBalance === 0) return "settled";
  const now = new Date();
  const isOverdue = dueDate != null && dueDate.toDate() < now;
  if (paidAmount > 0) return isOverdue ? "overdue" : "partial";
  return isOverdue ? "overdue" : "active";
}

/**
 * Format receipt number from parts.
 * @param {string} prefix e.g. "RCPT"
 * @param {number} year
 * @param {number} number
 * @return {string} e.g. "RCPT-2026-00042"
 */
function formatReceiptNumber(prefix, year, number) {
  return `${prefix}-${year}-${String(number).padStart(5, "0")}`;
}

/**
 * Current calendar year in Asia/Jerusalem.
 * @return {number}
 */
function currentYearJerusalem() {
  return parseInt(
      new Intl.DateTimeFormat("en-CA", {
        timeZone: "Asia/Jerusalem",
        year: "numeric",
      }).format(new Date()),
      10,
  );
}

/**
 * Format agorot as display string for notification messages.
 * @param {number} agorot
 * @return {string}
 */
function formatAgorot(agorot) {
  return `₪${(agorot / 100).toFixed(2)}`;
}

// Returns {valid, reason} — reason is null when valid, a string key when invalid.
function validatePaymentAgainstDebt(paymentAmount, remainingBalance, debtStatus) {
  const terminalStatuses = ["settled", "cancelled", "written_off"];
  if (terminalStatuses.includes(debtStatus)) {
    return {valid: false, reason: "debt_terminal"};
  }
  if (paymentAmount > remainingBalance) {
    return {valid: false, reason: "overpayment"};
  }
  return {valid: true, reason: null};
}

// ─── onPaymentCreated ─────────────────────────────────────────────────────────

exports.onPaymentCreated = onDocumentCreated("payments/{paymentId}", async (event) => {
  const paymentId = event.params.paymentId;
  const payment = event.data.data();

  // Idempotency: CF already ran if receiptNumber is populated
  if (payment.receiptNumber && payment.receiptNumber !== "") return;

  const db = admin.firestore();
  let receiptNumber = "";
  let paymentData;
  let installmentPlanId = null; // captured inside tx for post-tx FIFO allocation

  try {
    await db.runTransaction(async (tx) => {
      // Read all docs before any writes (Firestore transaction requirement)
      const paymentRef = db.collection("payments").doc(paymentId);
      const paymentSnap = await tx.get(paymentRef);
      paymentData = paymentSnap.data();

      // Idempotency check inside transaction
      if (!paymentData || (paymentData.receiptNumber && paymentData.receiptNumber !== "")) return;
      if (paymentData.isCancelled) return;

      const debtRef = db.collection("debts").doc(paymentData.debtId);
      const debtSnap = await tx.get(debtRef);
      if (!debtSnap.exists) throw new Error(`Debt ${paymentData.debtId} not found`);
      const debt = debtSnap.data();
      installmentPlanId = debt.installmentPlanId || null;

      const counterRef = db.collection("config").doc("counters");
      const counterSnap = await tx.get(counterRef);

      const collectorRef = db.collection("users").doc(paymentData.collectorId);
      const customerRef = db.collection("customers").doc(paymentData.customerId);

      // Validate payment
      const validation = validatePaymentAgainstDebt(
          paymentData.amount,
          debt.remainingBalance,
          debt.status,
      );
      if (!validation.valid) {
        tx.update(paymentRef, {status: "invalid", receiptNumber: "INVALID"});
        return;
      }

      // Build receipt number
      const counters = counterSnap.exists ? counterSnap.data() : {};
      let receipts = counters.receipts || {year: 0, lastNumber: 0, prefix: "RCPT"};
      const currentYear = currentYearJerusalem();
      if (receipts.year !== currentYear) {
        receipts = {year: currentYear, lastNumber: 0, prefix: receipts.prefix || "RCPT"};
      }
      receipts.lastNumber += 1;
      receiptNumber = formatReceiptNumber(receipts.prefix, currentYear, receipts.lastNumber);

      // Compute updated debt state
      const newPaidAmount = debt.paidAmount + paymentData.amount;
      const newRemainingBalance = debt.remainingBalance - paymentData.amount;
      const newStatus = recalculateDebtStatus(newPaidAmount, newRemainingBalance, debt.dueDate || null);

      // Writes (must follow all reads)
      tx.set(counterRef, {receipts}, {merge: true});
      tx.update(paymentRef, {receiptNumber});
      tx.update(debtRef, {
        paidAmount: newPaidAmount,
        remainingBalance: newRemainingBalance,
        status: newStatus,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
      tx.update(collectorRef, {
        cashOnHand: admin.firestore.FieldValue.increment(paymentData.amount),
      });
      tx.update(customerRef, {
        lastPaymentAt: paymentData.collectedAt,
        totalOutstandingBalance: admin.firestore.FieldValue.increment(-paymentData.amount),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    });
  } catch (err) {
    console.error("onPaymentCreated transaction failed:", err);
    return;
  }

  // Abort best-effort steps if transaction marked payment invalid
  if (!receiptNumber || receiptNumber === "INVALID") return;

  // Mark any open PTPs as 'kept' if payment arrived on or before promisedDate
  try {
    const visitSnap = await db.collection("visits")
        .where("debtId", "==", paymentData.debtId)
        .where("promiseToPay.status", "==", "pending")
        .get();
    const ptpBatch = db.batch();
    let ptpUpdated = false;
    for (const doc of visitSnap.docs) {
      const ptp = doc.data().promiseToPay;
      const collectedAt = payment.collectedAt ?
          payment.collectedAt.toDate() :
          new Date();
      if (ptp && collectedAt <= ptp.promisedDate.toDate()) {
        ptpBatch.update(doc.ref, {"promiseToPay.status": "kept"});
        ptpBatch.set(db.collection("collection_logs").doc(), {
          entityType: "visit",
          entityId: doc.id,
          action: "ptp.kept",
          actorId: "system",
          actorName: "system",
          timestamp: admin.firestore.FieldValue.serverTimestamp(),
          customerId: paymentData.customerId || null,
          debtId: paymentData.debtId,
          collectorId: paymentData.collectorId || null,
          amount: ptp.amount || null,
        });
        ptpUpdated = true;
      }
    }
    if (ptpUpdated) await ptpBatch.commit();
  } catch (err) {
    console.error("onPaymentCreated: PTP kept marking failed:", err);
  }

  // FIFO installment allocation (best-effort; debt balance already updated)
  if (installmentPlanId && paymentData) {
    try {
      await applyPaymentToInstallments(
          db,
          installmentPlanId,
          paymentId,
          paymentData.amount,
          paymentData.debtId,
      );
    } catch (err) {
      console.error("onPaymentCreated: installment allocation failed:", err);
    }
  }

  // Write collection_log
  try {
    await db.collection("collection_logs").add({
      entityType: "payment",
      entityId: paymentId,
      action: "payment.recorded",
      actorId: payment.recordedById,
      actorName: payment.recordedByName,
      timestamp: admin.firestore.FieldValue.serverTimestamp(),
      customerId: payment.customerId,
      debtId: payment.debtId,
      collectorId: payment.collectorId,
      amount: payment.amount,
      receiptNumber,
    });
  } catch (err) {
    console.error("onPaymentCreated: collection_log failed:", err);
  }

  // Notify all admins: FCM push + in-app notification
  try {
    const adminSnap = await db.collection("users")
        .where("role", "==", "admin")
        .where("isActive", "==", true)
        .get();

    const adminIds = adminSnap.docs.map((d) => d.id);
    const adminDocs = adminSnap.docs.map((d) => d.data());
    const tokenMap = await getFcmTokensBatch(db, adminIds);

    await Promise.all(adminIds.map((adminId, idx) => {
      const langCode = adminDocs[idx].languageCode || "en";
      const title = localizePayment("payment_recorded_title", {}, langCode);
      const body = localizePayment("payment_recorded_body", {
        collector: payment.collectorName,
        amount: formatAgorot(payment.amount),
        customer: payment.customerName,
      }, langCode);

      const token = tokenMap[adminId];
      const fcmPromise = token ?
        sendFCMNotification({
          token,
          notification: {title, body},
          data: {paymentId, type: "payment_recorded"},
        }) :
        Promise.resolve();

      return Promise.all([
        fcmPromise,
        createInAppNotification({
          userId: adminId,
          type: "payment_recorded",
          data: {
            paymentId,
            collectorName: payment.collectorName,
            customerName: payment.customerName,
            amount: payment.amount,
            amountFormatted: formatAgorot(payment.amount),
            receiptNumber,
            debtId: payment.debtId,
          },
        }),
      ]);
    }));
  } catch (err) {
    console.error("onPaymentCreated: admin notification failed:", err);
  }
});

// ─── onPaymentCancelled ───────────────────────────────────────────────────────

exports.onPaymentCancelled = onDocumentUpdated("payments/{paymentId}", async (event) => {
  const before = event.data.before.data();
  const after = event.data.after.data();

  // Only handle isCancelled false → true
  if (before.isCancelled || !after.isCancelled) return;

  const paymentId = event.params.paymentId;
  const db = admin.firestore();

  // Block cancellation if payment belongs to any handover.
  // handoverId is stamped at handover creation so this covers pending_verification
  // handovers as well as verified ones, preventing cashOnHand double-decrement.
  if (after.handoverId) {
    try {
      const handoverSnap = await db.collection("handovers").doc(after.handoverId).get();
      if (handoverSnap.exists) {
        const hStatus = handoverSnap.data().status;
        const revertStatus = hStatus === "pending_verification" ? "pending_handover" : "verified";
        await db.collection("payments").doc(paymentId).update({
          isCancelled: false,
          cancellationReason: null,
          cancelledBy: null,
          cancelledAt: null,
          status: revertStatus,
        });
        console.warn(`Payment ${paymentId} cancellation blocked: in ${hStatus} handover ${after.handoverId}`);
        return;
      }
    } catch (err) {
      console.error("onPaymentCancelled: handover check failed:", err);
    }
  }

  // Reverse balances in transaction
  try {
    await db.runTransaction(async (tx) => {
      const debtRef = db.collection("debts").doc(after.debtId);
      const debtSnap = await tx.get(debtRef);
      if (!debtSnap.exists) return;
      const debt = debtSnap.data();

      const collectorRef = db.collection("users").doc(after.collectorId);
      const customerRef = db.collection("customers").doc(after.customerId);

      const newPaidAmount = Math.max(0, debt.paidAmount - after.amount);
      const newRemainingBalance = debt.remainingBalance + after.amount;
      const newStatus = recalculateDebtStatus(newPaidAmount, newRemainingBalance, debt.dueDate || null);

      tx.update(debtRef, {
        paidAmount: newPaidAmount,
        remainingBalance: newRemainingBalance,
        status: newStatus,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
      tx.update(collectorRef, {
        cashOnHand: admin.firestore.FieldValue.increment(-after.amount),
      });
      tx.update(customerRef, {
        totalOutstandingBalance: admin.firestore.FieldValue.increment(after.amount),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    });
  } catch (err) {
    console.error("onPaymentCancelled transaction failed:", err);
    return;
  }

  // Write collection_log
  try {
    await db.collection("collection_logs").add({
      entityType: "payment",
      entityId: paymentId,
      action: "payment.cancelled",
      actorId: after.cancelledBy || "",
      actorName: "",
      timestamp: admin.firestore.FieldValue.serverTimestamp(),
      customerId: after.customerId,
      debtId: after.debtId,
      collectorId: after.collectorId,
      amount: after.amount,
      notes: after.cancellationReason || null,
    });
  } catch (err) {
    console.error("onPaymentCancelled: collection_log failed:", err);
  }
});

// ─── Exports ──────────────────────────────────────────────────────────────────

module.exports = {
  ...exports,
  // Pure helpers exported for unit testing
  recalculateDebtStatus,
  formatReceiptNumber,
  currentYearJerusalem,
  formatAgorot,
  validatePaymentAgainstDebt,
};
