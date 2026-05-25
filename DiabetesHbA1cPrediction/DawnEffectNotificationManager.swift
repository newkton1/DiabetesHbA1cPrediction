import Foundation
import UserNotifications

/// Manages local notifications for dawn effect pattern detection.
/// Notifications are informational and educational — they describe a pattern
/// observed in the user's glucose data, not a diagnosis.
enum DawnEffectNotificationManager {

    private static let lastNotifiedKey = "dawnEffectLastNotifiedDate"

    /// Schedules a local notification if one hasn't been sent in the last 7 days.
    /// This prevents notification fatigue while still informing the user when the
    /// pattern is first detected or re-emerges after a quiet period.
    static func scheduleIfNeeded() {
        let lastNotified = UserDefaults.standard.object(forKey: lastNotifiedKey) as? Date ?? .distantPast
        let daysSinceLast = Calendar.current.dateComponents([.day], from: lastNotified, to: Date()).day ?? 999

        // Only notify once per 7 days
        guard daysSinceLast >= 7 else { return }

        let content = UNMutableNotificationContent()
        content.title = "Morning Glucose Pattern"
        content.body = "Your glucose readings between 4–8 AM have been consistently higher than overnight on several recent days, with no meals logged beforehand. This pattern is sometimes called the \"dawn effect\" and is common in people with diabetes. Open Diabetes Feast for more details."
        content.sound = .default

        // Deliver after a short delay (not time-critical)
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 5, repeats: false)
        let request = UNNotificationRequest(
            identifier: "dawnEffectPattern-\(UUID().uuidString)",
            content: content,
            trigger: trigger
        )

        let key = lastNotifiedKey
        UNUserNotificationCenter.current().add(request) { error in
            if error == nil {
                UserDefaults.standard.set(Date(), forKey: key)
            }
            #if DEBUG
            if let error = error {
                print("Dawn effect notification error: \(error.localizedDescription)")
            } else {
                print("Dawn effect notification scheduled successfully")
            }
            #endif
        }
    }
}
