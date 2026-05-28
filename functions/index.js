const {onCall, HttpsError} = require("firebase-functions/https");
const {onDocumentCreated} = require("firebase-functions/v2/firestore");
const {onDocumentUpdated} = require("firebase-functions/v2/firestore");
const {onSchedule} = require("firebase-functions/v2/scheduler");
const admin = require("firebase-admin");

admin.initializeApp();

const i18n = {
  en: {
    task_assigned_title: "New Task Assigned",
    task_assigned_body: "{by} assigned you: {task}",
    task_completed_title: "Task Completed ✅",
    task_completed_body: "{task}",
    task_deadline_title: "Task Reminder ⏰",
    task_deadline_today_body: "Your task is due today: {task}",
    task_deadline_72h_body: "Your task '{taskTitle}' is due in 3 days.",
    task_deadline_tomorrow_body: "Your task is due tomorrow: {task}",
    task_overdue_title: "Overdue Task ⚠️",
    task_overdue_body: "Your task is overdue: {task}",
    task_overdue_escalation_title: "Overdue Task Escalation 🚨",
    task_overdue_escalation_body: "{employee}'s task is overdue: {task}",
  },
  ar: {
    task_assigned_title: "تم إسناد مهمة جديدة",
    task_assigned_body: "{by} أسند إليك: {task}",
    task_completed_title: "تم إنجاز المهمة ✅",
    task_completed_body: "{task}",
    task_deadline_title: "تذكير بالمهمة ⏰",
    task_deadline_today_body: "مهمتك مستحقة اليوم: {task}",
    task_deadline_72h_body: "مهمتك '{taskTitle}' تستحق خلال 3 أيام.",
    task_deadline_tomorrow_body: "مهمتك مستحقة غداً: {task}",
    task_overdue_title: "مهمة متأخرة ⚠️",
    task_overdue_body: "مهمتك متأخرة: {task}",
    task_overdue_escalation_title: "تصعيد مهمة متأخرة 🚨",
    task_overdue_escalation_body: "مهمة {employee} متأخرة: {task}",
  },
};

function localize(key, args, languageCode) {
  const lang = languageCode === "ar" ? i18n.ar : i18n.en;
  const template = lang[key] || i18n.en[key] || "";
  return template.replace(/\{(\w+)\}/g, (_, k) =>
    args && args[k] != null ? args[k] : "",
  );
}

// ─── Asia/Jerusalem helpers ───────────────────────────────────────────────────

function ymdInJerusalem(date) {
  // Returns "YYYY-MM-DD" in Asia/Jerusalem wall-clock.
  const formatter = new Intl.DateTimeFormat("en-CA", {
    timeZone: "Asia/Jerusalem",
    year: "numeric",
    month: "2-digit",
    day: "2-digit",
  });
  return formatter.format(date); // en-CA gives ISO-like YYYY-MM-DD
}

function jerusalemOffsetForDate(date) {
  // Compute Asia/Jerusalem UTC offset for the given date as ±HH:MM.
  const tzFormatter = new Intl.DateTimeFormat("en-US", {
    timeZone: "Asia/Jerusalem",
    timeZoneName: "longOffset",
  });
  const parts = tzFormatter.formatToParts(date);
  const tz = parts.find((p) => p.type === "timeZoneName").value; // e.g. "GMT+3"
  const match = tz.match(/GMT([+-])(\d{1,2})(?::?(\d{2}))?/);
  if (!match) return "+00:00";
  const sign = match[1];
  const hh = match[2].padStart(2, "0");
  const mm = (match[3] || "00").padStart(2, "0");
  return `${sign}${hh}:${mm}`;
}

function jerusalemMidnightAsUTC(date) {
  // Returns the JS Date representing 00:00 Asia/Jerusalem on date's calendar day.
  const ymd = ymdInJerusalem(date);
  const offset = jerusalemOffsetForDate(date); // e.g. "+03:00"
  return new Date(`${ymd}T00:00:00${offset}`);
}

function sameDayJerusalem(a, b) {
  return ymdInJerusalem(a) === ymdInJerusalem(b);
}

function jerusalemDayOfWeek(date) {
  // 1=Mon ... 7=Sun (matches Dart DateTime.weekday).
  const formatter = new Intl.DateTimeFormat("en-US", {
    timeZone: "Asia/Jerusalem",
    weekday: "short",
  });
  const map = {Mon: 1, Tue: 2, Wed: 3, Thu: 4, Fri: 5, Sat: 6, Sun: 7};
  return map[formatter.format(date)];
}

