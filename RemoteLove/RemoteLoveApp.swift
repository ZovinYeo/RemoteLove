import SwiftUI
import UserNotifications

@main
struct RemoteLoveApp: App {
    @StateObject private var store = RemoteLoveStore()
    @AppStorage("appearance") private var appearance = "system"
    @AppStorage("colorPalette") private var colorPalette = "classic"
    @Environment(\.scenePhase) private var scenePhase
    private let notificationDelegate = RemoteLoveNotificationDelegate()

    private var preferredScheme: ColorScheme? {
        if appearance == "light" { return .light }
        if appearance == "dark" { return .dark }
        return nil
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .id(colorPalette)
                .environmentObject(store)
                .preferredColorScheme(preferredScheme)
                .onAppear {
                    if colorPalette == "pinkBlueBlack" {
                        colorPalette = "blue"
                    }
                    notificationDelegate.store = store
                    UNUserNotificationCenter.current().delegate = notificationDelegate
                    RemoteLoveNotificationScheduler.registerActionCategories()
                }
                .onOpenURL { url in
                    store.handleAuthCallback(url)
                }
                .onChange(of: scenePhase) { _, phase in
                    if phase == .active {
                        store.prepareNotificationsForActiveCareCircle()
                    }
                    if phase == .background {
                        store.lockHelperSessionIfNeeded()
                    }
                }
        }
    }
}
