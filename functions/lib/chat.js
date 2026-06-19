const {onDocumentCreated} = require("firebase-functions/v2/firestore");
const admin = require("firebase-admin");
const {localize, getFcmTokensBatch, sendFCMNotification} = require("./shared");

// ─── Chat: onNewChatMessage ───────────────────────────────────────────────────

exports.onNewChatMessage = onDocumentCreated(
    "conversations/{conversationId}/messages/{messageId}",
    async (event) => {
      const snap = event.data;
      if (!snap) return;
      const msg = snap.data();
      if (!msg || msg.type === "system") return;

      const conversationId = event.params.conversationId;
      const db = admin.firestore();

      // Read the conversation document.
      const convRef = db.collection("conversations").doc(conversationId);
      const convSnap = await convRef.get();
      if (!convSnap.exists) return;
      const conv = convSnap.data();

      const senderId = msg.senderId || "";
      const senderName = msg.senderName || "";
      const rawText = msg.text || "";
      const preview = rawText.length > 80 ? rawText.substring(0, 80) + "…" : rawText;
      const isGroupLike = conv.type === "group" || conv.type === "task";

      const recipients = (conv.participantIds || []).filter((uid) => uid !== senderId);
      if (recipients.length === 0) return;

      // Update lastMessage, lastMessageAt, and unreadCounts atomically.
      const convUpdates = {
        "lastMessage": {
          text: preview,
          senderId,
          senderName,
          sentAt: snap.createTime,
        },
        "lastMessageAt": snap.createTime,
      };
      recipients.forEach((uid) => {
        convUpdates[`unreadCounts.${uid}`] = admin.firestore.FieldValue.increment(1);
      });

      try {
        await convRef.update(convUpdates);
      } catch (err) {
        console.error("onNewChatMessage: failed to update conversation", err);
      }

      // Fetch FCM tokens and user language codes in parallel.
      const [tokenMap, userDocs] = await Promise.all([
        getFcmTokensBatch(db, recipients),
        Promise.all(recipients.map((uid) => db.collection("users").doc(uid).get())),
      ]);

      const notificationTitle = isGroupLike ? (conv.name || senderName) : senderName;

      const perRecipient = recipients.map(async (uid, i) => {
        const userDoc = userDocs[i];
        const lang = userDoc.exists ? (userDoc.data().languageCode || "en") : "en";

        const body = isGroupLike ?
          localize("chat_group_message_body", {senderName, messageText: preview}, lang) :
          preview;

        const token = tokenMap[uid];
        if (token) {
          await sendFCMNotification({
            token,
            notification: {title: notificationTitle, body},
            data: {
              conversationId,
              type: "chat_message",
              click_action: "FLUTTER_NOTIFICATION_CLICK",
              notificationTitle,
              notificationBody: body,
            },
            android: {
              priority: "high",
              notification: {channelId: "chat_messages"},
            },
          });
        }
        // Chat messages are not written to the notifications collection.
        // Unread state is tracked via unreadCounts on the conversation document
        // (badge in the chat tab); FCM push is the user-facing alert surface.
      });

      await Promise.allSettled(perRecipient);
    },
);
