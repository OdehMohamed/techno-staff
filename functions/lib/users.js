const {onCall, HttpsError} = require("firebase-functions/https");
const admin = require("firebase-admin");

exports.createEmployeeUser = onCall(async (request) => {
  try {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "User must be logged in");
    }

    const {email, password, name, role} = request.data;

    if (!email || !password || !name || !role) {
      throw new HttpsError("invalid-argument", "Missing required fields");
    }

    if (!["admin", "employee", "collector"].includes(role)) {
      throw new HttpsError(
          "invalid-argument",
          "role must be 'admin', 'employee', or 'collector'",
      );
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
          "Only admins can create employees",
      );
    }

    const userRecord = await admin.auth().createUser({
      email,
      password,
      displayName: name,
    });

    const userDoc = {
      email,
      name,
      role,
      isActive: true,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    };
    if (role === "collector") {
      userDoc.cashOnHand = 0;
      userDoc.maxCashOnHand = null;
    }
    await db.collection("users").doc(userRecord.uid).set(userDoc);

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
    // Create a fresh custom token AFTER revocation so the calling device can
    // re-authenticate with a new refresh token that is not covered by the
    // revocation. All other devices' revoked refresh tokens remain invalid.
    const customToken = await admin.auth().createCustomToken(request.auth.uid);
    return {success: true, customToken};
  } catch (error) {
    console.error("revokeUserSessions failed", error);
    throw new HttpsError("internal", "Failed to revoke sessions");
  }
});
