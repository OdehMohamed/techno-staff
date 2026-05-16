import 'package:cloud_firestore/cloud_firestore.dart';

class AttendanceSession {
  final DateTime checkInAt;
  final DateTime? checkOutAt;
  final int? durationMinutes;

  const AttendanceSession({
    required this.checkInAt,
    this.checkOutAt,
    this.durationMinutes,
  });

  factory AttendanceSession.fromMap(Map<String, dynamic> data) {
    return AttendanceSession(
      checkInAt: _toDateTime(data['checkInAt'])!,
      checkOutAt: _toDateTime(data['checkOutAt']),
      durationMinutes: data['durationMinutes'] is int
          ? data['durationMinutes'] as int
          : null,
    );
  }

  static DateTime? _toDateTime(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return null;
  }
}