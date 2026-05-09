import 'package:cloud_firestore/cloud_firestore.dart';

class RecurrenceRule {
  final String type; // 'daily' | 'weekly' | 'monthly'
  final List<int>? daysOfWeek; // weekly: 1..7 (Mon..Sun)
  final int? dayOfMonth; // monthly: 1..31

  const RecurrenceRule({
    required this.type,
    this.daysOfWeek,
    this.dayOfMonth,
  }) : assert(
          (type == 'weekly' &&
                  daysOfWeek != null &&
                  daysOfWeek.length > 0) ||
              (type == 'monthly' && dayOfMonth != null) ||
              type == 'daily',
          'Invalid RecurrenceRule for type: $type',
        );

  factory RecurrenceRule.fromMap(Map<String, dynamic> data) {
    final type = (data['type'] as String?) ?? 'daily';
    List<int>? daysOfWeek;
    int? dayOfMonth;

    if (type == 'weekly') {
      final raw = data['daysOfWeek'];
      if (raw is List) {
        daysOfWeek = raw
            .whereType<num>()
            .map((e) => e.toInt())
            .where((d) => d >= 1 && d <= 7)
            .toList();
      }
      if (daysOfWeek == null || daysOfWeek.isEmpty) {
        daysOfWeek = [1]; // fallback to Monday
      }
    }

    if (type == 'monthly') {
      final raw = data['dayOfMonth'];
      if (raw is num) {
        dayOfMonth = raw.toInt().clamp(1, 31);
      } else {
        dayOfMonth = 1;
      }
    }

    return RecurrenceRule(
      type: type,
      daysOfWeek: daysOfWeek,
      dayOfMonth: dayOfMonth,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'type': type,
      if (daysOfWeek != null) 'daysOfWeek': daysOfWeek,
      if (dayOfMonth != null) 'dayOfMonth': dayOfMonth,
    };
  }

  RecurrenceRule copyWith({
    String? type,
    List<int>? daysOfWeek,
    int? dayOfMonth,
    bool clearDaysOfWeek = false,
    bool clearDayOfMonth = false,
  }) {
    return RecurrenceRule(
      type: type ?? this.type,
      daysOfWeek:
          clearDaysOfWeek ? null : (daysOfWeek ?? this.daysOfWeek),
      dayOfMonth:
          clearDayOfMonth ? null : (dayOfMonth ?? this.dayOfMonth),
    );
  }
}

class TaskTemplateModel {
  final String id;
  final String title;
  final String description;
  final String assignedTo;
  final String assignedToName;
  final String assignedBy;
  final String assignedByName;
  final String priority;
  final String taskType; // 'standard' | 'counter' — immutable after create
  final int? targetCount; // required when taskType == 'counter'
  final RecurrenceRule recurrence;
  final bool isActive;
  final DateTime? lastGeneratedAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  const TaskTemplateModel({
    required this.id,
    required this.title,
    required this.description,
    required this.assignedTo,
    required this.assignedToName,
    required this.assignedBy,
    required this.assignedByName,
    required this.priority,
    required this.taskType,
    this.targetCount,
    required this.recurrence,
    required this.isActive,
    this.lastGeneratedAt,
    required this.createdAt,
    required this.updatedAt,
  });

  bool get isCounter => taskType == 'counter';

  factory TaskTemplateModel.fromMap(String id, Map<String, dynamic> data) {
    return TaskTemplateModel(
      id: id,
      title: data['title'] as String? ?? '',
      description: data['description'] as String? ?? '',
      assignedTo: data['assignedTo'] as String? ?? '',
      assignedToName: data['assignedToName'] as String? ?? '',
      assignedBy: data['assignedBy'] as String? ?? '',
      assignedByName: data['assignedByName'] as String? ?? '',
      priority: data['priority'] as String? ?? 'medium',
      taskType: data['taskType'] as String? ?? 'standard',
      targetCount: data['targetCount'] is int
          ? data['targetCount'] as int
          : null,
      recurrence: RecurrenceRule.fromMap(
        (data['recurrence'] as Map<String, dynamic>?) ?? {},
      ),
      isActive: data['isActive'] as bool? ?? true,
      lastGeneratedAt: data['lastGeneratedAt'] != null
          ? (data['lastGeneratedAt'] as Timestamp).toDate()
          : null,
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      updatedAt: (data['updatedAt'] as Timestamp).toDate(),
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
      'taskType': taskType,
      if (targetCount != null) 'targetCount': targetCount,
      'recurrence': recurrence.toMap(),
      'isActive': isActive,
      if (lastGeneratedAt != null)
        'lastGeneratedAt': Timestamp.fromDate(lastGeneratedAt!),
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  TaskTemplateModel copyWith({
    String? id,
    String? title,
    String? description,
    String? assignedTo,
    String? assignedToName,
    String? assignedBy,
    String? assignedByName,
    String? priority,
    String? taskType,
    int? targetCount,
    bool clearTargetCount = false,
    RecurrenceRule? recurrence,
    bool? isActive,
    DateTime? lastGeneratedAt,
    bool clearLastGeneratedAt = false,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return TaskTemplateModel(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      assignedTo: assignedTo ?? this.assignedTo,
      assignedToName: assignedToName ?? this.assignedToName,
      assignedBy: assignedBy ?? this.assignedBy,
      assignedByName: assignedByName ?? this.assignedByName,
      priority: priority ?? this.priority,
      taskType: taskType ?? this.taskType,
      targetCount:
          clearTargetCount ? null : (targetCount ?? this.targetCount),
      recurrence: recurrence ?? this.recurrence,
      isActive: isActive ?? this.isActive,
      lastGeneratedAt: clearLastGeneratedAt
          ? null
          : (lastGeneratedAt ?? this.lastGeneratedAt),
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
