const {onSchedule} = require("firebase-functions/v2/scheduler");
const admin = require("firebase-admin");

// Deletes in-app notifications older than 30 days. Runs weekly on Sunday at
// 02:00 Asia/Jerusalem so batch deletes don't overlap with peak-hour traffic.
exports.cleanupExpiredNotifications = onSchedule(
    {
      schedule: "0 2 * * 0",
      timeZone: "Asia/Jerusalem",
    },
    async () => {
      const db = admin.firestore();
      const cutoff = admin.firestore.Timestamp.fromDate(
          new Date(Date.now() - 30 * 24 * 60 * 60 * 1000),
      );

      const snap = await db
          .collection("notifications")
          .where("createdAt", "<", cutoff)
          .get();

      if (snap.empty) {
        console.log("cleanupExpiredNotifications: no expired notifications.");
        return;
      }

      const BATCH_SIZE = 500;
      for (let i = 0; i < snap.docs.length; i += BATCH_SIZE) {
        const batch = db.batch();
        snap.docs.slice(i, i + BATCH_SIZE).forEach((doc) => batch.delete(doc.ref));
        await batch.commit();
      }

      console.log(`cleanupExpiredNotifications: deleted ${snap.docs.length}.`);
    },
);
