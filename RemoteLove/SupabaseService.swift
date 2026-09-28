import Foundation

struct SupabaseConfig {
    static let projectURL = URL(string: "https://lyezhrepixisfdtlxdci.supabase.co")!
    static let anonKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imx5ZXpocmVwaXhpc2ZkdGx4ZGNpIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODkzNDAwNzEsImV4cCI6MjEwNDkxNjA3MX0.odTy_kgKV4oRbna4X77y7dG6i2ZH7kE9s-rxK_m94Ts"
    static let authCallbackURL = "remotelove://auth/callback"
}

struct SupabaseUser: Codable {
    let id: UUID
    let email: String?
}

struct SupabaseAuthSession: Codable {
    let accessToken: String?
    let refreshToken: String?
    let user: SupabaseUser?

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
        case user
    }
}

struct SupabaseProfileRecord: Codable {
    let id: UUID
    let displayName: String

    enum CodingKeys: String, CodingKey {
        case id
        case displayName = "display_name"
    }
}

struct SupabaseCareCircleRecord: Codable {
    let id: UUID
    let ownerID: UUID
    let name: String
    let caregiverMode: String?
    let healthEnabled: Bool?

    enum CodingKeys: String, CodingKey {
        case id
        case ownerID = "owner_id"
        case name
        case caregiverMode = "caregiver_mode"
        case healthEnabled = "health_enabled"
    }
}

struct SupabaseCareCircleJoinResponse: Codable {
    let circleID: UUID
    let inviteCode: String

    enum CodingKeys: String, CodingKey {
        case circleID = "circle_id"
        case inviteCode = "invite_code"
    }
}

struct SupabaseInitialCareSetupResponse: Codable {
    let circleID: UUID
    let recipientID: UUID
    let familyInviteCode: String
    let helperInviteCode: String

    enum CodingKeys: String, CodingKey {
        case circleID = "circle_id"
        case recipientID = "recipient_id"
        case familyInviteCode = "family_invite_code"
        case helperInviteCode = "helper_invite_code"
    }
}

struct SupabaseCareCircleInviteRecord: Codable {
    let code: String
    let circleID: UUID
    let createdBy: UUID?
    let active: Bool
    let invitationType: String?

    enum CodingKeys: String, CodingKey {
        case code
        case circleID = "circle_id"
        case createdBy = "created_by"
        case active
        case invitationType = "invitation_type"
    }

    init(code: String, circleID: UUID, createdBy: UUID?, active: Bool, invitationType: String? = nil) {
        self.code = code
        self.circleID = circleID
        self.createdBy = createdBy
        self.active = active
        self.invitationType = invitationType
    }
}

struct SupabaseCareCircleEntitlementRecord: Codable {
    let circleID: UUID
    let planCode: String
    let status: String
    let billingPeriod: String
    let purchasedBy: UUID?
    let purchasedAt: Date
    let currentPeriodEndsAt: Date?

    enum CodingKeys: String, CodingKey {
        case circleID = "circle_id"
        case planCode = "plan_code"
        case status
        case billingPeriod = "billing_period"
        case purchasedBy = "purchased_by"
        case purchasedAt = "purchased_at"
        case currentPeriodEndsAt = "current_period_ends_at"
    }
}

struct SupabaseCareRecipientRecord: Codable {
    let id: UUID
    let circleID: UUID
    let name: String
    let label: String
    let age: Int
    let relationship: String
    let lastUpdated: Date

    enum CodingKeys: String, CodingKey {
        case id
        case circleID = "circle_id"
        case name
        case label
        case age
        case relationship
        case lastUpdated = "last_updated"
    }
}

struct SupabaseCircleMemberRecord: Codable {
    let id: UUID
    let circleID: UUID
    let recipientID: UUID?
    let userID: UUID?
    let name: String
    let role: String
    let permission: String
    let active: Bool
    let joinedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case circleID = "circle_id"
        case recipientID = "recipient_id"
        case userID = "user_id"
        case name
        case role
        case permission
        case active
        case joinedAt = "joined_at"
    }

    init(id: UUID, circleID: UUID, recipientID: UUID?, userID: UUID?, name: String, role: String, permission: String, active: Bool, joinedAt: Date) {
        self.id = id
        self.circleID = circleID
        self.recipientID = recipientID
        self.userID = userID
        self.name = name
        self.role = role
        self.permission = permission
        self.active = active
        self.joinedAt = joinedAt
    }
}

struct SupabaseCareTaskRecord: Codable {
    let id: UUID
    let recipientID: UUID
    let title: String
    let instructions: String
    let scheduledAt: Date
    let frequency: String
    let requiresPhoto: Bool
    let state: String
    let notifiedAt: Date?
    let medicineID: UUID?

