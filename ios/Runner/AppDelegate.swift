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

  /// Controls foreground notification presentation for FCM and local notifications.
  ///
  /// Remote (FCM/push) notifications: the real completionHandler is forwarded to
  /// super so FlutterAppDelegate dispatches it to all plugin delegates.
  /// firebase_messaging's plugin calls the handler with the options configured by
  /// setForegroundNotificationPresentationOptions (set to all-off in Dart), so
  /// completionHandler([]) is called and no native banner is shown. onMessage
  /// fires in Dart, which applies the active-conversation check and calls
  /// flutter_local_notifications when the notification should be displayed.
  ///
  /// Local notifications (scheduled by flutter_local_notifications): the handler
  /// is called directly with banner+sound so they always display correctly.
  override func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    willPresent notification: UNNotification,
    withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
  ) {
    if notification.request.trigger is UNPushNotificationTrigger {
      super.userNotificationCenter(
        center, willPresent: notification, withCompletionHandler: completionHandler)
    } else {
      completionHandler([.banner, .list, .sound])
    }
  }
}
