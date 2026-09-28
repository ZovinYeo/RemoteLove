import SwiftUI
import Charts
import PhotosUI
import Photos
import UserNotifications
#if canImport(UIKit)
import UIKit
#endif

struct LoginView: View {
    @EnvironmentObject private var store: RemoteLoveStore
    @State private var email = ""
    @State private var password = ""
    @State private var helperName = ""
    @State private var inviteCode = ""
    @State private var helperPIN = ""
    @State private var helperUsesInvite = false
    @State private var showReset = false
    @State private var errorMessage = ""
    @State private var showRemote = false
    @State private var showLove = false
    @State private var showTagline = false
    @State private var showDemoOptions = false
    @State private var lovePulseScale: CGFloat = 1.0
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 10) {
                    Image("LaunchLogo")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 122, height: 122)
                        .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))

                    VStack(spacing: 1) {

                        HStack(spacing: 0) {
                            Text("Remote")
                                .offset(x: showRemote ? 0 : -120)
                                .opacity(showRemote ? 1 : 0)

                            Text("Love")
                                .foregroundColor(RemoteLoveTheme.coral)
                                .scaleEffect(lovePulseScale)
                                .offset(x: showLove ? 0 : 120)
                                .opacity(showLove ? 1 : 0)
                        }
                        .font(.largeTitle.bold())
                        .tracking(1)

                        Text(store.route == .helperJoin ? "Join the care circle" : "Love never feels far")
                            .font(.title3)
                            .opacity(showTagline ? 1 : 0)
                    }
                    .onAppear {

                        // RemoteLove slides in
                        withAnimation(.easeOut(duration: 0.9)) {
                            showRemote = true
                            showLove = true
                        }

                        // Tagline fades in afterwards
                        withAnimation(.easeIn(duration: 0.8).delay(0.2)) {
                            showTagline = true
                        }

                        startLoveHeartbeat()
                    }

                    VStack(spacing: 14) {
                        switch store.route {
                        case .welcome:
                            welcomeRoleButton(
                                title: "I’m a family member",
                                subtitle: "Create or join a care circle for someone you love.",
                                icon: "person.2.fill",
                                isPrimary: true
                            ) {
                                store.route = .familyAuthentication
                                clearLoginMessages()
                            }

                            welcomeRoleButton(
                                title: "I’m a helper",
                                subtitle: store.hasSavedHelperAccount ? "Continue with your helper PIN." : "Join using a helper invite code.",
                                icon: "heart.text.square.fill",
                                isPrimary: false
                            ) {
                                store.route = .helperJoin
                                clearLoginMessages()
                                helperUsesInvite = !store.hasSavedHelperAccount
                                helperName = store.savedHelperName ?? ""
                                helperPIN = ""
                            }

                        case .helperJoin:
                            if store.hasSavedHelperAccount && !helperUsesInvite {
                                NativeField(title: "Helper name", placeholder: store.savedHelperName ?? "e.g. Ana", text: $helperName)
                                SecureField("Helper PIN", text: $helperPIN)
                                    .keyboardType(.numberPad)
                                    .textContentType(.oneTimeCode)
                                    .padding(16)
                                    .background(Color.secondary.opacity(0.09), in: RoundedRectangle(cornerRadius: 15))

                                Button(store.isSyncing ? "Opening..." : "Continue as helper") {
                                    Task {
                                        clearLoginMessages()
                                        await store.signInReturningHelper(name: helperName, pin: helperPIN)
                                    }
                                }
                                .disabled(store.isSyncing || helperName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || helperPIN.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                                .buttonStyle(PrimaryButtonStyle())

                                Button("Join with invite code instead") {
                                    store.useHelperInviteInstead()
                                    clearLoginMessages()
                                    helperUsesInvite = true
                                    helperName = ""
                                    helperPIN = ""
                                    inviteCode = ""
                                }
                                .buttonStyle(SecondaryButtonStyle())
                            } else {
                                NativeField(title: "Your name", placeholder: "e.g. Ana", text: $helperName)
                                NativeField(title: "Helper invite code", placeholder: "e.g. LOVE2026", text: $inviteCode)
                                    .textInputAutocapitalization(.characters)
                                SecureField("Create helper PIN", text: $helperPIN)
                                    .keyboardType(.numberPad)
                                    .textContentType(.oneTimeCode)
                                    .padding(16)
                                    .background(Color.secondary.opacity(0.09), in: RoundedRectangle(cornerRadius: 15))
                                Text("Use 4 to 6 digits. This PIN unlocks helper access on this device.")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .multilineTextAlignment(.center)
                                Button(store.isSyncing ? "Joining..." : "Join care circle") {
                                    Task {
                                        if inviteCode.uppercased().trimmingCharacters(in: .whitespacesAndNewlines) == "LOVE2026" {
                                            clearLoginMessages()
                                            await store.enterDemo(as: .helper, name: helperName)
                                        } else {
                                            clearLoginMessages()
                                            await store.signInHelper(name: helperName, inviteCode: inviteCode, pin: helperPIN)
                                        }
                                    }
                                }
                                .disabled(store.isSyncing || helperName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || inviteCode.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || helperPIN.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                                .buttonStyle(PrimaryButtonStyle())
                            }

                        case .familyAuthentication:
                            NativeField(title: "Email address", placeholder: "you@example.com", text: $email)
                                .textInputAutocapitalization(.never)
                                .keyboardType(.emailAddress)
                                .textContentType(.emailAddress)
                                .onChange(of: email) {
                                    clearLoginMessages()
                                }
                            NativeSecureField(title: "Password", placeholder: "Password", text: $password)
                                .textContentType(.password)
                                .onChange(of: password) {
                                    clearLoginMessages()
                                }
                            Button(store.isSyncing ? "Signing in..." : "Sign in") {
                                Task {
                                    clearLoginMessages()
                                    await store.signInFamily(email: email, password: password)
                                }
                            }
                            .disabled(store.isSyncing)
                            .buttonStyle(PrimaryButtonStyle())
                            NavigationLink {
                                CreateAccountView()
                            } label: {
                                Text("Create account")
                            }
                            .simultaneousGesture(TapGesture().onEnded {
                                clearLoginMessages()
                            })
                            .buttonStyle(SecondaryButtonStyle())
                            Button("Forgot or reset password") {
                                clearLoginMessages()
                                showReset = true
                            }
                                .font(.subheadline.weight(.semibold))

                        case .familyGettingStarted:
                            Text("Create a new care profile, or join a care circle someone has already started.")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)

                            Button("Set up care for someone") {
                                store.beginNewCareSetup()
                            }
                            .disabled(store.isSyncing)
                            .buttonStyle(PrimaryButtonStyle())

                            Button("Join an existing family care circle") {
                                clearLoginMessages()
                                store.route = .joinFamilyCareCircle
                            }
                            .disabled(store.isSyncing)
                            .buttonStyle(SecondaryButtonStyle())

                        case .joinFamilyCareCircle:
                            NativeField(title: "Family invite code", placeholder: "LOVE2026", text: $inviteCode)
                                .textInputAutocapitalization(.characters)
                                .onChange(of: inviteCode) {
                                    clearLoginMessages()
                                }

                            Button(store.isSyncing ? "Joining..." : "Join care circle") {
                                Task {
                                    clearLoginMessages()
                                    await store.joinCareCircle(inviteCode: inviteCode)
                                }
                            }
                            .disabled(store.isSyncing || inviteCode.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                            .buttonStyle(PrimaryButtonStyle())

                            Button("Start a new care circle instead") {
                                clearLoginMessages()
                                store.route = .familyGettingStarted
                            }
                            .disabled(store.isSyncing)
                            .buttonStyle(SecondaryButtonStyle())

                        default:
                            EmptyView()
                        }

                        if !errorMessage.isEmpty {
                            LoginMessageBanner(message: errorMessage, style: .error)
                        }

                        if let authMessage = store.authMessage, !authMessage.isEmpty {
                            LoginMessageBanner(
                                message: authMessage,
                                style: authMessage.isErrorLike ? .error : .info
                            )
                        }
                    }
                    .padding(20)
                    .background(.background, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
                    .shadow(color: .black.opacity(0.08), radius: 18, y: 8)

                    if store.route != .welcome {
                        Button("Back to welcome") {
                            clearLoginMessages()
                            store.route = .welcome
                        }
                        .buttonStyle(SecondaryButtonStyle())
                    }

                    if store.route == .welcome {
                        demoAccessPanel
                    }
                }
                .padding(.horizontal, 22)
                .padding(.vertical, 36)
                .frame(maxWidth: 520)
                .frame(maxWidth: .infinity)
            }
            .background(RemoteLoveTheme.mint.opacity(0.55).ignoresSafeArea())
            .sheet(isPresented: $showReset) { PasswordResetView() }
            .onChange(of: store.route) {
                if store.route == .welcome {
                    clearLoginMessages()
                }
            }
        }
    }

    private func clearLoginMessages() {
        errorMessage = ""
        store.authMessage = nil
    }

    private func welcomeRoleButton(
        title: String,
        subtitle: String,
        icon: String,
        isPrimary: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .font(.title3.weight(.semibold))
                    .foregroundColor(isPrimary ? RemoteLoveTheme.onAccent : RemoteLoveTheme.green)
                    .frame(width: 46, height: 46)
                    .background(isPrimary ? Color.white.opacity(0.18) : RemoteLoveTheme.green.opacity(0.12), in: Circle())
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.headline)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(isPrimary ? RemoteLoveTheme.onAccent.opacity(0.86) : .secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
                    .accessibilityHidden(true)
            }
            .frame(maxWidth: .infinity, minHeight: 72, alignment: .leading)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .foregroundColor(isPrimary ? RemoteLoveTheme.onAccent : .primary)
            .background(
                isPrimary ? RemoteLoveTheme.green : Color.secondary.opacity(0.08),
                in: RoundedRectangle(cornerRadius: 18, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(isPrimary ? Color.clear : RemoteLoveTheme.green.opacity(0.22), lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
        .accessibilityHint(subtitle)
    }

    @ViewBuilder
    private var demoAccessPanel: some View {
        VStack(spacing: 10) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    showDemoOptions.toggle()
                }
            } label: {
                Label(showDemoOptions ? "Hide demo" : "Try demo", systemImage: "play.circle.fill")
                    .font(.subheadline.weight(.semibold))
            }
            .buttonStyle(SecondaryButtonStyle())

            if showDemoOptions {
                VStack(spacing: 10) {
                    HStack(spacing: 12) {
                        Button("Act as family") {
                            Task {
                                clearLoginMessages()
                                await store.enterDemo(as: .family)
                            }
                        }
                        .buttonStyle(SecondaryButtonStyle())

                        Button("Act as helper") {
                            Task {
                                clearLoginMessages()
                                await store.enterDemo(as: .helper)
                            }
                        }
                        .buttonStyle(SecondaryButtonStyle())
                    }

                    Text("Demo mode uses shared sample care data for trying the app.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(14)
                .remoteLoveSectionSurface(cornerRadius: 18)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }

    private func startLoveHeartbeat() {
        Task { @MainActor in
            while true {
                withAnimation(.easeOut(duration: 0.12)) {
                    lovePulseScale = 1.045
                }
                try? await Task.sleep(nanoseconds: 120_000_000)
                withAnimation(.easeIn(duration: 0.16)) {
                    lovePulseScale = 1.0
                }
                try? await Task.sleep(nanoseconds: 140_000_000)
                withAnimation(.easeOut(duration: 0.10)) {
                    lovePulseScale = 1.03
                }
                try? await Task.sleep(nanoseconds: 100_000_000)
                withAnimation(.easeIn(duration: 0.18)) {
                    lovePulseScale = 1.0
                }
                try? await Task.sleep(nanoseconds: 1_050_000_000)
            }
        }
    }
}

struct CreateAccountView: View {
    @EnvironmentObject private var store: RemoteLoveStore
    @State private var name = ""
    @State private var email = ""
    @State private var password = ""

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                Image("LaunchLogo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 96, height: 96)
                    .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))

                VStack(spacing: 4) {
                    Text("Create account")
                        .font(.system(size: 30, weight: .bold, design: .rounded))
                    Text("Set up your RemoteLove family account")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .multilineTextAlignment(.center)

                VStack(spacing: 14) {
                    NativeField(title: "Your name", placeholder: "e.g. Zovin", text: $name)
                        .textContentType(.name)
                        .onChange(of: name) {
                            store.authMessage = nil
                        }
                    NativeField(title: "Email address", placeholder: "you@example.com", text: $email)
                        .textInputAutocapitalization(.never)
                        .keyboardType(.emailAddress)
                        .textContentType(.emailAddress)
                        .onChange(of: email) {
                            store.authMessage = nil
                        }
                    NativeSecureField(title: "Password", placeholder: "Password", text: $password)
                        .textContentType(.newPassword)
                        .onChange(of: password) {
                            store.authMessage = nil
                        }
                    PasswordCriteriaView(password: password)

                    Button(store.isSyncing ? "Creating..." : "Create account") {
                        Task {
                            store.authMessage = nil
                            await store.createFamilyAccount(
                                name: name,
                                email: email,
                                password: password
                            )
                        }
                    }
                    .disabled(store.isSyncing || name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !PasswordPolicy.isValid(password))
                    .buttonStyle(PrimaryButtonStyle())

                    if let authMessage = store.authMessage, !authMessage.isEmpty {
                        LoginMessageBanner(
                            message: authMessage,
                            style: authMessage.isErrorLike ? .error : .info
                        )
                    }
                }
                .padding(20)
                .background(.background, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
                .shadow(color: .black.opacity(0.08), radius: 18, y: 8)
            }
            .padding(.horizontal, 22)
            .padding(.vertical, 36)
            .frame(maxWidth: 520)
            .frame(maxWidth: .infinity)
        }
        .background(RemoteLoveTheme.mint.opacity(0.55).ignoresSafeArea())
        .navigationTitle("Create account")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct HelperPinLockView: View {
    @EnvironmentObject private var store: RemoteLoveStore
    @State private var pin = ""

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                Image("LaunchLogo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 104, height: 104)
                    .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))

                VStack(spacing: 4) {
                    Text("Welcome, \(store.currentUserName)")
                        .font(.system(size: 30, weight: .bold, design: .rounded))
                    Text("Enter your helper PIN to continue")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .multilineTextAlignment(.center)

                VStack(spacing: 14) {
                    SecureField("Helper PIN", text: $pin)
                        .keyboardType(.numberPad)
                        .textContentType(.oneTimeCode)
                        .padding(16)
                        .background(Color.secondary.opacity(0.09), in: RoundedRectangle(cornerRadius: 15))

                    Button("Unlock helper access") {
                        store.unlockHelperSession(pin: pin)
                    }
                    .disabled(pin.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .buttonStyle(PrimaryButtonStyle())

                    Button("Use invite code instead") {
                        store.logout()
                        store.route = .helperJoin
                    }
                    .buttonStyle(SecondaryButtonStyle())

                    if let helperPinMessage = store.helperPinMessage, !helperPinMessage.isEmpty {
                        Text(helperPinMessage)
                            .font(.footnote)
                            .foregroundColor(.red)
                            .multilineTextAlignment(.center)
                    }
                }
                .padding(20)
                .background(.background, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
                .shadow(color: .black.opacity(0.08), radius: 18, y: 8)
            }
            .padding(.horizontal, 22)
            .padding(.vertical, 42)
            .frame(maxWidth: 520)
            .frame(maxWidth: .infinity)
        }
        .background(RemoteLoveTheme.mint.opacity(0.55).ignoresSafeArea())
    }
}

struct CareCircleSetupView: View {
    @EnvironmentObject private var store: RemoteLoveStore
    @State private var inviteCode = ""
    @State private var confirmLogout = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    Image("LaunchLogo")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 96, height: 96)
                        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))

                    VStack(spacing: 4) {
                        Text(store.route == .joinFamilyCareCircle ? "Join your care circle" : "Start your care circle")
                            .font(.system(size: 30, weight: .bold, design: .rounded))
                        Text("Signed in as \(store.currentUserName)")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .multilineTextAlignment(.center)

                    VStack(spacing: 14) {
                        if store.route == .joinFamilyCareCircle {
                            NativeField(title: "Family invite code", placeholder: "LOVE2026", text: $inviteCode)
                                .textInputAutocapitalization(.characters)
                                .onChange(of: inviteCode) {
                                    store.authMessage = nil
                                }

                            Button(store.isSyncing ? "Joining..." : "Join care circle") {
                                Task {
                                    store.authMessage = nil
                                    await store.joinCareCircle(inviteCode: inviteCode)
                                }
                            }
                            .frame(minHeight: 44)
                            .disabled(store.isSyncing || inviteCode.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                            .buttonStyle(PrimaryButtonStyle())

                            Button("Start a new care circle instead") {
                                store.authMessage = nil
                                store.route = .familyGettingStarted
                            }
                            .disabled(store.isSyncing)
                            .buttonStyle(SecondaryButtonStyle())
                        } else {
                            Text("Create the first care profile and RemoteLove will generate a family invite code for that profile.")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)

                            Button("Set up care for someone") {
                                store.authMessage = nil
                                store.beginNewCareSetup()
                            }
                            .frame(minHeight: 44)
                            .disabled(store.isSyncing)
                            .buttonStyle(PrimaryButtonStyle())

                            Button("Join an existing family care circle") {
                                store.authMessage = nil
                                store.route = .joinFamilyCareCircle
                            }
                            .frame(minHeight: 44)
                            .disabled(store.isSyncing)
                            .buttonStyle(SecondaryButtonStyle())
                        }

                        if let authMessage = store.authMessage, !authMessage.isEmpty {
                            LoginMessageBanner(
                                message: authMessage,
                                style: authMessage.isErrorLike ? .error : .info
                            )
                        }
                    }
                    .padding(20)
                    .background(.background, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
                    .shadow(color: .black.opacity(0.08), radius: 18, y: 8)

                    Button("Log out") {
                        store.authMessage = nil
                        confirmLogout = true
                    }
                        .font(.subheadline.weight(.semibold))
                }
                .padding(.horizontal, 22)
                .padding(.vertical, 36)
                .frame(maxWidth: 520)
                .frame(maxWidth: .infinity)
            }
            .background(RemoteLoveTheme.mint.opacity(0.55).ignoresSafeArea())
            .alert("Log out?", isPresented: $confirmLogout) {
                Button("Cancel", role: .cancel) { store.authMessage = nil }
                Button("Log out", role: .destructive) {
                    store.authMessage = nil
                    store.logout()
                }
            } message: {
                Text("This clears the local session and returns RemoteLove to the welcome screen.")
            }
        }
    }
}

struct InitialCareSetupView: View {
    @EnvironmentObject private var store: RemoteLoveStore
    @State private var profiles = [CareProfileInput.starter()]
    @State private var caregiverMode: CaregiverMode = .helperOnly
    @State private var healthFeatureEnabled = true
    @FocusState private var focusedField: InitialCareSetupField?

    private var profileCount: Binding<Int> {
        Binding(
            get: { profiles.count },
            set: { updateProfileCount($0) }
        )
    }

    private var canCreateSetup: Bool {
        !store.isSyncing && profiles.contains { !$0.trimmedName.isEmpty }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        InitialCareSetupHeader(profileCount: profiles.count)

                        InitialCareProfileCountCard(profileCount: profileCount)

                        ForEach($profiles) { $profile in
                            InitialCareRecipientCard(
                                profile: $profile,
                                focusedField: $focusedField
                            )
                        }

                        InitialCaregiverModeCard(selection: $caregiverMode)

                        InitialHealthFeatureCard(isEnabled: $healthFeatureEnabled)

                        InitialCareSetupSummaryCard(caregiverMode: caregiverMode, healthFeatureEnabled: healthFeatureEnabled)

                        if let authMessage = store.authMessage, !authMessage.isEmpty {
                            Label {
                                Text(authMessage)
                                    .font(.footnote)
                                    .fixedSize(horizontal: false, vertical: true)
                            } icon: {
                                Image(systemName: authMessage.contains("created") ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                            }
                            .foregroundColor(authMessage.contains("created") ? RemoteLoveTheme.green : RemoteLoveTheme.coral)
                            .padding(14)
                            .remoteLoveSectionSurface(cornerRadius: 16)
                        }
                    }
                    .padding(20)
                    .padding(.bottom, 8)
                }

                VStack(spacing: 10) {
                    Button {
                        focusedField = nil
                        Task {
                            await store.createInitialCareSetup(
                                profiles: profiles,
                                caregiverMode: caregiverMode,
                                healthFeatureEnabled: healthFeatureEnabled
                            )
                        }
                    } label: {
                        HStack {
                            if store.isSyncing {
                                ProgressView()
                                    .tint(RemoteLoveTheme.onAccent)
                            }
                            Text(store.isSyncing ? "Creating care setup..." : "Create care setup")
                        }
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    .disabled(!canCreateSetup)
                    .opacity(canCreateSetup ? 1 : 0.55)

                    Text("This creates the care profile, owner access and invite codes together.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(20)
                .background(.ultraThinMaterial)
            }
            .background(Color(uiColor: .systemGroupedBackground).ignoresSafeArea())
            .navigationTitle("Set up care")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Back") { store.route = .familyGettingStarted }
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") {
                        focusedField = nil
                    }
                }
            }
        }
    }

    private func updateProfileCount(_ newCount: Int) {
        let clampedCount = min(max(newCount, 1), 6)
        if clampedCount > profiles.count {
            for index in profiles.count..<clampedCount {
                profiles.append(CareProfileInput.starter(index: index))
            }
        } else if clampedCount < profiles.count {
            profiles.removeLast(profiles.count - clampedCount)
        }
    }
}

private enum InitialCareSetupField: Hashable {
    case name(UUID)
    case label(UUID)
    case relationship(UUID)
}

private struct InitialCareSetupHeader: View {
    let profileCount: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center, spacing: 14) {
                Image(systemName: "heart.text.square.fill")
                    .font(.system(size: 32))
                    .foregroundColor(RemoteLoveTheme.coral)
                    .frame(width: 58, height: 58)
                    .background(RemoteLoveTheme.coral.opacity(0.13), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 4) {
                    Text(profileCount == 1 ? "Create your first care profile" : "Create \(profileCount) care profiles")
                        .font(.title2.bold())
                    Text("Start with the people your family will care for. You can still add more later.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }

            HStack(spacing: 8) {
                SetupStepPill(number: "1", title: "Profile")
                SetupStepPill(number: "2", title: "Care mode")
                SetupStepPill(number: "3", title: "Invite codes")
            }
        }
        .padding(18)
        .remoteLoveSectionSurface(cornerRadius: 24)
    }
}

private struct InitialCareProfileCountCard: View {
    @Binding var profileCount: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            SetupSectionHeader(
                icon: "person.2.badge.plus.fill",
                title: "How many care profiles?",
                subtitle: "Choose how many people you want to set up now."
            )

            Stepper(value: $profileCount, in: 1...6) {
                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("\(profileCount) care profile\(profileCount == 1 ? "" : "s")")
                            .font(.headline)
                        Text("You can add or edit profiles later from Care circle.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                }
            }
        }
        .padding(18)
        .remoteLoveSectionSurface(cornerRadius: 24)
    }
}

private struct SetupStepPill: View {
    let number: String
    let title: String

    var body: some View {
        HStack(spacing: 6) {
            Text(number)
                .font(.caption2.bold())
                .foregroundColor(RemoteLoveTheme.onAccent)
                .frame(width: 20, height: 20)
                .background(RemoteLoveTheme.green, in: Circle())

            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundColor(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(Color.secondary.opacity(0.08), in: Capsule())
    }
}

private struct InitialCareRecipientCard: View {
    @Binding var profile: CareProfileInput
    var focusedField: FocusState<InitialCareSetupField?>.Binding

    private let labelSuggestions = ["Mum", "Dad", "Grandma", "Grandpa", "Partner"]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 5) {
                Text(profileTitle)
                    .font(.title3.bold())
                    .foregroundColor(.primary)
                Text("Full name, relationship and label")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            VStack(spacing: 12) {
                TextField("Full name", text: $profile.name)
                    .textContentType(.name)
                    .focused(focusedField, equals: .name(profile.id))
                    .submitLabel(.next)
                    .onSubmit { focusedField.wrappedValue = .relationship(profile.id) }
                    .padding(14)
                    .background(Color.secondary.opacity(0.09), in: RoundedRectangle(cornerRadius: 14, style: .continuous))

                TextField("Relationship, e.g. Parent", text: $profile.relationship)
                    .focused(focusedField, equals: .relationship(profile.id))
                    .submitLabel(.next)
                    .onSubmit { focusedField.wrappedValue = .label(profile.id) }
                    .padding(14)
                    .background(Color.secondary.opacity(0.09), in: RoundedRectangle(cornerRadius: 14, style: .continuous))

                VStack(alignment: .leading, spacing: 10) {
                    TextField("Label, e.g. Mum", text: $profile.label)
                        .focused(focusedField, equals: .label(profile.id))
                        .submitLabel(.done)
                        .onSubmit { focusedField.wrappedValue = nil }
                        .padding(14)
                        .background(Color.secondary.opacity(0.09), in: RoundedRectangle(cornerRadius: 14, style: .continuous))

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(labelSuggestions, id: \.self) { suggestion in
                                Button {
                                    profile.label = suggestion
                                    if profile.relationship.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                        profile.relationship = suggestedRelationship(for: suggestion)
                                    }
                                } label: {
                                    Text(suggestion)
                                        .font(.caption.weight(.semibold))
                                        .foregroundColor(profile.label == suggestion ? RemoteLoveTheme.onAccent : RemoteLoveTheme.green)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 8)
                                        .background(profile.label == suggestion ? RemoteLoveTheme.green : RemoteLoveTheme.green.opacity(0.10), in: Capsule())
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }

                InitialCareAgePicker(age: $profile.age)
            }
        }
        .padding(18)
        .remoteLoveSectionSurface(cornerRadius: 24)
    }

    private var profileTitle: String {
        let name = profile.trimmedName.isEmpty ? "New care profile" : profile.trimmedName
        return "\(name) · \(profile.normalizedRelationship) · \(profile.normalizedLabel)"
    }

    private func suggestedRelationship(for label: String) -> String {
        switch label {
        case "Mum", "Dad":
            return "Parent"
        case "Grandma", "Grandpa":
            return "Grandparent"
        case "Partner":
            return "Partner"
        default:
            return profile.relationship
        }
    }
}

private struct InitialCareAgePicker: View {
    @Binding var age: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Age")
                        .font(.subheadline.weight(.semibold))
                    Text("\(age) years old")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
            }

            Picker("Age", selection: $age) {
                ForEach(0...120, id: \.self) { value in
                    Text("\(value)")
                        .tag(value)
                }
            }
            .pickerStyle(.wheel)
            .frame(height: 118)
            .clipped()
        }
        .padding(14)
        .background(Color.secondary.opacity(0.09), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

private struct InitialCaregiverModeCard: View {
    @Binding var selection: CaregiverMode

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            SetupSectionHeader(
                icon: "checkmark.circle.fill",
                title: "Who completes daily tasks?",
                subtitle: "Choose how task Done buttons should appear for your care circle."
            )

            VStack(spacing: 10) {
                ForEach(CaregiverMode.allCases) { mode in
                    Button {
                        withAnimation(.easeInOut(duration: 0.18)) {
                            selection = mode
                        }
                    } label: {
                        HStack(alignment: .top, spacing: 12) {
                            Image(systemName: selection == mode ? "checkmark.circle.fill" : "circle")
                                .font(.title3)
                                .foregroundColor(selection == mode ? RemoteLoveTheme.green : .secondary)
                                .frame(width: 28, height: 28)
                                .accessibilityHidden(true)

                            VStack(alignment: .leading, spacing: 4) {
                                Text(mode.title)
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundColor(.primary)
                                Text(mode.detail)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }

                            Spacer(minLength: 0)
                        }
                        .padding(14)
                        .background(
                            selection == mode ? RemoteLoveTheme.green.opacity(0.13) : Color.secondary.opacity(0.08),
                            in: RoundedRectangle(cornerRadius: 16, style: .continuous)
                        )
                        .overlay {
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .stroke(selection == mode ? RemoteLoveTheme.green.opacity(0.55) : Color.clear, lineWidth: 1)
                        }
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(selection == mode ? .isSelected : [])
                }
            }
        }
        .padding(18)
        .remoteLoveSectionSurface(cornerRadius: 24)
    }
}

private struct InitialHealthFeatureCard: View {
    @Binding var isEnabled: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            SetupSectionHeader(
                icon: "heart.text.square.fill",
                title: "Use Health monitor?",
                subtitle: "Some families want health readings, while others only need tasks and planning."
            )

            VStack(spacing: 10) {
                healthChoice(
                    enabledValue: true,
                    title: "Show Health tab",
                    detail: "Use this if your care circle wants to log readings like hydration, mood, blood pressure or sleep."
                )

                healthChoice(
                    enabledValue: false,
                    title: "Hide Health tab for now",
                    detail: "Keeps the tab bar and Overview simpler. Existing readings are kept if you turn it back on later."
                )
            }

            Label("You can change this later in More > Care circle > Health monitor.", systemImage: "info.circle.fill")
                .font(.caption)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(18)
        .remoteLoveSectionSurface(cornerRadius: 24)
    }

    private func healthChoice(enabledValue: Bool, title: String, detail: String) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.18)) {
                isEnabled = enabledValue
            }
        } label: {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: isEnabled == enabledValue ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundColor(isEnabled == enabledValue ? RemoteLoveTheme.green : .secondary)
                    .frame(width: 28, height: 28)
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(.primary)
                    Text(detail)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)
            }
            .padding(14)
            .background(
                isEnabled == enabledValue ? RemoteLoveTheme.green.opacity(0.13) : Color.secondary.opacity(0.08),
                in: RoundedRectangle(cornerRadius: 16, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(isEnabled == enabledValue ? RemoteLoveTheme.green.opacity(0.55) : Color.clear, lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isEnabled == enabledValue ? .isSelected : [])
    }
}

private struct InitialCareSetupSummaryCard: View {
    let caregiverMode: CaregiverMode
    let healthFeatureEnabled: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SetupSectionHeader(
                icon: "sparkles",
                title: "What happens next",
                subtitle: "RemoteLove will prepare the care space after you tap Create."
            )

            VStack(alignment: .leading, spacing: 10) {
                SetupSummaryRow(icon: "person.text.rectangle.fill", title: "Create the care profile")
                SetupSummaryRow(icon: "person.badge.key.fill", title: "Add you as owner")
                SetupSummaryRow(icon: "number.square.fill", title: "Generate family and helper invite codes")
                SetupSummaryRow(icon: caregiverMode.allowsHelperCompletion ? "checkmark.seal.fill" : "eye.fill", title: caregiverMode.detail)
                SetupSummaryRow(icon: healthFeatureEnabled ? "heart.text.square.fill" : "eye.slash.fill", title: healthFeatureEnabled ? "Show Health tab for this care circle" : "Hide Health tab for now")
            }
        }
        .padding(18)
        .remoteLoveSectionSurface(cornerRadius: 24)
    }
}

private struct SetupSectionHeader: View {
    let icon: String
    let title: String
    let subtitle: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.headline)
                .foregroundColor(RemoteLoveTheme.coral)
                .frame(width: 34, height: 34)
                .background(RemoteLoveTheme.coral.opacity(0.12), in: Circle())
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.headline)
                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

private struct SetupSummaryRow: View {
    let icon: String
    let title: String

    var body: some View {
        Label {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        } icon: {
            Image(systemName: icon)
                .foregroundColor(RemoteLoveTheme.green)
        }
    }
}

struct PasswordResetView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var email = ""
    @State private var sent = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text("Enter the email used for the family account. This demonstration confirms the flow without sending a real email.")
                    TextField("Email address", text: $email)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                    Button("Send reset instructions") { sent = true }
                        .disabled(email.isEmpty)
                }
                if sent {
                    Section { Label("Reset instructions requested", systemImage: "checkmark.circle.fill").foregroundColor(RemoteLoveTheme.green) }
                }
            }
            .navigationTitle("Reset password")
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Close") { dismiss() } } }
        }
    }
}

struct MainTabView: View {
    @EnvironmentObject private var store: RemoteLoveStore
    @AppStorage("hasSeenRemoteLovePermissionOnboarding") private var hasSeenPermissionOnboarding = false
    @State private var showGuidedTutorialPrompt = false
    @State private var showGuidedTutorial = false
    @State private var showPermissionOnboarding = false
    @State private var guidedTutorialIndex = 0

    private var guidedSteps: [GuidedTutorialStep] {
        GuidedTutorialStep.steps(for: store.currentRole).filter { step in
            store.healthFeatureEnabled || !step.id.contains("health")
        }
    }

    var body: some View {
        Group {
            if store.recipients.isEmpty {
                EmptyCareCircleHomeView()
            } else if store.currentRole == .helper {
                TabView(selection: $store.selectedMainTab) {
                    NavigationStack { HelperHomeView() }
                        .tabItem { Label("Today", systemImage: "sun.max.fill") }
                        .tag(MainTab.helperToday)
                    NavigationStack { PlannerView() }
                        .tabItem { Label("Planner", systemImage: "calendar") }
                        .tag(MainTab.planner)
                    if store.healthFeatureEnabled {
                        NavigationStack { HealthView() }
                            .tabItem { Label("Health", systemImage: "heart.text.square") }
                            .tag(MainTab.health)
                    }
                    NavigationStack { SettingsView() }
                        .tabItem { Label("Settings", systemImage: "gearshape") }
                        .tag(MainTab.settings)
                }
            } else if store.currentRole == .viewer {
                TabView(selection: $store.selectedMainTab) {
                    NavigationStack { OverviewView() }
                        .tabItem { Label("Overview", systemImage: "square.grid.2x2.fill") }
                        .tag(MainTab.overview)
                    NavigationStack { PlannerView() }
                        .tabItem { Label("Planner", systemImage: "calendar") }
                        .tag(MainTab.planner)
                    if store.healthFeatureEnabled {
                        NavigationStack { HealthView() }
                            .tabItem { Label("Health", systemImage: "heart.text.square") }
                            .tag(MainTab.health)
                    }
                    NavigationStack { SettingsView() }
                        .tabItem { Label("Settings", systemImage: "gearshape") }
                        .tag(MainTab.settings)
                }
            } else {
                TabView(selection: $store.selectedMainTab) {
                    NavigationStack { OverviewView() }
                        .tabItem { Label("Overview", systemImage: "square.grid.2x2.fill") }
                        .tag(MainTab.overview)
                    NavigationStack { CareView() }
                        .tabItem { Label("Care", systemImage: "checklist") }
                        .tag(MainTab.care)
                    NavigationStack { PlannerView() }
                        .tabItem { Label("Planner", systemImage: "calendar") }
                        .tag(MainTab.planner)
                    if store.healthFeatureEnabled {
                        NavigationStack { HealthView() }
                            .tabItem { Label("Health", systemImage: "heart.text.square") }
                            .tag(MainTab.health)
                    }
                    NavigationStack { MoreView() }
                        .tabItem { Label("More", systemImage: "ellipsis.circle") }
                        .tag(MainTab.more)
                }
            }
        }
        .onAppear {
            ensureVisibleSelectedTab()
            showTutorialIfNeeded()
        }
        .onChange(of: store.healthFeatureEnabled) {
            ensureVisibleSelectedTab()
        }
        .overlayPreferenceValue(TutorialTargetPreferenceKey.self) { targets in
            GeometryReader { proxy in
                if showGuidedTutorial, guidedSteps.isEmpty == false {
                    let step = guidedSteps[min(guidedTutorialIndex, max(guidedSteps.count - 1, 0))]
                    GuidedTutorialOverlay(
                        steps: guidedSteps,
                        currentIndex: $guidedTutorialIndex,
                        focusRect: targets[step.target].map { proxy[$0] },
                        onBack: previousGuidedTutorialStep,
                        onNext: nextGuidedTutorialStep,
                        onSkip: finishGuidedTutorial
                    )
                    .transition(.opacity)
                    .zIndex(20)
                }
            }
        }
        .overlay {
            if showGuidedTutorialPrompt, guidedSteps.isEmpty == false {
                GuidedTutorialStartPrompt(
                    role: store.currentRole,
                    onStart: startGuidedTutorial,
                    onSkip: dismissGuidedTutorialPrompt
                )
                .transition(.opacity)
                .zIndex(19)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .remoteLoveStartGuidedTutorial)) { _ in
            startGuidedTutorial()
        }
        .sheet(isPresented: $showPermissionOnboarding) {
            PermissionOnboardingView(
                completionTitle: "Done",
                onComplete: finishPermissionOnboarding
            )
        }
    }

    private func startGuidedTutorial() {
        guidedTutorialIndex = 0
        if let firstStep = guidedSteps.first {
            withAnimation(.easeInOut(duration: 0.22)) {
                showGuidedTutorialPrompt = false
                store.selectedMainTab = firstStep.tab
                showGuidedTutorial = true
            }
            announceTutorialFocus(firstStep)
        }
    }

    private func ensureVisibleSelectedTab() {
        if !store.healthFeatureEnabled && store.selectedMainTab == .health {
            store.selectedMainTab = store.currentRole == .helper ? .helperToday : .overview
        }
    }

    private func previousGuidedTutorialStep() {
        guard guidedTutorialIndex > 0 else { return }
        guidedTutorialIndex -= 1
        if guidedSteps.indices.contains(guidedTutorialIndex) {
            withAnimation(.easeInOut(duration: 0.22)) {
                store.selectedMainTab = guidedSteps[guidedTutorialIndex].tab
            }
            announceTutorialFocus(guidedSteps[guidedTutorialIndex])
        }
    }

    private func nextGuidedTutorialStep() {
        let nextIndex = guidedTutorialIndex + 1
        guard nextIndex < guidedSteps.count else {
            finishGuidedTutorial()
            return
        }

        guidedTutorialIndex = nextIndex
        withAnimation(.easeInOut(duration: 0.22)) {
            store.selectedMainTab = guidedSteps[nextIndex].tab
        }
        announceTutorialFocus(guidedSteps[nextIndex])
    }

    private func announceTutorialFocus(_ step: GuidedTutorialStep) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.28) {
            NotificationCenter.default.post(name: .remoteLoveTutorialFocusChanged, object: step.target)
        }
    }

    private func finishGuidedTutorial() {
        markTutorialSeen()
        withAnimation(.easeInOut(duration: 0.18)) {
            showGuidedTutorial = false
            showGuidedTutorialPrompt = false
        }
        showPermissionOnboardingIfNeeded(delay: 0.35)
    }

    private func dismissGuidedTutorialPrompt() {
        markTutorialSeen()
        withAnimation(.easeInOut(duration: 0.18)) {
            showGuidedTutorialPrompt = false
        }
        showPermissionOnboardingIfNeeded(delay: 0.35)
    }

    private func showTutorialIfNeeded() {
        guard !store.recipients.isEmpty else { return }

        if shouldShowTutorialForCurrentRole {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
                guard shouldShowTutorialForCurrentRole else { return }
                withAnimation(.easeInOut(duration: 0.22)) {
                    showGuidedTutorialPrompt = true
                }
            }
        } else {
            showPermissionOnboardingIfNeeded(delay: 0.65)
        }
    }

    private func showPermissionOnboardingIfNeeded(delay: Double) {
        guard !hasSeenPermissionOnboarding else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            guard !showGuidedTutorialPrompt, !showGuidedTutorial else { return }
            showPermissionOnboarding = true
        }
    }

    private func finishPermissionOnboarding() {
        hasSeenPermissionOnboarding = true
        showPermissionOnboarding = false
    }

    private var shouldShowTutorialForCurrentRole: Bool {
        !UserDefaults.standard.bool(forKey: store.guidedTutorialStorageKey)
    }

    private func markTutorialSeen() {
        UserDefaults.standard.set(true, forKey: store.guidedTutorialStorageKey)
    }
}

private extension Notification.Name {
    static let remoteLoveStartGuidedTutorial = Notification.Name("remoteLoveStartGuidedTutorial")
    static let remoteLoveTutorialFocusChanged = Notification.Name("remoteLoveTutorialFocusChanged")
    static let remoteLoveDestinationScrollRequested = Notification.Name("remoteLoveDestinationScrollRequested")
}

private enum DestinationScrollTarget {
    static func task(_ id: UUID) -> String { "destination.task.\(id.uuidString)" }
    static func medicine(_ id: UUID) -> String { "destination.medicine.\(id.uuidString)" }
    static func appointment(_ id: UUID) -> String { "destination.appointment.\(id.uuidString)" }
    static func otherItem(_ id: UUID) -> String { "destination.other.\(id.uuidString)" }
    static func healthCategory(_ rawValue: String) -> String { "destination.health.\(rawValue)" }
    static func member(_ id: UUID) -> String { "destination.member.\(id.uuidString)" }
}

private func postDestinationScroll(_ target: String, delay: TimeInterval = 0.35) {
    DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
        NotificationCenter.default.post(name: .remoteLoveDestinationScrollRequested, object: target)
    }
}

private enum TutorialTarget: String, Hashable {
    case overviewHeader
    case overviewProfiles
    case overviewToday
    case overviewHealth
    case overviewCircle
    case careHeader
    case careProgress
    case careCalendar
    case careTasks
    case careUndo
    case helperHeader
    case helperProgress
    case helperTasks
    case helperEmergency
    case plannerHeader
    case plannerCalendar
    case plannerSchedule
    case plannerAttention
    case plannerMedicines
    case plannerAppointments
    case plannerOther
    case healthHeader
    case healthCategories
    case healthStatus
    case healthLog
    case healthExport
    case moreHeader
    case moreCareCircle
    case moreCarePlan
    case moreSafety
    case moreTutorial
    case settingsHeader
    case settingsNotifications
    case settingsTutorial

    var scrollID: String { rawValue }
}

private struct TutorialTargetPreferenceKey: PreferenceKey {
    static var defaultValue: [TutorialTarget: Anchor<CGRect>] = [:]

    static func reduce(value: inout [TutorialTarget: Anchor<CGRect>], nextValue: () -> [TutorialTarget: Anchor<CGRect>]) {
        value.merge(nextValue(), uniquingKeysWith: { _, new in new })
    }
}

private extension View {
    func tutorialSpotlight(_ target: TutorialTarget) -> some View {
        id(target.scrollID)
            .anchorPreference(key: TutorialTargetPreferenceKey.self, value: .bounds) { anchor in
                [target: anchor]
            }
    }

    func tutorialScrollReceiver(_ proxy: ScrollViewProxy) -> some View {
        onReceive(NotificationCenter.default.publisher(for: .remoteLoveTutorialFocusChanged)) { notification in
            guard let target = notification.object as? TutorialTarget else { return }
            withAnimation(.easeInOut(duration: 0.28)) {
                proxy.scrollTo(target.scrollID, anchor: .center)
            }
        }
    }

    func destinationScrollReceiver(_ proxy: ScrollViewProxy) -> some View {
        onReceive(NotificationCenter.default.publisher(for: .remoteLoveDestinationScrollRequested)) { notification in
            guard let target = notification.object as? String else { return }
            withAnimation(.easeInOut(duration: 0.32)) {
                proxy.scrollTo(target, anchor: .center)
            }
        }
    }
}

private struct GuidedTutorialStep: Identifiable {
    let id: String
    let tab: MainTab
    let icon: String
    let title: String
    let message: String
    let focus: String
    let interaction: String
    var action: GuidedTutorialAction = .none

    var target: TutorialTarget {
        switch id {
        case "owner-overview-start", "family-joined-overview", "viewer-overview-status":
            return .overviewHeader
        case "family-joined-today":
            return .overviewToday
        case "viewer-overview-health":
            return .overviewHealth
        case "family-joined-people":
            return .overviewCircle
        case "family-joined-care":
            return .careCalendar
        case "owner-care-first-task", "family-joined-task-list":
            return .careTasks
        case "owner-care-add-task":
            return .careHeader
        case "owner-planner-add", "family-joined-planner", "helper-planner", "viewer-planner-items":
            return .plannerMedicines
        case "helper-planner-attention", "viewer-planner-attention":
            return .plannerAttention
        case "owner-health-log", "family-joined-health", "helper-health", "viewer-health-readings":
            return .healthCategories
        case "helper-health-status":
            return .healthStatus
        case "helper-health-log":
            return .healthLog
        case "viewer-health-export":
            return .healthHeader
        case "owner-more-invites":
            return .moreCareCircle
        case "owner-more-replay", "family-joined-replay":
            return .moreTutorial
        case "helper-today-progress":
            return .helperProgress
        case "helper-today-task", "helper-today-practice-done", "helper-today-photo", "helper-today-calendar":
            return .helperTasks
        case "helper-today-emergency":
            return .helperEmergency
        case "helper-settings-access":
            return .settingsHeader
        case "helper-settings-notifications":
            return .settingsNotifications
        case "helper-settings-tutorial", "viewer-settings":
            return .settingsTutorial
        default:
            switch tab {
            case .overview:
                return .overviewHeader
            case .care:
                return .careHeader
            case .planner:
                return .plannerHeader
            case .health:
                return .healthHeader
            case .more:
                return .moreHeader
            case .helperToday:
                return .helperHeader
            case .settings:
                return .settingsHeader
            default:
                return .overviewHeader
            }
        }
    }

    static func steps(for role: UserRole) -> [GuidedTutorialStep] {
        switch role {
        case .helper:
            return helperSteps
        case .viewer:
            return viewerSteps
        case .owner:
            return newOwnerSteps
        case .family:
            return joiningFamilySteps
        }
    }

    private static let newOwnerSteps: [GuidedTutorialStep] = [
        GuidedTutorialStep(
            id: "owner-overview-start",
            tab: .overview,
            icon: "square.grid.2x2.fill",
            title: "Your family dashboard",
            message: "Overview is the calm check-in page for this care profile. Start here when you want to know what needs attention today.",
            focus: "Overview header",
            interaction: "Check that the selected care profile is the person you just set up."
        ),
        GuidedTutorialStep(
            id: "owner-care-add-task",
            tab: .care,
            icon: "plus.circle.fill",
            title: "Add the first routine task",
            message: "Care is where daily routines live. You can add a first task now, or leave it until your family is ready.",
            focus: "Care action: Add task",
            interaction: "Open the task controls to see where a new routine starts."
        ),
        GuidedTutorialStep(
            id: "owner-care-first-task",
            tab: .care,
            icon: "checklist.checked",
            title: "Today’s task list",
            message: "Tasks stay sorted by time. If your family completes care directly, Done and Undo appear on today’s tasks.",
            focus: "Care section: Tasks",
            interaction: "Scan the list. If it is empty, use the add button later when you know the routine."
        ),
        GuidedTutorialStep(
            id: "owner-planner-add",
            tab: .planner,
            icon: "calendar.badge.plus",
            title: "Plan medicines and appointments",
            message: "Planner keeps medicines, appointments, and other reminders separate from daily task management.",
            focus: "Bottom tab: Planner",
            interaction: "Tap Add later to choose Medicine, Appointment, or Other."
        ),
        GuidedTutorialStep(
            id: "owner-health-log",
            tab: .health,
            icon: "heart.text.square.fill",
            title: "Track health only if useful",
            message: "Health monitor is optional for each care circle. When enabled, readings sync for family and helpers who have access.",
            focus: "Bottom tab: Health",
            interaction: "Open a category when you want to log or review readings."
        ),
        GuidedTutorialStep(
            id: "owner-more-invites",
            tab: .more,
            icon: "person.badge.plus.fill",
            title: "Invite the right people",
            message: "Care circle is where you share invite codes and review who has access to this care profile.",
            focus: "More row: Care circle",
            interaction: "Open Care circle later when you want to invite family or helpers."
        ),
        GuidedTutorialStep(
            id: "owner-more-replay",
            tab: .more,
            icon: "questionmark.circle.fill",
            title: "Replay this anytime",
            message: "Skip means RemoteLove will not show this automatically again. You can still replay the walkthrough from App tutorial.",
            focus: "More row: App tutorial",
            interaction: "Remember this row if another family member needs a refresher."
        )
    ]

    private static let joiningFamilySteps: [GuidedTutorialStep] = [
        GuidedTutorialStep(
            id: "family-joined-overview",
            tab: .overview,
            icon: "person.2.fill",
            title: "You’ve joined this care circle",
            message: "Overview shows the shared picture for the care profile you joined. You do not need to create another profile.",
            focus: "Overview header",
            interaction: "Check the selected care profile before reviewing the day."
        ),
        GuidedTutorialStep(
            id: "family-joined-today",
            tab: .overview,
            icon: "list.bullet.clipboard.fill",
            title: "Start with today’s care",
            message: "This section explains what is done, what is open, and what may need attention.",
            focus: "Overview section: Today’s care",
            interaction: "Tap a summary later to jump to the matching area."
        ),
        GuidedTutorialStep(
            id: "family-joined-care",
            tab: .care,
            icon: "checklist",
            title: "Review the daily routine",
            message: "Care shows tasks by date. If family completion is enabled, you can help mark today’s tasks done.",
            focus: "Care date calendar",
            interaction: "Swipe dates or jump back to today."
        ),
        GuidedTutorialStep(
            id: "family-joined-task-list",
            tab: .care,
            icon: "checkmark.circle.fill",
            title: "Open task details carefully",
            message: "Task cards show timing, instructions, and whether a photo is required. Edits should be intentional.",
            focus: "Care section: Tasks",
            interaction: "Tap a task later when you need its details."
        ),
        GuidedTutorialStep(
            id: "family-joined-planner",
            tab: .planner,
            icon: "calendar",
            title: "Look ahead in Planner",
            message: "Planner keeps medicines, appointments, and other upcoming care items connected to this profile.",
            focus: "Bottom tab: Planner",
            interaction: "Open an item later to review its details."
        ),
        GuidedTutorialStep(
            id: "family-joined-health",
            tab: .health,
            icon: "heart.text.square.fill",
            title: "Check health signals",
            message: "Health readings use simple labels like Good, Watch, and Needs attention so everyone can scan quickly.",
            focus: "Overview section: Health condition",
            interaction: "Tap a Health category later to see readings and notes."
        ),
        GuidedTutorialStep(
            id: "family-joined-replay",
            tab: .more,
            icon: "questionmark.circle.fill",
            title: "Find help later",
            message: "More keeps support, settings, safety information, and App tutorial. You can replay this whenever you need.",
            focus: "More row: App tutorial",
            interaction: "Use App tutorial if you want to run the guide again."
        )
    ]

    private static let helperSteps: [GuidedTutorialStep] = [
        GuidedTutorialStep(
            id: "helper-today-progress",
            tab: .helperToday,
            icon: "sun.max.fill",
            title: "Today: task progress",
            message: "Today is the helper home base. The progress bar at the top shows how many tasks are completed for the selected day.",
            focus: "Bottom tab: Today",
            interaction: "Read the progress bar before looking through the tasks."
        ),
        GuidedTutorialStep(
            id: "helper-today-task",
            tab: .helperToday,
            icon: "checklist",
            title: "Today: task cards",
            message: "Task cards show what needs to be done, when it is due, and whether photo evidence is required.",
            focus: "Today section: Task list",
            interaction: "Open one task card and read the instructions."
        ),
        GuidedTutorialStep(
            id: "helper-today-practice-done",
            tab: .helperToday,
            icon: "checkmark.circle.fill",
            title: "Practice Done safely",
            message: "Helpers can mark today's tasks done. For this tutorial, the practice tap will be undone automatically so nothing changes for the family.",
            focus: "Task action: Done / Undo done",
            interaction: "Use Practice Done below, or continue if there is no task available.",
            action: .practiceHelperDone
        ),
        GuidedTutorialStep(
            id: "helper-today-photo",
            tab: .helperToday,
            icon: "camera.fill",
            title: "Today: photo tasks",
            message: "Some tasks require a photo before they can be completed. This gives family members confidence that the task was handled.",
            focus: "Task requirement: Photo",
            interaction: "Look for the Photo label on any task that requires evidence."
        ),
        GuidedTutorialStep(
            id: "helper-today-calendar",
            tab: .helperToday,
            icon: "calendar",
            title: "Today: future dates",
            message: "Helpers can view future tasks to prepare, but completion controls only appear for today's tasks.",
            focus: "Today section: Date strip",
            interaction: "Swipe the date strip, then use Today to jump back."
        ),
        GuidedTutorialStep(
            id: "helper-today-emergency",
            tab: .helperToday,
            icon: "exclamationmark.triangle.fill",
            title: "Today: emergency alert",
            message: "Emergency alert should be used only when the care recipient needs urgent family attention.",
            focus: "Today action: Emergency alert",
            interaction: "Notice where the emergency button is, but use it only for urgent situations."
        ),
        GuidedTutorialStep(
            id: "helper-planner-medicines",
            tab: .planner,
            icon: "pills.fill",
            title: "Planner: medicines",
            message: "Planner shows medicines and upcoming care items. Medicine cards show timing, dose, and supply status.",
            focus: "Bottom tab: Planner",
            interaction: "Tap a medicine to review its details."
        ),
        GuidedTutorialStep(
            id: "helper-planner-attention",
            tab: .planner,
            icon: "exclamationmark.circle.fill",
            title: "Planner: attention items",
            message: "Amber highlights point out medicines or planner items that need extra attention from the care circle.",
            focus: "Planner highlight: Attention",
            interaction: "Look for amber outlines or labels when reviewing Planner."
        ),
        GuidedTutorialStep(
            id: "helper-planner-appointments",
            tab: .planner,
            icon: "calendar.badge.clock",
            title: "Planner: appointments",
            message: "Appointments and other planner items help helpers prepare for what is coming next.",
            focus: "Planner section: Appointments and Other",
            interaction: "Tap an upcoming item to see what the family has planned."
        ),
        GuidedTutorialStep(
            id: "helper-health-categories",
            tab: .health,
            icon: "heart.text.square.fill",
            title: "Health: categories",
            message: "Helpers can use Health to review readings and add new health records by default when Health is enabled for the care circle.",
            focus: "Bottom tab: Health",
            interaction: "Tap a health category to review its latest reading."
        ),
        GuidedTutorialStep(
            id: "helper-health-status",
            tab: .health,
            icon: "info.circle.fill",
            title: "Health: status labels",
            message: "Status labels help helpers know whether a reading looks normal, should be watched, or needs family attention.",
            focus: "Health labels: Good / Watch / Attention",
            interaction: "Tap the info button to open the status guide popup."
        ),
        GuidedTutorialStep(
            id: "helper-health-log",
            tab: .health,
            icon: "plus.circle.fill",
            title: "Health: logging readings",
            message: "When you add a reading, include helpful notes so the family understands the context.",
            focus: "Health action: Log reading",
            interaction: "Find the plus button when you need to record a new reading."
        ),
        GuidedTutorialStep(
            id: "helper-settings-access",
            tab: .settings,
            icon: "gearshape.fill",
            title: "Settings: helper access",
            message: "Settings keeps helper access information, including PIN-related controls and account/session actions.",
            focus: "Bottom tab: Settings",
            interaction: "Review where helper access settings live."
        ),
        GuidedTutorialStep(
            id: "helper-settings-notifications",
            tab: .settings,
            icon: "bell.slash.fill",
            title: "Settings: notifications",
            message: "Helpers can mute notifications when needed. RemoteLove records this so family members know reminders were muted.",
            focus: "Settings section: Notifications",
            interaction: "Find the notification mute controls."
        ),
        GuidedTutorialStep(
            id: "helper-settings-tutorial",
            tab: .settings,
            icon: "questionmark.circle.fill",
            title: "Settings: replay tutorial",
            message: "You can replay this tutorial anytime from Settings if you need a refresher.",
            focus: "Settings row: App tutorial",
            interaction: "Remember where App tutorial is for later."
        )
    ]

    private static let viewerSteps: [GuidedTutorialStep] = [
        GuidedTutorialStep(
            id: "viewer-overview-status",
            tab: .overview,
            icon: "square.grid.2x2.fill",
            title: "Overview: read-only status",
            message: "Viewer access is read-only. Overview helps you understand care status across profiles without changing records.",
            focus: "Bottom tab: Overview",
            interaction: "Try switching care profiles to compare each person's status."
        ),
        GuidedTutorialStep(
            id: "viewer-overview-health",
            tab: .overview,
            icon: "heart.text.square.fill",
            title: "Overview: health condition",
            message: "Use health condition summaries to see whether recent readings look Good, Watch, or Need attention.",
            focus: "Overview section: Health condition",
            interaction: "Look for any status labels that need follow-up."
        ),
        GuidedTutorialStep(
            id: "viewer-planner-items",
            tab: .planner,
            icon: "calendar",
            title: "Planner: upcoming items",
            message: "Review medicines, appointments, and other upcoming items connected to the selected care profile.",
            focus: "Bottom tab: Planner",
            interaction: "Try selecting an upcoming item to inspect the details."
        ),
        GuidedTutorialStep(
            id: "viewer-planner-attention",
            tab: .planner,
            icon: "exclamationmark.circle.fill",
            title: "Planner: attention highlights",
            message: "Attention highlights help viewers spot low-supply medicines or items the family may need to review.",
            focus: "Planner highlight: Attention",
            interaction: "Look for highlighted medicine or planner rows."
        ),
        GuidedTutorialStep(
            id: "viewer-health-readings",
            tab: .health,
            icon: "heart.text.square.fill",
            title: "Health: readings",
            message: "Review health readings and simple status labels. Viewer access does not edit care records.",
            focus: "Bottom tab: Health",
            interaction: "Try opening a health category to understand its recent trend."
        ),
        GuidedTutorialStep(
            id: "viewer-health-export",
            tab: .health,
            icon: "arrow.down.doc.fill",
            title: "Health: export",
            message: "If permitted, health data can be exported by category for sharing outside the app.",
            focus: "Health action: Export",
            interaction: "Look for the export icon at the top of Health monitor."
        ),
        GuidedTutorialStep(
            id: "viewer-settings",
            tab: .settings,
            icon: "gearshape.fill",
            title: "Settings",
            message: "Settings contains appearance, policies, tutorial access, and logout.",
            focus: "Bottom tab: Settings",
            interaction: "Try finding Tutorial here if you want to replay the walkthrough."
        )
    ]
}

private enum GuidedTutorialAction {
    case none
    case practiceHelperDone
}

private struct GuidedTutorialOverlay: View {
    @EnvironmentObject private var store: RemoteLoveStore
    let steps: [GuidedTutorialStep]
    @Binding var currentIndex: Int
    let focusRect: CGRect?
    let onBack: () -> Void
    let onNext: () -> Void
    let onSkip: () -> Void
    @State private var actionMessage: String?

    private var step: GuidedTutorialStep {
        steps[min(currentIndex, max(steps.count - 1, 0))]
    }

    private var nextStepTitle: String? {
        let nextIndex = currentIndex + 1
        guard steps.indices.contains(nextIndex) else { return nil }
        return steps[nextIndex].title
    }

    private var nextStep: GuidedTutorialStep? {
        let nextIndex = currentIndex + 1
        guard steps.indices.contains(nextIndex) else { return nil }
        return steps[nextIndex]
    }

    private var nextButtonTitle: String {
        if currentIndex == steps.count - 1 {
            return "Finish"
        }
        guard let nextStep else { return "Next" }
        if nextStep.tab == step.tab {
            return "Next"
        }
        return "Next: \(tabTitle(for: nextStep.tab))"
    }

    private var tutorialCueText: String {
        if currentIndex == steps.count - 1 {
            return "Last step. Finish when you’re ready."
        }
        if let nextStepTitle {
            return "Next, we’ll look at \(nextStepTitle.lowercased())."
        }
        return "Continue when this part feels clear."
    }

    private var tabProgressText: String {
        let tabSteps = steps.filter { $0.tab == step.tab }
        let completedInTab = steps.prefix(currentIndex + 1).filter { $0.tab == step.tab }.count
        return "\(tabTitle(for: step.tab)) \(completedInTab)/\(max(tabSteps.count, 1))"
    }

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: cardAlignment(in: proxy.size)) {
                Color.black.opacity(0.34)
                    .ignoresSafeArea()
                    .allowsHitTesting(false)

                if let focusRect {
                    TutorialFocusBox(rect: focusRect)
                        .allowsHitTesting(false)
                }

                tutorialCard
                    .padding(.horizontal, 18)
                    .padding(cardPadding(in: proxy.size))
            }
        }
        .accessibilityElement(children: .contain)
    }

    private var tutorialCard: some View {
        VStack(spacing: 14) {
                HStack(spacing: 10) {
                    Image(systemName: step.icon)
                        .font(.headline)
                        .foregroundColor(RemoteLoveTheme.green)
                        .frame(width: 40, height: 40)
                        .background(RemoteLoveTheme.green.opacity(0.13), in: Circle())
                        .accessibilityHidden(true)

                    VStack(alignment: .leading, spacing: 3) {
                        Text("Guided walkthrough")
                            .font(.caption.weight(.bold))
                            .foregroundColor(RemoteLoveTheme.green)
                        Text(step.title)
                            .font(.headline)
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 5) {
                        Text(tabProgressText)
                            .font(.caption.weight(.bold))
                            .foregroundColor(RemoteLoveTheme.green)
                            .padding(.horizontal, 9)
                            .padding(.vertical, 6)
                            .background(RemoteLoveTheme.green.opacity(0.10), in: Capsule())
                        Text("\(currentIndex + 1)/\(steps.count) total")
                            .font(.caption2.weight(.semibold))
                            .foregroundColor(.secondary)
                    }
                }

                HStack(alignment: .top, spacing: 9) {
                    Image(systemName: "scope")
                        .font(.caption.weight(.bold))
                        .foregroundColor(RemoteLoveTheme.green)
                        .frame(width: 24, height: 24)
                        .background(RemoteLoveTheme.green.opacity(0.12), in: Circle())
                        .accessibilityHidden(true)

                    VStack(alignment: .leading, spacing: 3) {
                        Text("We’re looking at \(step.focus.lowercased())")
                            .font(.caption.weight(.bold))
                            .foregroundColor(.primary)
                        Text("The green glow marks the real area on screen. Explore it first, then continue when it makes sense.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer(minLength: 0)
                }
                .padding(10)
                .background(RemoteLoveTheme.green.opacity(0.08), in: RoundedRectangle(cornerRadius: 14, style: .continuous))

                Text(step.message)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)

                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "hand.tap.fill")
                        .font(.subheadline.weight(.bold))
                        .foregroundColor(RemoteLoveTheme.green)
                        .frame(width: 28, height: 28)
                        .background(RemoteLoveTheme.green.opacity(0.14), in: Circle())
                        .accessibilityHidden(true)

                    VStack(alignment: .leading, spacing: 3) {
                        Text("Try it now")
                            .font(.caption.weight(.bold))
                            .foregroundColor(.primary)
                        Text(step.interaction)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer(minLength: 0)
                }
                .padding(12)
                .background(RemoteLoveTheme.green.opacity(0.08), in: RoundedRectangle(cornerRadius: 16, style: .continuous))

                tutorialAction

                HStack(spacing: 8) {
                    Image(systemName: "checkmark.seal.fill")
                        .foregroundColor(RemoteLoveTheme.green)
                        .accessibilityHidden(true)
                    Text(tutorialCueText)
                        .font(.caption.weight(.semibold))
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 13, style: .continuous))

                ProgressView(value: Double(currentIndex + 1), total: Double(max(steps.count, 1)))
                    .tint(RemoteLoveTheme.green)

                HStack(spacing: 10) {
                    Button("Skip for now") {
                        onSkip()
                    }
                    .buttonStyle(.bordered)

                    Spacer()

                    Button("Back") {
                        onBack()
                    }
                    .buttonStyle(.bordered)
                    .disabled(currentIndex == 0)
                    .opacity(currentIndex == 0 ? 0.45 : 1)

                    Button {
                        onNext()
                    } label: {
                        Label(
                            currentIndex == steps.count - 1 ? "Finish" : nextButtonTitle,
                            systemImage: currentIndex == steps.count - 1 ? "checkmark" : "chevron.right"
                        )
                            .lineLimit(1)
                            .minimumScaleFactor(0.72)
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    .frame(maxWidth: 190)
                }
            }
            .padding(16)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 26, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .stroke(RemoteLoveTheme.green.opacity(0.18), lineWidth: 1)
            }
            .shadow(color: .black.opacity(0.18), radius: 24, y: 10)
            .onChange(of: currentIndex) {
                actionMessage = nil
            }
    }

    @ViewBuilder
    private var tutorialAction: some View {
        switch step.action {
        case .none:
            EmptyView()
        case .practiceHelperDone:
            VStack(alignment: .leading, spacing: 8) {
                Button {
                    withAnimation(.spring(response: 0.28, dampingFraction: 0.82)) {
                        actionMessage = store.practiceCompleteFirstHelperTaskForTutorial()
                    }
                } label: {
                    Label("Practice Done", systemImage: "checkmark.circle.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(PrimaryButtonStyle())

                if let actionMessage {
                    Text(actionMessage)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(12)
            .background(RemoteLoveTheme.coral.opacity(0.08), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
    }

    private func cardAlignment(in size: CGSize) -> Alignment {
        guard let focusRect else { return .bottom }
        return focusRect.midY < size.height * 0.52 ? .bottom : .top
    }

    private func cardPadding(in size: CGSize) -> EdgeInsets {
        guard let focusRect else {
            return EdgeInsets(top: 0, leading: 0, bottom: 16, trailing: 0)
        }

        if focusRect.midY < size.height * 0.52 {
            return EdgeInsets(top: 0, leading: 0, bottom: 16, trailing: 0)
        }

        return EdgeInsets(top: 12, leading: 0, bottom: 0, trailing: 0)
    }

    private func tabTitle(for tab: MainTab) -> String {
        switch tab {
        case .overview:
            return "Overview"
        case .care:
            return "Care"
        case .planner:
            return "Planner"
        case .health:
            return "Health"
        case .more:
            return "More"
        case .helperToday:
            return "Today"
        case .helperTasks:
            return "Tasks"
        case .updates:
            return "Updates"
        case .history:
            return "History"
        case .settings:
            return "Settings"
        }
    }
}

private struct TutorialFocusBox: View {
    let rect: CGRect
    @State private var pulse = false

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(RemoteLoveTheme.green.opacity(pulse ? 0.12 : 0.06))

            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(RemoteLoveTheme.green.opacity(pulse ? 0.95 : 0.58), lineWidth: pulse ? 3.2 : 2.2)
                .shadow(color: RemoteLoveTheme.green.opacity(pulse ? 0.52 : 0.22), radius: pulse ? 18 : 8)

            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(RemoteLoveTheme.green.opacity(pulse ? 0.28 : 0.12), lineWidth: 9)
                .blur(radius: 4)

            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(Color.white.opacity(pulse ? 0.48 : 0.20), lineWidth: 1)
        }
        .frame(width: max(rect.width + 12, 72), height: max(rect.height + 12, 52))
        .position(x: rect.midX, y: rect.midY)
        .animation(.easeInOut(duration: 1.05).repeatForever(autoreverses: true), value: pulse)
        .onAppear {
            pulse = true
        }
    }
}

private struct GuidedTutorialStartPrompt: View {
    let role: UserRole
    let onStart: () -> Void
    let onSkip: () -> Void

    private var title: String {
        switch role {
        case .helper:
            return "Quick helper walkthrough?"
        case .viewer:
            return "Quick viewer walkthrough?"
        case .owner, .family:
            return "Quick family walkthrough?"
        }
    }

    private var message: String {
        switch role {
        case .helper:
            return "RemoteLove can walk you through Today, Planner, Health, and Settings so you know where tasks and updates live."
        case .viewer:
            return "RemoteLove can show you how to review care status, planner items, health readings, and settings without changing records."
        case .owner, .family:
            return "RemoteLove can guide you through each tab step by step, from overview to care tasks, planner, health, and invite settings."
        }
    }

    var body: some View {
        ZStack {
            Color.black.opacity(0.30)
                .ignoresSafeArea()

            VStack(spacing: 16) {
                Image("LaunchLogo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 74, height: 74)
                    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                    .accessibilityHidden(true)

                VStack(spacing: 8) {
                    Text(title)
                        .font(.title3.bold())
                        .multilineTextAlignment(.center)
                    Text(message)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }

                VStack(spacing: 10) {
                    Button {
                        onStart()
                    } label: {
                        Label("Start walkthrough", systemImage: "sparkles")
                    }
                    .buttonStyle(PrimaryButtonStyle())

                    Button("Skip for now") {
                        onSkip()
                    }
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(RemoteLoveTheme.green)
                    .frame(minHeight: 44)
                }
            }
            .padding(22)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .stroke(RemoteLoveTheme.green.opacity(0.18), lineWidth: 1)
            }
            .shadow(color: .black.opacity(0.18), radius: 24, y: 10)
            .padding(.horizontal, 24)
            .accessibilityElement(children: .contain)
        }
    }
}

struct EmptyCareCircleHomeView: View {
    @EnvironmentObject private var store: RemoteLoveStore
    @State private var confirmLogout = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    Image("LaunchLogo")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 88, height: 88)
                        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))

                    VStack(spacing: 6) {
                        Text("New care circle")
                            .font(.system(size: 30, weight: .bold, design: .rounded))
                        Text("Family code \(store.generatedInviteCode ?? "")")
                            .font(.headline.monospaced())
                            .foregroundColor(RemoteLoveTheme.green)
                        Text("Helper code \(store.activeHelperInviteCode)")
                            .font(.subheadline.monospaced())
                            .foregroundColor(.secondary)
                    }

                    VStack(spacing: 14) {
                        Button {
                            store.shouldPromptForFirstCareProfile = true
                        } label: {
                            Label("Add care profile", systemImage: "person.crop.circle.badge.plus")
                        }
                        .buttonStyle(PrimaryButtonStyle())

                        ShareLink(item: store.generatedInviteCode ?? "") {
                            Label("Share family code", systemImage: "square.and.arrow.up")
                        }
                        .buttonStyle(SecondaryButtonStyle())

                        ShareLink(item: store.activeHelperInviteCode) {
                            Label("Share helper code", systemImage: "key.fill")
                        }
                        .buttonStyle(SecondaryButtonStyle())

                        if let authMessage = store.authMessage, !authMessage.isEmpty {
                            Text(authMessage)
                                .font(.footnote)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                        }
                    }
                    .padding(20)
                    .background(.background, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
                    .shadow(color: .black.opacity(0.08), radius: 18, y: 8)
                }
                .padding(.horizontal, 22)
                .padding(.vertical, 36)
                .frame(maxWidth: 520)
                .frame(maxWidth: .infinity)
            }
            .background(RemoteLoveTheme.mint.opacity(0.55).ignoresSafeArea())
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Log out") { confirmLogout = true }
                }
            }
            .sheet(isPresented: $store.shouldPromptForFirstCareProfile) {
                AddCareProfileView()
            }
            .alert("Log out?", isPresented: $confirmLogout) {
                Button("Cancel", role: .cancel) { }
                Button("Log out", role: .destructive) { store.logout() }
            } message: {
                Text("This clears the local session and returns RemoteLove to the welcome screen.")
            }
        }
    }
}

struct AddCareProfileView: View {
    @EnvironmentObject private var store: RemoteLoveStore
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var label = ""
    @State private var age = 0
    @State private var relationship = ""

    private var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var profileTitle: String {
        let displayName = trimmedName.isEmpty ? "New care profile" : trimmedName
        let displayRelationship = relationship.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Family" : relationship
        let displayLabel = label.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Family" : label
        return "\(displayName) · \(displayRelationship) · \(displayLabel)"
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    VStack(alignment: .leading, spacing: 5) {
                        Text(profileTitle)
                            .font(.title3.bold())
                        Text("Full name, relationship and label")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(18)
                    .remoteLoveSectionSurface(cornerRadius: 22)

                    TextField("Full name", text: $name)
                        .textContentType(.name)
                        .padding(14)
                        .background(Color.secondary.opacity(0.09), in: RoundedRectangle(cornerRadius: 14, style: .continuous))

                    TextField("Relationship, e.g. Parent", text: $relationship)
                        .padding(14)
                        .background(Color.secondary.opacity(0.09), in: RoundedRectangle(cornerRadius: 14, style: .continuous))

                    TextField("Label, e.g. Mum", text: $label)
                        .padding(14)
                        .background(Color.secondary.opacity(0.09), in: RoundedRectangle(cornerRadius: 14, style: .continuous))

                    InitialCareAgePicker(age: $age)

                    Button(store.isSyncing ? "Saving..." : "Save care profile") {
                        Task {
                            await store.addCareRecipient(name: name, label: label, age: age, relationship: relationship)
                            if !store.recipients.isEmpty {
                                dismiss()
                            }
                        }
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    .disabled(store.isSyncing || trimmedName.isEmpty)
                    .opacity(store.isSyncing || trimmedName.isEmpty ? 0.55 : 1)
                }
                .padding(20)
            }
            .background(Color(uiColor: .systemGroupedBackground).ignoresSafeArea())
            .navigationTitle("Add care profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}

struct RecipientHeader: View {
    @EnvironmentObject private var store: RemoteLoveStore

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 1) {
                Text("PEOPLE RECEIVING CARE").font(.caption2.weight(.bold)).foregroundColor(.secondary)
                Menu {
                    ForEach(store.recipients) { recipient in
                        Button {
                            store.selectedRecipientID = recipient.id
                        } label: {
                            Label(recipient.label + " · " + recipient.name, systemImage: recipient.id == store.selectedRecipientID ? "checkmark.circle.fill" : "person.circle")
                        }
                    }
                } label: {
                    HStack(spacing: 5) {
                        Text(store.selectedRecipient.label).font(.headline).foregroundColor(.primary)
                        Image(systemName: "chevron.down").font(.caption.bold())
                    }
                }
            }
            Spacer()
        }
        .padding(.horizontal)
        .padding(.vertical, 10)
        .background(.background)
    }
}

struct OverviewView: View {
    @EnvironmentObject private var store: RemoteLoveStore
    @State private var hasAppeared = false
    @State private var showAddCareProfile = false
    @State private var editingFirstTask: CareTask?
    @State private var editingFirstMedicine: Medicine?
    @State private var showHealthLogger = false

    private var overviewRecipients: [CareRecipient] {
        guard let id = store.overviewRecipientID else { return store.recipients }
        return store.recipients.filter { $0.id == id }
    }

    private var overviewTasks: [CareTask] {
        overviewRecipients.flatMap { recipient in
            store.tasks(on: Date(), recipientID: recipient.id)
        }
    }
    private var allOverviewTasks: [CareTask] {
        store.tasks.filter { task in
            overviewRecipients.contains(where: { $0.id == task.recipientID })
        }
    }
    private var completed: Int { overviewTasks.filter { $0.state == .done }.count }
    private var activeMedicines: [Medicine] { store.medicines.filter { medicine in medicine.active && overviewRecipients.contains(where: { $0.id == medicine.recipientID }) } }
    private var lowMedicines: [Medicine] { activeMedicines.filter { $0.daysRemaining <= $0.attentionDays } }
    private var selectedHealthLogs: [HealthLog] {
        store.healthLogs.filter { log in overviewRecipients.contains(where: { $0.id == log.recipientID }) }
    }

    private var healthAttentionCount: Int {
        latestHealthRows().filter { row in
            row.category.status(for: row.log.value, age: store.selectedRecipient.age) == .needsAttention
        }.count
    }

    private var shouldShowFirstSteps: Bool {
        store.currentRole.canManageCare
            && store.overviewRecipientID != nil
            && (allOverviewTasks.isEmpty || activeMedicines.isEmpty || (store.healthFeatureEnabled && selectedHealthLogs.isEmpty))
    }

    var body: some View {
        ScrollViewReader { tutorialProxy in
            ScrollView {
                LazyVStack(spacing: 16) {
                RecipientHeader()

                VStack(alignment: .leading, spacing: 8) {
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("CARE AT A GLANCE").font(.caption.bold()).foregroundColor(RemoteLoveTheme.green)
                            Text(store.overviewRecipientID == nil ? "Everyone today" : "\(overviewRecipients.first?.label ?? "Care") today")
                                .font(.largeTitle.bold())
                        }
                        Spacer()
                        if store.currentRole.canManageCare {
                            Button {
                                showAddCareProfile = true
                            } label: {
                                Label("Add profile", systemImage: "person.crop.circle.badge.plus")
                                    .font(.subheadline.weight(.semibold))
                            }
                            .buttonStyle(.bordered)
                            .accessibilityLabel("Add care profile")
                        }
                    }
                    Picker("Viewing", selection: $store.overviewRecipientID) {
                        Text("All people").tag(UUID?.none)
                        ForEach(store.recipients) { Text($0.label).tag(Optional($0.id)) }
                    }
                    .pickerStyle(.segmented)
                    Text(store.overviewRecipientID == nil ? "Start with each person, then tap a profile for details." : "Showing tasks, health and care-circle activity for this profile.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal)
                .tutorialSpotlight(.overviewHeader)

                if let emergency = store.emergencyMessage {
                    EmergencyBanner(message: emergency)
                }

                if !store.recipients.isEmpty {
                    OverviewPrioritySummaryCard(
                        recipientCount: overviewRecipients.count,
                        openTaskCount: overviewTasks.filter { $0.state != .done }.count,
                        lowMedicineCount: lowMedicines.count,
                        healthAttentionCount: healthAttentionCount
                    )
                    .padding(.horizontal)
                    .remoteLoveAppear(active: hasAppeared, delay: 0.01)
                }

                if shouldShowFirstSteps {
                    FirstCareStepsCard(
                        needsTask: allOverviewTasks.isEmpty,
                        needsMedicine: activeMedicines.isEmpty,
                        needsHealth: store.healthFeatureEnabled && selectedHealthLogs.isEmpty,
                        onAddTask: { editingFirstTask = newFirstTask() },
                        onAddMedicine: { editingFirstMedicine = newFirstMedicine() },
                        onLogHealth: { showHealthLogger = true }
                    )
                    .remoteLoveAppear(active: hasAppeared, delay: 0.01)
                }

                if store.overviewRecipientID == nil {
                    NativeCard(title: "People receiving care", subtitle: "Tap a profile to focus the whole overview", icon: "person.2.fill") {
                        ForEach(store.recipients) { recipient in
                            OverviewPersonBreakdownRow(recipient: recipient)
                            if recipient.id != store.recipients.last?.id {
                                Divider()
                            }
                        }
                    }
                    .remoteLoveAppear(active: hasAppeared, delay: 0.02)
                    .tutorialSpotlight(.overviewProfiles)
                } else {
                    HStack(spacing: 12) {
                        MetricCard(value: "\(completed)/\(overviewTasks.count)", label: "Tasks complete", icon: "checkmark.circle.fill", tint: RemoteLoveTheme.green)
                        MetricCard(value: "\(lowMedicines.count)", label: "Medicines to check", icon: "pills.fill", tint: lowMedicines.isEmpty ? RemoteLoveTheme.green : RemoteLoveTheme.amber)
                    }
                    .padding(.horizontal)
                    .remoteLoveAppear(active: hasAppeared, delay: 0.02)
                }

                NativeCard(title: "Today’s care", subtitle: store.overviewRecipientID == nil ? "Grouped by care profile" : "Live progress for this profile", icon: "checklist") {
                    if store.overviewRecipientID == nil {
                        ForEach(store.recipients) { recipient in
                            OverviewPersonTasksRow(recipient: recipient)
                            if recipient.id != store.recipients.last?.id {
                                Divider()
                            }
                        }
                    } else {
                        ProgressView(value: overviewTasks.isEmpty ? 0 : Double(completed) / Double(overviewTasks.count))
                            .tint(RemoteLoveTheme.green)
                        ForEach(overviewTasks.filter { $0.state != .done }.prefix(3)) { task in
                            Button {
                                store.navigate(to: .task(recipientID: task.recipientID, taskID: task.id))
                            } label: {
                                HStack {
                                    Text(task.title)
                                        .foregroundColor(.primary)
                                    Spacer()
                                    Text(task.scheduledAt, style: .time).foregroundColor(.secondary)
                                    Image(systemName: "chevron.right")
                                        .font(.caption.bold())
                                        .foregroundColor(.secondary)
                                }
                            }
                            .font(.subheadline)
                        }
                    }
                }
                .remoteLoveAppear(active: hasAppeared, delay: 0.07)
                .tutorialSpotlight(.overviewToday)

                if !lowMedicines.isEmpty {
                    NativeCard(title: "Medicine attention", subtitle: "Tap to open Planner for the correct profile", icon: "pills.fill", tint: RemoteLoveTheme.amber) {
                        ForEach(lowMedicines.prefix(3)) { medicine in
                            Button {
                                store.navigate(to: .medicine(recipientID: medicine.recipientID, medicineID: medicine.id))
                            } label: {
                                HStack {
                                    Text(medicine.name)
                                        .foregroundColor(.primary)
                                    Spacer()
                                    Text("\(medicine.daysRemaining) days left")
                                        .foregroundColor(RemoteLoveTheme.amber)
                                        .fontWeight(.semibold)
                                    Image(systemName: "chevron.right")
                                        .font(.caption.bold())
                                        .foregroundColor(.secondary)
                                }
                                .padding(10)
                                .background(RemoteLoveTheme.amber.opacity(0.10), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                            }
                            .font(.subheadline)
                            .buttonStyle(.plain)
                        }
                    }
                    .neonAttention(active: true, tint: RemoteLoveTheme.amber, cornerRadius: 20)
                    .remoteLoveAppear(active: hasAppeared, delay: 0.12)
                }

                if store.healthFeatureEnabled {
                    NativeCard(title: "Health condition", subtitle: store.overviewRecipientID == nil ? "Latest readings by care profile" : "Latest recorded readings, with simple status labels", icon: "heart.text.square") {
                        if store.overviewRecipientID == nil {
                            ForEach(store.recipients) { recipient in
                                OverviewPersonHealthRow(recipient: recipient)
                                if recipient.id != store.recipients.last?.id {
                                    Divider()
                                }
                            }
                        } else {
                            ForEach(latestHealthRows()) { row in
                                let status = row.category.status(for: row.log.value, age: store.selectedRecipient.age)
                                Button {
                                    store.navigate(to: .health(recipientID: row.log.recipientID, category: row.category.rawValue))
                                } label: {
                                    HStack(alignment: .center, spacing: 10) {
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(row.category.label)
                                                .foregroundColor(.primary)
                                            Text(status.summary)
                                                .font(.caption2)
                                                .foregroundColor(.secondary)
                                        }
                                        Spacer()
                                        HealthStatusCapsule(status: status)
                                        Text("\(row.log.value.formatted()) \(row.category.unit)").bold()
                                            .foregroundColor(.primary)
                                        Image(systemName: "chevron.right")
                                            .font(.caption.bold())
                                            .foregroundColor(.secondary)
                                    }
                                    .padding(10)
                                    .background(status == .needsAttention ? RemoteLoveTheme.coral.opacity(0.09) : Color.clear, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                                }
                                .font(.subheadline)
                                .buttonStyle(.plain)
                                .neonAttention(active: status == .needsAttention, tint: RemoteLoveTheme.coral, cornerRadius: 12)
                            }
                        }
                    }
                    .remoteLoveAppear(active: hasAppeared, delay: 0.17)
                    .tutorialSpotlight(.overviewHealth)
                }

                NativeCard(title: "Care circle", subtitle: "People currently in the loop", icon: "person.3.fill") {
                    let overviewMembers = store.members.filter { member in member.active && overviewRecipients.contains(where: { $0.id == member.recipientID }) }
                    if overviewMembers.isEmpty {
                        Text("No active memberships for this view.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    } else {
                        ForEach(overviewMembers.prefix(3)) { member in
                            Button {
                                store.navigate(to: .member(recipientID: member.recipientID ?? store.selectedRecipientID, membershipID: member.id))
                            } label: {
                                HStack {
                                    Text(member.name)
                                        .foregroundColor(.primary)
                                    Spacer()
                                    Text(member.role)
                                        .foregroundColor(.secondary)
                                    Image(systemName: "chevron.right")
                                        .font(.caption.bold())
                                        .foregroundColor(.secondary)
                                }
                            }
                            .font(.subheadline)
                        }
                    }
                }
                .remoteLoveAppear(active: hasAppeared, delay: 0.22)
                .tutorialSpotlight(.overviewCircle)
                }
                .padding(.bottom, 22)
            }
            .tutorialScrollReceiver(tutorialProxy)
            .destinationScrollReceiver(tutorialProxy)
        }
        .background(Color(uiColor: .systemGroupedBackground))
        .navigationBarHidden(true)
        .sheet(isPresented: $showAddCareProfile) {
            AddCareProfileView()
        }
        .sheet(item: $editingFirstTask) { task in
            TaskEditorView(task: task)
        }
        .sheet(item: $editingFirstMedicine) { medicine in
            MedicineEditorView(medicine: medicine)
        }
        .sheet(isPresented: $showHealthLogger) {
            HealthLoggerView(initialCategory: .bloodPressure)
        }
        .onAppear {
            hasAppeared = false
            withAnimation(.easeOut(duration: 0.32)) {
                hasAppeared = true
            }
        }
        .animation(.easeInOut(duration: 0.22), value: store.overviewRecipientID)
    }

    private struct LatestHealthRow: Identifiable {
        let category: HealthCategory
        let log: HealthLog
        var id: UUID { log.id }
    }

    private func latestHealthRows() -> [LatestHealthRow] {
        var output: [LatestHealthRow] = []
        for category in HealthCategory.allCases {
            if let latest = store.healthLogs
                .filter({ log in log.category == category && overviewRecipients.contains(where: { recipient in recipient.id == log.recipientID }) })
                .sorted(by: { $0.recordedAt > $1.recordedAt }).first {
                output.append(LatestHealthRow(category: category, log: latest))
            }
        }
        return Array(output.prefix(4))
    }

    private func newFirstTask() -> CareTask {
        let scheduledAt = Calendar.current.date(bySettingHour: 9, minute: 0, second: 0, of: Date()) ?? Date()
        return CareTask(
            id: UUID(),
            recipientID: store.selectedRecipientID,
            title: "",
            instructions: "",
            scheduledAt: scheduledAt,
            frequency: "Every day",
            requiresPhoto: false,
            state: .pending,
            notifiedAt: nil,
            medicineID: nil
        )
    }

    private func newFirstMedicine() -> Medicine {
        Medicine(
            id: UUID(),
            recipientID: store.selectedRecipientID,
            name: "",
            purpose: "",
            instructions: "",
            currentSupply: 30,
            dose: 1,
            unit: "tablets",
            timesDaily: 1,
            intervalDays: 1,
            attentionDays: 7,
            active: true,
            firstTime: Date()
        )
    }
}

private struct FirstCareStepsCard: View {
    let needsTask: Bool
    let needsMedicine: Bool
    let needsHealth: Bool
    let onAddTask: () -> Void
    let onAddMedicine: () -> Void
    let onLogHealth: () -> Void

    var body: some View {
        NativeCard(
            title: "Finish setting up this profile",
            subtitle: "Add the first few items so the care circle has something useful to follow.",
            icon: "sparkles",
            tint: RemoteLoveTheme.coral
        ) {
            VStack(spacing: 10) {
                if needsTask {
                    firstStepButton(title: "Add first task", icon: "checklist", action: onAddTask)
                }
                if needsMedicine {
                    firstStepButton(title: "Add medicine", icon: "pills.fill", action: onAddMedicine)
                }
                if needsHealth {
                    firstStepButton(title: "Log first health reading", icon: "heart.text.square.fill", action: onLogHealth)
                }
            }
        }
    }

    private func firstStepButton(title: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: icon)
                .font(.subheadline.weight(.semibold))
                .frame(maxWidth: .infinity, minHeight: 44)
        }
        .buttonStyle(SecondaryButtonStyle())
    }
}

private struct OverviewPrioritySummaryCard: View {
    let recipientCount: Int
    let openTaskCount: Int
    let lowMedicineCount: Int
    let healthAttentionCount: Int

    private var attentionCount: Int {
        openTaskCount + lowMedicineCount + healthAttentionCount
    }

    private var title: String {
        attentionCount == 0 ? "Everything looks settled" : "\(attentionCount) item\(attentionCount == 1 ? "" : "s") to check"
    }

    private var detail: String {
        if attentionCount == 0 {
            return recipientCount == 1 ? "This care profile has no open tasks or alerts right now." : "All visible care profiles have no open tasks or alerts right now."
        }

        var pieces: [String] = []
        if openTaskCount > 0 {
            pieces.append("\(openTaskCount) open task\(openTaskCount == 1 ? "" : "s")")
        }
        if lowMedicineCount > 0 {
            pieces.append("\(lowMedicineCount) medicine supply alert\(lowMedicineCount == 1 ? "" : "s")")
        }
        if healthAttentionCount > 0 {
            pieces.append("\(healthAttentionCount) health reading\(healthAttentionCount == 1 ? "" : "s") needing attention")
        }
        return pieces.joined(separator: " · ")
    }

    private var tint: Color {
        attentionCount == 0 ? RemoteLoveTheme.green : RemoteLoveTheme.amber
    }

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: attentionCount == 0 ? "checkmark.seal.fill" : "exclamationmark.circle.fill")
                .font(.title3.weight(.semibold))
                .foregroundColor(tint)
                .frame(width: 44, height: 44)
                .background(tint.opacity(0.13), in: Circle())
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                Text(detail)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .padding(16)
        .remoteLoveSectionSurface(cornerRadius: 20)
        .accessibilityElement(children: .combine)
    }
}

struct OverviewPersonBreakdownRow: View {
    @EnvironmentObject private var store: RemoteLoveStore
    let recipient: CareRecipient

    private var tasks: [CareTask] {
        store.tasks(on: Date(), recipientID: recipient.id)
    }

    private var completedTasks: Int {
        tasks.filter { $0.state == .done }.count
    }

    private var lowMedicines: [Medicine] {
        store.medicines.filter { medicine in
            medicine.recipientID == recipient.id && medicine.active && medicine.daysRemaining <= medicine.attentionDays
        }
    }

    private var activeMembers: Int {
        store.members.filter { $0.recipientID == recipient.id && $0.active }.count
    }

    private var latestHealthLogs: Int {
        let categories = Set(store.healthLogs.filter { $0.recipientID == recipient.id }.map(\.category))
        return categories.count
    }

    private var headlineStatus: (String, Color) {
        if !lowMedicines.isEmpty {
            return ("Needs medicine review", RemoteLoveTheme.amber)
        }
        if !tasks.isEmpty && completedTasks < tasks.count {
            return ("Care in progress", RemoteLoveTheme.green)
        }
        if tasks.isEmpty && latestHealthLogs == 0 {
            return ("Set up profile", .secondary)
        }
        return ("Looking settled", RemoteLoveTheme.green)
    }

    var body: some View {
        Button {
            store.overviewRecipientID = recipient.id
            store.selectedRecipientID = recipient.id
        } label: {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(recipient.label) · \(recipient.name)")
                            .font(.headline)
                            .foregroundColor(.primary)
                        Text("Updated \(recipient.lastUpdated, style: .relative)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    Text(headlineStatus.0)
                        .font(.caption2.weight(.bold))
                        .foregroundColor(headlineStatus.1)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 5)
                        .background(headlineStatus.1.opacity(0.14), in: Capsule())
                    Image(systemName: "chevron.right")
                        .font(.caption.bold())
                        .foregroundColor(.secondary)
                }

                ProgressView(value: tasks.isEmpty ? 0 : Double(completedTasks) / Double(tasks.count))
                    .tint(RemoteLoveTheme.green)

                VStack(spacing: 8) {
                    overviewSummaryRow(
                        icon: "checkmark.circle.fill",
                        title: "Tasks completed",
                        detail: tasks.isEmpty ? "No tasks planned today" : "\(completedTasks) of \(tasks.count) planned tasks are done today"
                    )
                    overviewSummaryRow(
                        icon: "pills.fill",
                        title: "Medicines needing attention",
                        detail: lowMedicines.isEmpty ? "No low-supply medicine alerts" : "\(lowMedicines.count) medicine\(lowMedicines.count == 1 ? "" : "s") need supply review"
                    )
                    overviewSummaryRow(
                        icon: "heart.text.square.fill",
                        title: "Health readings tracked",
                        detail: latestHealthLogs == 0 ? "No health readings logged yet" : "\(latestHealthLogs) reading type\(latestHealthLogs == 1 ? "" : "s") have recent history"
                    )
                    overviewSummaryRow(
                        icon: "person.3.fill",
                        title: "People in care circle",
                        detail: "\(activeMembers) active member\(activeMembers == 1 ? "" : "s") linked to this profile"
                    )
                }
            }
            .padding(.vertical, 6)
        }
        .buttonStyle(.plain)
    }

    private func overviewSummaryRow(icon: String, title: String, detail: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon)
                .foregroundColor(RemoteLoveTheme.green)
                .frame(width: 22)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(.primary)
                Text(detail)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Spacer()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

struct OverviewPersonTasksRow: View {
    @EnvironmentObject private var store: RemoteLoveStore
    let recipient: CareRecipient

    private var tasks: [CareTask] {
        store.tasks(on: Date(), recipientID: recipient.id)
    }

    private var incompleteTasks: [CareTask] {
        tasks.filter { $0.state != .done }
    }

    private var completedTasks: Int {
        tasks.filter { $0.state == .done }.count
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(recipient.label)’s tasks")
                        .font(.headline)
                    Text(tasks.isEmpty ? "No tasks planned" : "\(completedTasks) completed, \(incompleteTasks.count) still open")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
                Text("\(completedTasks)/\(tasks.count)")
                    .font(.subheadline.bold())
                    .foregroundColor(RemoteLoveTheme.green)
            }

            ProgressView(value: tasks.isEmpty ? 0 : Double(completedTasks) / Double(tasks.count))
                .tint(RemoteLoveTheme.green)

            if incompleteTasks.isEmpty {
                Text(tasks.isEmpty ? "Nothing has been added for this care profile yet." : "All tasks are complete.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } else {
                ForEach(incompleteTasks.prefix(2)) { task in
                    Button {
                        store.navigate(to: .task(recipientID: task.recipientID, taskID: task.id))
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(task.title)
                                    .foregroundColor(.primary)
                                Text(task.frequency)
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            Text(task.scheduledAt, style: .time)
                                .font(.caption.bold())
                                .foregroundColor(.secondary)
                            Image(systemName: "chevron.right")
                                .font(.caption.bold())
                                .foregroundColor(.secondary)
                        }
                    }
                    .font(.subheadline)
                }
            }
        }
        .padding(.vertical, 6)
    }
}

struct OverviewPersonHealthRow: View {
    @EnvironmentObject private var store: RemoteLoveStore
    let recipient: CareRecipient

    private var latestLogs: [(HealthCategory, HealthLog)] {
        HealthCategory.allCases.compactMap { category in
            guard let latest = store.healthLogs
                .filter({ $0.recipientID == recipient.id && $0.category == category })
                .sorted(by: { $0.recordedAt > $1.recordedAt })
                .first
            else { return nil }
            return (category, latest)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(recipient.label)’s health")
                        .font(.headline)
                    Text(latestLogs.isEmpty ? "No readings logged yet" : "\(latestLogs.count) categories with recent readings")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
            }

            if latestLogs.isEmpty {
                Text("Add health readings from the Health tab to see trends here.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } else {
                ForEach(latestLogs.prefix(3), id: \.1.id) { category, log in
                    let status = category.status(for: log.value, age: recipient.age)
                    Button {
                        store.navigate(to: .health(recipientID: recipient.id, category: category.rawValue))
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(category.label)
                                    .foregroundColor(.primary)
                                Text(log.recordedAt, style: .relative)
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            HealthStatusCapsule(status: status)
                            Text("\(log.value.formatted()) \(category.unit)")
                                .font(.subheadline.bold())
                                .foregroundColor(.primary)
                            Image(systemName: "chevron.right")
                                .font(.caption.bold())
                                .foregroundColor(.secondary)
                        }
                        .padding(10)
                        .background(status == .needsAttention ? RemoteLoveTheme.coral.opacity(0.09) : Color.clear, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                    .font(.subheadline)
                    .buttonStyle(.plain)
                    .neonAttention(active: status == .needsAttention, tint: RemoteLoveTheme.coral, cornerRadius: 12)
                }
            }
        }
        .padding(.vertical, 6)
    }
}

struct HelperHomeView: View {
    @EnvironmentObject private var store: RemoteLoveStore
    @State private var confirmEmergency = false
    @State private var showCompletionCelebration = false
    @State private var celebratedTaskSignature: String?
    @State private var calendarExpanded = false
    @State private var visibleMonth = Calendar.current.date(from: Calendar.current.dateComponents([.year, .month], from: Date())) ?? Date()

    private var nextOpenTaskID: UUID? {
        guard store.isSelectedTaskDateToday else { return nil }
        return store.selectedTasks.first(where: { $0.state != .done && $0.state != .paused })?.id
    }

    var body: some View {
        ScrollViewReader { tutorialProxy in
            ScrollView {
                VStack(spacing: 16) {
                RecipientHeader()
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("TODAY’S CARE").font(.caption.bold()).foregroundColor(RemoteLoveTheme.green)
                        Text("Hello, \(store.currentUserName)").font(.largeTitle.bold())
                        Text("Just what you need to do for \(store.selectedRecipient.label).")
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    if !store.isSelectedTaskDateToday {
                        Button {
                            withAnimation(.easeInOut(duration: 0.22)) {
                                store.selectedTaskDate = Calendar.current.startOfDay(for: Date())
                            }
                        } label: {
                            Label("Today", systemImage: "calendar.badge.clock")
                                .font(.subheadline.weight(.semibold))
                        }
                        .buttonStyle(.bordered)
                        .accessibilityLabel("Jump to today")
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal)
                .tutorialSpotlight(.helperHeader)

                CareCalendarPanel(
                    isExpanded: $calendarExpanded,
                    visibleMonth: $visibleMonth,
                    onAddTask: nil
                )
                .tutorialSpotlight(.helperTasks)

                TaskUndoBanner()

                if !store.isSelectedTaskDateToday {
                    Label("Preview only. Helpers can complete tasks on the scheduled day.", systemImage: "eye")
                        .font(.caption.weight(.semibold))
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(12)
                        .remoteLoveSectionSurface(cornerRadius: 14)
                        .padding(.horizontal)
                }

                LazyVStack(spacing: 12) {
                    if store.selectedTasks.isEmpty {
                        EmptyStateCard(icon: "checklist", title: "No tasks planned", message: "There are no care tasks for this selected day.")
                            .padding(.horizontal)
                            .transition(.opacity.combined(with: .move(edge: .bottom)))
                    } else {
                        ForEach(store.selectedTasks) { task in
                            TaskRow(
                                task: task,
                                allowsCompletion: store.isSelectedTaskDateToday,
                                isNextAction: task.id == nextOpenTaskID
                            )
                                .id(DestinationScrollTarget.task(task.id))
                                .transition(.opacity.combined(with: .move(edge: .bottom)))
                        }
                    }
                }
                .tutorialSpotlight(.helperTasks)

                Button(role: .destructive) {
                    confirmEmergency = true
                } label: {
                    Label("Emergency alert family", systemImage: "exclamationmark.triangle.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(SecondaryButtonStyle())
                .padding(.horizontal)
                .tutorialSpotlight(.helperEmergency)
                }
                .padding(.bottom, 24)
                .animation(.easeInOut(duration: 0.22), value: store.selectedTaskDate)
                .animation(.spring(response: 0.28, dampingFraction: 0.86), value: store.selectedTasks)
            }
            .tutorialScrollReceiver(tutorialProxy)
            .destinationScrollReceiver(tutorialProxy)
        }
        .overlay {
            if showCompletionCelebration {
                TaskCompletionCelebrationView()
                    .transition(.opacity.combined(with: .scale(scale: 0.92)))
                    .zIndex(1)
            }
        }
        .background(Color(uiColor: .systemGroupedBackground))
        .navigationBarHidden(true)
        .safeAreaInset(edge: .top) {
            TaskCompletionProgressBar()
                .tutorialSpotlight(store.currentRole == .helper ? .helperProgress : .careProgress)
        }
        .onAppear(perform: checkTaskCompletionCelebration)
        .onChange(of: store.selectedTasks) {
            checkTaskCompletionCelebration()
        }
        .onChange(of: store.selectedTaskDate) {
            showCompletionCelebration = false
            celebratedTaskSignature = nil
            visibleMonth = startOfMonth(containing: store.selectedTaskDate)
            checkTaskCompletionCelebration()
        }
        .alert("Alert the family?", isPresented: $confirmEmergency) {
            Button("Cancel", role: .cancel) { }
            Button("Send emergency alert", role: .destructive) {
                store.triggerEmergency(message: "\(store.currentUserName) requested urgent family assistance for \(store.selectedRecipient.label).")
            }
        } message: {
            Text("Use this only when \(store.selectedRecipient.label) needs urgent family attention.")
        }
    }

    private func checkTaskCompletionCelebration() {
        guard store.isSelectedTaskDateToday else { return }
        let tasks = store.selectedTasks
        guard tasks.isEmpty == false, tasks.allSatisfy({ $0.state == .done }) else {
            showCompletionCelebration = false
            celebratedTaskSignature = nil
            return
        }

        let signature = tasks
            .map { $0.id.uuidString }
            .sorted()
            .joined(separator: "-")

        guard celebratedTaskSignature != signature else { return }
        celebratedTaskSignature = signature

        withAnimation(.spring(response: 0.36, dampingFraction: 0.78)) {
            showCompletionCelebration = true
        }

        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 3_200_000_000)
            withAnimation(.easeInOut(duration: 0.22)) {
                showCompletionCelebration = false
            }
        }
    }

    private func startOfMonth(containing date: Date) -> Date {
        Calendar.current.date(from: Calendar.current.dateComponents([.year, .month], from: date)) ?? date
    }
}

struct CareView: View {
    @EnvironmentObject private var store: RemoteLoveStore
    @State private var editingTask: CareTask?
    @State private var showManage = false
    @State private var calendarExpanded = false
    @State private var visibleMonth = Calendar.current.date(from: Calendar.current.dateComponents([.year, .month], from: Date())) ?? Date()
    @State private var showCompletionCelebration = false
    @State private var celebratedTaskSignature: String?

    private var nextOpenTaskID: UUID? {
        guard store.isSelectedTaskDateToday else { return nil }
        return store.selectedTasks.first(where: { $0.state != .done && $0.state != .paused })?.id
    }

    var body: some View {
        ScrollViewReader { tutorialProxy in
            ScrollView {
                LazyVStack(spacing: 14) {
                RecipientHeader()
                HStack {
                    VStack(alignment: .leading) {
                        Text(store.currentRole.isFamilyExperience ? "\(store.selectedRecipient.label)’s routine" : "Today’s tasks")
                            .font(.largeTitle.bold())
                        Text("Updated \(store.selectedRecipient.lastUpdated, style: .relative)")
                            .font(.caption).foregroundColor(.secondary)
                    }
                    Spacer()
                    if !store.isSelectedTaskDateToday {
                        Button {
                            withAnimation(.easeInOut(duration: 0.22)) {
                                store.selectedTaskDate = Calendar.current.startOfDay(for: Date())
                            }
                        } label: {
                            Label("Today", systemImage: "calendar.badge.clock")
                                .font(.subheadline.weight(.semibold))
                        }
                        .buttonStyle(.bordered)
                        .accessibilityLabel("Jump to today")
                    }
                    if store.canEditCareRecords {
                        VStack(spacing: 8) {
                            Button {
                                editingTask = newTask()
                            } label: {
                                Label("Add task", systemImage: "plus.circle.fill")
                                    .font(.subheadline.weight(.semibold))
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.borderedProminent)

                            Button {
                                showManage = true
                            } label: {
                                Label("Modify", systemImage: "slider.horizontal.3")
                                    .font(.subheadline.weight(.semibold))
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.bordered)
                        }
                        .frame(width: 132)
                    }
                }
                .padding(.horizontal)
                .tutorialSpotlight(.careHeader)

                CareCalendarPanel(
                    isExpanded: $calendarExpanded,
                    visibleMonth: $visibleMonth,
                    onAddTask: nil
                )
                .tutorialSpotlight(.careCalendar)

                TaskUndoBanner()
                    .tutorialSpotlight(.careUndo)

                VStack(spacing: 12) {
                    if store.selectedTasks.isEmpty {
                        ActionEmptyStateCard(
                            icon: "checklist",
                            title: "No tasks planned",
                            message: store.canEditCareRecords ? "Use Add task at the top to start this day’s routine." : "There are no tasks for this selected day.",
                            actionTitle: nil,
                            action: nil
                        )
                        .padding(.horizontal)
                        .transition(.opacity.combined(with: .move(edge: .bottom)))
                    } else {
                        ForEach(store.selectedTasks) { task in
                            TaskRow(
                                task: task,
                                allowsCompletion: store.isSelectedTaskDateToday && store.canCompleteCareTasks,
                                onEdit: store.canEditCareRecords ? { editingTask = task } : nil,
                                isNextAction: task.id == nextOpenTaskID
                            )
                            .id(DestinationScrollTarget.task(task.id))
                            .transition(.opacity.combined(with: .move(edge: .bottom)))
                        }
                    }
                }
                .tutorialSpotlight(.careTasks)
                }
                .padding(.bottom, 24)
                .animation(.easeInOut(duration: 0.22), value: store.selectedTaskDate)
                .animation(.spring(response: 0.28, dampingFraction: 0.86), value: store.selectedTasks)
            }
            .tutorialScrollReceiver(tutorialProxy)
            .destinationScrollReceiver(tutorialProxy)
        }
        .overlay {
            if showCompletionCelebration {
                TaskCompletionCelebrationView()
                    .transition(.opacity.combined(with: .scale(scale: 0.92)))
                    .zIndex(1)
            }
        }
        .background(Color(uiColor: .systemGroupedBackground))
        .navigationBarHidden(true)
        .safeAreaInset(edge: .top) {
            TaskCompletionProgressBar()
                .tutorialSpotlight(.careProgress)
        }
        .sheet(item: $editingTask) { TaskEditorView(task: $0) }
        .sheet(isPresented: $showManage) { TaskManagementView() }
        .onAppear {
            openPendingTaskDestination()
            checkTaskCompletionCelebration()
        }
        .onChange(of: store.pendingDestination) {
            openPendingTaskDestination()
        }
        .onChange(of: store.selectedTasks) {
            checkTaskCompletionCelebration()
        }
        .onChange(of: store.selectedTaskDate) {
            showCompletionCelebration = false
            celebratedTaskSignature = nil
            checkTaskCompletionCelebration()
        }
    }

    private func newTask() -> CareTask {
        let selectedDay = Calendar.current.startOfDay(for: store.selectedTaskDate)
        let nowComponents = Calendar.current.dateComponents([.hour, .minute], from: Date())
        let scheduledAt = Calendar.current.date(bySettingHour: nowComponents.hour ?? 9, minute: nowComponents.minute ?? 0, second: 0, of: selectedDay) ?? store.selectedTaskDate
        return CareTask(id: UUID(), recipientID: store.selectedRecipientID, title: "", instructions: "", scheduledAt: scheduledAt, frequency: "Every day", requiresPhoto: false, state: .pending, notifiedAt: nil, medicineID: nil)
    }

    private func openPendingTaskDestination() {
        guard case let .task(recipientID, taskID) = store.pendingDestination else { return }
        store.selectedRecipientID = recipientID
        if let task = store.tasks.first(where: { $0.id == taskID }) {
            store.selectedTaskDate = task.scheduledAt
            visibleMonth = startOfMonth(containing: task.scheduledAt)
        }
        store.pendingDestination = nil
        postDestinationScroll(DestinationScrollTarget.task(taskID))
    }

    private func startOfMonth(containing date: Date) -> Date {
        Calendar.current.date(from: Calendar.current.dateComponents([.year, .month], from: date)) ?? date
    }

    private func checkTaskCompletionCelebration() {
        guard store.isSelectedTaskDateToday, store.canCompleteCareTasks else { return }
        let tasks = store.selectedTasks
        guard tasks.isEmpty == false, tasks.allSatisfy({ $0.state == .done }) else {
            showCompletionCelebration = false
            celebratedTaskSignature = nil
            return
        }

        let signature = tasks
            .map { $0.id.uuidString }
            .sorted()
            .joined(separator: "-")

        guard celebratedTaskSignature != signature else { return }
        celebratedTaskSignature = signature

        withAnimation(.spring(response: 0.36, dampingFraction: 0.78)) {
            showCompletionCelebration = true
        }

        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 3_200_000_000)
            withAnimation(.easeInOut(duration: 0.22)) {
                showCompletionCelebration = false
            }
        }
    }
}

struct TaskCompletionProgressBar: View {
    @EnvironmentObject private var store: RemoteLoveStore

    private var doneCount: Int {
        store.selectedTasks.filter { $0.state == .done }.count
    }

    private var totalCount: Int {
        store.selectedTasks.count
    }

    private var progress: Double {
        guard totalCount > 0 else { return 0 }
        return Double(doneCount) / Double(totalCount)
    }

    private var dateTitle: String {
        if store.isSelectedTaskDateToday {
            return "Today"
        }
        return store.selectedTaskDate.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day())
    }

    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 10) {
                Image(systemName: progress >= 1 && totalCount > 0 ? "checkmark.seal.fill" : "checklist")
                    .foregroundColor(progress >= 1 && totalCount > 0 ? RemoteLoveTheme.green : RemoteLoveTheme.amber)
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 2) {
                    Text("\(dateTitle)'s tasks")
                        .font(.caption.weight(.semibold))
                        .foregroundColor(.secondary)
                    Text(totalCount == 0 ? "No tasks planned" : "\(doneCount) of \(totalCount) completed")
                        .font(.subheadline.weight(.bold))
                        .foregroundColor(.primary)
                }

                Spacer()

                Text(totalCount == 0 ? "0%" : "\(Int((progress * 100).rounded()))%")
                    .font(.caption.weight(.bold))
                    .foregroundColor(RemoteLoveTheme.green)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 5)
                    .background(RemoteLoveTheme.green.opacity(0.12), in: Capsule())
            }

            ProgressView(value: progress)
                .tint(progress >= 1 && totalCount > 0 ? RemoteLoveTheme.green : RemoteLoveTheme.amber)
                .animation(.spring(response: 0.34, dampingFraction: 0.78), value: progress)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.secondary.opacity(0.12), lineWidth: 1)
        }
        .padding(.horizontal)
        .padding(.top, 6)
        .padding(.bottom, 4)
        .background(.ultraThinMaterial)
        .animation(.spring(response: 0.28, dampingFraction: 0.82), value: doneCount)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(totalCount == 0 ? "\(dateTitle), no tasks planned" : "\(dateTitle), \(doneCount) of \(totalCount) tasks completed")
    }
}

struct RoutineDateStrip: View {
    @EnvironmentObject private var store: RemoteLoveStore
    var showsSurface = true
    private let calendar = Calendar.current

    var body: some View {
        let strip = ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(store.routineDates, id: \.self) { date in
                        let tasks = store.tasks(on: date)
                        let done = tasks.filter { $0.state == .done }.count
                        let selected = calendar.isDate(date, inSameDayAs: store.selectedTaskDate)

                        Button {
                            withAnimation(.easeInOut(duration: 0.28)) {
                                store.selectedTaskDate = date
                                proxy.scrollTo(calendar.startOfDay(for: date), anchor: .leading)
                            }
                        } label: {
                            VStack(spacing: 6) {
                                Text(dayTitle(for: date))
                                    .font(.caption.weight(.semibold))
                                Text(date.formatted(.dateTime.day()))
                                    .font(.title3.weight(.bold))
                                Text(tasks.isEmpty ? "No tasks" : "\(done)/\(tasks.count) done")
                                    .font(.caption2.weight(.medium))
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.8)
                            }
                            .frame(width: 86)
                            .frame(minHeight: 82)
                            .foregroundColor(selected ? RemoteLoveTheme.onAccent : .primary)
                            .background(
                                selected ? RemoteLoveTheme.green : Color(uiColor: .secondarySystemGroupedBackground),
                                in: RoundedRectangle(cornerRadius: 16, style: .continuous)
                            )
                            .overlay {
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .stroke(selected ? RemoteLoveTheme.green : Color.secondary.opacity(0.18), lineWidth: 1)
                            }
                        }
                        .buttonStyle(.plain)
                        .id(calendar.startOfDay(for: date))
                        .accessibilityLabel(accessibilityLabel(for: date, tasks: tasks, done: done))
                    }
                }
                .padding(.horizontal)
            }
            .onAppear {
                proxy.scrollTo(calendar.startOfDay(for: store.selectedTaskDate), anchor: .leading)
            }
            .onChange(of: store.selectedTaskDate) { _, date in
                withAnimation(.easeInOut(duration: 0.32)) {
                    proxy.scrollTo(calendar.startOfDay(for: date), anchor: .leading)
                }
            }
        }

        if showsSurface {
            strip
                .padding(.vertical, 10)
                .remoteLoveSectionSurface(cornerRadius: 22)
                .padding(.horizontal)
                .animation(.spring(response: 0.28, dampingFraction: 0.82), value: store.selectedTaskDate)
        } else {
            strip
                .padding(.vertical, 2)
                .animation(.spring(response: 0.28, dampingFraction: 0.82), value: store.selectedTaskDate)
        }
    }

    private func dayTitle(for date: Date) -> String {
        if calendar.isDateInToday(date) { return "Today" }
        if calendar.isDateInTomorrow(date) { return "Tomorrow" }
        return date.formatted(.dateTime.weekday(.abbreviated))
    }

    private func accessibilityLabel(for date: Date, tasks: [CareTask], done: Int) -> String {
        let dateText = date.formatted(.dateTime.weekday(.wide).month(.wide).day())
        return tasks.isEmpty ? "\(dateText), no tasks" : "\(dateText), \(done) of \(tasks.count) tasks done"
    }
}

struct CareCalendarPanel: View {
    @EnvironmentObject private var store: RemoteLoveStore
    @Binding var isExpanded: Bool
    @Binding var visibleMonth: Date
    let onAddTask: (() -> Void)?

    private let calendar = Calendar.current

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("ROUTINE CALENDAR")
                        .font(.caption2.weight(.bold))
                        .foregroundColor(RemoteLoveTheme.green)
                    Text(isExpanded ? visibleMonth.formatted(.dateTime.month(.wide).year()) : selectedDateTitle)
                        .font(.headline)
                }

                Spacer()

                if let onAddTask {
                    Button {
                        onAddTask()
                    } label: {
                        Label("Add task", systemImage: "plus.circle.fill")
                            .labelStyle(.iconOnly)
                            .font(.title3)
                    }
                    .accessibilityLabel("Add task for \(selectedDateTitle)")
                }

                Button {
                    withAnimation(.spring(response: 0.30, dampingFraction: 0.84)) {
                        isExpanded.toggle()
                        if isExpanded {
                            visibleMonth = startOfMonth(containing: store.selectedTaskDate)
                        }
                    }
                } label: {
                    Label(isExpanded ? "Collapse calendar" : "Expand calendar", systemImage: isExpanded ? "chevron.up.circle.fill" : "chevron.down.circle.fill")
                        .labelStyle(.iconOnly)
                        .font(.title3)
                }
                .accessibilityLabel(isExpanded ? "Collapse calendar" : "Expand calendar")
            }
            .padding(.horizontal)

            if isExpanded {
                CareMonthCalendarView(visibleMonth: $visibleMonth)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            } else {
                RoutineDateStrip(showsSurface: false)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }

            HStack(spacing: 14) {
                calendarLegend(color: RemoteLoveTheme.green, title: "All done")
                calendarLegend(color: RemoteLoveTheme.amber, title: "Open")
                calendarLegend(color: .secondary, title: "No tasks")
                Spacer()
            }
            .padding(.horizontal)
        }
        .padding(.vertical, 12)
        .remoteLoveSectionSurface(cornerRadius: 22)
        .padding(.horizontal)
        .onChange(of: store.selectedTaskDate) { _, date in
            if !calendar.isDate(date, equalTo: visibleMonth, toGranularity: .month) {
                visibleMonth = startOfMonth(containing: date)
            }
        }
    }

    private var selectedDateTitle: String {
        if calendar.isDateInToday(store.selectedTaskDate) {
            return "Today · " + store.selectedTaskDate.formatted(.dateTime.month(.abbreviated).day())
        }
        return store.selectedTaskDate.formatted(.dateTime.weekday(.wide).month(.abbreviated).day())
    }

    private func calendarLegend(color: Color, title: String) -> some View {
        HStack(spacing: 6) {
            Circle()
                .fill(color)
                .frame(width: 7, height: 7)
            Text(title)
                .font(.caption2.weight(.semibold))
                .foregroundColor(.secondary)
        }
    }

    private func startOfMonth(containing date: Date) -> Date {
        calendar.date(from: calendar.dateComponents([.year, .month], from: date)) ?? date
    }
}

private struct CareMonthCalendarView: View {
    @EnvironmentObject private var store: RemoteLoveStore
    @Binding var visibleMonth: Date

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 5), count: 7)

    private var calendar: Calendar {
        var value = Calendar.current
        value.firstWeekday = 2
        return value
    }

    private var weekdayLabels: [String] {
        ["M", "T", "W", "T", "F", "S", "S"]
    }

    private var monthDates: [Date?] {
        guard let dayRange = calendar.range(of: .day, in: .month, for: visibleMonth),
              let firstDay = calendar.date(from: calendar.dateComponents([.year, .month], from: visibleMonth)) else {
            return []
        }

        let weekday = calendar.component(.weekday, from: firstDay)
        let leadingSpaces = (weekday - calendar.firstWeekday + 7) % 7
        var dates = Array<Date?>(repeating: nil, count: leadingSpaces)
        dates.append(contentsOf: dayRange.compactMap { day in
            calendar.date(byAdding: .day, value: day - 1, to: firstDay)
        })
        return dates
    }

    var body: some View {
        VStack(spacing: 14) {
            HStack {
                Button {
                    changeMonth(by: -1)
                } label: {
                    Image(systemName: "chevron.left")
                        .frame(width: 36, height: 36)
                        .background(Color.secondary.opacity(0.10), in: Circle())
                }

                Spacer()

                Button {
                    let today = calendar.startOfDay(for: Date())
                    withAnimation(.easeInOut(duration: 0.26)) {
                        store.selectedTaskDate = today
                        visibleMonth = startOfMonth(containing: today)
                    }
                } label: {
                    Label("Today", systemImage: "calendar.badge.clock")
                        .font(.caption.weight(.semibold))
                }
                .buttonStyle(.bordered)

                Spacer()

                Button {
                    changeMonth(by: 1)
                } label: {
                    Image(systemName: "chevron.right")
                        .frame(width: 36, height: 36)
                        .background(Color.secondary.opacity(0.10), in: Circle())
                }
            }

            LazyVGrid(columns: columns, spacing: 8) {
                ForEach(weekdayLabels.indices, id: \.self) { index in
                    Text(weekdayLabels[index])
                        .font(.caption2.weight(.bold))
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity)
                }

                ForEach(monthDates.indices, id: \.self) { index in
                    if let date = monthDates[index] {
                        calendarDay(date)
                    } else {
                        Color.clear
                            .frame(height: 58)
                    }
                }
            }
        }
        .padding(.horizontal)
    }

    private func calendarDay(_ date: Date) -> some View {
        let dayTasks = store.tasks(on: date)
        let done = dayTasks.filter { $0.state == .done }.count
        let selected = calendar.isDate(date, inSameDayAs: store.selectedTaskDate)
        let today = calendar.isDateInToday(date)
        let tint = dayTint(total: dayTasks.count, done: done)

        return Button {
            withAnimation(.easeInOut(duration: 0.22)) {
                store.selectedTaskDate = calendar.startOfDay(for: date)
            }
        } label: {
            VStack(spacing: 5) {
                Text(String(calendar.component(.day, from: date)))
                    .font(.subheadline.weight(selected ? .bold : .semibold))

                if dayTasks.isEmpty {
                    Circle()
                        .fill(Color.secondary.opacity(0.35))
                        .frame(width: 5, height: 5)
                } else {
                    Text("\(done)/\(dayTasks.count)")
                        .font(.caption2.weight(.bold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                        .foregroundColor(selected ? RemoteLoveTheme.onAccent : tint)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 58)
            .foregroundColor(selected ? RemoteLoveTheme.onAccent : .primary)
            .background(selected ? RemoteLoveTheme.green : Color(uiColor: .tertiarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(today && !selected ? RemoteLoveTheme.green : tint.opacity(dayTasks.isEmpty ? 0.15 : 0.45), lineWidth: today || !dayTasks.isEmpty ? 1.4 : 0.6)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(date.formatted(date: .complete, time: .omitted))
        .accessibilityValue(dayTasks.isEmpty ? "No tasks" : "\(done) of \(dayTasks.count) tasks completed")
    }

    private func dayTint(total: Int, done: Int) -> Color {
        if total == 0 {
            return .secondary
        }
        return done == total ? RemoteLoveTheme.green : RemoteLoveTheme.amber
    }

    private func changeMonth(by amount: Int) {
        guard let newMonth = calendar.date(byAdding: .month, value: amount, to: visibleMonth) else { return }
        withAnimation(.easeInOut(duration: 0.24)) {
            visibleMonth = startOfMonth(containing: newMonth)
        }
    }

    private func startOfMonth(containing date: Date) -> Date {
        calendar.date(from: calendar.dateComponents([.year, .month], from: date)) ?? date
    }
}

struct TaskUndoBanner: View {
    @EnvironmentObject private var store: RemoteLoveStore

    var body: some View {
        let singleDateUndo = store.taskUndoCount(scope: .singleDate)
        let singleDateRedo = store.taskRedoCount(scope: .singleDate)
        let futureUndo = store.taskUndoCount(scope: .futureRoutine)
        let futureRedo = store.taskRedoCount(scope: .futureRoutine)

        if store.currentRole.canManageCare && singleDateUndo + singleDateRedo + futureUndo + futureRedo > 0 {
            VStack(spacing: 12) {
                if singleDateUndo + singleDateRedo > 0 {
                    historyRow(scope: .singleDate, undoCount: singleDateUndo, redoCount: singleDateRedo)
                }
                if futureUndo + futureRedo > 0 {
                    historyRow(scope: .futureRoutine, undoCount: futureUndo, redoCount: futureRedo)
                }
            }
            .padding(14)
            .remoteLoveSectionSurface(cornerRadius: 16)
            .padding(.horizontal)
        }
    }

    @ViewBuilder
    private func historyRow(scope: TaskHistoryScope, undoCount: Int, redoCount: Int) -> some View {
        let undoEntries = store.taskUndoEntries(scope: scope)
        let redoEntries = store.taskRedoEntries(scope: scope)

        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(scope.title)
                    .font(.caption.weight(.semibold))
                    .foregroundColor(.secondary)
                Text("\(undoCount) change\(undoCount == 1 ? "" : "s") made")
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(.primary)
            }
            Spacer()
            Menu {
                ForEach(undoEntries) { entry in
                    Button {
                        store.undoTaskChange(entryID: entry.id)
                    } label: {
                        Label(historyEntryTitle(entry), systemImage: "arrow.uturn.backward")
                    }
                }
                if undoEntries.count > 1 {
                    Divider()
                    Button("Undo latest") {
                        store.undoTaskChange(scope: scope)
                    }
                }
            } label: {
                Label("Undo", systemImage: "arrow.uturn.backward.circle")
            }
            .font(.subheadline.bold())
            .disabled(undoCount == 0)

            Menu {
                ForEach(redoEntries) { entry in
                    Button {
                        store.redoTaskChange(entryID: entry.id)
                    } label: {
                        Label(historyEntryTitle(entry), systemImage: "arrow.uturn.forward")
                    }
                }
                if redoEntries.count > 1 {
                    Divider()
                    Button("Redo latest") {
                        store.redoTaskChange(scope: scope)
                    }
                }
            } label: {
                Label("Redo", systemImage: "arrow.uturn.forward.circle")
            }
            .font(.subheadline.bold())
            .disabled(redoCount == 0)
        }
    }

    private func historyEntryTitle(_ entry: TaskUndoEntry) -> String {
        "\(historyEntryChangeSummary(entry)) · \(entry.date.formatted(date: .omitted, time: .shortened))"
    }

    private func historyEntryChangeSummary(_ entry: TaskUndoEntry) -> String {
        let beforeByID = Dictionary(uniqueKeysWithValues: entry.tasksBefore.map { ($0.id, $0) })
        let afterByID = Dictionary(uniqueKeysWithValues: entry.tasksAfter.map { ($0.id, $0) })

        if let added = entry.tasksAfter.first(where: { beforeByID[$0.id] == nil }) {
            return "Added \(added.title.isEmpty ? "task" : added.title)"
        }

        if let removed = entry.tasksBefore.first(where: { afterByID[$0.id] == nil }) {
            return "Removed \(removed.title.isEmpty ? "task" : removed.title)"
        }

        for updated in entry.tasksAfter {
            guard let old = beforeByID[updated.id], old != updated else { continue }
            return "\(updated.title.isEmpty ? "Task" : updated.title): \(taskFieldChanges(from: old, to: updated))"
        }

        return entry.message
    }

    private func taskFieldChanges(from old: CareTask, to new: CareTask) -> String {
        var changes: [String] = []

        if old.title != new.title {
            changes.append("title")
        }
        if old.instructions != new.instructions {
            changes.append("instructions")
        }
        if old.scheduledAt != new.scheduledAt {
            changes.append("time")
        }
        if old.frequency != new.frequency {
            changes.append("repeat")
        }
        if old.requiresPhoto != new.requiresPhoto {
            changes.append("photo")
        }
        if old.state != new.state {
            changes.append("status")
        }

        if changes.isEmpty {
            return "details changed"
        }

        return changes.prefix(3).joined(separator: ", ") + (changes.count > 3 ? "…" : "")
    }
}

struct TaskRow: View {
    @EnvironmentObject private var store: RemoteLoveStore
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let task: CareTask
    var allowsCompletion = true
    var onEdit: (() -> Void)? = nil
    var isNextAction = false
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var isAttachingPhoto = false
    @State private var didPop = false

    private var shouldHighlightNextAction: Bool {
        isNextAction && task.state != .done
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if shouldHighlightNextAction {
                Label("Next up", systemImage: "sparkles")
                    .font(.caption.weight(.bold))
                    .foregroundColor(RemoteLoveTheme.green)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(RemoteLoveTheme.green.opacity(0.14), in: Capsule())
                    .accessibilityLabel("Next task to complete")
            }

            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(task.scheduledAt, style: .time).font(.caption.bold()).foregroundColor(RemoteLoveTheme.green)
                    Text(task.title).font(.headline)
                    if !task.instructions.isEmpty { Text(task.instructions).font(.subheadline).foregroundColor(.secondary) }
                }
                Spacer()
                StatusCapsule(state: task.state)
            }
            HStack(spacing: 8) {
                Label(displayFrequency, systemImage: "repeat")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .labelStyle(.titleAndIcon)
                if task.requiresPhoto {
                    Label("Photo required", systemImage: "camera.fill")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .labelStyle(.titleAndIcon)
                }
                Spacer()
            }

            taskActionControls
        }
        .padding(16)
        .remoteLoveSectionSurface()
        .neonAttention(active: shouldHighlightNextAction, tint: RemoteLoveTheme.green, cornerRadius: 20)
        .padding(.horizontal)
        .scaleEffect(didPop ? 1.025 : (task.state == .done ? 0.985 : 1))
        .animation(.spring(response: 0.28, dampingFraction: 0.86), value: task.state)
        .animation(.spring(response: 0.22, dampingFraction: 0.56), value: didPop)
        .onChange(of: selectedPhoto) { _, item in
            guard let item else { return }
            Task { await attachPhoto(item) }
        }
        .onChange(of: task.state) {
            triggerCompletionPop()
        }
    }

    @ViewBuilder
    private var taskActionControls: some View {
        if dynamicTypeSize.isAccessibilitySize {
            VStack(alignment: .leading, spacing: 10) {
                taskActionsMenu
                completionArea
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        } else {
            HStack(spacing: 10) {
                taskActionsMenu
                Spacer(minLength: 0)
                completionArea
            }
            .frame(minHeight: 44)
        }
    }

    @ViewBuilder
    private var taskActionsMenu: some View {
        if store.currentRole.canManageCare || onEdit != nil {
            Menu {
                if let onEdit = onEdit {
                    Button(action: onEdit) {
                        Label("Edit task", systemImage: "pencil")
                    }
                }
                if store.currentRole.canManageCare {
                    Button {
                        store.notifyHelper(taskID: task.id)
                    } label: {
                        Label(task.notifiedAt == nil ? "Notify helper" : "Notify again", systemImage: "bell.fill")
                    }
                }
                if task.state == .done && store.canCompleteCareTasks {
                    Button {
                        withAnimation(.spring(response: 0.28, dampingFraction: 0.82)) {
                            store.setTask(task.id, state: .pending)
                        }
                    } label: {
                        Label("Undo done", systemImage: "arrow.uturn.backward")
                    }
                }
            } label: {
                if dynamicTypeSize.isAccessibilitySize {
                    Label("Task actions", systemImage: "ellipsis.circle")
                        .font(.subheadline.weight(.semibold))
                } else {
                    Label("Task actions", systemImage: "ellipsis.circle")
                        .labelStyle(.iconOnly)
                        .font(.title3)
                }
            }
            .accessibilityLabel("Task actions for \(task.title)")
        }
    }

    @ViewBuilder
    private var completionArea: some View {
        if allowsCompletion && task.state != .paused {
            completionControls
        } else if !allowsCompletion && task.state != .done && !store.canEditCareRecords {
            Text("View only")
                .font(.caption.weight(.semibold))
                .foregroundColor(.secondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background(Color.secondary.opacity(0.10), in: Capsule())
        }
    }

    @ViewBuilder
    private var completionControls: some View {
        if task.state == .done {
            Button("Undo done") {
                withAnimation(.spring(response: 0.28, dampingFraction: 0.82)) {
                    store.setTaskForSelectedDate(task.id, state: .pending)
                }
            }
            .buttonStyle(.bordered)
        } else {
            if task.state != .attending {
                Button("Attending now") {
                    withAnimation(.spring(response: 0.28, dampingFraction: 0.82)) {
                        store.setTaskForSelectedDate(task.id, state: .attending)
                    }
                }
                .buttonStyle(.bordered)
            }
            if task.requiresPhoto && !store.hasPhotoEvidence(for: task.id) {
                PhotosPicker(selection: $selectedPhoto, matching: .images) {
                    Label(isAttachingPhoto ? "Attaching..." : "Add photo", systemImage: "camera.fill")
                }
                .buttonStyle(.bordered)
                .disabled(isAttachingPhoto)
            } else {
                Button("Done") {
                    withAnimation(.spring(response: 0.28, dampingFraction: 0.82)) {
                        store.setTaskForSelectedDate(task.id, state: .done)
                    }
                }
                .buttonStyle(.borderedProminent)
            }
        }
    }

    private func attachPhoto(_ item: PhotosPickerItem) async {
        isAttachingPhoto = true
        defer {
            isAttachingPhoto = false
            selectedPhoto = nil
        }

        do {
            if let data = try await item.loadTransferable(type: Data.self) {
                store.attachTaskPhoto(taskID: task.id, byteCount: data.count)
            } else {
                store.authMessage = "Could not read that photo. Please choose another image."
            }
        } catch {
            store.authMessage = "Could not attach that photo. Please try again."
        }
    }

    private var displayFrequency: String {
        task.frequency.components(separatedBy: " · except ").first ?? task.frequency
    }

    private func triggerCompletionPop() {
        didPop = true
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 180_000_000)
            didPop = false
        }
    }
}

struct TaskEditorView: View {
    @EnvironmentObject private var store: RemoteLoveStore
    @Environment(\.dismiss) private var dismiss

    private let originalTask: CareTask
    @State private var draft: CareTask

    @State private var repeatOption: String
    @State private var editScope: TaskEditScope?
    @State private var customInterval: Int = 1
    @State private var customUnit: String = "Days"
    @State private var dailyLimit: Int = 3
    @State private var selectedWeekdays: Set<Int>
    @State private var reminderEnabled = true
    @State private var reminderTiming: ReminderTimingOption = .atTime
    @State private var reminderCustomDaysBefore = 0
    @State private var reminderTime: Date
    @State private var reminderRepeat: ReminderRepeatOption = .everyHour
    @State private var reminderRecipient: ReminderRecipientOption = .everyone
    @State private var selectedTemplateID: String?
    @State private var showEditScopePrompt = false

    init(task: CareTask) {
        originalTask = task
        _draft = State(initialValue: task)
        _editScope = State(initialValue: task.title.isEmpty ? .allFuture : nil)
        _reminderTime = State(initialValue: task.scheduledAt)

        if ["Every day", "Weekdays", "Does not repeat"].contains(task.frequency) {
            _repeatOption = State(initialValue: task.frequency)
            _selectedWeekdays = State(initialValue: Set(Self.weekdayOptions.map(\.id)))
        } else if let weekdays = Self.weekdays(from: task.frequency) {
            _repeatOption = State(initialValue: "Selected days")
            _selectedWeekdays = State(initialValue: weekdays)
        } else {
            _repeatOption = State(initialValue: "Custom")
            _selectedWeekdays = State(initialValue: Set(Self.weekdayOptions.map(\.id)))
        }
    }

    var body: some View {
        NavigationStack {
            ScrollViewReader { formProxy in
            Form {
                Section {
                    EditorProfileContextCard(
                        profileName: store.selectedRecipient.name,
                        profileLabel: store.selectedRecipient.label,
                        action: draft.title.isEmpty ? "Creating task for" : "Editing task for"
                    )
                    EditorSetupSummaryCard(
                        title: draft.title.isEmpty ? "Build a clear daily step" : "Review before saving",
                        detail: "Start with what needs doing, then set when it appears, who gets reminded and whether photo proof is needed.",
                        icon: "checklist"
                    )
                }

                if requiresEditScope {
                    Section {
                        VStack(spacing: 10) {
                            ForEach(TaskEditScope.allCases) { scope in
                                Button {
                                    editScope = scope
                                } label: {
                                    HStack(spacing: 12) {
                                        Image(systemName: editScope == scope ? "checkmark.circle.fill" : "circle")
                                            .font(.title3)
                                            .foregroundColor(RemoteLoveTheme.green)
                                        VStack(alignment: .leading, spacing: 3) {
                                            Text(scope.title)
                                                .font(.headline)
                                                .foregroundColor(.primary)
                                            Text(scope.subtitle)
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        }
                                        Spacer()
                                    }
                                    .padding(14)
                                    .background(
                                        editScope == scope ? RemoteLoveTheme.green.opacity(0.14) : Color.secondary.opacity(0.08),
                                        in: RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    )
                                    .overlay {
                                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                                            .stroke(editScope == scope ? RemoteLoveTheme.green.opacity(0.55) : Color.secondary.opacity(0.12), lineWidth: 1)
                                    }
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        if showEditScopePrompt {
                            Label("Select first", systemImage: "hand.tap.fill")
                                .font(.caption.weight(.bold))
                                .foregroundColor(RemoteLoveTheme.coral)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(10)
                                .background(RemoteLoveTheme.coral.opacity(0.10), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                                .transition(.opacity.combined(with: .move(edge: .top)))
                        }
                    } header: {
                        Text("Choose edit scope")
                    } footer: {
                        Text("Pick one before editing. This prevents changing a whole routine by accident.")
                    }
                    .id(editScopeSectionID)
                }

                // MARK: - Task Details
                Section {
                    VStack(alignment: .leading, spacing: 18) {

                        if draft.title.isEmpty {
                            TaskTemplatePicker(
                                selectedTemplateID: $selectedTemplateID,
                                onSelect: applyTemplate
                            )
                        }

                        VStack(alignment: .leading, spacing: 8) {
                            Label("Task name", systemImage: "pencil")
                                .font(.subheadline.weight(.semibold))
                                .foregroundColor(RemoteLoveTheme.green)

                            TextField(
                                "e.g. Take morning medication",
                                text: $draft.title
                            )
                            .textInputAutocapitalization(.sentences)
                            .padding(14)
                            .background(
                                Color.secondary.opacity(0.08),
                                in: RoundedRectangle(
                                    cornerRadius: 14,
                                    style: .continuous
                                )
                            )

                            RecentSuggestionChips(title: "Recent tasks", suggestions: recentTaskTitles) { suggestion in
                                draft.title = suggestion
                            }
                        }


                        VStack(alignment: .leading, spacing: 8) {
                            Label("Instructions", systemImage: "list.bullet.rectangle")
                                .font(.subheadline.weight(.semibold))
                                .foregroundColor(RemoteLoveTheme.green)

                            TextField(
                                "Add useful details for the caregiver...",
                                text: $draft.instructions,
                                axis: .vertical
                            )
                            .lineLimit(3...6)
                            .padding(14)
                            .background(
                                Color.secondary.opacity(0.08),
                                in: RoundedRectangle(
                                    cornerRadius: 14,
                                    style: .continuous
                                )
                            )

                            Text("Optional")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.vertical, 8)

                } header: {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("TASK DETAILS")
                            .font(.caption.weight(.bold))

                        Text("What needs to be done?")
                            .font(.headline)
                            .textCase(nil)
                            .foregroundColor(.primary)
                    }
                    .padding(.bottom, 6)

                } footer: {
                    Text(
                        "Use a short, clear task name and include any instructions that will help the caregiver."
                    )
                }
                .disabled(isWaitingForEditScope)
                .scopeSelectionGate(isActive: isWaitingForEditScope) {
                    promptForEditScope(using: formProxy)
                }


                // MARK: - Schedule
                Section {
                    TaskSchedulePreviewCard(
                        time: draft.scheduledAt,
                        repeatText: scheduleSummaryText,
                        photoRequired: draft.requiresPhoto
                    )

                    DatePicker(
                        "First time",
                        selection: $draft.scheduledAt,
                        displayedComponents: .hourAndMinute
                    )

                    Picker("Repeat", selection: $repeatOption) {
                        Text("Every day")
                            .tag("Every day")

                        Text("Weekdays")
                            .tag("Weekdays")

                        Text("Selected days")
                            .tag("Selected days")

                        Text("Does not repeat")
                            .tag("Does not repeat")

                        Text("Custom")
                            .tag("Custom")
                    }
                    .pickerStyle(.menu)

                } header: {
                    Text("Schedule")
                }
                .disabled(isWaitingForEditScope)


                // MARK: - Selected Days
                if repeatOption == "Selected days" {
                    Section {
                        LazyVGrid(columns: weekdayColumns, spacing: 10) {
                            ForEach(Self.weekdayOptions) { day in
                                Button {
                                    toggleWeekday(day.id)
                                } label: {
                                    Text(day.shortName)
                                        .font(.subheadline.weight(.semibold))
                                        .frame(maxWidth: .infinity, minHeight: 44)
                                        .foregroundColor(selectedWeekdays.contains(day.id) ? RemoteLoveTheme.onAccent : RemoteLoveTheme.green)
                                        .background(
                                            selectedWeekdays.contains(day.id) ? RemoteLoveTheme.green : Color.secondary.opacity(0.08),
                                            in: RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        )
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel(day.name)
                                .accessibilityAddTraits(selectedWeekdays.contains(day.id) ? .isSelected : [])
                            }
                        }
                    } header: {
                        Text("Days of week")
                    } footer: {
                        Text("Choose at least one day for this task.")
                    }
                    .disabled(isWaitingForEditScope)
                    .scopeSelectionGate(isActive: isWaitingForEditScope) {
                        promptForEditScope(using: formProxy)
                    }
                }


                // MARK: - Custom Repeat
                if repeatOption == "Custom" {
                    Section {

                        Stepper(
                            "Every \(customInterval) \(unitLabel)",
                            value: $customInterval,
                            in: 1...30
                        )

                        VStack(alignment: .leading, spacing: 10) {
                            Text("Repeat by")
                                .font(.subheadline.weight(.semibold))

                            Picker("Repeat unit", selection: $customUnit) {
                                Text("Hours").tag("Hours")
                                Text("Days").tag("Days")
                                Text("Weeks").tag("Weeks")
                            }
                            .pickerStyle(.segmented)
                        }
                        .padding(.vertical, 4)

                        if customUnit == "Hours" {
                            Stepper(
                                "Maximum \(dailyLimit) times per day",
                                value: $dailyLimit,
                                in: 1...12
                            )
                        }

                    } header: {
                        Text("Custom repeat")
                    } footer: {
                        if customUnit == "Hours" {
                            Text(
                                "This task repeats every \(customInterval) \(unitLabel), up to \(dailyLimit) times per day."
                            )
                        } else {
                            Text(
                                "This task repeats every \(customInterval) \(unitLabel)."
                            )
                        }
                    }
                    .disabled(isWaitingForEditScope)
                    .scopeSelectionGate(isActive: isWaitingForEditScope) {
                        promptForEditScope(using: formProxy)
                    }
                }


                Section {
                    ReminderSettingsCard(
                        itemName: draft.title,
                        scheduledAt: draft.scheduledAt,
                        isEnabled: $reminderEnabled,
                        timing: $reminderTiming,
                        customDaysBefore: $reminderCustomDaysBefore,
                        customTime: $reminderTime,
                        repeatOption: $reminderRepeat,
                        recipient: $reminderRecipient
                    )
                } header: {
                    Text("Reminder")
                } footer: {
                    Text("Task reminders use the task schedule. Repeat settings describe how reminders should continue until someone responds.")
                }
                .disabled(isWaitingForEditScope)
                .scopeSelectionGate(isActive: isWaitingForEditScope) {
                    promptForEditScope(using: formProxy)
                }


                // MARK: - Completion
                Section {
                    Toggle(
                        "Require a photo before completion",
                        isOn: $draft.requiresPhoto
                    )

                } header: {
                    Text("Completion")
                } footer: {
                    if draft.requiresPhoto {
                        Text(
                            "The caregiver will be asked to provide a photo before marking this task as completed."
                        )
                    }
                }
                .disabled(isWaitingForEditScope)
                .scopeSelectionGate(isActive: isWaitingForEditScope) {
                    promptForEditScope(using: formProxy)
                }


                // MARK: - Save
                Section {
                    Button {
                        saveTask()
                    } label: {
                        HStack {
                            Spacer()

                            Label(
                                draft.title.isEmpty
                                ? "Create task"
                                : "Save task changes",
                                systemImage: "checkmark.circle.fill"
                            )
                            .fontWeight(.semibold)

                            Spacer()
                        }
                    }
                    .disabled(
                        draft.title
                            .trimmingCharacters(in: .whitespacesAndNewlines)
                            .isEmpty
                        || isWaitingForEditScope
                    )
                    .buttonStyle(PrimaryButtonStyle())
                    .scopeSelectionGate(isActive: isWaitingForEditScope) {
                        promptForEditScope(using: formProxy)
                    }
                }


                // MARK: - Task Status
                if !draft.title.isEmpty {
                    Section {
                        if draft.state == .paused {
                            Button {
                                draft.state = .pending
                            } label: {
                                Label(
                                    "Resume task",
                                    systemImage: "play.circle"
                                )
                            }

                        } else {
                            Button {
                                draft.state = .paused
                            } label: {
                                Label(
                                    "Pause task",
                                    systemImage: "pause.circle"
                                )
                            }
                        }

                    } header: {
                        Text("Task status")
                    } footer: {
                        if draft.state == .paused {
                            Text(
                                "This task is currently paused and will not appear as an active care task."
                            )
                        } else {
                            Text(
                                "Pausing a task temporarily removes it from the active care routine."
                            )
                        }
                    }
                    .disabled(isWaitingForEditScope)
                    .scopeSelectionGate(isActive: isWaitingForEditScope) {
                        promptForEditScope(using: formProxy)
                    }
                }
            }
            .navigationTitle(
                draft.title.isEmpty
                ? "Create task"
                : "Edit task"
            )
            .navigationBarTitleDisplayMode(.inline)

            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            }
        }
    }


    // MARK: - Repeat label

    private var unitLabel: String {
        let unit = customUnit.lowercased()

        if customInterval == 1 {
            return String(unit.dropLast())
        }

        return unit
    }

    private var recentTaskTitles: [String] {
        uniqueRecent(store.tasks.map(\.title), excluding: draft.title)
    }

    private var scheduleSummaryText: String {
        switch repeatOption {
        case "Selected days":
            return selectedWeekdayFrequency
        case "Custom":
            if customUnit == "Hours" {
                return "Every \(customInterval) \(unitLabel), up to \(dailyLimit) times daily"
            }
            return "Every \(customInterval) \(unitLabel)"
        default:
            return repeatOption
        }
    }

    private var weekdayColumns: [GridItem] {
        [GridItem(.adaptive(minimum: 64), spacing: 10)]
    }

    private var requiresEditScope: Bool {
        !originalTask.title.isEmpty
    }

    private var isWaitingForEditScope: Bool {
        requiresEditScope && editScope == nil
    }

    private var editScopeSectionID: String {
        "task-edit-scope-section"
    }

    private func promptForEditScope(using proxy: ScrollViewProxy) {
        guard isWaitingForEditScope else { return }
        withAnimation(.easeInOut(duration: 0.24)) {
            showEditScopePrompt = true
            proxy.scrollTo(editScopeSectionID, anchor: .top)
        }
    }

    // MARK: - Save Task

    private func saveTask() {

        if repeatOption == "Selected days" {
            if selectedWeekdays.isEmpty {
                selectedWeekdays.insert(Calendar.current.component(.weekday, from: Date()))
            }
            draft.frequency = selectedWeekdayFrequency

        } else if repeatOption == "Custom" {

            if customUnit == "Hours" {
                draft.frequency =
                    "Every \(customInterval) \(unitLabel) · maximum \(dailyLimit) daily"
            } else {
                draft.frequency =
                    "Every \(customInterval) \(unitLabel)"
            }

        } else {
            draft.frequency = repeatOption
        }

        switch editScope ?? .allFuture {
        case .allFuture:
            store.saveTask(draft)
        case .singleEvent:
            store.saveTaskOccurrenceOverride(
                originalTaskID: originalTask.id,
                editedTask: draft,
                occurrenceDate: store.selectedTaskDate
            )
        }

        dismiss()
    }

    private func applyTemplate(_ template: TaskTemplate) {
        selectedTemplateID = template.id
        draft.title = template.title
        draft.instructions = template.instructions
        draft.requiresPhoto = template.requiresPhoto
        repeatOption = template.repeatOption
        if let hour = template.hour,
           let scheduledAt = Calendar.current.date(bySettingHour: hour, minute: template.minute, second: 0, of: draft.scheduledAt) {
            draft.scheduledAt = scheduledAt
            reminderTime = scheduledAt
        }
    }

    private func repeatOption(for frequency: String) -> String {
        let baseFrequency = frequency.components(separatedBy: " · except ").first ?? frequency
        if ["Every day", "Weekdays", "Does not repeat"].contains(baseFrequency) {
            return baseFrequency
        }
        if Self.weekdays(from: baseFrequency) != nil {
            return "Selected days"
        }
        return "Custom"
    }

    private var selectedWeekdayFrequency: String {
        let names = Self.weekdayOptions
            .filter { selectedWeekdays.contains($0.id) }
            .map(\.name)

        guard !names.isEmpty else { return "Every day" }
        return "Every " + names.joined(separator: ", ")
    }

    private func toggleWeekday(_ id: Int) {
        if selectedWeekdays.contains(id) {
            selectedWeekdays.remove(id)
        } else {
            selectedWeekdays.insert(id)
        }
    }

    private static let weekdayOptions: [WeekdayOption] = [
        WeekdayOption(id: 2, shortName: "Mon", name: "Monday"),
        WeekdayOption(id: 3, shortName: "Tue", name: "Tuesday"),
        WeekdayOption(id: 4, shortName: "Wed", name: "Wednesday"),
        WeekdayOption(id: 5, shortName: "Thu", name: "Thursday"),
        WeekdayOption(id: 6, shortName: "Fri", name: "Friday"),
        WeekdayOption(id: 7, shortName: "Sat", name: "Saturday"),
        WeekdayOption(id: 1, shortName: "Sun", name: "Sunday")
    ]

    private static func weekdays(from frequency: String) -> Set<Int>? {
        guard frequency.hasPrefix("Every ") else { return nil }
        let matches = weekdayOptions.filter { frequency.contains($0.name) }
        return matches.isEmpty ? nil : Set(matches.map(\.id))
    }

    private struct WeekdayOption: Identifiable {
        let id: Int
        let shortName: String
        let name: String
    }

    private enum TaskEditScope: String, CaseIterable, Identifiable {
        case allFuture
        case singleEvent

        var id: String { rawValue }

        var title: String {
            switch self {
            case .allFuture:
                return "All future similar events"
            case .singleEvent:
                return "This selected date only"
            }
        }

        var subtitle: String {
            switch self {
            case .allFuture:
                return "Update the routine from this point forward."
            case .singleEvent:
                return "Create a one-off change for the selected day."
            }
        }
    }
}

struct TaskManagementView: View {
    @EnvironmentObject private var store: RemoteLoveStore
    @Environment(\.dismiss) private var dismiss
    @State private var selected = Set<UUID>()

    var body: some View {
        NavigationStack {
            List(store.selectedTasks) { task in
                Button {
                    if selected.contains(task.id) { selected.remove(task.id) } else { selected.insert(task.id) }
                } label: {
                    HStack {
                        Image(systemName: selected.contains(task.id) ? "checkmark.circle.fill" : "circle")
                        VStack(alignment: .leading) { Text(task.title); Text(task.scheduledAt, style: .time).font(.caption).foregroundColor(.secondary) }
                    }
                }
                .foregroundColor(.primary)
            }
            .navigationTitle("Manage tasks")
            .safeAreaInset(edge: .bottom) {
                Button("Remove \(selected.count) selected task\(selected.count == 1 ? "" : "s")", role: .destructive) {
                    store.removeTasks(selected); dismiss()
                }
                .buttonStyle(PrimaryButtonStyle(tint: .red))
                .disabled(selected.isEmpty)
                .padding()
                .background(.ultraThinMaterial)
            }
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Close") { dismiss() } } }
        }
    }
}

private struct TaskTemplatePicker: View {
    @Binding var selectedTemplateID: String?
    let onSelect: (TaskTemplate) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Start with a common task", systemImage: "sparkles")
                .font(.subheadline.weight(.semibold))
                .foregroundColor(RemoteLoveTheme.green)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(TaskTemplate.common) { template in
                        Button {
                            onSelect(template)
                        } label: {
                            VStack(alignment: .leading, spacing: 6) {
                                Image(systemName: template.icon)
                                    .font(.headline)
                                    .foregroundColor(selectedTemplateID == template.id ? RemoteLoveTheme.onAccent : RemoteLoveTheme.green)
                                Text(template.title)
                                    .font(.caption.weight(.semibold))
                                    .foregroundColor(selectedTemplateID == template.id ? RemoteLoveTheme.onAccent : .primary)
                                    .lineLimit(2)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            .frame(width: 118, alignment: .leading)
                            .padding(12)
                            .background(
                                selectedTemplateID == template.id ? RemoteLoveTheme.green : RemoteLoveTheme.green.opacity(0.10),
                                in: RoundedRectangle(cornerRadius: 16, style: .continuous)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            Text("Templates only fill the form. You can edit every detail before saving.")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(14)
        .background(Color.secondary.opacity(0.07), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

private struct TaskSchedulePreviewCard: View {
    let time: Date
    let repeatText: String
    let photoRequired: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "calendar.badge.clock")
                .font(.headline)
                .foregroundColor(RemoteLoveTheme.green)
                .frame(width: 34, height: 34)
                .background(RemoteLoveTheme.green.opacity(0.12), in: Circle())
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 4) {
                Text("Schedule preview")
                    .font(.subheadline.weight(.semibold))
                Text("\(time.formatted(date: .omitted, time: .shortened)) · \(repeatText)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                if photoRequired {
                    Label("Photo required before completion", systemImage: "camera.fill")
                        .font(.caption.weight(.semibold))
                        .foregroundColor(RemoteLoveTheme.coral)
                }
            }
        }
        .padding(12)
        .background(RemoteLoveTheme.green.opacity(0.08), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

private struct TaskTemplate: Identifiable {
    let id: String
    let title: String
    let instructions: String
    let icon: String
    let repeatOption: String
    let requiresPhoto: Bool
    let hour: Int?
    let minute: Int

    static let common: [TaskTemplate] = [
        TaskTemplate(
            id: "morning-medicine",
            title: "Morning medicine",
            instructions: "Confirm the correct medicine and dose before marking done.",
            icon: "pills.fill",
            repeatOption: "Every day",
            requiresPhoto: false,
            hour: 8,
            minute: 0
        ),
        TaskTemplate(
            id: "meal-check",
            title: "Meal check",
            instructions: "Check that a meal was prepared or eaten, and add notes if appetite was poor.",
            icon: "fork.knife",
            repeatOption: "Every day",
            requiresPhoto: false,
            hour: 12,
            minute: 0
        ),
        TaskTemplate(
            id: "hydration",
            title: "Hydration reminder",
            instructions: "Offer water or preferred fluids unless restricted by their care plan.",
            icon: "waterbottle.fill",
            repeatOption: "Every day",
            requiresPhoto: false,
            hour: 10,
            minute: 0
        ),
        TaskTemplate(
            id: "exercise",
            title: "Mobility exercise",
            instructions: "Support only safe movements recommended by family or a care professional.",
            icon: "figure.walk",
            repeatOption: "Weekdays",
            requiresPhoto: false,
            hour: 15,
            minute: 0
        ),
        TaskTemplate(
            id: "proof",
            title: "Photo check-in",
            instructions: "Attach a clear photo before completing this task.",
            icon: "camera.fill",
            repeatOption: "Every day",
            requiresPhoto: true,
            hour: 18,
            minute: 0
        )
    ]
}

struct PlannerView: View {
    @EnvironmentObject private var store: RemoteLoveStore
    @State private var editingMedicine: Medicine?
    @State private var editingAppointment: CareAppointment?
    @State private var editingOtherItem: PlannerOtherItem?
    @State private var filter: PlannerFilter = .all
    @State private var selectedDate = Calendar.current.startOfDay(for: Date())
    @State private var visibleMonth = Calendar.current.date(
        from: Calendar.current.dateComponents([.year, .month], from: Date())
    ) ?? Date()

    private var lowMedicines: [Medicine] {
        store.selectedMedicines.filter { $0.active && $0.daysRemaining <= $0.attentionDays }
    }

    private var visibleMedicines: [Medicine] {
        filter.showsMedicines ? store.selectedMedicines : []
    }

    private var visibleAppointments: [CareAppointment] {
        filter.showsAppointments ? store.selectedAppointments : []
    }

    private var visibleOtherItems: [PlannerOtherItem] {
        filter.showsOtherItems ? store.selectedPlannerOtherItems : []
    }

    var body: some View {
        ScrollViewReader { tutorialProxy in
            ScrollView {
                LazyVStack(spacing: 16) {
                RecipientHeader()
                HStack {
                    VStack(alignment: .leading) {
                        Text("Planner").font(.largeTitle.bold())
                        Text("Medicines, refills and appointments").foregroundColor(.secondary)
                    }
                    Spacer()
                    if store.canEditCareRecords {
                        Menu {
                            Button { editingMedicine = newMedicine() } label: {
                                Label("Add medicine", systemImage: "pills")
                            }
                            Button { editingAppointment = newAppointment() } label: {
                                Label("Add appointment", systemImage: "calendar.badge.plus")
                            }
                            Button { editingOtherItem = newOtherItem() } label: {
                                Label("Add other", systemImage: "plus.square.on.square")
                            }
                        } label: {
                            Label("Add", systemImage: "plus.circle.fill")
                                .font(.headline)
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
                .padding(.horizontal)
                .tutorialSpotlight(.plannerHeader)

                Picker("Planner filter", selection: $filter) {
                    ForEach(PlannerFilter.allCases) { option in
                        Text(option.title).tag(option)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)

                PlannerCalendarView(
                    selectedDate: $selectedDate,
                    visibleMonth: $visibleMonth,
                    medicines: visibleMedicines,
                    appointments: visibleAppointments,
                    otherItems: visibleOtherItems
                )
                .tutorialSpotlight(.plannerCalendar)

                PlannerDayScheduleView(
                    date: selectedDate,
                    medicines: filter.showsMedicines ? medicines(on: selectedDate) : [],
                    appointments: filter.showsAppointments ? appointments(on: selectedDate) : [],
                    otherItems: filter.showsOtherItems ? otherItems(on: selectedDate) : [],
                    onSelectMedicine: { if store.canEditCareRecords { editingMedicine = $0 } },
                    onSelectAppointment: { if store.canEditCareRecords { editingAppointment = $0 } },
                    onSelectOtherItem: { if store.canEditCareRecords { editingOtherItem = $0 } }
                )
                .tutorialSpotlight(.plannerSchedule)

                if filter.showsMedicines && !lowMedicines.isEmpty {
                    NativeCard(title: "Needs attention", subtitle: "Based on each medicine’s chosen threshold", icon: "exclamationmark.circle.fill", tint: RemoteLoveTheme.amber) {
                        ForEach(lowMedicines) { medicine in
                            Button { if store.canEditCareRecords { editingMedicine = medicine } } label: {
                                HStack {
                                    Text(medicine.name).foregroundColor(.primary)
                                    Spacer()
                                    Text("\(medicine.daysRemaining) days left").foregroundColor(RemoteLoveTheme.amber).bold()
                                }
                                .padding(10)
                                .background(RemoteLoveTheme.amber.opacity(0.10), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .neonAttention(active: true, tint: RemoteLoveTheme.amber, cornerRadius: 20)
                    .tutorialSpotlight(.plannerAttention)
                }

                if filter.showsMedicines {
                    sectionHeader("Active medicines", action: nil) { editingMedicine = newMedicine() }
                    if visibleMedicines.isEmpty {
                        ActionEmptyStateCard(
                            icon: "pills.fill",
                            title: "No medicines added",
                            message: store.canEditCareRecords ? "Add medicines here so timing, supply and reminders stay visible to the care circle." : "No medicines have been added for this profile.",
                            actionTitle: store.canEditCareRecords ? "Add medicine" : nil,
                            action: store.canEditCareRecords ? { editingMedicine = newMedicine() } : nil
                        )
                        .padding(.horizontal)
                    } else {
                        ForEach(visibleMedicines) { medicine in
                            MedicineCard(medicine: medicine, onEdit: store.canEditCareRecords ? { editingMedicine = medicine } : nil)
                                .id(DestinationScrollTarget.medicine(medicine.id))
                        }
                        .tutorialSpotlight(.plannerMedicines)
                    }
                }

                if filter.showsAppointments {
                    sectionHeader("Appointments", action: nil) { editingAppointment = newAppointment() }
                    if visibleAppointments.isEmpty {
                        ActionEmptyStateCard(
                            icon: "calendar.badge.plus",
                            title: "No appointments yet",
                            message: store.canEditCareRecords ? "Add appointments so everyone can see what is coming up." : "No appointments have been added for this profile.",
                            actionTitle: store.canEditCareRecords ? "Add appointment" : nil,
                            action: store.canEditCareRecords ? { editingAppointment = newAppointment() } : nil
                        )
                        .padding(.horizontal)
                    } else {
                        ForEach(visibleAppointments) { appointment in
                            AppointmentCard(appointment: appointment, onEdit: store.canEditCareRecords ? { editingAppointment = appointment } : nil)
                                .id(DestinationScrollTarget.appointment(appointment.id))
                        }
                        .tutorialSpotlight(.plannerAppointments)
                    }
                }

                if filter.showsOtherItems {
                    sectionHeader("Other items", action: nil) { editingOtherItem = newOtherItem() }
                    if visibleOtherItems.isEmpty {
                        ActionEmptyStateCard(
                            icon: "square.grid.2x2.fill",
                            title: "No other planner items",
                            message: store.canEditCareRecords ? "Use Other for errands, documents, equipment or preparation notes." : "No other planner items have been added for this profile.",
                            actionTitle: store.canEditCareRecords ? "Add other item" : nil,
                            action: store.canEditCareRecords ? { editingOtherItem = newOtherItem() } : nil
                        )
                        .padding(.horizontal)
                    } else {
                        ForEach(visibleOtherItems) { item in
                            PlannerOtherItemCard(item: item, onEdit: store.canEditCareRecords ? { editingOtherItem = item } : nil)
                                .id(DestinationScrollTarget.otherItem(item.id))
                        }
                        .tutorialSpotlight(.plannerOther)
                    }
                }
                }
                .padding(.bottom, 24)
            }
            .tutorialScrollReceiver(tutorialProxy)
            .destinationScrollReceiver(tutorialProxy)
        }
        .background(Color(uiColor: .systemGroupedBackground))
        .navigationBarHidden(true)
        .safeAreaInset(edge: .top) {
            PlannerFocusCard(
                filter: filter,
                medicineCount: visibleMedicines.count,
                appointmentCount: visibleAppointments.count,
                otherCount: visibleOtherItems.count,
                selectedDate: selectedDate
            )
            .padding(.horizontal)
            .padding(.vertical, 8)
            .background(.ultraThinMaterial)
        }
        .sheet(item: $editingMedicine) { MedicineEditorView(medicine: $0) }
        .sheet(item: $editingAppointment) { AppointmentEditorView(appointment: $0) }
        .sheet(item: $editingOtherItem) { PlannerOtherItemEditorView(item: $0) }
        .onAppear(perform: openPendingPlannerDestination)
        .onChange(of: store.pendingDestination) {
            openPendingPlannerDestination()
        }
    }

    private func sectionHeader(_ title: String, action: String?, perform: @escaping () -> Void) -> some View {
        HStack {
            Text(title).font(.title2.bold())
            Spacer()
            if let action {
                Button(action) { perform() }.font(.subheadline.bold())
            }
        }
            .padding(.horizontal)
    }

    private func medicines(on date: Date) -> [Medicine] {
        store.selectedMedicines
            .filter { medicineOccurs($0, on: date) }
            .sorted { $0.firstTime < $1.firstTime }
    }

    private func appointments(on date: Date) -> [CareAppointment] {
        store.selectedAppointments
            .filter { appointmentOccurs($0, on: date) }
            .sorted { $0.date < $1.date }
    }

    private func otherItems(on date: Date) -> [PlannerOtherItem] {
        store.selectedPlannerOtherItems
            .filter { plannerOtherItemOccurs($0, on: date) }
            .sorted { $0.date < $1.date }
    }

    private func newMedicine() -> Medicine {
        Medicine(id: UUID(), recipientID: store.selectedRecipientID, name: "", purpose: "", instructions: "", currentSupply: 30, dose: 1, unit: "tablets", timesDaily: 1, intervalDays: 1, attentionDays: 7, active: true, firstTime: Date())
    }

    private func newAppointment() -> CareAppointment {
        CareAppointment(id: UUID(), recipientID: store.selectedRecipientID, title: "", date: Date(), notes: "", repeatRule: "Does not repeat", remindThreeDaysBefore: true, reminderEnabled: true, reminderDaysBefore: 3, reminderCount: 1, state: .scheduled)
    }

    private func newOtherItem() -> PlannerOtherItem {
        PlannerOtherItem(id: UUID(), recipientID: store.selectedRecipientID, title: "", date: Date(), notes: "", repeatRule: "Does not repeat", active: true)
    }

    private func openPendingPlannerDestination() {
        switch store.pendingDestination {
        case let .medicine(recipientID, medicineID):
            store.selectedRecipientID = recipientID
            if let medicine = store.medicines.first(where: { $0.id == medicineID }) {
                selectedDate = Calendar.current.startOfDay(for: medicine.firstTime)
                visibleMonth = Calendar.current.date(from: Calendar.current.dateComponents([.year, .month], from: medicine.firstTime)) ?? medicine.firstTime
            }
            store.pendingDestination = nil
            postDestinationScroll(DestinationScrollTarget.medicine(medicineID))
        case let .appointment(recipientID, appointmentID):
            store.selectedRecipientID = recipientID
            if let appointment = store.appointments.first(where: { $0.id == appointmentID }) {
                selectedDate = Calendar.current.startOfDay(for: appointment.date)
                visibleMonth = Calendar.current.date(from: Calendar.current.dateComponents([.year, .month], from: appointment.date)) ?? appointment.date
            }
            store.pendingDestination = nil
            postDestinationScroll(DestinationScrollTarget.appointment(appointmentID))
        default:
            break
        }
    }
}

private struct PlannerFocusCard: View {
    let filter: PlannerFilter
    let medicineCount: Int
    let appointmentCount: Int
    let otherCount: Int
    let selectedDate: Date

    private var totalCount: Int {
        medicineCount + appointmentCount + otherCount
    }

    private var detail: String {
        switch filter {
        case .all:
            return "\(medicineCount) medicine\(medicineCount == 1 ? "" : "s") · \(appointmentCount) appointment\(appointmentCount == 1 ? "" : "s") · \(otherCount) other"
        case .medicines:
            return "\(medicineCount) active medicine\(medicineCount == 1 ? "" : "s") for this care profile"
        case .appointments:
            return "\(appointmentCount) appointment\(appointmentCount == 1 ? "" : "s") saved for this care profile"
        case .other:
            return "\(otherCount) other planner item\(otherCount == 1 ? "" : "s") saved for this care profile"
        }
    }

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            Image(systemName: filter.iconName)
                .font(.headline.weight(.semibold))
                .foregroundColor(RemoteLoveTheme.green)
                .frame(width: 38, height: 38)
                .background(RemoteLoveTheme.green.opacity(0.12), in: Circle())
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 3) {
                Text("\(filter.fullTitle) plan")
                    .font(.headline)
                Text(detail)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)

            Text(selectedDate, format: .dateTime.day().month(.abbreviated))
                .font(.caption.weight(.bold))
                .foregroundColor(RemoteLoveTheme.green)
                .padding(.horizontal, 9)
                .padding(.vertical, 6)
                .background(RemoteLoveTheme.green.opacity(0.10), in: Capsule())
                .accessibilityLabel("Selected date \(selectedDate.formatted(date: .long, time: .omitted))")
        }
        .padding(14)
        .remoteLoveSectionSurface(cornerRadius: 18)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(filter.fullTitle) plan. \(detail). \(totalCount) total items.")
    }
}

private enum PlannerFilter: String, CaseIterable, Identifiable {
    case all
    case medicines
    case appointments
    case other

    var id: String { rawValue }

    var title: String {
        switch self {
        case .all: return "All"
        case .medicines: return "Meds"
        case .appointments: return "Appts"
        case .other: return "Other"
        }
    }

    var showsMedicines: Bool { self == .all || self == .medicines }
    var showsAppointments: Bool { self == .all || self == .appointments }
    var showsOtherItems: Bool { self == .all || self == .other }

    var fullTitle: String {
        switch self {
        case .all: return "Full"
        case .medicines: return "Medicine"
        case .appointments: return "Appointment"
        case .other: return "Other"
        }
    }

    var iconName: String {
        switch self {
        case .all: return "calendar"
        case .medicines: return "pills.fill"
        case .appointments: return "calendar.badge.clock"
        case .other: return "square.grid.2x2.fill"
        }
    }
}

private func medicineOccurs(
    _ medicine: Medicine,
    on date: Date,
    calendar: Calendar = .current
) -> Bool {
    guard medicine.active else { return false }

    let start = calendar.startOfDay(for: medicine.firstTime)
    let target = calendar.startOfDay(for: date)

    guard target >= start else { return false }

    let numberOfDays = calendar.dateComponents(
        [.day],
        from: start,
        to: target
    ).day ?? 0

    guard numberOfDays < medicine.daysRemaining else {
        return false
    }

    if let weekdays = medicine.repeatWeekdays, weekdays.isEmpty == false {
        return weekdays.contains(calendar.component(.weekday, from: target))
    }

    return medicine.intervalDays <= 1
        || numberOfDays.isMultiple(of: medicine.intervalDays)
}

private func appointmentOccurs(
    _ appointment: CareAppointment,
    on date: Date,
    calendar: Calendar = .current
) -> Bool {
    guard appointment.state == .scheduled else { return false }

    return plannerItemOccurs(
        startDate: appointment.date,
        repeatRule: appointment.repeatRule,
        on: date,
        calendar: calendar
    )
}

private func plannerOtherItemOccurs(
    _ item: PlannerOtherItem,
    on date: Date,
    calendar: Calendar = .current
) -> Bool {
    guard item.active else { return false }

    return plannerItemOccurs(
        startDate: item.date,
        repeatRule: item.repeatRule,
        on: date,
        calendar: calendar
    )
}

private func plannerItemOccurs(
    startDate: Date,
    repeatRule: String,
    on date: Date,
    calendar: Calendar
) -> Bool {
    let start = calendar.startOfDay(for: startDate)
    let target = calendar.startOfDay(for: date)

    guard target >= start else { return false }

    if calendar.isDate(start, inSameDayAs: target) {
        return true
    }

    switch repeatRule {
    case "Every month":
        return calendar.component(.day, from: start)
            == calendar.component(.day, from: target)

    case "Every 3 months":
        let months = calendar.dateComponents(
            [.month],
            from: start,
            to: target
        ).month ?? 0

        return months >= 0
            && months.isMultiple(of: 3)
            && calendar.component(.day, from: start)
                == calendar.component(.day, from: target)

    case "Every year":
        return calendar.component(.month, from: start)
                == calendar.component(.month, from: target)
            && calendar.component(.day, from: start)
                == calendar.component(.day, from: target)

    default:
        return customAppointmentOccurs(
            rule: repeatRule,
            from: start,
            to: target,
            calendar: calendar
        )
    }
}

private func customAppointmentOccurs(
    rule: String,
    from start: Date,
    to target: Date,
    calendar: Calendar
) -> Bool {
    let parts = rule.lowercased().split(separator: " ")

    guard parts.count >= 3,
          parts[0] == "every",
          let interval = Int(parts[1]),
          interval > 0 else {
        return false
    }

    let unit = String(parts[2])

    if unit.hasPrefix("day") || unit.hasPrefix("week") {
        let days = calendar.dateComponents(
            [.day],
            from: start,
            to: target
        ).day ?? 0

        let repeatEveryDays = unit.hasPrefix("week")
            ? interval * 7
            : interval

        return days >= 0 && days.isMultiple(of: repeatEveryDays)
    }

    if unit.hasPrefix("month") {
        let months = calendar.dateComponents(
            [.month],
            from: start,
            to: target
        ).month ?? 0

        return months >= 0
            && months.isMultiple(of: interval)
            && calendar.component(.day, from: start)
                == calendar.component(.day, from: target)
    }

    if unit.hasPrefix("year") {
        let years = calendar.dateComponents(
            [.year],
            from: start,
            to: target
        ).year ?? 0

        return years >= 0
            && years.isMultiple(of: interval)
            && calendar.component(.month, from: start)
                == calendar.component(.month, from: target)
            && calendar.component(.day, from: start)
                == calendar.component(.day, from: target)
    }

    return false
}

private struct PlannerCalendarView: View {
    @Binding var selectedDate: Date
    @Binding var visibleMonth: Date

    let medicines: [Medicine]
    let appointments: [CareAppointment]
    let otherItems: [PlannerOtherItem]

    private let columns = Array(
        repeating: GridItem(.flexible(), spacing: 4),
        count: 7
    )

    private var calendar: Calendar {
        var value = Calendar.current
        value.firstWeekday = 2
        return value
    }

    private var weekdayLabels: [String] {
        ["M", "T", "W", "T", "F", "S", "S"]
    }

    private var monthDates: [Date?] {
        guard let dayRange = calendar.range(of: .day, in: .month, for: visibleMonth),
              let firstDay = calendar.date(
                from: calendar.dateComponents([.year, .month], from: visibleMonth)
              ) else {
            return []
        }

        let weekday = calendar.component(.weekday, from: firstDay)
        let leadingSpaces = (weekday - calendar.firstWeekday + 7) % 7
        var dates = Array<Date?>(repeating: nil, count: leadingSpaces)

        dates.append(contentsOf: dayRange.compactMap { day in
            calendar.date(byAdding: .day, value: day - 1, to: firstDay)
        })

        return dates
    }

    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Button { changeMonth(by: -1) } label: {
                    Image(systemName: "chevron.left")
                        .frame(width: 36, height: 36)
                        .background(
                            Color.secondary.opacity(0.10),
                            in: Circle()
                        )
                }

                Spacer()

                VStack(spacing: 2) {
                    Text(visibleMonth.formatted(.dateTime.month(.wide).year()))
                        .font(.headline)

                    Button("Today") {
                        let today = calendar.startOfDay(for: Date())
                        selectedDate = today
                        visibleMonth = startOfMonth(containing: today)
                    }
                    .font(.caption.weight(.semibold))
                }

                Spacer()

                Button { changeMonth(by: 1) } label: {
                    Image(systemName: "chevron.right")
                        .frame(width: 36, height: 36)
                        .background(
                            Color.secondary.opacity(0.10),
                            in: Circle()
                        )
                }
            }

            LazyVGrid(columns: columns, spacing: 8) {
                ForEach(weekdayLabels.indices, id: \.self) { index in
                    Text(weekdayLabels[index])
                        .font(.caption2.weight(.bold))
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity)
                }

                ForEach(monthDates.indices, id: \.self) { index in
                    if let date = monthDates[index] {
                        calendarDay(date)
                    } else {
                        Color.clear
                            .frame(height: 48)
                    }
                }
            }

            HStack(spacing: 18) {
                calendarLegend(
                    color: RemoteLoveTheme.green,
                    title: "Medicine"
                )

                calendarLegend(
                    color: RemoteLoveTheme.coral,
                    title: "Appointment"
                )

                calendarLegend(
                    color: RemoteLoveTheme.amber,
                    title: "Other"
                )

                Spacer()
            }
        }
        .padding(16)
        .background(
            Color(uiColor: .secondarySystemGroupedBackground),
            in: RoundedRectangle(cornerRadius: 22, style: .continuous)
        )
        .padding(.horizontal)
    }

    private func calendarDay(_ date: Date) -> some View {
        let selected = calendar.isDate(date, inSameDayAs: selectedDate)
        let today = calendar.isDateInToday(date)
        let hasMedicine = medicines.contains {
            medicineOccurs($0, on: date, calendar: calendar)
        }
        let hasAppointment = appointments.contains {
            appointmentOccurs($0, on: date, calendar: calendar)
        }
        let hasOtherItem = otherItems.contains {
            plannerOtherItemOccurs($0, on: date, calendar: calendar)
        }

        return Button {
            selectedDate = calendar.startOfDay(for: date)
        } label: {
            VStack(spacing: 4) {
                Text(String(calendar.component(.day, from: date)))
                    .font(.subheadline.weight(selected ? .bold : .medium))

                HStack(spacing: 3) {
                    Circle()
                        .fill(hasMedicine ? RemoteLoveTheme.green : Color.clear)
                        .frame(width: 5, height: 5)

                    Circle()
                        .fill(hasAppointment ? RemoteLoveTheme.coral : Color.clear)
                        .frame(width: 5, height: 5)

                    Circle()
                        .fill(hasOtherItem ? RemoteLoveTheme.amber : Color.clear)
                        .frame(width: 5, height: 5)
                }
            }
            .foregroundColor(selected ? RemoteLoveTheme.onAccent : .primary)
            .frame(maxWidth: .infinity)
            .frame(height: 44)
            .background(
                selected ? RemoteLoveTheme.green : Color.clear,
                in: RoundedRectangle(cornerRadius: 12, style: .continuous)
            )
            .overlay {
                if today && !selected {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(RemoteLoveTheme.green, lineWidth: 1.5)
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(date.formatted(date: .complete, time: .omitted))
        .accessibilityValue(dayAccessibilityValue(
            hasMedicine: hasMedicine,
            hasAppointment: hasAppointment,
            hasOtherItem: hasOtherItem
        ))
    }

    private func calendarLegend(
        color: Color,
        title: String
    ) -> some View {
        HStack(spacing: 6) {
            Circle()
                .fill(color)
                .frame(width: 7, height: 7)

            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }

    private func dayAccessibilityValue(
        hasMedicine: Bool,
        hasAppointment: Bool,
        hasOtherItem: Bool
    ) -> String {
        var scheduledItems: [String] = []
        if hasMedicine {
            scheduledItems.append("medicine")
        }
        if hasAppointment {
            scheduledItems.append("appointment")
        }
        if hasOtherItem {
            scheduledItems.append("other item")
        }

        if scheduledItems.isEmpty {
            return "No scheduled items"
        }

        return scheduledItems.joined(separator: ", ") + " scheduled"
    }

    private func changeMonth(by amount: Int) {
        guard let newMonth = calendar.date(
            byAdding: .month,
            value: amount,
            to: visibleMonth
        ) else {
            return
        }

        visibleMonth = startOfMonth(containing: newMonth)
        selectedDate = visibleMonth
    }

    private func startOfMonth(containing date: Date) -> Date {
        calendar.date(
            from: calendar.dateComponents([.year, .month], from: date)
        ) ?? date
    }
}

private struct PlannerDayScheduleView: View {
    let date: Date
    let medicines: [Medicine]
    let appointments: [CareAppointment]
    let otherItems: [PlannerOtherItem]
    let onSelectMedicine: (Medicine) -> Void
    let onSelectAppointment: (CareAppointment) -> Void
    let onSelectOtherItem: (PlannerOtherItem) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("SCHEDULE")
                        .font(.caption2.weight(.bold))
                        .foregroundColor(RemoteLoveTheme.green)

                    Text(dayTitle)
                        .font(.title3.weight(.bold))
                }

                Spacer()

                Text("\(itemCount) item\(itemCount == 1 ? "" : "s")")
                    .font(.caption.weight(.semibold))
                    .foregroundColor(.secondary)
            }

            if medicines.isEmpty && appointments.isEmpty && otherItems.isEmpty {
                HStack(spacing: 12) {
                    Image(systemName: "calendar.badge.checkmark")
                        .font(.title2)
                        .foregroundColor(RemoteLoveTheme.green)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Nothing scheduled")
                            .font(.subheadline.weight(.semibold))

                        Text("There are no active medicines, appointments or other items for this day.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.vertical, 6)
            }

            ForEach(appointments) { appointment in
                Button {
                    onSelectAppointment(appointment)
                } label: {
                    scheduleRow(
                        icon: "calendar",
                        color: RemoteLoveTheme.coral,
                        title: appointment.title,
                        time: appointment.date.formatted(
                            date: .omitted,
                            time: .shortened
                        ),
                        detail: appointment.repeatRule
                    )
                }
                .buttonStyle(.plain)
            }

            ForEach(medicines) { medicine in
                Button {
                    onSelectMedicine(medicine)
                } label: {
                    scheduleRow(
                        icon: "pills.fill",
                        color: RemoteLoveTheme.green,
                        title: medicine.name,
                        time: medicineTimeSummary(medicine),
                        detail: medicineSchedule(medicine)
                    )
                }
                .buttonStyle(.plain)
            }

            ForEach(otherItems) { item in
                Button {
                    onSelectOtherItem(item)
                } label: {
                    scheduleRow(
                        icon: "square.grid.2x2.fill",
                        color: RemoteLoveTheme.amber,
                        title: item.title,
                        time: item.date.formatted(
                            date: .omitted,
                            time: .shortened
                        ),
                        detail: item.repeatRule
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(16)
        .background(
            Color(uiColor: .secondarySystemGroupedBackground),
            in: RoundedRectangle(cornerRadius: 22, style: .continuous)
        )
        .padding(.horizontal)
    }

    private var dayTitle: String {
        if Calendar.current.isDateInToday(date) {
            return "Today · " + date.formatted(
                .dateTime.weekday(.wide).day().month(.wide)
            )
        }

        return date.formatted(
            .dateTime.weekday(.wide).day().month(.wide)
        )
    }

    private var itemCount: Int {
        medicines.count + appointments.count + otherItems.count
    }

    private func medicineSchedule(_ medicine: Medicine) -> String {
        let timeCount = medicine.scheduledDoseTimes.count
        if let weekdays = medicine.repeatWeekdays, weekdays.isEmpty == false {
            return "\(medicine.dose.formatted()) \(medicine.unit) · \(timeCount)× \(weekdaySummary(for: weekdays))"
        }

        if medicine.intervalDays > 1 {
            return "\(medicine.dose.formatted()) \(medicine.unit) · \(timeCount)× every \(medicine.intervalDays) days"
        }

        return "\(medicine.dose.formatted()) \(medicine.unit) · \(timeCount)× daily"
    }

    private func medicineTimeSummary(_ medicine: Medicine) -> String {
        medicine.scheduledDoseTimes
            .prefix(3)
            .map { $0.formatted(date: .omitted, time: .shortened) }
            .joined(separator: ", ")
    }

    private func scheduleRow(
        icon: String,
        color: Color,
        title: String,
        time: String,
        detail: String
    ) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(color)
                .frame(width: 36, height: 36)
                .background(color.opacity(0.12), in: Circle())

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(.primary)

                Text(detail)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            Text(time)
                .font(.caption.weight(.semibold))
                .foregroundColor(.secondary)

            Image(systemName: "chevron.right")
                .font(.caption.weight(.bold))
                .foregroundColor(.secondary)
        }
        .padding(12)
        .background(
            Color(uiColor: .tertiarySystemGroupedBackground),
            in: RoundedRectangle(cornerRadius: 15, style: .continuous)
        )
    }
}

struct MedicineCard: View {
    @EnvironmentObject private var store: RemoteLoveStore
    let medicine: Medicine
    let onEdit: (() -> Void)?

    private var needsAttention: Bool {
        medicine.active && medicine.daysRemaining <= medicine.attentionDays
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "pills.fill").foregroundColor(medicine.active ? RemoteLoveTheme.green : .secondary)
                VStack(alignment: .leading) {
                    Text(medicine.name).font(.headline)
                    Text(medicine.purpose).font(.caption).foregroundColor(.secondary)
                }
                Spacer()
                VStack(alignment: .trailing) {
                    Text(medicine.currentSupply.formatted()).font(.headline)
                    Text("\(medicine.unit) left").font(.caption).foregroundColor(.secondary)
                }
            }
            Text(medicineSummary)
                .font(.subheadline)
            HStack {
                if store.canEditCareRecords {
                    Toggle(medicine.active ? "Active" : "Paused", isOn: Binding(get: { medicine.active }, set: { _ in store.toggleMedicine(medicine.id) }))
                } else {
                    Label(medicine.active ? "Active" : "Paused", systemImage: medicine.active ? "checkmark.circle.fill" : "pause.circle.fill")
                        .font(.caption.weight(.semibold))
                        .foregroundColor(medicine.active ? RemoteLoveTheme.green : .secondary)
                }
                Spacer()
                if let onEdit {
                    Button("Edit", action: onEdit).font(.subheadline.bold())
                }
            }
        }
        .padding(16)
        .background(.background, in: RoundedRectangle(cornerRadius: 20))
        .padding(.horizontal)
        .opacity(medicine.active ? 1 : 0.65)
    }

    private var medicineSummary: String {
        let count = medicine.scheduledDoseTimes.count
        let repeatText: String
        if let weekdays = medicine.repeatWeekdays, weekdays.isEmpty == false {
            repeatText = weekdaySummary(for: weekdays)
        } else {
            repeatText = medicine.intervalDays > 1 ? "every \(medicine.intervalDays) days" : "daily"
        }
        let times = medicine.scheduledDoseTimes
            .prefix(3)
            .map { $0.formatted(date: .omitted, time: .shortened) }
            .joined(separator: ", ")
        return "\(medicine.dose.formatted()) \(medicine.unit) · \(count)× \(repeatText) · \(times)"
    }
}

private struct MedicineSupplyWheelCard: View {
    @Binding var currentSupply: Int
    @Binding var dose: Double
    let unit: String

    private let doseOptions = stride(from: 0.5, through: 10.0, by: 0.5).map { $0 }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("Supply and dose", systemImage: "pills.fill")
                .font(.subheadline.weight(.semibold))
                .foregroundColor(RemoteLoveTheme.green)

            HStack(spacing: 14) {
                wheelColumn(
                    title: "Current supply",
                    value: currentSupply.formatted(),
                    unit: unit
                ) {
                    Picker("Current supply", selection: $currentSupply) {
                        ForEach(0...365, id: \.self) { amount in
                            Text("\(amount)").tag(amount)
                        }
                    }
                    .pickerStyle(.wheel)
                }

                wheelColumn(
                    title: "Dose each time",
                    value: dose.formatted(),
                    unit: unit
                ) {
                    Picker("Dose each time", selection: $dose) {
                        ForEach(doseOptions, id: \.self) { amount in
                            Text(amount.formatted()).tag(amount)
                        }
                    }
                    .pickerStyle(.wheel)
                }
            }

            Text("Use the unit below if this medicine is measured in ml, drops, puffs or another format.")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(14)
        .background(Color.secondary.opacity(0.07), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func wheelColumn<Content: View>(
        title: String,
        value: String,
        unit: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(spacing: 6) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            Text("\(value) \(unit)")
                .font(.caption.bold())
                .foregroundColor(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
            content()
                .frame(height: 112)
                .clipped()
        }
        .frame(maxWidth: .infinity)
    }
}

struct MedicineEditorView: View {
    @EnvironmentObject private var store: RemoteLoveStore
    @Environment(\.dismiss) private var dismiss
    @State private var draft: Medicine
    @State private var repeatOption: String
    @State private var customInterval: Int
    @State private var selectedWeekdays: Set<Int>
    @State private var doseTimes: [Date]
    @State private var autoDoseTimes: Bool
    @State private var autoDoseSpacingHours: Int
    @State private var autoDoseSpacingMinutes: Int
    @State private var selectedUnitPreset: String
    @State private var reminderEnabled: Bool
    @State private var reminderTiming: ReminderTimingOption = .atTime
    @State private var reminderCustomDaysBefore = 0
    @State private var reminderTime: Date
    @State private var reminderRepeat: ReminderRepeatOption = .everyDay
    @State private var reminderRecipient: ReminderRecipientOption = .everyone

    init(medicine: Medicine) {
        _draft = State(initialValue: medicine)
        _repeatOption = State(
            initialValue: medicine.intervalDays > 1
                || (medicine.repeatWeekdays?.isEmpty == false)
                ? "Custom"
                : "Every day"
        )
        _customInterval = State(
            initialValue: max(2, medicine.intervalDays)
        )
        _selectedWeekdays = State(initialValue: Set(medicine.repeatWeekdays ?? []))
        _doseTimes = State(initialValue: Self.initialDoseTimes(for: medicine))
        let schedule = Self.inferredDoseSchedule(for: medicine)
        _autoDoseTimes = State(initialValue: schedule.isAutomatic)
        _autoDoseSpacingHours = State(initialValue: schedule.spacingHours)
        _autoDoseSpacingMinutes = State(initialValue: schedule.spacingMinutes)
        _selectedUnitPreset = State(initialValue: Self.unitPresets.contains(medicine.unit) ? medicine.unit : "Custom")
        _reminderEnabled = State(initialValue: medicine.active)
        _reminderTime = State(initialValue: medicine.firstTime)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    EditorProfileContextCard(
                        profileName: store.selectedRecipient.name,
                        profileLabel: store.selectedRecipient.label,
                        action: draft.name.isEmpty ? "Adding medicine for" : "Editing medicine for"
                    )
                    EditorSetupSummaryCard(
                        title: "Keep medicine timing simple",
                        detail: "Add the name, supply and dose times first. Reminders and refill alerts use the schedule you set below.",
                        icon: "pills.fill"
                    )
                }

                Section {
                    VStack(alignment: .leading, spacing: 18) {
                        editorTextField(
                            title: "Medicine name",
                            icon: "pills.fill",
                            placeholder: "e.g. Amlodipine",
                            text: $draft.name
                        )

                        RecentSuggestionChips(title: "Recent medicines", suggestions: recentMedicineNames) { suggestion in
                            draft.name = suggestion
                            if let match = store.medicines.first(where: { $0.name == suggestion }) {
                                draft.purpose = match.purpose
                                draft.instructions = match.instructions
                                draft.unit = match.unit
                                draft.dose = match.dose
                            }
                        }

                        editorTextField(
                            title: "Purpose",
                            icon: "heart.text.square",
                            placeholder: "e.g. Blood pressure",
                            text: $draft.purpose
                        )

                        VStack(alignment: .leading, spacing: 8) {
                            Label(
                                "Instructions",
                                systemImage: "list.bullet.rectangle"
                            )
                            .font(.subheadline.weight(.semibold))
                            .foregroundColor(RemoteLoveTheme.green)

                            TextField(
                                "Add dosage or food instructions...",
                                text: $draft.instructions,
                                axis: .vertical
                            )
                            .lineLimit(3...6)
                            .padding(14)
                            .background(
                                Color.secondary.opacity(0.08),
                                in: RoundedRectangle(
                                    cornerRadius: 14,
                                    style: .continuous
                                )
                            )

                            Text("Optional")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.vertical, 8)

                } header: {
                    editorSectionHeader(
                        eyebrow: "MEDICINE DETAILS",
                        title: "What medicine is being taken?"
                    )

                } footer: {
                    Text(
                        "Use the medicine label and the instructions provided by their healthcare professional."
                    )
                }

                Section {
                    MedicineSupplyWheelCard(
                        currentSupply: currentSupplyBinding,
                        dose: doseBinding,
                        unit: draft.unit
                    )

                    medicineUnitPicker

                } header: {
                    editorSectionHeader(
                        eyebrow: "SUPPLY",
                        title: "How much is available?"
                    )
                }

                Section {
                    Picker("Repeat", selection: $repeatOption) {
                        Text("Every day").tag("Every day")
                        Text("Custom").tag("Custom")
                    }
                    .pickerStyle(.menu)

                    Picker("Times per due day", selection: $draft.timesDaily) {
                        ForEach(1...8, id: \.self) { count in
                            Text("\(count)").tag(count)
                        }
                    }
                    .pickerStyle(.segmented)
                    .onChange(of: draft.timesDaily) { _, _ in
                        syncDoseTimeCount()
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        Text(draft.timesDaily == 1 ? "Medicine time" : "Medicine times")
                            .font(.subheadline.weight(.semibold))
                            .foregroundColor(RemoteLoveTheme.green)

                        DatePicker(
                            draft.timesDaily == 1 ? "Dose time" : "First dose",
                            selection: firstDoseBinding,
                            displayedComponents: .hourAndMinute
                        )

                        if draft.timesDaily > 1 {
                            Toggle("Auto-calculate the remaining dose times", isOn: $autoDoseTimes)
                                .onChange(of: autoDoseTimes) { _, enabled in
                                    if enabled {
                                        rebuildAutomaticDoseTimes()
                                    }
                                }

                            if autoDoseTimes {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Spacing between doses")
                                        .font(.caption.weight(.semibold))
                                        .foregroundColor(.secondary)
                                    HStack {
                                        Stepper(
                                            "\(autoDoseSpacingHours) hr",
                                            value: $autoDoseSpacingHours,
                                            in: 0...12
                                        )
                                        Stepper(
                                            "\(autoDoseSpacingMinutes) min",
                                            value: $autoDoseSpacingMinutes,
                                            in: 0...55,
                                            step: 5
                                        )
                                    }
                                }
                                .onChange(of: autoDoseSpacingHours) { _, _ in rebuildAutomaticDoseTimes() }
                                .onChange(of: autoDoseSpacingMinutes) { _, _ in rebuildAutomaticDoseTimes() }

                                VStack(alignment: .leading, spacing: 6) {
                                    ForEach(doseTimes.indices, id: \.self) { index in
                                        Label(
                                            "Dose \(index + 1): \(doseTimes[index].formatted(date: .omitted, time: .shortened))",
                                            systemImage: index == 0 ? "1.circle.fill" : "\(index + 1).circle"
                                        )
                                        .font(.caption.weight(.semibold))
                                        .foregroundColor(index == 0 ? RemoteLoveTheme.green : .secondary)
                                    }
                                }
                            } else {
                                ForEach(doseTimes.indices, id: \.self) { index in
                                    DatePicker(
                                        "Dose \(index + 1)",
                                        selection: doseTimeBinding(for: index),
                                        displayedComponents: .hourAndMinute
                                    )
                                }
                            }
                        }

                        Text(autoDoseTimes && draft.timesDaily > 1 ? "RemoteLove calculates the later doses from the first dose and interval. Turn this off to set each time manually." : "These are the exact times RemoteLove will show in Planner and use for medicine reminders.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(14)
                    .background(Color.secondary.opacity(0.07), in: RoundedRectangle(cornerRadius: 16, style: .continuous))

                } header: {
                    editorSectionHeader(
                        eyebrow: "SCHEDULE",
                        title: "When should it be taken?"
                    )
                }

                if repeatOption == "Custom" {
                    Section {
                        Stepper(
                            "Every \(customInterval) day\(customInterval == 1 ? "" : "s")",
                            value: $customInterval,
                            in: 2...30
                        )

                        VStack(alignment: .leading, spacing: 10) {
                            Text("Or choose due days")
                                .font(.subheadline.weight(.semibold))
                                .foregroundColor(RemoteLoveTheme.green)

                            LazyVGrid(columns: Self.weekdayColumns, spacing: 8) {
                                ForEach(Self.weekdayOptions, id: \.value) { weekday in
                                    Button {
                                        toggleWeekday(weekday.value)
                                    } label: {
                                        Text(weekday.short)
                                            .font(.caption.weight(.bold))
                                            .frame(maxWidth: .infinity)
                                            .padding(.vertical, 10)
                                            .foregroundColor(selectedWeekdays.contains(weekday.value) ? RemoteLoveTheme.onAccent : RemoteLoveTheme.green)
                                            .background(
                                                selectedWeekdays.contains(weekday.value)
                                                    ? RemoteLoveTheme.green
                                                    : RemoteLoveTheme.green.opacity(0.12),
                                                in: RoundedRectangle(cornerRadius: 12, style: .continuous)
                                            )
                                    }
                                    .buttonStyle(.plain)
                                    .accessibilityLabel(weekday.name)
                                    .accessibilityAddTraits(selectedWeekdays.contains(weekday.value) ? .isSelected : [])
                                }
                            }

                            Text(customRepeatSummary)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(.top, 6)

                    } header: {
                        Text("Custom repeat")

                    } footer: {
                        Text(
                            selectedWeekdays.isEmpty
                                ? "This medicine will appear every \(customInterval) days while its schedule is active and supply remains."
                                : "Selected weekdays override the every-\(customInterval)-days pattern."
                        )
                    }
                }

                Section {
                    ReminderSettingsCard(
                        itemName: draft.name,
                        scheduledAt: draft.firstTime,
                        isEnabled: $reminderEnabled,
                        timing: $reminderTiming,
                        customDaysBefore: $reminderCustomDaysBefore,
                        customTime: $reminderTime,
                        repeatOption: $reminderRepeat,
                        recipient: $reminderRecipient
                    )
                } header: {
                    Text("Reminder")
                } footer: {
                    Text("Medicine reminders follow the medicine schedule and active status.")
                }

                Section {
                    Stepper(
                        "Refill alert at \(draft.attentionDays) days left",
                        value: $draft.attentionDays,
                        in: 1...60
                    )

                    Toggle("Active schedule", isOn: $draft.active)

                } header: {
                    Text("Status")

                } footer: {
                    Text(
                        draft.active
                            ? "This medicine appears in the Planner calendar and helper schedule."
                            : "A paused medicine is hidden from the calendar and helper schedule."
                    )
                }

                Section {
                    Button {
                        saveMedicine()
                    } label: {
                        HStack {
                            Spacer()
                            Label(
                                "Save medicine",
                                systemImage: "checkmark.circle.fill"
                            )
                            .fontWeight(.semibold)
                            Spacer()
                        }
                    }
                    .disabled(
                        draft.name
                            .trimmingCharacters(in: .whitespacesAndNewlines)
                            .isEmpty
                    )
                    .buttonStyle(PrimaryButtonStyle())
                }
            }
            .navigationTitle(draft.name.isEmpty ? "Add medicine" : "Edit medicine")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } } }
        }
    }

    private func saveMedicine() {
        syncDoseTimeCount()
        draft.intervalDays = repeatOption == "Custom"
            ? customInterval
            : 1
        draft.repeatWeekdays = repeatOption == "Custom" && selectedWeekdays.isEmpty == false
            ? Array(selectedWeekdays).sorted()
            : nil
        draft.doseTimes = normalizedDoseTimes
        draft.timesDaily = max(normalizedDoseTimes.count, 1)
        draft.firstTime = normalizedDoseTimes.first ?? draft.firstTime

        store.saveMedicine(draft)
        dismiss()
    }

    private var currentSupplyBinding: Binding<Int> {
        Binding(
            get: { max(0, Int(draft.currentSupply.rounded())) },
            set: { draft.currentSupply = Double($0) }
        )
    }

    private var doseBinding: Binding<Double> {
        Binding(
            get: { draft.dose },
            set: { draft.dose = $0 }
        )
    }

    private var medicineUnitPicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Unit", systemImage: "number")
                .font(.subheadline.weight(.semibold))
                .foregroundColor(RemoteLoveTheme.green)

            Picker("Unit", selection: $selectedUnitPreset) {
                ForEach(Self.unitPresets, id: \.self) { unit in
                    Text(unit).tag(unit)
                }
                Text("Custom").tag("Custom")
            }
            .pickerStyle(.wheel)
            .frame(height: 118)
            .clipped()
            .onChange(of: selectedUnitPreset) { _, unit in
                if unit != "Custom" {
                    draft.unit = unit
                }
            }

            if selectedUnitPreset == "Custom" {
                editorTextField(
                    title: "Custom unit",
                    icon: "pencil",
                    placeholder: "e.g. sachets, sprays",
                    text: $draft.unit
                )
            }
        }
    }

    private var normalizedDoseTimes: [Date] {
        doseTimes
            .prefix(max(draft.timesDaily, 1))
            .sorted { $0 < $1 }
    }

    private var firstDoseBinding: Binding<Date> {
        Binding(
            get: { doseTimes.first ?? draft.firstTime },
            set: { newValue in
                if doseTimes.isEmpty {
                    doseTimes = [newValue]
                } else {
                    doseTimes[0] = newValue
                }
                draft.firstTime = newValue
                if autoDoseTimes {
                    rebuildAutomaticDoseTimes()
                }
            }
        )
    }

    private func doseTimeBinding(for index: Int) -> Binding<Date> {
        Binding(
            get: {
                guard doseTimes.indices.contains(index) else { return Date() }
                return doseTimes[index]
            },
            set: { newValue in
                guard doseTimes.indices.contains(index) else { return }
                doseTimes[index] = newValue
            }
        )
    }

    private func syncDoseTimeCount() {
        let expectedCount = max(draft.timesDaily, 1)
        if doseTimes.isEmpty {
            doseTimes = [draft.firstTime]
        }

        if autoDoseTimes {
            rebuildAutomaticDoseTimes()
            return
        }

        while doseTimes.count < expectedCount {
            let base = doseTimes.last ?? draft.firstTime
            let next = Calendar.current.date(byAdding: .hour, value: 4, to: base) ?? base
            doseTimes.append(next)
        }

        if doseTimes.count > expectedCount {
            doseTimes = Array(doseTimes.prefix(expectedCount))
        }
    }

    private func rebuildAutomaticDoseTimes() {
        let firstDose = doseTimes.first ?? draft.firstTime
        let expectedCount = max(draft.timesDaily, 1)
        let spacingMinutes = max((autoDoseSpacingHours * 60) + autoDoseSpacingMinutes, 5)
        doseTimes = (0..<expectedCount).map { index in
            Calendar.current.date(byAdding: .minute, value: index * spacingMinutes, to: firstDose) ?? firstDose
        }
    }

    private static func initialDoseTimes(for medicine: Medicine) -> [Date] {
        let times = medicine.scheduledDoseTimes
        return times.isEmpty ? [medicine.firstTime] : times
    }

    private static func inferredDoseSchedule(for medicine: Medicine) -> (isAutomatic: Bool, spacingHours: Int, spacingMinutes: Int) {
        let times = initialDoseTimes(for: medicine).sorted()
        guard times.count > 1 else { return (true, 4, 0) }

        let calendar = Calendar.current
        let minuteSpacings = zip(times, times.dropFirst()).compactMap { earlier, later in
            calendar.dateComponents([.minute], from: earlier, to: later).minute
        }

        guard let firstSpacing = minuteSpacings.first,
              (5...720).contains(firstSpacing),
              minuteSpacings.allSatisfy({ $0 == firstSpacing }) else {
            return (false, 4, 0)
        }

        return (true, firstSpacing / 60, firstSpacing % 60)
    }

    private static let unitPresets = [
        "tablets",
        "capsules",
        "ml",
        "mg",
        "drops",
        "puffs",
        "patches",
        "sachets",
        "sprays",
        "units"
    ]

    private var recentMedicineNames: [String] {
        uniqueRecent(store.medicines.map(\.name), excluding: draft.name)
    }

    private var customRepeatSummary: String {
        guard selectedWeekdays.isEmpty == false else {
            return "No weekdays selected, so RemoteLove uses every \(customInterval) days."
        }

        return "Due on \(weekdaySummary(for: Array(selectedWeekdays).sorted()))."
    }

    private func toggleWeekday(_ weekday: Int) {
        if selectedWeekdays.contains(weekday) {
            selectedWeekdays.remove(weekday)
        } else {
            selectedWeekdays.insert(weekday)
        }
    }

    private static let weekdayColumns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 4)

    private static let weekdayOptions: [(value: Int, short: String, name: String)] = [
        (2, "Mon", "Monday"),
        (3, "Tue", "Tuesday"),
        (4, "Wed", "Wednesday"),
        (5, "Thu", "Thursday"),
        (6, "Fri", "Friday"),
        (7, "Sat", "Saturday"),
        (1, "Sun", "Sunday")
    ]
}

private func weekdaySummary(for weekdays: [Int]) -> String {
    let orderedNames: [(value: Int, short: String)] = [
        (2, "Mon"),
        (3, "Tue"),
        (4, "Wed"),
        (5, "Thu"),
        (6, "Fri"),
        (7, "Sat"),
        (1, "Sun")
    ]
    let names = orderedNames
        .filter { weekdays.contains($0.value) }
        .map(\.short)

    guard names.isEmpty == false else { return "custom days" }
    return names.joined(separator: ", ")
}

struct AppointmentCard: View {
    let appointment: CareAppointment
    let onEdit: (() -> Void)?

    var body: some View {
        Button(action: { onEdit?() }) {
            HStack(spacing: 14) {
                VStack {
                    Text(appointment.date.formatted(.dateTime.month(.abbreviated))).font(.caption.bold())
                    Text(appointment.date.formatted(.dateTime.day())).font(.title2.bold())
                }
                .frame(width: 54, height: 58)
                .background(RemoteLoveTheme.green.opacity(0.12), in: RoundedRectangle(cornerRadius: 14))
                VStack(alignment: .leading, spacing: 4) {
                    Text(appointment.title).font(.headline).foregroundColor(.primary)
                    Text(appointment.date.formatted(date: .omitted, time: .shortened)).font(.subheadline).foregroundColor(.secondary)
                    if appointment.reminderEnabled {
                        Label(appointmentReminderLabel, systemImage: "bell.fill")
                            .font(.caption)
                            .foregroundColor(RemoteLoveTheme.green)
                    }
                }
                Spacer()
                if onEdit != nil {
                    Image(systemName: "chevron.right").foregroundColor(.secondary)
                }
            }
            .padding(16)
            .background(.background, in: RoundedRectangle(cornerRadius: 20))
            .padding(.horizontal)
            .opacity(appointment.state == .scheduled ? 1 : 0.5)
        }
        .disabled(onEdit == nil)
    }

    private var appointmentReminderLabel: String {
        let days = max(0, appointment.reminderDaysBefore)
        let reminders = max(1, appointment.reminderCount)
        guard days > 0 else { return "\(reminders) reminder\(reminders == 1 ? "" : "s") before appointment" }

        let dayLabel = days == 1 ? "1 day" : "\(days) days"
        if reminders == 1 {
            return "Reminder \(dayLabel) before"
        }

        return "\(reminders) reminders from \(dayLabel) before"
    }
}

struct PlannerOtherItemCard: View {
    let item: PlannerOtherItem
    let onEdit: (() -> Void)?

    var body: some View {
        Button(action: { onEdit?() }) {
            HStack(spacing: 14) {
                VStack {
                    Text(item.date.formatted(.dateTime.month(.abbreviated))).font(.caption.bold())
                    Text(item.date.formatted(.dateTime.day())).font(.title2.bold())
                }
                .frame(width: 54, height: 58)
                .background(RemoteLoveTheme.amber.opacity(0.14), in: RoundedRectangle(cornerRadius: 14))

                VStack(alignment: .leading, spacing: 4) {
                    Text(item.title).font(.headline).foregroundColor(.primary)
                    Text(item.date.formatted(date: .omitted, time: .shortened)).font(.subheadline).foregroundColor(.secondary)
                    if !item.notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        Text(item.notes).font(.caption).foregroundColor(.secondary).lineLimit(2)
                    }
                    Label(item.repeatRule, systemImage: "square.grid.2x2.fill")
                        .font(.caption)
                        .foregroundColor(RemoteLoveTheme.amber)
                }

                Spacer()

                if onEdit != nil {
                    Image(systemName: "chevron.right").foregroundColor(.secondary)
                }
            }
            .padding(16)
            .background(.background, in: RoundedRectangle(cornerRadius: 20))
            .padding(.horizontal)
            .opacity(item.active ? 1 : 0.5)
        }
        .disabled(onEdit == nil)
    }
}

struct AppointmentEditorView: View {
    @EnvironmentObject private var store: RemoteLoveStore
    @Environment(\.dismiss) private var dismiss
    @State private var draft: CareAppointment
    @State private var confirmRemove = false
    @State private var repeatOption: String
    @State private var customInterval: Int
    @State private var customUnit: String
    @State private var reminderTiming: ReminderTimingOption
    @State private var reminderCustomDaysBefore: Int
    @State private var reminderTime: Date
    @State private var reminderRepeat: ReminderRepeatOption
    @State private var reminderRecipient: ReminderRecipientOption = .everyone

    init(appointment: CareAppointment) {
        _draft = State(initialValue: appointment)

        let standardRules = [
            "Does not repeat",
            "Every month",
            "Every 3 months",
            "Every year"
        ]

        let isStandard = standardRules.contains(appointment.repeatRule)
        _repeatOption = State(
            initialValue: isStandard
                ? appointment.repeatRule
                : "Custom"
        )

        let custom = Self.customRuleValues(
            from: appointment.repeatRule
        )
        _customInterval = State(initialValue: custom.interval)
        _customUnit = State(initialValue: custom.unit)
        _reminderTiming = State(initialValue: Self.timingOption(daysBefore: appointment.reminderDaysBefore))
        _reminderCustomDaysBefore = State(initialValue: appointment.reminderDaysBefore)
        _reminderTime = State(initialValue: appointment.date)
        _reminderRepeat = State(initialValue: appointment.reminderCount > 1 ? .everyDay : .none)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    EditorProfileContextCard(
                        profileName: store.selectedRecipient.name,
                        profileLabel: store.selectedRecipient.label,
                        action: draft.title.isEmpty ? "Adding appointment for" : "Editing appointment for"
                    )
                    EditorSetupSummaryCard(
                        title: "Plan the visit clearly",
                        detail: "Add the appointment name, time, preparation notes and reminders so everyone knows what is coming up.",
                        icon: "calendar.badge.clock"
                    )
                }

                Section {
                    VStack(alignment: .leading, spacing: 18) {
                        editorTextField(
                            title: "Appointment name",
                            icon: "calendar",
                            placeholder: "e.g. Blood pressure review",
                            text: $draft.title
                        )

                        RecentSuggestionChips(title: "Recent appointments", suggestions: recentAppointmentTitles) { suggestion in
                            draft.title = suggestion
                            if let match = store.appointments.first(where: { $0.title == suggestion }) {
                                draft.notes = match.notes
                            }
                        }

                        VStack(alignment: .leading, spacing: 8) {
                            Label(
                                "Notes",
                                systemImage: "list.bullet.rectangle"
                            )
                            .font(.subheadline.weight(.semibold))
                            .foregroundColor(RemoteLoveTheme.green)

                            TextField(
                                "What should the family or helper prepare?",
                                text: $draft.notes,
                                axis: .vertical
                            )
                            .lineLimit(3...6)
                            .padding(14)
                            .background(
                                Color.secondary.opacity(0.08),
                                in: RoundedRectangle(
                                    cornerRadius: 14,
                                    style: .continuous
                                )
                            )

                            Text("Optional")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.vertical, 8)

                } header: {
                    editorSectionHeader(
                        eyebrow: "APPOINTMENT DETAILS",
                        title: "What is the appointment for?"
                    )

                } footer: {
                    Text(
                        "Add preparation notes such as documents, medicine lists or recent readings to bring."
                    )
                }

                Section {
                    DatePicker(
                        "Date and time",
                        selection: $draft.date
                    )

                    Picker("Repeat", selection: $repeatOption) {
                        Text("Does not repeat").tag("Does not repeat")
                        Text("Every month").tag("Every month")
                        Text("Every 3 months").tag("Every 3 months")
                        Text("Every year").tag("Every year")
                        Text("Custom").tag("Custom")
                    }

                } header: {
                    editorSectionHeader(
                        eyebrow: "SCHEDULE",
                        title: "When should it happen?"
                    )
                }

                if repeatOption == "Custom" {
                    Section {
                        Stepper(
                            "Every \(customInterval) \(customUnitLabel)",
                            value: $customInterval,
                            in: 1...52
                        )

                        Picker("Repeat by", selection: $customUnit) {
                            Text("Days").tag("Days")
                            Text("Weeks").tag("Weeks")
                            Text("Months").tag("Months")
                            Text("Years").tag("Years")
                        }
                        .pickerStyle(.segmented)

                    } header: {
                        Text("Custom repeat")

                    } footer: {
                        Text(
                            "This appointment repeats every \(customInterval) \(customUnitLabel)."
                        )
                    }
                }

                Section {
                    ReminderSettingsCard(
                        itemName: draft.title,
                        scheduledAt: draft.date,
                        isEnabled: $draft.reminderEnabled,
                        timing: $reminderTiming,
                        customDaysBefore: $reminderCustomDaysBefore,
                        customTime: $reminderTime,
                        repeatOption: $reminderRepeat,
                        recipient: $reminderRecipient
                    )
                } header: {
                    Text("Reminder")
                } footer: {
                    Text("Appointment reminders are saved with this appointment and used for scheduled notifications.")
                }

                Section {
                    Button {
                        saveAppointment()
                    } label: {
                        HStack {
                            Spacer()
                            Label(
                                "Save appointment",
                                systemImage: "checkmark.circle.fill"
                            )
                            .fontWeight(.semibold)
                            Spacer()
                        }
                    }
                    .disabled(
                        draft.title
                            .trimmingCharacters(in: .whitespacesAndNewlines)
                            .isEmpty
                    )
                    .buttonStyle(PrimaryButtonStyle())

                    Button(
                        draft.state == .scheduled
                            ? "Cancel appointment"
                            : "Restore appointment"
                    ) {
                        draft.state = draft.state == .scheduled
                            ? .cancelled
                            : .scheduled
                    }

                    Button(
                        "Remove appointment",
                        role: .destructive
                    ) {
                        confirmRemove = true
                    }
                }
            }
            .navigationTitle(draft.title.isEmpty ? "Add appointment" : "Edit appointment")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Close") { dismiss() } } }
            .confirmationDialog("Remove this appointment?", isPresented: $confirmRemove, titleVisibility: .visible) {
                Button("Remove appointment", role: .destructive) { store.removeAppointment(draft.id); dismiss() }
            }
        }
    }

    private var customUnitLabel: String {
        if customInterval == 1 {
            return String(customUnit.lowercased().dropLast())
        }

        return customUnit.lowercased()
    }

    private var recentAppointmentTitles: [String] {
        uniqueRecent(store.appointments.map(\.title), excluding: draft.title)
    }

    private func saveAppointment() {
        if repeatOption == "Custom" {
            draft.repeatRule = "Every \(customInterval) \(customUnitLabel)"
        } else {
            draft.repeatRule = repeatOption
        }

        draft.reminderDaysBefore = max(0, resolvedReminderDaysBefore)
        draft.reminderCount = reminderRepeat == .none ? 1 : max(2, draft.reminderCount)
        draft.remindThreeDaysBefore = draft.reminderEnabled && draft.reminderDaysBefore == 3
        store.saveAppointment(draft)
        dismiss()
    }

    private var resolvedReminderDaysBefore: Int {
        switch reminderTiming {
        case .oneDayBefore:
            return 1
        case .threeDaysBefore:
            return 3
        case .custom:
            return reminderCustomDaysBefore
        default:
            return 0
        }
    }

    private static func timingOption(daysBefore: Int) -> ReminderTimingOption {
        switch daysBefore {
        case 1:
            return .oneDayBefore
        case 3:
            return .threeDaysBefore
        case 0:
            return .atTime
        default:
            return .custom
        }
    }

    private static func customRuleValues(
        from rule: String
    ) -> (interval: Int, unit: String) {
        let parts = rule.split(separator: " ")

        guard parts.count >= 3,
              let interval = Int(parts[1]) else {
            return (1, "Weeks")
        }

        let unit = String(parts[2]).lowercased()
        let displayUnit: String

        if unit.hasPrefix("day") {
            displayUnit = "Days"
        } else if unit.hasPrefix("month") {
            displayUnit = "Months"
        } else if unit.hasPrefix("year") {
            displayUnit = "Years"
        } else {
            displayUnit = "Weeks"
        }

        return (max(1, interval), displayUnit)
    }
}

struct PlannerOtherItemEditorView: View {
    @EnvironmentObject private var store: RemoteLoveStore
    @Environment(\.dismiss) private var dismiss
    @State private var draft: PlannerOtherItem
    @State private var confirmRemove = false
    @State private var repeatOption: String
    @State private var customInterval: Int
    @State private var customUnit: String
    @State private var reminderEnabled = true
    @State private var reminderTiming: ReminderTimingOption = .oneHourBefore
    @State private var reminderCustomDaysBefore = 0
    @State private var reminderTime: Date
    @State private var reminderRepeat: ReminderRepeatOption = .none
    @State private var reminderRecipient: ReminderRecipientOption = .everyone

    init(item: PlannerOtherItem) {
        _draft = State(initialValue: item)
        _reminderEnabled = State(initialValue: item.active)
        _reminderTime = State(initialValue: item.date)

        let standardRules = [
            "Does not repeat",
            "Every day",
            "Every week",
            "Every month",
            "Every year"
        ]
        let isStandard = standardRules.contains(item.repeatRule)
        _repeatOption = State(initialValue: isStandard ? item.repeatRule : "Custom")

        let custom = Self.customRuleValues(from: item.repeatRule)
        _customInterval = State(initialValue: custom.interval)
        _customUnit = State(initialValue: custom.unit)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    EditorProfileContextCard(
                        profileName: store.selectedRecipient.name,
                        profileLabel: store.selectedRecipient.label,
                        action: draft.title.isEmpty ? "Adding planner item for" : "Editing planner item for"
                    )
                    EditorSetupSummaryCard(
                        title: "Capture anything else",
                        detail: "Use this for errands, documents, equipment or preparation notes that should appear in the shared Planner.",
                        icon: "square.grid.2x2.fill"
                    )
                }

                Section {
                    VStack(alignment: .leading, spacing: 18) {
                        editorTextField(
                            title: "Item name",
                            icon: "square.grid.2x2.fill",
                            placeholder: "e.g. Bring insurance card",
                            text: $draft.title
                        )

                        RecentSuggestionChips(title: "Recent items", suggestions: recentOtherItemTitles) { suggestion in
                            draft.title = suggestion
                            if let match = store.plannerOtherItems.first(where: { $0.title == suggestion }) {
                                draft.notes = match.notes
                            }
                        }

                        VStack(alignment: .leading, spacing: 8) {
                            Label("Notes", systemImage: "note.text")
                                .font(.subheadline.weight(.semibold))
                                .foregroundColor(RemoteLoveTheme.green)

                            TextField("Add details the care circle should know", text: $draft.notes, axis: .vertical)
                                .lineLimit(3...6)
                                .padding(14)
                                .background(
                                    Color.secondary.opacity(0.08),
                                    in: RoundedRectangle(cornerRadius: 14, style: .continuous)
                                )
                        }
                    }
                    .padding(.vertical, 8)

                } header: {
                    editorSectionHeader(eyebrow: "OTHER ITEM", title: "What should be remembered?")
                } footer: {
                    Text("Use this for planner items that are not medicines or appointments, such as documents, equipment, errands or preparation notes.")
                }

                Section {
                    DatePicker("Date and time", selection: $draft.date)

                    Picker("Repeat", selection: $repeatOption) {
                        Text("Does not repeat").tag("Does not repeat")
                        Text("Every day").tag("Every day")
                        Text("Every week").tag("Every week")
                        Text("Every month").tag("Every month")
                        Text("Every year").tag("Every year")
                        Text("Custom").tag("Custom")
                    }

                } header: {
                    editorSectionHeader(eyebrow: "SCHEDULE", title: "When should it show?")
                }

                if repeatOption == "Custom" {
                    Section {
                        Stepper("Every \(customInterval) \(customUnitLabel)", value: $customInterval, in: 1...52)

                        Picker("Repeat by", selection: $customUnit) {
                            Text("Days").tag("Days")
                            Text("Weeks").tag("Weeks")
                            Text("Months").tag("Months")
                            Text("Years").tag("Years")
                        }
                        .pickerStyle(.segmented)

                    } header: {
                        Text("Custom repeat")

                    } footer: {
                        Text("This item repeats every \(customInterval) \(customUnitLabel).")
                    }
                }

                Section {
                    ReminderSettingsCard(
                        itemName: draft.title,
                        scheduledAt: draft.date,
                        isEnabled: $reminderEnabled,
                        timing: $reminderTiming,
                        customDaysBefore: $reminderCustomDaysBefore,
                        customTime: $reminderTime,
                        repeatOption: $reminderRepeat,
                        recipient: $reminderRecipient
                    )
                } header: {
                    Text("Reminder")
                } footer: {
                    Text("Other-item reminders use this item's date and time.")
                }

                Section {
                    Toggle("Active", isOn: $draft.active)

                    Button {
                        saveItem()
                    } label: {
                        HStack {
                            Spacer()
                            Label("Save other item", systemImage: "checkmark.circle.fill")
                                .fontWeight(.semibold)
                            Spacer()
                        }
                    }
                    .disabled(draft.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .buttonStyle(PrimaryButtonStyle())

                    Button("Remove other item", role: .destructive) {
                        confirmRemove = true
                    }
                }
            }
            .navigationTitle(draft.title.isEmpty ? "Add other item" : "Edit other item")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Close") { dismiss() } } }
            .confirmationDialog("Remove this other item?", isPresented: $confirmRemove, titleVisibility: .visible) {
                Button("Remove other item", role: .destructive) {
                    store.removePlannerOtherItem(draft.id)
                    dismiss()
                }
            }
        }
    }

    private var customUnitLabel: String {
        if customInterval == 1 {
            return String(customUnit.lowercased().dropLast())
        }

        return customUnit.lowercased()
    }

    private var recentOtherItemTitles: [String] {
        uniqueRecent(store.plannerOtherItems.map(\.title), excluding: draft.title)
    }

    private func saveItem() {
        if repeatOption == "Custom" {
            draft.repeatRule = "Every \(customInterval) \(customUnitLabel)"
        } else {
            draft.repeatRule = repeatOption
        }

        store.savePlannerOtherItem(draft)
        dismiss()
    }

    private static func customRuleValues(from rule: String) -> (interval: Int, unit: String) {
        let parts = rule.split(separator: " ")

        guard parts.count >= 3,
              let interval = Int(parts[1]) else {
            return (1, "Weeks")
        }

        let unit = String(parts[2]).lowercased()
        let displayUnit: String

        if unit.hasPrefix("day") {
            displayUnit = "Days"
        } else if unit.hasPrefix("month") {
            displayUnit = "Months"
        } else if unit.hasPrefix("year") {
            displayUnit = "Years"
        } else {
            displayUnit = "Weeks"
        }

        return (max(1, interval), displayUnit)
    }
}

private struct ReminderSettingsCard: View {
    let itemName: String
    let scheduledAt: Date
    @Binding var isEnabled: Bool
    @Binding var timing: ReminderTimingOption
    @Binding var customDaysBefore: Int
    @Binding var customTime: Date
    @Binding var repeatOption: ReminderRepeatOption
    @Binding var recipient: ReminderRecipientOption
    @State private var selectedTimings: Set<ReminderTimingOption>
    @State private var customReminderDays: Int
    @State private var customReminderHours: Int
    @State private var customReminderMinutes: Int

    init(
        itemName: String,
        scheduledAt: Date,
        isEnabled: Binding<Bool>,
        timing: Binding<ReminderTimingOption>,
        customDaysBefore: Binding<Int>,
        customTime: Binding<Date>,
        repeatOption: Binding<ReminderRepeatOption>,
        recipient: Binding<ReminderRecipientOption>
    ) {
        self.itemName = itemName
        self.scheduledAt = scheduledAt
        _isEnabled = isEnabled
        _timing = timing
        _customDaysBefore = customDaysBefore
        _customTime = customTime
        _repeatOption = repeatOption
        _recipient = recipient
        _selectedTimings = State(initialValue: [timing.wrappedValue])
        _customReminderDays = State(initialValue: max(customDaysBefore.wrappedValue, 0))
        _customReminderHours = State(initialValue: 0)
        _customReminderMinutes = State(initialValue: 0)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Toggle(isOn: $isEnabled) {
                Label("Remind care circle", systemImage: "bell.fill")
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(RemoteLoveTheme.green)
            }

            if isEnabled {
                VStack(alignment: .leading, spacing: 10) {
                    Text("When should we remind you?")
                        .font(.caption.weight(.semibold))
                        .foregroundColor(.secondary)
                    Text("Select one or more reminder moments.")
                        .font(.caption2)
                        .foregroundColor(.secondary)

                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 128), spacing: 8)], spacing: 8) {
                        ForEach(ReminderTimingOption.allCases) { option in
                            Button {
                                toggleTiming(option)
                            } label: {
                                Text(option.title)
                                    .font(.caption.weight(.semibold))
                                    .frame(maxWidth: .infinity, minHeight: 36)
                                    .foregroundColor(selectedTimings.contains(option) ? RemoteLoveTheme.onAccent : RemoteLoveTheme.green)
                                    .background(selectedTimings.contains(option) ? RemoteLoveTheme.green : RemoteLoveTheme.green.opacity(0.10), in: Capsule())
                            }
                            .buttonStyle(.plain)
                            .accessibilityAddTraits(selectedTimings.contains(option) ? .isSelected : [])
                        }
                    }
                }

                if selectedTimings.contains(.custom) {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Custom reminder")
                            .font(.caption.weight(.semibold))
                            .foregroundColor(.secondary)

                        Text("Build one reminder offset using days, hours and minutes.")
                            .font(.caption2)
                            .foregroundColor(.secondary)

                        Stepper(customReminderPartLabel(value: customReminderDays, singular: "day"), value: $customReminderDays, in: 0...30)
                            .onChange(of: customReminderDays) { _, _ in
                                syncCustomDaysForCompatibility()
                            }
                        Stepper(customReminderPartLabel(value: customReminderHours, singular: "hour"), value: $customReminderHours, in: 0...23)
                            .onChange(of: customReminderHours) { _, _ in
                                syncCustomDaysForCompatibility()
                            }
                        Stepper(customReminderPartLabel(value: customReminderMinutes, singular: "minute"), value: $customReminderMinutes, in: 0...55, step: 5)
                            .onChange(of: customReminderMinutes) { _, _ in
                                syncCustomDaysForCompatibility()
                            }

                        HStack(spacing: 8) {
                            Image(systemName: "clock.badge")
                                .foregroundColor(RemoteLoveTheme.green)
                            Text(customReminderSummary)
                                .font(.caption.weight(.semibold))
                                .foregroundColor(.primary)
                        }
                    }
                    .padding(12)
                    .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                }

                DatePicker("Reminder time", selection: $customTime, displayedComponents: .hourAndMinute)

                Picker("Repeat if not acknowledged", selection: $repeatOption) {
                    ForEach(ReminderRepeatOption.allCases) { option in
                        Text(option.title).tag(option)
                    }
                }

                Picker("Who should be reminded?", selection: $recipient) {
                    ForEach(ReminderRecipientOption.allCases) { option in
                        Text(option.title).tag(option)
                    }
                }

                VStack(alignment: .leading, spacing: 8) {
                    Label("Preview", systemImage: "eye.fill")
                        .font(.caption.weight(.semibold))
                        .foregroundColor(RemoteLoveTheme.green)

                    Text(previewText)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(12)
                .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            } else {
                Text("No reminder will be scheduled for this item.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 6)
    }

    private var previewText: String {
        let timingText = selectedTimings
            .sortedForDisplay
            .map(timingPreviewText)
            .joined(separator: ", ")
        let timeText = customTime.formatted(date: .omitted, time: .shortened)
        let scheduledText = scheduledAt.formatted(date: .abbreviated, time: .shortened)
        let repeatText = repeatOption == .none ? "" : " If no one acknowledges it, it repeats \(repeatOption.title.lowercased())."
        return "\(recipient.title) will be reminded about \(itemName.isEmpty ? "this item" : itemName) at \(timeText): \(timingText). Scheduled for \(scheduledText).\(repeatText)"
    }

    private func toggleTiming(_ option: ReminderTimingOption) {
        if selectedTimings.contains(option) {
            selectedTimings.remove(option)
        } else {
            selectedTimings.insert(option)
        }

        if selectedTimings.isEmpty {
            selectedTimings.insert(.atTime)
        }

        timing = selectedTimings.sortedForDisplay.first ?? .atTime
    }

    private func timingPreviewText(_ option: ReminderTimingOption) -> String {
        switch option {
        case .atTime:
            return "at the scheduled time"
        case .tenMinutesBefore:
            return "10 minutes before"
        case .thirtyMinutesBefore:
            return "30 minutes before"
        case .oneHourBefore:
            return "1 hour before"
        case .oneDayBefore:
            return "1 day before"
        case .threeDaysBefore:
            return "3 days before"
        case .custom:
            return customReminderSummary
        }
    }

    private func syncCustomDaysForCompatibility() {
        customDaysBefore = customReminderDays
    }

    private var customReminderSummary: String {
        let parts = [
            customReminderDays > 0 ? customReminderPartLabel(value: customReminderDays, singular: "day").lowercased() : nil,
            customReminderHours > 0 ? customReminderPartLabel(value: customReminderHours, singular: "hour").lowercased() : nil,
            customReminderMinutes > 0 ? customReminderPartLabel(value: customReminderMinutes, singular: "minute").lowercased() : nil
        ].compactMap { $0 }

        if parts.isEmpty {
            return "At the scheduled time"
        }

        return "\(parts.joined(separator: " ")) before"
    }

    private func customReminderPartLabel(value: Int, singular: String) -> String {
        "\(value) \(value == 1 ? singular : "\(singular)s")"
    }
}

private extension Set where Element == ReminderTimingOption {
    var sortedForDisplay: [ReminderTimingOption] {
        ReminderTimingOption.allCases.filter { contains($0) }
    }
}

private struct RecentSuggestionChips: View {
    let title: String
    let suggestions: [String]
    let onSelect: (String) -> Void

    var body: some View {
        if !suggestions.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Text(title)
                    .font(.caption.weight(.semibold))
                    .foregroundColor(.secondary)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(suggestions, id: \.self) { suggestion in
                            Button {
                                onSelect(suggestion)
                            } label: {
                                Text(suggestion)
                                    .font(.caption.weight(.semibold))
                                    .foregroundColor(RemoteLoveTheme.green)
                                    .lineLimit(1)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                    .background(RemoteLoveTheme.green.opacity(0.10), in: Capsule())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
    }
}

private func uniqueRecent(_ values: [String], excluding excludedValue: String = "", limit: Int = 6) -> [String] {
    var seen = Set<String>()
    let excluded = excludedValue.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    var output: [String] = []

    for value in values.reversed() {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        let key = trimmed.lowercased()
        guard !trimmed.isEmpty, key != excluded, !seen.contains(key) else { continue }
        seen.insert(key)
        output.append(trimmed)
        if output.count >= limit { break }
    }

    return output
}

private func editorSectionHeader(
    eyebrow: String,
    title: String
) -> some View {
    VStack(alignment: .leading, spacing: 4) {
        Text(eyebrow)
            .font(.caption.weight(.bold))

        Text(title)
            .font(.headline)
            .textCase(nil)
            .foregroundColor(.primary)
    }
    .padding(.bottom, 6)
}

private func editorTextField(
    title: String,
    icon: String,
    placeholder: String,
    text: Binding<String>
) -> some View {
    VStack(alignment: .leading, spacing: 8) {
        Label(title, systemImage: icon)
            .font(.subheadline.weight(.semibold))
            .foregroundColor(RemoteLoveTheme.green)

        TextField(placeholder, text: text)
            .textInputAutocapitalization(.sentences)
            .padding(14)
            .background(
                Color.secondary.opacity(0.08),
                in: RoundedRectangle(
                    cornerRadius: 14,
                    style: .continuous
                )
            )
    }
}

private struct EditorProfileContextCard: View {
    let profileName: String
    let profileLabel: String
    let action: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "person.crop.circle.fill")
                .font(.title3)
                .foregroundColor(RemoteLoveTheme.green)
                .frame(width: 40, height: 40)
                .background(RemoteLoveTheme.green.opacity(0.12), in: Circle())
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 3) {
                Text(action.uppercased())
                    .font(.caption2.weight(.bold))
                    .foregroundColor(.secondary)
                Text("\(profileLabel) · \(profileName)")
                    .font(.headline)
                    .foregroundColor(.primary)
            }

            Spacer(minLength: 0)
        }
        .padding(.vertical, 4)
    }
}

private struct EditorSetupSummaryCard: View {
    let title: String
    let detail: String
    let icon: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.subheadline.weight(.semibold))
                .foregroundColor(RemoteLoveTheme.green)
                .frame(width: 34, height: 34)
                .background(RemoteLoveTheme.green.opacity(0.12), in: Circle())
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(.primary)
                Text(detail)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .padding(12)
        .background(RemoteLoveTheme.green.opacity(0.07), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .accessibilityElement(children: .combine)
    }
}

private func editorNumberField(
    title: String,
    value: Binding<Double>,
    suffix: String
) -> some View {
    VStack(alignment: .leading, spacing: 8) {
        Text(title)
            .font(.subheadline.weight(.semibold))
            .foregroundColor(RemoteLoveTheme.green)

        HStack {
            TextField(
                "0",
                value: value,
                format: .number
            )
            .keyboardType(.decimalPad)

            Text(suffix)
                .foregroundColor(.secondary)
        }
        .padding(14)
        .background(
            Color.secondary.opacity(0.08),
            in: RoundedRectangle(
                cornerRadius: 14,
                style: .continuous
            )
        )
    }
}

struct HealthView: View {
    @EnvironmentObject private var store: RemoteLoveStore
    @State private var category: HealthCategory = .bloodPressure
    @State private var showLogger = false
    @State private var showStatusGuide = false
    @State private var showExportOptions = false
    @State private var exportCategories = Set(HealthCategory.allCases)
    @State private var exportFile: HealthExportFile?

    private var logs: [HealthLog] {
        store.selectedHealthLogs.filter { $0.category == category }.sorted { $0.recordedAt < $1.recordedAt }
    }

    var body: some View {
        ScrollViewReader { tutorialProxy in
            ScrollView {
                VStack(spacing: 16) {
                RecipientHeader()
                HStack {
                    VStack(alignment: .leading) {
                        Text("Health monitor").font(.largeTitle.bold())
                        Text("A useful history to share with care professionals").foregroundColor(.secondary)
                    }
                    Spacer()
                    HStack(spacing: 8) {
                        HealthHeaderActionButton(title: "Guide", icon: "info.circle") {
                            showStatusGuide = true
                        }
                        HealthHeaderActionButton(title: "CSV", icon: "arrow.down.doc") {
                            showExportOptions = true
                        }
                        .disabled(store.selectedHealthLogs.isEmpty)
                        .opacity(store.selectedHealthLogs.isEmpty ? 0.45 : 1)
                    }
                    if store.canLogHealthRecords {
                        Button { showLogger = true } label: {
                            Label("Log", systemImage: "plus.circle.fill")
                                .font(.headline)
                        }
                        .buttonStyle(.borderedProminent)
                        .accessibilityLabel("Log health reading")
                    }
                }
                .padding(.horizontal)
                .tutorialSpotlight(.healthHeader)

                HealthSnapshotCard(logs: store.selectedHealthLogs, recipientAge: store.selectedRecipient.age)
                    .tutorialSpotlight(.healthStatus)

                if store.selectedHealthLogs.isEmpty {
                    ActionEmptyStateCard(
                        icon: "heart.text.square.fill",
                        title: "No health readings yet",
                        message: store.canLogHealthRecords ? "Log the first reading so the care circle can start seeing trends and status labels." : "No health readings have been logged for this profile.",
                        actionTitle: store.canLogHealthRecords ? "Log first reading" : nil,
                        action: store.canLogHealthRecords ? { showLogger = true } : nil
                    )
                    .padding(.horizontal)
                }

                HealthCategorySelector(selectedCategory: $category, logs: store.selectedHealthLogs, recipientAge: store.selectedRecipient.age)
                    .tutorialSpotlight(.healthCategories)

                HealthSelectedCategoryCard(
                    category: category,
                    latestLog: logs.last,
                    previousLog: logs.count >= 2 ? logs[logs.count - 2] : nil,
                    recipientAge: store.selectedRecipient.age
                )
                .id(DestinationScrollTarget.healthCategory(category.rawValue))
                .tutorialSpotlight(.healthLog)

                NativeCard(title: "\(category.label) trend", subtitle: category.reference(for: store.selectedRecipient.age), icon: "chart.xyaxis.line") {
                    if logs.count >= 2 {
                        Chart(logs) { log in
                            LineMark(x: .value("Date", log.recordedAt), y: .value(category.label, log.value))
                                .foregroundStyle(RemoteLoveTheme.green)
                            PointMark(x: .value("Date", log.recordedAt), y: .value(category.label, log.value))
                                .foregroundStyle(RemoteLoveTheme.coral)
                        }
                        .frame(height: 190)
                    } else {
                        Text("Add at least two readings to show a trend.").foregroundColor(.secondary)
                    }
                }
                .transition(.opacity.combined(with: .move(edge: .bottom)))

                NativeCard(title: "Reading history", subtitle: "Filtered to \(category.label.lowercased())", icon: "clock.arrow.circlepath") {
                    if logs.isEmpty {
                        Text("No \(category.label.lowercased()) readings yet. Add one to start tracking trends.")
                            .foregroundColor(.secondary)
                    } else {
                        ForEach(logs.reversed()) { log in
                            HealthReadingHistoryRow(category: category, log: log, recipientAge: store.selectedRecipient.age)
                            Divider()
                        }
                    }
                }
                .transition(.opacity.combined(with: .move(edge: .bottom)))
                }
                .padding(.bottom, 24)
                .animation(.easeInOut(duration: 0.22), value: category)
            }
            .tutorialScrollReceiver(tutorialProxy)
        }
        .background(Color(uiColor: .systemGroupedBackground))
        .navigationBarHidden(true)
        .overlay {
            if showStatusGuide {
                HealthStatusGuidePopup {
                    withAnimation(.easeInOut(duration: 0.18)) {
                        showStatusGuide = false
                    }
                }
                .transition(.opacity.combined(with: .scale(scale: 0.94)))
                .zIndex(5)
            }
        }
        .animation(.easeInOut(duration: 0.18), value: showStatusGuide)
        .sheet(isPresented: $showLogger) { HealthLoggerView(initialCategory: category) }
        .sheet(isPresented: $showExportOptions) {
            HealthExportOptionsView(
                selectedCategories: $exportCategories,
                onExport: {
                    if let url = makeHealthCSV(categories: exportCategories) {
                        exportFile = HealthExportFile(url: url)
                    }
                    showExportOptions = false
                }
            )
        }
        .sheet(item: $exportFile) { file in
            ActivityShareSheet(items: [file.url])
        }
        .onAppear(perform: openPendingHealthDestination)
        .onChange(of: store.pendingDestination) {
            openPendingHealthDestination()
        }
    }

    private func openPendingHealthDestination() {
        guard case let .health(recipientID, categoryValue) = store.pendingDestination else { return }
        store.selectedRecipientID = recipientID
        if let categoryValue, let requestedCategory = HealthCategory(rawValue: categoryValue) {
            category = requestedCategory
            postDestinationScroll(DestinationScrollTarget.healthCategory(categoryValue))
        }
        store.pendingDestination = nil
    }

    private func makeHealthCSV(categories: Set<HealthCategory>) -> URL? {
        let recipient = store.selectedRecipient
        let selectedCategories = categories.isEmpty ? [category] : Array(categories)
        let exportLogs = store.selectedHealthLogs
            .filter { selectedCategories.contains($0.category) }
            .sorted { $0.recordedAt < $1.recordedAt }
        guard exportLogs.isEmpty == false else { return nil }

        var rows = [
            ["Recipient", "Label", "Category", "Value", "Unit", "Recorded At", "Notes"]
        ]
        rows.append(contentsOf: exportLogs.map { log in
            let exportCategory = log.category
            return [
                recipient.name,
                recipient.label,
                exportCategory.label,
                String(log.value),
                exportCategory.unit,
                ISO8601DateFormatter().string(from: log.recordedAt),
                log.notes
            ]
        })

        let csv = rows.map { row in
            row.map(csvEscape).joined(separator: ",")
        }.joined(separator: "\n")

        let safeLabel = recipient.label.replacingOccurrences(of: " ", with: "-")
        let safeCategory = selectedCategories.count == HealthCategory.allCases.count ? "all-categories" : "\(selectedCategories.count)-categories"
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("RemoteLove-\(safeLabel)-\(safeCategory)-health.csv")

        do {
            try csv.write(to: url, atomically: true, encoding: .utf8)
            store.authMessage = "Health data export is ready."
            return url
        } catch {
            store.authMessage = "Could not prepare the health export."
            return nil
        }
    }

    private func csvEscape(_ value: String) -> String {
        let escaped = value.replacingOccurrences(of: "\"", with: "\"\"")
        return "\"\(escaped)\""
    }
}

private struct HealthHeaderActionButton: View {
    let title: String
    let icon: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 3) {
                Image(systemName: icon)
                    .font(.subheadline.weight(.semibold))
                Text(title)
                    .font(.caption2.weight(.bold))
            }
            .foregroundColor(RemoteLoveTheme.green)
            .frame(width: 48, height: 44)
            .background(RemoteLoveTheme.green.opacity(0.10), in: RoundedRectangle(cornerRadius: 13, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title == "CSV" ? "Export health data as CSV" : "Show health status guide")
    }
}

private struct HealthStatusGuidePopup: View {
    let onDismiss: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.34)
                .ignoresSafeArea()
                .onTapGesture(perform: onDismiss)

            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: "info.circle.fill")
                        .font(.title2)
                        .foregroundColor(RemoteLoveTheme.green)
                        .frame(width: 40, height: 40)
                        .background(RemoteLoveTheme.green.opacity(0.12), in: Circle())
                        .accessibilityHidden(true)

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Status guide")
                            .font(.title3.bold())
                        Text("Simple flags for family awareness, not medical advice.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    Button(action: onDismiss) {
                        Image(systemName: "xmark")
                            .font(.caption.bold())
                            .foregroundColor(.secondary)
                            .frame(width: 44, height: 44)
                            .background(Color.secondary.opacity(0.10), in: Circle())
                    }
                    .accessibilityLabel("Close status guide")
                }

                VStack(alignment: .leading, spacing: 12) {
                    HealthLegendRow(status: .good)
                    HealthLegendRow(status: .watch)
                    HealthLegendRow(status: .needsAttention)
                    HealthLegendRow(status: .trendOnly)
                }

                Text("Use these labels as a quick prompt to review patterns and contact a care professional when needed.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(18)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 26, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .stroke(RemoteLoveTheme.green.opacity(0.16), lineWidth: 1)
            }
            .shadow(color: .black.opacity(0.20), radius: 24, y: 12)
            .padding(.horizontal, 24)
            .accessibilityElement(children: .contain)
        }
    }
}

struct HealthExportFile: Identifiable {
    let id = UUID()
    let url: URL
}

private struct HealthExportOptionsView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var selectedCategories: Set<HealthCategory>
    let onExport: () -> Void

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Button {
                        selectedCategories = Set(HealthCategory.allCases)
                    } label: {
                        Label("Select all categories", systemImage: "checkmark.circle.fill")
                    }
                    Button {
                        selectedCategories.removeAll()
                    } label: {
                        Label("Clear selection", systemImage: "circle")
                    }
                }

                Section("Categories") {
                    ForEach(HealthCategory.allCases) { category in
                        Button {
                            if selectedCategories.contains(category) {
                                selectedCategories.remove(category)
                            } else {
                                selectedCategories.insert(category)
                            }
                        } label: {
                            HStack {
                                Label(category.label, systemImage: healthIcon(for: category))
                                Spacer()
                                if selectedCategories.contains(category) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(RemoteLoveTheme.green)
                                }
                            }
                        }
                        .foregroundColor(.primary)
                    }
                }

                Section {
                    Button {
                        onExport()
                    } label: {
                        Label("Download selected CSV", systemImage: "arrow.down.doc.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .disabled(selectedCategories.isEmpty)
                } footer: {
                    Text("Only readings from selected categories will be included.")
                }
            }
            .navigationTitle("Export health data")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}

private struct HealthSnapshotCard: View {
    let logs: [HealthLog]
    let recipientAge: Int
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var selectedStatus: HealthSnapshotStatusDetail?

    private var latestByCategory: [(HealthCategory, HealthLog)] {
        HealthCategory.allCases.compactMap { category in
            guard let latest = logs
                .filter({ $0.category == category })
                .sorted(by: { $0.recordedAt > $1.recordedAt })
                .first else { return nil }
            return (category, latest)
        }
    }

    private var statusCounts: (good: Int, watch: Int, attention: Int) {
        latestByCategory.reduce((0, 0, 0)) { result, item in
            let status = item.0.status(for: item.1.value, age: recipientAge)
            switch status {
            case .good:
                return (result.good + 1, result.watch, result.attention)
            case .watch:
                return (result.good, result.watch + 1, result.attention)
            case .needsAttention:
                return (result.good, result.watch, result.attention + 1)
            case .trendOnly:
                return result
            }
        }
    }

    private var statusItems: [HealthSnapshotStatusItem] {
        latestByCategory.map { category, log in
            HealthSnapshotStatusItem(
                category: category,
                log: log,
                status: category.status(for: log.value, age: recipientAge)
            )
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("Today's health snapshot", systemImage: "heart.text.square.fill")
                .font(.headline)
                .foregroundColor(RemoteLoveTheme.green)

            Group {
                if dynamicTypeSize.isAccessibilitySize {
                    VStack(spacing: 10) {
                        snapshotMetrics
                    }
                } else {
                    HStack(spacing: 10) {
                        snapshotMetrics
                    }
                }
            }

            Text(latestByCategory.isEmpty ? "No health readings logged yet." : "Latest readings across \(latestByCategory.count) categor\(latestByCategory.count == 1 ? "y" : "ies").")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(18)
        .remoteLoveSectionSurface(cornerRadius: 22)
        .padding(.horizontal)
        .sheet(item: $selectedStatus) { detail in
            HealthSnapshotStatusDetailView(detail: detail)
        }
    }

    private func showHealthSnapshotDetail(for status: HealthReadingStatus) {
        selectedStatus = HealthSnapshotStatusDetail(
            status: status,
            items: statusItems.filter { $0.status == status }
        )
    }

    @ViewBuilder
    private var snapshotMetrics: some View {
        HealthSnapshotMetric(
            value: "\(statusCounts.good)",
            label: "Good",
            tint: RemoteLoveTheme.green
        ) {
            showHealthSnapshotDetail(for: .good)
        }
        HealthSnapshotMetric(
            value: "\(statusCounts.watch)",
            label: "Watch",
            tint: RemoteLoveTheme.amber
        ) {
            showHealthSnapshotDetail(for: .watch)
        }
        HealthSnapshotMetric(
            value: "\(statusCounts.attention)",
            label: "Attention",
            tint: RemoteLoveTheme.coral
        ) {
            showHealthSnapshotDetail(for: .needsAttention)
        }
    }
}

private struct HealthSnapshotMetric: View {
    let value: String
    let label: String
    let tint: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 2) {
                Text(value)
                    .font(.title3.bold())
                    .foregroundColor(tint)
                Text(label)
                    .font(.caption2.weight(.semibold))
                    .foregroundColor(.secondary)
                Image(systemName: "chevron.up.right.circle.fill")
                    .font(.caption)
                    .foregroundColor(tint.opacity(0.75))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .background(tint.opacity(0.10), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(label), \(value) categories")
    }
}

private struct HealthSnapshotStatusItem: Identifiable, Hashable {
    var id: HealthCategory { category }
    let category: HealthCategory
    let log: HealthLog
    let status: HealthReadingStatus
}

private struct HealthSnapshotStatusDetail: Identifiable {
    var id: String { status.rawValue }
    let status: HealthReadingStatus
    let items: [HealthSnapshotStatusItem]
}

private struct HealthSnapshotStatusDetailView: View {
    @Environment(\.dismiss) private var dismiss
    let detail: HealthSnapshotStatusDetail

    var body: some View {
        NavigationStack {
            List {
                if detail.items.isEmpty {
                    ContentUnavailableView(
                        "No \(detail.status.label.lowercased()) readings",
                        systemImage: "heart.text.square",
                        description: Text("Latest readings will appear here after they are logged.")
                    )
                } else {
                    Section(detail.status.summary) {
                        ForEach(detail.items, id: \.category) { item in
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(item.category.label)
                                        .font(.headline)
                                    Text(item.log.recordedAt.formatted(date: .abbreviated, time: .shortened))
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }

                                Spacer()

                                Text(healthDisplayValue(category: item.category, value: item.log.value))
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundColor(statusColor(item.status))
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }
            }
            .navigationTitle(detail.status.label)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

private struct HealthCategorySelector: View {
    @Binding var selectedCategory: HealthCategory
    let logs: [HealthLog]
    let recipientAge: Int
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(alignment: .top, spacing: 14) {
                ForEach(HealthCategoryGroup.allCases) { group in
                    VStack(alignment: .leading, spacing: 8) {
                        Label(group.title, systemImage: group.icon)
                            .font(.caption.weight(.bold))
                            .foregroundColor(group.tint)

                        HStack(spacing: 8) {
                            ForEach(group.categories) { category in
                                categoryButton(category)
                            }
                        }
                    }
                    .padding(10)
                    .background(group.tint.opacity(0.08), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                }
            }
            .padding(.horizontal)
        }
    }

    private func categoryButton(_ category: HealthCategory) -> some View {
        let latest = latestLog(for: category)
        let isSelected = selectedCategory == category
        let status = latest.map { category.status(for: $0.value, age: recipientAge) }
        return Button {
            selectedCategory = category
        } label: {
            VStack(alignment: .leading, spacing: 7) {
                Image(systemName: healthIcon(for: category))
                    .font(.headline)
                    .foregroundColor(isSelected ? RemoteLoveTheme.onAccent : statusColor(status ?? .trendOnly))
                Text(category.label)
                    .font(.caption.weight(.semibold))
                    .foregroundColor(isSelected ? RemoteLoveTheme.onAccent : .primary)
                    .lineLimit(dynamicTypeSize.isAccessibilitySize ? 2 : 1)
                if let latest {
                    Text(healthDisplayValue(category: category, value: latest.value))
                        .font(.caption2.weight(.medium))
                        .foregroundColor(isSelected ? RemoteLoveTheme.onAccent.opacity(0.85) : .secondary)
                        .lineLimit(dynamicTypeSize.isAccessibilitySize ? 2 : 1)
                    if let status {
                        Text(status.label)
                            .font(.caption2.weight(.bold))
                            .foregroundColor(isSelected ? RemoteLoveTheme.onAccent : statusColor(status))
                            .lineLimit(dynamicTypeSize.isAccessibilitySize ? 2 : 1)
                    }
                } else {
                    Text("No reading")
                        .font(.caption2)
                        .foregroundColor(isSelected ? RemoteLoveTheme.onAccent.opacity(0.80) : .secondary)
                }
            }
            .frame(width: dynamicTypeSize.isAccessibilitySize ? 168 : 126, alignment: .leading)
            .padding(12)
            .background(isSelected ? RemoteLoveTheme.green : Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private func latestLog(for category: HealthCategory) -> HealthLog? {
        logs.filter { $0.category == category }.sorted { $0.recordedAt > $1.recordedAt }.first
    }
}

private enum HealthCategoryGroup: String, CaseIterable, Identifiable {
    case vitals
    case nutrition
    case activity
    case body

    var id: String { rawValue }

    var title: String {
        switch self {
        case .vitals: return "Vitals"
        case .nutrition: return "Nutrition"
        case .activity: return "Activity"
        case .body: return "Body"
        }
    }

    var icon: String {
        switch self {
        case .vitals: return "waveform.path.ecg"
        case .nutrition: return "fork.knife"
        case .activity: return "figure.walk"
        case .body: return "person.fill"
        }
    }

    var tint: Color {
        switch self {
        case .vitals: return RemoteLoveTheme.coral
        case .nutrition: return RemoteLoveTheme.green
        case .activity: return RemoteLoveTheme.amber
        case .body: return RemoteLoveTheme.green
        }
    }

    var categories: [HealthCategory] {
        switch self {
        case .vitals:
            return [.bloodPressure, .bloodSugar, .heartRate, .temperature, .oxygen]
        case .nutrition:
            return [.hydration, .diet]
        case .activity:
            return [.mobility, .sleep]
        case .body:
            return [.weight]
        }
    }
}

private struct HealthSelectedCategoryCard: View {
    let category: HealthCategory
    let latestLog: HealthLog?
    let previousLog: HealthLog?
    let recipientAge: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                Image(systemName: healthIcon(for: category))
                    .font(.title3)
                    .foregroundColor(RemoteLoveTheme.coral)
                    .frame(width: 44, height: 44)
                    .background(RemoteLoveTheme.coral.opacity(0.12), in: Circle())
                VStack(alignment: .leading, spacing: 3) {
                    Text(category.label)
                        .font(.headline)
                    Text(category.reference(for: recipientAge))
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            if let latestLog {
                let status = category.status(for: latestLog.value, age: recipientAge)
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Latest")
                            .font(.caption.weight(.semibold))
                            .foregroundColor(.secondary)
                        Text(healthDisplayValue(category: category, value: latestLog.value))
                            .font(.title3.bold())
                    }
                    Spacer()
                    HealthStatusCapsule(status: status)
                }
                HealthTrendSummaryRow(
                    category: category,
                    latestLog: latestLog,
                    previousLog: previousLog,
                    status: status
                )
                Text(latestLog.recordedAt.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption)
                    .foregroundColor(.secondary)
            } else {
                Text("No reading has been logged for this category yet.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(18)
        .remoteLoveSectionSurface(cornerRadius: 22)
        .padding(.horizontal)
    }
}

private struct HealthTrendSummaryRow: View {
    let category: HealthCategory
    let latestLog: HealthLog
    let previousLog: HealthLog?
    let status: HealthReadingStatus

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: trendIcon)
                .font(.subheadline.weight(.semibold))
                .foregroundColor(statusColor(status))
                .frame(width: 28, height: 28)
                .background(statusColor(status).opacity(0.12), in: Circle())
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 3) {
                Text(trendTitle)
                    .font(.subheadline.weight(.semibold))
                Text(nextStep)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(12)
        .background(statusColor(status).opacity(0.08), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var trendTitle: String {
        guard let previousLog else { return "First reading recorded" }
        let delta = latestLog.value - previousLog.value
        if abs(delta) < 0.01 { return "Stable from last reading" }
        let direction = delta > 0 ? "higher" : "lower"
        return "\(category.label) is \(direction) by \(abs(delta).formatted()) \(category.unit)"
    }

    private var nextStep: String {
        switch status {
        case .good:
            return "Looks within the app’s general reference range. Keep tracking as usual."
        case .watch:
            return "Worth watching. Review the next reading and add notes if anything changed."
        case .needsAttention:
            return "Needs attention. Tell the family and follow the care recipient’s clinical guidance if concerned."
        case .trendOnly:
            return "Best understood over time. Look for patterns across future readings."
        }
    }

    private var trendIcon: String {
        guard let previousLog else { return "sparkles" }
        let delta = latestLog.value - previousLog.value
        if abs(delta) < 0.01 { return "equal.circle.fill" }
        return delta > 0 ? "arrow.up.circle.fill" : "arrow.down.circle.fill"
    }
}

private struct HealthReadingHistoryRow: View {
    let category: HealthCategory
    let log: HealthLog
    let recipientAge: Int

    var body: some View {
        let status = category.status(for: log.value, age: recipientAge)
        HStack(alignment: .center, spacing: 12) {
            Image(systemName: healthIcon(for: category))
                .foregroundColor(statusColor(status))
                .frame(width: 34, height: 34)
                .background(statusColor(status).opacity(0.12), in: Circle())

            VStack(alignment: .leading, spacing: 3) {
                Text(log.recordedAt.formatted(date: .abbreviated, time: .shortened))
                    .font(.subheadline.weight(.semibold))
                Text(status.summary)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                if !log.notes.isEmpty {
                    Text(log.notes)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 5) {
                Text(healthDisplayValue(category: category, value: log.value)).bold()
                HealthStatusCapsule(status: status)
            }
        }
        .padding(10)
        .background(status == .needsAttention ? RemoteLoveTheme.coral.opacity(0.09) : Color.clear, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .neonAttention(active: status == .needsAttention, tint: RemoteLoveTheme.coral, cornerRadius: 12)
    }
}

private func healthIcon(for category: HealthCategory) -> String {
    switch category {
    case .weight: return "scalemass.fill"
    case .bloodPressure: return "waveform.path.ecg"
    case .bloodSugar: return "drop.fill"
    case .heartRate: return "heart.fill"
    case .temperature: return "thermometer.medium"
    case .oxygen: return "lungs.fill"
    case .mobility: return "figure.walk"
    case .diet: return "fork.knife"
    case .hydration: return "waterbottle.fill"
    case .sleep: return "bed.double.fill"
    }
}

private func healthDisplayValue(category: HealthCategory, value: Double) -> String {
    if category == .hydration {
        let ml = Int((value * 250).rounded())
        return "\(ml) ml · \(value.formatted()) glasses"
    }
    return "\(value.formatted()) \(category.unit)"
}

private func statusColor(_ status: HealthReadingStatus) -> Color {
    switch status {
    case .good:
        return RemoteLoveTheme.green
    case .watch:
        return RemoteLoveTheme.amber
    case .needsAttention:
        return RemoteLoveTheme.coral
    case .trendOnly:
        return .secondary
    }
}

#if canImport(UIKit)
struct ActivityShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) { }
}
#endif

struct HealthLoggerView: View {
    @EnvironmentObject private var store: RemoteLoveStore
    @Environment(\.dismiss) private var dismiss
    @State private var category: HealthCategory
    @State private var value = ""
    @State private var hydrationAmount = 250.0
    @State private var hydrationUnit: HydrationInputUnit = .ml
    @State private var moodScore = 4.0
    @State private var painScore = 3.0
    @State private var notes = ""
    @State private var isSaving = false

    init(initialCategory: HealthCategory) { _category = State(initialValue: initialCategory) }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    EditorProfileContextCard(
                        profileName: store.selectedRecipient.name,
                        profileLabel: store.selectedRecipient.label,
                        action: "Logging health for"
                    )
                    EditorSetupSummaryCard(
                        title: "Record one clear reading",
                        detail: "Choose the category, enter the value, then add notes if something may help the care circle understand the reading.",
                        icon: "heart.text.square.fill"
                    )
                }

                Section {
                    Picker("Category", selection: $category) {
                        ForEach(HealthCategory.allCases) { Text($0.label).tag($0) }
                    }
                    Text(category.prompt)
                        .font(.caption)
                        .foregroundColor(.secondary)
                } header: {
                    editorSectionHeader(eyebrow: "CATEGORY", title: "What are you recording?")
                }

                Section {
                    categoryInput
                    TextField("Notes or context (optional)", text: $notes, axis: .vertical)
                        .lineLimit(2...5)
                        .padding(14)
                        .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                } header: {
                    editorSectionHeader(eyebrow: "READING", title: "What is the latest value?")
                }

                Section {
                    Text(category.reference(for: store.selectedRecipient.age))
                        .font(.subheadline)
                    Text("RemoteLove records and flags changes; it does not diagnose. Follow the person’s clinician-approved targets.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                } header: {
                    editorSectionHeader(eyebrow: "REFERENCE", title: "Guide for age \(store.selectedRecipient.age)")
                }
                Section {
                    Button {
                        guard let number = resolvedValue else { return }
                        Task {
                            isSaving = true
                            await store.addHealthLogAndSync(category: category, value: number, notes: enrichedNotes)
                            isSaving = false
                            dismiss()
                        }
                    } label: {
                        HStack {
                            Spacer()
                            Label(isSaving ? "Saving..." : "Save health update", systemImage: "checkmark.circle.fill")
                                .fontWeight(.semibold)
                            Spacer()
                        }
                    }
                    .disabled(resolvedValue == nil || isSaving)
                    .buttonStyle(PrimaryButtonStyle())
                }
            }
            .navigationTitle("Log health update")
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } } }
        }
    }

    @ViewBuilder
    private var categoryInput: some View {
        switch category {
        case .hydration:
            VStack(alignment: .leading, spacing: 12) {
                Text("How much fluid did they drink?")
                    .font(.subheadline.weight(.semibold))
                Picker("Unit", selection: $hydrationUnit) {
                    ForEach(HydrationInputUnit.allCases) { unit in
                        Text(unit.title).tag(unit)
                    }
                }
                .pickerStyle(.segmented)

                HStack {
                    TextField("Amount", value: $hydrationAmount, format: .number)
                        .keyboardType(.decimalPad)
                    Text(hydrationUnit.shortTitle)
                        .foregroundColor(.secondary)
                }
                .padding(14)
                .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 14, style: .continuous))

                HStack(spacing: 8) {
                    hydrationQuickButton(title: "+250 ml", amount: 250, unit: .ml)
                    hydrationQuickButton(title: "+500 ml", amount: 500, unit: .ml)
                    hydrationQuickButton(title: "+1 bottle", amount: 1, unit: .bottles)
                }

                Text("Saved as approx. \(resolvedValue?.formatted() ?? "0") glasses for compatibility. Displayed as \(Int((resolvedValue ?? 0) * 250)) ml.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        case .diet:
            VStack(alignment: .leading, spacing: 10) {
                Text("Diet quality")
                    .font(.subheadline.weight(.semibold))
                Picker("Diet quality", selection: numericBinding(defaultValue: 3)) {
                    ForEach(1...5, id: \.self) { score in
                        Text("\(score) / 5").tag(Double(score))
                    }
                }
                .pickerStyle(.segmented)
            }
        case .mobility:
            numericInput(title: "Minutes mobile", unit: category.unit)
        case .sleep:
            numericInput(title: "Hours slept", unit: category.unit)
        default:
            numericInput(title: category.prompt, unit: category.unit)
        }
    }

    private func numericInput(title: String, unit: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.subheadline.weight(.semibold))
            HStack {
                TextField("Reading", text: $value)
                    .keyboardType(.decimalPad)
                Text(unit)
                    .foregroundColor(.secondary)
            }
            .padding(14)
            .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
    }

    private func hydrationQuickButton(title: String, amount: Double, unit: HydrationInputUnit) -> some View {
        Button(title) {
            hydrationAmount = amount
            hydrationUnit = unit
        }
        .font(.caption.weight(.semibold))
        .buttonStyle(.bordered)
    }

    private var resolvedValue: Double? {
        switch category {
        case .hydration:
            return hydrationUnit.glasses(for: hydrationAmount)
        case .diet:
            return Double(value) ?? 3
        default:
            return Double(value)
        }
    }

    private var enrichedNotes: String {
        var parts: [String] = []
        if category == .hydration {
            let ml = Int(hydrationUnit.millilitres(for: hydrationAmount).rounded())
            parts.append("\(ml) ml entered as \(hydrationAmount.formatted()) \(hydrationUnit.shortTitle)")
        }
        let trimmedNotes = notes.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedNotes.isEmpty {
            parts.append(trimmedNotes)
        }
        return parts.joined(separator: " · ")
    }

    private func numericBinding(defaultValue: Double) -> Binding<Double> {
        Binding(
            get: { Double(value) ?? defaultValue },
            set: { value = String($0) }
        )
    }
}

private enum HydrationInputUnit: String, CaseIterable, Identifiable {
    case ml
    case litres
    case cups
    case glasses
    case bottles

    var id: String { rawValue }

    var title: String {
        switch self {
        case .ml: return "ml"
        case .litres: return "L"
        case .cups: return "Cups"
        case .glasses: return "Glasses"
        case .bottles: return "Bottles"
        }
    }

    var shortTitle: String { title.lowercased() }

    func millilitres(for amount: Double) -> Double {
        switch self {
        case .ml: return amount
        case .litres: return amount * 1000
        case .cups: return amount * 240
        case .glasses: return amount * 250
        case .bottles: return amount * 500
        }
    }

    func glasses(for amount: Double) -> Double {
        millilitres(for: amount) / 250
    }
}

struct UpdatesView: View {
    @EnvironmentObject private var store: RemoteLoveStore
    @State private var message = ""
    @State private var mood = "Comfortable"

    var body: some View {
        List {
            Section {
                RecipientHeader()
                    .listRowInsets(EdgeInsets())
            }
            Section("Quick update") {
                Picker("Mood", selection: $mood) {
                    ForEach(["Cheerful", "Comfortable", "Tired", "Uncomfortable"], id: \.self) { Text($0) }
                }
                TextField("Share how things are going…", text: $message, axis: .vertical)
                    .lineLimit(3...6)
                Button("Send update to family") {
                    store.sendUpdate(message: message, mood: mood)
                    message = ""
                }
                .disabled(message.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            Section("Recent updates") {
                let selected = store.updates.filter { $0.recipientID == store.selectedRecipientID }
                if selected.isEmpty {
                    Text("No updates sent yet.").foregroundColor(.secondary)
                } else {
                    ForEach(selected) { update in
                        VStack(alignment: .leading, spacing: 6) {
                            HStack { Text(update.author).bold(); Spacer(); Text(update.createdAt, style: .relative).font(.caption).foregroundColor(.secondary) }
                            Text(update.message)
                            Text(update.mood).font(.caption.bold()).foregroundColor(RemoteLoveTheme.green)
                        }
                        .padding(.vertical, 5)
                    }
                }
            }
        }
        .navigationTitle("Care updates")
    }
}

struct MoreView: View {
    @EnvironmentObject private var store: RemoteLoveStore
    @State private var showCareCircleDestination = false

    var body: some View {
        List {
            Section("Care") {
                if store.currentRole.canManageCare {
                    NavigationLink { CareCircleView() } label: { MoreNavigationRow(title: "Care circle", systemImage: "person.3.fill") }
                        .tutorialSpotlight(.moreCareCircle)
                }
                if store.canPurchaseCarePlan {
                    NavigationLink { CarePlanView() } label: { MoreNavigationRow(title: "Care plan", systemImage: "creditcard.fill") }
                        .tutorialSpotlight(.moreCarePlan)
                }
                NavigationLink { HistoryView() } label: { MoreNavigationRow(title: "Activity history", systemImage: "clock.arrow.circlepath") }
            }
            Section("Safety") {
                if store.currentRole.canManageCare {
                    NavigationLink { SafetyRulesView() } label: { MoreNavigationRow(title: "Safety and escalation rules", systemImage: "flag.fill") }
                        .tutorialSpotlight(.moreSafety)
                }
                NavigationLink { SafetyDisclaimerView() } label: { MoreNavigationRow(title: "Safety disclaimer", systemImage: "cross.case.fill") }
            }
            Section {
                NavigationLink { HelpCentreView() } label: { MoreNavigationRow(title: "Help centre", systemImage: "lifepreserver.fill") }
                NavigationLink { SupportRequestView(kind: .support) } label: { MoreNavigationRow(title: "Contact support", systemImage: "envelope.fill") }
                NavigationLink { SupportRequestView(kind: .bug) } label: { MoreNavigationRow(title: "Report a problem", systemImage: "exclamationmark.bubble.fill") }
                NavigationLink { SupportRequestView(kind: .feature) } label: { MoreNavigationRow(title: "Request a feature", systemImage: "sparkles") }
            } header: {
                Text("Customer Service")
            } footer: {
                Text("RemoteLove support is not for emergencies. Call local emergency services immediately if someone may be in danger.")
            }
            Section("Account") {
                NavigationLink { AppTutorialView(role: store.currentRole) } label: { MoreNavigationRow(title: "App tutorial", systemImage: "questionmark.circle.fill") }
                    .tutorialSpotlight(.moreTutorial)
                NavigationLink { SettingsView() } label: { MoreNavigationRow(title: "Settings and account", systemImage: "gearshape") }
            }
            Section("Legal") {
                NavigationLink { PrivacyPolicyView() } label: { MoreNavigationRow(title: "Privacy policy", systemImage: "hand.raised.fill") }
                NavigationLink { DataDeletionPolicyView() } label: { MoreNavigationRow(title: "Account and data deletion", systemImage: "trash.fill") }
            }
        }
        .navigationTitle("More")
        .tint(RemoteLoveTheme.green)
        .navigationDestination(isPresented: $showCareCircleDestination) {
            CareCircleView()
        }
        .onAppear(perform: openPendingMoreDestination)
        .onChange(of: store.pendingDestination) {
            openPendingMoreDestination()
        }
    }

    private func openPendingMoreDestination() {
        guard case .member = store.pendingDestination else { return }
        showCareCircleDestination = true
    }
}

private enum SupportRequestKind: String, CaseIterable, Identifiable {
    case support
    case bug
    case feature

    var id: String { rawValue }

    var navigationTitle: String {
        switch self {
        case .support: return "Contact support"
        case .bug: return "Report a problem"
        case .feature: return "Request a feature"
        }
    }

    var icon: String {
        switch self {
        case .support: return "envelope.fill"
        case .bug: return "exclamationmark.bubble.fill"
        case .feature: return "sparkles"
        }
    }

    var intro: String {
        switch self {
        case .support:
            return "Tell us what you need help with. For now this prototype records the request on this screen only."
        case .bug:
            return "Share what went wrong and what you were trying to do. Include any error message if you saw one."
        case .feature:
            return "Tell us what would make RemoteLove more useful for your care circle."
        }
    }

    var topicOptions: [String] {
        switch self {
        case .support:
            return ["Account and login", "Invite code", "Helper access", "Notifications", "Tasks and planner", "Health data", "Other"]
        case .bug:
            return ["Data not syncing", "Notification not showing", "Invite code not working", "Task or planner issue", "Photo upload issue", "App crash or freeze", "Other"]
        case .feature:
            return ["Care tasks", "Planner", "Health monitor", "Helpers", "Notifications", "Widgets", "Other"]
        }
    }

    var submitTitle: String {
        switch self {
        case .support: return "Submit support request"
        case .bug: return "Submit problem report"
        case .feature: return "Submit feature request"
        }
    }

    var confirmationTitle: String {
        switch self {
        case .support: return "Support request noted"
        case .bug: return "Problem report noted"
        case .feature: return "Feature request noted"
        }
    }
}

private struct HelpCentreView: View {
    private let sections: [HelpCentreSection] = [
        HelpCentreSection(
            title: "Account and login",
            icon: "person.crop.circle.fill",
            items: [
                HelpCentreItem(question: "How do family members join?", answer: "Family members create or sign in to an account, then enter a family invite code from the care circle."),
                HelpCentreItem(question: "How do helpers join?", answer: "Helpers use their name, helper invite code and helper PIN. Returning helpers can use their name and PIN on the same device.")
            ]
        ),
        HelpCentreSection(
            title: "Invite codes",
            icon: "person.badge.plus",
            items: [
                HelpCentreItem(question: "Which code should I share?", answer: "Share the family code with family members and the helper code with helpers."),
                HelpCentreItem(question: "Why is a code not working?", answer: "Check that the code matches the right type, has no extra spaces, and belongs to the care profile you want to join.")
            ]
        ),
        HelpCentreSection(
            title: "Tasks and planner",
            icon: "checklist",
            items: [
                HelpCentreItem(question: "Can helpers edit care records?", answer: "Helpers are view-and-complete only by default. Family members can enable helper editing from More > Care circle."),
                HelpCentreItem(question: "Why does a planner item appear in Care?", answer: "Medicines, appointments and other planner items are mirrored into Care so they can be followed as part of the routine.")
            ]
        ),
        HelpCentreSection(
            title: "Notifications and photos",
            icon: "bell.badge.fill",
            items: [
                HelpCentreItem(question: "How do I turn notifications off?", answer: "Open Permissions setup or iPhone Settings to manage RemoteLove notification access."),
                HelpCentreItem(question: "How do I manage photo access?", answer: "Use Permissions setup to request access first, then manage photo access from iPhone Settings.")
            ]
        ),
        HelpCentreSection(
            title: "Health data",
            icon: "heart.text.square.fill",
            items: [
                HelpCentreItem(question: "Are health labels medical advice?", answer: "No. RemoteLove helps track and flag readings, but it does not diagnose. Follow the care recipient's clinician-approved targets."),
                HelpCentreItem(question: "Can I export readings?", answer: "Yes. Health monitor can export selected categories or all health categories to CSV.")
            ]
        )
    ]

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Label("Help centre", systemImage: "lifepreserver.fill")
                        .font(.title3.bold())
                        .foregroundColor(RemoteLoveTheme.green)
                    Text("Quick answers for common RemoteLove questions.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 6)
            }

            ForEach(sections) { section in
                Section {
                    ForEach(section.items) { item in
                        DisclosureGroup {
                            Text(item.answer)
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                                .padding(.top, 6)
                        } label: {
                            Label(item.question, systemImage: section.icon)
                                .foregroundColor(.primary)
                        }
                    }
                } header: {
                    Text(section.title)
                }
            }

            Section {
                Text("RemoteLove support is not an emergency service. If someone may be in danger, call local emergency services immediately.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .navigationTitle("Help centre")
    }
}

private struct SupportRequestView: View {
    @EnvironmentObject private var store: RemoteLoveStore
    let kind: SupportRequestKind
    @State private var name = ""
    @State private var email = ""
    @State private var topic = ""
    @State private var message = ""
    @State private var showConfirmation = false

    private var canSubmit: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !topic.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        Form {
            Section {
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: kind.icon)
                        .font(.title2)
                        .foregroundColor(RemoteLoveTheme.green)
                        .frame(width: 44, height: 44)
                        .background(RemoteLoveTheme.green.opacity(0.12), in: Circle())
                        .accessibilityHidden(true)

                    VStack(alignment: .leading, spacing: 5) {
                        Text(kind.navigationTitle)
                            .font(.headline)
                        Text(kind.intro)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding(.vertical, 4)
            }

            Section("Your details") {
                TextField("Name", text: $name)
                    .textContentType(.name)
                TextField("Email", text: $email)
                    .keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .textContentType(.emailAddress)
            }

            Section("Topic") {
                Picker("Topic", selection: $topic) {
                    Text("Select topic").tag("")
                    ForEach(kind.topicOptions, id: \.self) { option in
                        Text(option).tag(option)
                    }
                }
            }

            Section("Message") {
                TextField(messagePlaceholder, text: $message, axis: .vertical)
                    .lineLimit(5...9)
            }

            Section {
                Button {
                    showConfirmation = true
                } label: {
                    Label(kind.submitTitle, systemImage: "paperplane.fill")
                }
                .disabled(!canSubmit)
            } footer: {
                Text("Prototype note: this creates a local confirmation only. We can connect this form to Supabase support requests later.")
            }
        }
        .navigationTitle(kind.navigationTitle)
        .onAppear {
            if name.isEmpty {
                name = store.currentUserName
            }
        }
        .alert(kind.confirmationTitle, isPresented: $showConfirmation) {
            Button("Done", role: .cancel) {
                topic = ""
                message = ""
            }
        } message: {
            Text("Thanks. Your message is ready for the support workflow once backend submission is connected.")
        }
    }

    private var messagePlaceholder: String {
        switch kind {
        case .support:
            return "How can we help?"
        case .bug:
            return "What happened? What did you expect instead?"
        case .feature:
            return "What would you like RemoteLove to support?"
        }
    }
}

private struct HelpCentreSection: Identifiable {
    let id = UUID()
    let title: String
    let icon: String
    let items: [HelpCentreItem]
}

private struct HelpCentreItem: Identifiable {
    let id = UUID()
    let question: String
    let answer: String
}

private struct MoreNavigationRow: View {
    let title: String
    let systemImage: String

    var body: some View {
        Label {
            Text(title)
                .foregroundColor(.primary)
        } icon: {
            Image(systemName: systemImage)
                .symbolRenderingMode(.monochrome)
                .foregroundColor(RemoteLoveTheme.green)
        }
    }
}

struct AppTutorialView: View {
    @Environment(\.dismiss) private var dismiss
    let role: UserRole
    var completionTitle: String?
    var onComplete: (() -> Void)?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 10) {
                    Image(systemName: "heart.text.square.fill")
                        .font(.system(size: 42))
                        .foregroundColor(RemoteLoveTheme.coral)
                        .accessibilityHidden(true)

                    Text("RemoteLove guide")
                        .font(.largeTitle.bold())

                    Text(introText)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding(.bottom, 4)

                Button {
                    onComplete?()
                    dismiss()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                        NotificationCenter.default.post(name: .remoteLoveStartGuidedTutorial, object: nil)
                    }
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "play.circle.fill")
                            .font(.title2)
                            .foregroundColor(RemoteLoveTheme.coral)
                            .frame(width: 34, height: 34)
                            .accessibilityHidden(true)

                        VStack(alignment: .leading, spacing: 3) {
                            Text("Start guided app walkthrough")
                                .font(.headline)
                                .foregroundColor(.primary)

                            Text("Walk through the real app tab by tab with Skip, Back and Next.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }

                        Spacer(minLength: 0)

                        Image(systemName: "chevron.right")
                            .font(.caption.weight(.bold))
                            .foregroundColor(.secondary)
                            .accessibilityHidden(true)
                    }
                    .padding(16)
                    .background(.background.opacity(0.92), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                }
                .buttonStyle(.plain)

                ForEach(tutorialSections) { section in
                    TutorialSectionCard(section: section)
                }
            }
            .padding(20)
        }
        .background(RemoteLoveTheme.mint.opacity(0.45).ignoresSafeArea())
        .navigationTitle("App tutorial")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if let completionTitle, let onComplete {
                ToolbarItem(placement: .confirmationAction) {
                    Button(completionTitle, action: onComplete)
                        .fontWeight(.semibold)
                }
            }
        }
    }

    private var introText: String {
        switch role {
        case .helper:
            return "A quick walkthrough of the helper buttons you will use most often."
        case .viewer:
            return "A quick walkthrough of the read-only areas available to you."
        case .owner, .family:
            return "A quick walkthrough of the main family buttons and care-circle tools."
        }
    }

    private var tutorialSections: [TutorialSection] {
        switch role {
        case .helper:
            return [
                TutorialSection(
                    title: "Bottom tabs",
                    icon: "rectangle.bottomthird.inset.filled",
                    tint: RemoteLoveTheme.green,
                    rows: [
                        TutorialRow(icon: "sun.max.fill", title: "Today", detail: "Shows today’s assigned tasks. Tap Done when a task is completed, or Undo if you tapped it by accident."),
                        TutorialRow(icon: "calendar", title: "Planner", detail: "Shows medicines, appointments and other reminders. You can add or edit planner items if your care circle allows helper editing."),
                        TutorialRow(icon: "heart.text.square", title: "Health", detail: "Log health readings and review past readings shared with the care circle."),
                        TutorialRow(icon: "gearshape", title: "Settings", detail: "Change appearance, review safety pages, open this tutorial again, or log out.")
                    ]
                ),
                TutorialSection(
                    title: "Daily care buttons",
                    icon: "checkmark.circle.fill",
                    tint: RemoteLoveTheme.coral,
                    rows: [
                        TutorialRow(icon: "checkmark.circle.fill", title: "Done", detail: "Marks only that day’s task as completed."),
                        TutorialRow(icon: "arrow.uturn.backward.circle", title: "Undo", detail: "Reopens a task if it was marked done by mistake."),
                        TutorialRow(icon: "camera.fill", title: "Photo proof", detail: "Adds a photo when a task asks for one.")
                    ]
                )
            ]
        case .viewer:
            return [
                TutorialSection(
                    title: "Bottom tabs",
                    icon: "rectangle.bottomthird.inset.filled",
                    tint: RemoteLoveTheme.green,
                    rows: [
                        TutorialRow(icon: "square.grid.2x2.fill", title: "Overview", detail: "Gives a quick summary of care status, people in the circle, tasks and health signals."),
                        TutorialRow(icon: "calendar", title: "Planner", detail: "View medicines, appointments and other planner items without changing care records."),
                        TutorialRow(icon: "heart.text.square", title: "Health", detail: "Review shared health readings for each care profile."),
                        TutorialRow(icon: "gearshape", title: "Settings", detail: "Change appearance, open this tutorial again, review policies, or log out.")
                    ]
                )
            ]
        case .owner, .family:
            return [
                TutorialSection(
                    title: "Bottom tabs",
                    icon: "rectangle.bottomthird.inset.filled",
                    tint: RemoteLoveTheme.green,
                    rows: [
                        TutorialRow(icon: "square.grid.2x2.fill", title: "Overview", detail: "A glanceable summary of people, care tasks, health readings and items needing attention."),
                        TutorialRow(icon: "checklist", title: "Care", detail: "Create tasks, review the next days of routine, mark tasks done, and undo or redo task edits until the app is cleared."),
                        TutorialRow(icon: "calendar", title: "Planner", detail: "Add medicines, appointments and other planner items, set refill attention levels, and choose appointment reminder timing."),
                        TutorialRow(icon: "heart.text.square", title: "Health", detail: "Log readings, check whether results look good or need attention, and export CSV data."),
                        TutorialRow(icon: "ellipsis.circle", title: "More", detail: "Manage members, share invite codes, view plans, open legal pages, settings and this tutorial.")
                    ]
                ),
                TutorialSection(
                    title: "Common action buttons",
                    icon: "plus.circle.fill",
                    tint: RemoteLoveTheme.coral,
                    rows: [
                        TutorialRow(icon: "plus.circle.fill", title: "Add", detail: "Creates a new task, medicine, appointment, care profile or health reading depending on the page."),
                        TutorialRow(icon: "square.and.arrow.up", title: "Share", detail: "Shares the selected invite code with another family member or helper."),
                        TutorialRow(icon: "arrow.down.doc.fill", title: "Download", detail: "Exports health readings as CSV for one category or all categories."),
                        TutorialRow(icon: "arrow.uturn.backward.circle", title: "Undo", detail: "Reverses recent task edits until the app is cleared.")
                    ]
                ),
                TutorialSection(
                    title: "Care-circle tools",
                    icon: "person.3.fill",
                    tint: RemoteLoveTheme.amber,
                    rows: [
                        TutorialRow(icon: "person.badge.plus", title: "Invite codes", detail: "Family and helper codes connect new people to the selected care profile."),
                        TutorialRow(icon: "creditcard.fill", title: "Care plan", detail: "Only family members can view or buy plans. Helpers do not see this area."),
                        TutorialRow(icon: "flag.fill", title: "Safety rules", detail: "Keep emergency and escalation information clear for the whole care circle.")
                    ]
                )
            ]
        }
    }
}

struct InteractiveTutorialView: View {
    @Environment(\.dismiss) private var dismiss
    let role: UserRole
    @State private var stepIndex = 0

    private var steps: [TutorialWalkthroughStep] {
        TutorialWalkthroughStep.steps(for: role)
    }

    private var currentStep: TutorialWalkthroughStep {
        steps[min(stepIndex, max(steps.count - 1, 0))]
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    VStack(alignment: .leading, spacing: 8) {
                        ProgressView(value: Double(stepIndex + 1), total: Double(max(steps.count, 1)))
                            .tint(RemoteLoveTheme.green)

                        Text("Step \(stepIndex + 1) of \(steps.count)")
                            .font(.caption.weight(.semibold))
                            .foregroundColor(.secondary)
                    }

                    TutorialWalkthroughCard(step: currentStep)
                        .id(currentStep.id)
                        .transition(.opacity.combined(with: .move(edge: .trailing)))
                }
                .padding(20)
            }

            Divider()

            HStack(spacing: 12) {
                Button {
                    withAnimation(.easeInOut(duration: 0.22)) {
                        stepIndex = max(0, stepIndex - 1)
                    }
                } label: {
                    Label("Back", systemImage: "chevron.left")
                }
                .buttonStyle(SecondaryButtonStyle())
                .disabled(stepIndex == 0)
                .opacity(stepIndex == 0 ? 0.45 : 1)

                Button {
                    if stepIndex == steps.count - 1 {
                        dismiss()
                    } else {
                        withAnimation(.easeInOut(duration: 0.22)) {
                            stepIndex += 1
                        }
                    }
                } label: {
                    Label(stepIndex == steps.count - 1 ? "Finish" : "Next", systemImage: stepIndex == steps.count - 1 ? "checkmark" : "chevron.right")
                }
                .buttonStyle(PrimaryButtonStyle())
            }
            .padding(16)
            .background(.ultraThinMaterial)
        }
        .background(RemoteLoveTheme.mint.opacity(0.45).ignoresSafeArea())
        .navigationTitle("Walkthrough")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Close") {
                    dismiss()
                }
            }
        }
    }
}

private struct TutorialWalkthroughCard: View {
    let step: TutorialWalkthroughStep

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top, spacing: 14) {
                Image(systemName: step.icon)
                    .font(.title2)
                    .foregroundColor(step.tint)
                    .frame(width: 48, height: 48)
                    .background(step.tint.opacity(0.14), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 5) {
                    Text(step.title)
                        .font(.title3.bold())

                    Text(step.subtitle)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            VStack(alignment: .leading, spacing: 10) {
                Label("Try this", systemImage: "hand.tap.fill")
                    .font(.headline)
                    .foregroundColor(step.tint)

                ForEach(step.actions) { action in
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: action.icon)
                            .font(.subheadline.weight(.semibold))
                            .foregroundColor(step.tint)
                            .frame(width: 28, height: 28)
                            .background(step.tint.opacity(0.10), in: Circle())
                            .accessibilityHidden(true)

                        VStack(alignment: .leading, spacing: 3) {
                            Text(action.title)
                                .font(.subheadline.weight(.semibold))

                            Text(action.detail)
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
            }

            VStack(alignment: .leading, spacing: 10) {
                Label("What you'll see", systemImage: "eye.fill")
                    .font(.headline)
                    .foregroundColor(RemoteLoveTheme.green)

                ForEach(step.highlights, id: \.self) { highlight in
                    Label {
                        Text(highlight)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    } icon: {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(RemoteLoveTheme.green)
                    }
                }
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.background.opacity(0.94), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
    }
}

private struct TutorialWalkthroughStep: Identifiable {
    let id: String
    let title: String
    let subtitle: String
    let icon: String
    let tint: Color
    let actions: [TutorialWalkthroughAction]
    let highlights: [String]

    static func steps(for role: UserRole) -> [TutorialWalkthroughStep] {
        switch role {
        case .helper:
            return helperSteps
        case .viewer:
            return viewerSteps
        case .owner, .family:
            return familySteps
        }
    }

    private static let familySteps: [TutorialWalkthroughStep] = [
        TutorialWalkthroughStep(
            id: "family-overview",
            title: "Start with Overview",
            subtitle: "Use this tab as the daily snapshot for every care profile you can access.",
            icon: "square.grid.2x2.fill",
            tint: RemoteLoveTheme.green,
            actions: [
                TutorialWalkthroughAction(id: "family-overview-profile", icon: "person.crop.circle", title: "Choose a care profile", detail: "Switch between Mum, Dad or another care recipient before reviewing the summary."),
                TutorialWalkthroughAction(id: "family-overview-status", icon: "list.bullet.clipboard", title: "Check today's status", detail: "Look for tasks due, completed tasks and items needing attention.")
            ],
            highlights: [
                "People are grouped by care profile so the care circle is easier to understand.",
                "Health readings show simple status labels, such as good or needs attention.",
                "Tapping a summary should guide you to the matching tab without opening edit sheets."
            ]
        ),
        TutorialWalkthroughStep(
            id: "family-care",
            title: "Run daily care",
            subtitle: "The Care tab is where routines, proof photos, task completion and task edits happen.",
            icon: "checklist",
            tint: RemoteLoveTheme.coral,
            actions: [
                TutorialWalkthroughAction(id: "family-care-dates", icon: "calendar", title: "Swipe through dates", detail: "Move across the next days of routine, then use Jump to Today to return."),
                TutorialWalkthroughAction(id: "family-care-add", icon: "plus.circle.fill", title: "Add or edit tasks", detail: "Create one-off tasks or recurring routines for selected days of the week."),
                TutorialWalkthroughAction(id: "family-care-done", icon: "checkmark.circle.fill", title: "Mark done when enabled", detail: "Families can complete tasks when the care circle setting allows family members to help.")
            ],
            highlights: [
                "Helpers can only complete today's tasks, while family permissions depend on your care setting.",
                "Photo-required tasks open the app so a photo can be attached.",
                "Undo and redo for task edits stay available until the app is cleared from memory."
            ]
        ),
        TutorialWalkthroughStep(
            id: "family-planner",
            title: "Plan ahead",
            subtitle: "The Planner tab keeps medicines, appointments and other reminders in one place.",
            icon: "calendar.badge.plus",
            tint: RemoteLoveTheme.amber,
            actions: [
                TutorialWalkthroughAction(id: "family-planner-add", icon: "plus.circle.fill", title: "Tap Add", detail: "Choose medicine, appointment or other depending on what you need to plan."),
                TutorialWalkthroughAction(id: "family-planner-reminders", icon: "bell.badge.fill", title: "Set reminders", detail: "Appointments can have custom reminder timing instead of one fixed reminder."),
                TutorialWalkthroughAction(id: "family-planner-edit", icon: "pencil", title: "Edit intentionally", detail: "Edit sheets should open only when you choose to edit that item.")
            ],
            highlights: [
                "Medicine attention appears in context without repeatedly popping up edit screens.",
                "Other planner items cover anything that is not a medicine or appointment.",
                "Planner data is shared with members who have access to the care profile."
            ]
        ),
        TutorialWalkthroughStep(
            id: "family-health",
            title: "Track health readings",
            subtitle: "Use Health for readings, status labels and CSV exports.",
            icon: "heart.text.square.fill",
            tint: RemoteLoveTheme.green,
            actions: [
                TutorialWalkthroughAction(id: "family-health-add", icon: "plus.circle.fill", title: "Log a reading", detail: "Add new health data for the selected care profile."),
                TutorialWalkthroughAction(id: "family-health-review", icon: "waveform.path.ecg", title: "Review the status", detail: "Each reading should show whether it looks good or needs attention."),
                TutorialWalkthroughAction(id: "family-health-export", icon: "arrow.down.doc.fill", title: "Download data", detail: "Export one category or all categories when you need a copy.")
            ],
            highlights: [
                "New health readings sync so other care-circle members can see them.",
                "The all export keeps each category separated for easier review.",
                "Use this for tracking patterns, not for emergency decisions."
            ]
        ),
        TutorialWalkthroughStep(
            id: "family-more",
            title: "Manage the care circle",
            subtitle: "More contains invite codes, plan access, tutorial, policies and settings.",
            icon: "ellipsis.circle.fill",
            tint: RemoteLoveTheme.coral,
            actions: [
                TutorialWalkthroughAction(id: "family-more-invites", icon: "person.badge.plus", title: "Share invite codes", detail: "Invite family members or helpers to the selected care profile."),
                TutorialWalkthroughAction(id: "family-more-mode", icon: "slider.horizontal.3", title: "Set who can complete tasks", detail: "Choose helper only, family only or both depending on how care is arranged."),
                TutorialWalkthroughAction(id: "family-more-tutorial", icon: "questionmark.circle.fill", title: "Return to this tutorial", detail: "Open More, then App tutorial whenever you want to review the app.")
            ],
            highlights: [
                "Only family members can view care plans.",
                "Helpers should not see family administration tools.",
                "Notification mute options live in settings and affect reminders."
            ]
        )
    ]

    private static let helperSteps: [TutorialWalkthroughStep] = [
        TutorialWalkthroughStep(
            id: "helper-today",
            title: "Start with Today",
            subtitle: "This is the helper home base for tasks that need attention today.",
            icon: "sun.max.fill",
            tint: RemoteLoveTheme.green,
            actions: [
                TutorialWalkthroughAction(id: "helper-today-review", icon: "list.bullet.clipboard", title: "Review today's tasks", detail: "Work down the list for the selected care profile."),
                TutorialWalkthroughAction(id: "helper-today-done", icon: "checkmark.circle.fill", title: "Tap Done", detail: "This completes only that specific task for today."),
                TutorialWalkthroughAction(id: "helper-today-photo", icon: "camera.fill", title: "Add photos when asked", detail: "Photo-required tasks open the camera or photo picker before completion.")
            ],
            highlights: [
                "Undo is available if you mark a task done by mistake.",
                "Future tasks are view-only for helpers.",
                "Finishing all tasks can show the Good Job completion animation."
            ]
        ),
        TutorialWalkthroughStep(
            id: "helper-planner",
            title: "Use Planner for upcoming care",
            subtitle: "Planner shows medicines, appointments and other items connected to the care profile.",
            icon: "calendar",
            tint: RemoteLoveTheme.amber,
            actions: [
                TutorialWalkthroughAction(id: "helper-planner-view", icon: "calendar.day.timeline.left", title: "Check upcoming items", detail: "Look ahead without changing task completion."),
                TutorialWalkthroughAction(id: "helper-planner-edit", icon: "pencil", title: "Add or edit if allowed", detail: "Some care circles allow helpers to add planner notes or update medicines."),
                TutorialWalkthroughAction(id: "helper-planner-alert", icon: "bell.badge.fill", title: "Notice reminders", detail: "Medicine and appointment reminders help keep the day on track.")
            ],
            highlights: [
                "Planner access is shared with the care circle.",
                "Medicine edit screens should open only when you choose Edit.",
                "Other items can capture non-medical reminders."
            ]
        ),
        TutorialWalkthroughStep(
            id: "helper-health",
            title: "Log health updates",
            subtitle: "Health lets helpers record readings and review recent care signals.",
            icon: "heart.text.square.fill",
            tint: RemoteLoveTheme.coral,
            actions: [
                TutorialWalkthroughAction(id: "helper-health-add", icon: "plus.circle.fill", title: "Add a reading", detail: "Record the reading requested by the family or care routine."),
                TutorialWalkthroughAction(id: "helper-health-status", icon: "waveform.path.ecg", title: "Read the status", detail: "Good or attention labels make readings easier to understand quickly."),
                TutorialWalkthroughAction(id: "helper-health-note", icon: "text.bubble.fill", title: "Add useful context", detail: "Use notes for things family members should know.")
            ],
            highlights: [
                "Health readings sync to the care circle.",
                "Use the app for tracking and communication, not emergency diagnosis.",
                "Families can review the same readings from their account."
            ]
        ),
        TutorialWalkthroughStep(
            id: "helper-settings",
            title: "Manage helper access",
            subtitle: "Settings keeps the helper session, PIN, notifications and tutorial.",
            icon: "gearshape.fill",
            tint: RemoteLoveTheme.green,
            actions: [
                TutorialWalkthroughAction(id: "helper-settings-pin", icon: "lock.fill", title: "Use your helper PIN", detail: "Returning helpers can unlock access with their name and PIN."),
                TutorialWalkthroughAction(id: "helper-settings-mute", icon: "bell.slash.fill", title: "Mute notifications carefully", detail: "Helpers can mute reminders, and the family is alerted when this happens."),
                TutorialWalkthroughAction(id: "helper-settings-tutorial", icon: "questionmark.circle.fill", title: "Open this tutorial again", detail: "Come back here from Settings whenever you need a refresher.")
            ],
            highlights: [
                "Helpers do not see care plans or family administration.",
                "Logging out clears access on that device.",
                "Notifications can be muted for a day, a few days, a month, forever or a custom time."
            ]
        )
    ]

    private static let viewerSteps: [TutorialWalkthroughStep] = [
        TutorialWalkthroughStep(
            id: "viewer-overview",
            title: "Review the overview",
            subtitle: "Viewer access is for checking care status without changing records.",
            icon: "square.grid.2x2.fill",
            tint: RemoteLoveTheme.green,
            actions: [
                TutorialWalkthroughAction(id: "viewer-overview-profile", icon: "person.crop.circle", title: "Choose a care profile", detail: "Switch to the person you want to review."),
                TutorialWalkthroughAction(id: "viewer-overview-summary", icon: "eye.fill", title: "Scan the summary", detail: "Look at people, tasks, planner items and health status.")
            ],
            highlights: [
                "Viewer access is read-only.",
                "Summary cards explain what needs attention.",
                "Details stay tied to the selected care profile."
            ]
        ),
        TutorialWalkthroughStep(
            id: "viewer-planner-health",
            title: "Check Planner and Health",
            subtitle: "Use these tabs to understand what is coming up and how readings look.",
            icon: "heart.text.square",
            tint: RemoteLoveTheme.coral,
            actions: [
                TutorialWalkthroughAction(id: "viewer-planner", icon: "calendar", title: "Open Planner", detail: "Review medicines, appointments and other upcoming items."),
                TutorialWalkthroughAction(id: "viewer-health", icon: "waveform.path.ecg", title: "Open Health", detail: "Review readings and their simple status labels."),
                TutorialWalkthroughAction(id: "viewer-settings", icon: "gearshape", title: "Use Settings", detail: "Change appearance, open policies, view this tutorial or log out.")
            ],
            highlights: [
                "You can view shared care information without editing it.",
                "Health labels make readings easier to scan.",
                "Legal and safety pages remain available from settings."
            ]
        )
    ]
}

private struct TutorialWalkthroughAction: Identifiable {
    let id: String
    let icon: String
    let title: String
    let detail: String
}

private struct TutorialSection: Identifiable {
    let id = UUID()
    let title: String
    let icon: String
    let tint: Color
    let rows: [TutorialRow]
}

private struct TutorialRow: Identifiable {
    let id = UUID()
    let icon: String
    let title: String
    let detail: String
}

private struct TutorialSectionCard: View {
    let section: TutorialSection

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label {
                Text(section.title)
                    .font(.headline)
            } icon: {
                Image(systemName: section.icon)
                    .foregroundColor(section.tint)
            }

            VStack(spacing: 12) {
                ForEach(section.rows) { row in
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: row.icon)
                            .font(.headline)
                            .foregroundColor(section.tint)
                            .frame(width: 26, height: 26)
                            .accessibilityHidden(true)

                        VStack(alignment: .leading, spacing: 3) {
                            Text(row.title)
                                .font(.subheadline.weight(.semibold))
                            Text(row.detail)
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }

                        Spacer(minLength: 0)
                    }
                }
            }
        }
        .padding(16)
        .background(.background.opacity(0.92), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

struct CareCircleView: View {
    @EnvironmentObject private var store: RemoteLoveStore
    @State private var showAddCareProfile = false

    private var selectedProfileMembers: [CircleMember] {
        store.members
            .filter { $0.recipientID == store.selectedRecipientID }
            .sorted { $0.joinedAt < $1.joinedAt }
    }

    private var activeMembers: [CircleMember] {
        selectedProfileMembers.filter(\.active)
    }

    private var familyMembers: [CircleMember] {
        activeMembers.filter { member in
            let role = member.role.lowercased()
            return role == "owner" || role == "family"
        }
    }

    private var helpers: [CircleMember] {
        activeMembers.filter { $0.role.lowercased() == "helper" }
    }

    private var viewersAndOthers: [CircleMember] {
        activeMembers.filter { member in
            let role = member.role.lowercased()
            return role != "owner" && role != "family" && role != "helper"
        }
    }

    private var inactiveMembers: [CircleMember] {
        selectedProfileMembers.filter { !$0.active }
    }

    var body: some View {
        ScrollViewReader { destinationProxy in
            List {
                Section {
                    CareCircleProfileSummaryCard(
                        recipient: store.selectedRecipient,
                        familyCount: familyMembers.count,
                        helperCount: helpers.count,
                        viewerCount: viewersAndOthers.count
                    )
                }

                if store.currentRole.canManageCare {
                    Section("Care profiles") {
                        Button {
                            showAddCareProfile = true
                        } label: {
                            Label("Add care profile", systemImage: "person.crop.circle.badge.plus")
                        }

                        Text("Create another profile for a different person in this care circle.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Section("Daily task completion") {
                        Picker("Who can mark tasks done?", selection: Binding(
                            get: { store.caregiverMode },
                            set: { store.updateCaregiverMode($0) }
                        )) {
                            ForEach(CaregiverMode.allCases) { mode in
                                Text(mode.title).tag(mode)
                            }
                        }

                        Text(store.caregiverMode.detail)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Section("Health monitor") {
                        Toggle("Show Health tab", isOn: Binding(
                            get: { store.healthFeatureEnabled },
                            set: { store.updateHealthFeatureEnabled($0) }
                        ))

                        Text(store.healthFeatureEnabled ? "Health readings appear in the tab bar and Overview." : "Health readings are hidden from the tab bar and Overview. Existing readings are kept and can be shown again later.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Section("Helper editing access") {
                        Toggle("Allow helpers to add and edit care records", isOn: Binding(
                            get: { store.helperEditingEnabledForSelectedProfile },
                            set: { store.updateHelperEditingAccess($0) }
                        ))
                        .disabled(helpers.isEmpty)

                        Text(helpers.isEmpty ? "Add a helper before turning this on. Helpers are view-and-complete only by default, with health logging available when Health is enabled." : "When enabled, active helpers for \(store.selectedRecipient.label) can add and edit tasks, medicines, appointments and other planner items.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Section("Family invite") {
                        InviteCodeBlock(
                            code: store.inviteCode,
                            title: "Family code",
                            detail: "Gives family access to \(store.selectedRecipient.label)’s care profile.",
                            icon: "person.2.fill",
                            shareTitle: "Share family code"
                        )
                    }
                    Section("Helper invite") {
                        InviteCodeBlock(
                            code: store.activeHelperInviteCode,
                            title: "Helper code",
                            detail: "Lets helpers access tasks, planner and health updates without family administration.",
                            icon: "key.fill",
                            shareTitle: "Share helper code"
                        )
                    }
                }

                memberSection(
                    title: "Family members",
                    emptyMessage: "No family members are linked to this profile yet.",
                    members: familyMembers
                )

                memberSection(
                    title: "Helpers",
                    emptyMessage: "No helpers have joined this profile yet.",
                    members: helpers
                )

                if !viewersAndOthers.isEmpty {
                    memberSection(
                        title: "Viewers and other roles",
                        emptyMessage: "",
                        members: viewersAndOthers
                    )
                }

                if !inactiveMembers.isEmpty {
                    Section("Removed access") {
                        ForEach(inactiveMembers) { member in
                            CircleMemberRow(member: member, canRemove: false, onRemove: { })
                                .id(DestinationScrollTarget.member(member.id))
                        }
                    }
                }
            }
            .destinationScrollReceiver(destinationProxy)
        }
        .navigationTitle("Care circle")
        .sheet(isPresented: $showAddCareProfile) {
            AddCareProfileView()
        }
        .onAppear(perform: openPendingMemberDestination)
        .onChange(of: store.pendingDestination) {
            openPendingMemberDestination()
        }
    }

    private func memberSection(title: String, emptyMessage: String, members: [CircleMember]) -> some View {
        Section {
            if members.isEmpty {
                Text(emptyMessage)
                    .font(.caption)
                    .foregroundColor(.secondary)
            } else {
                ForEach(members) { member in
                    CircleMemberRow(
                        member: member,
                        canRemove: store.currentRole.canManageCare && member.role.lowercased() == "helper",
                        onRemove: { store.removeHelper(member) }
                    )
                    .id(DestinationScrollTarget.member(member.id))
                }
            }
        } header: {
            Text("\(title) · \(members.count)")
        }
    }

    private func openPendingMemberDestination() {
        guard case let .member(recipientID, membershipID) = store.pendingDestination else { return }
        store.selectedRecipientID = recipientID
        store.pendingDestination = nil
        postDestinationScroll(DestinationScrollTarget.member(membershipID), delay: 0.45)
    }
}

private struct CareCircleProfileSummaryCard: View {
    let recipient: CareRecipient
    let familyCount: Int
    let helperCount: Int
    let viewerCount: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "person.3.fill")
                    .font(.title2)
                    .foregroundColor(RemoteLoveTheme.green)
                    .frame(width: 46, height: 46)
                    .background(RemoteLoveTheme.green.opacity(0.12), in: Circle())
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 3) {
                    Text("\(recipient.label) · \(recipient.name)")
                        .font(.headline)
                    Text("People with access to this care profile.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            HStack(spacing: 10) {
                CareCircleMetric(value: "\(familyCount)", title: "family", tint: RemoteLoveTheme.green)
                CareCircleMetric(value: "\(helperCount)", title: "helpers", tint: RemoteLoveTheme.coral)
                CareCircleMetric(value: "\(viewerCount)", title: "viewers", tint: RemoteLoveTheme.amber)
            }
        }
        .padding(.vertical, 4)
    }
}

private struct CareCircleMetric: View {
    let value: String
    let title: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(.headline.bold())
                .foregroundColor(tint)
            Text(title)
                .font(.caption2.weight(.semibold))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(tint.opacity(0.10), in: RoundedRectangle(cornerRadius: 13, style: .continuous))
    }
}

private struct InviteCodeBlock: View {
    let code: String
    let title: String
    let detail: String
    let icon: String
    let shareTitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(title, systemImage: icon)
                .font(.headline)
                .foregroundColor(RemoteLoveTheme.green)

            Text(code)
                .font(.system(.title2, design: .monospaced).bold())
                .textSelection(.enabled)

            Text(detail)
                .font(.caption)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            ShareLink(item: code) {
                Label(shareTitle, systemImage: "square.and.arrow.up")
                    .font(.subheadline.weight(.semibold))
            }
        }
        .padding(.vertical, 6)
    }
}

private struct CircleMemberRow: View {
    let member: CircleMember
    let canRemove: Bool
    let onRemove: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Text(initials)
                .font(.subheadline.bold())
                .foregroundColor(RemoteLoveTheme.green)
                .frame(width: 40, height: 40)
                .background(RemoteLoveTheme.green.opacity(0.13), in: Circle())

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(member.name)
                        .font(.subheadline.weight(.semibold))
                    if !member.active {
                        Text("Removed")
                            .font(.caption2.weight(.bold))
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3)
                            .background(Color.secondary.opacity(0.12), in: Capsule())
                    }
                }

                Text("\(member.role) · \(member.permission)")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Text("Joined \(member.joinedAt.formatted(date: .abbreviated, time: .omitted))")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }

            Spacer()

            if canRemove {
                Button("Remove", role: .destructive, action: onRemove)
                    .font(.caption.weight(.semibold))
            }
        }
        .padding(.vertical, 4)
    }

    private var initials: String {
        let parts = member.name.split(separator: " ")
        let letters = parts.prefix(2).compactMap(\.first)
        let result = String(letters).uppercased()
        return result.isEmpty ? "?" : result
    }
}

struct CarePlanView: View {
    @EnvironmentObject private var store: RemoteLoveStore
    @State private var selectedBilling: CarePlanBillingFilter = .monthly

    private var monthlyPlans: [CarePlan] {
        [.plusMonthly, .proMonthly]
    }

    private var yearlyPlans: [CarePlan] {
        [.plusYearly, .proYearly]
    }

    private var recommendedPlan: CarePlan {
        .plusYearly
    }

    private var visiblePlans: [CarePlan] {
        switch selectedBilling {
        case .monthly:
            return monthlyPlans
        case .yearly:
            return yearlyPlans
        case .lifetime:
            return [.lifetime]
        }
    }

    var body: some View {
        List {
            Section("Current care-circle plan") {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(store.activeCarePlan.name)
                                .font(.title3.bold())
                            Text(store.activeCarePlan.billing)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            Text(store.carePlanStatus.label)
                                .font(.caption.bold())
                                .foregroundColor(RemoteLoveTheme.green)
                        }
                        Spacer()
                        Text(store.activeCarePlan.price)
                            .font(.headline)
                            .foregroundColor(RemoteLoveTheme.green)
                    }
                    if store.carePlanStatus == .trialing, let endsAt = store.carePlanPeriodEndsAt {
                        CarePlanTimingNotice(
                            icon: "clock.badge.checkmark",
                            title: "Trial ends",
                            date: endsAt,
                            detail: "Payment begins after this time unless cancelled."
                        )
                    } else if store.carePlanStatus == .active {
                        if let endsAt = store.carePlanPeriodEndsAt {
                            CarePlanTimingNotice(
                                icon: "calendar.badge.clock",
                                title: store.activeCarePlan.billing == "Monthly" || store.activeCarePlan.billing == "Yearly" ? "Current plan period ends" : "Plan access ends",
                                date: endsAt,
                                detail: store.activeCarePlan.billing == "Monthly" || store.activeCarePlan.billing == "Yearly" ? "Renewal or next billing should happen after this period." : "This care circle keeps access until this date."
                            )
                        } else if store.activeCarePlan == .lifetime {
                            Label("Lifetime access has no plan end date.", systemImage: "infinity")
                                .font(.caption.weight(.semibold))
                                .foregroundColor(RemoteLoveTheme.green)
                        }
                    }
                    Text("One active plan unlocks features for every current and future member in this care circle.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 4)
            }

            Section {
                Picker("Billing period", selection: $selectedBilling) {
                    ForEach(CarePlanBillingFilter.allCases) { option in
                        Text(option.title).tag(option)
                    }
                }
                .pickerStyle(.segmented)
            } footer: {
                Text(selectedBilling.footer)
            }

            Section(selectedBilling.sectionTitle) {
                ForEach(visiblePlans) { plan in
                    CarePlanRow(plan: plan, isRecommended: plan == recommendedPlan)
                }
            }

#if DEBUG
            Section {
                if store.canPurchaseCarePlan {
                    Text("Prototype purchase buttons save the entitlement in RemoteLove. Real card details and trial billing should be handled by StoreKit before release.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                } else {
                    Text("Only a family member can buy or change the plan. Your access updates automatically when the care circle has an active plan.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
#else
            if !store.canPurchaseCarePlan {
                Section {
                    Text("Only a family member can buy or change the plan. Your access updates automatically when the care circle has an active plan.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
#endif

            if store.canPurchaseCarePlan, store.activeCarePlan.isPaid {
                Section {
                    Button("Cancel trial or plan", role: .destructive) {
                        Task {
                            await store.cancelCarePlan()
                        }
                    }
                    .disabled(store.isSyncing)
                } footer: {
                    Text("Cancelling immediately returns this care circle to the Free plan.")
                }
            }

            if let authMessage = store.authMessage, !authMessage.isEmpty {
                Section {
                    Text(authMessage)
                        .font(.footnote)
                        .foregroundColor(.secondary)
                }
            }
        }
        .navigationTitle("Care plan")
    }
}

private enum CarePlanBillingFilter: String, CaseIterable, Identifiable {
    case monthly
    case yearly
    case lifetime

    var id: String { rawValue }

    var title: String {
        switch self {
        case .monthly: return "Monthly"
        case .yearly: return "Yearly"
        case .lifetime: return "Lifetime"
        }
    }

    var sectionTitle: String {
        switch self {
        case .monthly: return "Monthly plans"
        case .yearly: return "Yearly plans"
        case .lifetime: return "One-time purchase"
        }
    }

    var footer: String {
        switch self {
        case .monthly:
            return "Monthly plans are flexible and renew every month."
        case .yearly:
            return "Yearly plans show the annual price and are usually better value."
        case .lifetime:
            return "Lifetime is a one-time purchase for one long-term care circle."
        }
    }
}

private struct CarePlanTimingNotice: View {
    let icon: String
    let title: String
    let date: Date
    let detail: String

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon)
                .foregroundColor(RemoteLoveTheme.green)
                .frame(width: 22)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 3) {
                Text("\(title): \(date.formatted(date: .abbreviated, time: .shortened))")
                    .font(.caption.weight(.bold))
                    .foregroundColor(.primary)
                Text(detail)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(10)
        .background(RemoteLoveTheme.green.opacity(0.08), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

private struct CarePlanRow: View {
    @EnvironmentObject private var store: RemoteLoveStore
    let plan: CarePlan
    var isRecommended = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text(plan.name)
                            .font(.headline)
                        if isRecommended {
                            Text("Recommended")
                                .font(.caption2.weight(.bold))
                                .foregroundColor(RemoteLoveTheme.onAccent)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(RemoteLoveTheme.coral, in: Capsule())
                        }
                    }
                    Text(plan.summary)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Text(plan.billing)
                        .font(.caption.bold())
                        .foregroundColor(RemoteLoveTheme.green)
                }
                Spacer()
                Text(plan.price)
                    .font(.subheadline.bold())
                    .multilineTextAlignment(.trailing)
            }

            ForEach(plan.features, id: \.self) { feature in
                Label(feature, systemImage: "checkmark.circle.fill")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            VStack(spacing: 8) {
                CarePlanLimitRow(icon: "person.crop.circle.fill", title: "Care profiles", value: plan.careProfileLimit)
                CarePlanLimitRow(icon: "person.2.fill", title: "Family members", value: plan.familyMemberLimit)
                CarePlanLimitRow(icon: "person.badge.clock.fill", title: "Helpers", value: plan.helperLimit)
            }
            .padding(12)
            .background(Color.secondary.opacity(0.07), in: RoundedRectangle(cornerRadius: 14, style: .continuous))

            if plan != .lifetime {
                Label("Includes a 3-day trial with payment starting after trial unless cancelled", systemImage: "clock.badge.checkmark")
                    .font(.caption)
                    .foregroundColor(RemoteLoveTheme.green)
            }

            if store.activeCarePlan == plan, store.carePlanStatus != .inactive {
                VStack(alignment: .leading, spacing: 6) {
                    Label(store.carePlanStatus == .trialing ? "Trialing for this care circle" : "Active for this care circle", systemImage: "checkmark.seal.fill")
                        .font(.subheadline.bold())
                        .foregroundColor(RemoteLoveTheme.green)

                    if let endText = activePlanTimingText {
                        Text(endText)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            } else if store.canPurchaseCarePlan {
                VStack(spacing: 8) {
                    Button("Start 3-day trial") {
                        Task {
                            await store.startCarePlanTrial(plan)
                        }
                    }
                    .disabled(store.isSyncing)
                    .buttonStyle(.borderedProminent)

                    Button("Buy \(plan.name) \(plan.billing)") {
                        Task {
                            await store.purchaseCarePlan(plan)
                        }
                    }
                    .disabled(store.isSyncing)
                    .buttonStyle(.bordered)
                }
            }
        }
        .padding(.vertical, 8)
        .padding(isRecommended ? 12 : 0)
        .background(
            isRecommended ? RemoteLoveTheme.coral.opacity(0.08) : Color.clear,
            in: RoundedRectangle(cornerRadius: 16, style: .continuous)
        )
        .overlay {
            if isRecommended {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(RemoteLoveTheme.coral.opacity(0.35), lineWidth: 1)
            }
        }
    }

    private var activePlanTimingText: String? {
        if store.carePlanStatus == .trialing, let endsAt = store.carePlanPeriodEndsAt {
            return "Trial ends \(endsAt.formatted(date: .abbreviated, time: .shortened))."
        }
        if store.carePlanStatus == .active, let endsAt = store.carePlanPeriodEndsAt {
            return "Current plan period ends \(endsAt.formatted(date: .abbreviated, time: .shortened))."
        }
        if store.carePlanStatus == .active, plan == .lifetime {
            return "Lifetime access has no end date."
        }
        return nil
    }
}

private struct CarePlanLimitRow: View {
    let icon: String
    let title: String
    let value: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .foregroundColor(RemoteLoveTheme.green)
                .frame(width: 22)
                .accessibilityHidden(true)
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .font(.caption.weight(.bold))
                .foregroundColor(.primary)
        }
    }
}

struct HistoryView: View {
    @EnvironmentObject private var store: RemoteLoveStore
    @State private var showAllProfiles = false
    @State private var selectedEvent: ActivityEvent?

    private var events: [ActivityEvent] {
        store.history.filter { showAllProfiles || $0.recipientID == store.selectedRecipientID }.sorted { $0.createdAt > $1.createdAt }
    }

    var body: some View {
        List {
            Section { Toggle("Show all care profiles", isOn: $showAllProfiles) }
            Section("Actions by everyone") {
                ForEach(events) { event in
                    Button {
                        store.navigate(to: .history(recipientID: event.recipientID, eventID: event.id))
                        selectedEvent = event
                    } label: {
                        VStack(alignment: .leading, spacing: 5) {
                            HStack { Text(event.action).bold(); Spacer(); Text(event.createdAt, style: .relative).font(.caption).foregroundColor(.secondary) }
                            Text(event.detail).font(.subheadline)
                            Text(event.actor).font(.caption.bold()).foregroundColor(RemoteLoveTheme.green)
                        }
                        .foregroundColor(.primary)
                    }
                    .padding(.vertical, 5)
                }
            }
        }
        .navigationTitle("Activity history")
        .sheet(item: $selectedEvent) { event in
            HistoryEventDetailView(event: event)
        }
    }
}

struct HistoryEventDetailView: View {
    let event: ActivityEvent
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section("Action") {
                    Text(event.action)
                    Text(event.detail)
                        .foregroundColor(.secondary)
                }
                Section("Actor") {
                    Text(event.actor)
                }
                Section("Time") {
                    Text(event.createdAt.formatted(date: .abbreviated, time: .shortened))
                }
            }
            .navigationTitle("History detail")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
    }
}

struct SafetyRulesView: View {
    @EnvironmentObject private var store: RemoteLoveStore
    @State private var missedTaskMinutes = 30
    @State private var noResponseMinutes = 10
    @State private var notifyOwner = true
    @State private var escalateAgain = true
    @State private var alertMissedCriticalMedicine = true
    @State private var alertBadHealthReading = true
    @State private var alertHelperEmergency = true
    @State private var alertMissedAppointment = false
    @State private var helperInstructions = "Stay with the care recipient if safe. Contact the primary family member first, and call local emergency services immediately if there may be danger."
    @State private var medicalNotes = "Add allergies, mobility risks, key conditions, preferred clinic, home address or where important documents are kept."
    @State private var showTestPreview = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                SafetyStatusCard(
                    recipientName: store.selectedRecipient.label,
                    completedSteps: completedSafetySteps,
                    totalSteps: 5,
                    activeContacts: activeFamilyContacts.count,
                    activeTriggers: activeTriggerCount
                )

                SafetySyncNoticeCard()

                SafetyChecklistCard(completedSteps: completedSafetySteps, totalSteps: 5)

                SafetyContactsCard(members: activeFamilyContacts)

                SafetyTriggersCard(
                    missedTaskMinutes: $missedTaskMinutes,
                    alertMissedCriticalMedicine: $alertMissedCriticalMedicine,
                    alertBadHealthReading: $alertBadHealthReading,
                    alertHelperEmergency: $alertHelperEmergency,
                    alertMissedAppointment: $alertMissedAppointment
                )

                SafetyEscalationCard(
                    noResponseMinutes: $noResponseMinutes,
                    notifyOwner: $notifyOwner,
                    escalateAgain: $escalateAgain
                )

                SafetyNotesCard(
                    title: "Helper instructions",
                    icon: "hands.sparkles.fill",
                    text: $helperInstructions,
                    placeholder: "What should helpers do first?"
                )

                SafetyNotesCard(
                    title: "Emergency medical info",
                    icon: "cross.case.fill",
                    text: $medicalNotes,
                    placeholder: "Allergies, conditions, address, clinic, document location..."
                )

                SafetyPreviewCard {
                    showTestPreview = true
                }

                NavigationLink {
                    SafetyDisclaimerView()
                } label: {
                    Label("Read full safety disclaimer", systemImage: "doc.text.magnifyingglass")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(16)
                        .remoteLoveSectionSurface(cornerRadius: 18)
                }
                .buttonStyle(.plain)
            }
            .padding(20)
        }
        .background(Color(uiColor: .systemGroupedBackground).ignoresSafeArea())
        .navigationTitle("Safety rules")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Test safety flow", isPresented: $showTestPreview) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("In a real emergency alert, RemoteLove would notify the selected care circle contacts. This is only a preview and does not contact emergency services.")
        }
    }

    private var activeFamilyContacts: [CircleMember] {
        store.selectedMembers.filter { member in
            member.active && member.role.lowercased() != "helper"
        }
    }

    private var activeTriggerCount: Int {
        [
            alertMissedCriticalMedicine,
            alertBadHealthReading,
            alertHelperEmergency,
            alertMissedAppointment
        ].filter { $0 }.count
    }

    private var completedSafetySteps: Int {
        var steps = 0
        if !activeFamilyContacts.isEmpty { steps += 1 }
        if activeTriggerCount > 0 { steps += 1 }
        if notifyOwner || escalateAgain { steps += 1 }
        if !helperInstructions.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { steps += 1 }
        if !medicalNotes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { steps += 1 }
        return steps
    }
}

private struct SafetySyncNoticeCard: View {
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.headline)
                .foregroundColor(RemoteLoveTheme.amber)
                .frame(width: 34, height: 34)
                .background(RemoteLoveTheme.amber.opacity(0.14), in: Circle())
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 4) {
                Text("Safety rules are device-local for now")
                    .font(.headline)
                Text("Use this as a planning checklist. Confirm urgent instructions directly with the care circle until safety rules are synced across accounts.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(16)
        .remoteLoveSectionSurface(cornerRadius: 18)
    }
}

private struct SafetyStatusCard: View {
    let recipientName: String
    let completedSteps: Int
    let totalSteps: Int
    let activeContacts: Int
    let activeTriggers: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 14) {
                Image(systemName: completedSteps == totalSteps ? "checkmark.shield.fill" : "shield.lefthalf.filled")
                    .font(.system(size: 34))
                    .foregroundColor(completedSteps == totalSteps ? RemoteLoveTheme.green : RemoteLoveTheme.amber)
                    .frame(width: 58, height: 58)
                    .background((completedSteps == totalSteps ? RemoteLoveTheme.green : RemoteLoveTheme.amber).opacity(0.14), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 5) {
                    Text(completedSteps == totalSteps ? "Safety setup active" : "Safety setup needs review")
                        .font(.title3.bold())
                    Text("\(recipientName)'s safety plan has \(completedSteps) of \(totalSteps) setup steps completed.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            ProgressView(value: Double(completedSteps), total: Double(totalSteps))
                .tint(completedSteps == totalSteps ? RemoteLoveTheme.green : RemoteLoveTheme.amber)

            HStack(spacing: 10) {
                SafetyMiniMetric(value: "\(activeContacts)", title: "contacts", tint: RemoteLoveTheme.green)
                SafetyMiniMetric(value: "\(activeTriggers)", title: "triggers", tint: RemoteLoveTheme.amber)
                SafetyMiniMetric(value: "Now", title: "helper alert", tint: RemoteLoveTheme.coral)
            }
        }
        .padding(18)
        .remoteLoveSectionSurface(cornerRadius: 24)
    }
}

private struct SafetyMiniMetric: View {
    let value: String
    let title: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(.headline.bold())
                .foregroundColor(tint)
            Text(title)
                .font(.caption2.weight(.semibold))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(tint.opacity(0.10), in: RoundedRectangle(cornerRadius: 13, style: .continuous))
    }
}

private struct SafetyChecklistCard: View {
    let completedSteps: Int
    let totalSteps: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SafetySectionHeader(icon: "checklist.checked", title: "Safety checklist", subtitle: "\(completedSteps) of \(totalSteps) steps completed")
            SafetyChecklistRow(done: completedSteps >= 1, title: "Add a family contact")
            SafetyChecklistRow(done: completedSteps >= 2, title: "Choose alert triggers")
            SafetyChecklistRow(done: completedSteps >= 3, title: "Set escalation timing")
            SafetyChecklistRow(done: completedSteps >= 4, title: "Write helper instructions")
            SafetyChecklistRow(done: completedSteps >= 5, title: "Add emergency medical notes")
        }
        .padding(18)
        .remoteLoveSectionSurface(cornerRadius: 22)
    }
}

private struct SafetyChecklistRow: View {
    let done: Bool
    let title: String

    var body: some View {
        Label {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        } icon: {
            Image(systemName: done ? "checkmark.circle.fill" : "circle")
                .foregroundColor(done ? RemoteLoveTheme.green : .secondary)
        }
    }
}

private struct SafetyContactsCard: View {
    let members: [CircleMember]

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            SafetySectionHeader(icon: "person.2.fill", title: "Emergency contacts", subtitle: "Family members who should receive urgent alerts first.")

            if members.isEmpty {
                Text("No family contacts found for this care profile yet. Add family members to the care circle before relying on safety alerts.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                ForEach(Array(members.prefix(4).enumerated()), id: \.element.id) { index, member in
                    HStack(spacing: 12) {
                        Text("\(index + 1)")
                            .font(.caption.bold())
                            .foregroundColor(RemoteLoveTheme.onAccent)
                            .frame(width: 28, height: 28)
                            .background(RemoteLoveTheme.green, in: Circle())
                        VStack(alignment: .leading, spacing: 2) {
                            Text(member.name)
                                .font(.subheadline.weight(.semibold))
                            Text(member.role + " · " + member.permission)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        Text(index == 0 ? "Primary" : "Backup")
                            .font(.caption2.weight(.bold))
                            .foregroundColor(index == 0 ? RemoteLoveTheme.green : .secondary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 5)
                            .background((index == 0 ? RemoteLoveTheme.green : Color.secondary).opacity(0.12), in: Capsule())
                    }
                }
            }
        }
        .padding(18)
        .remoteLoveSectionSurface(cornerRadius: 22)
    }
}

private struct SafetyTriggersCard: View {
    @Binding var missedTaskMinutes: Int
    @Binding var alertMissedCriticalMedicine: Bool
    @Binding var alertBadHealthReading: Bool
    @Binding var alertHelperEmergency: Bool
    @Binding var alertMissedAppointment: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            SafetySectionHeader(icon: "bell.badge.fill", title: "When should family be alerted?", subtitle: "Pick the moments that should become safety alerts.")

            Stepper("Task overdue by \(missedTaskMinutes) minutes", value: $missedTaskMinutes, in: 10...180, step: 10)
            Toggle("Missed critical medicine", isOn: $alertMissedCriticalMedicine)
            Toggle("Bad health reading entered", isOn: $alertBadHealthReading)
            Toggle("Helper presses emergency alert", isOn: $alertHelperEmergency)
            Toggle("Appointment may be missed", isOn: $alertMissedAppointment)
        }
        .padding(18)
        .remoteLoveSectionSurface(cornerRadius: 22)
    }
}

private struct SafetyEscalationCard: View {
    @Binding var noResponseMinutes: Int
    @Binding var notifyOwner: Bool
    @Binding var escalateAgain: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            SafetySectionHeader(icon: "arrow.triangle.branch", title: "Escalation flow", subtitle: "What RemoteLove should show when nobody responds.")

            SafetyFlowStep(number: "1", title: "Alert primary family", detail: "Notify the first family contact immediately.")
            SafetyFlowStep(number: "2", title: "Wait \(noResponseMinutes) minutes", detail: "Give the first contact time to respond.")
            SafetyFlowStep(number: "3", title: escalateAgain ? "Alert all family" : "Keep alert visible", detail: escalateAgain ? "Send another alert to the care circle." : "Do not send repeated alerts automatically.")

            Stepper("Escalate after \(noResponseMinutes) minutes", value: $noResponseMinutes, in: 5...60, step: 5)
            Toggle("Notify family owner first", isOn: $notifyOwner)
            Toggle("Repeat until acknowledged", isOn: $escalateAgain)
        }
        .padding(18)
        .remoteLoveSectionSurface(cornerRadius: 22)
    }
}

private struct SafetyFlowStep: View {
    let number: String
    let title: String
    let detail: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text(number)
                .font(.caption.bold())
                .foregroundColor(RemoteLoveTheme.onAccent)
                .frame(width: 26, height: 26)
                .background(RemoteLoveTheme.coral, in: Circle())
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                Text(detail)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
}

private struct SafetyNotesCard: View {
    let title: String
    let icon: String
    @Binding var text: String
    let placeholder: String

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SafetySectionHeader(icon: icon, title: title, subtitle: "Keep this simple and readable during stressful moments.")
            TextField(placeholder, text: $text, axis: .vertical)
                .lineLimit(4...8)
                .padding(14)
                .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .padding(18)
        .remoteLoveSectionSurface(cornerRadius: 22)
    }
}

private struct SafetyPreviewCard: View {
    let onPreview: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SafetySectionHeader(icon: "eye.fill", title: "Preview and test", subtitle: "Check what would happen before anyone depends on it.")
            Button {
                onPreview()
            } label: {
                Label("Preview test alert flow", systemImage: "play.circle.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(SecondaryButtonStyle())

            Text("RemoteLove is not an emergency service. Call local emergency services immediately if someone may be in danger.")
                .font(.caption)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(18)
        .remoteLoveSectionSurface(cornerRadius: 22)
    }
}

private struct SafetySectionHeader: View {
    let icon: String
    let title: String
    let subtitle: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.headline)
                .foregroundColor(RemoteLoveTheme.coral)
                .frame(width: 34, height: 34)
                .background(RemoteLoveTheme.coral.opacity(0.12), in: Circle())
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.headline)
                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

struct PrivacyPolicyView: View {
    var body: some View {
        PolicyListView(title: "Privacy policy", updated: "Last updated: September 19, 2026") {
            PolicySection(
                title: "What RemoteLove collects",
                rows: [
                    "Account details such as name, email address, role and care-circle membership.",
                    "Care information entered by family members or helpers, including care profiles, tasks, medicines, appointments, health readings, updates and activity history.",
                    "Invite-code and helper-access information needed to connect approved members to the correct care circle.",
                    "Basic technical information needed to sign in, sync data and keep the app working."
                ]
            )
            PolicySection(
                title: "How the information is used",
                rows: [
                    "To show the right care profiles, tasks, planner items, health logs and updates to approved care-circle members.",
                    "To help family members and helpers coordinate care.",
                    "To sync care-circle information across devices using Supabase.",
                    "To maintain account access, invite codes, permissions and app reliability."
                ]
            )
            PolicySection(
                title: "Who can see care information",
                rows: [
                    "People who have joined the same care circle may see information according to their role and permission level.",
                    "Helpers should only see information for care circles they have joined.",
                    "Do not share invite codes with anyone who should not have access to the care circle."
                ]
            )
            PolicySection(
                title: "Important privacy choices",
                rows: [
                    "Only enter information that you are comfortable sharing with the relevant care circle.",
                    "Do not enter emergency-only instructions, highly sensitive documents or information that should only be held by a licensed clinician.",
                    "Contact support or the care-circle owner if access should be removed."
                ]
            )
        }
    }
}

struct DataDeletionPolicyView: View {
    var body: some View {
        PolicyListView(title: "Account and data deletion", updated: "Last updated: September 19, 2026") {
            PolicySection(
                title: "What can be deleted",
                rows: [
                    "A user account can be removed from RemoteLove.",
                    "Care-circle information such as care profiles, tasks, medicines, appointments, health logs, updates and history can be deleted when requested by an authorised family owner.",
                    "Helper access can be removed by a family member with care-circle management permission."
                ]
            )
            PolicySection(
                title: "How to request deletion",
                rows: [
                    "Use the in-app care-circle controls where available, or contact the RemoteLove administrator/support contact for the current build.",
                    "Include the email address or helper name used in the app and the care-circle name or invite code if known.",
                    "For safety, deletion requests may require identity or ownership verification before care-circle data is removed."
                ]
            )
            PolicySection(
                title: "What happens after deletion",
                rows: [
                    "Deleted users may lose access to all care circles and shared care information.",
                    "Deleting a care profile may remove associated tasks, medicines, appointments, health logs, updates and history for that profile.",
                    "Some records may be retained temporarily if needed for security, legal compliance, backup recovery or abuse prevention."
                ]
            )
            PolicySection(
                title: "Before deleting shared care data",
                rows: [
                    "Export or copy any information that the family still needs.",
                    "Make sure the deletion request is agreed by the appropriate care-circle owner or family administrator.",
                    "RemoteLove is not a medical record system. Keep official medical records with the relevant healthcare provider."
                ]
            )
        }
    }
}

struct SafetyDisclaimerView: View {
    var body: some View {
        PolicyListView(title: "Safety disclaimer", updated: "Last updated: September 19, 2026") {
            PolicySection(
                title: "Not for emergencies",
                rows: [
                    "RemoteLove is not an emergency response service.",
                    "Do not rely on RemoteLove for urgent, life-threatening or time-critical care.",
                    "For immediate danger, serious symptoms or urgent medical concerns, contact local emergency services or a qualified healthcare professional."
                ]
            )
            PolicySection(
                title: "Not medical advice",
                rows: [
                    "RemoteLove does not diagnose, treat, prevent or cure medical conditions.",
                    "Health references and trends are informational only.",
                    "Always follow clinician-approved care plans, medication instructions and health targets."
                ]
            )
            PolicySection(
                title: "Care coordination limits",
                rows: [
                    "Tasks, reminders, updates and invite codes depend on accurate information entered by users.",
                    "Family members and helpers remain responsible for checking that care tasks are appropriate, current and completed safely.",
                    "Network issues, device settings, account access or incorrect data entry may delay or prevent updates from appearing."
                ]
            )
            PolicySection(
                title: "Medication and health readings",
                rows: [
                    "Confirm medication names, doses, timing and supply with the prescribing clinician or pharmacist.",
                    "Do not change medication or treatment based only on RemoteLove.",
                    "If a health reading looks unusual or concerning, follow the care recipient’s clinical advice or contact a healthcare professional."
                ]
            )
        }
    }
}

struct PolicyListView<Content: View>: View {
    let title: String
    let updated: String
    @ViewBuilder let content: Content

    var body: some View {
        List {
            Section {
                Text(updated)
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text("This in-app text is provided for transparency and should be reviewed before public release.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            content
        }
        .navigationTitle(title)
    }
}

struct PolicySection: View {
    let title: String
    let rows: [String]

    var body: some View {
        Section(title) {
            ForEach(rows, id: \.self) { row in
                Text(row)
            }
        }
    }
}

struct SettingsView: View {
    @EnvironmentObject private var store: RemoteLoveStore
    @AppStorage("appearance") private var appearance = "system"
    @AppStorage("colorPalette") private var colorPalette = "classic"
    @State private var confirmLogout = false
    @State private var customMuteUntil = Calendar.current.date(byAdding: .hour, value: 2, to: Date()) ?? Date()

    var body: some View {
        Form {
            Section("Signed in as") {
                LabeledContent("Name", value: store.currentUserName)
                LabeledContent("Access", value: accessLabel)
                if store.currentRole != .helper {
                    LabeledContent("Care plan", value: "\(store.activeCarePlan.name) · \(store.activeCarePlan.billing)")
                }
            }
            .tutorialSpotlight(.settingsHeader)
            if store.currentRole != .helper {
                Section("Care circle") {
                    NavigationLink { CarePlanView() } label: { Label("Care plan", systemImage: "creditcard.fill") }
                }
            }
            Section("Appearance") {
                Picker("Mode", selection: $appearance) {
                    Text("System").tag("system")
                    Text("Light").tag("light")
                    Text("Dark").tag("dark")
                }
                Picker("Color theme", selection: $colorPalette) {
                    ThemePalettePickerRow(
                        title: "Classic Care",
                        colors: [
                            UIColor(red: 0.18, green: 0.40, blue: 0.35, alpha: 1),
                            UIColor(red: 0.92, green: 0.36, blue: 0.36, alpha: 1),
                            UIColor(red: 0.88, green: 0.92, blue: 0.84, alpha: 1)
                        ]
                    )
                    .tag("classic")

                    ThemePalettePickerRow(
                        title: "Pink",
                        colors: [
                            UIColor(red: 0.78, green: 0.10, blue: 0.45, alpha: 1),
                            UIColor(red: 0.95, green: 0.28, blue: 0.62, alpha: 1),
                            UIColor(red: 1.00, green: 0.92, blue: 0.97, alpha: 1)
                        ]
                    )
                    .tag("pink")

                    ThemePalettePickerRow(
                        title: "Blue",
                        colors: [
                            UIColor(red: 0.05, green: 0.32, blue: 0.88, alpha: 1),
                            UIColor(red: 0.00, green: 0.54, blue: 0.86, alpha: 1),
                            UIColor(red: 0.92, green: 0.96, blue: 1.00, alpha: 1)
                        ]
                    )
                    .tag("blue")

                    ThemePalettePickerRow(
                        title: "Black",
                        colors: [
                            UIColor(red: 0.05, green: 0.06, blue: 0.09, alpha: 1),
                            UIColor(red: 0.18, green: 0.20, blue: 0.26, alpha: 1),
                            UIColor(red: 1.00, green: 0.38, blue: 0.72, alpha: 1)
                        ]
                    )
                    .tag("black")
                }
            }
            Section("Notifications") {
                NotificationSettingsPanel(customMuteUntil: $customMuteUntil)
            }
            .tutorialSpotlight(.settingsNotifications)
            Section("Help") {
                NavigationLink { PermissionOnboardingView() } label: { Label("Permissions setup", systemImage: "hand.tap.fill") }
                NavigationLink { AppTutorialView(role: store.currentRole) } label: { Label("App tutorial", systemImage: "questionmark.circle.fill") }
                    .tutorialSpotlight(.settingsTutorial)
            }
            Section {
                Button("Log out", role: .destructive) { confirmLogout = true }
            }
        }
        .navigationTitle("Settings")
        .alert("Log out?", isPresented: $confirmLogout) {
            Button("Cancel", role: .cancel) { }
            Button("Log out", role: .destructive) { store.logout() }
        } message: {
            Text("This clears the local session and returns RemoteLove to the welcome screen.")
        }
    }

    private var accessLabel: String {
        switch store.currentRole {
        case .owner:
            return "Owner"
        case .family:
            return "Family account"
        case .helper:
            return "Helper invite code"
        case .viewer:
            return "Viewer"
        }
    }
}

private struct ThemePalettePickerRow: View {
    let title: String
    let colors: [UIColor]

    var body: some View {
        HStack(spacing: 10) {
            Text(title)
            Spacer()
            HStack(spacing: -4) {
                ForEach(Array(colors.enumerated()), id: \.offset) { _, color in
                    Circle()
                        .fill(Color(color))
                        .frame(width: 18, height: 18)
                        .overlay {
                            Circle()
                                .stroke(Color.white.opacity(0.85), lineWidth: 1)
                        }
                }
            }
            .accessibilityHidden(true)
        }
    }
}

struct PermissionOnboardingView: View {
    @Environment(\.dismiss) private var dismiss
    var completionTitle: String?
    var onComplete: (() -> Void)?
    @State private var notificationStatus: PermissionStatus = .checking
    @State private var photoStatus: PermissionStatus = .checking
    @State private var isRequestingNotifications = false
    @State private var isRequestingPhotos = false
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    VStack(alignment: .leading, spacing: 8) {
                        Image(systemName: "hand.tap.fill")
                            .font(.system(size: 42))
                            .foregroundColor(RemoteLoveTheme.coral)
                            .accessibilityHidden(true)

                        Text("Set up permissions")
                            .font(.largeTitle.bold())

                        Text("RemoteLove works best when reminders and photo access are ready before the care routine gets busy.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.bottom, 4)

                    PermissionSetupCard(
                        icon: "bell.badge.fill",
                        title: "Notifications",
                        status: notificationStatus,
                        detail: "Get task, medicine, appointment and urgent family reminders.",
                        primaryActionTitle: notificationActionTitle,
                        isWorking: isRequestingNotifications,
                        onPrimaryAction: {
                            Task {
                                await handleNotificationPermissionAction()
                            }
                        }
                    )

                    PermissionSetupCard(
                        icon: "photo.on.rectangle.angled",
                        title: "Photo access",
                        status: photoStatus,
                        detail: "Allow RemoteLove to upload and share photos when you choose to add them.",
                        primaryActionTitle: photoActionTitle,
                        isWorking: isRequestingPhotos,
                        onPrimaryAction: {
                            Task {
                                await handlePhotoPermissionAction()
                            }
                        }
                    )

                    Text("You can change these later in iPhone Settings. Skipping now will not block the app, but some actions may ask again when used.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(20)
            }
            .background(RemoteLoveTheme.mint.opacity(0.45).ignoresSafeArea())
            .navigationTitle("Permissions")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(completionTitle ?? "Close") {
                        onComplete?()
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
            .task {
                await refreshStatuses()
            }
            .onChange(of: scenePhase) { _, phase in
                guard phase == .active else { return }
                Task {
                    await refreshStatuses()
                }
            }
        }
    }

    private var notificationActionTitle: String {
        switch notificationStatus {
        case .checking:
            return "Checking..."
        case .notRequested:
            return "Allow notifications"
        case .allowed:
            return "Manage notification settings"
        case .blocked, .unknown:
            return "Open Settings"
        case .limited, .manual:
            return "Manage in Settings"
        }
    }

    private var photoActionTitle: String {
        switch photoStatus {
        case .checking:
            return "Checking..."
        case .notRequested:
            return "Allow photo access"
        case .allowed, .limited:
            return "Manage photo access"
        case .blocked, .unknown:
            return "Open Settings"
        case .manual:
            return "Manage in Settings"
        }
    }

    private func refreshStatuses() async {
        notificationStatus = await currentNotificationStatus()
        photoStatus = currentPhotoStatus()
    }

    private func handleNotificationPermissionAction() async {
        guard notificationStatus == .notRequested else {
            openAppSettings()
            return
        }

        isRequestingNotifications = true
        _ = await RemoteLoveNotificationScheduler.requestAuthorizationIfNeeded()
        notificationStatus = await currentNotificationStatus()
        isRequestingNotifications = false
    }

    private func handlePhotoPermissionAction() async {
        guard photoStatus == .notRequested else {
            openAppSettings()
            return
        }

        isRequestingPhotos = true
        let status = await withCheckedContinuation { continuation in
            PHPhotoLibrary.requestAuthorization(for: .readWrite) { status in
                continuation.resume(returning: status)
            }
        }
        photoStatus = PermissionStatus(photoAuthorizationStatus: status)
        isRequestingPhotos = false
    }

    private func currentNotificationStatus() async -> PermissionStatus {
        let settings = await withCheckedContinuation { continuation in
            UNUserNotificationCenter.current().getNotificationSettings { settings in
                continuation.resume(returning: settings)
            }
        }

        switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            return .allowed
        case .denied:
            return .blocked
        case .notDetermined:
            return .notRequested
        @unknown default:
            return .unknown
        }
    }

    private func currentPhotoStatus() -> PermissionStatus {
        PermissionStatus(photoAuthorizationStatus: PHPhotoLibrary.authorizationStatus(for: .readWrite))
    }

    private func openAppSettings() {
        #if canImport(UIKit)
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
        #endif
    }
}

private enum PermissionStatus: Hashable {
    case checking
    case notRequested
    case allowed
    case limited
    case blocked
    case manual
    case unknown

    init(photoAuthorizationStatus status: PHAuthorizationStatus) {
        switch status {
        case .authorized:
            self = .allowed
        case .limited:
            self = .limited
        case .denied, .restricted:
            self = .blocked
        case .notDetermined:
            self = .notRequested
        @unknown default:
            self = .unknown
        }
    }

    var label: String {
        switch self {
        case .checking:
            return "Checking"
        case .notRequested:
            return "Not set up"
        case .allowed:
            return "Allowed"
        case .limited:
            return "Limited"
        case .blocked:
            return "Blocked"
        case .manual:
            return "Manual setup"
        case .unknown:
            return "Unknown"
        }
    }

    var icon: String {
        switch self {
        case .allowed:
            return "checkmark.circle.fill"
        case .limited, .manual:
            return "info.circle.fill"
        case .blocked:
            return "xmark.circle.fill"
        case .checking:
            return "clock.fill"
        case .notRequested, .unknown:
            return "questionmark.circle.fill"
        }
    }

    var tint: Color {
        switch self {
        case .allowed:
            return RemoteLoveTheme.green
        case .limited, .manual, .notRequested:
            return RemoteLoveTheme.amber
        case .blocked:
            return RemoteLoveTheme.coral
        case .checking, .unknown:
            return .secondary
        }
    }
}

private struct PermissionSetupCard<ExtraContent: View>: View {
    let icon: String
    let title: String
    let status: PermissionStatus
    let detail: String
    let primaryActionTitle: String
    let isWorking: Bool
    let onPrimaryAction: () -> Void
    let extraContent: ExtraContent

    init(
        icon: String,
        title: String,
        status: PermissionStatus,
        detail: String,
        primaryActionTitle: String,
        isWorking: Bool,
        onPrimaryAction: @escaping () -> Void,
        @ViewBuilder extraContent: () -> ExtraContent
    ) {
        self.icon = icon
        self.title = title
        self.status = status
        self.detail = detail
        self.primaryActionTitle = primaryActionTitle
        self.isWorking = isWorking
        self.onPrimaryAction = onPrimaryAction
        self.extraContent = extraContent()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundColor(RemoteLoveTheme.green)
                    .frame(width: 42, height: 42)
                    .background(RemoteLoveTheme.green.opacity(0.12), in: Circle())
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.headline)
                    Text(detail)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)
            }

            Label(status.label, systemImage: status.icon)
                .font(.caption.weight(.bold))
                .foregroundColor(status.tint)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(status.tint.opacity(0.12), in: Capsule())

            extraContent

            Button {
                onPrimaryAction()
            } label: {
                Label(isWorking ? "Working..." : primaryActionTitle, systemImage: actionIcon)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(PrimaryButtonStyle(tint: status == .allowed || status == .limited ? RemoteLoveTheme.green.opacity(0.82) : RemoteLoveTheme.green))
            .disabled(isWorking || status == .checking)

            if status == .blocked {
                Text("Access is blocked in iPhone Settings. Open Settings if you want to change it.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } else if status == .allowed || status == .limited {
                Text("To reduce or turn off this access later, manage it in iPhone Settings.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(18)
        .background(.background.opacity(0.94), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
    }

    private var actionIcon: String {
        switch status {
        case .allowed, .limited, .blocked:
            return "gearshape.fill"
        case .checking:
            return "clock.fill"
        default:
            return "arrow.right"
        }
    }
}

private extension PermissionSetupCard where ExtraContent == EmptyView {
    init(
        icon: String,
        title: String,
        status: PermissionStatus,
        detail: String,
        primaryActionTitle: String,
        isWorking: Bool,
        onPrimaryAction: @escaping () -> Void
    ) {
        self.init(
            icon: icon,
            title: title,
            status: status,
            detail: detail,
            primaryActionTitle: primaryActionTitle,
            isWorking: isWorking,
            onPrimaryAction: onPrimaryAction
        ) {
            EmptyView()
        }
    }
}

private struct PermissionInstructionRow: View {
    let number: String
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Text(number)
                .font(.caption.bold())
                .foregroundColor(RemoteLoveTheme.onAccent)
                .frame(width: 24, height: 24)
                .background(RemoteLoveTheme.coral, in: Circle())
            Text(text)
                .font(.caption)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

private struct NotificationSettingsPanel: View {
    @EnvironmentObject private var store: RemoteLoveStore
    @Binding var customMuteUntil: Date
    @State private var permissionStatus = "Checking..."
    @State private var isRequestingPermission = false
    @State private var isSendingTest = false

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            notificationStatusHeader

            VStack(alignment: .leading, spacing: 10) {
                Text("Reminder categories")
                    .font(.caption.weight(.bold))
                    .foregroundColor(.secondary)

                NotificationCategoryRow(
                    icon: "checklist",
                    title: "Care tasks",
                    detail: "Due tasks can show Done or Attending actions.",
                    tint: RemoteLoveTheme.green
                )
                NotificationCategoryRow(
                    icon: "pills.fill",
                    title: "Medicines",
                    detail: "Medicine reminders follow the planner schedule.",
                    tint: RemoteLoveTheme.amber
                )
                NotificationCategoryRow(
                    icon: "calendar.badge.clock",
                    title: "Appointments",
                    detail: "Appointment reminders use the timing selected in Planner.",
                    tint: RemoteLoveTheme.coral
                )
                NotificationCategoryRow(
                    icon: "exclamationmark.triangle.fill",
                    title: "Urgent alerts",
                    detail: "Emergency and helper mute updates stay visible to the family.",
                    tint: .red
                )
            }

            Divider()

            muteControls

            if store.currentRole == .helper {
                Label {
                    Text("When helpers mute notifications, family members will see an update in the care circle.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                } icon: {
                    Image(systemName: "person.2.wave.2.fill")
                        .foregroundColor(RemoteLoveTheme.amber)
                }
            }
        }
        .padding(.vertical, 4)
        .task {
            await refreshPermissionStatus()
        }
    }

    private var notificationStatusHeader: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label {
                Text(store.notificationMuteStatusText)
                    .font(.subheadline.weight(.semibold))
            } icon: {
                Image(systemName: store.notificationsAreMuted ? "bell.slash.fill" : "bell.fill")
            }
            .foregroundColor(store.notificationsAreMuted ? .secondary : RemoteLoveTheme.green)

            HStack {
                Label(permissionStatus, systemImage: permissionIcon)
                    .font(.caption.weight(.semibold))
                    .foregroundColor(permissionTint)

                Spacer()

                Button(isRequestingPermission ? "Checking..." : "Allow") {
                    Task {
                        await requestPermission()
                    }
                }
                .disabled(isRequestingPermission || permissionStatus == "Allowed")
                .font(.caption.weight(.semibold))
            }

            Button {
                Task {
                    await sendTestNotification()
                }
            } label: {
                Label(isSendingTest ? "Sending test..." : "Send test notification", systemImage: "paperplane.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .disabled(isSendingTest || permissionStatus == "Blocked")
        }
    }

    private var muteControls: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Mute reminders")
                .font(.caption.weight(.bold))
                .foregroundColor(.secondary)

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 132), spacing: 8)], spacing: 8) {
                ForEach(NotificationMutePreset.allCases.filter { $0 != .custom }) { preset in
                    Button(role: preset == .forever ? .destructive : nil) {
                        store.muteNotifications(preset)
                    } label: {
                        Text(shortMuteTitle(for: preset))
                            .font(.caption.weight(.semibold))
                            .frame(maxWidth: .infinity, minHeight: 36)
                    }
                    .buttonStyle(.bordered)
                }
            }

            DatePicker("Custom until", selection: $customMuteUntil, in: Date()...)

            Button {
                store.muteNotifications(.custom, customUntil: customMuteUntil)
            } label: {
                Label("Mute until selected time", systemImage: "clock.badge")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)

            if store.notificationsAreMuted {
                Button {
                    store.unmuteNotifications()
                } label: {
                    Label("Turn notifications back on", systemImage: "bell.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(PrimaryButtonStyle())
            }
        }
    }

    private var permissionIcon: String {
        switch permissionStatus {
        case "Allowed":
            return "checkmark.circle.fill"
        case "Blocked":
            return "xmark.circle.fill"
        default:
            return "questionmark.circle.fill"
        }
    }

    private var permissionTint: Color {
        switch permissionStatus {
        case "Allowed":
            return RemoteLoveTheme.green
        case "Blocked":
            return RemoteLoveTheme.coral
        default:
            return RemoteLoveTheme.amber
        }
    }

    private func shortMuteTitle(for preset: NotificationMutePreset) -> String {
        switch preset {
        case .today:
            return "Today"
        case .threeDays:
            return "3 days"
        case .week:
            return "1 week"
        case .month:
            return "1 month"
        case .forever:
            return "Forever"
        case .custom:
            return "Custom"
        }
    }

    private func requestPermission() async {
        isRequestingPermission = true
        _ = await RemoteLoveNotificationScheduler.requestAuthorizationIfNeeded()
        await refreshPermissionStatus()
        isRequestingPermission = false
    }

    private func sendTestNotification() async {
        isSendingTest = true
        let scheduled = await RemoteLoveNotificationScheduler.sendImmediate(
            title: "💚 RemoteLove reminder test",
            body: "Notifications are working. Care reminders will appear here.",
            identifier: "settings-test.\(UUID().uuidString)"
        )
        await refreshPermissionStatus()
        store.authMessage = scheduled
            ? "Test notification scheduled. It should appear in a moment."
            : "Notifications are not allowed. Open iPhone Settings to enable them for RemoteLove."
        isSendingTest = false
    }

    private func refreshPermissionStatus() async {
        let settings = await notificationSettings()
        switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            permissionStatus = "Allowed"
        case .denied:
            permissionStatus = "Blocked"
        case .notDetermined:
            permissionStatus = "Not allowed yet"
        @unknown default:
            permissionStatus = "Unknown"
        }
    }

    private func notificationSettings() async -> UNNotificationSettings {
        await withCheckedContinuation { continuation in
            UNUserNotificationCenter.current().getNotificationSettings { settings in
                continuation.resume(returning: settings)
            }
        }
    }
}

private struct NotificationCategoryRow: View {
    let icon: String
    let title: String
    let detail: String
    let tint: Color

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon)
                .font(.subheadline.weight(.semibold))
                .foregroundColor(tint)
                .frame(width: 28, height: 28)
                .background(tint.opacity(0.12), in: Circle())
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                Text(detail)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

struct EmergencyBanner: View {
    @EnvironmentObject private var store: RemoteLoveStore
    let message: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Urgent response needed", systemImage: "exclamationmark.triangle.fill").font(.headline)
            Text(message).font(.subheadline)
            Button("I’m responding") { store.acknowledgeEmergency() }.buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color.red.opacity(0.13), in: RoundedRectangle(cornerRadius: 20))
        .padding(.horizontal)
    }
}

struct MetricCard: View {
    let value: String
    let label: String
    let icon: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(systemName: icon).foregroundColor(tint).font(.title2)
            Text(value).font(.title.bold())
            Text(label).font(.caption).foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .remoteLoveSectionSurface()
    }
}

private enum LoginMessageStyle {
    case info
    case error

    var tint: Color {
        switch self {
        case .info:
            return RemoteLoveTheme.green
        case .error:
            return RemoteLoveTheme.coral
        }
    }

    var iconName: String {
        switch self {
        case .info:
            return "checkmark.circle.fill"
        case .error:
            return "exclamationmark.triangle.fill"
        }
    }
}

private struct LoginMessageBanner: View {
    let message: String
    let style: LoginMessageStyle

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: style.iconName)
                .font(.subheadline.weight(.semibold))
                .foregroundColor(style.tint)
                .accessibilityHidden(true)

            Text(message)
                .font(.footnote)
                .foregroundColor(.primary)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 0)
        }
        .padding(12)
        .background(style.tint.opacity(0.10), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(style.tint.opacity(0.20), lineWidth: 1)
        }
        .accessibilityElement(children: .combine)
    }
}

private extension String {
    var isErrorLike: Bool {
        let lowercasedMessage = lowercased()
        return lowercasedMessage.contains("failed")
            || lowercasedMessage.contains("error")
            || lowercasedMessage.contains("enter")
            || lowercasedMessage.contains("could not")
            || lowercasedMessage.contains("does not match")
            || lowercasedMessage.contains("please sign in")
    }
}

struct NativeCard<Content: View>: View {
    let title: String
    let subtitle: String
    let icon: String
    var tint: Color = RemoteLoveTheme.green
    let content: Content

    init(title: String, subtitle: String, icon: String, tint: Color = RemoteLoveTheme.green, @ViewBuilder content: () -> Content) {
        self.title = title
        self.subtitle = subtitle
        self.icon = icon
        self.tint = tint
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                Image(systemName: icon).foregroundColor(tint).font(.title3)
                VStack(alignment: .leading, spacing: 2) { Text(title).font(.headline); Text(subtitle).font(.caption).foregroundColor(.secondary) }
            }
            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .remoteLoveSectionSurface()
        .padding(.horizontal)
    }
}

struct StatusCapsule: View {
    let state: TaskState
    private var color: Color {
        switch state { case .done: return RemoteLoveTheme.green; case .attending: return .blue; case .paused: return .secondary; case .pending: return RemoteLoveTheme.amber }
    }
    var body: some View {
        Text(state.label)
            .font(.caption.bold())
            .foregroundColor(color)
            .padding(.horizontal, 9)
            .padding(.vertical, 5)
            .background(color.opacity(0.13), in: Capsule())
            .scaleEffect(state == .done ? 1.04 : 1)
            .animation(.spring(response: 0.26, dampingFraction: 0.76), value: state)
    }
}

struct HealthStatusCapsule: View {
    let status: HealthReadingStatus

    private var color: Color {
        switch status {
        case .good:
            return RemoteLoveTheme.green
        case .watch:
            return RemoteLoveTheme.amber
        case .needsAttention:
            return RemoteLoveTheme.coral
        case .trendOnly:
            return .secondary
        }
    }

    var body: some View {
        Text(status.label)
            .font(.caption2.weight(.bold))
            .foregroundColor(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(color.opacity(0.14), in: Capsule())
            .scaleEffect(status == .needsAttention ? 1.04 : 1)
            .animation(.spring(response: 0.26, dampingFraction: 0.78), value: status)
    }
}

struct HealthLegendRow: View {
    let status: HealthReadingStatus

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            HealthStatusCapsule(status: status)
            Text(status.summary)
                .font(.caption)
                .foregroundColor(.secondary)
            Spacer()
        }
    }
}

struct TaskCompletionCelebrationView: View {
    @State private var animate = false

    private let confetti = TaskCompletionConfettiPiece.celebrationBurst()

    var body: some View {
        ZStack {
            Color.black.opacity(0.18)
                .ignoresSafeArea()

            ZStack {
                ForEach(Array(confetti.enumerated()), id: \.offset) { index, piece in
                    confettiPiece(piece)
                        .rotationEffect(.degrees(animate ? piece.rotation : 0))
                        .offset(
                            x: animate ? piece.x : 0,
                            y: animate ? piece.y : 8
                        )
                        .scaleEffect(animate ? 1 : 0.25)
                        .opacity(animate ? 0.98 : 0)
                        .animation(.spring(response: 0.72, dampingFraction: 0.70).delay(Double(index % 18) * 0.014), value: animate)
                }

                VStack(spacing: 14) {
                    ZStack {
                        ForEach(0..<3, id: \.self) { index in
                            Circle()
                                .stroke(RemoteLoveTheme.green.opacity(0.20 - Double(index) * 0.04), lineWidth: 8)
                                .frame(width: 98 + CGFloat(index * 28), height: 98 + CGFloat(index * 28))
                                .scaleEffect(animate ? 1.35 : 0.70)
                                .opacity(animate ? 0 : 1)
                                .animation(.easeOut(duration: 0.86).delay(Double(index) * 0.08), value: animate)
                        }

                        Circle()
                            .fill(RemoteLoveTheme.green.opacity(0.16))
                            .frame(width: 94, height: 94)

                        Circle()
                            .stroke(RemoteLoveTheme.green.opacity(0.28), lineWidth: 10)
                            .frame(width: 94, height: 94)
                            .scaleEffect(animate ? 1.16 : 0.72)
                            .opacity(animate ? 0 : 1)
                            .animation(.easeOut(duration: 0.72), value: animate)

                        Image(systemName: "checkmark")
                            .font(.system(size: 44, weight: .black, design: .rounded))
                            .foregroundColor(RemoteLoveTheme.green)
                            .scaleEffect(animate ? 1.12 : 0.55)
                            .rotationEffect(.degrees(animate ? 0 : -14))
                            .animation(.spring(response: 0.36, dampingFraction: 0.54).delay(0.04), value: animate)

                        Image(systemName: "heart.fill")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(RemoteLoveTheme.coral)
                            .offset(x: 34, y: -32)
                            .scaleEffect(animate ? 1 : 0.2)
                            .opacity(animate ? 1 : 0)
                            .animation(.spring(response: 0.34, dampingFraction: 0.58).delay(0.16), value: animate)
                    }

                    VStack(spacing: 4) {
                        Text("Good job!")
                            .font(.system(size: 30, weight: .bold, design: .rounded))
                        Text("All tasks completed")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        Text("Care is all checked off for today.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.horizontal, 34)
                .padding(.vertical, 28)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .stroke(RemoteLoveTheme.green.opacity(0.32), lineWidth: 1)
                }
                .shadow(color: RemoteLoveTheme.green.opacity(0.18), radius: 28, y: 12)
                .shadow(color: .black.opacity(0.16), radius: 18, y: 10)
                .scaleEffect(animate ? 1 : 0.88)
                .opacity(animate ? 1 : 0)
                .animation(.spring(response: 0.36, dampingFraction: 0.76), value: animate)
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Good job. All tasks completed.")
        }
        .onAppear {
            animate = false
            withAnimation {
                animate = true
            }
        }
    }

    @ViewBuilder
    private func confettiPiece(_ piece: TaskCompletionConfettiPiece) -> some View {
        switch piece.shape {
        case .circle:
            Circle()
                .fill(piece.color)
                .frame(width: piece.width, height: piece.height)
        case .capsule:
            Capsule()
                .fill(piece.color)
                .frame(width: piece.width, height: piece.height)
        }
    }
}

private struct TaskCompletionConfettiPiece {
    enum ShapeKind {
        case circle
        case capsule
    }

    let x: CGFloat
    let y: CGFloat
    let width: CGFloat
    let height: CGFloat
    let rotation: Double
    let color: Color
    let shape: ShapeKind

    static func celebrationBurst() -> [TaskCompletionConfettiPiece] {
        let colors = [
            RemoteLoveTheme.green,
            RemoteLoveTheme.coral,
            RemoteLoveTheme.amber,
            Color.blue.opacity(0.82),
            Color.pink.opacity(0.82)
        ]

        return (0..<64).map { index in
            let angle = (Double(index) / 64.0) * Double.pi * 2.0
            let ring = CGFloat(index % 4)
            let radius = CGFloat(150 + (index % 9) * 18) + ring * 16
            let wave = CGFloat((index % 7) - 3) * 12
            let x = cos(angle) * radius + wave
            let y = sin(angle) * radius - CGFloat(18 + (index % 5) * 10)
            let isCircle = index % 3 == 0
            let color = colors[index % colors.count]
            return TaskCompletionConfettiPiece(
                x: x,
                y: y,
                width: CGFloat(isCircle ? 8 + (index % 3) : 6 + (index % 4)),
                height: CGFloat(isCircle ? 8 + (index % 3) : 15 + (index % 6)),
                rotation: Double((index * 37) % 180) - 90,
                color: color,
                shape: isCircle ? .circle : .capsule
            )
        }
    }
}

private struct NeonAttentionModifier: ViewModifier {
    let active: Bool
    let tint: Color
    let cornerRadius: CGFloat
    @State private var pulse = false

    func body(content: Content) -> some View {
        content
            .overlay {
                if active {
                    ZStack {
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .fill(tint.opacity(pulse ? 0.08 : 0.04))

                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .inset(by: 1.5)
                            .stroke(tint.opacity(pulse ? 0.88 : 0.42), lineWidth: pulse ? 2.2 : 1.4)

                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .inset(by: 4)
                            .stroke(tint.opacity(pulse ? 0.22 : 0.10), lineWidth: 5)
                            .blur(radius: 0.8)

                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .inset(by: 7)
                            .stroke(tint.opacity(pulse ? 0.22 : 0.08), lineWidth: 1)
                    }
                    .allowsHitTesting(false)
                    .animation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true), value: pulse)
                }
            }
            .onAppear {
                if active {
                    pulse = true
                }
            }
            .onChange(of: active) { _, value in
                pulse = value
            }
    }
}

struct EmptyStateCard: View {
    let icon: String
    let title: String
    let message: String

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: icon)
                .font(.title2.weight(.semibold))
                .foregroundColor(RemoteLoveTheme.green)
                .frame(width: 44, height: 44)
                .background(RemoteLoveTheme.green.opacity(0.12), in: Circle())
            Text(title)
                .font(.headline)
            Text(message)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(18)
        .remoteLoveSectionSurface()
    }
}

struct ActionEmptyStateCard: View {
    let icon: String
    let title: String
    let message: String
    let actionTitle: String?
    let action: (() -> Void)?

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title2.weight(.semibold))
                .foregroundColor(RemoteLoveTheme.green)
                .frame(width: 48, height: 48)
                .background(RemoteLoveTheme.green.opacity(0.12), in: Circle())
                .accessibilityHidden(true)

            VStack(spacing: 4) {
                Text(title)
                    .font(.headline)
                Text(message)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .buttonStyle(PrimaryButtonStyle())
                    .padding(.top, 2)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(18)
        .remoteLoveSectionSurface()
    }
}

struct NativeField: View {
    let title: String
    let placeholder: String
    @Binding var text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.subheadline.bold())
            TextField(placeholder, text: $text)
                .padding(16)
                .background(Color.secondary.opacity(0.09), in: RoundedRectangle(cornerRadius: 15))
        }
    }
}

struct NativeSecureField: View {
    let title: String
    let placeholder: String
    @Binding var text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.subheadline.bold())
            SecureField(placeholder, text: $text)
                .padding(16)
                .background(Color.secondary.opacity(0.09), in: RoundedRectangle(cornerRadius: 15))
        }
    }
}

private struct PasswordCriteriaView: View {
    let password: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            PasswordCriterionRow(title: "At least 8 characters", isMet: PasswordPolicy.hasMinimumLength(password))
            PasswordCriterionRow(title: "An uppercase and a lowercase letter", isMet: PasswordPolicy.hasUppercaseLetter(password) && PasswordPolicy.hasLowercaseLetter(password))
            PasswordCriterionRow(title: "A number", isMet: PasswordPolicy.hasNumber(password))
            PasswordCriterionRow(title: "A special character", isMet: PasswordPolicy.hasSpecialCharacter(password))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Password requirements")
    }
}

private struct PasswordCriterionRow: View {
    let title: String
    let isMet: Bool

    var body: some View {
        Label(title, systemImage: isMet ? "checkmark.circle.fill" : "circle")
            .font(.caption)
            .foregroundStyle(isMet ? RemoteLoveTheme.green : .secondary)
            .accessibilityLabel("\(title): \(isMet ? "met" : "not met")")
    }
}

private struct RemoteLoveSectionSurface: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme
    let cornerRadius: CGFloat

    func body(content: Content) -> some View {
        content
            .background(surfaceColor, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(borderColor, lineWidth: 1)
            }
    }

    private var surfaceColor: Color {
        colorScheme == .dark
            ? Color.white.opacity(0.07)
            : Color(uiColor: .systemBackground).opacity(0.96)
    }

    private var borderColor: Color {
        colorScheme == .dark
            ? Color.white.opacity(0.10)
            : Color.black.opacity(0.04)
    }
}

private struct RemoteLoveAppearModifier: ViewModifier {
    let active: Bool
    let delay: Double

    func body(content: Content) -> some View {
        content
            .opacity(active ? 1 : 0)
            .offset(y: active ? 0 : 10)
            .animation(.easeOut(duration: 0.32).delay(delay), value: active)
    }
}

private struct ScopeSelectionGateModifier: ViewModifier {
    let isActive: Bool
    let onTap: () -> Void

    func body(content: Content) -> some View {
        content
            .overlay {
                if isActive {
                    Color.clear
                        .contentShape(Rectangle())
                        .onTapGesture(perform: onTap)
                        .accessibilityLabel("Select edit scope first")
                        .accessibilityAddTraits(.isButton)
                }
            }
    }
}

private extension View {
    func remoteLoveSectionSurface(cornerRadius: CGFloat = 20) -> some View {
        modifier(RemoteLoveSectionSurface(cornerRadius: cornerRadius))
    }

    func remoteLoveAppear(active: Bool, delay: Double = 0) -> some View {
        modifier(RemoteLoveAppearModifier(active: active, delay: delay))
    }

    func neonAttention(active: Bool, tint: Color, cornerRadius: CGFloat) -> some View {
        modifier(NeonAttentionModifier(active: active, tint: tint, cornerRadius: cornerRadius))
    }

    func scopeSelectionGate(isActive: Bool, onTap: @escaping () -> Void) -> some View {
        modifier(ScopeSelectionGateModifier(isActive: isActive, onTap: onTap))
    }
}

struct PrimaryButtonStyle: ButtonStyle {
    var tint: Color = RemoteLoveTheme.green
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundColor(RemoteLoveTheme.onAccent)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 15)
            .background(tint.opacity(configuration.isPressed ? 0.72 : 1), in: RoundedRectangle(cornerRadius: 15))
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundColor(RemoteLoveTheme.green)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(RemoteLoveTheme.green.opacity(configuration.isPressed ? 0.18 : 0.10), in: RoundedRectangle(cornerRadius: 15))
            .overlay {
                RoundedRectangle(cornerRadius: 15)
                    .stroke(RemoteLoveTheme.green.opacity(0.32), lineWidth: 1)
            }
    }
}