    enum CodingKeys: String, CodingKey {
        case id
        case recipientID = "recipient_id"
        case title
        case instructions
        case scheduledAt = "scheduled_at"
        case frequency
        case requiresPhoto = "requires_photo"
        case state
        case notifiedAt = "notified_at"
        case medicineID = "medicine_id"
    }
}

struct SupabaseMedicineRecord: Codable {
    let id: UUID
    let recipientID: UUID
    let name: String
    let purpose: String
    let instructions: String
    let currentSupply: Double
    let dose: Double
    let unit: String
    let timesDaily: Int
    let intervalDays: Int
    let attentionDays: Int
    let active: Bool
    let firstTime: Date
    let doseTimes: [Date]?
    let repeatWeekdays: [Int]?

    enum CodingKeys: String, CodingKey {
        case id
        case recipientID = "recipient_id"
        case name
        case purpose
        case instructions
        case currentSupply = "current_supply"
        case dose
        case unit
        case timesDaily = "times_daily"
        case intervalDays = "interval_days"
        case attentionDays = "attention_days"
        case active
        case firstTime = "first_time"
        case doseTimes = "dose_times"
        case repeatWeekdays = "repeat_weekdays"
    }
}

struct SupabaseAppointmentRecord: Codable {
    let id: UUID
    let recipientID: UUID
    let title: String
    let date: Date
    let notes: String
    let repeatRule: String
    let remindThreeDaysBefore: Bool
    let reminderEnabled: Bool?
    let reminderDaysBefore: Int?
    let reminderCount: Int?
    let state: String

    enum CodingKeys: String, CodingKey {
        case id
        case recipientID = "recipient_id"
        case title
        case date
        case notes
        case repeatRule = "repeat_rule"
        case remindThreeDaysBefore = "remind_three_days_before"
        case reminderEnabled = "reminder_enabled"
        case reminderDaysBefore = "reminder_days_before"
        case reminderCount = "reminder_count"
        case state
    }
}

struct SupabasePlannerOtherItemRecord: Codable {
    let id: UUID
    let recipientID: UUID
    let title: String
    let date: Date
    let notes: String
    let repeatRule: String
    let active: Bool

    enum CodingKeys: String, CodingKey {
        case id
        case recipientID = "recipient_id"
        case title
        case date
        case notes
        case repeatRule = "repeat_rule"
        case active
    }
}

struct SupabaseHealthLogRecord: Codable {
    let id: UUID
    let recipientID: UUID
    let category: String
    let value: Double
    let recordedAt: Date
    let notes: String

    enum CodingKeys: String, CodingKey {
        case id
        case recipientID = "recipient_id"
        case category
        case value
        case recordedAt = "recorded_at"
        case notes
    }
}

struct SupabaseCareUpdateRecord: Codable {
    let id: UUID
    let recipientID: UUID
    let author: String
    let message: String
    let mood: String
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case recipientID = "recipient_id"
        case author
        case message
        case mood
        case createdAt = "created_at"
    }
}

struct SupabaseActivityEventRecord: Codable {
    let id: UUID
    let recipientID: UUID
    let actor: String
    let action: String
    let detail: String
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case recipientID = "recipient_id"
        case actor
        case action
        case detail
        case createdAt = "created_at"
    }
}

struct SupabaseCareCircleSnapshot {
    let circle: SupabaseCareCircleRecord?
    let invites: [SupabaseCareCircleInviteRecord]
    let entitlement: SupabaseCareCircleEntitlementRecord?
    let recipients: [SupabaseCareRecipientRecord]
    let members: [SupabaseCircleMemberRecord]
    let tasks: [SupabaseCareTaskRecord]
    let medicines: [SupabaseMedicineRecord]
    let appointments: [SupabaseAppointmentRecord]
    let plannerOtherItems: [SupabasePlannerOtherItemRecord]
    let healthLogs: [SupabaseHealthLogRecord]
    let updates: [SupabaseCareUpdateRecord]
    let history: [SupabaseActivityEventRecord]
}

enum SupabaseServiceError: LocalizedError {
    case missingSession
    case emailConfirmationRequired
    case requestFailed(String)

    var errorDescription: String? {
        switch self {
        case .missingSession:
            return "Please sign in before syncing care data."
        case .emailConfirmationRequired:
            return "Account created. Please confirm your email, then sign in."
        case .requestFailed(let message):
            return message
        }
    }
}

final class SupabaseService {
    static let shared = SupabaseService()

