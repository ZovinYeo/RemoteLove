import Foundation
import Combine
import CryptoKit
import UserNotifications
import WidgetKit

@MainActor
final class RemoteLoveStore: ObservableObject {
    private static let helperBasePermission = "Assigned care tasks"
    private static let helperEditPermission = "Can add and edit care records"

    @Published var route: AppRoute
    @Published var selectedMainTab: MainTab
    @Published var pendingDestination: AppDestination?
    @Published var isAuthenticated: Bool
    @Published var currentRole: UserRole = .family
    @Published var currentUserName = "Zovin"
    @Published var authMessage: String?
    @Published var helperPinMessage: String?
    @Published var isSyncing = false
    @Published var hasCareCircle: Bool
    @Published var generatedInviteCode: String?
    @Published var helperInviteCode: String?
    @Published var shouldPromptForFirstCareProfile = false
    @Published var selectedRecipientID: UUID
    @Published var selectedTaskDate = Date()
    @Published var overviewRecipientID: UUID?
    @Published var recipients = DemoFixtures.recipients
    @Published var tasks = DemoFixtures.tasks
    @Published var medicines = DemoFixtures.medicines
    @Published var appointments = DemoFixtures.appointments
    @Published var plannerOtherItems = DemoFixtures.plannerOtherItems
    @Published var healthLogs = DemoFixtures.healthLogs
    @Published var members = DemoFixtures.members
    @Published var updates = DemoFixtures.updates
    @Published var history = DemoFixtures.history
    @Published var emergencyMessage: String?
    @Published var activeCarePlan: CarePlan = .free
    @Published var carePlanStatus: CarePlanStatus = .inactive
    @Published var carePlanPeriodEndsAt: Date?
    @Published var caregiverMode: CaregiverMode = .helperOnly
    @Published var healthFeatureEnabled = true
    @Published var notificationsMutedUntil: Date?
    @Published var taskUndoStack: [TaskUndoEntry] = []
    @Published var taskRedoStack: [TaskUndoEntry] = []
    @Published private var taskPhotoEvidence = Set<UUID>()

    private let supabaseService = SupabaseService.shared
    private var authSession: SupabaseAuthSession?
    private var activeCareCircleID = DemoFixtures.careCircleID
    private var ownsActiveCareCircle = false
    private static let authSessionStorageKey = "RemoteLove.supabase.authSession"
    private static let widgetAppGroupID = "group.com.zozo.remotelove"
    private static let widgetSnapshotKey = "RemoteLove.widget.snapshot"
    private static let widgetQueuedActionsKey = "RemoteLove.widget.queuedActions"

    init(previewAuthenticated: Bool = false) {
        let hasSavedSession = UserDefaults.standard.data(forKey: Self.authSessionStorageKey) != nil
        route = previewAuthenticated ? .familyApp : (hasSavedSession ? .restoringSession : .welcome)
        selectedMainTab = previewAuthenticated ? .overview : .overview
        pendingDestination = nil
        isAuthenticated = previewAuthenticated
        hasCareCircle = previewAuthenticated
        generatedInviteCode = previewAuthenticated ? "LOVE2026" : nil
        helperInviteCode = previewAuthenticated ? "LOVE2026" : nil
        selectedRecipientID = DemoFixtures.mumID
    }

    var selectedRecipient: CareRecipient {
        recipients.first(where: { $0.id == selectedRecipientID })
            ?? recipients.first
            ?? CareRecipient(id: selectedRecipientID, name: "No care profile", label: "Care", age: 0, relationship: "Family", lastUpdated: Date())
    }

    var selectedTasks: [CareTask] {
        tasks(on: selectedTaskDate)
    }

    func tasks(on date: Date) -> [CareTask] {
        tasks(on: date, recipientID: selectedRecipientID)
    }

    func tasks(on date: Date, recipientID: UUID) -> [CareTask] {
        tasks
            .filter { $0.recipientID == recipientID && task($0, occursOn: date) }
            .sorted { taskSortKey($0.scheduledAt) < taskSortKey($1.scheduledAt) }
    }