function jerusalemDayOfMonth(date) {
  const formatter = new Intl.DateTimeFormat("en-CA", {
    timeZone: "Asia/Jerusalem",
    day: "numeric",
  });
  return parseInt(formatter.format(date), 10);
}

function jerusalemHHMMMinutes(date) {
  const formatter = new Intl.DateTimeFormat("en-US", {
    timeZone: "Asia/Jerusalem",
    hour: "2-digit",
    minute: "2-digit",
    hour12: false,
  });
  const [h, m] = formatter.format(date).split(":").map(Number);
  return h * 60 + m;
}

// Returns "present" | "late" | "off_day_work" based on the employee's schedule.
// scheduleData is the raw Firestore doc data (or null if no schedule doc exists).
// dayOfWeek is 1=Mon … 7=Sun (matches Dart DateTime.weekday / jerusalemDayOfWeek).
function checkInStatusForSchedule(scheduleData, now, dayOfWeek) {
  if (!scheduleData) return "present";
  const days = scheduleData.days || {};
  const daySchedule = days[String(dayOfWeek)];
  if (!daySchedule) return "present";
  if (!daySchedule.isWorkingDay) return "off_day_work";
  if (daySchedule.expectedStartTime) {
    const grace = daySchedule.graceMinutes != null ?
      daySchedule.graceMinutes :
      (scheduleData.defaultGraceMinutes != null ? scheduleData.defaultGraceMinutes : 15);
    const [startH, startM] = daySchedule.expectedStartTime.split(":").map(Number);
    const deadlineMinutes = startH * 60 + startM + grace;
    if (jerusalemHHMMMinutes(now) > deadlineMinutes) return "late";
  }
  return "present";
}

function jerusalemLastDayOfMonth(date) {
  // Last calendar day of the month containing `date` in Asia/Jerusalem.
  const ymd = ymdInJerusalem(date); // "YYYY-MM-DD"
  const [y, m] = ymd.split("-").map(Number);
  // JS Date with day=0 of the next month gives the last day of month m.
  return new Date(Date.UTC(y, m, 0)).getUTCDate();
}

// ─── FCM token helpers ────────────────────────────────────────────────────────
// Tokens are stored in fcm_tokens/{userId}.token, not on the users document,
// so clients cannot read each other's FCM tokens. Admin SDK bypasses rules.

async function getFcmToken(db, userId) {
  const doc = await db.collection("fcm_tokens").doc(userId).get();
  return doc.exists ? (doc.data().token || null) : null;
}

async function getFcmTokensBatch(db, userIds) {
  if (userIds.length === 0) return {};
  const refs = userIds.map((id) => db.collection("fcm_tokens").doc(id));
  const docs = await db.getAll(...refs);
  const result = {};
  docs.forEach((doc) => {
    result[doc.id] = doc.exists ? (doc.data().token || null) : null;
  });
  return result;
}

function shouldGenerateOn(recurrence, now) {
  if (!recurrence || typeof recurrence !== "object") return false;
  const type = recurrence.type;
  if (type === "daily") return true;

  if (type === "weekly") {
    const days = recurrence.daysOfWeek;
    if (!Array.isArray(days) || days.length === 0) return false;
    return days.includes(jerusalemDayOfWeek(now));
  }

  if (type === "monthly") {
    const dayOfMonth = recurrence.dayOfMonth;
    if (typeof dayOfMonth !== "number" || dayOfMonth < 1 || dayOfMonth > 31) {
      return false;
    }
    const lastDay = jerusalemLastDayOfMonth(now);
    const targetDay = Math.min(dayOfMonth, lastDay); // monthly clamp
    return jerusalemDayOfMonth(now) === targetDay;
  }

  return false;
}

// ─── Recurring task instance generator ───────────────────────────────────────

