/* eslint-disable */
const { onCall, HttpsError } = require("firebase-functions/https");
const { onDocumentCreated } = require("firebase-functions/v2/firestore");
const { onDocumentUpdated } = require("firebase-functions/v2/firestore");
const { onSchedule } = require("firebase-functions/v2/scheduler");
const admin = require("firebase-admin");

admin.initializeApp();

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
          title: "New Task Assigned",
          body: assignedByName + " assigned you: " + taskTitle,
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

      const tokens = new Set();
      const adminUserIds = new Set();

      adminsSnapshot.forEach((doc) => {
        const data = doc.data();

        adminUserIds.add(doc.id);

        if (data.fcmToken) {
          tokens.add(data.fcmToken);
        }
      });

      if (assignedById && assignedById !== currentUserId) {
        const creatorDoc = await db.collection("users").doc(assignedById).get();
        const creatorData = creatorDoc.data();

        if (creatorData && creatorData.fcmToken) {
          tokens.add(creatorData.fcmToken);
        }

        adminUserIds.add(assignedById);
      }

      const tokensList = Array.from(tokens);

      if (tokensList.length > 0) {
        await admin.messaging().sendEachForMulticast({
          tokens: tokensList,
          notification: {
            title: "Task Completed ✅",
            body: after.title,
          },
          data: {
            taskId: event.params.taskId,
          },
        });
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

        if (!fcmToken) continue;

        await admin.messaging().send({
          token: fcmToken,
          notification: {
            title: "Task Reminder ⏰",
            body: "Your task is due tomorrow: " + taskTitle,
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

      if (!fcmToken) continue;

      await admin.messaging().send({
        token: fcmToken,
        notification: {
          title: "Task Reminder ⏰",
          body: "Your task is due today: " + taskTitle,
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

            if (employeeToken) {
              await admin.messaging().send({
                token: employeeToken,
                notification: {
                  title: "Overdue Task ⚠️",
                  body: "Your task is overdue: " + taskTitle,
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
          await admin.messaging().sendEachForMulticast({
            tokens: adminTokens,
            notification: {
              title: "Overdue Task Escalation 🚨",
              body:
                "Overdue task assigned to " + assignedToName + ": " + taskTitle,
            },
            data: {
              taskId: taskId,
              type: "task_overdue_escalation",
            },
          });

          adminsNotified = true;
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

          if (employeeToken) {
            await admin.messaging().send({
              token: employeeToken,
              notification: {
                title: "Overdue Task ⚠️",
                body: "Your task is overdue: " + taskTitle,
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
        await admin.messaging().sendEachForMulticast({
          tokens: adminTokens,
          notification: {
            title: "Overdue Task Escalation 🚨",
            body:
              "Overdue task assigned to " + assignedToName + ": " + taskTitle,
          },
          data: {
            taskId: taskId,
            type: "task_overdue_escalation",
          },
        });

        sentCount += adminTokens.length;
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
        docs.slice(i, i + CHUNK).forEach((doc) => batch.update(doc.ref, updateFn(doc)));
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
      await batchUpdate(assignedBySnap.docs, () => ({ assignedByName: "Deleted user" }));
    }

    // Step 2: tasks assigned TO this user → overwrite assignedToName
    const assignedToSnap = await db
      .collection("tasks")
      .where("assignedTo", "==", uid)
      .get();
    if (!assignedToSnap.empty) {
      await batchUpdate(assignedToSnap.docs, () => ({ assignedToName: "Deleted user" }));
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
