const {onCall, HttpsError} = require("firebase-functions/https");
const {onSchedule} = require("firebase-functions/v2/scheduler");
const admin = require("firebase-admin");
const {
  ymdInJerusalem,
  jerusalemDayOfWeek,
  checkInStatusForSchedule,
} = require("./shared");

exports.recordAttendance = onCall(async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "User must be logged in");
  }

  const action = request.data && request.data.action;

  if (action !== "check_in" && action !== "check_out") {
    throw new HttpsError("invalid-argument", "Invalid attendance action");
  }

  const db = admin.firestore();
  const now = new Date();
  const date = ymdInJerusalem(now);
  const userId = request.auth.uid;
  const docId = `${userId}_${date}`;

  const userDoc = await db.collection("users").doc(userId).get();
  if (!userDoc.exists) {
    throw new HttpsError("permission-denied", "Current user record not found");
  }
  const userData = userDoc.data() || {};
  const userName = userData.name || "Unknown";

  const scheduleDoc = await db.collection("schedules").doc(userId).get();
  const scheduleData = scheduleDoc.exists ? scheduleDoc.data() : null;
  const dayOfWeek = jerusalemDayOfWeek(now);
  const checkInStatus = checkInStatusForSchedule(scheduleData, now, dayOfWeek);

  const attendanceRef = db.collection("attendance").doc(docId);
  const logRef = db.collection("attendance_logs").doc();

  await db.runTransaction(async (txn) => {
    const attendanceSnap = await txn.get(attendanceRef);
    const previousValue = attendanceSnap.exists ? attendanceSnap.data() : null;

    if (action === "check_in") {
      const existingData = attendanceSnap.exists ? attendanceSnap.data() : {};
      const sessions = Array.isArray(existingData.sessions) ?
        existingData.sessions :
        [];
      const lastSession =
        sessions.length > 0 ? sessions[sessions.length - 1] : null;

      if (lastSession && lastSession.checkOutAt == null) {
        throw new HttpsError("already-exists", "already-checked-in");
      }

      const newSession = {
        checkInAt: admin.firestore.Timestamp.fromDate(now),
        checkOutAt: null,
        durationMinutes: null,
      };

      if (!attendanceSnap.exists) {
        txn.set(attendanceRef, {
          userId,
          userName,
          date,
          status: checkInStatus,
          isCorrected: false,
          totalDurationMinutes: 0,
          sessions: [newSession],
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        });
      } else {
        txn.update(attendanceRef, {
          sessions: [...sessions, newSession],
          status: checkInStatus,
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        });
      }

      txn.set(logRef, {
        attendanceId: docId,
        userId,
        action: "check_in",
        performedBy: userId,
        performedByName: userName,
        previousValue,
        newValue: {
          session: "appended",
          status: checkInStatus,
        },
        performedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
      return;
    }

    if (!attendanceSnap.exists) {
      throw new HttpsError("failed-precondition", "not-checked-in");
    }

    const sessions = Array.isArray(attendanceSnap.data().sessions) ?
      attendanceSnap.data().sessions :
      [];
    const openSession =
      sessions.length > 0 ? sessions[sessions.length - 1] : null;

    if (!openSession || openSession.checkOutAt != null) {
      throw new HttpsError("failed-precondition", "not-checked-in");
    }

    const checkInAt = openSession.checkInAt.toDate();
    const durationMinutes = Math.max(
        0,
        Math.round((now.getTime() - checkInAt.getTime()) / 60000),
    );
    const closedSession = {
      ...openSession,
      checkOutAt: admin.firestore.Timestamp.fromDate(now),
      durationMinutes,
    };
    const updatedSessions = [...sessions.slice(0, -1), closedSession];
    const totalDurationMinutes = updatedSessions.reduce(
        (sum, session) => sum + (session.durationMinutes || 0),
        0,
    );

    txn.update(attendanceRef, {
      sessions: updatedSessions,
      totalDurationMinutes,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });
    txn.set(logRef, {
      attendanceId: docId,
      userId,
      action: "check_out",
      performedBy: userId,
      performedByName: userName,
      previousValue,
      newValue: {
        session: "closed",
        totalDurationMinutes,
      },
      performedAt: admin.firestore.FieldValue.serverTimestamp(),
    });
  });

  return {success: true, docId};
});