exports.generateRecurringTaskInstances = onSchedule(
    {
      schedule: "0 6 * * *",
      timeZone: "Asia/Jerusalem",
    },
    async () => {
      try {
        const db = admin.firestore();
        const now = new Date();
        const todayYMD = ymdInJerusalem(now);
        const todayDueDate = jerusalemMidnightAsUTC(now);

        const snap = await db
            .collection("task_templates")
            .where("isActive", "==", true)
            .get();

        for (const templateDoc of snap.docs) {
          try {
            const template = templateDoc.data();
            if (!shouldGenerateOn(template.recurrence, now)) continue;

            // Support both legacy single-assignee and new multi-assignee templates.
            const assigneeIds =
            Array.isArray(template.assignedToIds) &&
            template.assignedToIds.length > 0 ?
              template.assignedToIds :
              template.assignedTo ?
                [template.assignedTo] :
                [];
            const assigneeNames =
            Array.isArray(template.assignedToNames) &&
            template.assignedToNames.length > 0 ?
              template.assignedToNames :
              template.assignedToName ?
                [template.assignedToName] :
                [];

            if (assigneeIds.length === 0) continue;

            for (let i = 0; i < assigneeIds.length; i++) {
              const assigneeId = assigneeIds[i];
              const assigneeName = assigneeNames[i] || "";
              // One instance per (template, assignee, date) — deterministic ID is
              // the sole idempotency gate; existence check is inside the transaction.
              const instanceId = `${templateDoc.id}_${assigneeId}_${todayYMD}`;
              const instanceRef = db.collection("tasks").doc(instanceId);

              await db.runTransaction(async (txn) => {
                const freshTemplate = await txn.get(templateDoc.ref);
                if (!freshTemplate.exists) return;
                const freshData = freshTemplate.data() || {};
                if (freshData.isActive !== true) return;

                const existingInstance = await txn.get(instanceRef);
                if (existingInstance.exists) return; // already generated

                const instance = {
                  title: freshData.title || "",
                  description: freshData.description || "",
                  assignedTo: assigneeId,
                  assignedToName: assigneeName,
                  assignedBy: freshData.assignedBy || "",
                  assignedByName: freshData.assignedByName || "",
                  priority: freshData.priority || "medium",
                  status: "pending",
                  taskType: freshData.taskType || "standard",
                  currentCount: 0,
                  dueDate: admin.firestore.Timestamp.fromDate(todayDueDate),
                  createdAt: admin.firestore.Timestamp.fromDate(now),
                  updatedAt: admin.firestore.Timestamp.fromDate(now),
                  completedAt: null,
                  templateId: templateDoc.id,
                };
                if (freshData.taskType === "counter" && freshData.targetCount) {
                  instance.targetCount = freshData.targetCount;
                }

                txn.set(instanceRef, instance);
              });
            }

            // lastGeneratedAt is metadata only — written after all assignees are
            // processed so a partial-run crash leaves it unset for the next retry.
            await templateDoc.ref.update({
              lastGeneratedAt: admin.firestore.Timestamp.fromDate(now),
              updatedAt: admin.firestore.Timestamp.fromDate(now),
            });
          } catch (templateError) {
            console.error(
                `Error processing template ${templateDoc.id}:`,
                templateError,
            );
            // Alert all admins in-app so template failures surface beyond logs.
            try {
              const adminsSnap = await db
                  .collection("users")
                  .where("role", "==", "admin")
                  .get();
              await Promise.all(
                  adminsSnap.docs.map((adminDoc) =>
                    createInAppNotification({
                      userId: adminDoc.id,
                      type: "recurring_template_error",
                      taskId: null,
                      data: {
                        templateId: templateDoc.id,
                        error: templateError.message || "Unknown error",
                      },
                    }),
                  ),
              );
            } catch (alertError) {
              console.error(
                  "Failed to send template-error admin alert:",
                  alertError,
              );
            }
          }
        }
      } catch (error) {
        console.error("Error generating recurring task instances:", error);
      }
    },
);

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

exports.createEmployeeUser = onCall(async (request) => {
  try {
    // 🔐 تحقق أن المستخدم مسجل دخول
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "User must be logged in");
    }

    const {email, password, name, role} = request.data;

    // 🧠 تحقق من البيانات
    if (!email || !password || !name || !role) {
      throw new HttpsError("invalid-argument", "Missing required fields");
    }

    if (!["admin", "employee"].includes(role)) {
      throw new HttpsError(
          "invalid-argument",
          "role must be 'admin' or 'employee'",
      );
    }

    const db = admin.firestore();

    // 🔐 تحقق أن المستخدم Admin
    const currentUserDoc = await db
        .collection("users")
        .doc(request.auth.uid)
        .get();

    if (!currentUserDoc.exists) {
      throw new HttpsError(
          "permission-denied",
          "Current user record not found",
      );
    }

    const currentUserData = currentUserDoc.data();

    if (!currentUserData || currentUserData.role !== "admin") {
      throw new HttpsError(
          "permission-denied",
          "Only admins can create employees",
      );
    }

    // 🔥 إنشاء المستخدم في Firebase Auth
    const userRecord = await admin.auth().createUser({
      email,
      password,
      displayName: name,
    });

    // 🔥 إنشاء document في Firestore
    await db.collection("users").doc(userRecord.uid).set({
      email,
      name,
      role,
      isActive: true,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    return {
      success: true,
      uid: userRecord.uid,
    };
  } catch (error) {
    console.error("Error creating employee:", error);

    if (error instanceof HttpsError) {
      throw error;
    }

    throw new HttpsError("internal", error.message || "Something went wrong");
  }
});

