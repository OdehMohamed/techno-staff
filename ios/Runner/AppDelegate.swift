import Flutter
import UIKit
import UserNotifications

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  /// Controls foreground notification presentation for both FCM and local
  /// notifications.
  ///
  /// For remote (FCM) push notifications we call super with a no-op handler so
  /// that FlutterAppDelegate forwards the event to all registered plugins
  /// (firebase_messaging fires onMessage in Dart; flutter_local_notifications
  /// is also notified). We then call the real completion handler with empty
  /// options to suppress the native banner — Dart's onMessage handler decides
  /// whether to display a local notification, which gives us active-conversation
  /// suppression on iOS.
  ///
  /// For local notifications created by flutter_local_notifications we skip
  /// the plugin forwarding (no plugin needs to intercept them here) and call
  /// the completion handler directly to show the banner and play sound.
  override func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    willPresent notification: UNNotification,
    withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
  ) {
    if notification.request.trigger is UNPushNotificationTrigger {
      // Remote notification: dispatch to plugins via super (fires onMessage),
      // then suppress native display so Dart owns the decision.
      super.userNotificationCenter(
        center, willPresent: notification, withCompletionHandler: { _ in })
      completionHandler([])
    } else {
      // Local notification from flutter_local_notifications: show it.
      completionHandler([.banner, .list, .sound])
    }
  }
}
