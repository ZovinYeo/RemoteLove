import Foundation
import UserNotifications

final class RemoteLoveNotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
    weak var store: RemoteLoveStore?

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .sound]
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let actionIdentifier = response.actionIdentifier
        let userInfo = response.notification.request.content.userInfo

        Task { @MainActor in
            store?.handleNotificationResponse(actionIdentifier: actionIdentifier, userInfo: userInfo)
            completionHandler()
        }
    }
}

struct RemoteLoveLocalNotification {
    let identifier: String
    let title: String
    let body: String
    let date: Date
    var categoryIdentifier: String?
    var userInfo: [String: String] = [:]
    var sound: UNNotificationSound = .default
}

enum RemoteLoveNotificationScheduler {
    private static let notificationPrefix = "RemoteLove.local."
    static let taskStandardCategory = "REMOTELOVE_TASK_STANDARD"
    static let taskPhotoCategory = "REMOTELOVE_TASK_PHOTO"
    static let taskAttendingCategory = "REMOTELOVE_TASK_ATTENDING"
    static let actionAttending = "REMOTELOVE_TASK_ATTENDING_ACTION"
    static let actionDone = "REMOTELOVE_TASK_DONE_ACTION"
    static let actionOpenTask = "REMOTELOVE_TASK_OPEN_ACTION"

    static func registerActionCategories() {
        configureCategories(center: UNUserNotificationCenter.current())
    }

