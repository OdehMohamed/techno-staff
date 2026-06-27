// handover-triggers.js — onHandoverCreated / onHandoverUpdated
// CF notifies admins on creation; updates payment statuses + cashOnHand on verification.

const {onDocumentCreated, onDocumentUpdated} = require("firebase-functions/firestore");
const admin = require("firebase-admin");
const {createInAppNotification, getFcmToken, getFcmTokensBatch, sendFCMNotification} = require("../shared");
const {formatAgorot} = require("./payment-triggers");

// ─── i18n strings for handover notifications ──────────────────────────────────

const i18nHandover = {
  en: {
    handover_pending_title: "Handover Pending Verification",
    handover_pending_body: "{collector} is handing over {amount} — please verify",
    handover_verified_title: "Handover Verified ✅",
    handover_verified_body: "Your handover of {amount} has been verified by {admin}",
    handover_discrepancy_title: "Handover Discrepancy ⚠️",
    handover_discrepancy_body: "Discrepancy in your handover — contact admin ({amount} difference)",
  },
  ar: {
    handover_pending_title: "تسليم نقدي بانتظار التحقق",
    handover_pending_body: "{collector} يريد تسليم {amount} — يرجى التحقق",
    handover_verified_title: "تم التحقق من التسليم ✅",
    handover_verified_body: "تم التحقق من تسليمك بقيمة {amount} بواسطة {admin}",
    handover_discrepancy_title: "تعارض في التسليم ⚠️",
    handover_discrepancy_body: "يوجد تعارض في تسليمك — تواصل مع المشرف (فارق {amount})",
  },
};

function localizeHandover(key, args, languageCode) {
  const lang = languageCode === "ar" ? i18nHandover.ar : i18nHandover.en;
  const template = lang[key] || i18nHandover.en[key] || "";
  return template.replace(/\{(\w+)\}/g, (_, k) => (args && args[k] != null ? args[k] : ""));
}

// ─── onHandoverCreated ────────────────────────────────────────────────────────

exports.onHandoverCreated = onDocumentCreated("handovers/{handoverId}", async (event) => {
  const handoverId = event.params.handoverId;
  const handover = event.data.data();
  const db = admin.firestore();

  // Write collection_log
  try {
    await db.collection("collection_logs").add({
      entityType: "handover",
      entityId: handoverId,
      action: "handover.initiated",
      actorId: handover.collectorId,
      actorName: handover.collectorName,
      timestamp: admin.firestore.FieldValue.serverTimestamp(),
      collectorId: handover.collectorId,
      amount: handover.claimedAmount,
    });
  } catch (err) {
    console.error("onHandoverCreated: collection_log failed:", err);
  }

  // Notify all admins (FCM + in-app)
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
      const title = localizeHandover("handover_pending_title", {}, langCode);
      const body = localizeHandover("handover_pending_body", {
        collector: handover.collectorName,
        amount: formatAgorot(handover.claimedAmount),
      }, langCode);

      const token = tokenMap[adminId];
      const fcmPromise = token ?
        sendFCMNotification({
          token,
          notification: {title, body},
          data: {handoverId, type: "handover_pending"},
        }) :
        Promise.resolve();

      return Promise.all([
        fcmPromise,
        createInAppNotification({
          userId: adminId,
          type: "handover_pending",
          data: {
            handoverId,
            collectorId: handover.collectorId,
            collectorName: handover.collectorName,
            amount: handover.claimedAmount,
          },
        }),
      ]);
    }));
  } catch (err) {
    console.error("onHandoverCreated: admin notification failed:", err);
  }
});

// ─── onHandoverUpdated ────────────────────────────────────────────────────────

exports.onHandoverUpdated = onDocumentUpdated("handovers/{handoverId}", async (event) => {
  const before = event.data.before.data();
  const after = event.data.after.data();

  // Only handle status transitions to verified or discrepancy
  if (before.status === after.status) return;
  if (after.status !== "verified" && after.status !== "discrepancy") return;

  const handoverId = event.params.handoverId;
  const db = admin.firestore();

  // Settled amount: verified = claimedAmount, discrepancy = actualAmount (what admin received)
  const settledAmount = after.status === "verified" ?
    after.claimedAmount :
    (after.actualAmount || 0);

  // Batch-update all included payments to 'verified' and attach handoverId,
  // then decrement collector cashOnHand atomically
  try {
    const batch = db.batch();

    for (const paymentId of after.paymentIds) {
      const payRef = db.collection("payments").doc(paymentId);
      batch.update(payRef, {status: "verified", handoverId});
    }

    const collectorRef = db.collection("users").doc(after.collectorId);
    batch.update(collectorRef, {
      cashOnHand: admin.firestore.FieldValue.increment(-settledAmount),
    });

    await batch.commit();
  } catch (err) {
    console.error("onHandoverUpdated: batch update failed:", err);
    return;
  }

  // Write collection_log
  try {
    const action = after.status === "verified" ?
      "handover.verified" :
      "handover.discrepancy_noted";

    await db.collection("collection_logs").add({
      entityType: "handover",
      entityId: handoverId,
      action,
      actorId: after.receivedBy || "",
      actorName: after.receivedByName || "",
      timestamp: admin.firestore.FieldValue.serverTimestamp(),
      collectorId: after.collectorId,
      amount: settledAmount,
      notes: after.discrepancyNotes || null,
      after: after.status === "discrepancy" ? {
        discrepancyAmount: after.discrepancyAmount,
        actualAmount: after.actualAmount,
        claimedAmount: after.claimedAmount,
      } : null,
    });
  } catch (err) {
    console.error("onHandoverUpdated: collection_log failed:", err);
  }

  // Notify the collector (FCM + in-app)
  try {
    const collectorSnap = await db.collection("users").doc(after.collectorId).get();
    const collectorData = collectorSnap.exists ? collectorSnap.data() : {};
    const langCode = collectorData.languageCode || "en";
    const token = await getFcmToken(db, after.collectorId);

    let title; let body;
    if (after.status === "verified") {
      title = localizeHandover("handover_verified_title", {}, langCode);
      body = localizeHandover("handover_verified_body", {
        amount: formatAgorot(settledAmount),
        admin: after.receivedByName || "",
      }, langCode);
    } else {
      title = localizeHandover("handover_discrepancy_title", {}, langCode);
      body = localizeHandover("handover_discrepancy_body", {
        amount: formatAgorot(Math.abs(after.discrepancyAmount || 0)),
      }, langCode);
    }

    if (token) {
      await sendFCMNotification({
        token,
        notification: {title, body},
        data: {handoverId, type: `handover_${after.status}`},
      });
    }

    await createInAppNotification({
      userId: after.collectorId,
      type: `handover_${after.status}`,
      data: {
        handoverId,
        status: after.status,
        settledAmount,
        discrepancyAmount: after.discrepancyAmount || null,
        adminName: after.receivedByName || null,
      },
    });
  } catch (err) {
    console.error("onHandoverUpdated: collector notification failed:", err);
  }
});
