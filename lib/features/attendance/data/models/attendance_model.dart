import 'package:cloud_firestore/cloud_firestore.dart';

import 'attendance_session.dart';

class AttendanceModel {
  final String id;
  final String userId;
  final String userName;
  final String date;
  final List<AttendanceSession> sessions;
  final int totalDurationMinutes;
  final String status;
  final bool isCorrected;
  final List<AttendanceSession>? originalSessions;
  final String? notes;
  final String? correctedBy;
  final String? correctedByName;
  final DateTime? correctedAt;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const AttendanceModel({
    required this.id,
    required this.userId,
    this.userName = '',
    required this.date,
    this.sessions = const [],
    this.totalDurationMinutes = 0,
    required this.status,
    this.isCorrected = false,
    this.originalSessions,
    this.notes,
    this.correctedBy,
    this.correctedByName,
    this.correctedAt,
    this.createdAt,
    this.updatedAt,
  });

  DateTime? get checkInAt =>
      sessions.isNotEmpty ? sessions.first.checkInAt : null;

  DateTime? get checkOutAt =>
      sessions.isNotEmpty ? sessions.last.checkOutAt : null;

  bool get hasOpenSession =>
      sessions.isNotEmpty && sessions.last.checkOutAt == null;

  factory AttendanceModel.fromMap(String id, Map<String, dynamic> data) {
    final mappedStatus = (() {
      final s = data['status'] as String? ?? 'absent';
      return s == 'manual' ? 'present' : s;
    })();

    final rawSessions = data['sessions'] as List<dynamic>? ?? [];
    final parsedSessions = rawSessions
        .whereType<Map<String, dynamic>>()
        .where((s) => _toDateTime(s['checkInAt']) != null)
        .map(AttendanceSession.fromMap)
        .toList();

    final fallbackCheckInAt = _toDateTime(data['checkInAt']);
    final fallbackCheckOutAt = _toDateTime(data['checkOutAt']);
    final fallbackDurationMinutes = data['durationMinutes'] is int
        ? data['durationMinutes'] as int
        : null;

    final sessions = parsedSessions.isNotEmpty
        ? (parsedSessions..sort((a, b) => a.checkInAt.compareTo(b.checkInAt)))
        : fallbackCheckInAt != null
        ? [
            AttendanceSession(
              checkInAt: fallbackCheckInAt,
              checkOutAt: fallbackCheckOutAt,
              durationMinutes: fallbackDurationMinutes,
            ),
          ]
        : const <AttendanceSession>[];

    final rawOriginalSessions = data['originalSessions'] as List<dynamic>?;
    final parsedOriginalSessions = rawOriginalSessions
        ?.whereType<Map<String, dynamic>>()
        .where((s) => _toDateTime(s['checkInAt']) != null)
        .map(AttendanceSession.fromMap)
        .toList();

    return AttendanceModel(
      id: id,
      userId: data['userId'] as String? ?? '',
      userName: data['userName'] as String? ?? '',
      date: data['date'] as String? ?? '',
      sessions: sessions,
      totalDurationMinutes:
          data['totalDurationMinutes'] as int? ?? fallbackDurationMinutes ?? 0,
      status: mappedStatus,
      isCorrected: data['isCorrected'] as bool? ?? (data['status'] == 'manual'),
      originalSessions: parsedOriginalSessions,
      notes: data['notes'] as String?,
      correctedBy: data['correctedBy'] as String?,
      correctedByName: data['correctedByName'] as String?,
      correctedAt: _toDateTime(data['correctedAt']),
      createdAt: _toDateTime(data['createdAt']),
      updatedAt: _toDateTime(data['updatedAt']),
    );
  }

  static DateTime? _toDateTime(dynamic value) {
    if (value == null) {
      return null;
    }
    if (value is Timestamp) {
      return value.toDate();
    }
    if (value is DateTime) {
      return value;
    }
    return null;
  }
}