    static func requestAuthorizationIfNeeded() async -> Bool {
        let center = UNUserNotificationCenter.current()
        registerActionCategories()
        let settings = await notificationSettings(center: center)

        switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            return true
        case .denied:
            return false
        case .notDetermined:
            do {
                return try await center.requestAuthorization(options: [.alert, .sound, .badge])
            } catch {
                return false
            }
        @unknown default:
            return false
        }
    }

    static func replaceScheduledCareReminders(with notifications: [RemoteLoveLocalNotification]) async {
        guard await requestAuthorizationIfNeeded() else { return }

        let center = UNUserNotificationCenter.current()
        let pending = await pendingNotificationRequests(center: center)
        let existingRemoteLoveIDs = pending
            .map(\.identifier)
            .filter { $0.hasPrefix(notificationPrefix) }

        center.removePendingNotificationRequests(withIdentifiers: existingRemoteLoveIDs)

        for notification in notifications where notification.date > Date() {
            await schedule(notification, center: center)
        }
    }

    @discardableResult
    static func sendImmediate(title: String, body: String, identifier: String = UUID().uuidString) async -> Bool {
        guard await requestAuthorizationIfNeeded() else { return false }
        let notification = RemoteLoveLocalNotification(
            identifier: notificationPrefix + "immediate." + identifier,
            title: title,
            body: body,
            date: Date().addingTimeInterval(2)
        )
        return await schedule(notification, center: UNUserNotificationCenter.current())
    }

    static func sendAttendingTaskNotification(taskID: UUID, recipientID: UUID, scheduledAt: Date, title: String, body: String) async {
        guard await requestAuthorizationIfNeeded() else { return }
        let notification = RemoteLoveLocalNotification(
            identifier: taskIdentifier(taskID: taskID, date: scheduledAt, kind: "attending"),
            title: title,
            body: body,
            date: Date().addingTimeInterval(1),
            categoryIdentifier: taskAttendingCategory,
            userInfo: taskUserInfo(taskID: taskID, recipientID: recipientID, scheduledAt: scheduledAt, requiresPhoto: false)
        )
        await schedule(notification, center: UNUserNotificationCenter.current())
    }

    static func cancelTaskNotifications(taskID: UUID) {
        cancelNotifications(matching: ".task.\(taskID.uuidString).")
    }

    static func clearTaskNotifications(taskID: UUID) {
        let token = ".task.\(taskID.uuidString)."
        Task {
            let center = UNUserNotificationCenter.current()
            let pending = await pendingNotificationRequests(center: center)
            let pendingIDs = pending
                .map(\.identifier)
                .filter { $0.hasPrefix(notificationPrefix) && $0.contains(token) }
            center.removePendingNotificationRequests(withIdentifiers: pendingIDs)
            let delivered = await deliveredNotifications(center: center)
            let deliveredIDs = delivered
                .map(\.request.identifier)
                .filter { $0.hasPrefix(notificationPrefix) && $0.contains(token) }
            center.removeDeliveredNotifications(withIdentifiers: deliveredIDs)
        }
    }

    static func cancelAppointmentNotifications(appointmentID: UUID) {
        cancelNotifications(matching: ".appointment.\(appointmentID.uuidString).")
    }

    static func cancelAllRemoteLoveNotifications() async {
        let center = UNUserNotificationCenter.current()
        let pending = await pendingNotificationRequests(center: center)
        let identifiers = pending
            .map(\.identifier)
            .filter { $0.hasPrefix(notificationPrefix) }
        center.removePendingNotificationRequests(withIdentifiers: identifiers)
    }

    static func taskIdentifier(taskID: UUID, date: Date, kind: String) -> String {
        notificationPrefix + "task.\(taskID.uuidString).\(kind).\(dateToken(for: date))"
    }

    static func medicineIdentifier(medicineID: UUID, date: Date) -> String {
        notificationPrefix + "medicine.\(medicineID.uuidString).\(dateToken(for: date))"
    }

    static func appointmentIdentifier(appointmentID: UUID, date: Date, kind: String) -> String {
        notificationPrefix + "appointment.\(appointmentID.uuidString).\(kind).\(dateToken(for: date))"
    }

    static func taskUserInfo(taskID: UUID, recipientID: UUID, scheduledAt: Date, requiresPhoto: Bool) -> [String: String] {
        [
            "kind": "task",
            "taskID": taskID.uuidString,
            "recipientID": recipientID.uuidString,
            "scheduledAt": String(scheduledAt.timeIntervalSince1970),
            "requiresPhoto": requiresPhoto ? "true" : "false"
        ]
    }

    @discardableResult
    private static func schedule(_ notification: RemoteLoveLocalNotification, center: UNUserNotificationCenter) async -> Bool {
        let content = UNMutableNotificationContent()
        content.title = notification.title
        content.body = notification.body
        content.sound = notification.sound
        if let categoryIdentifier = notification.categoryIdentifier {
            content.categoryIdentifier = categoryIdentifier
        }
        content.userInfo = notification.userInfo

        let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute, .second], from: notification.date)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        let request = UNNotificationRequest(identifier: notification.identifier, content: content, trigger: trigger)

        do {
            try await center.add(request)
            return true
        } catch {
            // Keep notification scheduling best-effort so care data changes never fail because alerts could not be scheduled.
            return false
        }
    }

    private static func cancelNotifications(matching token: String) {
        Task {
            let center = UNUserNotificationCenter.current()
            let pending = await pendingNotificationRequests(center: center)
            let identifiers = pending
                .map(\.identifier)
                .filter { $0.hasPrefix(notificationPrefix) && $0.contains(token) }
            center.removePendingNotificationRequests(withIdentifiers: identifiers)
        }
    }

    private static func configureCategories(center: UNUserNotificationCenter) {
        let attending = UNNotificationAction(
            identifier: actionAttending,
            title: "Attending",
            options: []
        )
        let done = UNNotificationAction(
            identifier: actionDone,
            title: "Done",
            options: []
        )
        let openTask = UNNotificationAction(
            identifier: actionOpenTask,
            title: "Open task",
            options: [.foreground]
        )

        let standardTask = UNNotificationCategory(
            identifier: taskStandardCategory,
            actions: [done, attending],
            intentIdentifiers: [],
            options: []
        )
        let photoTask = UNNotificationCategory(
            identifier: taskPhotoCategory,
            actions: [openTask],
            intentIdentifiers: [],
            options: []
        )
        let attendingTask = UNNotificationCategory(
            identifier: taskAttendingCategory,
            actions: [done],
            intentIdentifiers: [],
            options: []
        )

        center.setNotificationCategories([standardTask, photoTask, attendingTask])
    }

    private static func notificationSettings(center: UNUserNotificationCenter) async -> UNNotificationSettings {
        await withCheckedContinuation { continuation in
            center.getNotificationSettings { settings in
                continuation.resume(returning: settings)
            }
        }
    }

    private static func pendingNotificationRequests(center: UNUserNotificationCenter) async -> [UNNotificationRequest] {
        await withCheckedContinuation { continuation in
            center.getPendingNotificationRequests { requests in
                continuation.resume(returning: requests)
            }
        }
    }

    private static func deliveredNotifications(center: UNUserNotificationCenter) async -> [UNNotification] {
        await withCheckedContinuation { continuation in
            center.getDeliveredNotifications { notifications in
                continuation.resume(returning: notifications)
            }
        }
    }

    private static func dateToken(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyyMMddHHmm"
        return formatter.string(from: date)
    }
}
