import 'package:cloud_firestore/cloud_firestore.dart';

class InAppNotificationModel {
  final String id;
  final String userId;
  final String type;
  final String? taskId;
  final String? conversationId;
  final bool isRead;
  final DateTime? createdAt;
  final Map<String, dynamic>? data;

  InAppNotificationModel({
    required this.id,
    required this.userId,
    required this.type,
    required this.taskId,
    this.conversationId,
    required this.isRead,
    required this.createdAt,
    required this.data,
  });

  factory InAppNotificationModel.fromMap(String id, Map<String, dynamic> map) {
    return InAppNotificationModel(
      id: id,
      userId: map['userId'] ?? '',
      type: map['type'] ?? '',
      taskId: map['taskId'],
      conversationId: map['conversationId'] as String?,
      isRead: map['isRead'] ?? false,
      createdAt: map['createdAt'] != null
          ? (map['createdAt'] as Timestamp).toDate()
          : null,
      data: map['data'] != null ? Map<String, dynamic>.from(map['data']) : null,
    );
  }
}
