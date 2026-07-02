// schedulers.js — daily automation crons for the collections subsystem
//
// updateDebtAgingBuckets   08:00 Jerusalem — ages all open debts
// checkBrokenPtps          08:30 Jerusalem — marks missed PTPs as broken
// sendOverdueDebtEscalations 10:00 Jerusalem — notifies collectors + admins
// sendStaleCashWarnings    11:00 Jerusalem — warns about un-handed-over cash

const {onSchedule} = require("firebase-functions/v2/scheduler");
const {onCall, HttpsError} = require("firebase-functions/v2/https");
const admin = require("firebase-admin");
const {createInAppNotification} = require("../shared");

// ─── helpers ─────────────────────────────────────────────────────────────────

function todayJerusalem() {
  const now = new Date();
  const parts = new Intl.DateTimeFormat("en-CA", {
    timeZone: "Asia/Jerusalem",
    year: "numeric",
    month: "2-digit",
    day: "2-digit",
  }).formatToParts(now);
  const y = parts.find((p) => p.type === "year").value;
  const m = parts.find((p) => p.type === "month").value;
  const d = parts.find((p) => p.type === "day").value;
  return new Date(`${y}-${m}-${d}T00:00:00.000Z`);
}

function agingBucket(daysPastDue) {
  if (daysPastDue <= 0) return "current";
  if (daysPastDue <= 30) return "1-30";
  if (daysPastDue <= 60) return "31-60";
  if (daysPastDue <= 90) return "61-90";
  return "90+";
}

function formatAgorot(agorot) {
  return `₪${(agorot / 100).toFixed(2)}`;
}

// ─── updateDebtAgingBuckets ───────────────────────────────────────────────────

async function _runDebtAgingBuckets() {
  const db = admin.firestore();
  const today = todayJerusalem();

  // Process in pages of 500
  let lastDoc = null;
  const customerUpdates = new Map(); // customerId → worst agingBucket

  for (;;) {
    let query = db.collection("debts")
        .where("status", "in", ["active", "partial", "overdue"])
        .limit(500);
    if (lastDoc) query = query.startAfter(lastDoc);

    const snap = await query.get();
    if (snap.empty) break;

    const batch = db.batch();

    for (const doc of snap.docs) {
      const debt = doc.data();
      let daysPastDue = 0;
      let newStatus = debt.status;

      if (debt.dueDate) {
        const due = debt.dueDate.toDate();
        daysPastDue = Math.max(
            0,
            Math.floor((today - due) / 86400000),
        );
        if (daysPastDue > 0 && debt.status !== "overdue") {
          newStatus = "overdue";
        }
      }

      const bucket = agingBucket(daysPastDue);
      const update = {
        daysPastDue,
        agingBucket: bucket,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      };
      if (newStatus !== debt.status) update.status = newStatus;
      batch.update(doc.ref, update);

      // Track worst bucket per customer for accountStatus update
      if (debt.customerId) {
        const existing = customerUpdates.get(debt.customerId);
        const bucketRank = {"current": 0, "1-30": 1, "31-60": 2, "61-90": 3, "90+": 4};
        if (!existing || bucketRank[bucket] > bucketRank[existing]) {
          customerUpdates.set(debt.customerId, bucket);
        }
      }
    }

    await batch.commit();
    lastDoc = snap.docs[snap.docs.length - 1];
    if (snap.docs.length < 500) break;
  }

  // Update customer.accountStatus based on worst aging bucket
  const customerBatch = db.batch();
  for (const [customerId, bucket] of customerUpdates) {
    let accountStatus = "good_standing";
    if (bucket === "31-60" || bucket === "61-90") accountStatus = "at_risk";
    if (bucket === "90+") accountStatus = "delinquent";

    customerBatch.update(db.collection("customers").doc(customerId), {
      accountStatus,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });
  }
  if (customerUpdates.size > 0) {
    await customerBatch.commit();
  }
}

exports.updateDebtAgingBuckets = onSchedule(
    {schedule: "0 8 * * *", timeZone: "Asia/Jerusalem"},
    _runDebtAgingBuckets,
);

// ─── checkBrokenPtps ─────────────────────────────────────────────────────────

