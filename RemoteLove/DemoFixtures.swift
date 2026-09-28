import Foundation

enum DemoFixtures {
    static let careCircleID = UUID(uuidString: "00000000-0000-0000-0000-000000000047")!
    static let mumID = UUID(uuidString: "10000000-0000-0000-0000-000000000001")!
    static let dadID = UUID(uuidString: "10000000-0000-0000-0000-000000000002")!
    static let amlodipineID = UUID(uuidString: "20000000-0000-0000-0000-000000000001")!
    private static let vitaminDID = UUID(uuidString: "20000000-0000-0000-0000-000000000002")!
    private static let metforminID = UUID(uuidString: "20000000-0000-0000-0000-000000000003")!

    private static func date(days: Int = 0, hour: Int, minute: Int = 0) -> Date {
        let start = Calendar.current.startOfDay(for: Date())
        let day = Calendar.current.date(byAdding: .day, value: days, to: start) ?? start
        return Calendar.current.date(bySettingHour: hour, minute: minute, second: 0, of: day) ?? day
    }

    static let recipients = [
        CareRecipient(id: mumID, name: "Mei Ling", label: "Mum", age: 68, relationship: "Parent", lastUpdated: Date()),
        CareRecipient(id: dadID, name: "Wei Ming", label: "Dad", age: 72, relationship: "Parent", lastUpdated: Date().addingTimeInterval(-720))
    ]

    static let tasks = [
        CareTask(id: UUID(uuidString: "30000000-0000-0000-0000-000000000001")!, recipientID: mumID, title: "Breakfast", instructions: "Oatmeal, fruit and warm water", scheduledAt: date(hour: 8), frequency: "Every day", requiresPhoto: false, state: .done, notifiedAt: nil, medicineID: nil),
        CareTask(id: UUID(uuidString: "30000000-0000-0000-0000-000000000002")!, recipientID: mumID, title: "Morning medication", instructions: "Amlodipine - take after breakfast", scheduledAt: date(hour: 9), frequency: "Every day", requiresPhoto: false, state: .done, notifiedAt: nil, medicineID: amlodipineID),
        CareTask(id: UUID(uuidString: "30000000-0000-0000-0000-000000000003")!, recipientID: mumID, title: "Gentle walk", instructions: "15 minutes around the block", scheduledAt: date(hour: 10, minute: 30), frequency: "Every day", requiresPhoto: true, state: .done, notifiedAt: nil, medicineID: nil),
        CareTask(id: UUID(uuidString: "30000000-0000-0000-0000-000000000004")!, recipientID: mumID, title: "Lunch", instructions: "Serve a balanced meal", scheduledAt: date(hour: 12, minute: 30), frequency: "Every day", requiresPhoto: false, state: .pending, notifiedAt: Date().addingTimeInterval(-600), medicineID: nil),
        CareTask(id: UUID(uuidString: "30000000-0000-0000-0000-000000000005")!, recipientID: mumID, title: "Afternoon water", instructions: "One full glass", scheduledAt: date(hour: 15), frequency: "Every 3 hours - maximum 3 daily", requiresPhoto: false, state: .pending, notifiedAt: nil, medicineID: nil),
        CareTask(id: UUID(uuidString: "30000000-0000-0000-0000-000000000006")!, recipientID: mumID, title: "Evening check-in", instructions: "Record mood and comfort", scheduledAt: date(hour: 20, minute: 30), frequency: "Every day", requiresPhoto: false, state: .pending, notifiedAt: nil, medicineID: nil),
        CareTask(id: UUID(uuidString: "30000000-0000-0000-0000-000000000007")!, recipientID: dadID, title: "Breakfast", instructions: "Low-sugar breakfast", scheduledAt: date(hour: 8), frequency: "Every day", requiresPhoto: false, state: .done, notifiedAt: nil, medicineID: nil),
        CareTask(id: UUID(uuidString: "30000000-0000-0000-0000-000000000008")!, recipientID: dadID, title: "Blood sugar check", instructions: "Record reading before lunch", scheduledAt: date(hour: 11, minute: 45), frequency: "Every day", requiresPhoto: false, state: .attending, notifiedAt: Date().addingTimeInterval(-300), medicineID: nil),
        CareTask(id: UUID(uuidString: "30000000-0000-0000-0000-000000000009")!, recipientID: dadID, title: "Evening walk", instructions: "20 minutes at a comfortable pace", scheduledAt: date(hour: 18), frequency: "Every day", requiresPhoto: false, state: .pending, notifiedAt: nil, medicineID: nil)
    ]

