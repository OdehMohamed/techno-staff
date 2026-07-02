// installment-triggers.js — installment plan lifecycle
// onCreate: generates sub-docs + stamps debt
// applyPaymentToInstallments: FIFO payment allocation (called by payment-triggers.js)
// sendInstallmentDueReminders: daily 09:00 Asia/Jerusalem scheduler

const {onDocumentCreated} = require("firebase-functions/firestore");
const {onSchedule} = require("firebase-functions/v2/scheduler");
const admin = require("firebase-admin");
const {createInAppNotification} = require("../shared");

// ─── Pure helpers ─────────────────────────────────────────────────────────────

function padNum(n) {
  return String(n).padStart(3, "0");
}

/**
 * Compute the due date for installment at zero-based `offset` from startDate.
 * @param {admin.firestore.Timestamp|Date} startDate
 * @param {string} frequency 'weekly' | 'biweekly' | 'monthly'
 * @param {number} offset 0 = startDate itself
 * @return {Date}
 */
function installmentDueDate(startDate, frequency, offset) {
  const d = new Date(startDate.toDate ? startDate.toDate() : startDate);
  if (frequency === "weekly") {
    d.setDate(d.getDate() + 7 * offset);
  } else if (frequency === "biweekly") {
    d.setDate(d.getDate() + 14 * offset);
  } else {
    // monthly
    d.setMonth(d.getMonth() + offset);
  }
  return d;
}

function formatAgorot(agorot) {
  return `₪${(agorot / 100).toFixed(2)}`;
}

// ─── onInstallmentPlanCreated ─────────────────────────────────────────────────

