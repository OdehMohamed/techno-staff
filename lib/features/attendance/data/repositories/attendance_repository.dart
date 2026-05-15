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
        .get();

    return snapshot.docs
        .map((doc) => AttendanceModel.fromMap(doc.id, doc.data()))
        .toList();
  }

  Future<void> checkIn() async {
    final callable = _functions.httpsCallable('recordAttendance');
    await callable.call(const {'action': 'check_in', 'biometricVerified': true});
  }

  Future<void> checkOut() async {
    final callable = _functions.httpsCallable('recordAttendance');
    await callable.call(const {'action': 'check_out', 'biometricVerified': true});
  }

  String _todayJerusalemYmd() {
    // Matches backend phase assumptions (Jerusalem UTC+3 approximation).
    final nowJerusalem = DateTime.now().toUtc().add(const Duration(hours: 3));
    return DateFormat('yyyy-MM-dd').format(nowJerusalem);
  }
}
