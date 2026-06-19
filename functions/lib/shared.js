const admin = require("firebase-admin");

// ─── i18n ─────────────────────────────────────────────────────────────────────

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
    chat_group_message_body: "{senderName}: {messageText}",
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
    chat_group_message_body: "{senderName}: {messageText}",
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

// ─── Notification + FCM helpers ───────────────────────────────────────────────

async function createInAppNotification({userId, type, taskId, conversationId, data}) {
  if (!userId) return;

  await admin
      .firestore()
      .collection("notifications")
      .add({
        userId,
        type,
        taskId: taskId || null,
        conversationId: conversationId || null,
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

module.exports = {
  i18n,
  localize,
  ymdInJerusalem,
  jerusalemOffsetForDate,
  jerusalemMidnightAsUTC,
  sameDayJerusalem,
  jerusalemDayOfWeek,
  jerusalemDayOfMonth,
  jerusalemHHMMMinutes,
  jerusalemLastDayOfMonth,
  checkInStatusForSchedule,
  shouldGenerateOn,
  getFcmToken,
  getFcmTokensBatch,
  createInAppNotification,
  sendFCMNotification,
};