    static let medicines = [
        Medicine(id: amlodipineID, recipientID: mumID, name: "Amlodipine", purpose: "Blood pressure", instructions: "Take after breakfast", currentSupply: 8, dose: 1, unit: "tablets", timesDaily: 1, intervalDays: 1, attentionDays: 7, active: true, firstTime: date(hour: 9)),
        Medicine(id: vitaminDID, recipientID: mumID, name: "Vitamin D", purpose: "Bone health", instructions: "Take with food every two days", currentSupply: 6, dose: 1, unit: "tablets", timesDaily: 1, intervalDays: 2, attentionDays: 5, active: true, firstTime: date(hour: 10)),
        Medicine(id: metforminID, recipientID: dadID, name: "Metformin", purpose: "Blood sugar", instructions: "Take after dinner", currentSupply: 18, dose: 1, unit: "tablets", timesDaily: 1, intervalDays: 1, attentionDays: 7, active: true, firstTime: date(hour: 20))
    ]

    static let appointments = [
        CareAppointment(id: UUID(uuidString: "40000000-0000-0000-0000-000000000001")!, recipientID: mumID, title: "Blood pressure review", date: date(days: 2, hour: 10), notes: "Bring recent readings and medicine list.", repeatRule: "Does not repeat", remindThreeDaysBefore: true, reminderEnabled: true, reminderDaysBefore: 3, reminderCount: 1, state: .scheduled),
        CareAppointment(id: UUID(uuidString: "40000000-0000-0000-0000-000000000002")!, recipientID: mumID, title: "Annual health screening", date: date(days: 14, hour: 9, minute: 30), notes: "Routine yearly check-up.", repeatRule: "Every year", remindThreeDaysBefore: true, reminderEnabled: true, reminderDaysBefore: 7, reminderCount: 2, state: .scheduled),
        CareAppointment(id: UUID(uuidString: "40000000-0000-0000-0000-000000000003")!, recipientID: dadID, title: "Diabetes review", date: date(days: 5, hour: 14), notes: "Bring glucose log.", repeatRule: "Every 3 months", remindThreeDaysBefore: true, reminderEnabled: true, reminderDaysBefore: 3, reminderCount: 1, state: .scheduled)
    ]

    static let plannerOtherItems = [
        PlannerOtherItem(id: UUID(uuidString: "41000000-0000-0000-0000-000000000001")!, recipientID: mumID, title: "Bring insurance card", date: date(days: 2, hour: 8), notes: "Keep it ready before the clinic visit.", repeatRule: "Does not repeat", active: true),
        PlannerOtherItem(id: UUID(uuidString: "41000000-0000-0000-0000-000000000002")!, recipientID: dadID, title: "Charge glucose meter", date: date(hour: 21), notes: "Place it beside the medication box.", repeatRule: "Every day", active: true)
    ]

