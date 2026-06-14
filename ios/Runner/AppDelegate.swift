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

    // Force THIS AppDelegate to own the notification-center delegate so our
    // willPresent override below is the method iOS actually invokes. Without
    // this, firebase_messaging or flutter_local_notifications can register
    // themselves as the delegate during plugin registration, in which case our
    // per-conversation suppression never runs and every banner is shown.
    // FlutterAppDelegate's own UNUserNotificationCenterDelegate methods forward
    // to the registered plugins, so calling `super` from our overrides keeps
    // firebase_messaging's foreground/tap handling working.
    UNUserNotificationCenter.current().delegate = self

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  /// Per-conversation foreground notification suppression.
  ///
  /// On iOS, firebase_messaging presents FCM banners natively in the foreground
  /// (configured via `setForegroundNotificationPresentationOptions(alert: true)`
  /// in Dart). Because that presentation happens before Dart's `onMessage` can
  /// intervene, the per-conversation suppression has to be decided here, in the
  /// native delegate, before deciding whether to forward to firebase_messaging.
  ///
  /// ConversationCubit writes the open conversation id to `UserDefaults` via
  /// `shared_preferences` on enter and removes it on exit. The legacy
  /// `SharedPreferences` API stores keys under the `flutter.` prefix, but we read
  /// both variants defensively so a prefix change in the plugin can't silently
  /// break suppression.
  override func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    willPresent notification: UNNotification,
    withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
  ) {
    let request = notification.request

    guard request.trigger is UNPushNotificationTrigger else {
      // Local notification (flutter_local_notifications) — present directly.
      completionHandler([.alert, .sound, .badge])
      return
    }

    // FCM push in the foreground. FCM places `data` fields at the top level of
    // userInfo, so the conversation id is read directly. The legacy
    // shared_preferences API stores keys under the `flutter.` prefix; the
    // unprefixed key is read as a defensive fallback.
    let userInfo = request.content.userInfo
    let incomingConvId = userInfo["conversationId"] as? String
    let activeConvId =
      UserDefaults.standard.string(forKey: "flutter.active_conversation_id")
      ?? UserDefaults.standard.string(forKey: "active_conversation_id")

    if let incomingConvId = incomingConvId,
       let activeConvId = activeConvId,
       incomingConvId == activeConvId {
      // User already has this conversation open — suppress the banner.
      completionHandler([])
    } else {
      // Different conversation or a task notification — let firebase_messaging
      // present the banner using the alert:true foreground option.
      super.userNotificationCenter(
        center, willPresent: notification, withCompletionHandler: completionHandler)
    }
  }
}