    var routineDates: [Date] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        return (0..<30).compactMap { calendar.date(byAdding: .day, value: $0, to: today) }
    }

    var isSelectedTaskDateToday: Bool {
        Calendar.current.isDateInToday(selectedTaskDate)
    }

    func taskUndoCount(scope: TaskHistoryScope) -> Int {
        historyEntries(in: taskUndoStack, scope: scope).count
    }

    func taskRedoCount(scope: TaskHistoryScope) -> Int {
        historyEntries(in: taskRedoStack, scope: scope).count
    }

    func taskUndoEntries(scope: TaskHistoryScope) -> [TaskUndoEntry] {
        Array(historyEntries(in: taskUndoStack, scope: scope).reversed())
    }

    func taskRedoEntries(scope: TaskHistoryScope) -> [TaskUndoEntry] {
        Array(historyEntries(in: taskRedoStack, scope: scope).reversed())
    }

    var selectedMedicines: [Medicine] {
        medicines.filter { $0.recipientID == selectedRecipientID }
    }

    var selectedAppointments: [CareAppointment] {
        appointments.filter { $0.recipientID == selectedRecipientID }.sorted { $0.date < $1.date }
    }

    var selectedPlannerOtherItems: [PlannerOtherItem] {
        plannerOtherItems.filter { $0.recipientID == selectedRecipientID && $0.active }.sorted { $0.date < $1.date }
    }

    var selectedHealthLogs: [HealthLog] {
        healthLogs.filter { $0.recipientID == selectedRecipientID }.sorted { $0.recordedAt > $1.recordedAt }
    }

    var selectedMembers: [CircleMember] {
        members.filter { $0.recipientID == selectedRecipientID && $0.active }
    }

    var inviteCode: String {
        generatedInviteCode ?? "No invite code yet"
    }

    var activeHelperInviteCode: String {
        helperInviteCode ?? "No helper code yet"
    }

    var hasActiveSupabaseSession: Bool {
        authSession?.accessToken != nil
    }

    var canPurchaseCarePlan: Bool {
        currentRole.canManageCare
    }

    var canEditCareRecords: Bool {
        switch currentRole {
        case .owner, .family:
            return true
        case .helper:
            return activeCurrentHelperMember?.permission == Self.helperEditPermission
        case .viewer:
            return false
        }
    }

    var canLogHealthRecords: Bool {
        guard healthFeatureEnabled else { return false }
        switch currentRole {
        case .owner, .family, .helper:
            return true
        case .viewer:
            return false
        }
    }

    var helperEditingEnabledForSelectedProfile: Bool {
        let helperMembers = members.filter { member in
            member.active
                && member.recipientID == selectedRecipientID
                && member.role.caseInsensitiveCompare("Helper") == .orderedSame
        }
        return !helperMembers.isEmpty && helperMembers.allSatisfy { $0.permission == Self.helperEditPermission }
    }

    var canCompleteCareTasks: Bool {
        switch currentRole {
        case .owner, .family:
            return caregiverMode.allowsFamilyCompletion
        case .helper:
            return caregiverMode.allowsHelperCompletion
        case .viewer:
            return false
        }
    }

    var canUseHealthFeature: Bool {
        healthFeatureEnabled
    }

    var guidedTutorialStorageKey: String {
        let userPart = authSession?.user?.id.uuidString
            ?? currentUserName.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            .replacingOccurrences(of: " ", with: "-")
        return "RemoteLove.guidedTutorial.\(activeCareCircleID.uuidString).\(currentRole.rawValue).\(userPart)"
    }

    private var activeCurrentHelperMember: CircleMember? {
        guard currentRole == .helper else { return nil }
        let currentUserID = authSession?.user?.id
        return members.first { member in
            guard member.active, member.role.caseInsensitiveCompare("Helper") == .orderedSame else { return false }
            guard member.recipientID == selectedRecipientID else { return false }
            if let currentUserID, let memberUserID = member.userID {
                return memberUserID == currentUserID
            }
            return member.name.caseInsensitiveCompare(currentUserName) == .orderedSame
        }
    }

    var notificationsAreMuted: Bool {
        guard let notificationsMutedUntil else { return false }
        return notificationsMutedUntil > Date()
    }

    var notificationMuteStatusText: String {
        guard let notificationsMutedUntil else {
            return "Notifications are on."
        }

        if notificationsMutedUntil > Date.distantFuture.addingTimeInterval(-10_000) {
            return "Notifications are muted forever."
        }

        if notificationsMutedUntil <= Date() {
            return "Notifications are on."
        }

        return "Muted until \(notificationsMutedUntil.formatted(date: .abbreviated, time: .shortened))."
    }

    private var isSharedDemoCircle: Bool {
        activeCareCircleID == DemoFixtures.careCircleID
    }

    var savedHelperName: String? {
        guard
            let session = persistedAuthSession(),
            let userID = session.user?.id,
            UserDefaults.standard.string(forKey: helperPINStorageKey(userID: userID)) != nil
        else { return nil }
        return UserDefaults.standard.string(forKey: helperNameStorageKey(userID: userID))
    }

    var hasSavedHelperAccount: Bool {
        savedHelperName != nil
    }

    func hasPhotoEvidence(for taskID: UUID) -> Bool {
        taskPhotoEvidence.contains(taskID)
    }

    func prepareNotificationsForActiveCareCircle() {
        guard isAuthenticated, hasCareCircle else { return }
        applyQueuedWidgetActions()
        restoreNotificationMuteSelection()
        refreshScheduledNotifications()
    }

    func muteNotifications(_ preset: NotificationMutePreset, customUntil: Date? = nil) {
        let now = Date()
        let calendar = Calendar.current
        let until: Date?

        switch preset {
        case .today:
            until = calendar.date(bySettingHour: 23, minute: 59, second: 59, of: now)
        case .threeDays:
            until = calendar.date(byAdding: .day, value: 3, to: now)
        case .week:
            until = calendar.date(byAdding: .day, value: 7, to: now)
        case .month:
            until = calendar.date(byAdding: .month, value: 1, to: now)
        case .forever:
            until = .distantFuture
        case .custom:
            until = customUntil
        }

        guard let until, until > now else {
            authMessage = "Choose a future time to mute notifications."
            return
        }

        notificationsMutedUntil = until
        saveNotificationMuteSelection()
        refreshScheduledNotifications()

        if currentRole == .helper {
            notifyFamilyAboutHelperMute(until: until)
        } else {
            authMessage = notificationMuteStatusText
        }
    }

    func unmuteNotifications() {
        notificationsMutedUntil = nil
        saveNotificationMuteSelection()
        refreshScheduledNotifications()
        authMessage = "Notifications are on."
    }

    func clearTemporaryTaskHistory() {
        taskUndoStack.removeAll()
        taskRedoStack.removeAll()
    }

    func attachTaskPhoto(taskID: UUID, byteCount: Int) {
        guard let task = tasks.first(where: { $0.id == taskID }) else { return }
        taskPhotoEvidence.insert(taskID)
        record(
            action: "Attached photo for \(task.title)",
            detail: "Photo evidence was added before completion.",
            recipientID: task.recipientID
        )
        authMessage = byteCount > 0 ? "Photo attached for \(task.title)." : "Photo evidence attached."
        syncIfSignedIn()
    }

    func restoreSessionIfNeeded() async {
        guard route == .restoringSession else { return }
        guard
            let data = UserDefaults.standard.data(forKey: Self.authSessionStorageKey),
            let session = try? JSONDecoder().decode(SupabaseAuthSession.self, from: data),
            session.accessToken != nil
        else {
            clearSensitiveCareState()
            route = .welcome
            return
        }

        authSession = session
        isAuthenticated = true
        currentUserName = session.user?.email ?? currentUserName
        await resolveRouteForCurrentSession()
    }

    func navigate(to destination: AppDestination) {
        pendingDestination = destination
        switch destination {
        case .overview(let recipientID):
            if let recipientID { selectedRecipientID = recipientID }
            selectedMainTab = .overview
        case .task(let recipientID, _):
            selectedRecipientID = recipientID
            selectedMainTab = currentRole == .helper ? .helperToday : .care
        case .medicine(let recipientID, _), .appointment(let recipientID, _):
            selectedRecipientID = recipientID
            selectedMainTab = .planner
        case .health(let recipientID, _):
            selectedRecipientID = recipientID
            selectedMainTab = healthFeatureEnabled ? .health : .overview
        case .member(let recipientID, _):
            selectedRecipientID = recipientID
            selectedMainTab = currentRole.canManageCare ? .more : .settings
        case .history(let recipientID, _):
            if let recipientID { selectedRecipientID = recipientID }
            selectedMainTab = currentRole == .helper ? .settings : .more
        case .emergency(let recipientID, _):
            selectedRecipientID = recipientID
            selectedMainTab = currentRole == .helper ? .helperToday : .overview
        }
    }

    func signInFamily(name: String) {
        currentUserName = name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Zovin" : name
        currentRole = .family
        hasCareCircle = true
        isAuthenticated = true
        route = .familyApp
    }

    func createFamilyAccount(name: String, email: String, password: String) async {
        await authenticateWithSupabase(name: name, email: email, password: password, createsAccount: true)
    }

    func beginNewCareSetup() {
        authMessage = nil
        guard hasActiveSupabaseSession else {
            isAuthenticated = false
            route = .familyAuthentication
            authMessage = "Please sign in before setting up a care profile."
            return
        }
        route = .createCareSetup
    }

    func createInitialCareSetup(name: String, label: String, age: Int, relationship: String, caregiverMode selectedCaregiverMode: CaregiverMode, healthFeatureEnabled selectedHealthFeatureEnabled: Bool = true) async {
        await createInitialCareSetup(
            profiles: [
                CareProfileInput(
                    name: name,
                    label: label,
                    age: age,
                    relationship: relationship
                )
            ],
            caregiverMode: selectedCaregiverMode,
            healthFeatureEnabled: selectedHealthFeatureEnabled
        )
    }

    func createInitialCareSetup(profiles: [CareProfileInput], caregiverMode selectedCaregiverMode: CaregiverMode, healthFeatureEnabled selectedHealthFeatureEnabled: Bool = true) async {
        guard !isSyncing else { return }
        authMessage = nil

        let validProfiles = profiles.filter { !$0.trimmedName.isEmpty }
        guard let firstProfile = validProfiles.first else {
            authMessage = "Enter the care recipient's name."
            return
        }

        guard let accessToken = authSession?.accessToken else {
            isAuthenticated = false
            route = .familyAuthentication
            authMessage = "Please sign in before setting up a care profile."
            return
        }

        isSyncing = true
        defer { isSyncing = false }

        do {
            let result = try await supabaseService.createInitialCareSetup(
                recipientName: firstProfile.name,
                recipientLabel: firstProfile.label,
                recipientAge: firstProfile.age,
                relationship: firstProfile.relationship,
                caregiverMode: selectedCaregiverMode,
                displayName: currentUserName,
                accessToken: accessToken
            )
            activeCareCircleID = result.circleID
            generatedInviteCode = result.familyInviteCode
            helperInviteCode = result.helperInviteCode
            caregiverMode = selectedCaregiverMode
            healthFeatureEnabled = selectedHealthFeatureEnabled
            ownsActiveCareCircle = true
            currentRole = .owner
            selectedMainTab = .overview
            clearCareCircleData()
            let recipient = CareRecipient(
                id: result.recipientID,
                name: firstProfile.trimmedName,
                label: firstProfile.normalizedLabel,
                age: firstProfile.age,
                relationship: firstProfile.normalizedRelationship,
                lastUpdated: Date()
            )
            recipients = [recipient]
            selectedRecipientID = recipient.id
            overviewRecipientID = nil
            addCurrentUserToCareCircle(role: "Owner", permission: "Full access")
            appendStarterCareProfiles(validProfiles.dropFirst())
            do {
                let snapshot = try await supabaseService.fetchCareCircle(
                    circleID: result.circleID,
                    accessToken: accessToken
                )
                apply(snapshot: snapshot)
                healthFeatureEnabled = selectedHealthFeatureEnabled
                appendStarterCareProfiles(validProfiles.dropFirst())
                if validProfiles.count > 1 || !selectedHealthFeatureEnabled {
                    await syncAllToSupabase()
                }
                authMessage = validProfiles.count == 1
                    ? "Care setup created. Family and helper invitations are ready."
                    : "Care setup created with \(validProfiles.count) care profiles. Family and helper invitations are ready."
            } catch {
                healthFeatureEnabled = selectedHealthFeatureEnabled
                if validProfiles.count > 1 || !selectedHealthFeatureEnabled {
                    await syncAllToSupabase()
                }
                authMessage = "Care setup created. If anything looks missing, pull to refresh or sign in again."
            }
            hasCareCircle = true
            saveCareCircleSelection()
            route = .familyApp
        } catch {
            authMessage = error.localizedDescription
        }
    }

    private func appendStarterCareProfiles<S: Sequence>(_ profiles: S) where S.Element == CareProfileInput {
        for profile in profiles where !profile.trimmedName.isEmpty {
            let recipient = CareRecipient(
                id: UUID(),
                name: profile.trimmedName,
                label: profile.normalizedLabel,
                age: profile.age,
                relationship: profile.normalizedRelationship,
                lastUpdated: Date()
            )
            guard !recipients.contains(where: { existing in
                existing.name.caseInsensitiveCompare(recipient.name) == .orderedSame
                    && existing.label.caseInsensitiveCompare(recipient.label) == .orderedSame
            }) else {
                continue
            }
            recipients.append(recipient)
        }
    }

    func signInFamily(email: String, password: String) async {
        await authenticateWithSupabase(name: "", email: email, password: password, createsAccount: false)
    }

    func signInHelper(name: String, inviteCode: String, pin: String) async {
        guard !isSyncing else { return }

        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let displayName = trimmedName.isEmpty ? "Helper" : trimmedName
        let normalizedCode = inviteCode.uppercased().trimmingCharacters(in: .whitespacesAndNewlines)
        let requestedPIN = pin.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !normalizedCode.isEmpty else {
            authMessage = "Enter the helper invite code."
            return
        }

        guard Self.isValidHelperPIN(requestedPIN) else {
            authMessage = "Create a 4 to 6 digit helper PIN."
            return
        }

        isSyncing = true

        do {
            resetCareCircleSessionState()
            if authSession?.accessToken == nil {
                authSession = try await supabaseService.signInAnonymously(displayName: displayName)
            }
            persistAuthSession()
            currentUserName = displayName
            currentRole = .helper
            isSyncing = false
            await joinCareCircle(inviteCode: normalizedCode, role: .helper)
            if route == .helperApp {
                saveHelperPIN(requestedPIN)
                helperPinMessage = nil
            }
        } catch {
            isSyncing = false
            isAuthenticated = false
            hasCareCircle = false
            route = .helperJoin
            authMessage = error.localizedDescription
        }
    }

    func unlockHelperSession(pin: String) {
        let trimmedPIN = pin.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let userID = authSession?.user?.id else {
            helperPinMessage = "Please join again with your helper invite code."
            route = .helperJoin
            return
        }

        guard let storedHash = UserDefaults.standard.string(forKey: helperPINStorageKey(userID: userID)) else {
            helperPinMessage = "Please join again to create your helper PIN."
            route = .helperJoin
            return
        }

        if storedHash == Self.helperPINHash(trimmedPIN, userID: userID) {
            helperPinMessage = nil
            route = .helperApp
            selectedMainTab = .helperToday
        } else {
            helperPinMessage = "That PIN does not match. Please try again."
        }
    }

    func signInReturningHelper(name: String, pin: String) async {
        guard !isSyncing else { return }

        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedPIN = pin.trimmingCharacters(in: .whitespacesAndNewlines)

        guard let session = persistedAuthSession(), let userID = session.user?.id else {
            authMessage = "Please join with your helper invite code first."
            return
        }

        let savedName = UserDefaults.standard.string(forKey: helperNameStorageKey(userID: userID)) ?? ""
        guard !trimmedName.isEmpty, savedName.localizedCaseInsensitiveCompare(trimmedName) == .orderedSame else {
            authMessage = "Enter the helper name used on this device."
            return
        }

        guard let storedHash = UserDefaults.standard.string(forKey: helperPINStorageKey(userID: userID)),
              storedHash == Self.helperPINHash(trimmedPIN, userID: userID) else {
            authMessage = "That helper PIN does not match."
            return
        }

        authSession = session
        currentUserName = savedName
        currentRole = .helper
        isAuthenticated = true
        isSyncing = true
        defer { isSyncing = false }
        await resolveRouteForCurrentSession(unlockedHelper: true)
    }

    func useHelperInviteInstead() {
        clearPersistedHelperAccount()
        authSession = nil
        helperPinMessage = nil
        authMessage = nil
        route = .helperJoin
    }

    func lockHelperSessionIfNeeded() {
        guard currentRole == .helper, isAuthenticated, route == .helperApp else { return }
        guard let userID = authSession?.user?.id else { return }
        guard UserDefaults.standard.string(forKey: helperPINStorageKey(userID: userID)) != nil else { return }
        helperPinMessage = nil
        route = .helperPinLock
    }

    func enterDemo(as role: UserRole, name: String? = nil) async {
        guard !isSyncing else { return }

        let fallbackName = role == .family ? "Zovin" : "Ana"
        let displayName = name?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
            ? name!.trimmingCharacters(in: .whitespacesAndNewlines)
            : fallbackName

        isSyncing = true
        defer { isSyncing = false }

        do {
            if authSession?.accessToken == nil {
                authSession = try await supabaseService.signInAnonymously(displayName: displayName)
                persistAuthSession()
            }

            guard let accessToken = authSession?.accessToken else {
                throw SupabaseServiceError.missingSession
            }

            let response = try await supabaseService.joinDemoCareCircle(
                displayName: displayName,
                role: role,
                accessToken: accessToken
            )
            activeCareCircleID = response.circleID
            generatedInviteCode = response.inviteCode
            helperInviteCode = response.inviteCode
            currentRole = role
            currentUserName = displayName
            ownsActiveCareCircle = role.isFamilyExperience

            let snapshot = try await supabaseService.fetchCareCircle(
                circleID: response.circleID,
                accessToken: accessToken
            )
            if shouldSeedSharedDemo(from: snapshot) {
                loadDemoCareCircle()
                activeCareCircleID = response.circleID
                generatedInviteCode = response.inviteCode
                helperInviteCode = response.inviteCode
                currentRole = role
                currentUserName = displayName
                ownsActiveCareCircle = role.isFamilyExperience
                await syncAllToSupabase()
            } else {
                apply(snapshot: snapshot)
                ownsActiveCareCircle = role.isFamilyExperience
            }
            selectedMainTab = role == .helper ? .helperToday : .overview
            hasCareCircle = true
            isAuthenticated = true
            route = role == .helper ? .helperApp : .familyApp
            if authMessage?.hasPrefix("Sync failed") != true {
                authMessage = "Loaded the shared LOVE2026 demo."
            }
        } catch {
            loadDemoCareCircle()
            currentRole = role
            currentUserName = displayName
            selectedMainTab = role == .helper ? .helperToday : .overview
            hasCareCircle = true
            isAuthenticated = true
            route = role == .helper ? .helperApp : .familyApp
            authMessage = "Loaded local demo data because the shared Supabase demo could not load: \(error.localizedDescription)"
        }
    }

    func enterLocalDemo(as role: UserRole) {
        loadDemoCareCircle()
        currentRole = role
        currentUserName = role == .family ? "Zovin" : "Ana"
        selectedMainTab = role == .helper ? .helperToday : .overview
        hasCareCircle = true
        isAuthenticated = true
        route = role == .helper ? .helperApp : .familyApp
    }

    func joinAsHelper(name: String, code: String) -> Bool {
        let normalized = code.uppercased().trimmingCharacters(in: .whitespacesAndNewlines)
        if recipients.isEmpty {
            loadDemoCareCircle()
        }
        guard let recipient = recipients.first(where: { candidate in
            candidate.id == DemoFixtures.mumID ? normalized == "LOVE2026" : normalized == "CARE4726"
        }) else { return false }
        currentUserName = name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Helper" : name
        currentRole = .helper
        selectedMainTab = .helperToday
        selectedRecipientID = recipient.id
        hasCareCircle = true
        isAuthenticated = true
        route = .helperApp
        return true
    }

    func logout() {
        let wasHelper = currentRole == .helper
        authSession = nil
        if !wasHelper {
            clearPersistedSession()
            clearHelperPINForCurrentSession()
        }
        helperPinMessage = nil
        authMessage = nil
        isAuthenticated = false
        hasCareCircle = false
        clearSensitiveCareState()
        currentRole = .family
        selectedMainTab = .overview
        pendingDestination = nil
        route = .welcome
        Task { await RemoteLoveNotificationScheduler.cancelAllRemoteLoveNotifications() }
    }

    func joinCareCircle(inviteCode: String) async {
        await joinCareCircle(inviteCode: inviteCode, role: .family)
    }

    private func joinCareCircle(inviteCode: String, role: UserRole) async {
        guard !isSyncing else { return }

        let normalized = inviteCode.uppercased().trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else {
            authMessage = "Enter a family invite code."
            return
        }

        isSyncing = true
        defer { isSyncing = false }

        let memberRole = role == .helper ? "Helper" : "Family"
        let permission = role == .helper ? "Assigned care tasks" : "Monitor and respond"

        guard let accessToken = authSession?.accessToken else {
            authMessage = SupabaseServiceError.missingSession.localizedDescription
            return
        }

        do {
            let response = try await supabaseService.redeemInvitation(
                inviteCode: normalized,
                invitationType: role == .helper ? "helper" : "family",
                displayName: currentUserName,
                accessToken: accessToken
            )
            activeCareCircleID = response.circleID
            generatedInviteCode = response.inviteCode
            ownsActiveCareCircle = false
            currentRole = role
            selectedMainTab = role == .helper ? .helperToday : .overview
            hasCareCircle = true
            isAuthenticated = true
            let snapshot = try await supabaseService.fetchCareCircle(circleID: response.circleID, accessToken: accessToken)
            apply(snapshot: snapshot)
            if recipients.isEmpty {
                addCurrentUserToCareCircle(role: memberRole, permission: permission)
            }
            saveCareCircleSelection()
            authMessage = "Joined care circle \(response.inviteCode)."
            route = role == .helper ? .helperApp : .familyApp
        } catch {
            if role == .helper {
                isAuthenticated = false
                hasCareCircle = false
                route = .helperJoin
            } else {
                route = .joinFamilyCareCircle
            }
            authMessage = error.localizedDescription
        }
    }

    func startCareCircle() async {
        guard !isSyncing else { return }

        let newCircleID = UUID()
        generatedInviteCode = Self.generateInviteCode()
        guard let inviteCode = generatedInviteCode else {
            authMessage = "Could not generate an invite code."
            return
        }

        isSyncing = true
        defer { isSyncing = false }

        if let accessToken = authSession?.accessToken {
            do {
                let response = try await supabaseService.createCareCircle(circleID: newCircleID, inviteCode: inviteCode, displayName: currentUserName, accessToken: accessToken)
                activeCareCircleID = response.circleID
                generatedInviteCode = response.inviteCode
            } catch {
                generatedInviteCode = nil
                authMessage = error.localizedDescription
                return
            }
        } else {
            activeCareCircleID = newCircleID
        }

        ownsActiveCareCircle = true
        clearCareCircleData()
        addCurrentUserToCareCircle(role: "Owner", permission: "Full access")
        currentRole = .family
        hasCareCircle = true
        shouldPromptForFirstCareProfile = true
        saveCareCircleSelection()
        authMessage = "Care circle started. Share invite code \(generatedInviteCode ?? "")."
    }

    func addCareRecipient(name: String, label: String, age: Int, relationship: String) async {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else {
            authMessage = "Enter the care recipient's name."
            return
        }

        let normalizedLabel = label.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Family" : label.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedRelationship = relationship.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Family" : relationship.trimmingCharacters(in: .whitespacesAndNewlines)
        let recipient = CareRecipient(id: UUID(), name: trimmedName, label: normalizedLabel, age: age, relationship: normalizedRelationship, lastUpdated: Date())

        recipients.append(recipient)
        selectedRecipientID = recipient.id
        overviewRecipientID = nil
        shouldPromptForFirstCareProfile = false
        attachCurrentUserToRecipientIfNeeded(recipient.id)
        saveCareCircleSelection()
        authMessage = "Care profile added."
        await syncAllToSupabase()
    }

    func updateCaregiverMode(_ mode: CaregiverMode) {
        caregiverMode = mode
        saveCareCircleSelection()
        syncIfSignedIn()
    }

    func updateHealthFeatureEnabled(_ isEnabled: Bool) {
        guard currentRole.canManageCare else {
            authMessage = "Only family members can change health monitor settings."
            return
        }

        healthFeatureEnabled = isEnabled
        if !isEnabled && selectedMainTab == .health {
            selectedMainTab = currentRole == .helper ? .helperToday : .overview
        }
        record(
            action: isEnabled ? "Turned on Health monitor" : "Turned off Health monitor",
            detail: isEnabled ? "Health readings and the Health tab are visible for this care circle." : "Health readings are hidden from the main tabs and overview.",
            recipientID: selectedRecipientID
        )
        saveCareCircleSelection()
        syncIfSignedIn()
    }

    func updateHelperEditingAccess(_ isEnabled: Bool) {
        guard currentRole.canManageCare else {
            authMessage = "Only family members can change helper permissions."
            return
        }

        let updatedPermission = isEnabled ? Self.helperEditPermission : Self.helperBasePermission
        var changed = false
        for index in members.indices {
            guard members[index].active,
                  members[index].recipientID == selectedRecipientID,
                  members[index].role.caseInsensitiveCompare("Helper") == .orderedSame
            else { continue }
            if members[index].permission != updatedPermission {
                members[index].permission = updatedPermission
                changed = true
            }
        }

        guard changed else { return }
        record(
            action: isEnabled ? "Allowed helper editing" : "Turned off helper editing",
            detail: isEnabled ? "Helpers can add and edit tasks, medicines, planner items and health readings for this profile." : "Helpers can view and complete assigned care without editing records.",
            recipientID: selectedRecipientID
        )
        syncIfSignedIn()
    }

    func handleAuthCallback(_ url: URL) {
        guard url.scheme == "remotelove", url.host == "auth" else { return }
        authMessage = "Email confirmed. Please sign in with your email and password."
    }

    func syncAllToSupabase() async {
        guard let accessToken = authSession?.accessToken, let userID = authSession?.user?.id else {
            authMessage = SupabaseServiceError.missingSession.localizedDescription
            return
        }

        isSyncing = true
        defer { isSyncing = false }

        do {
            if isSharedDemoCircle {
                _ = try await supabaseService.joinDemoCareCircle(
                    displayName: currentUserName,
                    role: currentRole,
                    accessToken: accessToken
                )
                if currentRole.isFamilyExperience {
                    ownsActiveCareCircle = true
                }
            }

            try await supabaseService.upsert([SupabaseProfileRecord(id: userID, displayName: currentUserName)], into: "profiles", accessToken: accessToken)
            if ownsActiveCareCircle {
                try await supabaseService.upsert([SupabaseCareCircleRecord(id: activeCareCircleID, ownerID: userID, name: "\(currentUserName)'s Care Circle", caregiverMode: caregiverMode.rawValue, healthEnabled: healthFeatureEnabled)], into: "care_circles", accessToken: accessToken)
                if let generatedInviteCode {
                    try await supabaseService.upsert([SupabaseCareCircleInviteRecord(code: generatedInviteCode, circleID: activeCareCircleID, createdBy: userID, active: true)], into: "care_circle_invites", accessToken: accessToken, onConflict: "code")
                }
            }
            try await supabaseService.upsert(recipients.map { recipient in
                SupabaseCareRecipientRecord(
                    id: recipient.id,
                    circleID: activeCareCircleID,
                    name: recipient.name,
                    label: recipient.label,
                    age: recipient.age,
                    relationship: recipient.relationship,
                    lastUpdated: recipient.lastUpdated
                )
            }, into: "care_recipients", accessToken: accessToken)
            let memberRecords = members.filter { member in
                member.userID == nil || member.userID != userID
            }.map { member in
                let resolvedUserID: UUID?
                if isSharedDemoCircle {
                    resolvedUserID = member.userID
                } else {
                    resolvedUserID = member.userID ?? (member.name == currentUserName ? userID : nil)
                }
                return SupabaseCircleMemberRecord(
                    id: member.id,
                    circleID: activeCareCircleID,
                    recipientID: member.recipientID,
                    userID: resolvedUserID,
                    name: member.name,
                    role: member.role,
                    permission: member.permission,
                    active: member.active,
                    joinedAt: member.joinedAt
                )
            }
            try await supabaseService.upsert(memberRecords, into: "care_circle_members", accessToken: accessToken)
            try await supabaseService.upsert(tasks.map { task in
                SupabaseCareTaskRecord(
                    id: task.id,
                    recipientID: task.recipientID,
                    title: task.title,
                    instructions: task.instructions,
                    scheduledAt: task.scheduledAt,
                    frequency: task.frequency,
                    requiresPhoto: task.requiresPhoto,
                    state: task.state.rawValue,
                    notifiedAt: task.notifiedAt,
                    medicineID: task.medicineID
                )
            }, into: "care_tasks", accessToken: accessToken)
            try await supabaseService.upsert(medicines.map { medicine in
                SupabaseMedicineRecord(
                    id: medicine.id,
                    recipientID: medicine.recipientID,
                    name: medicine.name,
                    purpose: medicine.purpose,
                    instructions: medicine.instructions,
                    currentSupply: medicine.currentSupply,
                    dose: medicine.dose,
                    unit: medicine.unit,
                    timesDaily: medicine.timesDaily,
                    intervalDays: medicine.intervalDays,
                    attentionDays: medicine.attentionDays,
                    active: medicine.active,
                    firstTime: medicine.firstTime,
                    doseTimes: medicine.doseTimes,
                    repeatWeekdays: medicine.repeatWeekdays
                )
            }, into: "medicines", accessToken: accessToken)
            try await supabaseService.upsert(appointments.map { appointment in
                SupabaseAppointmentRecord(
                    id: appointment.id,
                    recipientID: appointment.recipientID,
                    title: appointment.title,
                    date: appointment.date,
                    notes: appointment.notes,
                    repeatRule: appointment.repeatRule,
                    remindThreeDaysBefore: appointment.remindThreeDaysBefore,
                    reminderEnabled: appointment.reminderEnabled,
                    reminderDaysBefore: appointment.reminderDaysBefore,
                    reminderCount: appointment.reminderCount,
                    state: appointment.state.rawValue
                )
            }, into: "appointments", accessToken: accessToken)
            try await supabaseService.upsert(plannerOtherItems.map { item in
                SupabasePlannerOtherItemRecord(
                    id: item.id,
                    recipientID: item.recipientID,
                    title: item.title,
                    date: item.date,
                    notes: item.notes,
                    repeatRule: item.repeatRule,
                    active: item.active
                )
            }, into: "planner_other_items", accessToken: accessToken)
            try await supabaseService.upsert(healthLogs.map { log in
                SupabaseHealthLogRecord(
                    id: log.id,
                    recipientID: log.recipientID,
                    category: log.category.rawValue,
                    value: log.value,
                    recordedAt: log.recordedAt,
                    notes: log.notes
                )
            }, into: "health_logs", accessToken: accessToken)
            try await supabaseService.upsert(updates.map { update in
                SupabaseCareUpdateRecord(
                    id: update.id,
                    recipientID: update.recipientID,
                    author: update.author,
                    message: update.message,
                    mood: update.mood,
                    createdAt: update.createdAt
                )
            }, into: "care_updates", accessToken: accessToken)
            try await supabaseService.upsert(history.map { event in
                SupabaseActivityEventRecord(
                    id: event.id,
                    recipientID: event.recipientID,
                    actor: event.actor,
                    action: event.action,
                    detail: event.detail,
                    createdAt: event.createdAt
                )
            }, into: "activity_events", accessToken: accessToken)
            authMessage = "Care data synced to Supabase."
        } catch {
            authMessage = "Sync failed: \(error.localizedDescription)"
        }
    }

    func setTask(_ id: UUID, state: TaskState) {
        guard let index = tasks.firstIndex(where: { $0.id == id }) else { return }
        updateTask(at: index, state: state, dateSpecific: false)
    }

    func setTaskForSelectedDate(_ id: UUID, state: TaskState) {
        guard let index = tasks.firstIndex(where: { $0.id == id }) else { return }
        updateTask(at: index, state: state, dateSpecific: true)
    }

    func practiceCompleteFirstHelperTaskForTutorial() -> String {
        guard currentRole == .helper else {
            return "This practice step is only available in the helper view."
        }

        let calendar = Calendar.current
        selectedTaskDate = calendar.startOfDay(for: Date())
        guard let task = tasks(on: selectedTaskDate).first(where: { task in
            task.state != .done && (!task.requiresPhoto || taskPhotoEvidence.contains(task.id))
        }), let index = tasks.firstIndex(where: { $0.id == task.id }) else {
            return "There is no available task to practice with right now. You can continue the tutorial."
        }

        let previousState = tasks[index].state
        tasks[index].state = .done
        authMessage = "Practice complete. We’ll undo it automatically."

        Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 1_000_000_000)
            guard let self, let restoreIndex = self.tasks.firstIndex(where: { $0.id == task.id }) else { return }
            self.tasks[restoreIndex].state = previousState
            self.authMessage = "Practice task restored. Nothing was changed for the family."
        }

        return "Nice. That task was marked done for practice and will be restored automatically."
    }

    func handleNotificationResponse(actionIdentifier: String, userInfo: [AnyHashable: Any]) {
        guard userInfo["kind"] as? String == "task",
              let taskIDString = userInfo["taskID"] as? String,
              let taskID = UUID(uuidString: taskIDString),
              let task = tasks.first(where: { $0.id == taskID }) else {
            return
        }

        let scheduledAt: Date
        if let rawScheduledAt = userInfo["scheduledAt"] as? String,
           let interval = TimeInterval(rawScheduledAt) {
            scheduledAt = Date(timeIntervalSince1970: interval)
        } else {
            scheduledAt = task.scheduledAt
        }

        let requiresPhoto = (userInfo["requiresPhoto"] as? String) == "true" || task.requiresPhoto

        selectedRecipientID = task.recipientID
        selectedTaskDate = Calendar.current.startOfDay(for: scheduledAt)

        switch actionIdentifier {
        case RemoteLoveNotificationScheduler.actionDone:
            if requiresPhoto {
                openTaskFromNotification(task)
                authMessage = "Open the task and attach a photo before marking it done."
                return
            }
            setTaskForSelectedDate(taskID, state: .done)
            RemoteLoveNotificationScheduler.clearTaskNotifications(taskID: taskID)

        case RemoteLoveNotificationScheduler.actionAttending:
            if requiresPhoto {
                openTaskFromNotification(task)
                return
            }
            setTaskForSelectedDate(taskID, state: .attending)
            let attendingTitle = "🧡 Task in progress"
            let attendingBody = "\(recipientLabel(for: task.recipientID))’s \(task.title) is being attended to. Tap Done when finished."
            Task {
                await RemoteLoveNotificationScheduler.sendAttendingTaskNotification(
                    taskID: taskID,
                    recipientID: task.recipientID,
                    scheduledAt: scheduledAt,
                    title: attendingTitle,
                    body: attendingBody
                )
            }

        case RemoteLoveNotificationScheduler.actionOpenTask, UNNotificationDefaultActionIdentifier:
            openTaskFromNotification(task)

        default:
            break
        }
    }

    private func openTaskFromNotification(_ task: CareTask) {
        selectedRecipientID = task.recipientID
        selectedTaskDate = Calendar.current.startOfDay(for: task.scheduledAt)
        pendingDestination = nil
        selectedMainTab = currentRole == .helper ? .helperToday : .care
        if currentRole == .helper {
            route = .helperApp
        } else if currentRole.isFamilyExperience {
            route = .familyApp
        }
    }

    private func updateTask(at index: Int, state: TaskState, dateSpecific: Bool) {
        let task = tasks[index]
        if state == .done, task.requiresPhoto, !taskPhotoEvidence.contains(task.id) {
            authMessage = "Attach a photo before marking this task done."
            return
        }

        if dateSpecific, task.frequency != "Does not repeat" {
            var original = task
            original.frequency = frequency(original.frequency, excluding: selectedTaskDate)
            tasks[index] = original

            var occurrence = task
            occurrence.id = UUID()
            occurrence.frequency = "Does not repeat"
            occurrence.scheduledAt = scheduledDate(on: selectedTaskDate, matchingTimeOf: task.scheduledAt)
            occurrence.state = state
            occurrence.notifiedAt = nil
            tasks.append(occurrence)

            if state == .done, let medicineID = occurrence.medicineID,
               let medicineIndex = medicines.firstIndex(where: { $0.id == medicineID }) {
                medicines[medicineIndex].currentSupply = max(0, medicines[medicineIndex].currentSupply - medicines[medicineIndex].dose)
            }

            touch(occurrence.recipientID)
            record(action: state == .attending ? "Attending to \(occurrence.title)" : "Marked \(occurrence.title) as \(state.label)", detail: "Task status was updated for this date only.", recipientID: occurrence.recipientID)
            if state == .done || state == .paused {
                RemoteLoveNotificationScheduler.cancelTaskNotifications(taskID: occurrence.id)
            }
            refreshScheduledNotifications()
            syncIfSignedIn()
            return
        }

        let wasDone = task.state == .done
        tasks[index].state = state
        if state == .done, !wasDone, let medicineID = tasks[index].medicineID,
           let medicineIndex = medicines.firstIndex(where: { $0.id == medicineID }) {
            medicines[medicineIndex].currentSupply = max(0, medicines[medicineIndex].currentSupply - medicines[medicineIndex].dose)
        }
        touch(tasks[index].recipientID)
        record(action: state == .attending ? "Attending to \(tasks[index].title)" : "Marked \(tasks[index].title) as \(state.label)", detail: dateSpecific ? "Task status was updated for this date only." : "Task status was updated.", recipientID: tasks[index].recipientID)
        if state == .done || state == .paused {
            RemoteLoveNotificationScheduler.cancelTaskNotifications(taskID: tasks[index].id)
        }
        refreshScheduledNotifications()
        syncIfSignedIn()
    }

    func notifyHelper(taskID: UUID) {
        guard let index = tasks.firstIndex(where: { $0.id == taskID }) else { return }
        tasks[index].notifiedAt = Date()
        let taskTitle = tasks[index].title
        let recipientLabel = recipientLabel(for: tasks[index].recipientID)
        record(action: "Notified helper about \(taskTitle)", detail: "The reminder remains active until acknowledged.", recipientID: tasks[index].recipientID)
        Task {
            await RemoteLoveNotificationScheduler.sendImmediate(
                title: "💚 A care task needs attention",
                body: "\(recipientLabel) needs help with \(taskTitle).",
                identifier: "notify-helper.\(taskID.uuidString)"
            )
        }
        refreshScheduledNotifications()
        syncIfSignedIn()
    }

    func saveTask(_ task: CareTask) {
        let tasksBefore = tasks
        if let index = tasks.firstIndex(where: { $0.id == task.id }) {
            tasks[index] = task
            record(action: "Updated \(task.title)", detail: "Task details or schedule changed.", recipientID: task.recipientID)
        } else {
            tasks.append(task)
            record(action: "Added \(task.title)", detail: "New care task was added to the timeline.", recipientID: task.recipientID)
        }
        captureTaskHistory(
            scope: .futureRoutine,
            message: "Routine change saved.",
            date: selectedTaskDate,
            tasksBefore: tasksBefore
        )
        touch(task.recipientID)
        refreshScheduledNotifications()
        syncIfSignedIn()
    }

    func saveTaskOccurrenceOverride(originalTaskID: UUID, editedTask: CareTask, occurrenceDate: Date) {
        guard let index = tasks.firstIndex(where: { $0.id == originalTaskID }) else {
            saveTask(editedTask)
            return
        }

        let tasksBefore = tasks
        var original = tasks[index]
        original.frequency = frequency(original.frequency, excluding: occurrenceDate)
        tasks[index] = original

        var occurrence = editedTask
        occurrence.id = UUID()
        occurrence.frequency = "Does not repeat"
        occurrence.scheduledAt = scheduledDate(on: occurrenceDate, matchingTimeOf: editedTask.scheduledAt)
        tasks.append(occurrence)

        record(action: "Updated \(occurrence.title)", detail: "Only this date was changed.", recipientID: occurrence.recipientID)
        captureTaskHistory(
            scope: .singleDate,
            message: "Date change saved.",
            date: occurrenceDate,
            tasksBefore: tasksBefore
        )
        touch(occurrence.recipientID)
        refreshScheduledNotifications()
        syncIfSignedIn()
    }

    func undoTaskChange(scope: TaskHistoryScope) {
        guard let entry = popLatestHistoryEntry(from: &taskUndoStack, scope: scope) else { return }
        tasks = entry.tasksBefore
        taskRedoStack.append(entry)
        authMessage = "Task changes undone."
        refreshScheduledNotifications()
        syncIfSignedIn()
    }

    func undoTaskChange(entryID: UUID) {
        guard let index = taskUndoStack.firstIndex(where: { $0.id == entryID }) else { return }
        let entry = taskUndoStack.remove(at: index)
        tasks = entry.tasksBefore
        taskRedoStack.append(entry)
        authMessage = "Selected task change undone."
        refreshScheduledNotifications()
        syncIfSignedIn()
    }

    func redoTaskChange(scope: TaskHistoryScope) {
        guard let entry = popLatestHistoryEntry(from: &taskRedoStack, scope: scope) else { return }
        tasks = entry.tasksAfter
        taskUndoStack.append(entry)
        authMessage = "Task changes redone."
        refreshScheduledNotifications()
        syncIfSignedIn()
    }

    func redoTaskChange(entryID: UUID) {
        guard let index = taskRedoStack.firstIndex(where: { $0.id == entryID }) else { return }
        let entry = taskRedoStack.remove(at: index)
        tasks = entry.tasksAfter
        taskUndoStack.append(entry)
        authMessage = "Selected task change redone."
        refreshScheduledNotifications()
        syncIfSignedIn()
    }

    func removeTasks(_ ids: Set<UUID>) {
        let affected = tasks.filter { ids.contains($0.id) }
        tasks.removeAll { ids.contains($0.id) }
        for task in affected {
            record(action: "Removed \(task.title)", detail: "Task was removed through task management.", recipientID: task.recipientID)
            RemoteLoveNotificationScheduler.cancelTaskNotifications(taskID: task.id)
        }
        refreshScheduledNotifications()
        syncIfSignedIn()
    }

    func saveMedicine(_ medicine: Medicine) {
        if let index = medicines.firstIndex(where: { $0.id == medicine.id }) {
            medicines[index] = medicine
            record(action: "Updated \(medicine.name)", detail: "Medicine schedule or supply changed.", recipientID: medicine.recipientID)
        } else {
            medicines.append(medicine)
            record(action: "Added \(medicine.name)", detail: "Medicine was added to Planner.", recipientID: medicine.recipientID)
        }
        syncMedicineTasks(for: medicine)
        touch(medicine.recipientID)
        refreshScheduledNotifications()
        syncIfSignedIn()
    }

    func toggleMedicine(_ id: UUID) {
        guard let index = medicines.firstIndex(where: { $0.id == id }) else { return }
        medicines[index].active.toggle()
        record(action: medicines[index].active ? "Resumed \(medicines[index].name)" : "Paused \(medicines[index].name)", detail: medicines[index].active ? "Returned to helper tasks and Planner." : "Hidden from helper tasks and Planner calendar.", recipientID: medicines[index].recipientID)
        syncMedicineTasks(for: medicines[index])
        refreshScheduledNotifications()
        syncIfSignedIn()
    }

    func saveAppointment(_ appointment: CareAppointment) {
        if let index = appointments.firstIndex(where: { $0.id == appointment.id }) {
            appointments[index] = appointment
            record(action: "Updated \(appointment.title)", detail: "Appointment details changed.", recipientID: appointment.recipientID)
        } else {
            appointments.append(appointment)
            record(action: "Added \(appointment.title)", detail: "Appointment was added to Planner.", recipientID: appointment.recipientID)
        }
        syncAppointmentTask(for: appointment)
        touch(appointment.recipientID)
        refreshScheduledNotifications()
        syncIfSignedIn()
    }

    func savePlannerOtherItem(_ item: PlannerOtherItem) {
        if let index = plannerOtherItems.firstIndex(where: { $0.id == item.id }) {
            plannerOtherItems[index] = item
            record(action: "Updated \(item.title)", detail: "Other planner item details changed.", recipientID: item.recipientID)
        } else {
            plannerOtherItems.append(item)
            record(action: "Added \(item.title)", detail: "Other item was added to Planner.", recipientID: item.recipientID)
        }
        syncPlannerOtherTask(for: item)
        touch(item.recipientID)
        refreshScheduledNotifications()
        syncIfSignedIn()
    }

    func removePlannerOtherItem(_ id: UUID) {
        guard let item = plannerOtherItems.first(where: { $0.id == id }) else { return }
        plannerOtherItems.removeAll { $0.id == id }
        removePlannerMirrorTasks(kind: "other", sourceID: id)
        record(action: "Removed \(item.title)", detail: "Other planner item was removed.", recipientID: item.recipientID)
        refreshScheduledNotifications()
        syncIfSignedIn()
    }

    func removeAppointment(_ id: UUID) {
        guard let appointment = appointments.first(where: { $0.id == id }) else { return }
        appointments.removeAll { $0.id == id }
        removePlannerMirrorTasks(kind: "appointment", sourceID: id)
        record(action: "Removed \(appointment.title)", detail: "Appointment and reminder were removed.", recipientID: appointment.recipientID)
        RemoteLoveNotificationScheduler.cancelAppointmentNotifications(appointmentID: id)
        refreshScheduledNotifications()
        syncIfSignedIn()
    }

    func addHealthLog(category: HealthCategory, value: Double, notes: String) {
        guard canLogHealthRecords else {
            authMessage = "Health logging is not available for this access level."
            return
        }
        let log = HealthLog(id: UUID(), recipientID: selectedRecipientID, category: category, value: value, recordedAt: Date(), notes: notes)
        healthLogs.append(log)
        record(action: "Recorded \(category.label)", detail: "\(value.formatted()) \(category.unit)", recipientID: selectedRecipientID)
        touch(selectedRecipientID)
        syncIfSignedIn()
    }

    func addHealthLogAndSync(category: HealthCategory, value: Double, notes: String) async {
        guard canLogHealthRecords else {
            authMessage = "Health logging is not available for this access level."
            return
        }
        let log = HealthLog(id: UUID(), recipientID: selectedRecipientID, category: category, value: value, recordedAt: Date(), notes: notes)
        healthLogs.append(log)
        record(action: "Recorded \(category.label)", detail: "\(value.formatted()) \(category.unit)", recipientID: selectedRecipientID)
        touch(selectedRecipientID)
        await syncAllToSupabase()
    }

    func sendUpdate(message: String, mood: String) {
        let update = CareUpdate(id: UUID(), recipientID: selectedRecipientID, author: currentUserName, message: message, mood: mood, createdAt: Date())
        updates.insert(update, at: 0)
        record(action: "Sent a care update", detail: message, recipientID: selectedRecipientID)
        touch(selectedRecipientID)
        syncIfSignedIn()
    }

    private func notifyFamilyAboutHelperMute(until: Date) {
        let detail: String
        if until > Date.distantFuture.addingTimeInterval(-10_000) {
            detail = "\(currentUserName) muted RemoteLove notifications forever."
        } else {
            detail = "\(currentUserName) muted RemoteLove notifications until \(until.formatted(date: .abbreviated, time: .shortened))."
        }

        updates.insert(
            CareUpdate(
                id: UUID(),
                recipientID: selectedRecipientID,
                author: "RemoteLove",
                message: detail,
                mood: "Muted",
                createdAt: Date()
            ),
            at: 0
        )
        record(action: "Helper muted notifications", detail: detail, recipientID: selectedRecipientID)
        touch(selectedRecipientID)
        authMessage = detail
        syncIfSignedIn()
    }

    func triggerEmergency(message: String) {
        emergencyMessage = message
        let recipientLabel = selectedRecipient.label
        record(action: "Raised an emergency alert", detail: message, recipientID: selectedRecipientID)
        Task {
            await RemoteLoveNotificationScheduler.sendImmediate(
                title: "🚨 Urgent family alert",
                body: "\(recipientLabel) may need help now. \(message)",
                identifier: "emergency.\(UUID().uuidString)"
            )
        }
        syncIfSignedIn()
    }

    func acknowledgeEmergency() {
        guard let message = emergencyMessage else { return }
        emergencyMessage = nil
        record(action: "Acknowledged emergency alert", detail: message, recipientID: selectedRecipientID)
        syncIfSignedIn()
    }

    func removeHelper(_ member: CircleMember) {
        guard let index = members.firstIndex(where: { $0.id == member.id }) else { return }
        members[index].active = false
        record(action: "Removed helper \(member.name)", detail: "Helper access was deactivated.", recipientID: member.recipientID ?? selectedRecipientID)
        syncIfSignedIn()
    }

    func purchaseCarePlan(_ plan: CarePlan) async {
        await activateCarePlan(plan, status: .active)
    }

    func startCarePlanTrial(_ plan: CarePlan) async {
        await activateCarePlan(plan, status: .trialing)
    }

    func cancelCarePlan() async {
        guard currentRole.canManageCare else {
            authMessage = "Only family members can buy or change the care-circle plan."
            return
        }

        guard !isSyncing else { return }

        isSyncing = true
        defer { isSyncing = false }

        if let accessToken = authSession?.accessToken, let userID = authSession?.user?.id {
            do {
                try await supabaseService.saveCarePlanEntitlement(
                    circleID: activeCareCircleID,
                    plan: .free,
                    status: .inactive,
                    buyerUserID: userID,
                    accessToken: accessToken
                )
            } catch {
                authMessage = "Care plan cancellation could not be saved. Please try again."
                return
            }
        }

        activeCarePlan = .free
        carePlanStatus = .inactive
        carePlanPeriodEndsAt = nil
        saveCarePlanSelection()
        if let recipientID = recipients.first?.id {
            record(
                action: "Cancelled care plan",
                detail: "The care circle returned to the Free plan immediately.",
                recipientID: recipientID
            )
        }
        authMessage = "Care plan cancelled. The care circle is back on Free."
    }

    private func activateCarePlan(_ plan: CarePlan, status: CarePlanStatus) async {
        guard currentRole.canManageCare else {
            authMessage = "Only family members can buy or change the care-circle plan."
            return
        }

        guard !isSyncing else { return }
        guard plan.isPaid else {
            await cancelCarePlan()
            return
        }

        isSyncing = true
        defer { isSyncing = false }

        if let accessToken = authSession?.accessToken, let userID = authSession?.user?.id {
            do {
                try await supabaseService.saveCarePlanEntitlement(
                    circleID: activeCareCircleID,
                    plan: plan,
                    status: status,
                    buyerUserID: userID,
                    accessToken: accessToken
                )
            } catch {
                authMessage = status == .trialing ? "Care plan trial could not be saved. Please try again." : "Care plan purchase could not be saved. Please try again."
                return
            }
        }

        activeCarePlan = plan
        carePlanStatus = status
        carePlanPeriodEndsAt = status == .trialing ? plan.trialEnd(from: Date()) : plan.currentPeriodEnd(from: Date())
        saveCarePlanSelection()
        if let recipientID = recipients.first?.id {
            record(
                action: status == .trialing ? "Started \(plan.name) trial" : "Activated \(plan.name) plan",
                detail: status == .trialing ? "3-day trial access is shared with all current and future care-circle members." : "\(plan.billing) access is shared with all current and future care-circle members.",
                recipientID: recipientID
            )
        }
        authMessage = status == .trialing ? "\(plan.name) trial started for this care circle." : "\(plan.name) \(plan.billing.lowercased()) plan activated for this care circle."
    }

    private func authenticateWithSupabase(name: String, email: String, password: String, createsAccount: Bool) async {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let displayName = trimmedName.isEmpty ? currentUserName : trimmedName
        let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedEmail.isEmpty, !password.isEmpty else {
            authMessage = "Enter an email address and password."
            return
        }

        guard !createsAccount || PasswordPolicy.isValid(password) else {
            authMessage = "Create a password with at least 8 characters, including uppercase and lowercase letters, a number, and a special character."
            return
        }

        isSyncing = true
        defer { isSyncing = false }

        do {
            resetCareCircleSessionState()
            let session = createsAccount
                ? try await supabaseService.signUp(email: trimmedEmail, password: password, displayName: displayName)
                : try await supabaseService.signIn(email: trimmedEmail, password: password)

            authSession = session
            persistAuthSession()
            currentUserName = displayName
            currentRole = .family
            selectedMainTab = .overview
            isAuthenticated = true
            if createsAccount {
                guard session.accessToken != nil else {
                    authSession = nil
                    clearPersistedSession()
                    isAuthenticated = false
                    hasCareCircle = false
                    route = .familyAuthentication
                    authMessage = "Account created. Please confirm your email, then sign in before setting up care."
                    return
                }
                hasCareCircle = false
                clearCareCircleData()
                route = .familyGettingStarted
                authMessage = "Account created. Choose how you would like to get started."
            } else {
                await resolveFamilyRoute(userID: session.user?.id, accessToken: session.accessToken)
            }
        } catch {
            authSession = nil
            clearPersistedSession()
            isAuthenticated = false
            hasCareCircle = false
            route = .familyAuthentication
            authMessage = error.localizedDescription
        }
    }

    private func resolveFamilyRoute(userID: UUID?, accessToken: String?) async {
        guard let userID, let accessToken else {
            hasCareCircle = false
            route = .familyGettingStarted
            return
        }

        do {
            let activeMemberships = try await supabaseService.fetchActiveMemberships(
                userID: userID,
                accessToken: accessToken
            )
            guard let membership = activeMemberships.first else {
                hasCareCircle = false
                route = .familyGettingStarted
                authMessage = "Signed in. Choose how you would like to get started."
                return
            }

            activeCareCircleID = membership.circleID
            currentRole = role(from: membership.role)
            if currentRole == .helper,
               let userID = authSession?.user?.id,
               let savedName = UserDefaults.standard.string(forKey: helperNameStorageKey(userID: userID)) {
                currentUserName = savedName
            }
            ownsActiveCareCircle = currentRole == .owner
            let snapshot = try await supabaseService.fetchCareCircle(
                circleID: membership.circleID,
                accessToken: accessToken
            )
            apply(snapshot: snapshot)
            hasCareCircle = true
            selectedMainTab = currentRole == .helper ? .helperToday : .overview
            route = currentRole == .helper ? .helperApp : .familyApp
            authMessage = "Signed in with Supabase."
        } catch {
            hasCareCircle = false
            route = .familyGettingStarted
            authMessage = error.localizedDescription
        }
    }

    private func resolveRouteForCurrentSession(unlockedHelper: Bool = false) async {
        guard let userID = authSession?.user?.id, let accessToken = authSession?.accessToken else {
            clearSensitiveCareState()
            route = .welcome
            return
        }

        do {
            let activeMemberships = try await supabaseService.fetchActiveMemberships(
                userID: userID,
                accessToken: accessToken
            )
            guard let membership = activeMemberships.first else {
                resetCareCircleSessionState()
                clearCareCircleData()
                isAuthenticated = true
                currentRole = .family
                selectedMainTab = .overview
                route = .familyGettingStarted
                authMessage = "Signed in. Choose how you would like to get started."
                return
            }

            activeCareCircleID = membership.circleID
            currentRole = role(from: membership.role)
            ownsActiveCareCircle = currentRole == .owner
            let snapshot = try await supabaseService.fetchCareCircle(
                circleID: membership.circleID,
                accessToken: accessToken
            )
            apply(snapshot: snapshot)
            hasCareCircle = true
            isAuthenticated = true
            selectedMainTab = currentRole == .helper ? .helperToday : .overview
            route = currentRole == .helper ? .helperApp : .familyApp
            authMessage = nil
            if currentRole == .helper && !unlockedHelper {
                if hasStoredHelperPIN() {
                    route = .helperPinLock
                } else {
                    isAuthenticated = false
                    hasCareCircle = false
                    route = .helperJoin
                    authMessage = "Please join again to create your helper PIN."
                }
            }
        } catch {
            clearSensitiveCareState()
            isAuthenticated = false
            route = .welcome
            authMessage = "Please sign in again."
        }
    }

    private func refreshScheduledNotifications() {
        guard isAuthenticated, hasCareCircle else { return }
        refreshWidgetSnapshot()
        if notificationsAreMuted {
            Task {
                await RemoteLoveNotificationScheduler.cancelAllRemoteLoveNotifications()
            }
            return
        }
        if let notificationsMutedUntil, notificationsMutedUntil <= Date() {
            self.notificationsMutedUntil = nil
            saveNotificationMuteSelection()
        }
        let notifications = upcomingLocalNotifications()
        Task {
            await RemoteLoveNotificationScheduler.replaceScheduledCareReminders(with: notifications)
        }
    }

    private func refreshWidgetSnapshot() {
        guard let defaults = UserDefaults(suiteName: Self.widgetAppGroupID) else { return }

        let todayTasks = tasks(on: Date())
        let doneCount = todayTasks.filter { $0.state == .done }.count
        let nextTask = todayTasks.first { $0.state != .done && $0.state != .paused }
        let lowMedicineCount = medicines.filter {
            $0.recipientID == selectedRecipientID && $0.active && $0.daysRemaining <= $0.attentionDays
        }.count
        let attentionHealthCount = healthLogs
            .filter { $0.recipientID == selectedRecipientID }
            .reduce(into: [HealthCategory: HealthLog]()) { latest, log in
                if let existing = latest[log.category], existing.recordedAt > log.recordedAt {
                    return
                }
                latest[log.category] = log
            }
            .values
            .filter { $0.category.status(for: $0.value, age: selectedRecipient.age) == .needsAttention }
            .count

        let snapshot = RemoteLoveWidgetSnapshot(
            updatedAt: Date(),
            recipientName: selectedRecipient.name,
            recipientLabel: selectedRecipient.label,
            roleName: currentRole.rawValue.capitalized,
            completedTaskCount: doneCount,
            totalTaskCount: todayTasks.count,
            nextTaskID: nextTask?.id,
            nextTaskRecipientID: nextTask?.recipientID,
            nextTaskTitle: nextTask?.title,
            nextTaskTime: nextTask?.scheduledAt,
            nextTaskRequiresPhoto: nextTask?.requiresPhoto ?? false,
            medicineAttentionCount: lowMedicineCount,
            healthAttentionCount: attentionHealthCount
        )

        if let data = try? JSONEncoder().encode(snapshot) {
            defaults.set(data, forKey: Self.widgetSnapshotKey)
            WidgetCenter.shared.reloadTimelines(ofKind: "RemoteLoveWidgets")
        }
    }

    private func applyQueuedWidgetActions() {
        guard let defaults = UserDefaults(suiteName: Self.widgetAppGroupID),
              let data = defaults.data(forKey: Self.widgetQueuedActionsKey),
              let actions = try? JSONDecoder().decode([RemoteLoveWidgetQueuedAction].self, from: data),
              actions.isEmpty == false else { return }

        defaults.removeObject(forKey: Self.widgetQueuedActionsKey)

        for action in actions where action.kind == .completeTask {
            selectedRecipientID = action.recipientID
            selectedTaskDate = Calendar.current.startOfDay(for: action.scheduledAt)
            setTaskForSelectedDate(action.taskID, state: .done)
        }

        refreshWidgetSnapshot()
        syncIfSignedIn()
    }

    private func upcomingLocalNotifications() -> [RemoteLoveLocalNotification] {
        let now = Date()
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: now)
        let days = (0..<30).compactMap { calendar.date(byAdding: .day, value: $0, to: today) }
        var notifications: [RemoteLoveLocalNotification] = []

        for recipient in recipients {
            let recipientTasks = tasks.filter { $0.recipientID == recipient.id && $0.state != .done && $0.state != .paused }
            for day in days {
                for task in recipientTasks where self.task(task, occursOn: day) {
                    let scheduledAt = scheduledDate(on: day, matchingTimeOf: task.scheduledAt)
                    if scheduledAt > now {
                        notifications.append(
                            RemoteLoveLocalNotification(
                                identifier: RemoteLoveNotificationScheduler.taskIdentifier(taskID: task.id, date: scheduledAt, kind: "due"),
                                title: "⏰ Time for a care task",
                                body: "\(recipient.label)’s \(task.title) is scheduled now.",
                                date: scheduledAt,
                                categoryIdentifier: task.requiresPhoto ? RemoteLoveNotificationScheduler.taskPhotoCategory : RemoteLoveNotificationScheduler.taskStandardCategory,
                                userInfo: RemoteLoveNotificationScheduler.taskUserInfo(taskID: task.id, recipientID: task.recipientID, scheduledAt: scheduledAt, requiresPhoto: task.requiresPhoto)
                            )
                        )
                    }

                    if let missedAt = calendar.date(byAdding: .minute, value: 30, to: scheduledAt), missedAt > now {
                        notifications.append(
                            RemoteLoveLocalNotification(
                                identifier: RemoteLoveNotificationScheduler.taskIdentifier(taskID: task.id, date: missedAt, kind: "missed"),
                                title: "🧡 Still waiting on this task",
                                body: "\(recipient.label)’s \(task.title) is still open.",
                                date: missedAt,
                                categoryIdentifier: task.requiresPhoto ? RemoteLoveNotificationScheduler.taskPhotoCategory : RemoteLoveNotificationScheduler.taskStandardCategory,
                                userInfo: RemoteLoveNotificationScheduler.taskUserInfo(taskID: task.id, recipientID: task.recipientID, scheduledAt: scheduledAt, requiresPhoto: task.requiresPhoto)
                            )
                        )
                    }
                }
            }
        }

        notifications.append(contentsOf: upcomingMedicineNotifications(now: now, calendar: calendar))
        notifications.append(contentsOf: upcomingAppointmentNotifications(now: now, calendar: calendar))
        return Array(notifications.sorted { $0.date < $1.date }.prefix(60))
    }

    private func upcomingMedicineNotifications(now: Date, calendar: Calendar) -> [RemoteLoveLocalNotification] {
        let today = calendar.startOfDay(for: now)
        let days = (0..<14).compactMap { calendar.date(byAdding: .day, value: $0, to: today) }
        var notifications: [RemoteLoveLocalNotification] = []

        for medicine in medicines where medicine.active {
            let recipient = recipientLabel(for: medicine.recipientID)
            let firstDay = calendar.startOfDay(for: medicine.firstTime)
            for day in days {
                let daysFromFirst = calendar.dateComponents([.day], from: firstDay, to: day).day ?? 0
                guard daysFromFirst >= 0 else { continue }

                if let weekdays = medicine.repeatWeekdays, weekdays.isEmpty == false {
                    guard weekdays.contains(calendar.component(.weekday, from: day)) else { continue }
                } else {
                    guard daysFromFirst % max(medicine.intervalDays, 1) == 0 else { continue }
                }

                for doseSlot in medicine.scheduledDoseTimes {
                    let doseTime = scheduledDate(on: day, matchingTimeOf: doseSlot)
                    guard doseTime > now else { continue }
                    notifications.append(
                        RemoteLoveLocalNotification(
                            identifier: RemoteLoveNotificationScheduler.medicineIdentifier(medicineID: medicine.id, date: doseTime),
                            title: "💊 Medicine time",
                            body: "\(recipient) needs \(medicine.name). \(medicine.instructions)",
                            date: doseTime
                        )
                    )
                }
            }

            if medicine.daysRemaining <= medicine.attentionDays,
               let supplyCheck = calendar.date(bySettingHour: 9, minute: 0, second: 0, of: today.addingTimeInterval(86_400)),
               supplyCheck > now {
                notifications.append(
                    RemoteLoveLocalNotification(
                        identifier: "RemoteLove.local.medicine.\(medicine.id.uuidString).supply",
                        title: "🧡 Refill check",
                        body: "\(recipient)’s \(medicine.name) may need a refill soon.",
                        date: supplyCheck
                    )
                )
            }
        }

        return Array(notifications.sorted { $0.date < $1.date }.prefix(24))
    }

    private func upcomingAppointmentNotifications(now: Date, calendar: Calendar) -> [RemoteLoveLocalNotification] {
        var notifications: [RemoteLoveLocalNotification] = []
        for appointment in appointments where appointment.state == .scheduled {
            let recipient = recipientLabel(for: appointment.recipientID)
            if appointment.date > now {
                notifications.append(
                    RemoteLoveLocalNotification(
                        identifier: RemoteLoveNotificationScheduler.appointmentIdentifier(appointmentID: appointment.id, date: appointment.date, kind: "due"),
                        title: "📅 Appointment coming up",
                        body: "\(recipient) has \(appointment.title) soon.",
                        date: appointment.date
                    )
                )
            }

            if appointment.reminderEnabled {
                for daysBefore in appointmentReminderOffsets(for: appointment) {
                    guard let reminderDate = calendar.date(byAdding: .day, value: -daysBefore, to: appointment.date),
                          reminderDate > now else { continue }

                    notifications.append(
                        RemoteLoveLocalNotification(
                            identifier: RemoteLoveNotificationScheduler.appointmentIdentifier(appointmentID: appointment.id, date: reminderDate, kind: "reminder-\(daysBefore)-days"),
                            title: daysBefore == 1 ? "📅 Appointment tomorrow" : "📅 Appointment in \(daysBefore) days",
                            body: "\(recipient) has \(appointment.title) coming up.",
                            date: reminderDate
                        )
                    )
                }
            }
        }
        return Array(notifications.sorted { $0.date < $1.date }.prefix(12))
    }

    private func appointmentReminderOffsets(for appointment: CareAppointment) -> [Int] {
        let daysBefore = max(0, appointment.reminderDaysBefore)
        guard daysBefore > 0 else { return [] }

        let reminderCount = min(max(1, appointment.reminderCount), daysBefore)
        guard reminderCount > 1 else { return [daysBefore] }

        let step = Double(daysBefore - 1) / Double(reminderCount - 1)
        let offsets = (0..<reminderCount).map { index in
            max(1, Int(round(Double(daysBefore) - (Double(index) * step))))
        }

        return Array(Set(offsets)).sorted(by: >)
    }

    private func recipientLabel(for recipientID: UUID) -> String {
        recipients.first(where: { $0.id == recipientID })?.label ?? "this care profile"
    }

    private func syncIfSignedIn() {
        guard hasCareCircle else { return }

        if authSession?.accessToken == nil {
            guard isSharedDemoCircle else {
                authMessage = SupabaseServiceError.missingSession.localizedDescription
                return
            }

            Task {
                do {
                    authSession = try await supabaseService.signInAnonymously(displayName: currentUserName)
                    persistAuthSession()
                    await syncAllToSupabase()
                } catch {
                    authMessage = "Sync failed: \(error.localizedDescription)"
                }
            }
            return
        }

        Task { await syncAllToSupabase() }
    }

    private func role(from value: String) -> UserRole {
        switch value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "owner":
            return .owner
        case "helper":
            return .helper
        case "viewer":
            return .viewer
        default:
            return .family
        }
    }

    private func persistAuthSession() {
        guard let authSession, let data = try? JSONEncoder().encode(authSession) else { return }
        UserDefaults.standard.set(data, forKey: Self.authSessionStorageKey)
    }

    private func persistedAuthSession() -> SupabaseAuthSession? {
        guard
            let data = UserDefaults.standard.data(forKey: Self.authSessionStorageKey),
            let session = try? JSONDecoder().decode(SupabaseAuthSession.self, from: data),
            session.accessToken != nil
        else { return nil }
        return session
    }

    private func clearPersistedSession() {
        UserDefaults.standard.removeObject(forKey: Self.authSessionStorageKey)
    }

    private func saveHelperPIN(_ pin: String) {
        guard let userID = authSession?.user?.id else { return }
        UserDefaults.standard.set(Self.helperPINHash(pin, userID: userID), forKey: helperPINStorageKey(userID: userID))
        UserDefaults.standard.set(currentUserName, forKey: helperNameStorageKey(userID: userID))
    }

    private func clearHelperPINForCurrentSession() {
        guard let userID = authSession?.user?.id else { return }
        UserDefaults.standard.removeObject(forKey: helperPINStorageKey(userID: userID))
        UserDefaults.standard.removeObject(forKey: helperNameStorageKey(userID: userID))
    }

    private func clearPersistedHelperAccount() {
        if let session = persistedAuthSession(), let userID = session.user?.id {
            UserDefaults.standard.removeObject(forKey: helperPINStorageKey(userID: userID))
            UserDefaults.standard.removeObject(forKey: helperNameStorageKey(userID: userID))
        }
        clearPersistedSession()
    }

    private func hasStoredHelperPIN() -> Bool {
        guard let userID = authSession?.user?.id else { return false }
        return UserDefaults.standard.string(forKey: helperPINStorageKey(userID: userID)) != nil
    }

    private func helperPINStorageKey(userID: UUID) -> String {
        "RemoteLove.helperPIN.\(userID.uuidString)"
    }

    private func helperNameStorageKey(userID: UUID) -> String {
        "RemoteLove.helperName.\(userID.uuidString)"
    }

    private static func isValidHelperPIN(_ pin: String) -> Bool {
        (4...6).contains(pin.count) && pin.allSatisfy(\.isNumber)
    }

    private static func helperPINHash(_ pin: String, userID: UUID) -> String {
        let input = "\(userID.uuidString):\(pin):RemoteLove.helper.pin"
        let digest = SHA256.hash(data: Data(input.utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    private func addCurrentUserToCareCircle(role: String, permission: String) {
        let userID = authSession?.user?.id
        if let userID, members.contains(where: { $0.userID == userID }) {
            return
        }
        if members.contains(where: { $0.name == currentUserName && $0.recipientID == recipients.first?.id }) {
            return
        }

        members.append(CircleMember(
            id: UUID(),
            recipientID: recipients.first?.id,
            userID: userID,
            name: currentUserName,
            role: role,
            permission: permission,
            active: true,
            joinedAt: Date()
        ))
    }

    private func attachCurrentUserToRecipientIfNeeded(_ recipientID: UUID) {
        let userID = authSession?.user?.id
        if let userID, let index = members.firstIndex(where: { $0.userID == userID }) {
            members[index].recipientID = recipientID
            return
        }
        if let index = members.firstIndex(where: { $0.name == currentUserName && $0.recipientID == nil }) {
            members[index].recipientID = recipientID
            return
        }
        addCurrentUserToCareCircle(role: "Owner", permission: "Full access")
    }

    private static func generateInviteCode() -> String {
        let characters = Array("ABCDEFGHJKLMNPQRSTUVWXYZ23456789")
        return String((0..<8).compactMap { _ in characters.randomElement() })
    }

    private func loadDemoCareCircle() {
        activeCareCircleID = DemoFixtures.careCircleID
        restoreCarePlanSelection(for: activeCareCircleID)
        generatedInviteCode = "LOVE2026"
        helperInviteCode = "LOVE2026"
        caregiverMode = .both
        healthFeatureEnabled = true
        shouldPromptForFirstCareProfile = false
        ownsActiveCareCircle = false
        selectedRecipientID = DemoFixtures.mumID
        overviewRecipientID = nil
        recipients = DemoFixtures.recipients
        tasks = DemoFixtures.tasks
        medicines = DemoFixtures.medicines
        appointments = DemoFixtures.appointments
        plannerOtherItems = DemoFixtures.plannerOtherItems
        healthLogs = DemoFixtures.healthLogs
        members = DemoFixtures.members
        updates = DemoFixtures.updates
        history = DemoFixtures.history
        refreshScheduledNotifications()
    }

    private func shouldSeedSharedDemo(from snapshot: SupabaseCareCircleSnapshot) -> Bool {
        snapshot.recipients.isEmpty
            || snapshot.tasks.isEmpty
            || snapshot.medicines.isEmpty
            || snapshot.appointments.isEmpty
            || snapshot.healthLogs.isEmpty
    }

    private func clearCareCircleData() {
        selectedRecipientID = UUID()
        overviewRecipientID = nil
        recipients = []
        tasks = []
        medicines = []
        appointments = []
        plannerOtherItems = []
        healthLogs = []
        members = []
        updates = []
        history = []
        taskPhotoEvidence = []
        emergencyMessage = nil
        caregiverMode = .helperOnly
        healthFeatureEnabled = true
    }

    private func clearSensitiveCareState() {
        generatedInviteCode = nil
        helperInviteCode = nil
        activeCarePlan = .free
        carePlanStatus = .inactive
        carePlanPeriodEndsAt = nil
        caregiverMode = .helperOnly
        healthFeatureEnabled = true
        shouldPromptForFirstCareProfile = false
        activeCareCircleID = DemoFixtures.careCircleID
        ownsActiveCareCircle = false
        selectedMainTab = .overview
        pendingDestination = nil
        clearCareCircleData()
    }

    private func resetCareCircleSessionState() {
        hasCareCircle = false
        generatedInviteCode = nil
        helperInviteCode = nil
        activeCarePlan = .free
        carePlanStatus = .inactive
        carePlanPeriodEndsAt = nil
        caregiverMode = .helperOnly
        healthFeatureEnabled = true
        shouldPromptForFirstCareProfile = false
        activeCareCircleID = DemoFixtures.careCircleID
        ownsActiveCareCircle = false
        selectedMainTab = .overview
        pendingDestination = nil
    }

    private func saveCareCircleSelection() {
        guard let userID = authSession?.user?.id, let generatedInviteCode else { return }
        let prefix = "RemoteLove.careCircle.\(userID.uuidString)"
        UserDefaults.standard.set(activeCareCircleID.uuidString, forKey: "\(prefix).id")
        UserDefaults.standard.set(generatedInviteCode, forKey: "\(prefix).inviteCode")
        if let helperInviteCode {
            UserDefaults.standard.set(helperInviteCode, forKey: "\(prefix).helperInviteCode")
        }
        UserDefaults.standard.set(ownsActiveCareCircle, forKey: "\(prefix).isOwner")
        UserDefaults.standard.set(healthFeatureEnabled, forKey: "\(prefix).healthEnabled")
        saveCarePlanSelection()
    }

    private func restoreCareCircleSelection() {
        guard let userID = authSession?.user?.id else { return }
        let prefix = "RemoteLove.careCircle.\(userID.uuidString)"
        guard
            let circleIDString = UserDefaults.standard.string(forKey: "\(prefix).id"),
            let circleID = UUID(uuidString: circleIDString),
            let inviteCode = UserDefaults.standard.string(forKey: "\(prefix).inviteCode")
        else { return }

        activeCareCircleID = circleID
        restoreCarePlanSelection(for: circleID)
        generatedInviteCode = inviteCode
        helperInviteCode = UserDefaults.standard.string(forKey: "\(prefix).helperInviteCode")
        ownsActiveCareCircle = UserDefaults.standard.bool(forKey: "\(prefix).isOwner")
        if UserDefaults.standard.object(forKey: "\(prefix).healthEnabled") != nil {
            healthFeatureEnabled = UserDefaults.standard.bool(forKey: "\(prefix).healthEnabled")
        } else {
            healthFeatureEnabled = true
        }
        hasCareCircle = true

        if inviteCode == "LOVE2026" {
            loadDemoCareCircle()
            hasCareCircle = true
        } else {
            clearCareCircleData()
            addCurrentUserToCareCircle(role: ownsActiveCareCircle ? "Owner" : "Family", permission: ownsActiveCareCircle ? "Full access" : "Monitor and respond")
        }
    }

    private func saveCarePlanSelection() {
        UserDefaults.standard.set(activeCarePlan.rawValue, forKey: carePlanStorageKey(circleID: activeCareCircleID))
        UserDefaults.standard.set(carePlanStatus.rawValue, forKey: "\(carePlanStorageKey(circleID: activeCareCircleID)).status")
        UserDefaults.standard.set(carePlanPeriodEndsAt, forKey: "\(carePlanStorageKey(circleID: activeCareCircleID)).periodEndsAt")
    }

    private func restoreCarePlanSelection(for circleID: UUID) {
        let rawPlan = UserDefaults.standard.string(forKey: carePlanStorageKey(circleID: circleID))
        activeCarePlan = rawPlan.flatMap(CarePlan.init(rawValue:)) ?? .free
        let rawStatus = UserDefaults.standard.string(forKey: "\(carePlanStorageKey(circleID: circleID)).status")
        carePlanStatus = rawStatus.flatMap(CarePlanStatus.init(rawValue:)) ?? (activeCarePlan.isPaid ? .active : .inactive)
        carePlanPeriodEndsAt = UserDefaults.standard.object(forKey: "\(carePlanStorageKey(circleID: circleID)).periodEndsAt") as? Date
    }

    private func restoreNotificationMuteSelection() {
        guard let date = UserDefaults.standard.object(forKey: notificationMuteStorageKey()) as? Date else {
            notificationsMutedUntil = nil
            return
        }

        if date <= Date() {
            notificationsMutedUntil = nil
            UserDefaults.standard.removeObject(forKey: notificationMuteStorageKey())
        } else {
            notificationsMutedUntil = date
        }
    }

    private func saveNotificationMuteSelection() {
        let key = notificationMuteStorageKey()
        if let notificationsMutedUntil {
            UserDefaults.standard.set(notificationsMutedUntil, forKey: key)
        } else {
            UserDefaults.standard.removeObject(forKey: key)
        }
    }

    private func notificationMuteStorageKey() -> String {
        let userPart = authSession?.user?.id.uuidString ?? "preview"
        return "RemoteLove.notificationMute.\(userPart).\(activeCareCircleID.uuidString)"
    }

    private func carePlanStorageKey(circleID: UUID) -> String {
        "RemoteLove.carePlan.\(circleID.uuidString)"
    }

    private func apply(snapshot: SupabaseCareCircleSnapshot) {
        restoreNotificationMuteSelection()

        if let rawMode = snapshot.circle?.caregiverMode,
           let mode = CaregiverMode(rawValue: rawMode) {
            caregiverMode = mode
        } else {
            caregiverMode = .helperOnly
        }
        healthFeatureEnabled = snapshot.circle?.healthEnabled ?? true
        if !healthFeatureEnabled && selectedMainTab == .health {
            selectedMainTab = currentRole == .helper ? .helperToday : .overview
        }

        if let entitlement = snapshot.entitlement,
           let plan = CarePlan(rawValue: entitlement.planCode) {
            activeCarePlan = plan
            let status = CarePlanStatus(rawValue: entitlement.status) ?? .active
            carePlanStatus = resolvedStatus(status, periodEndsAt: entitlement.currentPeriodEndsAt)
            carePlanPeriodEndsAt = entitlement.currentPeriodEndsAt
            saveCarePlanSelection()
        } else {
            activeCarePlan = .free
            carePlanStatus = .inactive
            carePlanPeriodEndsAt = nil
            saveCarePlanSelection()
        }

        let familyInvite = snapshot.invites.first { invite in
            (invite.invitationType ?? "family").trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == "family"
        }
        let helperInvite = snapshot.invites.first { invite in
            (invite.invitationType ?? "").trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == "helper"
        }
        generatedInviteCode = familyInvite?.code
        helperInviteCode = helperInvite?.code

        let mappedMembers = snapshot.members.map {
            CircleMember(
                id: $0.id,
                recipientID: $0.recipientID,
                userID: $0.userID,
                name: $0.name,
                role: $0.role,
                permission: $0.permission,
                active: $0.active,
                joinedAt: $0.joinedAt
            )
        }

        let mappedRecipients = snapshot.recipients.map {
            CareRecipient(
                id: $0.id,
                name: $0.name,
                label: $0.label,
                age: $0.age,
                relationship: $0.relationship,
                lastUpdated: $0.lastUpdated
            )
        }

        let permittedRecipientIDs: Set<UUID>?
        if currentRole == .helper || currentRole == .viewer {
            let currentUserID = authSession?.user?.id
            let ids = mappedMembers.compactMap { member -> UUID? in
                guard member.active, member.userID == currentUserID else { return nil }
                return member.recipientID
            }
            permittedRecipientIDs = ids.isEmpty ? nil : Set(ids)
        } else {
            permittedRecipientIDs = nil
        }

        recipients = mappedRecipients.filter { recipient in
            permittedRecipientIDs?.contains(recipient.id) ?? true
        }
        selectedRecipientID = recipients.first?.id ?? UUID()
        overviewRecipientID = nil
        members = mappedMembers.filter { member in
            guard let permittedRecipientIDs else { return true }
            guard let recipientID = member.recipientID else { return false }
            return permittedRecipientIDs.contains(recipientID)
        }

        tasks = snapshot.tasks.compactMap {
            guard permittedRecipientIDs?.contains($0.recipientID) ?? true else { return nil }
            return CareTask(
                id: $0.id,
                recipientID: $0.recipientID,
                title: $0.title,
                instructions: $0.instructions,
                scheduledAt: $0.scheduledAt,
                frequency: $0.frequency,
                requiresPhoto: $0.requiresPhoto,
                state: TaskState(rawValue: $0.state) ?? .pending,
                notifiedAt: $0.notifiedAt,
                medicineID: $0.medicineID
            )
        }
        medicines = snapshot.medicines.compactMap {
            guard permittedRecipientIDs?.contains($0.recipientID) ?? true else { return nil }
            return Medicine(
                id: $0.id,
                recipientID: $0.recipientID,
                name: $0.name,
                purpose: $0.purpose,
                instructions: $0.instructions,
                currentSupply: $0.currentSupply,
                dose: $0.dose,
                unit: $0.unit,
                timesDaily: $0.timesDaily,
                intervalDays: $0.intervalDays,
                attentionDays: $0.attentionDays,
                active: $0.active,
                firstTime: $0.firstTime,
                doseTimes: $0.doseTimes,
                repeatWeekdays: $0.repeatWeekdays
            )
        }
        appointments = snapshot.appointments.compactMap {
            guard permittedRecipientIDs?.contains($0.recipientID) ?? true else { return nil }
            return CareAppointment(
                id: $0.id,
                recipientID: $0.recipientID,
                title: $0.title,
                date: $0.date,
                notes: $0.notes,
                repeatRule: $0.repeatRule,
                remindThreeDaysBefore: $0.remindThreeDaysBefore,
                reminderEnabled: $0.reminderEnabled ?? $0.remindThreeDaysBefore,
                reminderDaysBefore: $0.reminderDaysBefore ?? ($0.remindThreeDaysBefore ? 3 : 0),
                reminderCount: $0.reminderCount ?? 1,
                state: AppointmentState(rawValue: $0.state) ?? .scheduled
            )
        }
        plannerOtherItems = snapshot.plannerOtherItems.compactMap {
            guard permittedRecipientIDs?.contains($0.recipientID) ?? true else { return nil }
            return PlannerOtherItem(
                id: $0.id,
                recipientID: $0.recipientID,
                title: $0.title,
                date: $0.date,
                notes: $0.notes,
                repeatRule: $0.repeatRule,
                active: $0.active
            )
        }
        healthLogs = snapshot.healthLogs.compactMap {
            guard permittedRecipientIDs?.contains($0.recipientID) ?? true else { return nil }
            guard let category = HealthCategory(rawValue: $0.category) else { return nil }
            return HealthLog(id: $0.id, recipientID: $0.recipientID, category: category, value: $0.value, recordedAt: $0.recordedAt, notes: $0.notes)
        }
        updates = snapshot.updates.compactMap {
            guard permittedRecipientIDs?.contains($0.recipientID) ?? true else { return nil }
            return CareUpdate(id: $0.id, recipientID: $0.recipientID, author: $0.author, message: $0.message, mood: $0.mood, createdAt: $0.createdAt)
        }
        history = snapshot.history.compactMap {
            guard permittedRecipientIDs?.contains($0.recipientID) ?? true else { return nil }
            return ActivityEvent(id: $0.id, recipientID: $0.recipientID, actor: $0.actor, action: $0.action, detail: $0.detail, createdAt: $0.createdAt)
        }
        refreshScheduledNotifications()
    }

    private func resolvedStatus(_ status: CarePlanStatus, periodEndsAt: Date?) -> CarePlanStatus {
        if status == .trialing, let periodEndsAt, periodEndsAt <= Date() {
            return .active
        }
        return status
    }

    private func record(action: String, detail: String, recipientID: UUID) {
        let role = currentRole.rawValue.capitalized
        history.insert(ActivityEvent(id: UUID(), recipientID: recipientID, actor: "\(currentUserName) · \(role)", action: action, detail: detail, createdAt: Date()), at: 0)
    }

    private func task(_ task: CareTask, occursOn date: Date) -> Bool {
        let calendar = Calendar.current
        let targetDay = calendar.startOfDay(for: date)
        let startDay = calendar.startOfDay(for: task.scheduledAt)
        guard targetDay >= startDay else { return false }

        let frequency = task.frequency.trimmingCharacters(in: .whitespacesAndNewlines)
        if excludedDates(in: frequency).contains(Self.taskDateToken(for: targetDay)) {
            return false
        }

        let baseFrequency = frequency.components(separatedBy: " · except ").first ?? frequency
        switch baseFrequency {
        case "Every day":
            return true
        case "Weekdays":
            return !calendar.isDateInWeekend(targetDay)
        case "Does not repeat":
            return calendar.isDate(targetDay, inSameDayAs: startDay)
        default:
            break
        }

        if baseFrequency.hasPrefix("Every ") {
            let weekdaySymbols = calendar.weekdaySymbols
            let targetWeekday = calendar.component(.weekday, from: targetDay)
            let selectedWeekdays = weekdaySymbols.enumerated().compactMap { index, name -> Int? in
                baseFrequency.contains(name) ? index + 1 : nil
            }
            if !selectedWeekdays.isEmpty {
                return selectedWeekdays.contains(targetWeekday)
            }
        }

        if baseFrequency.hasPrefix("Every "),
           let interval = Int(baseFrequency.components(separatedBy: " ").dropFirst().first ?? "") {
            let lowercased = baseFrequency.lowercased()
            if lowercased.contains("day") {
                let days = calendar.dateComponents([.day], from: startDay, to: targetDay).day ?? 0
                return days >= 0 && days % max(interval, 1) == 0
            }
            if lowercased.contains("week") {
                let weeks = calendar.dateComponents([.weekOfYear], from: startDay, to: targetDay).weekOfYear ?? 0
                return weeks >= 0 && weeks % max(interval, 1) == 0
            }
            if lowercased.contains("hour") {
                return true
            }
        }

        return calendar.isDate(targetDay, inSameDayAs: startDay)
    }

    private func frequency(_ frequency: String, excluding date: Date) -> String {
        let baseFrequency = frequency.components(separatedBy: " · except ").first ?? frequency
        var tokens = excludedDates(in: frequency)
        tokens.insert(Self.taskDateToken(for: date))
        return "\(baseFrequency) · except \(tokens.sorted().joined(separator: ","))"
    }

    private func captureTaskHistory(scope: TaskHistoryScope, message: String, date: Date, tasksBefore: [CareTask]) {
        let entry = TaskUndoEntry(
            date: date,
            scope: scope,
            message: message,
            tasksBefore: tasksBefore,
            tasksAfter: tasks
        )
        taskUndoStack.append(entry)
        taskRedoStack.removeAll { isHistoryEntryVisible($0, scope: scope) }
        if taskUndoStack.count > 20 {
            taskUndoStack.removeFirst(taskUndoStack.count - 20)
        }
    }

    private func syncMedicineTasks(for medicine: Medicine) {
        let mirrorIDs = Set((0..<24).map { plannerMirrorTaskID(kind: "medicine", sourceID: medicine.id, slot: $0) })
        tasks.removeAll { mirrorIDs.contains($0.id) }

        guard medicine.active else { return }

        for (index, doseTime) in medicine.scheduledDoseTimes.prefix(24).enumerated() {
            let doseLabel = medicine.scheduledDoseTimes.count > 1 ? " dose \(index + 1)" : ""
            tasks.append(
                CareTask(
                    id: plannerMirrorTaskID(kind: "medicine", sourceID: medicine.id, slot: index),
                    recipientID: medicine.recipientID,
                    title: "Medicine: \(medicine.name)\(doseLabel)",
                    instructions: medicineTaskInstructions(for: medicine),
                    scheduledAt: scheduledDate(on: medicine.firstTime, matchingTimeOf: doseTime),
                    frequency: medicineTaskFrequency(for: medicine),
                    requiresPhoto: false,
                    state: .pending,
                    notifiedAt: nil,
                    medicineID: medicine.id
                )
            )
        }
    }

    private func syncAppointmentTask(for appointment: CareAppointment) {
        removePlannerMirrorTasks(kind: "appointment", sourceID: appointment.id)
        guard appointment.state == .scheduled else { return }

        tasks.append(
            CareTask(
                id: plannerMirrorTaskID(kind: "appointment", sourceID: appointment.id),
                recipientID: appointment.recipientID,
                title: "Appointment: \(appointment.title)",
                instructions: appointment.notes.isEmpty ? "Appointment added from Planner." : appointment.notes,
                scheduledAt: appointment.date,
                frequency: appointment.repeatRule,
                requiresPhoto: false,
                state: .pending,
                notifiedAt: nil,
                medicineID: nil
            )
        )
    }

    private func syncPlannerOtherTask(for item: PlannerOtherItem) {
        removePlannerMirrorTasks(kind: "other", sourceID: item.id)
        guard item.active else { return }

        tasks.append(
            CareTask(
                id: plannerMirrorTaskID(kind: "other", sourceID: item.id),
                recipientID: item.recipientID,
                title: "Planner: \(item.title)",
                instructions: item.notes.isEmpty ? "Planner item added from Other." : item.notes,
                scheduledAt: item.date,
                frequency: item.repeatRule,
                requiresPhoto: false,
                state: .pending,
                notifiedAt: nil,
                medicineID: nil
            )
        )
    }

    private func removePlannerMirrorTasks(kind: String, sourceID: UUID) {
        let mirrorIDs = Set((0..<24).map { plannerMirrorTaskID(kind: kind, sourceID: sourceID, slot: $0) })
        tasks.removeAll { mirrorIDs.contains($0.id) }
    }

    private func plannerMirrorTaskID(kind: String, sourceID: UUID, slot: Int = 0) -> UUID {
        let seed = "RemoteLove.planner-task.\(kind).\(sourceID.uuidString).\(slot)"
        let digest = SHA256.hash(data: Data(seed.utf8))
        var bytes = Array(digest.prefix(16))
        bytes[6] = (bytes[6] & 0x0F) | 0x50
        bytes[8] = (bytes[8] & 0x3F) | 0x80
        return UUID(uuid: (
            bytes[0], bytes[1], bytes[2], bytes[3],
            bytes[4], bytes[5], bytes[6], bytes[7],
            bytes[8], bytes[9], bytes[10], bytes[11],
            bytes[12], bytes[13], bytes[14], bytes[15]
        ))
    }

    private func medicineTaskInstructions(for medicine: Medicine) -> String {
        var details: [String] = []
        if medicine.dose > 0 {
            details.append("Dose: \(medicine.dose.formatted()) \(medicine.unit)")
        }
        if !medicine.instructions.isEmpty {
            details.append(medicine.instructions)
        } else if !medicine.purpose.isEmpty {
            details.append(medicine.purpose)
        }
        return details.isEmpty ? "Medicine added from Planner." : details.joined(separator: "\n")
    }

    private func medicineTaskFrequency(for medicine: Medicine) -> String {
        if let weekdays = medicine.repeatWeekdays, weekdays.isEmpty == false {
            let weekdaySymbols = Calendar.current.weekdaySymbols
            let names = weekdays
                .sorted()
                .compactMap { index in weekdaySymbols.indices.contains(index - 1) ? weekdaySymbols[index - 1] : nil }
            return names.isEmpty ? "Every day" : "Every \(names.joined(separator: ", "))"
        }

        if medicine.intervalDays <= 1 {
            return "Every day"
        }

        return "Every \(medicine.intervalDays) days"
    }

    private func historyEntries(in stack: [TaskUndoEntry], scope: TaskHistoryScope) -> [TaskUndoEntry] {
        stack.filter { isHistoryEntryVisible($0, scope: scope) }
    }

    private func popLatestHistoryEntry(from stack: inout [TaskUndoEntry], scope: TaskHistoryScope) -> TaskUndoEntry? {
        guard let index = stack.lastIndex(where: { isHistoryEntryVisible($0, scope: scope) }) else {
            return nil
        }
        return stack.remove(at: index)
    }

    private func isHistoryEntryVisible(_ entry: TaskUndoEntry, scope: TaskHistoryScope) -> Bool {
        entry.scope == scope && (scope == .futureRoutine || Calendar.current.isDate(entry.date, inSameDayAs: selectedTaskDate))
    }

    private func taskSortKey(_ date: Date) -> Int {
        let components = Calendar.current.dateComponents([.hour, .minute], from: date)
        return (components.hour ?? 0) * 60 + (components.minute ?? 0)
    }

    private func excludedDates(in frequency: String) -> Set<String> {
        guard let exceptions = frequency.components(separatedBy: " · except ").dropFirst().first else {
            return []
        }
        return Set(exceptions.split(separator: ",").map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) })
    }

    private func scheduledDate(on date: Date, matchingTimeOf timeSource: Date) -> Date {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.hour, .minute, .second], from: timeSource)
        return calendar.date(
            bySettingHour: components.hour ?? 9,
            minute: components.minute ?? 0,
            second: components.second ?? 0,
            of: date
        ) ?? date
    }

    private static func taskDateToken(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }

    private func touch(_ recipientID: UUID) {
        guard let index = recipients.firstIndex(where: { $0.id == recipientID }) else { return }
        recipients[index].lastUpdated = Date()
    }
}