exports.sendTaskAssignedNotification = onDocumentCreated(
    "tasks/{taskId}",
    async (event) => {
      try {
        const snapshot = event.data;

        if (!snapshot) {
          console.log("No task data found.");
          return;
        }

        const task = snapshot.data();
        const db = admin.firestore();

        const assignedTo = task.assignedTo;
        const assignedBy = task.assignedBy;
        const taskTitle = task.title || "New Task";

        if (!assignedTo) {
          console.log("No assignedTo found in task.");
          return;
        }

        const assignedUserDoc = await db
            .collection("users")
            .doc(assignedTo)
            .get();

        if (!assignedUserDoc.exists) {
          console.log("Assigned user not found.");
          return;
        }

        const assignedUserData = assignedUserDoc.data() || {};
        const fcmToken = await getFcmToken(db, assignedTo);
        const languageCode = assignedUserData.languageCode || "en";

        if (!fcmToken) {
          console.log("Assigned user has no FCM token.");
          return;
        }

        let assignedByName = "Someone";
        if (assignedBy) {
          const assignedByDoc = await db
              .collection("users")
              .doc(assignedBy)
              .get();
          if (assignedByDoc.exists) {
            const assignedByData = assignedByDoc.data();
            assignedByName = (assignedByData && assignedByData.name) || "Someone";
          }
        }

        const message = {
          token: fcmToken,
          notification: {
            title: localize("task_assigned_title", {}, languageCode),
            body: localize(
                "task_assigned_body",
                {by: assignedByName, task: taskTitle},
                languageCode,
            ),
          },
          data: {
            taskId: event.params.taskId,
            type: "task_assigned",
            click_action: "FLUTTER_NOTIFICATION_CLICK",
          },
          android: {
            priority: "high",
            notification: {
              channelId: "task_notifications",
            },
          },
        };

        const response = await admin.messaging().send(message);
        console.log("Successfully sent notification:", response);

        await db.collection("task_logs").add({
          taskId: event.params.taskId,
          taskTitle: task.title || "",
          action: "created",
          newStatus: task.status || "pending",
          performedBy: assignedBy || null,
          performedByName: assignedByName,
          performedAt: admin.firestore.FieldValue.serverTimestamp(),
        });

        await createInAppNotification({
          userId: assignedTo,
          type: "task_assigned",
          taskId: event.params.taskId,
          data: {
            taskTitle: taskTitle,
            assignedByName: assignedByName,
          },
        });
      } catch (error) {
        console.error("Error sending task notification:", error);
      }
    },
);

