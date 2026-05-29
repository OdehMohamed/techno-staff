import 'package:cloud_firestore/cloud_firestore.dart';

class ConversationLastMessage {
  final String text;
  final String senderId;
  final String senderName;
  final DateTime sentAt;

  const ConversationLastMessage({
    required this.text,
    required this.senderId,
    required this.senderName,
    required this.sentAt,
  });

  factory ConversationLastMessage.fromMap(Map<String, dynamic> map) {
    return ConversationLastMessage(
      text: map['text'] as String? ?? '',
      senderId: map['senderId'] as String? ?? '',
      senderName: map['senderName'] as String? ?? '',
      sentAt: map['sentAt'] != null
          ? (map['sentAt'] as Timestamp).toDate()
          : DateTime.now(),
    );
  }
}

class ConversationModel {
  final String id;
  final String type; // 'dm' | 'group' | 'task' | 'announcement'
  final List<String> participantIds;
  final Map<String, String> participantNames; // uid → display name snapshot
  final String? name; // null for DMs
  final String? taskId; // task-type only
  final String createdBy;
  final DateTime createdAt;
  final ConversationLastMessage? lastMessage;
  final DateTime? lastMessageAt;
  final Map<String, DateTime> memberLastRead;
  final Map<String, int> unreadCounts;
  final String? writeRestriction; // null | 'all' | 'admin_only'

  const ConversationModel({
    required this.id,
    required this.type,
    required this.participantIds,
    required this.participantNames,
    required this.name,
    required this.taskId,
    required this.createdBy,
    required this.createdAt,
    required this.lastMessage,
    required this.lastMessageAt,
    required this.memberLastRead,
    required this.unreadCounts,
    required this.writeRestriction,
  });

  bool get isDm => type == 'dm';
  bool get isGroup => type == 'group';
  bool get isTaskThread => type == 'task';

  /// Returns the other participant's name for DM display.
  /// Falls back to the conversation ID suffix if the name is missing.
  String otherParticipantName(String currentUserId) {
    final otherEntry = participantNames.entries
        .where((e) => e.key != currentUserId)
        .firstOrNull;
    return otherEntry?.value ?? '?';
  }

  /// Display name: stored name for groups/tasks, derived name for DMs.
  String displayName(String currentUserId) {
    if (isDm) return otherParticipantName(currentUserId);
    return name ?? '';
  }

  int unreadCountFor(String uid) => unreadCounts[uid] ?? 0;

  factory ConversationModel.fromMap(String id, Map<String, dynamic> map) {
    final rawNames = map['participantNames'] as Map<String, dynamic>? ?? {};
    final rawLastRead = map['memberLastRead'] as Map<String, dynamic>? ?? {};
    final rawUnread = map['unreadCounts'] as Map<String, dynamic>? ?? {};
    final rawLastMsg = map['lastMessage'] as Map<String, dynamic>?;

    return ConversationModel(
      id: id,
      type: map['type'] as String? ?? 'group',
      participantIds: List<String>.from(map['participantIds'] as List? ?? []),
      participantNames: Map<String, String>.fromEntries(
        rawNames.entries.map((e) => MapEntry(e.key, e.value as String? ?? '')),
      ),
      name: map['name'] as String?,
      taskId: map['taskId'] as String?,
      createdBy: map['createdBy'] as String? ?? '',
      createdAt: map['createdAt'] != null
          ? (map['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
      lastMessage:
          rawLastMsg != null ? ConversationLastMessage.fromMap(rawLastMsg) : null,
      lastMessageAt: map['lastMessageAt'] != null
          ? (map['lastMessageAt'] as Timestamp).toDate()
          : null,
      memberLastRead: Map<String, DateTime>.fromEntries(
        rawLastRead.entries.map(
          (e) => MapEntry(e.key, (e.value as Timestamp).toDate()),
        ),
      ),
      unreadCounts: Map<String, int>.fromEntries(
        rawUnread.entries.map(
          (e) => MapEntry(e.key, (e.value as num?)?.toInt() ?? 0),
        ),
      ),
      writeRestriction: map['writeRestriction'] as String?,
    );
  }
}
