import Foundation
import SwiftUI

enum UserRole: String, Codable, Equatable {
    case owner
    case family
    case helper
    case viewer

    var canManageCare: Bool {
        self == .owner || self == .family
    }

    var canEditCareRecords: Bool {
        self == .owner || self == .family
    }

    var isFamilyExperience: Bool {
        self != .helper
    }
}

struct PasswordPolicy {
    static let minimumLength = 8

    static func hasMinimumLength(_ password: String) -> Bool {
        password.count >= minimumLength
    }

    static func hasUppercaseLetter(_ password: String) -> Bool {
        password.rangeOfCharacter(from: .uppercaseLetters) != nil
    }

    static func hasLowercaseLetter(_ password: String) -> Bool {
        password.rangeOfCharacter(from: .lowercaseLetters) != nil
    }

    static func hasNumber(_ password: String) -> Bool {
        password.rangeOfCharacter(from: .decimalDigits) != nil
    }

    static func hasSpecialCharacter(_ password: String) -> Bool {
        password.unicodeScalars.contains { scalar in
            !CharacterSet.alphanumerics.contains(scalar) && !CharacterSet.whitespacesAndNewlines.contains(scalar)
        }
    }

    static func isValid(_ password: String) -> Bool {
        hasMinimumLength(password)
            && hasUppercaseLetter(password)
            && hasLowercaseLetter(password)
            && hasNumber(password)
            && hasSpecialCharacter(password)
    }
}

enum CaregiverMode: String, Codable, CaseIterable, Identifiable, Hashable {
    case helperOnly = "helper_only"
    case familyOnly = "family_only"
    case both = "both"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .helperOnly:
            return "Helper only"
        case .familyOnly:
            return "Family only"
        case .both:
            return "Family and helper"
        }
    }

    var detail: String {
        switch self {
        case .helperOnly:
            return "Helpers complete daily tasks. Family members manage and monitor."
        case .familyOnly:
            return "Family members complete daily tasks. Helper access can stay unused."
        case .both:
            return "Both family members and helpers can complete daily tasks."
        }
    }

    var allowsFamilyCompletion: Bool {
        self == .familyOnly || self == .both
    }

    var allowsHelperCompletion: Bool {
        self == .helperOnly || self == .both
    }
}

enum NotificationMutePreset: String, CaseIterable, Identifiable, Hashable {
    case today
    case threeDays
    case week
    case month
    case forever
    case custom

    var id: String { rawValue }

    var title: String {
        switch self {
        case .today:
            return "Mute for today"
        case .threeDays:
            return "Mute for 3 days"
        case .week:
            return "Mute for a week"
        case .month:
            return "Mute for a month"
        case .forever:
            return "Mute forever"
        case .custom:
            return "Custom"
        }
    }
}

enum AppRoute: Equatable {
    case restoringSession
    case welcome
    case familyAuthentication
    case familyGettingStarted
    case createCareSetup
    case joinFamilyCareCircle
    case helperJoin
    case helperPinLock
    case familyApp
    case helperApp
}

enum MainTab: String, Codable, Hashable {
    case overview
    case care
    case planner
    case health
    case more
    case helperToday
    case helperTasks
    case updates
    case history
    case settings
}

enum AppDestination: Hashable {
    case overview(recipientID: UUID?)
    case task(recipientID: UUID, taskID: UUID)
    case medicine(recipientID: UUID, medicineID: UUID)
    case appointment(recipientID: UUID, appointmentID: UUID)
    case health(recipientID: UUID, category: String?)
    case member(recipientID: UUID, membershipID: UUID)
    case history(recipientID: UUID?, eventID: UUID?)
    case emergency(recipientID: UUID, alertID: UUID?)
}

enum TaskState: String, Codable, CaseIterable, Hashable {
    case pending
    case attending
    case done
    case paused

    var label: String {
        switch self {
        case .pending: return "To do"
        case .attending: return "Attending now"
        case .done: return "Done"
        case .paused: return "Paused"
        }
    }
}

struct CareRecipient: Identifiable, Codable, Hashable {
    var id: UUID
    var name: String
    var label: String
    var age: Int
    var relationship: String
    var lastUpdated: Date