exports.adminCorrectAttendance = onCall(async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "User must be logged in");
  }

  const adminUid = request.auth.uid;
  const db = admin.firestore();

  const adminDoc = await db.collection("users").doc(adminUid).get();
  if (!adminDoc.exists || (adminDoc.data() || {}).role !== "admin") {
    throw new HttpsError(
        "permission-denied",
        "Only admins can correct attendance",
    );
  }

  const adminName = (adminDoc.data() || {}).name || "Admin";
  const userId = request.data && request.data.userId;
  const date = request.data && request.data.date;

  if (!userId || !date) {
    throw new HttpsError(
        "invalid-argument",
        "Missing required correction payload",
    );
  }

  if (!/^\d{4}-\d{2}-\d{2}$/.test(date)) {
    throw new HttpsError("invalid-argument", "Invalid date format");
  }

  // New sessions-array path (primary).
  const rawSessions =
    request.data &&
    Array.isArray(request.data.sessions) &&
    request.data.sessions.length > 0 ?
      request.data.sessions :
      null;

  // Legacy fields path (backward compat — kept so old clients don't break).
  const fields = (request.data && request.data.fields) || {};
  const hasCheckInAt = Object.prototype.hasOwnProperty.call(fields, "checkInAt");
  const hasCheckOutAt = Object.prototype.hasOwnProperty.call(fields, "checkOutAt");

  if (!rawSessions && !hasCheckInAt) {
    throw new HttpsError(
        "invalid-argument",
        "Either sessions array or fields.checkInAt must be provided",
    );
  }

  // notes can arrive as a top-level field (new path) or inside fields (legacy).
  const notes =
    request.data && request.data.notes !== undefined ?
      request.data.notes :
      fields.notes !== undefined ?
        fields.notes :
        undefined;

  const userDoc = await db.collection("users").doc(userId).get();
  if (!userDoc.exists) {
    throw new HttpsError("not-found", "Target user not found");
  }
  const userName = (userDoc.data() || {}).name || "Unknown";

  const docId = `${userId}_${date}`;
  const attendanceRef = db.collection("attendance").doc(docId);
  const logRef = db.collection("attendance_logs").doc();

  await db.runTransaction(async (txn) => {
    const attendanceSnap = await txn.get(attendanceRef);
    const existing = attendanceSnap.exists ? attendanceSnap.data() : {};
    const previousValue = attendanceSnap.exists ? existing : null;

    const nextValue = {
      isCorrected: true,
      correctedBy: adminUid,
      correctedByName: adminName,
      correctedAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    };

    // Preserve the original sessions on the first correction for auditability.
    // Subsequent corrections leave originalSessions intact (first version wins).
    if (!existing.isCorrected && Array.isArray(existing.sessions)) {
      nextValue.originalSessions = existing.sessions;
    }

    if (notes !== undefined) {
      nextValue.notes = notes == null ? null : String(notes);
    }

    if (rawSessions) {
      // Validate, compute durations, and sort by checkInAt.
      const parsed = rawSessions.map((s, idx) => {
        const checkInDate = new Date(s.checkInAt);
        if (Number.isNaN(checkInDate.getTime())) {
          throw new HttpsError(
              "invalid-argument",
              `Session ${idx}: invalid checkInAt`,
          );
        }
        const checkOutDate = s.checkOutAt ? new Date(s.checkOutAt) : null;
        if (checkOutDate && Number.isNaN(checkOutDate.getTime())) {
          throw new HttpsError(
              "invalid-argument",
              `Session ${idx}: invalid checkOutAt`,
          );
        }
        const durationMinutes =
          checkOutDate != null ?
            Math.max(
                0,
                Math.round(
                    (checkOutDate.getTime() - checkInDate.getTime()) / 60000,
                ),
            ) :
            null;
        return {
          checkInAt: admin.firestore.Timestamp.fromDate(checkInDate),
          checkOutAt: checkOutDate ?
            admin.firestore.Timestamp.fromDate(checkOutDate) :
            null,
          durationMinutes,
        };
      });

      // Guarantee session ordering.
      parsed.sort((a, b) => a.checkInAt.toMillis() - b.checkInAt.toMillis());

      const totalDurationMinutes = parsed.reduce(
          (sum, s) => sum + (s.durationMinutes || 0),
          0,
      );

      nextValue.sessions = parsed;
      nextValue.totalDurationMinutes = totalDurationMinutes;
      nextValue.status = "present";
    } else if (hasCheckInAt && hasCheckOutAt) {
      // Legacy path: single check-in/check-out pair.
      const parsedCheckInAt = new Date(fields.checkInAt);
      const parsedCheckOutAt = new Date(fields.checkOutAt);
      if (
        Number.isNaN(parsedCheckInAt.getTime()) ||
        Number.isNaN(parsedCheckOutAt.getTime())
      ) {
        throw new HttpsError(
            "invalid-argument",
            "Invalid checkInAt/checkOutAt timestamp",
        );
      }

      const durationMinutes = Math.max(
          0,
          Math.round(
              (parsedCheckOutAt.getTime() - parsedCheckInAt.getTime()) / 60000,
          ),
      );

      nextValue.sessions = [
        {
          checkInAt: admin.firestore.Timestamp.fromDate(parsedCheckInAt),
          checkOutAt: admin.firestore.Timestamp.fromDate(parsedCheckOutAt),
          durationMinutes,
        },
      ];
      nextValue.totalDurationMinutes = durationMinutes;
      nextValue.status = "present";
    }

    if (!attendanceSnap.exists) {
      nextValue.userId = userId;
      nextValue.userName = userName;
      nextValue.date = date;
      nextValue.createdAt = admin.firestore.FieldValue.serverTimestamp();
      if (!Object.prototype.hasOwnProperty.call(nextValue, "sessions")) {
        nextValue.sessions = [];
      }
      if (!Object.prototype.hasOwnProperty.call(nextValue, "totalDurationMinutes")) {
        nextValue.totalDurationMinutes = 0;
      }
      if (!Object.prototype.hasOwnProperty.call(nextValue, "status")) {
        nextValue.status = "absent";
      }
    }

    txn.set(attendanceRef, nextValue, {merge: true});
    txn.set(logRef, {
      attendanceId: docId,
      userId,
      action: "admin_correction",
      performedBy: adminUid,
      performedByName: adminName,
      previousValue,
      newValue: {
        sessions: nextValue.sessions,
        ...(nextValue.notes !== undefined ? {notes: nextValue.notes} : {}),
        isCorrected: true,
        correctedBy: adminUid,
      },
      performedAt: admin.firestore.FieldValue.serverTimestamp(),
    });
  });

  return {success: true, docId};
});

