import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../../core/constants/firebase_paths.dart';
import '../models/conversation_model.dart';
import '../models/message_model.dart';

class ChatRepository {
  final FirebaseFirestore _firestore;

  ChatRepository(this._firestore);

  // ─── Conversation streams ────────────────────────────────────────────────

  /// Real-time stream of all conversations for [uid], sorted newest-first.
  Stream<List<ConversationModel>> streamConversations(String uid) {
    return _firestore
        .collection(FirebasePaths.conversations)
        .where('participantIds', arrayContains: uid)
        .orderBy('lastMessageAt', descending: true)
        .snapshots()
        .map(
          (snap) => snap.docs
              .map((d) => ConversationModel.fromMap(d.id, d.data()))
              .toList(),
        );
  }

  // ─── Message streams & pagination ───────────────────────────────────────

  /// Real-time stream of the 50 newest messages for [conversationId].
  Stream<List<MessageModel>> streamMessages(String conversationId) {
    return _firestore
        .collection(FirebasePaths.conversations)
        .doc(conversationId)
        .collection(FirebasePaths.messages)
        .orderBy('sentAt', descending: true)
        .limit(50)
        .snapshots()
        .map(
          (snap) => snap.docs
              .map((d) => MessageModel.fromMap(d.id, d.data()))
              .toList(),
        );
  }

  /// Fetches 50 messages older than [lastDocument] for pagination.
  Future<List<MessageModel>> loadOlderMessages(
    String conversationId,
    DocumentSnapshot lastDocument,
  ) async {
    final snap = await _firestore
        .collection(FirebasePaths.conversations)
        .doc(conversationId)
        .collection(FirebasePaths.messages)
        .orderBy('sentAt', descending: true)
        .startAfterDocument(lastDocument)
        .limit(50)
        .get(const GetOptions(source: Source.server));

    return snap.docs.map((d) => MessageModel.fromMap(d.id, d.data())).toList();
  }

  /// Returns the raw [DocumentSnapshot] for a message (used as pagination cursor).
  Future<DocumentSnapshot?> getMessageSnapshot(
    String conversationId,
    String messageId,
  ) async {
    final doc = await _firestore
        .collection(FirebasePaths.conversations)
        .doc(conversationId)
        .collection(FirebasePaths.messages)
        .doc(messageId)
        .get(const GetOptions(source: Source.server));
    return doc.exists ? doc : null;
  }

  // ─── DM ─────────────────────────────────────────────────────────────────

  /// Returns the deterministic DM conversation ID for [uid1] and [uid2].
  static String dmId(String uid1, String uid2) {
    final sorted = [uid1, uid2]..sort();
    return 'dm_${sorted.join('_')}';
  }

  /// Returns the existing DM conversation ID for [uid1]/[uid2], creating it
  /// if it does not exist. Never overwrites an existing conversation.
  Future<String> getOrCreateDm(
    String uid1,
    String uid2,
    String name1,
    String name2,
  ) async {
    final id = dmId(uid1, uid2);
    final ref = _firestore.collection(FirebasePaths.conversations).doc(id);

    final existing =
        await ref.get(const GetOptions(source: Source.server));
    if (!existing.exists) {
      await ref.set({
        'type': 'dm',
        'participantIds': [uid1, uid2],
        'participantNames': {uid1: name1, uid2: name2},
        'name': null,
        'taskId': null,
        'createdBy': uid1,
        'createdAt': FieldValue.serverTimestamp(),
        'lastMessage': null,
        'lastMessageAt': FieldValue.serverTimestamp(),
        'memberLastRead': {},
        'unreadCounts': {},
        'writeRestriction': null,
      });
    }
    return id;
  }

  // ─── Group ───────────────────────────────────────────────────────────────

  /// Creates a group conversation and inserts the "created" system message.
  /// Returns the new conversation ID.
  Future<String> createGroup({
    required String name,
    required String creatorUid,
    required String creatorName,
    required List<String> memberUids,
    required Map<String, String> memberNames,
  }) async {
    final convRef =
        _firestore.collection(FirebasePaths.conversations).doc();
    final msgRef =
        convRef.collection(FirebasePaths.messages).doc();
    final allUids = [creatorUid, ...memberUids];
    final allNames = {creatorUid: creatorName, ...memberNames};
    final systemText = '$creatorName created this group';
    final batch = _firestore.batch();

    batch.set(convRef, {
      'type': 'group',
      'participantIds': allUids,
      'participantNames': allNames,
      'name': name,
      'taskId': null,
      'createdBy': creatorUid,
      'createdAt': FieldValue.serverTimestamp(),
      'lastMessage': {
        'text': systemText,
        'senderId': creatorUid,
        'senderName': creatorName,
        'sentAt': FieldValue.serverTimestamp(),
      },
      'lastMessageAt': FieldValue.serverTimestamp(),
      'memberLastRead': {},
      'unreadCounts': {},
      'writeRestriction': null,
    });

    batch.set(msgRef, {
      'senderId': creatorUid,
      'senderName': creatorName,
      'text': systemText,
      'type': 'system',
      'sentAt': FieldValue.serverTimestamp(),
      'deletedAt': null,
      'deletedBy': null,
      'attachment': null,
      'reactions': null,
      'replyTo': null,
      'mentions': [],
      'editedAt': null,
    });

    await batch.commit();
    return convRef.id;
  }