exports.sendTaskStatusNotification = onDocumentUpdated(
    "tasks/{taskId}",
    async (event) => {
      const before = event.data.before.data();
      const after = event.data.after.data();

      const currentUserId = after.updatedBy || null;
      const currentUserName = after.updatedByName || "Unknown";

      console.log("Task status update trigger fired");
      console.log("Before status:", before.status);
      console.log("After status:", after.status);

      if (before.status === after.status) return;

      const db = admin.firestore();

      if (after.status === "completed") {
        const assignedById = after.assignedBy;

        const adminsSnapshot = await db
            .collection("users")
            .where("role", "==", "admin")
            .get();

        const adminUserIds = new Set();

        adminsSnapshot.forEach((doc) => {
          adminUserIds.add(doc.id);
        });

        if (assignedById && assignedById !== currentUserId) {
          adminUserIds.add(assignedById);
        }

        for (const userId of adminUserIds) {
          const recipientDoc = await db.collection("users").doc(userId).get();
          const recipientData = recipientDoc.data() || {};
          const recipientToken = await getFcmToken(db, userId);
          const languageCode = recipientData.languageCode || "en";

          if (recipientToken) {
            await admin.messaging().send({
              token: recipientToken,
              notification: {
                title: localize("task_completed_title", {}, languageCode),
                body: localize(
                    "task_completed_body",
                    {task: after.title || ""},
                    languageCode,
                ),
              },
              data: {
                taskId: event.params.taskId,
              },
            });
          }
        }

        for (const userId of adminUserIds) {
          await createInAppNotification({
            userId: userId,
            type: "task_completed",
            taskId: event.params.taskId,
            data: {
              taskTitle: after.title || "",
              performedByName: currentUserName,
            },
          });
        }
      }

      console.log("Writing task log for task:", event.params.taskId);

      await db.collection("task_logs").add({
        taskId: event.params.taskId,
        taskTitle: after.title || "",
        action: "status_changed",
        previousStatus: before.status || null,
        newStatus: after.status || null,
        performedBy: currentUserId,
        performedByName: currentUserName,
        performedAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      console.log("Task log written successfully");
    },
);

exports.sendTaskDeadlineReminders = onSchedule(
    {
      schedule: "0 9 * * *",
      timeZone: "Asia/Jerusalem",
    },
    async () => {
      try {
        const db = admin.firestore();

        const now = new Date();
        const todayYmd = ymdInJerusalem(now);
        const [year, month, day] = todayYmd.split("-").map(Number);

        const jerusalemDay = (offsetDays) =>
          new Date(Date.UTC(year, month - 1, day + offsetDays, 12, 0, 0));

        const in72hStart = jerusalemMidnightAsUTC(jerusalemDay(3));
        const in72hEnd = jerusalemMidnightAsUTC(jerusalemDay(4));

        const in24hStart = jerusalemMidnightAsUTC(jerusalemDay(1));
        const in24hEnd = jerusalemMidnightAsUTC(jerusalemDay(2));

        const [snap72h, snap24h] = await Promise.all([
          db
              .collection("tasks")
              .where("status", "!=", "completed")
              .where(
                  "dueDate",
                  ">=",
                  admin.firestore.Timestamp.fromDate(in72hStart),
              )
              .where("dueDate", "<", admin.firestore.Timestamp.fromDate(in72hEnd))
              .get(),
          db
              .collection("tasks")
              .where("status", "!=", "completed")
              .where(
                  "dueDate",
                  ">=",
                  admin.firestore.Timestamp.fromDate(in24hStart),
              )
              .where("dueDate", "<", admin.firestore.Timestamp.fromDate(in24hEnd))
              .get(),
        ]);

        const processThreshold = async ({
          snapshot,
          dedupField,
          bodyKey,
          bodyArgs,
        }) => {
          for (const taskDoc of snapshot.docs) {
            try {
              const task = taskDoc.data();
              const taskId = taskDoc.id;
              const assignedTo = task.assignedTo;
              const taskTitle = task.title || "Task";

              if (!assignedTo) {
                continue;
              }

              const sentAt = task[dedupField];
              if (
                sentAt &&
              typeof sentAt.toDate === "function" &&
              sameDayJerusalem(sentAt.toDate(), now)
              ) {
                continue;
              }

              const userDoc = await db.collection("users").doc(assignedTo).get();
              if (!userDoc.exists) {
                continue;
              }

              const userData = userDoc.data() || {};
              if (userData.isActive === false) {
                continue;
              }

              const languageCode = userData.languageCode || "en";
              const fcmToken = await getFcmToken(db, assignedTo);

              await sendFCMNotification({
                token: fcmToken,
                notification: {
                  title: localize("task_deadline_title", {}, languageCode),
                  body: localize(bodyKey, bodyArgs(taskTitle), languageCode),
                },
                data: {
                  taskId,
                  type: "task_deadline_reminder",
                },
                android: {
                  priority: "high",
                  notification: {
                    channelId: "task_notifications",
                  },
                },
                apns: {
                  payload: {
                    aps: {
                      sound: "default",
                    },
                  },
                },
              });

              await createInAppNotification({
                userId: assignedTo,
                type: "task_deadline_reminder",
                taskId,
                data: {
                  taskTitle,
                },
              });

              await db
                  .collection("tasks")
                  .doc(taskId)
                  .update({
                    [dedupField]: admin.firestore.FieldValue.serverTimestamp(),
                  });
            } catch (taskError) {
              console.error("Error processing deadline reminder task:", {
                taskId: taskDoc.id,
                dedupField,
                error: taskError,
              });
            }
          }
        };

        await processThreshold({
          snapshot: snap72h,
          dedupField: "reminderSent72hAt",
          bodyKey: "task_deadline_72h_body",
          bodyArgs: (taskTitle) => ({taskTitle}),
        });

        await processThreshold({
          snapshot: snap24h,
          dedupField: "reminderSent24hAt",
          bodyKey: "task_deadline_tomorrow_body",
          bodyArgs: (taskTitle) => ({task: taskTitle}),
        });
      } catch (error) {
        console.error("Error sending deadline reminders:", error);
      }
    },
);
exports.testTaskDeadlineReminders = onCall(async (request) => {
  try {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "User must be logged in");
    }

    const db = admin.firestore();

    const currentUserDoc = await db
        .collection("users")
        .doc(request.auth.uid)
        .get();

    if (!currentUserDoc.exists) {
      throw new HttpsError(
          "permission-denied",
          "Current user record not found",
      );
    }

    const currentUserData = currentUserDoc.data();

    if (!currentUserData || currentUserData.role !== "admin") {
      throw new HttpsError(
          "permission-denied",
          "Only admins can test reminders",
      );
    }

    const now = new Date();
    const start = new Date(
        now.getFullYear(),
        now.getMonth(),
        now.getDate(),
        0,
        0,
        0,
        0,
    );
    const end = new Date(
        now.getFullYear(),
        now.getMonth(),
        now.getDate() + 1,
        0,
        0,
        0,
        0,
    );

    const tasksSnapshot = await db
        .collection("tasks")
        .where("status", "!=", "completed")
        .where("dueDate", ">=", admin.firestore.Timestamp.fromDate(start))
        .where("dueDate", "<", admin.firestore.Timestamp.fromDate(end))
        .get();

    if (tasksSnapshot.empty) {
      return {
        success: true,
        message: "No tasks due today.",
        sentCount: 0,
      };
    }

    let sentCount = 0;

    for (const doc of tasksSnapshot.docs) {
      const task = doc.data();
      const assignedTo = task.assignedTo;
      const taskTitle = task.title || "Task";

      if (!assignedTo) continue;

      const userDoc = await db.collection("users").doc(assignedTo).get();
      if (!userDoc.exists) continue;

      const userData = userDoc.data() || {};
      const fcmToken = await getFcmToken(db, assignedTo);
      const languageCode = userData.languageCode || "en";

      if (!fcmToken) continue;

      await admin.messaging().send({
        token: fcmToken,
        notification: {
          title: localize("task_deadline_title", {}, languageCode),
          body: localize(
              "task_deadline_today_body",
              {task: taskTitle},
              languageCode,
          ),
        },
        data: {
          taskId: doc.id,
          type: "task_deadline_reminder",
        },
        android: {
          priority: "high",
          notification: {
            channelId: "task_notifications",
          },
        },
        apns: {
          payload: {
            aps: {
              sound: "default",
            },
          },
        },
      });

      sentCount++;
    }

    return {
      success: true,
      message: "Reminder test completed.",
      sentCount,
    };
  } catch (error) {
    console.error("Error testing deadline reminders:", error);

    if (error instanceof HttpsError) {
      throw error;
    }

    throw new HttpsError("internal", error.message || "Something went wrong");
  }
});

