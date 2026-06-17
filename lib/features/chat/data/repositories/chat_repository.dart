import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../../core/constants/firebase_paths.dart';
import '../models/conversation_model.dart';
import '../models/message_model.dart';

class ChatRepository {
  final FirebaseFirestore _firestore;

  ChatRepository(this._firestore);

  // ─── Conversation streams ────────────────────────────────────────────────

  /// Real-time stream of a single conversation document.
  Stream<ConversationModel?> streamConversation(String conversationId) {
    return _firestore
        .collection(FirebasePaths.conversations)
        .doc(conversationId)
        .snapshots()
        .map((doc) => doc.exists
            ? ConversationModel.fromMap(doc.id, doc.data()!)
            : null);
  }

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
  /// if it does not exist.
  ///
  /// Implementation note: we attempt the [set()] directly rather than doing
  /// a pre-read existence check. A pre-read with [Source.server] on a
  /// non-existent document causes the Firestore SDK to hang indefinitely
  /// while the security rules evaluation (which accesses [resource.data] on a
  /// null resource) never produces a clean response.
  ///
  /// A [set()] on an existing DM document is treated as a full update by
  /// Firestore rules; our [allow update] rule restricts participants to
  /// conversation-level fields only, so it returns [permission-denied].
  /// We catch that specific code and return the existing ID — it is the only
  /// reason [permission-denied] can fire here given the [create] rule
  /// validates [createdBy == auth.uid].
  Future<String> getOrCreateDm(
    String uid1,
    String uid2,
    String name1,
    String name2,
  ) async {
    final id = dmId(uid1, uid2);
    final ref = _firestore.collection(FirebasePaths.conversations).doc(id);

    try {
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
    } on FirebaseException catch (e) {
      // 'permission-denied' means the document already exists — our
      // update rules restrict full overwrites to admins. This is the
      // expected "DM exists" path; return the ID as-is.
      if (e.code != 'permission-denied') rethrow;
    }
    return id;
  }

  // ─── Group ───────────────────────────────────────────────────────────────

  /// Creates a group conversation and inserts the "created" system message.
  /// Returns the new conversation ID.
  ///
  /// Two sequential writes are used instead of a batch: the Firestore security
  /// rule for message creation calls `inConversation()` which reads the
  /// conversation document via `get()`. In a batched write the conversation
  /// doc is not yet in the committed state when the message rule is evaluated,
  /// so the rule would deny the write. Writing the conversation first and then
  /// the message avoids this ordering problem.
  Future<String> createGroup({
    required String name,
    required String creatorUid,
    required String creatorName,
    required List<String> memberUids,
    required Map<String, String> memberNames,
    String? writeRestriction,
  }) async {
    final convRef =
        _firestore.collection(FirebasePaths.conversations).doc();
    final allUids = [creatorUid, ...memberUids];
    final allNames = {creatorUid: creatorName, ...memberNames};
    final systemText = writeRestriction == 'admin_only'
        ? '$creatorName created this channel'
        : '$creatorName created this group';

    // Write 1: create the conversation document so the message security rule
    // can verify participantIds via get(conversation_doc).
    await convRef.set({
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
      'writeRestriction': writeRestriction,
    });

    // Write 2: create the system message now that the conversation exists.
    await convRef.collection(FirebasePaths.messages).add({
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

    return convRef.id;
  }

  // ─── Task thread ─────────────────────────────────────────────────────────

  /// Opens an existing task thread or creates a new one.
  /// Uses a deterministic document ID `task_${taskId}` to prevent duplicate
  /// threads when two users tap "Open discussion" simultaneously.
  Future<String> getOrCreateTaskThread({
    required String taskId,
    required String taskTitle,
    required String initiatorUid,
    required String initiatorName,
    required String creatorUid,
    required String creatorName,
    required String assigneeUid,
    required String assigneeName,
  }) async {
    final id = 'task_$taskId';
    final convRef =
        _firestore.collection(FirebasePaths.conversations).doc(id);
    final systemText = 'Discussion opened for "$taskTitle"';
    final participants = [creatorUid, assigneeUid];
    final participantNames = {
      creatorUid: creatorName,
      assigneeUid: assigneeName,
    };

    // Write 1: create the conversation document.
    //
    // We use set() without a pre-read existence check for two reasons:
    //
    // (a) The read rule `allow read: if isParticipant()` evaluates
    //     `resource.data.participantIds`, which throws in CEL when `resource`
    //     is null (non-existent document) → permission-denied on the get(),
    //     making an existence pre-check impossible without a rules change.
    //
    // (b) If the document already exists, Firestore evaluates the UPDATE rule
    //     for a set(). Non-admin participants cannot overwrite all fields
    //     (only `onlyAllowedConvFields()` changes are allowed), so
    //     permission-denied fires → we return the existing id. This mirrors
    //     the getOrCreateDm() pattern.
    try {
      await convRef.set({
        'type': 'task',
        'participantIds': participants,
        'participantNames': participantNames,
        'name': taskTitle,
        'taskId': taskId,
        'createdBy': initiatorUid,
        'createdAt': FieldValue.serverTimestamp(),
        'lastMessage': {
          'text': systemText,
          'senderId': initiatorUid,
          'senderName': initiatorName,
          'sentAt': FieldValue.serverTimestamp(),
        },
        'lastMessageAt': FieldValue.serverTimestamp(),
        'memberLastRead': {},
        'unreadCounts': {},
        'writeRestriction': null,
      });
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied') return id;
      rethrow;
    }

    // Write 2: add the system message now that the conversation is committed.
    //
    // Sequential (not batched with Write 1) because the message create rule
    // calls get(conversation) to verify the user is a participant. In a
    // batched write the conversation is not yet in the committed state when
    // the message rule is evaluated → permission-denied on the message write.
    // This is the same reason createGroup() uses sequential writes.
    await convRef.collection(FirebasePaths.messages).doc().set({
      'senderId': initiatorUid,
      'senderName': initiatorName,
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

    return id;
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