  // ─── Task thread ─────────────────────────────────────────────────────────

  /// Opens an existing task thread or creates a new one.
  /// [taskTitle] is shown in the conversation AppBar.
  Future<String> getOrCreateTaskThread({
    required String taskId,
    required String taskTitle,
    required String creatorUid,
    required String creatorName,
    required String assigneeUid,
    required String assigneeName,
  }) async {
    final existing = await _firestore
        .collection(FirebasePaths.conversations)
        .where('taskId', isEqualTo: taskId)
        .limit(1)
        .get(const GetOptions(source: Source.server));

    if (existing.docs.isNotEmpty) return existing.docs.first.id;

    final convRef =
        _firestore.collection(FirebasePaths.conversations).doc();
    final msgRef =
        convRef.collection(FirebasePaths.messages).doc();
    final systemText = 'Discussion opened for "$taskTitle"';
    final batch = _firestore.batch();
    final participants = {creatorUid, assigneeUid}.toList();
    final participantNames = {
      creatorUid: creatorName,
      assigneeUid: assigneeName,
    };

    batch.set(convRef, {
      'type': 'task',
      'participantIds': participants,
      'participantNames': participantNames,
      'name': taskTitle,
      'taskId': taskId,
      'createdBy': creatorUid,
      'createdAt': FieldValue.serverTimestamp(),
      'lastMessage': {
        'text': systemText,
        'senderId': creatorUid,
        'senderName': creatorName,
        'sentAt': FieldValue.serverTimestamp(),
      },
      'lastMessageAt': FieldValue.serverTimestamp(),
      'memberLastRead': {},
      'unreadCounts': {},
      'writeRestriction': null,
    });

    batch.set(msgRef, {
      'senderId': creatorUid,
      'senderName': creatorName,
      'text': systemText,
      'type': 'system',
      'sentAt': FieldValue.serverTimestamp(),
      'deletedAt': null,
      'deletedBy': null,
      'attachment': null,
      'reactions': null,
      'replyTo': null,
      'mentions': [],
      'editedAt': null,
    });

    await batch.commit();
    return convRef.id;
  }

  // ─── Messaging ───────────────────────────────────────────────────────────

  /// Sends a text message and immediately updates the conversation's
  /// lastMessage/lastMessageAt so the list reorders without waiting for the CF.
  Future<void> sendMessage({
    required String conversationId,
    required String senderId,
    required String senderName,
    required String text,
  }) async {
    final convRef = _firestore
        .collection(FirebasePaths.conversations)
        .doc(conversationId);
    final msgRef = convRef.collection(FirebasePaths.messages).doc();
    final batch = _firestore.batch();

    batch.set(msgRef, {
      'senderId': senderId,
      'senderName': senderName,
      'text': text,
      'type': 'text',
      'sentAt': FieldValue.serverTimestamp(),
      'deletedAt': null,
      'deletedBy': null,
      'attachment': null,
      'reactions': null,
      'replyTo': null,
      'mentions': [],
      'editedAt': null,
    });

    // Optimistic lastMessage update — CF will write the same values.
    batch.update(convRef, {
      'lastMessage': {
        'text': text,
        'senderId': senderId,
        'senderName': senderName,
        'sentAt': FieldValue.serverTimestamp(),
      },
      'lastMessageAt': FieldValue.serverTimestamp(),
    });

    await batch.commit();
  }

  // ─── Read tracking ───────────────────────────────────────────────────────

  /// Resets the unread count and records the last-read timestamp for [uid].
  Future<void> markAsRead(String conversationId, String uid) async {
    await _firestore
        .collection(FirebasePaths.conversations)
        .doc(conversationId)
        .update({
      'unreadCounts.$uid': 0,
      'memberLastRead.$uid': FieldValue.serverTimestamp(),
    });
  }

  // ─── Message management ──────────────────────────────────────────────────

  /// Soft-deletes a message. Only the sender is permitted by Firestore rules.
  Future<void> softDeleteMessage(
    String conversationId,
    String messageId,
    String uid,
  ) async {
    await _firestore
        .collection(FirebasePaths.conversations)
        .doc(conversationId)
        .collection(FirebasePaths.messages)
        .doc(messageId)
        .update({
      'deletedAt': FieldValue.serverTimestamp(),
      'deletedBy': uid,
    });
  }
}
