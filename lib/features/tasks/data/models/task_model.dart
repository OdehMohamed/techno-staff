import 'package:cloud_firestore/cloud_firestore.dart';

class TaskModel {
  final String id;
  final String title;
  final String description;
  final String assignedTo;
  final String assignedToName;
  final String assignedBy;
  final String assignedByName;
  final String priority;
  final String status;
  final DateTime dueDate;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final DateTime? completedAt;
  final String? updatedBy;
  final String? updatedByName;
  final String taskType;
  final int? targetCount;
  final int currentCount;
  final String? templateId;

  TaskModel({
    required this.id,
    required this.title,
    required this.description,
    required this.assignedTo,
    required this.assignedToName,
    required this.assignedBy,
    required this.assignedByName,
    required this.priority,
    required this.status,
    required this.dueDate,
    required this.createdAt,
    this.updatedAt,
    this.completedAt,
    this.updatedBy,
    this.updatedByName,
    this.taskType = 'standard',
    this.targetCount,
    this.currentCount = 0,
    this.templateId,
  });

  bool get isCounter => taskType == 'counter';

  static String deriveCounterStatus(int currentCount, int targetCount) {
    if (currentCount <= 0) return 'pending';
    if (currentCount >= targetCount) return 'completed';
    return 'in_progress';
  }

  factory TaskModel.fromMap(String id, Map<String, dynamic> data) {
    return TaskModel(
      id: id,
      title: data['title'] ?? '',
      description: data['description'] ?? '',
      assignedTo: data['assignedTo'] ?? '',
      assignedToName: data['assignedToName'] ?? '',
      assignedBy: data['assignedBy'] ?? '',
      assignedByName: data['assignedByName'] ?? '',
      priority: data['priority'] ?? 'medium',
      status: data['status'] ?? 'pending',
      dueDate: (data['dueDate'] as Timestamp).toDate(),
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      updatedAt: data['updatedAt'] != null
          ? (data['updatedAt'] as Timestamp).toDate()
          : null,
      completedAt: data['completedAt'] != null
          ? (data['completedAt'] as Timestamp).toDate()
          : null,
      updatedBy: data['updatedBy'],
      updatedByName: data['updatedByName'],
      taskType: (data['taskType'] as String?) ?? 'standard',
      targetCount: data['targetCount'] is int
          ? data['targetCount'] as int
          : null,
      currentCount: data['currentCount'] is int
          ? data['currentCount'] as int
          : 0,
      templateId: data['templateId'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'description': description,
      'assignedTo': assignedTo,
      'assignedToName': assignedToName,
      'assignedBy': assignedBy,
      'assignedByName': assignedByName,
      'priority': priority,
      'status': status,
      'dueDate': Timestamp.fromDate(dueDate),
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
      'completedAt': completedAt != null
          ? Timestamp.fromDate(completedAt!)
          : null,
      'updatedBy': updatedBy,
      'updatedByName': updatedByName,
      'taskType': taskType,
      if (targetCount != null) 'targetCount': targetCount,
      'currentCount': currentCount,
      if (templateId != null) 'templateId': templateId,
    };
  }

  TaskModel copyWith({
    String? id,
    String? title,
    String? description,
    String? assignedTo,
    String? assignedToName,
    String? assignedBy,
    String? assignedByName,
    String? priority,
    String? status,
    DateTime? dueDate,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? completedAt,
    bool clearCompletedAt = false,
    bool clearTargetCount = false,
    String? updatedBy,
    String? updatedByName,
    String? taskType,
    int? targetCount,
    int? currentCount,
    String? templateId,
  }) {
    return TaskModel(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      assignedTo: assignedTo ?? this.assignedTo,
      assignedToName: assignedToName ?? this.assignedToName,
      assignedBy: assignedBy ?? this.assignedBy,
      assignedByName: assignedByName ?? this.assignedByName,
      priority: priority ?? this.priority,
      status: status ?? this.status,
      dueDate: dueDate ?? this.dueDate,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      completedAt: clearCompletedAt ? null : (completedAt ?? this.completedAt),
      updatedBy: updatedBy ?? this.updatedBy,
      updatedByName: updatedByName ?? this.updatedByName,
      taskType: taskType ?? this.taskType,
      targetCount: clearTargetCount ? null : (targetCount ?? this.targetCount),
      currentCount: currentCount ?? this.currentCount,
      templateId: templateId ?? this.templateId,
    );
  }
}