exports.sendOverdueTaskEscalations = onSchedule(
    {
      schedule: "0 10 * * *",
      timeZone: "Asia/Jerusalem",
    },
    async () => {
      try {
        const db = admin.firestore();

        const now = new Date();
        const nowTimestamp = admin.firestore.Timestamp.fromDate(now);

        const tasksSnapshot = await db
            .collection("tasks")
            .where("status", "!=", "completed")
            .where("dueDate", "<", nowTimestamp)
            .get();

        if (tasksSnapshot.empty) {
          console.log("No overdue tasks found.");
          return;
        }

        const adminsSnapshot = await db
            .collection("users")
            .where("role", "==", "admin")
            .get();

        const adminIds = adminsSnapshot.docs.map((doc) => doc.id);
        const adminTokenMap = await getFcmTokensBatch(db, adminIds);

        for (const doc of tasksSnapshot.docs) {
          const task = doc.data();
          const taskId = doc.id;

          const assignedTo = task.assignedTo;
          const assignedToName = task.assignedToName || "Employee";
          const taskTitle = task.title || "Task";

          const lastReminderAt = task.lastOverdueReminderAt ?
          task.lastOverdueReminderAt.toDate() :
          null;

          const lastEscalationAt = task.lastOverdueEscalationAt ?
          task.lastOverdueEscalationAt.toDate() :
          null;

          const sameDayReminder =
          lastReminderAt && sameDayJerusalem(lastReminderAt, now);

          const sameDayEscalation =
          lastEscalationAt && sameDayJerusalem(lastEscalationAt, now);

          let employeeNotified = false;
          let adminsNotified = false;

          // 1) Notify assigned employee
          if (assignedTo && !sameDayReminder) {
            const userDoc = await db.collection("users").doc(assignedTo).get();

            if (userDoc.exists) {
              const userData = userDoc.data() || {};
              const employeeToken = await getFcmToken(db, assignedTo);
              const languageCode = userData.languageCode || "en";

              if (employeeToken) {
                await admin.messaging().send({
                  token: employeeToken,
                  notification: {
                    title: localize("task_overdue_title", {}, languageCode),
                    body: localize(
                        "task_overdue_body",
                        {task: taskTitle},
                        languageCode,
                    ),
                  },
                  data: {
                    taskId: taskId,
                    type: "task_overdue_reminder",
                  },
                  android: {
                    priority: "high",
                    notification: {
                      channelId: "task_notifications",
                    },
                  },
                  apns: {
                    payload: {
                      aps: {
                        sound: "default",
                      },
                    },
                  },
                });

                employeeNotified = true;
              }
            }
          }

          await createInAppNotification({
            userId: assignedTo,
            type: "task_overdue_reminder",
            taskId: taskId,
            data: {
              taskTitle: taskTitle,
            },
          });

          // 2) Notify admins
          if (adminIds.length > 0 && !sameDayEscalation) {
            let sentToAnyAdmin = false;

            for (const adminDoc of adminsSnapshot.docs) {
              const adminToken = adminTokenMap[adminDoc.id];
              const adminData = adminDoc.data() || {};
              const languageCode = adminData.languageCode || "en";

              if (!adminToken) {
                continue;
              }

              await admin.messaging().send({
                token: adminToken,
                notification: {
                  title: localize(
                      "task_overdue_escalation_title",
                      {},
                      languageCode,
                  ),
                  body: localize(
                      "task_overdue_escalation_body",
                      {employee: assignedToName, task: taskTitle},
                      languageCode,
                  ),
                },
                data: {
                  taskId: taskId,
                  type: "task_overdue_escalation",
                },
              });

              sentToAnyAdmin = true;
            }

            adminsNotified = sentToAnyAdmin;
          }

          for (const adminDoc of adminsSnapshot.docs) {
            await createInAppNotification({
              userId: adminDoc.id,
              type: "task_overdue_escalation",
              taskId: taskId,
              data: {
                taskTitle: taskTitle,
                assignedToName: assignedToName,
              },
            });
          }

          const updateData = {};

          if (employeeNotified) {
            updateData.lastOverdueReminderAt =
            admin.firestore.FieldValue.serverTimestamp();
          }

          if (adminsNotified) {
            updateData.lastOverdueEscalationAt =
            admin.firestore.FieldValue.serverTimestamp();
          }

          if (employeeNotified || adminsNotified) {
            await db.collection("tasks").doc(taskId).update(updateData);

            await db.collection("task_logs").add({
              taskId: taskId,
              taskTitle: task.title || "",
              action: "overdue_escalation",
              previousStatus: task.status || null,
              newStatus: task.status || null,
              performedBy: null,
              performedByName: "System",
              performedAt: admin.firestore.FieldValue.serverTimestamp(),
            });
          }
        }

        console.log("Overdue escalation job completed.");
      } catch (error) {
        console.error("Error sending overdue escalations:", error);
      }
    },
);

