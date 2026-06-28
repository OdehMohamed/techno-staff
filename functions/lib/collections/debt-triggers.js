// debt-triggers.js — onDebtStatusChanged
// Writes collection_log entries for admin status transitions (write-off, dispute, settle).
// The client (admin) writes the status change directly; this trigger picks it up.

const {onDocumentUpdated} = require("firebase-functions/firestore");
const admin = require("firebase-admin");

exports.onDebtStatusChanged = onDocumentUpdated("debts/{debtId}", async (event) => {
  const before = event.data.before.data();
  const after = event.data.after.data();

  if (before.status === after.status) return;

  const debtId = event.params.debtId;
  const db = admin.firestore();

  let action = null;
  let extra = {};

  if (after.status === "written_off") {
    action = "debt.written_off";
    extra = {
      amount: (after.writeOff && after.writeOff.amount) || null,
      notes: (after.writeOff && after.writeOff.reason) || null,
    };
  } else if (after.status === "disputed") {
    action = "debt.disputed";
    extra = {notes: (after.dispute && after.dispute.reason) || null};
  } else if (after.status === "settled" && after.settlement) {
    action = "debt.settled";
    extra = {
      amount: (after.settlement && after.settlement.settledAmount) || null,
      notes: (after.settlement && after.settlement.reason) || null,
    };
  } else if (after.status === "cancelled") {
    action = "debt.cancelled";
    extra = {notes: after.cancellationReason || null};
  }

  if (!action) return;

  const actorId =
      (after.writeOff && after.writeOff.authorizedBy) ||
      (after.dispute && after.dispute.raisedBy) ||
      (after.settlement && after.settlement.authorizedBy) ||
      "";
  const actorName =
      (after.writeOff && after.writeOff.authorizedByName) ||
      (after.dispute && after.dispute.raisedByName) ||
      (after.settlement && after.settlement.authorizedByName) ||
      "";

  try {
    await db.collection("collection_logs").add({
      entityType: "debt",
      entityId: debtId,
      action,
      actorId,
      actorName,
      timestamp: admin.firestore.FieldValue.serverTimestamp(),
      customerId: after.customerId || null,
      debtId,
      collectorId: after.assignedCollectorId || null,
      before: {status: before.status},
      after: {status: after.status},
      ...extra,
    });
  } catch (err) {
    console.error("onDebtStatusChanged: collection_log failed:", err);
  }
});