    static let healthLogs: [HealthLog] = {
        let values: [(String, UUID, HealthCategory, Int, Double, String)] = [
            ("50000000-0000-0000-0000-000000000001", mumID, .weight, -6, 63.2, "Before breakfast"),
            ("50000000-0000-0000-0000-000000000002", mumID, .weight, -4, 62.9, "Before breakfast"),
            ("50000000-0000-0000-0000-000000000003", mumID, .weight, -2, 62.7, "Before breakfast"),
            ("50000000-0000-0000-0000-000000000004", mumID, .weight, 0, 62.6, "Before breakfast"),
            ("50000000-0000-0000-0000-000000000005", mumID, .bloodPressure, -6, 134, "Morning reading"),
            ("50000000-0000-0000-0000-000000000006", mumID, .bloodPressure, -4, 131, "After resting"),
            ("50000000-0000-0000-0000-000000000007", mumID, .bloodPressure, -2, 129, "Morning reading"),
            ("50000000-0000-0000-0000-000000000008", mumID, .bloodPressure, 0, 128, "Morning reading"),
            ("50000000-0000-0000-0000-000000000009", mumID, .mobility, -2, 24, "Walk and stretching"),
            ("50000000-0000-0000-0000-000000000010", mumID, .mobility, 0, 25, "Comfortable walk"),
            ("50000000-0000-0000-0000-000000000011", mumID, .hydration, 0, 7, "Regular water through the day"),
            ("50000000-0000-0000-0000-000000000012", mumID, .sleep, 0, 7.5, "Slept through the night"),
            ("50000000-0000-0000-0000-000000000013", dadID, .bloodSugar, -2, 6.8, "Before breakfast"),
            ("50000000-0000-0000-0000-000000000014", dadID, .bloodSugar, 0, 6.5, "Before breakfast")
        ]
        return values.map { id, person, category, day, value, note in
            HealthLog(id: UUID(uuidString: id)!, recipientID: person, category: category, value: value, recordedAt: date(days: day, hour: 9), notes: note)
        }
    }()

    static let members = [
        CircleMember(id: UUID(uuidString: "80000000-0000-0000-0000-000000000001")!, recipientID: mumID, name: "Zovin", role: "Owner", permission: "Full access", active: true, joinedAt: date(days: -90, hour: 9)),
        CircleMember(id: UUID(uuidString: "80000000-0000-0000-0000-000000000002")!, recipientID: mumID, name: "Ana", role: "Helper", permission: "Tasks and updates", active: true, joinedAt: date(days: -60, hour: 9)),
        CircleMember(id: UUID(uuidString: "80000000-0000-0000-0000-000000000003")!, recipientID: mumID, name: "Cheryl", role: "Family", permission: "Monitor and respond", active: true, joinedAt: date(days: -45, hour: 9)),
        CircleMember(id: UUID(uuidString: "80000000-0000-0000-0000-000000000004")!, recipientID: dadID, name: "Zovin", role: "Owner", permission: "Full access", active: true, joinedAt: date(days: -80, hour: 9)),
        CircleMember(id: UUID(uuidString: "80000000-0000-0000-0000-000000000005")!, recipientID: dadID, name: "Ana", role: "Helper", permission: "Tasks and updates", active: true, joinedAt: date(days: -30, hour: 9))
    ]

    static let updates = [
        CareUpdate(id: UUID(uuidString: "60000000-0000-0000-0000-000000000001")!, recipientID: mumID, author: "Ana", message: "Mum ate well and was cheerful this morning. We walked downstairs before it became warm.", mood: "Cheerful", createdAt: Date().addingTimeInterval(-1800))
    ]

    static let history = [
        ActivityEvent(id: UUID(uuidString: "70000000-0000-0000-0000-000000000001")!, recipientID: mumID, actor: "Ana - Helper", action: "Completed Morning medication", detail: "Marked the 9:00 AM care task as done.", createdAt: Date().addingTimeInterval(-2520)),
        ActivityEvent(id: UUID(uuidString: "70000000-0000-0000-0000-000000000002")!, recipientID: mumID, actor: "Ana - Helper", action: "Sent a care update", detail: "Shared a cheerful mood update with the family.", createdAt: Date().addingTimeInterval(-3900)),
        ActivityEvent(id: UUID(uuidString: "70000000-0000-0000-0000-000000000003")!, recipientID: mumID, actor: "Zovin - Owner", action: "Updated Blood pressure review", detail: "Kept the three-day appointment reminder.", createdAt: Date().addingTimeInterval(-10800)),
        ActivityEvent(id: UUID(uuidString: "70000000-0000-0000-0000-000000000004")!, recipientID: dadID, actor: "Ana - Helper", action: "Attending to Blood sugar check", detail: "Family can see that the requested task is in progress.", createdAt: Date().addingTimeInterval(-300))
    ]
}