    var initials: String {
        name.split(separator: " ").prefix(2).compactMap { $0.first }.map(String.init).joined()
    }
}

struct CareProfileInput: Identifiable, Hashable {
    var id = UUID()
    var name: String
    var label: String
    var age: Int
    var relationship: String

    var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var normalizedLabel: String {
        label.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? "Family"
            : label.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var normalizedRelationship: String {
        relationship.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? "Family"
            : relationship.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func starter(index: Int = 0) -> CareProfileInput {
        return CareProfileInput(
            name: "",
            label: "",
            age: 0,
            relationship: ""
        )
    }
}

struct CareTask: Identifiable, Codable, Hashable {
    var id: UUID
    var recipientID: UUID
    var title: String
    var instructions: String
    var scheduledAt: Date
    var frequency: String
    var requiresPhoto: Bool
    var state: TaskState
    var notifiedAt: Date?
    var medicineID: UUID?
}

struct TaskUndoEntry: Identifiable, Hashable {
    let id = UUID()
    let date: Date
    let scope: TaskHistoryScope
    let message: String
    let tasksBefore: [CareTask]
    let tasksAfter: [CareTask]
}

enum TaskHistoryScope: String, Codable, Hashable, CaseIterable, Identifiable {
    case singleDate
    case futureRoutine

    var id: String { rawValue }

    var title: String {
        switch self {
        case .singleDate:
            return "This date"
        case .futureRoutine:
            return "Future routine"
        }
    }
}

struct Medicine: Identifiable, Codable, Hashable {
    var id: UUID
    var recipientID: UUID
    var name: String
    var purpose: String
    var instructions: String
    var currentSupply: Double
    var dose: Double
    var unit: String
    var timesDaily: Int
    var intervalDays: Int
    var attentionDays: Int
    var active: Bool
    var firstTime: Date
    var doseTimes: [Date]? = nil
    var repeatWeekdays: [Int]? = nil

    var daysRemaining: Int {
        guard active, dose > 0, timesDaily > 0 else { return 0 }
        let doses = currentSupply / dose
        if intervalDays > 1 { return max(0, Int(doses.rounded(.down))) * intervalDays }
        return max(0, Int(ceil(doses / Double(timesDaily))))
    }

    var scheduledDoseTimes: [Date] {
        let expectedCount = max(timesDaily, 1)
        let explicitTimes = (doseTimes ?? [])
            .prefix(expectedCount)
            .sorted { $0 < $1 }

        if explicitTimes.isEmpty == false {
            return Array(explicitTimes)
        }

        return (0..<expectedCount).compactMap { index in
            Calendar.current.date(byAdding: .hour, value: index * 4, to: firstTime)
        }
    }
}

enum AppointmentState: String, Codable, Hashable {
    case scheduled
    case cancelled
}

struct CareAppointment: Identifiable, Codable, Hashable {
    var id: UUID
    var recipientID: UUID
    var title: String
    var date: Date
    var notes: String
    var repeatRule: String
    var remindThreeDaysBefore: Bool
    var reminderEnabled: Bool = true
    var reminderDaysBefore: Int = 3
    var reminderCount: Int = 1
    var state: AppointmentState
}

struct PlannerOtherItem: Identifiable, Codable, Hashable {
    var id: UUID
    var recipientID: UUID
    var title: String
    var date: Date
    var notes: String
    var repeatRule: String
    var active: Bool
}

enum ReminderTimingOption: String, CaseIterable, Identifiable, Hashable {
    case atTime
    case tenMinutesBefore
    case thirtyMinutesBefore
    case oneHourBefore
    case oneDayBefore
    case threeDaysBefore
    case custom

    var id: String { rawValue }

    var title: String {
        switch self {
        case .atTime: return "At time"
        case .tenMinutesBefore: return "10 min before"
        case .thirtyMinutesBefore: return "30 min before"
        case .oneHourBefore: return "1 hour before"
        case .oneDayBefore: return "1 day before"
        case .threeDaysBefore: return "3 days before"
        case .custom: return "Custom"
        }
    }

    var daysBefore: Int? {
        switch self {
        case .oneDayBefore: return 1
        case .threeDaysBefore: return 3
        default: return nil
        }
    }
}

enum ReminderRepeatOption: String, CaseIterable, Identifiable, Hashable {
    case none
    case everyThirtyMinutes
    case everyHour
    case everyDay

    var id: String { rawValue }

    var title: String {
        switch self {
        case .none: return "Don't repeat"
        case .everyThirtyMinutes: return "Every 30 min"
        case .everyHour: return "Every hour"
        case .everyDay: return "Every day"
        }
    }
}

enum ReminderRecipientOption: String, CaseIterable, Identifiable, Hashable {
    case family
    case helpers
    case everyone

    var id: String { rawValue }

    var title: String {
        switch self {
        case .family: return "Family"
        case .helpers: return "Helpers"
        case .everyone: return "Everyone"
        }
    }
}

enum HealthCategory: String, Codable, CaseIterable, Identifiable, Hashable {
    case weight
    case bloodPressure
    case bloodSugar
    case heartRate
    case temperature
    case oxygen
    case mobility
    case diet
    case hydration
    case sleep

    var id: String { rawValue }

    var label: String {
        switch self {
        case .weight: return "Weight"
        case .bloodPressure: return "Blood pressure"
        case .bloodSugar: return "Blood sugar"
        case .heartRate: return "Heart rate"
        case .temperature: return "Temperature"
        case .oxygen: return "Blood oxygen"
        case .mobility: return "Mobility"
        case .diet: return "Diet quality"
        case .hydration: return "Hydration"
        case .sleep: return "Sleep"
        }
    }

    var unit: String {
        switch self {
        case .weight: return "kg"
        case .bloodPressure: return "mmHg"
        case .bloodSugar: return "mmol/L"
        case .heartRate: return "bpm"
        case .temperature: return "°C"
        case .oxygen: return "%"
        case .mobility: return "min"
        case .diet: return "/ 5"
        case .hydration: return "glasses"
        case .sleep: return "hours"
        }
    }

    var prompt: String {
        switch self {
        case .weight: return "What is their current weight?"
        case .bloodPressure: return "What is their systolic blood pressure?"
        case .bloodSugar: return "What is their blood sugar reading?"
        case .heartRate: return "What is their heart rate?"
        case .temperature: return "What is their body temperature?"
        case .oxygen: return "What is their blood oxygen level?"
        case .mobility: return "How many minutes were they mobile?"
        case .diet: return "How was their diet quality today?"
        case .hydration: return "How many glasses of water did they drink?"
        case .sleep: return "How many hours did they sleep?"
        }
    }

    func reference(for age: Int) -> String {
        switch self {
        case .bloodPressure:
            if age < 40 { return "Typical reference: below 120/80 mmHg" }
            if age < 60 { return "Typical reference: below 130/80 mmHg" }
            if age < 75 { return "Personal targets vary; often below 140/90 mmHg" }
            return "Targets should be personalised by their clinician"
        case .heartRate: return "Typical resting reference: 60–100 bpm"
        case .temperature: return "Typical reference: about 36.1–37.2°C"
        case .oxygen: return "Typical reference: 95–100%; follow their clinician’s target"
        case .bloodSugar: return "Targets depend on timing, medication and care plan"
        case .diet: return "Aim for regular, balanced meals suited to their care plan"
        case .hydration: return "Fluid needs vary with health conditions and medication"
        case .mobility: return "Use the safe goal agreed with their clinician or therapist"
        case .sleep: return "Many older adults need around 7–8 hours"
        case .weight: return "Track changes over time rather than one reading alone"
        }
    }

    func status(for value: Double, age: Int) -> HealthReadingStatus {
        switch self {
        case .bloodPressure:
            if age >= 75 { return value < 150 ? .good : .watch }
            if age >= 60 { return value < 140 ? .good : (value < 160 ? .watch : .needsAttention) }
            return value < 130 ? .good : (value < 150 ? .watch : .needsAttention)
        case .bloodSugar:
            if value < 4.0 || value >= 10.0 { return .needsAttention }
            if value >= 7.8 { return .watch }
            return .good
        case .heartRate:
            if value < 50 || value > 110 { return .needsAttention }
            if value < 60 || value > 100 { return .watch }
            return .good
        case .temperature:
            if value < 35.5 || value >= 38.0 { return .needsAttention }
            if value >= 37.3 { return .watch }
            return .good
        case .oxygen:
            if value < 92 { return .needsAttention }
            if value < 95 { return .watch }
            return .good
        case .diet:
            if value < 2 { return .needsAttention }
            if value < 3 { return .watch }
            return .good
        case .hydration:
            if value < 4 { return .needsAttention }
            if value < 6 { return .watch }
            return .good
        case .sleep:
            if value < 4 || value > 11 { return .needsAttention }
            if value < 6 || value > 9 { return .watch }
            return .good
        case .mobility:
            if value < 10 { return .watch }
            return .good
        case .weight:
            return .trendOnly
        }
    }
}

enum HealthReadingStatus: String, Codable, Hashable {
    case good
    case watch
    case needsAttention
    case trendOnly

    var label: String {
        switch self {
        case .good: return "Good"
        case .watch: return "Watch"
        case .needsAttention: return "Needs attention"
        case .trendOnly: return "Track trend"
        }
    }

    var summary: String {
        switch self {
        case .good:
            return "Within the app’s general reference range"
        case .watch:
            return "Worth keeping an eye on"
        case .needsAttention:
            return "May need family or clinical follow-up"
        case .trendOnly:
            return "Best understood over time"
        }
    }
}

struct HealthLog: Identifiable, Codable, Hashable {
    var id: UUID
    var recipientID: UUID
    var category: HealthCategory
    var value: Double
    var recordedAt: Date
    var notes: String
}

struct RemoteLoveWidgetSnapshot: Codable, Hashable {
    var updatedAt: Date
    var recipientName: String
    var recipientLabel: String
    var roleName: String
    var completedTaskCount: Int
    var totalTaskCount: Int
    var nextTaskID: UUID?
    var nextTaskRecipientID: UUID?
    var nextTaskTitle: String?
    var nextTaskTime: Date?
    var nextTaskRequiresPhoto: Bool
    var medicineAttentionCount: Int
    var healthAttentionCount: Int
}

struct RemoteLoveWidgetQueuedAction: Codable, Hashable {
    enum Kind: String, Codable, Hashable {
        case completeTask
    }

    var id: UUID
    var kind: Kind
    var taskID: UUID
    var recipientID: UUID
    var scheduledAt: Date
    var createdAt: Date
}

struct CircleMember: Identifiable, Codable, Hashable {
    var id: UUID
    var recipientID: UUID?
    var userID: UUID? = nil
    var name: String
    var role: String
    var permission: String
    var active: Bool
    var joinedAt: Date

    init(id: UUID, recipientID: UUID?, userID: UUID? = nil, name: String, role: String, permission: String, active: Bool, joinedAt: Date) {
        self.id = id
        self.recipientID = recipientID
        self.userID = userID
        self.name = name
        self.role = role
        self.permission = permission
        self.active = active
        self.joinedAt = joinedAt
    }
}

struct ActivityEvent: Identifiable, Codable, Hashable {
    var id: UUID
    var recipientID: UUID
    var actor: String
    var action: String
    var detail: String
    var createdAt: Date
}

struct CareUpdate: Identifiable, Codable, Hashable {
    var id: UUID
    var recipientID: UUID
    var author: String
    var message: String
    var mood: String
    var createdAt: Date
}

enum CarePlan: String, CaseIterable, Identifiable, Codable, Hashable {
    case free
    case plusMonthly
    case plusYearly
    case proMonthly
    case proYearly
    case lifetime

    var id: String { rawValue }

    var name: String {
        switch self {
        case .free: return "Free"
        case .plusMonthly: return "Plus"
        case .plusYearly: return "Plus"
        case .proMonthly: return "Pro"
        case .proYearly: return "Pro"
        case .lifetime: return "Lifetime"
        }
    }

    var billing: String {
        switch self {
        case .free: return "Starter"
        case .plusMonthly, .proMonthly: return "Monthly"
        case .plusYearly, .proYearly: return "Yearly"
        case .lifetime: return "One-time purchase"
        }
    }

    var price: String {
        switch self {
        case .free: return "$0"
        case .plusMonthly: return "$6.99 / month"
        case .plusYearly: return "$59.99 / year"
        case .proMonthly: return "$12.99 / month"
        case .proYearly: return "$119.99 / year"
        case .lifetime: return "$149 once"
        }
    }

    var summary: String {
        switch self {
        case .free:
            return "Start coordinating care"
        case .plusMonthly, .plusYearly:
            return "For most families caring together"
        case .proMonthly, .proYearly:
            return "For complex care with helpers and multiple loved ones"
        case .lifetime:
            return "One payment for one long-term care circle"
        }
    }

    var features: [String] {
        switch self {
        case .free:
            return ["Basic task reminders", "Basic planner and health log", "Last 30 days of health history"]
        case .plusMonthly, .plusYearly:
            return ["Unlimited tasks, medicines and planner items", "1 year health history", "Photo task evidence", "CSV export"]
        case .proMonthly, .proYearly:
            return ["Everything in Plus", "Unlimited health history", "Advanced reminders and mute tracking", "Priority support"]
        case .lifetime:
            return ["Unlimited tasks, medicines and planner items", "Unlimited health history", "CSV export", "No renewal"]
        }
    }

    var careProfileLimit: String {
        switch self {
        case .free: return "1"
        case .plusMonthly, .plusYearly: return "2"
        case .proMonthly, .proYearly: return "6"
        case .lifetime: return "4"
        }
    }

    var familyMemberLimit: String {
        switch self {
        case .free: return "2"
        case .plusMonthly, .plusYearly: return "4"
        case .proMonthly, .proYearly: return "8"
        case .lifetime: return "10"
        }
    }

    var helperLimit: String {
        switch self {
        case .free: return "1"
        case .plusMonthly, .plusYearly: return "1"
        case .proMonthly, .proYearly: return "3"
        case .lifetime: return "5"
        }
    }

    var photoStorageLimit: String {
        switch self {
        case .free: return "20 photos"
        case .plusMonthly, .plusYearly: return "1 GB"
        case .proMonthly, .proYearly: return "10 GB"
        case .lifetime: return "5 GB"
        }
    }

    var isPaid: Bool {
        self != .free
    }

    var entitlementBillingPeriod: String {
        switch self {
        case .free: return "none"
        case .plusMonthly, .proMonthly: return "monthly"
        case .plusYearly, .proYearly: return "yearly"
        case .lifetime: return "lifetime"
        }
    }

    func currentPeriodEnd(from date: Date) -> Date? {
        let calendar = Calendar.current
        switch self {
        case .plusMonthly, .proMonthly:
            return calendar.date(byAdding: .month, value: 1, to: date)
        case .plusYearly, .proYearly:
            return calendar.date(byAdding: .year, value: 1, to: date)
        case .free, .lifetime:
            return nil
        }
    }

    func trialEnd(from date: Date) -> Date? {
        guard isPaid else { return nil }
        return Calendar.current.date(byAdding: .day, value: 3, to: date)
    }
}

enum CarePlanStatus: String, Codable, Hashable {
    case active
    case trialing
    case inactive
    case expired
    case revoked

    var label: String {
        switch self {
        case .active: return "Active"
        case .trialing: return "3-day trial"
        case .inactive: return "Inactive"
        case .expired: return "Expired"
        case .revoked: return "Revoked"
        }
    }
}

enum RemoteLoveTheme {
    private static var selectedPalette: String {
        UserDefaults.standard.string(forKey: "colorPalette") ?? "classic"
    }

    private static var isPinkTheme: Bool {
        selectedPalette == "pink"
    }

    private static var isBlueTheme: Bool {
        selectedPalette == "blue"
    }

    private static var isBlackTheme: Bool {
        selectedPalette == "black"
    }

    static let green = Color(
        UIColor { traits in
            if isPinkTheme {
                return traits.userInterfaceStyle == .dark
                    ? UIColor(red: 1.00, green: 0.47, blue: 0.76, alpha: 1)
                    : UIColor(red: 0.78, green: 0.10, blue: 0.45, alpha: 1)
            }
            if isBlueTheme {
                return traits.userInterfaceStyle == .dark
                    ? UIColor(red: 0.38, green: 0.78, blue: 1.00, alpha: 1)
                    : UIColor(red: 0.05, green: 0.32, blue: 0.88, alpha: 1)
            }
            if isBlackTheme {
                return traits.userInterfaceStyle == .dark
                    ? UIColor(red: 0.92, green: 0.94, blue: 0.98, alpha: 1)
                    : UIColor(red: 0.05, green: 0.06, blue: 0.09, alpha: 1)
            }

            return traits.userInterfaceStyle == .dark
                ? UIColor(red: 0.47, green: 0.93, blue: 0.80, alpha: 1)
                : UIColor(red: 0.18, green: 0.40, blue: 0.35, alpha: 1)
        }
    )

    static let mint = Color(
        UIColor { traits in
            if isPinkTheme {
                return traits.userInterfaceStyle == .dark
                    ? UIColor(red: 0.11, green: 0.03, blue: 0.08, alpha: 1)
                    : UIColor(red: 1.00, green: 0.92, blue: 0.97, alpha: 1)
            }
            if isBlueTheme {
                return traits.userInterfaceStyle == .dark
                    ? UIColor(red: 0.02, green: 0.05, blue: 0.12, alpha: 1)
                    : UIColor(red: 0.92, green: 0.96, blue: 1.00, alpha: 1)
            }
            if isBlackTheme {
                return traits.userInterfaceStyle == .dark
                    ? UIColor(red: 0.02, green: 0.03, blue: 0.07, alpha: 1)
                    : UIColor(red: 0.94, green: 0.95, blue: 0.97, alpha: 1)
            }

            return traits.userInterfaceStyle == .dark
                ? UIColor(red: 0.08, green: 0.16, blue: 0.14, alpha: 1)
                : UIColor(red: 0.88, green: 0.92, blue: 0.84, alpha: 1)
        }
    )

    static let coral = Color(
        UIColor { traits in
            if isPinkTheme {
                return traits.userInterfaceStyle == .dark
                    ? UIColor(red: 1.00, green: 0.68, blue: 0.86, alpha: 1)
                    : UIColor(red: 0.95, green: 0.28, blue: 0.62, alpha: 1)
            }
            if isBlueTheme {
                return traits.userInterfaceStyle == .dark
                    ? UIColor(red: 0.43, green: 0.92, blue: 1.00, alpha: 1)
                    : UIColor(red: 0.00, green: 0.54, blue: 0.86, alpha: 1)
            }
            if isBlackTheme {
                return traits.userInterfaceStyle == .dark
                    ? UIColor(red: 1.00, green: 0.38, blue: 0.72, alpha: 1)
                    : UIColor(red: 0.18, green: 0.20, blue: 0.26, alpha: 1)
            }

            return traits.userInterfaceStyle == .dark
                ? UIColor(red: 1.00, green: 0.48, blue: 0.50, alpha: 1)
                : UIColor(red: 0.92, green: 0.36, blue: 0.36, alpha: 1)
        }
    )

    static let amber = Color(
        UIColor { traits in
            if isPinkTheme {
                return traits.userInterfaceStyle == .dark
                    ? UIColor(red: 0.98, green: 0.76, blue: 1.00, alpha: 1)
                    : UIColor(red: 0.63, green: 0.22, blue: 0.72, alpha: 1)
            }
            if isBlueTheme {
                return traits.userInterfaceStyle == .dark
                    ? UIColor(red: 0.70, green: 0.58, blue: 1.00, alpha: 1)
                    : UIColor(red: 0.39, green: 0.27, blue: 0.88, alpha: 1)
            }
            if isBlackTheme {
                return traits.userInterfaceStyle == .dark
                    ? UIColor(red: 0.46, green: 0.76, blue: 1.00, alpha: 1)
                    : UIColor(red: 0.22, green: 0.35, blue: 0.58, alpha: 1)
            }

            return traits.userInterfaceStyle == .dark
                ? UIColor(red: 1.00, green: 0.76, blue: 0.36, alpha: 1)
                : UIColor(red: 0.73, green: 0.50, blue: 0.25, alpha: 1)
        }
    )

    static let onAccent = Color(
        UIColor { traits in
            if isPinkTheme || isBlueTheme || isBlackTheme {
                return UIColor.white
            }

            return traits.userInterfaceStyle == .dark
                ? UIColor(red: 0.03, green: 0.08, blue: 0.07, alpha: 1)
                : UIColor.white
        }
    )
}
