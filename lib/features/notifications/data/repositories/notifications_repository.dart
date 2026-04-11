import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/in_app_notification_model.dart';

class NotificationsRepository {
  final FirebaseFirestore _firestore;

  NotificationsRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  Future<List<InAppNotificationModel>> getNotifications(String userId) async {
    final snapshot = await _firestore
        .collection('notifications')
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .limit(30)
        .get();

    return snapshot.docs
        .map((doc) => InAppNotificationModel.fromMap(doc.id, doc.data()))
        .toList();
  }

  Future<int> getUnreadCount(String userId) async {
    final snapshot = await _firestore
        .collection('notifications')
        .where('userId', isEqualTo: userId)
        .where('isRead', isEqualTo: false)
        .get();

    return snapshot.docs.length;
  }

  Future<void> markAsRead(String notificationId) async {
    await _firestore.collection('notifications').doc(notificationId).update({
      'isRead': true,
    });
  }

  Stream<List<InAppNotificationModel>> streamNotifications(String userId) {
    return _firestore
        .collection('notifications')
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .limit(30)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((doc) => InAppNotificationModel.fromMap(doc.id, doc.data()))
              .toList();
        });
  }
}
