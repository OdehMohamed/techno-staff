// debt-triggers.js — onDebtCreated + onDebtStatusChanged
//
// Owns customer.totalOutstandingBalance — the authoritative running total of
// all non-terminal debt remainingBalances for each customer.
//
// Write map:
//   onDebtCreated        → +originalAmount   (idempotent via _customerBalanceIncremented)
//   onDebtStatusChanged  → -before.remainingBalance when status goes terminal
//                          (idempotent via _customerBalanceSynced, clamped to 0)
//
// Payment-side writes (payment recorded / cancelled) live in payment-triggers.js.

const {onDocumentCreated, onDocumentUpdated} = require("firebase-functions/firestore");
const admin = require("firebase-admin");

// ─── Pure helper ──────────────────────────────────────────────────────────────

/**
 * Amount (agorot) to subtract from customer.totalOutstandingBalance when a debt
 * transitions into a terminal status. Returns 0 when no adjustment is needed.
 *
 * Covered cases:
 *   written_off — forgiven remainder, no prior payment covers it
 *   cancelled   — debt voided, remaining balance leaves the ledger
 *   settled via settleForLess (after.settlement present)
 *               — client set remainingBalance→0 directly; onPaymentCreated did
 *                 NOT record a payment, so the customer balance was not touched
 *
 * Not covered (already handled by onPaymentCreated):
 *   settled via normal payment — each payment decremented the balance
 *
 * @param {object} before Firestore data before the status-change write
 * @param {object} after  Firestore data after the status-change write
 * @return {number} agorot >= 0
 */
function calculateBalanceAdjustment(before, after) {
  const terminal = ["written_off", "cancelled", "settled"];

  // Skip if the debt was already in a terminal state (e.g., someone updates
  // a non-status field after the debt was written off).
  if (terminal.includes(before.status)) return 0;
  if (!terminal.includes(after.status)) return 0;

  if (after.status === "written_off" || after.status === "cancelled") {
    return before.remainingBalance || 0;
  }
  if (after.status === "settled" && after.settlement) {
    return before.remainingBalance || 0;
  }
  return 0; // settled via normal payment — onPaymentCreated already handled it
}

// ─── onDebtCreated ────────────────────────────────────────────────────────────

exports.onDebtCreated = onDocumentCreated("debts/{debtId}", async (event) => {
  const debtId = event.params.debtId;
  const debt = event.data.data();

  if (!debt || !debt.customerId || !debt.originalAmount || debt.originalAmount <= 0) return;

  const db = admin.firestore();

  try {
    await db.runTransaction(async (tx) => {
      const debtRef = db.collection("debts").doc(debtId);
      const debtSnap = await tx.get(debtRef);
      if (!debtSnap.exists) return;

      // Idempotency: _customerBalanceIncremented prevents double-increment on retry
      if (debtSnap.data()._customerBalanceIncremented) return;

      const amount = debtSnap.data().originalAmount;
      const customerRef = db.collection("customers").doc(debt.customerId);

      tx.update(debtRef, {_customerBalanceIncremented: true});
      tx.update(customerRef, {
        totalOutstandingBalance: admin.firestore.FieldValue.increment(amount),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    });
  } catch (err) {
    console.error("onDebtCreated: customer balance update failed:", err);
  }
});

// ─── onDebtStatusChanged ──────────────────────────────────────────────────────

exports.onDebtStatusChanged = onDocumentUpdated("debts/{debtId}", async (event) => {
  const before = event.data.before.data();
  const after = event.data.after.data();

  // Idempotency guard: setting the _customerBalance* stamps above triggers this
  // handler again — return immediately when status hasn't changed.
  if (before.status === after.status) return;

  const debtId = event.params.debtId;
  const db = admin.firestore();

  // ── collection_log ──────────────────────────────────────────────────────────

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

  if (action) {
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
  }

  // ── customer.totalOutstandingBalance ─────────────────────────────────────────

  if (!after.customerId) return;

  const adjustment = calculateBalanceAdjustment(before, after);
  if (adjustment <= 0) return;

  try {
    await db.runTransaction(async (tx) => {
      const debtRef = db.collection("debts").doc(debtId);
      const customerRef = db.collection("customers").doc(after.customerId);

      // Read both in one round-trip
      const [debtSnap, customerSnap] = await Promise.all([
        tx.get(debtRef),
        tx.get(customerRef),
      ]);

      // Idempotency: _customerBalanceSynced prevents double-decrement on retry
      if (debtSnap.data() && debtSnap.data()._customerBalanceSynced) return;

      const currentBalance = (customerSnap.data() && customerSnap.data().totalOutstandingBalance) || 0;
      // Clamp to 0 — guards against legacy data that was never initialised correctly
      const newBalance = Math.max(0, currentBalance - adjustment);

      tx.update(debtRef, {_customerBalanceSynced: true});
      tx.update(customerRef, {
        totalOutstandingBalance: newBalance,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    });
  } catch (err) {
    console.error("onDebtStatusChanged: customer balance sync failed:", err);
  }
});

// ─── Exports ──────────────────────────────────────────────────────────────────

module.exports = {
  ...exports,
  // Pure helper exported for unit tests
  calculateBalanceAdjustment,
};
