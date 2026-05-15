import 'package:cloud_firestore/cloud_firestore.dart';

class AttendanceModel {
  final String id;
  final String userId;
  final String date;
  final DateTime? checkInAt;
  final DateTime? checkOutAt;
  final int? durationMinutes;
  final String status;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const AttendanceModel({
    required this.id,
    required this.userId,
    required this.date,
    this.checkInAt,
    this.checkOutAt,
    this.durationMinutes,
    required this.status,
    this.createdAt,
    this.updatedAt,
  });

  factory AttendanceModel.fromMap(String id, Map<String, dynamic> data) {
    return AttendanceModel(
      id: id,
      userId: data['userId'] as String? ?? '',
      date: data['date'] as String? ?? '',
      checkInAt: _toDateTime(data['checkInAt']),
      checkOutAt: _toDateTime(data['checkOutAt']),
      durationMinutes: data['durationMinutes'] is int
          ? data['durationMinutes'] as int
          : null,
      status: data['status'] as String? ?? 'present',
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
