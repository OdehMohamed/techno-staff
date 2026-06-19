const {onCall, HttpsError} = require("firebase-functions/https");
const {onDocumentCreated} = require("firebase-functions/v2/firestore");
const {onDocumentUpdated} = require("firebase-functions/v2/firestore");
const {onSchedule} = require("firebase-functions/v2/scheduler");
const admin = require("firebase-admin");
const {
  localize,
  ymdInJerusalem,
  jerusalemMidnightAsUTC,
  sameDayJerusalem,
  getFcmToken,
  getFcmTokensBatch,
  createInAppNotification,
  sendFCMNotification,
} = require("./shared");

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