async function _runCheckBrokenPtps() {
  const db = admin.firestore();
  const today = todayJerusalem();

  let snap;
  try {
    snap = await db.collection("visits")
        .where("promiseToPay.status", "==", "pending")
        .where("promiseToPay.promisedDate", "<",
            admin.firestore.Timestamp.fromDate(today))
        .get();
  } catch (err) {
    console.error("checkBrokenPtps: query failed:", err);
    return;
  }

  if (snap.empty) return;

  // Chunk into batches of 200 pairs (400 ops max per batch; Firestore limit is 500).
  const CHUNK = 200;
  const brokenByCollector = new Map();

  for (let i = 0; i < snap.docs.length; i += CHUNK) {
    const chunk = snap.docs.slice(i, i + CHUNK);
    const batch = db.batch();

    for (const doc of chunk) {
      const visit = doc.data();
      batch.update(doc.ref, {"promiseToPay.status": "broken"});

      const logRef = db.collection("collection_logs").doc();
      batch.set(logRef, {
        entityType: "visit",
        entityId: doc.id,
        action: "ptp.broken",
        actorId: "system",
        actorName: "system",
        timestamp: admin.firestore.FieldValue.serverTimestamp(),
        customerId: visit.customerId || null,
        debtId: visit.debtId || null,
        collectorId: visit.collectorId || null,
        amount: (visit.promiseToPay && visit.promiseToPay.amount) || null,
      });

      if (visit.collectorId) {
        brokenByCollector.set(
            visit.collectorId,
            (brokenByCollector.get(visit.collectorId) || 0) + 1,
        );
      }
    }

    await batch.commit();
  }

  // Notify each collector with a digest
  for (const [collectorId, count] of brokenByCollector) {
    try {
      await createInAppNotification({
        userId: collectorId,
        type: "broken_ptps",
        data: {count},
      });
    } catch (err) {
      console.error(`checkBrokenPtps: collector notify failed (${collectorId}):`, err);
    }
  }

  // Single admin digest
  const totalBroken = snap.size;
  try {
    const adminSnap = await db.collection("users")
        .where("role", "==", "admin")
        .where("isActive", "==", true)
        .get();
    await Promise.all(adminSnap.docs.map((doc) =>
      createInAppNotification({
        userId: doc.id,
        type: "broken_ptps_admin",
        data: {count: totalBroken},
      }),
    ));
  } catch (err) {
    console.error("checkBrokenPtps: admin notify failed:", err);
  }
}

exports.checkBrokenPtps = onSchedule(
    {schedule: "30 8 * * *", timeZone: "Asia/Jerusalem"},
    _runCheckBrokenPtps,
);

// ─── sendOverdueDebtEscalations ──────────────────────────────────────────────

async function _runSendOverdueDebtEscalations() {
  const db = admin.firestore();
  const today = todayJerusalem();
  const todayTs = admin.firestore.Timestamp.fromDate(today);

  let snap;
  try {
    // Filter by status only — overdue debts are never 'current' once aging runs,
    // so the redundant agingBucket filter has been removed (it also required a
    // composite index that did not exist, causing this cron to fail silently).
    snap = await db.collection("debts")
        .where("status", "==", "overdue")
        .get();
  } catch (err) {
    console.error("sendOverdueDebtEscalations: query failed:", err);
    return;
  }

  if (snap.empty) return;

  const adminSnap = await db.collection("users")
      .where("role", "==", "admin")
      .where("isActive", "==", true)
      .get();

  const batch = db.batch();

  for (const doc of snap.docs) {
    const debt = doc.data();

    // Skip if already escalated today
    if (debt.lastOverdueEscalationAt) {
      const last = debt.lastOverdueEscalationAt.toDate();
      if (last >= today) continue;
    }

    // Notify collector
    if (debt.assignedCollectorId) {
      try {
        await createInAppNotification({
          userId: debt.assignedCollectorId,
          type: "debt_overdue",
          data: {
            debtId: doc.id,
            customerName: debt.customerName,
            daysPastDue: debt.daysPastDue,
            remainingBalance: debt.remainingBalance,
            amountFormatted: formatAgorot(debt.remainingBalance),
          },
        });
      } catch (err) {
        console.error(`sendOverdueDebtEscalations: collector notify failed (${doc.id}):`, err);
      }
    }

    // Escalate to admins if 30+ days past due
    if (debt.daysPastDue >= 30) {
      try {
        await Promise.all(adminSnap.docs.map((adminDoc) =>
          createInAppNotification({
            userId: adminDoc.id,
            type: "debt_overdue_escalation",
            data: {
              debtId: doc.id,
              customerName: debt.customerName,
              collectorName: debt.assignedCollectorName,
              daysPastDue: debt.daysPastDue,
              remainingBalance: debt.remainingBalance,
              amountFormatted: formatAgorot(debt.remainingBalance),
            },
          }),
        ));
      } catch (err) {
        console.error(`sendOverdueDebtEscalations: admin escalation failed (${doc.id}):`, err);
      }
    }

    batch.update(doc.ref, {
      lastOverdueEscalationAt: todayTs,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });
  }

  try {
    await batch.commit();
  } catch (err) {
    console.error("sendOverdueDebtEscalations: batch update failed:", err);
  }
}

