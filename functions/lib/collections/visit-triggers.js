// visit-triggers.js — onVisitCreated
// Updates customer.lastContactAt and writes collection_log entries.
// Visits are immutable after creation (Firestore rule: allow update: if false).

const {onDocumentCreated} = require("firebase-functions/firestore");
const admin = require("firebase-admin");

exports.onVisitCreated = onDocumentCreated("visits/{visitId}", async (event) => {
  const visitId = event.params.visitId;
  const visit = event.data.data();
  const db = admin.firestore();

  const batch = db.batch();

  // Update customer.lastContactAt
  if (visit.customerId) {
    const customerRef = db.collection("customers").doc(visit.customerId);
    batch.update(customerRef, {
      lastContactAt: visit.visitedAt,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });
  }

  // Write collection_log for visit.logged
  const logRef = db.collection("collection_logs").doc();
  batch.set(logRef, {
    entityType: "visit",
    entityId: visitId,
    action: "visit.logged",
    actorId: visit.collectorId || "",
    actorName: visit.collectorName || "",
    timestamp: admin.firestore.FieldValue.serverTimestamp(),
    customerId: visit.customerId || null,
    debtId: visit.debtId || null,
    collectorId: visit.collectorId || null,
    notes: visit.notes || null,
  });

  // Write collection_log for ptp.created if a PTP is embedded
  if (visit.promiseToPay) {
    const ptpLogRef = db.collection("collection_logs").doc();
    batch.set(ptpLogRef, {
      entityType: "visit",
      entityId: visitId,
      action: "ptp.created",
      actorId: visit.collectorId || "",
      actorName: visit.collectorName || "",
      timestamp: admin.firestore.FieldValue.serverTimestamp(),
      customerId: visit.customerId || null,
      debtId: visit.debtId || null,
      collectorId: visit.collectorId || null,
      amount: visit.promiseToPay.amount || null,
    });
  }

  try {
    await batch.commit();
  } catch (err) {
    console.error("onVisitCreated: batch failed:", err);
  }
});
