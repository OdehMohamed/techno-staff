class ScheduleDay {
  final bool isWorkingDay;
  final String? expectedStartTime; // "HH:mm" 24-hour
  final String? expectedEndTime;   // "HH:mm" 24-hour
  final int? graceMinutes;         // null = use WorkScheduleModel.defaultGraceMinutes

  const ScheduleDay({
    required this.isWorkingDay,
    this.expectedStartTime,
    this.expectedEndTime,
    this.graceMinutes,
  });

  factory ScheduleDay.fromMap(Map<String, dynamic> map) {
    return ScheduleDay(
      isWorkingDay: map['isWorkingDay'] as bool? ?? false,
      expectedStartTime: map['expectedStartTime'] as String?,
      expectedEndTime: map['expectedEndTime'] as String?,
      graceMinutes: map['graceMinutes'] as int?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'isWorkingDay': isWorkingDay,
      if (expectedStartTime != null) 'expectedStartTime': expectedStartTime,
      if (expectedEndTime != null) 'expectedEndTime': expectedEndTime,
      if (graceMinutes != null) 'graceMinutes': graceMinutes,
    };
  }

  ScheduleDay copyWith({
    bool? isWorkingDay,
    Object? expectedStartTime = _sentinel,
    Object? expectedEndTime = _sentinel,
    Object? graceMinutes = _sentinel,
  }) {
    return ScheduleDay(
      isWorkingDay: isWorkingDay ?? this.isWorkingDay,
      expectedStartTime: expectedStartTime == _sentinel
          ? this.expectedStartTime
          : expectedStartTime as String?,
      expectedEndTime: expectedEndTime == _sentinel
          ? this.expectedEndTime
          : expectedEndTime as String?,
      graceMinutes: graceMinutes == _sentinel
          ? this.graceMinutes
          : graceMinutes as int?,
    );
  }

  static const _sentinel = Object();
}