exports.adminResetAttendance = onCall(async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "User must be logged in");
  }

  const adminUid = request.auth.uid;
  const db = admin.firestore();

  const adminDoc = await db.collection("users").doc(adminUid).get();
  if (!adminDoc.exists || (adminDoc.data() || {}).role !== "admin") {
    throw new HttpsError(
        "permission-denied",
        "Only admins can reset attendance",
    );
  }

  const adminName = (adminDoc.data() || {}).name || "Admin";
  const userId = request.data && request.data.userId;
  const date = request.data && request.data.date;
  const reason =
    request.data && request.data.reason !== undefined ?
      String(request.data.reason) :
      "Day reset by admin";

  if (!userId || !date) {
    throw new HttpsError(
        "invalid-argument",
        "Missing required fields: userId and date",
    );
  }

  if (!/^\d{4}-\d{2}-\d{2}$/.test(date)) {
    throw new HttpsError("invalid-argument", "Invalid date format");
  }

  const userDoc = await db.collection("users").doc(userId).get();
  if (!userDoc.exists) {
    throw new HttpsError("not-found", "Target user not found");
  }
  const userName = (userDoc.data() || {}).name || "Unknown";

  // Determine the weekday of the target date (Mon=1 … Sun=7, matching Dart).
  const parsedDate = new Date(date);
  const jsDay = parsedDate.getUTCDay(); // 0=Sun … 6=Sat
  const dayKey = jsDay === 0 ? "7" : String(jsDay);

  let newStatus = "absent";
  const scheduleDoc = await db.collection("schedules").doc(userId).get();
  if (scheduleDoc.exists) {
    const dayEntry = (scheduleDoc.data().days || {})[dayKey];
    if (dayEntry && dayEntry.isWorkingDay === false) {
      newStatus = "off_day";
    }
  }

  const docId = `${userId}_${date}`;
  const attendanceRef = db.collection("attendance").doc(docId);
  const logRef = db.collection("attendance_logs").doc();

  await db.runTransaction(async (txn) => {
    const attendanceSnap = await txn.get(attendanceRef);
    const previousStatus = attendanceSnap.exists ?
      (attendanceSnap.data().status || null) :
      null;
    const previousSessions = attendanceSnap.exists ?
      (attendanceSnap.data().sessions || []) :
      [];

    const resetValue = {
      userId,
      userName,
      date,
      status: newStatus,
      sessions: [],
      totalDurationMinutes: 0,
      isCorrected: true,
      correctedBy: adminUid,
      correctedByName: adminName,
      correctedAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      notes: reason,
    };

    if (!attendanceSnap.exists) {
      resetValue.createdAt = admin.firestore.FieldValue.serverTimestamp();
    }

    txn.set(attendanceRef, resetValue);
    txn.set(logRef, {
      attendanceId: docId,
      userId,
      action: "admin_reset",
      performedBy: adminUid,
      performedByName: adminName,
      previousStatus,
      previousSessions,
      newStatus,
      notes: reason,
      performedAt: admin.firestore.FieldValue.serverTimestamp(),
    });
  });

  return {success: true, docId, newStatus};
});