exports.onInstallmentPlanCreated = onDocumentCreated(
    "installment_plans/{planId}",
    async (event) => {
      const planId = event.params.planId;
      const plan = event.data.data();
      const db = admin.firestore();

      const {
        debtId,
        customerId,
        totalInstallments,
        installmentAmount,
        frequency,
        startDate,
      } = plan;

      // Fetch debt to get assignedCollectorId for denormalization
      let collectorId = null;
      try {
        const debtSnap = await db.collection("debts").doc(debtId).get();
        if (debtSnap.exists) {
          collectorId = debtSnap.data().assignedCollectorId || null;
        }
      } catch (err) {
        console.error("onInstallmentPlanCreated: failed to fetch debt:", err);
      }

      const planRef = db.collection("installment_plans").doc(planId);
      const batch = db.batch();

      // Generate installment sub-documents (zero-padded id: '001', '002', …)
      for (let i = 0; i < totalInstallments; i++) {
        const dueDate = installmentDueDate(startDate, frequency, i);
        const subRef = planRef.collection("installments").doc(padNum(i + 1));
        batch.set(subRef, {
          number: i + 1,
          dueDate: admin.firestore.Timestamp.fromDate(dueDate),
          expectedAmount: installmentAmount,
          paidAmount: 0,
          status: "pending",
          paymentIds: [],
          paidAt: null,
          // Denormalized for collection group queries
          planId,
          debtId,
          customerId,
          collectorId,
        });
      }

      // Stamp debt: hasInstallmentPlan, installmentPlanId, nextInstallmentDueDate
      const firstDueDate = installmentDueDate(startDate, frequency, 0);
      batch.update(db.collection("debts").doc(debtId), {
        hasInstallmentPlan: true,
        installmentPlanId: planId,
        nextInstallmentDueDate: admin.firestore.Timestamp.fromDate(firstDueDate),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      try {
        await batch.commit();
      } catch (err) {
        console.error("onInstallmentPlanCreated: batch failed:", err);
      }
    },
);

// ─── applyPaymentToInstallments ───────────────────────────────────────────────

/**
 * FIFO installment allocation. Called from onPaymentCreated after the main
 * debt-balance transaction commits.
 *
 * Applies `paymentAmount` agorot to the plan's installments in ascending order,
 * skipping already-paid ones. Writes a batch update for modified installments
 * and refreshes debt.nextInstallmentDueDate.
 *
 * @param {admin.firestore.Firestore} db
 * @param {string} planId
 * @param {string} paymentId
 * @param {number} paymentAmount agorot
 * @param {string} debtId  needed to update nextInstallmentDueDate
 * @return {Promise<void>}
 */
async function applyPaymentToInstallments(db, planId, paymentId, paymentAmount, debtId) {
  const planRef = db.collection("installment_plans").doc(planId);
  const installmentsSnap = await planRef
      .collection("installments")
      .orderBy("number")
      .get();

  if (installmentsSnap.empty) return;

  let remaining = paymentAmount;
  const now = admin.firestore.Timestamp.now();
  const batch = db.batch();
  let modified = false;

  let nextDueDate = null; // first non-paid installment's dueDate

  for (const doc of installmentsSnap.docs) {
    const inst = doc.data();

    if (inst.status === "paid") {
      // Already paid — skip but don't count as nextDueDate
      continue;
    }

    if (remaining <= 0) {
      // No funds left — this installment is the next one due
      if (nextDueDate === null) nextDueDate = inst.dueDate;
      continue;
    }

    const deficit = inst.expectedAmount - inst.paidAmount;

    if (remaining >= deficit) {
      // Fully covers this installment
      batch.update(doc.ref, {
        paidAmount: inst.expectedAmount,
        status: "paid",
        paidAt: now,
        paymentIds: admin.firestore.FieldValue.arrayUnion(paymentId),
      });
      remaining -= deficit;
      modified = true;
    } else {
      // Partially covers this installment
      batch.update(doc.ref, {
        paidAmount: inst.paidAmount + remaining,
        status: "partial",
        paymentIds: admin.firestore.FieldValue.arrayUnion(paymentId),
      });
      remaining = 0;
      modified = true;
      // This installment is still outstanding — it's the next due
      if (nextDueDate === null) nextDueDate = inst.dueDate;
    }
  }

  if (!modified) return;

  // Update debt.nextInstallmentDueDate (null if all installments are paid)
  batch.update(db.collection("debts").doc(debtId), {
    nextInstallmentDueDate: nextDueDate,
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  });

  try {
    await batch.commit();
  } catch (err) {
    console.error("applyPaymentToInstallments: batch failed:", err);
  }
}

exports.applyPaymentToInstallments = applyPaymentToInstallments;

// ─── sendInstallmentDueReminders ─────────────────────────────────────────────

exports.sendInstallmentDueReminders = onSchedule(
    {schedule: "0 9 * * *", timeZone: "Asia/Jerusalem"},
    async () => {
      const db = admin.firestore();

      // Window: installments due tomorrow (any that land in the next 24 h)
      const now = new Date();
      const windowStart = new Date(now);
      windowStart.setHours(23, 59, 59, 999); // end of today
      const windowEnd = new Date(now);
      windowEnd.setDate(windowEnd.getDate() + 2);
      windowEnd.setHours(0, 0, 0, 0); // start of day after tomorrow

      let snap;
      try {
        snap = await db.collectionGroup("installments")
            .where("status", "in", ["pending", "partial"])
            .where("dueDate", ">", admin.firestore.Timestamp.fromDate(windowStart))
            .where("dueDate", "<=", admin.firestore.Timestamp.fromDate(windowEnd))
            .get();
      } catch (err) {
        console.error("sendInstallmentDueReminders: query failed:", err);
        return;
      }

      if (snap.empty) return;

      // Fetch admin list once outside the loop instead of once per installment.
      let adminSnap;
      try {
        adminSnap = await db.collection("users")
            .where("role", "==", "admin")
            .where("isActive", "==", true)
            .get();
      } catch (err) {
        console.error("sendInstallmentDueReminders: admin query failed:", err);
        adminSnap = {docs: []};
      }

      for (const doc of snap.docs) {
        const inst = doc.data();
        const {collectorId, debtId, customerId, expectedAmount, paidAmount, dueDate} = inst;

        const dueDateStr = dueDate.toDate().toLocaleDateString("he-IL");
        const outstanding = expectedAmount - paidAmount;

        // Notify collector
        if (collectorId) {
          try {
            await createInAppNotification({
              userId: collectorId,
              type: "installment_due",
              data: {
                debtId,
                customerId,
                amount: outstanding,
                dueDate: dueDateStr,
                amountFormatted: formatAgorot(outstanding),
              },
            });
          } catch (err) {
            console.error(`sendInstallmentDueReminders: collector notify failed (${doc.id}):`, err);
          }
        }

        // Notify admins
        try {
          await Promise.all(adminSnap.docs.map((adminDoc) =>
            createInAppNotification({
              userId: adminDoc.id,
              type: "installment_due",
              data: {
                debtId,
                customerId,
                collectorId,
                amount: outstanding,
                dueDate: dueDateStr,
                amountFormatted: formatAgorot(outstanding),
              },
            }),
          ));
        } catch (err) {
          console.error(`sendInstallmentDueReminders: admin notify failed (${doc.id}):`, err);
        }
      }
    },
);
