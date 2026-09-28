import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

struct ContentView: View {
    @EnvironmentObject private var store: RemoteLoveStore
    @State private var showOpeningAnimation = true
    @State private var showOpeningDestination = false

    var body: some View {
        ZStack {
            routedContent
                .opacity(showOpeningAnimation && !showOpeningDestination ? 0 : 1)

            if showOpeningAnimation {
                OpeningLogoAnimationView {
                    withAnimation(.easeInOut(duration: 0.22)) {
                        showOpeningDestination = true
                    }
                } onFinished: {
                    withAnimation(.easeInOut(duration: 0.24)) {
                        showOpeningAnimation = false
                    }
                }
                .transition(.opacity)
                .zIndex(2)
            }
        }
        .tint(RemoteLoveTheme.green)
        .animation(.easeInOut(duration: 0.22), value: store.route)
        .task {
            await store.restoreSessionIfNeeded()
        }
        .onAppear {
            KeyboardDismissal.install()
        }
    }

    @ViewBuilder
    private var routedContent: some View {
        switch store.route {
        case .restoringSession:
            ProgressView("Restoring your session…")
        case .welcome, .familyAuthentication, .helperJoin:
            LoginView()
        case .helperPinLock:
            HelperPinLockView()
        case .familyGettingStarted, .joinFamilyCareCircle:
            CareCircleSetupView()
        case .createCareSetup:
            InitialCareSetupView()
        case .familyApp, .helperApp:
            MainTabView()
        }
    }
}

private struct OpeningLogoAnimationView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let onRevealDestination: () -> Void
    let onFinished: () -> Void

    @State private var backgroundOpacity = 1.0
    @State private var logoOpacity = 1.0
    @State private var logoScale = 0.985
    @State private var pulseScale = 1.0
    @State private var logoOffsetY: CGFloat = 0

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                RemoteLoveTheme.mint
                    .opacity(0.55 * backgroundOpacity)
                    .ignoresSafeArea()

                Image("LaunchLogo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 148, height: 148)
                    .clipShape(RoundedRectangle(cornerRadius: 34, style: .continuous))
                    .opacity(logoOpacity)
                    .scaleEffect(logoScale * pulseScale)
                    .offset(y: logoOffsetY)
                    .shadow(color: RemoteLoveTheme.coral.opacity(0.14), radius: 18, y: 10)
                    .accessibilityHidden(true)
            }
            .task {
                await playAnimation(in: geometry.size)
            }
        }
    }

    @MainActor
    private func playAnimation(in size: CGSize) async {
        if reduceMotion {
            try? await Task.sleep(nanoseconds: 420_000_000)
            onFinished()
            return
        }

        logoOpacity = 0.0
        logoScale = 0.96

        try? await Task.sleep(nanoseconds: 120_000_000)
        withAnimation(.easeOut(duration: 0.38)) {
            logoOpacity = 1.0
            logoScale = 1.0
        }

        try? await Task.sleep(nanoseconds: 220_000_000)
        await pulseLogo()
        try? await Task.sleep(nanoseconds: 45_000_000)
        await pulseLogo()

        try? await Task.sleep(nanoseconds: 180_000_000)
        onRevealDestination()

        let targetOffset = -max(170, min(size.height * 0.30, 260))
        withAnimation(.easeInOut(duration: 0.48)) {
            logoOffsetY = targetOffset
            logoScale = 0.82
            backgroundOpacity = 0.0
            logoOpacity = 0.0
        }

        try? await Task.sleep(nanoseconds: 520_000_000)
        onFinished()
    }

    @MainActor
    private func pulseLogo() async {
        withAnimation(.easeInOut(duration: 0.11)) {
            pulseScale = 1.035
        }

        try? await Task.sleep(nanoseconds: 110_000_000)
        withAnimation(.easeInOut(duration: 0.13)) {
            pulseScale = 1.0
        }

        try? await Task.sleep(nanoseconds: 130_000_000)
    }
}

#if canImport(UIKit)
private final class KeyboardDismissalTarget: NSObject {
    @objc func dismissKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}

private enum KeyboardDismissal {
    private static let target = KeyboardDismissalTarget()
    private static var installedWindows = NSHashTable<UIWindow>.weakObjects()

    static func install() {
        UIScrollView.appearance().keyboardDismissMode = .interactive

        let windows = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)

        for window in windows where installedWindows.contains(window) == false {
            let recognizer = UITapGestureRecognizer(target: target, action: #selector(KeyboardDismissalTarget.dismissKeyboard))
            recognizer.cancelsTouchesInView = false
            recognizer.delaysTouchesBegan = false
            recognizer.delaysTouchesEnded = false
            window.addGestureRecognizer(recognizer)
            installedWindows.add(window)
        }
    }
}
#endif

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
            .environmentObject(RemoteLoveStore(previewAuthenticated: true))
    }
}
