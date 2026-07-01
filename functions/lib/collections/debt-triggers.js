// debt-triggers.js — onDebtStatusChanged
// Writes collection_log entries for admin status transitions (write-off, dispute, settle).
// Also syncs customer.totalOutstandingBalance when a debt is written off, cancelled,
// or settled via settle-for-less (normal payment settlement is handled by onPaymentCreated).

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

  // Sync customer.totalOutstandingBalance for terminal transitions.
  // written_off / cancelled: the remaining balance is forgiven — reduce customer total.
  // settled via settleForLess (after.settlement present): no payment was recorded,
  //   so onPaymentCreated did NOT decrement the balance — we must do it here.
  // settled via normal payment: onPaymentCreated already decremented by the payment
  //   amount, so we do NOT decrement again here.
  const terminalStatuses = ["written_off", "cancelled", "settled"];
  const prevWasNonTerminal = !terminalStatuses.includes(before.status);
  const nowIsTerminal = terminalStatuses.includes(after.status);

  if (prevWasNonTerminal && nowIsTerminal && after.customerId) {
    let adjustment = 0;

    if (after.status === "written_off" || after.status === "cancelled") {
      adjustment = before.remainingBalance || 0;
    } else if (after.status === "settled" && after.settlement) {
      // settleForLess: before.remainingBalance is the outstanding amount being forgiven
      adjustment = before.remainingBalance || 0;
    }

    if (adjustment > 0) {
      try {
        await db.collection("customers").doc(after.customerId).update({
          totalOutstandingBalance: admin.firestore.FieldValue.increment(-adjustment),
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        });
      } catch (balErr) {
        console.error("onDebtStatusChanged: customer balance sync failed:", balErr);
      }
    }
  }
});
