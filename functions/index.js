/* eslint-disable */
const { onCall, HttpsError } = require("firebase-functions/https");
const { onDocumentCreated } = require("firebase-functions/v2/firestore");
const { onDocumentUpdated } = require("firebase-functions/v2/firestore");
const { onSchedule } = require("firebase-functions/v2/scheduler");
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
  const map = { Mon: 1, Tue: 2, Wed: 3, Thu: 4, Fri: 5, Sat: 6, Sun: 7 };
  return map[formatter.format(date)];
}

function jerusalemDayOfMonth(date) {
  const formatter = new Intl.DateTimeFormat("en-CA", {
    timeZone: "Asia/Jerusalem",
    day: "numeric",
  });
  return parseInt(formatter.format(date), 10);
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
            template.assignedToIds.length > 0
              ? template.assignedToIds
              : template.assignedTo
                ? [template.assignedTo]
                : [];
          const assigneeNames =
            Array.isArray(template.assignedToNames) &&
            template.assignedToNames.length > 0
              ? template.assignedToNames
              : template.assignedToName
                ? [template.assignedToName]
                : [];

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
        }
      }
    } catch (error) {
      console.error("Error generating recurring task instances:", error);
    }
  },
);

exports.createEmployeeUser = onCall(async (request) => {
  try {
    // 🔐 تحقق أن المستخدم مسجل دخول
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "User must be logged in");
    }

    const { email, password, name, role } = request.data;

    // 🧠 تحقق من البيانات
    if (!email || !password || !name || !role) {
      throw new HttpsError("invalid-argument", "Missing required fields");
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
      const fcmToken = assignedUserData && assignedUserData.fcmToken;
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
            { by: assignedByName, task: taskTitle },
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
        const recipientToken = recipientData.fcmToken;
        const languageCode = recipientData.languageCode || "en";

        if (recipientToken) {
          await admin.messaging().send({
            token: recipientToken,
            notification: {
              title: localize("task_completed_title", {}, languageCode),
              body: localize(
                "task_completed_body",
                { task: after.title || "" },
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
      const tomorrowStart = new Date(
        now.getFullYear(),
        now.getMonth(),
        now.getDate() + 1,
        0,
        0,
        0,
        0,
      );
      const tomorrowEnd = new Date(
        now.getFullYear(),
        now.getMonth(),
        now.getDate() + 2,
        0,
        0,
        0,
        0,
      );

      const tasksSnapshot = await db
        .collection("tasks")
        .where("status", "!=", "completed")
        .where(
          "dueDate",
          ">=",
          admin.firestore.Timestamp.fromDate(tomorrowStart),
        )
        .where("dueDate", "<", admin.firestore.Timestamp.fromDate(tomorrowEnd))
        .get();

      if (tasksSnapshot.empty) {
        console.log("No tasks due tomorrow.");
        return;
      }

      for (const doc of tasksSnapshot.docs) {
        const task = doc.data();
        const assignedTo = task.assignedTo;
        const taskTitle = task.title || "Task";

        if (!assignedTo) continue;

        const userDoc = await db.collection("users").doc(assignedTo).get();
        if (!userDoc.exists) continue;

        const userData = userDoc.data() || {};
        const fcmToken = userData.fcmToken;
        const languageCode = userData.languageCode || "en";

        if (!fcmToken) continue;

        await admin.messaging().send({
          token: fcmToken,
          notification: {
            title: localize("task_deadline_title", {}, languageCode),
            body: localize(
              "task_deadline_tomorrow_body",
              { task: taskTitle },
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

        await createInAppNotification({
          userId: assignedTo,
          type: "task_deadline_reminder",
          taskId: doc.id,
          data: {
            taskTitle: taskTitle,
          },
        });
        console.log("Reminder sent for task:", doc.id);
      }
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
      const fcmToken = userData.fcmToken;
      const languageCode = userData.languageCode || "en";

      if (!fcmToken) continue;

      await admin.messaging().send({
        token: fcmToken,
        notification: {
          title: localize("task_deadline_title", {}, languageCode),
          body: localize(
            "task_deadline_today_body",
            { task: taskTitle },
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

      const adminTokens = [];
      adminsSnapshot.forEach((doc) => {
        const data = doc.data() || {};
        if (data.fcmToken) {
          adminTokens.push(data.fcmToken);
        }
      });

      for (const doc of tasksSnapshot.docs) {
        const task = doc.data();
        const taskId = doc.id;

        const assignedTo = task.assignedTo;
        const assignedToName = task.assignedToName || "Employee";
        const taskTitle = task.title || "Task";

        const lastReminderAt = task.lastOverdueReminderAt
          ? task.lastOverdueReminderAt.toDate()
          : null;

        const lastEscalationAt = task.lastOverdueEscalationAt
          ? task.lastOverdueEscalationAt.toDate()
          : null;

        const sameDayReminder =
          lastReminderAt &&
          lastReminderAt.getFullYear() === now.getFullYear() &&
          lastReminderAt.getMonth() === now.getMonth() &&
          lastReminderAt.getDate() === now.getDate();

        const sameDayEscalation =
          lastEscalationAt &&
          lastEscalationAt.getFullYear() === now.getFullYear() &&
          lastEscalationAt.getMonth() === now.getMonth() &&
          lastEscalationAt.getDate() === now.getDate();

        let employeeNotified = false;
        let adminsNotified = false;

        // 1) Notify assigned employee
        if (assignedTo && !sameDayReminder) {
          const userDoc = await db.collection("users").doc(assignedTo).get();

          if (userDoc.exists) {
            const userData = userDoc.data() || {};
            const employeeToken = userData.fcmToken;
            const languageCode = userData.languageCode || "en";

            if (employeeToken) {
              await admin.messaging().send({
                token: employeeToken,
                notification: {
                  title: localize("task_overdue_title", {}, languageCode),
                  body: localize(
                    "task_overdue_body",
                    { task: taskTitle },
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
        if (adminTokens.length > 0 && !sameDayEscalation) {
          let sentToAnyAdmin = false;

          for (const adminDoc of adminsSnapshot.docs) {
            const adminUserDoc = await db
              .collection("users")
              .doc(adminDoc.id)
              .get();
            const adminUserData = adminUserDoc.data() || {};
            const adminToken = adminUserData.fcmToken;
            const languageCode = adminUserData.languageCode || "en";

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
                  { employee: assignedToName, task: taskTitle },
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

    const adminTokens = [];
    adminsSnapshot.forEach((doc) => {
      const data = doc.data() || {};
      if (data.fcmToken) {
        adminTokens.push(data.fcmToken);
      }
    });

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
          const employeeToken = userData.fcmToken;
          const languageCode = userData.languageCode || "en";

          if (employeeToken) {
            await admin.messaging().send({
              token: employeeToken,
              notification: {
                title: localize("task_overdue_title", {}, languageCode),
                body: localize(
                  "task_overdue_body",
                  { task: taskTitle },
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

      if (adminTokens.length > 0) {
        for (const adminDoc of adminsSnapshot.docs) {
          const adminUserDoc = await db
            .collection("users")
            .doc(adminDoc.id)
            .get();
          const adminUserData = adminUserDoc.data() || {};
          const adminToken = adminUserData.fcmToken;
          const languageCode = adminUserData.languageCode || "en";

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
                { employee: assignedToName, task: taskTitle },
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

  try {
    // Helper: batch-update documents in chunks of 500
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

    // Helper: batch-delete documents in chunks of 500
    async function batchDelete(docs) {
      const CHUNK = 500;
      for (let i = 0; i < docs.length; i += CHUNK) {
        const batch = db.batch();
        docs.slice(i, i + CHUNK).forEach((doc) => batch.delete(doc.ref));
        await batch.commit();
      }
    }

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

    // Step 5: Firebase Auth account → delete (last; if this fails the user can retry)
    await admin.auth().deleteUser(uid);

    return { success: true };
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
    return { success: true };
  } catch (error) {
    console.error("revokeUserSessions failed", error);
    throw new HttpsError("internal", "Failed to revoke sessions");
  }
});

async function createInAppNotification({ userId, type, taskId, data }) {
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
