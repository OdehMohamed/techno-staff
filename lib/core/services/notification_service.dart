import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  NotificationService._();

  static final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  static const AndroidNotificationChannel _taskChannel =
      AndroidNotificationChannel(
    'task_notifications',
    'Task Notifications',
    description: 'Notifications for assigned tasks',
    importance: Importance.high,
  );

  static const AndroidNotificationChannel _chatChannel =
      AndroidNotificationChannel(
    'chat_messages',
    'Chat Messages',
    description: 'Notifications for new chat messages',
    importance: Importance.high,
  );

  static Future<void> initialize({
    void Function(String payload)? onNotificationTap,
  }) async {
    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );

    const iosSettings = DarwinInitializationSettings();

    const initializationSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _localNotifications.initialize(
      settings: initializationSettings,
      onDidReceiveNotificationResponse: (response) {
        final payload = response.payload;
        if (payload != null && onNotificationTap != null) {
          onNotificationTap(payload);
        }
      },
    );

    final androidPlugin = _localNotifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    await androidPlugin?.createNotificationChannel(_taskChannel);
    await androidPlugin?.createNotificationChannel(_chatChannel);
  }

  /// Shows a local notification for a foreground FCM message (Android only).
  ///
  /// On iOS, foreground presentation is handled natively by AppDelegate; this
  /// method is not called on that platform (see the `onMessage` listener in
  /// main.dart).
  ///
  /// Chat notifications use the [_chatChannel] and encode the conversationId
  /// as `conv:<id>` in the payload. Task notifications use [_taskChannel] and
  /// encode the raw taskId. The [onNotificationTap] callback in main.dart
  /// inspects the prefix to route correctly.
  static Future<void> showForegroundNotification(RemoteMessage message) async {
    final notification = message.notification;
    // Fall back to the data fields the Cloud Function also writes, in case
    // firebase_messaging delivers onMessage with notification == null.
    final title = notification?.title ?? message.data['notificationTitle'];
    final body = notification?.body ?? message.data['notificationBody'];

    if (title == null && body == null) return;

    final conversationId = message.data['conversationId'];
    final taskId = message.data['taskId'];
    final paymentId = message.data['paymentId'];
    final notifType = message.data['type'] as String?;

    final isChat = conversationId != null;
    final isPayment = notifType == 'payment_recorded' && paymentId != null;
    final channel = isChat ? _chatChannel : _taskChannel;
    final String? payload;
    if (isChat) {
      payload = 'conv:$conversationId';
    } else if (isPayment) {
      payload = 'pay:$paymentId';
    } else {
      payload = taskId;
    }

    await _localNotifications.show(
      id: message.hashCode,
      title: title,
      body: body,
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          channel.id,
          channel.name,
          channelDescription: channel.description,
          importance: Importance.high,
          priority: Priority.high,
        ),
      ),
      payload: payload,
    );
  }
}
