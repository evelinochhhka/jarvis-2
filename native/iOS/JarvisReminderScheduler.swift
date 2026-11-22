import Foundation
import UserNotifications
import JarvisCore

struct JarvisReminderScheduler {
    enum SchedulerError: Error {
        case dateMustBeInFuture
        case permissionDenied
    }

    func schedule(_ entry: JarvisWorkspaceEntry) async throws {
        guard let reminder = entry.reminder else { return }
        if reminder.repeatFrequency == .none && reminder.date <= .now {
            throw SchedulerError.dateMustBeInFuture
        }

        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        let granted: Bool
        if settings.authorizationStatus == .notDetermined {
            granted = try await center.requestAuthorization(options: [.alert, .sound, .badge])
        } else {
            granted = settings.authorizationStatus == .authorized
                || settings.authorizationStatus == .provisional
                || settings.authorizationStatus == .ephemeral
        }
        guard granted else { throw SchedulerError.permissionDenied }

        var components = Calendar.current.dateComponents(
            [.year, .month, .day, .hour, .minute, .weekday],
            from: reminder.date
        )
        let repeats: Bool
        switch reminder.repeatFrequency {
        case .none:
            repeats = false
        case .daily:
            components = Calendar.current.dateComponents([.hour, .minute], from: reminder.date)
            repeats = true
        case .weekly:
            components = Calendar.current.dateComponents([.weekday, .hour, .minute], from: reminder.date)
            repeats = true
        case .monthly:
            components = Calendar.current.dateComponents([.day, .hour, .minute], from: reminder.date)
            repeats = true
        }

        let content = UNMutableNotificationContent()
        content.title = "JARVIS"
        content.body = entry.title
        content.sound = .default
        content.threadIdentifier = "jarvis-reminders"

        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: repeats)
        let request = UNNotificationRequest(
            identifier: entry.id.uuidString,
            content: content,
            trigger: trigger
        )
        try await center.add(request)
    }

    func cancel(entryID: UUID) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(
            withIdentifiers: [entryID.uuidString]
        )
    }
}
