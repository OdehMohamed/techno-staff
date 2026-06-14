import 'package:cloud_firestore/cloud_firestore.dart';

class MessageModel {
  final String id;
  final String senderId;
  final String senderName;
  final String? text;
  final String type; // 'text' | 'image' | 'file' | 'voice' | 'system'
  final DateTime sentAt;
  final DateTime? deletedAt;
  final String? deletedBy;

  // Phase 3 — always null in v1; parsed defensively so the schema is stable.
  final Map<String, dynamic>? attachment;
  final Map<String, List<String>>? reactions;
  final Map<String, dynamic>? replyTo;
  final List<String> mentions;
  final DateTime? editedAt;

  const MessageModel({
    required this.id,
    required this.senderId,
    required this.senderName,
    required this.text,
    required this.type,
    required this.sentAt,
    required this.deletedAt,
    required this.deletedBy,
    this.attachment,
    this.reactions,
    this.replyTo,
    this.mentions = const [],
    this.editedAt,
  });

  bool get isDeleted => deletedAt != null;
  bool get isSystem => type == 'system';
  bool get isText => type == 'text';
  bool get hasAttachment => attachment != null;

  factory MessageModel.fromMap(String id, Map<String, dynamic> map) {
    // reactions: Map<String, dynamic> → Map<String, List<String>>
    final rawReactions = map['reactions'] as Map<String, dynamic>?;
    final parsedReactions = rawReactions != null
        ? Map<String, List<String>>.fromEntries(
            rawReactions.entries.map(
              (e) => MapEntry(e.key, List<String>.from(e.value as List? ?? [])),
            ),
          )
        : null;

    return MessageModel(
      id: id,
      senderId: map['senderId'] as String? ?? '',
      senderName: map['senderName'] as String? ?? '',
      text: map['text'] as String?,
      type: map['type'] as String? ?? 'text',
      sentAt: map['sentAt'] != null
          ? (map['sentAt'] as Timestamp).toDate()
          : DateTime.now(),
      deletedAt: map['deletedAt'] != null
          ? (map['deletedAt'] as Timestamp).toDate()
          : null,
      deletedBy: map['deletedBy'] as String?,
      attachment: map['attachment'] as Map<String, dynamic>?,
      reactions: parsedReactions,
      replyTo: map['replyTo'] as Map<String, dynamic>?,
      mentions: List<String>.from(map['mentions'] as List? ?? []),
      editedAt: map['editedAt'] != null
          ? (map['editedAt'] as Timestamp).toDate()
          : null,
    );
  }
}