exports.sendOverdueDebtEscalations = onSchedule(
    {schedule: "0 10 * * *", timeZone: "Asia/Jerusalem"},
    _runSendOverdueDebtEscalations,
);

// ─── sendStaleCashWarnings ────────────────────────────────────────────────────

async function _runStaleCashWarnings() {
  const db = admin.firestore();
  const today = todayJerusalem();

  // Read staleCashWarningDays from config (default 3)
  let warningDays = 3;
  try {
    const settingsSnap = await db
        .collection("config")
        .doc("collection_settings")
        .get();
    const sdata = settingsSnap.data();
    warningDays = (sdata && sdata.staleCashWarningDays) || 3;
  } catch (err) {
    console.error("sendStaleCashWarnings: settings read failed:", err);
  }

  const collectorsSnap = await db
      .collection("users")
      .where("role", "==", "collector")
      .where("cashOnHand", ">", 0)
      .where("isActive", "==", true)
      .get();

  if (collectorsSnap.empty) return;

  const adminSnap = await db
      .collection("users")
      .where("role", "==", "admin")
      .where("isActive", "==", true)
      .get();

  for (const collectorDoc of collectorsSnap.docs) {
    const collector = collectorDoc.data();

    // Skip if already warned today
    if (collector.lastStaleCashWarnAt) {
      const last = collector.lastStaleCashWarnAt.toDate();
      if (last >= today) continue;
    }

    // Find oldest pending_handover payment for this collector
    let oldestPayment = null;
    try {
      const paySnap = await db
          .collection("payments")
          .where("collectorId", "==", collectorDoc.id)
          .where("status", "==", "pending_handover")
          .where("isCancelled", "==", false)
          .orderBy("collectedAt")
          .limit(1)
          .get();
      if (!paySnap.empty) {
        oldestPayment = paySnap.docs[0].data();
      }
    } catch (err) {
      console.error(`sendStaleCashWarnings: payment query failed (${collectorDoc.id}):`, err);
      continue;
    }

    if (!oldestPayment) continue;

    const daysSince = Math.floor(
        (today - oldestPayment.collectedAt.toDate()) / 86400000,
    );

    if (daysSince < warningDays) continue;

    const cashOnHand = collector.cashOnHand || 0;

    try {
      await createInAppNotification({
        userId: collectorDoc.id,
        type: "stale_cash",
        data: {
          cashOnHand,
          amountFormatted: formatAgorot(cashOnHand),
          daysSince,
        },
      });
    } catch (err) {
      console.error(`sendStaleCashWarnings: collector notify failed (${collectorDoc.id}):`, err);
    }

    try {
      await Promise.all(adminSnap.docs.map((adminDoc) =>
        createInAppNotification({
          userId: adminDoc.id,
          type: "stale_cash_admin",
          data: {
            collectorId: collectorDoc.id,
            collectorName: collector.name || "",
            cashOnHand,
            amountFormatted: formatAgorot(cashOnHand),
            daysSince,
          },
        }),
      ));
    } catch (err) {
      console.error(`sendStaleCashWarnings: admin notify failed (${collectorDoc.id}):`, err);
    }

    // Stamp lastStaleCashWarnAt to deduplicate tomorrow
    await collectorDoc.ref.update({
      lastStaleCashWarnAt: admin.firestore.Timestamp.fromDate(today),
    });
  }
}

exports.sendStaleCashWarnings = onSchedule(
    {schedule: "0 11 * * *", timeZone: "Asia/Jerusalem"},
    _runStaleCashWarnings,
);

// ─── Test callables (admin-only) ─────────────────────────────────────────────

async function _assertAdmin(request) {
  if (!request.auth) throw new HttpsError("unauthenticated", "Login required");
  const snap = await admin.firestore().collection("users").doc(request.auth.uid).get();
  if (!snap.exists || snap.data().role !== "admin") {
    throw new HttpsError("permission-denied", "Admins only");
  }
}

exports.testUpdateDebtAgingBuckets = onCall(async (request) => {
  await _assertAdmin(request);
  await _runDebtAgingBuckets();
  return {success: true};
});

exports.testSendStaleCashWarnings = onCall(async (request) => {
  await _assertAdmin(request);
  await _runStaleCashWarnings();
  return {success: true};
});

exports.testCheckBrokenPtps = onCall(async (request) => {
  await _assertAdmin(request);
  await _runCheckBrokenPtps();
  return {success: true};
});

exports.testSendOverdueDebtEscalations = onCall(async (request) => {
  await _assertAdmin(request);
  await _runSendOverdueDebtEscalations();
  return {success: true};
});
