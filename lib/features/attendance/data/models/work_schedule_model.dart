import 'package:cloud_firestore/cloud_firestore.dart';
import 'schedule_day.dart';

class WorkScheduleModel {
  final String userId;
  final String userName;
  final int defaultGraceMinutes;
  /// Keys are day-of-week strings "1"–"7" (1 = Sunday, 7 = Saturday).
  final Map<String, ScheduleDay> days;
  final DateTime? updatedAt;
  final String? updatedBy;
  final String? updatedByName;

  const WorkScheduleModel({
    required this.userId,
    required this.userName,
    this.defaultGraceMinutes = 15,
    required this.days,
    this.updatedAt,
    this.updatedBy,
    this.updatedByName,
  });

  /// A blank schedule where every day is a working day with no time constraints.
  factory WorkScheduleModel.defaultFor({
    required String userId,
    required String userName,
  }) {
    return WorkScheduleModel(
      userId: userId,
      userName: userName,
      defaultGraceMinutes: 15,
      days: {
        for (final day in ['1', '2', '3', '4', '5', '6', '7'])
          day: const ScheduleDay(isWorkingDay: true),
      },
    );
  }

  factory WorkScheduleModel.fromMap(Map<String, dynamic> map, String docId) {
    final rawDays = map['days'] as Map<String, dynamic>? ?? {};
    final days = rawDays.map(
      (key, value) => MapEntry(key, ScheduleDay.fromMap(value as Map<String, dynamic>)),
    );
    return WorkScheduleModel(
      userId: docId,
      userName: map['userName'] as String? ?? '',
      defaultGraceMinutes: map['defaultGraceMinutes'] as int? ?? 15,
      days: days,
      updatedAt: (map['updatedAt'] as Timestamp?)?.toDate(),
      updatedBy: map['updatedBy'] as String?,
      updatedByName: map['updatedByName'] as String?,
    );
  }

  Map<String, dynamic> toMap({
    required String updatedBy,
    required String updatedByName,
  }) {
    return {
      'userId': userId,
      'userName': userName,
      'defaultGraceMinutes': defaultGraceMinutes,
      'days': days.map((key, value) => MapEntry(key, value.toMap())),
      'updatedAt': FieldValue.serverTimestamp(),
      'updatedBy': updatedBy,
      'updatedByName': updatedByName,
    };
  }

  WorkScheduleModel copyWith({
    String? userId,
    String? userName,
    int? defaultGraceMinutes,
    Map<String, ScheduleDay>? days,
    DateTime? updatedAt,
    String? updatedBy,
    String? updatedByName,
  }) {
    return WorkScheduleModel(
      userId: userId ?? this.userId,
      userName: userName ?? this.userName,
      defaultGraceMinutes: defaultGraceMinutes ?? this.defaultGraceMinutes,
      days: days ?? this.days,
      updatedAt: updatedAt ?? this.updatedAt,
      updatedBy: updatedBy ?? this.updatedBy,
      updatedByName: updatedByName ?? this.updatedByName,
    );
  }
}
