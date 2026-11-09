import Foundation
import UserNotifications

/// User Notifications (SPEC §10): alert-only authorization, banners even while the app is
/// frontmost, no sound (the app plays its own). Denied authorization means silence, no dialogs.
final class Notifier: NSObject, UNUserNotificationCenterDelegate {
    private let center = UNUserNotificationCenter.current()
    private let log: (String) -> Void
    private var requested = false

    init(log: @escaping (String) -> Void) {
        self.log = log
        super.init()
        center.delegate = self
    }

    /// Asks once per launch; macOS shows its dialog only the first time ever.
    func requestAuthorizationIfNeeded() {
        guard !requested else { return }
        requested = true
        center.requestAuthorization(options: [.alert]) { [log] granted, error in
            if let error { log("Notifications: authorization error: \(error.localizedDescription)") }
            else if !granted { log("Notifications: not authorized") }
        }
    }

    func notify(title: String, body: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        center.add(request) { [log] error in
            if let error { log("Notifications: delivery error: \(error.localizedDescription)") }
        }
    }

    // Show banners while the app is in the foreground too.
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .list])
    }
}
