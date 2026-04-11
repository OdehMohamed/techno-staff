import 'package:flutter_bloc/flutter_bloc.dart';
import '../../data/models/in_app_notification_model.dart';
import '../../data/repositories/notifications_repository.dart';

class NotificationsState {
  final List<InAppNotificationModel> notifications;
  final int unreadCount;
  final bool isLoading;

  NotificationsState({
    this.notifications = const [],
    this.unreadCount = 0,
    this.isLoading = false,
  });

  NotificationsState copyWith({
    List<InAppNotificationModel>? notifications,
    int? unreadCount,
    bool? isLoading,
  }) {
    return NotificationsState(
      notifications: notifications ?? this.notifications,
      unreadCount: unreadCount ?? this.unreadCount,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

class NotificationsCubit extends Cubit<NotificationsState> {
  final NotificationsRepository _repository;

  NotificationsCubit(this._repository) : super(NotificationsState());

  Future<void> loadNotifications(String userId) async {
    emit(state.copyWith(isLoading: true));

    final notifications = await _repository.getNotifications(userId);
    final unread = await _repository.getUnreadCount(userId);

    emit(
      state.copyWith(
        notifications: notifications,
        unreadCount: unread,
        isLoading: false,
      ),
    );
  }

  Future<void> markAsRead(String id, String userId) async {
    await _repository.markAsRead(id);
    await loadNotifications(userId);
  }
}
