import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:intl/intl.dart';

import '../models/attendance_model.dart';

class AttendanceRepository {
  final FirebaseFirestore _firestore;
  final FirebaseFunctions _functions;

  AttendanceRepository({
    FirebaseFirestore? firestore,
    FirebaseFunctions? functions,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _functions = functions ?? FirebaseFunctions.instance;

  Future<AttendanceModel?> fetchTodayRecord(String userId) async {
    final today = _todayJerusalemYmd();
    final docId = '${userId}_$today';
    final doc = await _firestore
        .collection('attendance')
        .doc(docId)
        .get(const GetOptions(source: Source.server));
    if (!doc.exists || doc.data() == null) return null;
    return AttendanceModel.fromMap(doc.id, doc.data()!);
  }

  Stream<AttendanceModel?> streamTodayRecord(String userId) {
    final today = _todayJerusalemYmd();
    final docId = '${userId}_$today';

    return _firestore.collection('attendance').doc(docId).snapshots().map((
      doc,
    ) {
      if (!doc.exists || doc.data() == null) {
        return null;
      }
      return AttendanceModel.fromMap(doc.id, doc.data()!);
    });
  }

  Future<List<AttendanceModel>> fetchHistory(
    String userId, {
    int limit = 30,
  }) async {
    final snapshot = await _firestore
        .collection('attendance')
        .where('userId', isEqualTo: userId)
        .orderBy('date', descending: true)
        .limit(limit)
        .get(const GetOptions(source: Source.server));

    return snapshot.docs
        .map((doc) => AttendanceModel.fromMap(doc.id, doc.data()))
        .toList();
  }

  Future<void> checkIn() async {
    final callable = _functions.httpsCallable('recordAttendance');
    await callable.call(const {
      'action': 'check_in',
      'biometricVerified': true,
    });
  }

  Future<void> checkOut() async {
    final callable = _functions.httpsCallable('recordAttendance');
    await callable.call(const {
      'action': 'check_out',
      'biometricVerified': true,
    });
  }

  Future<List<AttendanceModel>> fetchRosterForDate(String date) async {
    final snapshot = await _firestore
        .collection('attendance')
        .where('date', isEqualTo: date)
        .get(const GetOptions(source: Source.server));
    final docs = snapshot.docs
        .map((doc) => AttendanceModel.fromMap(doc.id, doc.data()))
        .toList();
    docs.sort((a, b) => a.userName.compareTo(b.userName));
    return docs;
  }

  Future<List<AttendanceModel>> fetchMonthlyAttendance(
    String userId,
    int year,
    int month,
  ) async {
    final start =
        '${year.toString().padLeft(4, '0')}-${month.toString().padLeft(2, '0')}-01';
    final nextMonth = month == 12
        ? '${year + 1}-01-01'
        : '${year.toString().padLeft(4, '0')}-${(month + 1).toString().padLeft(2, '0')}-01';

    final snapshot = await _firestore
        .collection('attendance')
        .where('userId', isEqualTo: userId)
        .where('date', isGreaterThanOrEqualTo: start)
        .where('date', isLessThan: nextMonth)
        .orderBy('date', descending: false)
        .get(const GetOptions(source: Source.server));

    return snapshot.docs
        .map((doc) => AttendanceModel.fromMap(doc.id, doc.data()))
        .toList();
  }

  Future<void> adminResetDay({
    required String userId,
    required String date,
    String? reason,
  }) async {
    final callable = _functions.httpsCallable('adminResetAttendance');
    await callable.call({
      'userId': userId,
      'date': date,
      if (reason != null) 'reason': reason,
    });
  }

  Future<void> adminCorrect({
    required String userId,
    required String date,
    required List<Map<String, dynamic>> sessions,
    String? notes,
  }) async {
    final callable = _functions.httpsCallable('adminCorrectAttendance');
    await callable.call({
      'userId': userId,
      'date': date,
      'sessions': sessions,
      if (notes != null) 'notes': notes,
    });
  }

  String _todayJerusalemYmd() {
    // Matches backend phase assumptions (Jerusalem UTC+3 approximation).
    final nowJerusalem = DateTime.now().toUtc().add(const Duration(hours: 3));
    return DateFormat('yyyy-MM-dd').format(nowJerusalem);
  }
}