exports.testOverdueTaskEscalations = onCall(async (request) => {
  try {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "User must be logged in");
    }

    const db = admin.firestore();

    const currentUserDoc = await db
        .collection("users")
        .doc(request.auth.uid)
        .get();

    if (!currentUserDoc.exists) {
      throw new HttpsError(
          "permission-denied",
          "Current user record not found",
      );
    }

    const currentUserData = currentUserDoc.data();

    if (!currentUserData || currentUserData.role !== "admin") {
      throw new HttpsError(
          "permission-denied",
          "Only admins can test escalations",
      );
    }

    const now = new Date();
    const nowTimestamp = admin.firestore.Timestamp.fromDate(now);

    const tasksSnapshot = await db
        .collection("tasks")
        .where("status", "!=", "completed")
        .where("dueDate", "<", nowTimestamp)
        .get();

    if (tasksSnapshot.empty) {
      return {
        success: true,
        message: "No overdue tasks found.",
        sentCount: 0,
      };
    }

    const adminsSnapshot = await db
        .collection("users")
        .where("role", "==", "admin")
        .get();

    const adminIds = adminsSnapshot.docs.map((doc) => doc.id);
    const adminTokenMap = await getFcmTokensBatch(db, adminIds);

    let sentCount = 0;

    for (const doc of tasksSnapshot.docs) {
      const task = doc.data();
      const taskId = doc.id;

      const assignedTo = task.assignedTo;
      const assignedToName = task.assignedToName || "Employee";
      const taskTitle = task.title || "Task";

      if (assignedTo) {
        const userDoc = await db.collection("users").doc(assignedTo).get();
        if (userDoc.exists) {
          const userData = userDoc.data() || {};
          const employeeToken = await getFcmToken(db, assignedTo);
          const languageCode = userData.languageCode || "en";

          if (employeeToken) {
            await admin.messaging().send({
              token: employeeToken,
              notification: {
                title: localize("task_overdue_title", {}, languageCode),
                body: localize(
                    "task_overdue_body",
                    {task: taskTitle},
                    languageCode,
                ),
              },
              data: {
                taskId: taskId,
                type: "task_overdue_reminder",
              },
              android: {
                priority: "high",
                notification: {
                  channelId: "task_notifications",
                },
              },
              apns: {
                payload: {
                  aps: {
                    sound: "default",
                  },
                },
              },
            });

            sentCount++;
          }
        }
      }

      if (adminIds.length > 0) {
        for (const adminDoc of adminsSnapshot.docs) {
          const adminToken = adminTokenMap[adminDoc.id];
          const adminData = adminDoc.data() || {};
          const languageCode = adminData.languageCode || "en";

          if (!adminToken) {
            continue;
          }

          await admin.messaging().send({
            token: adminToken,
            notification: {
              title: localize(
                  "task_overdue_escalation_title",
                  {},
                  languageCode,
              ),
              body: localize(
                  "task_overdue_escalation_body",
                  {employee: assignedToName, task: taskTitle},
                  languageCode,
              ),
            },
            data: {
              taskId: taskId,
              type: "task_overdue_escalation",
            },
          });

          sentCount++;
        }
      }

      await db.collection("task_logs").add({
        taskId: taskId,
        taskTitle: task.title || "",
        action: "overdue_escalation",
        previousStatus: task.status || null,
        newStatus: task.status || null,
        performedBy: null,
        performedByName: "System",
        performedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    }

    return {
      success: true,
      message: "Overdue escalation test completed.",
      sentCount,
    };
  } catch (error) {
    console.error("Error testing overdue escalations:", error);

    if (error instanceof HttpsError) {
      throw error;
    }

    throw new HttpsError("internal", error.message || "Something went wrong");
  }
});