exports.sendDailyAbsenceMarker = onSchedule(
    {
      schedule: "0 23 * * *",
      timeZone: "Asia/Jerusalem",
    },
    async () => {
      try {
        const db = admin.firestore();
        const now = new Date();
        const today = ymdInJerusalem(now);
        const todayDayOfWeek = jerusalemDayOfWeek(now);

        const employeesSnapshot = await db
            .collection("users")
            .where("isActive", "==", true)
            .where("role", "==", "employee")
            .get();

        for (const employeeDoc of employeesSnapshot.docs) {
          const employee = employeeDoc.data() || {};
          const userId = employeeDoc.id;
          const userName = employee.name || "Unknown";
          const attendanceId = `${userId}_${today}`;
          const attendanceRef = db.collection("attendance").doc(attendanceId);
          const attendanceSnap = await attendanceRef.get();
          const sessions =
          attendanceSnap.exists && Array.isArray(attendanceSnap.data().sessions) ?
            attendanceSnap.data().sessions :
            [];

          if (sessions.length > 0) {
            // Employee already has sessions — leave the doc untouched.
            continue;
          }

          // Read the employee's schedule to decide absent vs off_day.
          let markerStatus = "absent";
          try {
            const scheduleDoc = await db.collection("schedules").doc(userId).get();
            if (scheduleDoc.exists) {
              const scheduleData = scheduleDoc.data() || {};
              const days = scheduleData.days || {};
              const daySchedule = days[String(todayDayOfWeek)];
              if (daySchedule && !daySchedule.isWorkingDay) {
                markerStatus = "off_day";
              }
            }
          } catch (scheduleErr) {
            console.warn(`Could not read schedule for ${userId}, defaulting to absent:`, scheduleErr);
          }

          const markerDoc = {
            userId,
            userName,
            date: today,
            status: markerStatus,
            isCorrected: false,
            totalDurationMinutes: 0,
            sessions: [],
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
          };

          if (!attendanceSnap.exists) {
            markerDoc.createdAt = admin.firestore.FieldValue.serverTimestamp();
          }

          await attendanceRef.set(markerDoc, {merge: true});
        }
      } catch (error) {
        console.error("Error running daily absence marker:", error);
      }
    },
);
