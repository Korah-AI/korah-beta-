import SwiftUI
import Foundation
import UserNotifications
import FirebaseCore
import GoogleSignIn

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        FirebaseApp.configure()
        return true
    }
    
    func application(
        _ app: UIApplication,
        open url: URL,
        options: [UIApplication.OpenURLOptionsKey: Any] = [:]
    ) -> Bool {
        return GIDSignIn.sharedInstance.handle(url)
    }
}

@main
struct KorahApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    @State private var authCheckComplete = false
    /// Launch overlay (icon → "Korah AI" lockup → zoom) stays up until its
    /// animation finishes AND the auth check is done. No spinner, ever.
    @State private var showLaunchOverlay = true
    private let authManager = AuthManager.shared
    private let studyService = FirestoreStudyService.shared
    private let conversationService = FirestoreConversationService.shared
    @State private var themeManager = ThemeManager.shared

    init() {
        setupTabBarAppearance()
        setupNotifications()
    }

    var body: some Scene {
        WindowGroup {
            ZStack {
                if authCheckComplete {
                    if authManager.isAuthenticated {
                        // Authenticated: straight to launcher (has its own
                        // first-run onboarding)
                        LauncherView()
                            .transition(.opacity)
                    } else {
                        // Unauthenticated: straight to login. Make
                        // NavigationStack the container and apply star
                        // background behind it.
                        NavigationStack {
                            LoginView()
                                .navigationBarTitleDisplayMode(.inline)
                        }
                        .background(
                            ZStack {
                                TwinklingStarsBackground(starCount: 80)
                                    .ignoresSafeArea()
                            }
                        )
                        .transition(.opacity)
                    }
                }

                // Launch overlay: app icon while auth loads, then the
                // "Korah AI" reveal + zoom-through into the app.
                if showLaunchOverlay {
                    LaunchAnimationView(isReady: authCheckComplete) {
                        showLaunchOverlay = false
                    }
                    .zIndex(1)
                }
            }
            .preferredColorScheme(themeManager.colorScheme ?? .dark)
            .environment(authManager)
            .environment(studyService)
            .environment(conversationService)
            .environment(themeManager)
            .onOpenURL { url in
                GIDSignIn.sharedInstance.handle(url)
            }
            .task {
                await authManager.checkAuthenticationState()
                if authManager.isAuthenticated, let uid = authManager.currentUser?.id {
                    studyService.startListening(uid: uid)
                    conversationService.startListening(uid: uid)
                    await DataMigrationManager.shared.migrateIfNeeded(uid: uid)
                }
                withAnimation(.easeInOut(duration: 0.4)) {
                    authCheckComplete = true
                }
            }
            .onChange(of: authManager.isAuthenticated) { _, isAuthenticated in
                if isAuthenticated, let uid = authManager.currentUser?.id {
                    studyService.startListening(uid: uid)
                    conversationService.startListening(uid: uid)
                    Task {
                        await DataMigrationManager.shared.migrateIfNeeded(uid: uid)
                    }
                } else {
                    studyService.stopListening()
                    conversationService.stopListening()
                }
            }
        }
    }
    
    /// Configures the tab bar's tinted (selected item) color via the UIKit
    /// appearance proxy. This runs in `init()`, before any `UITabBar` is
    /// created, so the tint is correct on the very first render. Relying on
    /// SwiftUI's `.tint()` alone left the tab bar untinted on cold launch and
    /// only correct after backgrounding/foregrounding forced a rebuild.
    private func setupTabBarAppearance() {
        // `Color.kAccent` is backed by a dynamic UIColor (see Color.adaptive),
        // so this bridges back to a dynamic UIColor that stays correct in
        // light/dark rather than being frozen at init() time.
        let accent = UIColor(Color.kAccent)

        let appearance = UITabBarAppearance()
        appearance.configureWithDefaultBackground()

        for itemAppearance in [
            appearance.stackedLayoutAppearance,
            appearance.inlineLayoutAppearance,
            appearance.compactInlineLayoutAppearance
        ] {
            itemAppearance.selected.iconColor = accent
            itemAppearance.selected.titleTextAttributes = [.foregroundColor: accent]
        }

        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
    }

    private func setupNotifications() {
        // Request notification permissions
        NotificationManager.shared.requestPermission { granted in
            if granted {
                print("Notification permission granted")
            } else {
                print("Notification permission denied")
            }
        }
    }
}