exports.deleteUserAccount = onCall(async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "User must be logged in");
  }

  const uid = request.auth.uid;
  const db = admin.firestore();

  async function batchUpdate(docs, updateFn) {
    const CHUNK = 500;
    for (let i = 0; i < docs.length; i += CHUNK) {
      const batch = db.batch();
      docs
          .slice(i, i + CHUNK)
          .forEach((doc) => batch.update(doc.ref, updateFn(doc)));
      await batch.commit();
    }
  }

  async function batchDelete(docs) {
    const CHUNK = 500;
    for (let i = 0; i < docs.length; i += CHUNK) {
      const batch = db.batch();
      docs.slice(i, i + CHUNK).forEach((doc) => batch.delete(doc.ref));
      await batch.commit();
    }
  }

  try {
    // Step 1: tasks assigned BY this user → overwrite assignedByName
    const assignedBySnap = await db
        .collection("tasks")
        .where("assignedBy", "==", uid)
        .get();
    if (!assignedBySnap.empty) {
      await batchUpdate(assignedBySnap.docs, () => ({
        assignedByName: "Deleted user",
      }));
    }

    // Step 2: tasks assigned TO this user → overwrite assignedToName
    const assignedToSnap = await db
        .collection("tasks")
        .where("assignedTo", "==", uid)
        .get();
    if (!assignedToSnap.empty) {
      await batchUpdate(assignedToSnap.docs, () => ({
        assignedToName: "Deleted user",
      }));
    }

    // Step 3: notifications belonging to this user → delete
    const notificationsSnap = await db
        .collection("notifications")
        .where("userId", "==", uid)
        .get();
    if (!notificationsSnap.empty) {
      await batchDelete(notificationsSnap.docs);
    }

    // Step 4: user Firestore doc → delete
    await db.collection("users").doc(uid).delete();

    // Step 4.5: FCM token doc → delete
    await db.collection("fcm_tokens").doc(uid).delete().catch(() => {});

    // Step 5: Firebase Auth account → delete (last; if this fails the user can retry)
    await admin.auth().deleteUser(uid);

    return {success: true};
  } catch (error) {
    console.error("Error deleting user account:", error);

    if (error instanceof HttpsError) {
      throw error;
    }

    throw new HttpsError("internal", error.message || "Something went wrong");
  }
});

exports.revokeUserSessions = onCall(async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "User must be logged in");
  }
  try {
    await admin.auth().revokeRefreshTokens(request.auth.uid);
    return {success: true};
  } catch (error) {
    console.error("revokeUserSessions failed", error);
    throw new HttpsError("internal", "Failed to revoke sessions");
  }
});

async function createInAppNotification({userId, type, taskId, data}) {
  if (!userId) return;

  await admin
      .firestore()
      .collection("notifications")
      .add({
        userId,
        type,
        taskId: taskId || null,
        data: data || {},
        isRead: false,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      });
}

async function sendFCMNotification(message) {
  if (!message || !message.token) {
    return;
  }
  await admin.messaging().send(message);
}
