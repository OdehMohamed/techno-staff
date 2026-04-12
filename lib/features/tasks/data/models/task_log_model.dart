import 'package:cloud_firestore/cloud_firestore.dart';

class TaskLogModel {
  final String id;
  final String taskId;
  final String action;
  final String? previousStatus;
  final String? newStatus;
  final String? performedBy;
  final String performedByName;
  final DateTime? performedAt;

  TaskLogModel({
    required this.id,
    required this.taskId,
    required this.action,
    required this.previousStatus,
    required this.newStatus,
    required this.performedBy,
    required this.performedByName,
    required this.performedAt,
  });

  factory TaskLogModel.fromMap(String id, Map<String, dynamic> data) {
    return TaskLogModel(
      id: id,
      taskId: data['taskId'] ?? '',
      action: data['action'] ?? '',
      previousStatus: data['previousStatus'],
      newStatus: data['newStatus'],
      performedBy: data['performedBy'],
      performedByName: data['performedByName'] ?? 'Unknown',
      performedAt: data['performedAt'] != null
          ? (data['performedAt'] as Timestamp).toDate()
          : null,
    );
  }
}
