import Foundation
import UserNotifications

enum NotificationManager {
    static let center = UNUserNotificationCenter.current()
    static let dailyIds = ["daily_event_reminder_0250", "daily_event_reminder_2150"]

    static func requestAuthorization() async -> Bool {
        do {
            return try await center.requestAuthorization(options: [.alert, .sound, .badge])
        } catch {
            print("Notification authorization error: \(error)")
            return false
        }
    }

    static func notificationsEnabled() async -> Bool {
        let settings = await center.notificationSettings()
        return settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional
    }

    static func scheduleDailyReminders() async {
        // Remove existing to avoid duplicates
        await removeDailyReminders()

        let trTimeZone = TimeZone(identifier: "Europe/Istanbul") ?? .current
        let times: [(id: String, hour: Int, minute: Int)] = [
            (dailyIds[0], 2, 50),
            (dailyIds[1], 21, 50)
        ]

        for t in times {
            let content = UNMutableNotificationContent()
            content.title = "Etkinlik yaklaşıyor!"
            content.body = "FT etkinliğini kaçırma — zamanlayıcılarını hazırla."
            content.sound = .default

            var comps = DateComponents()
            comps.timeZone = trTimeZone
            comps.hour = t.hour
            comps.minute = t.minute

            let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: true)
            let req = UNNotificationRequest(identifier: t.id, content: content, trigger: trigger)
            do { try await center.add(req) } catch { print("Schedule error: \(error)") }
        }
    }

    static func removeDailyReminders() async {
         center.removePendingNotificationRequests(withIdentifiers: dailyIds)
    }

    static func scheduleOneOffTestNotification(after seconds: TimeInterval = 5) async {
        let content = UNMutableNotificationContent()
        content.title = "Test Bildirimi"
        content.body = "Bu bir test bildirimi. Her şey çalışıyor!"
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: seconds, repeats: false)
        let request = UNNotificationRequest(identifier: "oneoff_test_\(UUID().uuidString)", content: content, trigger: trigger)
        do { try await center.add(request) } catch { print("Test schedule error: \(error)") }
    }
}