    private let baseURL = SupabaseConfig.projectURL
    private let anonKey = SupabaseConfig.anonKey
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    private init() {
        encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601

        decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
    }

    func signUp(email: String, password: String, displayName: String) async throws -> SupabaseAuthSession {
        let session: SupabaseAuthSession = try await authRequest(path: "signup", queryItems: [
            URLQueryItem(name: "redirect_to", value: SupabaseConfig.authCallbackURL)
        ], body: [
            "email": email,
            "password": password,
            "data": ["display_name": displayName]
        ])

        guard session.accessToken != nil else {
            throw SupabaseServiceError.emailConfirmationRequired
        }
        return session
    }

    func signIn(email: String, password: String) async throws -> SupabaseAuthSession {
        try await authRequest(path: "token", queryItems: [URLQueryItem(name: "grant_type", value: "password")], body: [
            "email": email,
            "password": password
        ])
    }

    func signInAnonymously(displayName: String) async throws -> SupabaseAuthSession {
        try await authRequest(path: "signup", body: [
            "data": ["display_name": displayName]
        ])
    }

    func upsert<Record: Encodable>(_ records: [Record], into table: String, accessToken: String, onConflict: String = "id") async throws {
        guard !records.isEmpty else { return }

        var components = URLComponents(url: url(pathComponents: ["rest", "v1", table]), resolvingAgainstBaseURL: false)!
        components.queryItems = [URLQueryItem(name: "on_conflict", value: onConflict)]

        var request = URLRequest(url: components.url!)
        request.httpMethod = "POST"
        request.setValue(anonKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("resolution=merge-duplicates", forHTTPHeaderField: "Prefer")
        request.httpBody = try encoder.encode(records)

        try await send(request, context: "Syncing \(table)")
    }

    func joinCareCircle(inviteCode: String, displayName: String, accessToken: String) async throws -> SupabaseCareCircleJoinResponse {
        let responses: [SupabaseCareCircleJoinResponse] = try await rpc(
            "join_care_circle_with_code",
            body: [
                "invite_code_value": inviteCode,
                "display_name_value": displayName
            ],
            accessToken: accessToken,
            context: "Joining care circle"
        )

        guard let response = responses.first else {
            throw SupabaseServiceError.requestFailed("Joining care circle: Supabase did not return the joined circle.")
        }
        return response
    }

    func redeemInvitation(
        inviteCode: String,
        invitationType: String,
        displayName: String,
        accessToken: String
    ) async throws -> SupabaseCareCircleJoinResponse {
        let responses: [SupabaseCareCircleJoinResponse] = try await rpc(
            "redeem_care_invitation",
            body: [
                "invite_code_value": inviteCode,
                "expected_type_value": invitationType,
                "display_name_value": displayName
            ],
            accessToken: accessToken,
            context: "Redeeming \(invitationType) invitation"
        )

        guard let response = responses.first else {
            throw SupabaseServiceError.requestFailed("The invitation did not return a care circle.")
        }
        return response
    }

    func joinDemoCareCircle(displayName: String, role: UserRole, accessToken: String) async throws -> SupabaseCareCircleJoinResponse {
        let responses: [SupabaseCareCircleJoinResponse] = try await rpc(
            "join_remote_love_demo",
            body: [
                "display_name_value": displayName,
                "role_value": role == .helper ? "helper" : "family"
            ],
            accessToken: accessToken,
            context: "Joining demo care circle"
        )

        guard let response = responses.first else {
            throw SupabaseServiceError.requestFailed("The demo care circle did not return a result.")
        }
        return response
    }

    func createInitialCareSetup(
        recipientName: String,
        recipientLabel: String,
        recipientAge: Int,
        relationship: String,
        caregiverMode: CaregiverMode,
        displayName: String,
        accessToken: String
    ) async throws -> SupabaseInitialCareSetupResponse {
        let responses: [SupabaseInitialCareSetupResponse] = try await rpc(
            "create_initial_care_setup",
            body: [
                "recipient_name_value": recipientName,
                "recipient_label_value": recipientLabel,
                "recipient_age_value": recipientAge,
                "relationship_value": relationship,
                "caregiver_mode_value": caregiverMode.rawValue,
                "display_name_value": displayName
            ],
            accessToken: accessToken,
            context: "Creating care setup"
        )

        guard let response = responses.first else {
            throw SupabaseServiceError.requestFailed("Supabase did not return the new care setup.")
        }
        return response
    }

    func createCareCircle(circleID: UUID, inviteCode: String, displayName: String, accessToken: String) async throws -> SupabaseCareCircleJoinResponse {
        let responses: [SupabaseCareCircleJoinResponse] = try await rpc(
            "create_care_circle_with_invite",
            body: [
                "circle_id_value": circleID.uuidString,
                "invite_code_value": inviteCode,
                "display_name_value": displayName
            ],
            accessToken: accessToken,
            context: "Creating care circle"
        )

        guard let response = responses.first else {
            throw SupabaseServiceError.requestFailed("Creating care circle: Supabase did not return the new circle.")
        }
        return response
    }

    func fetchCareCircle(circleID: UUID, accessToken: String) async throws -> SupabaseCareCircleSnapshot {
        let entitlementRecords: [SupabaseCareCircleEntitlementRecord]
        do {
            entitlementRecords = try await select(
                from: "care_circle_entitlements",
                queryItems: [
                    URLQueryItem(name: "circle_id", value: "eq.\(circleID.uuidString)"),
                    URLQueryItem(name: "or", value: "(status.eq.active,status.eq.trialing)"),
                    URLQueryItem(name: "select", value: "*"),
                    URLQueryItem(name: "limit", value: "1")
                ],
                accessToken: accessToken,
                context: "Loading care plan"
            )
        } catch {
            entitlementRecords = []
        }

        let circleRecords: [SupabaseCareCircleRecord] = try await select(
            from: "care_circles",
            queryItems: [
                URLQueryItem(name: "id", value: "eq.\(circleID.uuidString)"),
                URLQueryItem(name: "select", value: "*"),
                URLQueryItem(name: "limit", value: "1")
            ],
            accessToken: accessToken,
            context: "Loading care circle settings"
        )

        let invites: [SupabaseCareCircleInviteRecord] = try await select(
            from: "care_circle_invites",
            queryItems: [
                URLQueryItem(name: "circle_id", value: "eq.\(circleID.uuidString)"),
                URLQueryItem(name: "active", value: "eq.true"),
                URLQueryItem(name: "select", value: "code,circle_id,created_by,active,invitation_type"),
                URLQueryItem(name: "order", value: "created_at.asc")
            ],
            accessToken: accessToken,
            context: "Loading invite codes"
        )
        let recipients: [SupabaseCareRecipientRecord] = try await select(
            from: "care_recipients",
            queryItems: [
                URLQueryItem(name: "circle_id", value: "eq.\(circleID.uuidString)"),
                URLQueryItem(name: "select", value: "*")
            ],
            accessToken: accessToken,
            context: "Loading care profiles"
        )
        let members: [SupabaseCircleMemberRecord] = try await select(
            from: "care_circle_members",
            queryItems: [
                URLQueryItem(name: "circle_id", value: "eq.\(circleID.uuidString)"),
                URLQueryItem(name: "select", value: "*")
            ],
            accessToken: accessToken,
            context: "Loading care circle members"
        )

        let recipientIDs = recipients.map { $0.id.uuidString }.joined(separator: ",")
        guard !recipientIDs.isEmpty else {
            return SupabaseCareCircleSnapshot(
                circle: circleRecords.first,
                invites: invites,
                entitlement: entitlementRecords.first,
                recipients: recipients,
                members: members,
                tasks: [],
                medicines: [],
                appointments: [],
                plannerOtherItems: [],
                healthLogs: [],
                updates: [],
                history: []
            )
        }

        let recipientFilter = "in.(\(recipientIDs))"
        async let tasks: [SupabaseCareTaskRecord] = select(from: "care_tasks", queryItems: [URLQueryItem(name: "recipient_id", value: recipientFilter), URLQueryItem(name: "select", value: "*")], accessToken: accessToken, context: "Loading care tasks")
        async let medicines: [SupabaseMedicineRecord] = select(from: "medicines", queryItems: [URLQueryItem(name: "recipient_id", value: recipientFilter), URLQueryItem(name: "select", value: "*")], accessToken: accessToken, context: "Loading medicines")
        async let appointments: [SupabaseAppointmentRecord] = select(from: "appointments", queryItems: [URLQueryItem(name: "recipient_id", value: recipientFilter), URLQueryItem(name: "select", value: "*")], accessToken: accessToken, context: "Loading appointments")
        async let plannerOtherItems: [SupabasePlannerOtherItemRecord] = select(from: "planner_other_items", queryItems: [URLQueryItem(name: "recipient_id", value: recipientFilter), URLQueryItem(name: "select", value: "*")], accessToken: accessToken, context: "Loading other planner items")
        async let healthLogs: [SupabaseHealthLogRecord] = select(from: "health_logs", queryItems: [URLQueryItem(name: "recipient_id", value: recipientFilter), URLQueryItem(name: "select", value: "*")], accessToken: accessToken, context: "Loading health logs")
        async let updates: [SupabaseCareUpdateRecord] = select(from: "care_updates", queryItems: [URLQueryItem(name: "recipient_id", value: recipientFilter), URLQueryItem(name: "select", value: "*")], accessToken: accessToken, context: "Loading care updates")
        async let history: [SupabaseActivityEventRecord] = select(from: "activity_events", queryItems: [URLQueryItem(name: "recipient_id", value: recipientFilter), URLQueryItem(name: "select", value: "*")], accessToken: accessToken, context: "Loading activity history")

        return try await SupabaseCareCircleSnapshot(
            circle: circleRecords.first,
            invites: invites,
            entitlement: entitlementRecords.first,
            recipients: recipients,
            members: members,
            tasks: tasks,
            medicines: medicines,
            appointments: appointments,
            plannerOtherItems: plannerOtherItems,
            healthLogs: healthLogs,
            updates: updates,
            history: history
        )
    }

    func saveCarePlanEntitlement(
        circleID: UUID,
        plan: CarePlan,
        status: CarePlanStatus,
        buyerUserID: UUID,
        accessToken: String
    ) async throws {
        let now = Date()
        let entitlement = SupabaseCareCircleEntitlementRecord(
            circleID: circleID,
            planCode: plan.rawValue,
            status: status.rawValue,
            billingPeriod: plan.entitlementBillingPeriod,
            purchasedBy: buyerUserID,
            purchasedAt: now,
            currentPeriodEndsAt: status == .trialing ? plan.trialEnd(from: now) : plan.currentPeriodEnd(from: now)
        )
        try await upsert([entitlement], into: "care_circle_entitlements", accessToken: accessToken, onConflict: "circle_id")
    }

    func fetchActiveMemberships(userID: UUID, accessToken: String) async throws -> [SupabaseCircleMemberRecord] {
        try await select(
            from: "care_circle_members",
            queryItems: [
                URLQueryItem(name: "user_id", value: "eq.\(userID.uuidString)"),
                URLQueryItem(name: "active", value: "eq.true"),
                URLQueryItem(name: "select", value: "*"),
                URLQueryItem(name: "order", value: "joined_at.asc")
            ],
            accessToken: accessToken,
            context: "Loading care-circle memberships"
        )
    }

    private func authRequest<Response: Decodable>(path: String, queryItems: [URLQueryItem] = [], body: [String: Any]) async throws -> Response {
        var components = URLComponents(url: url(pathComponents: ["auth", "v1", path]), resolvingAgainstBaseURL: false)!
        components.queryItems = queryItems.isEmpty ? nil : queryItems

        var request = URLRequest(url: components.url!)
        request.httpMethod = "POST"
        request.setValue(anonKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(anonKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let data = try await send(request, context: "Supabase auth \(path)")
        return try decoder.decode(Response.self, from: data)
    }

    private func rpc<Response: Decodable>(_ functionName: String, body: [String: Any], accessToken: String, context: String) async throws -> Response {
        var request = URLRequest(url: url(pathComponents: ["rest", "v1", "rpc", functionName]))
        request.httpMethod = "POST"
        request.setValue(anonKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let data = try await send(request, context: context)
        return try decoder.decode(Response.self, from: data)
    }

    private func select<Response: Decodable>(from table: String, queryItems: [URLQueryItem], accessToken: String, context: String) async throws -> Response {
        var components = URLComponents(url: url(pathComponents: ["rest", "v1", table]), resolvingAgainstBaseURL: false)!
        components.queryItems = queryItems

        var request = URLRequest(url: components.url!)
        request.httpMethod = "GET"
        request.setValue(anonKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")

        let data = try await send(request, context: context)
        return try decoder.decode(Response.self, from: data)
    }

    @discardableResult
    private func send(_ request: URLRequest, context: String) async throws -> Data {
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw SupabaseServiceError.requestFailed("Supabase did not return a valid response.")
        }

        guard 200..<300 ~= httpResponse.statusCode else {
            let message = errorMessage(from: data) ?? "Supabase request failed with status \(httpResponse.statusCode)."
            throw SupabaseServiceError.requestFailed("\(context): \(message)")
        }

        return data
    }

    private func errorMessage(from data: Data) -> String? {
        guard let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }
        return object["msg"] as? String ?? object["message"] as? String ?? object["error_description"] as? String
    }

    private func url(pathComponents: [String]) -> URL {
        pathComponents.reduce(baseURL) { partialURL, component in
            partialURL.appendingPathComponent(component)
        }
    }
}
