/* eslint-disable */
const { onCall, HttpsError } = require("firebase-functions/https");
const { onDocumentCreated } = require("firebase-functions/v2/firestore");
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
    } catch (error) {
      console.error("Error sending task notification:", error);
    }
  },
);
const { onDocumentUpdated } = require("firebase-functions/v2/firestore");

exports.sendTaskStatusNotification = onDocumentUpdated(
  "tasks/{taskId}",
  async (event) => {
    const before = event.data.before.data();
    const after = event.data.after.data();

    // ❗ إذا ما تغير status → لا تعمل شيء
    if (before.status === after.status) return;

    const db = admin.firestore();

    // 🔥 إذا المهمة اكتملت
    if (after.status === "completed") {
      const assignedById = after.assignedBy;
      const currentUserId = after.updatedBy;

      // 1️⃣ جلب جميع الأدمنز
      const adminsSnapshot = await db
        .collection("users")
        .where("role", "==", "admin")
        .get();

      const tokens = [];

      adminsSnapshot.forEach((doc) => {
        const data = doc.data();

        if (data.fcmToken) {
          tokens.push(data.fcmToken);
        }
      });

      // 2️⃣ جلب منشئ المهمة
      if (assignedById && assignedById !== currentUserId) {
        const creatorDoc = await db.collection("users").doc(assignedById).get();

        const creatorData = creatorDoc.data();

        if (creatorData && creatorData.fcmToken) {
          tokens.push(creatorData.fcmToken);
        }
      }

      if (tokens.length === 0) return;

      // 🔥 إرسال الإشعار
      await admin.messaging().sendEachForMulticast({
        tokens,
        notification: {
          title: "Task Completed ✅",
          body: after.title,
        },
        data: {
          taskId: event.params.taskId,
        },
      });
    }
  },
);
