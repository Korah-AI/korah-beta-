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
    /// Same lockup + zoom, replayed right after a fresh login/signup/Google/
    /// Apple/guest sign-in — not just on cold launch.
    @State private var showPostAuthAnimation = false
    private let authManager = AuthManager.shared
    private let studyService = FirestoreStudyService.shared
    private let conversationService = FirestoreConversationService.shared
    @State private var themeManager = ThemeManager.shared
    /// Owns onboarding completion so it can gate the very first screen,
    /// ahead of login/signup — not just the post-auth `LauncherView`.
    @State private var appState = AppStateManager()

    init() {
        setupTabBarAppearance()
        setupNotifications()
    }

    var body: some Scene {
        WindowGroup {
            ZStack {
                if authCheckComplete {
                    if !appState.hasCompletedOnboarding {
                        // First launch ever (or fresh reinstall): onboarding
                        // is the very first thing anyone sees, before
                        // login/signup.
                        OnboardingView(isOnboardingComplete: $appState.hasCompletedOnboarding) { profile in
                            appState.pendingOnboardingProfile = profile
                        }
                        .transition(.opacity)
                    } else if authManager.isAuthenticated {
                        // Onboarding done and authenticated: straight to the
                        // main app.
                        LauncherView()
                            .transition(.opacity)
                    } else {
                        // Onboarding done, not authenticated: straight to
                        // login. Make NavigationStack the container and
                        // apply star background behind it.
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

                // Same reveal, replayed after a fresh sign-in (the
                // underlying content has already switched to LauncherView
                // by this point, so the zoom-through reveals the main app).
                if showPostAuthAnimation {
                    LaunchAnimationView(isReady: true) {
                        showPostAuthAnimation = false
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
                    await flushPendingOnboardingProfileIfNeeded()
                }
                withAnimation(.easeInOut(duration: 0.4)) {
                    authCheckComplete = true
                }
            }
            .onChange(of: authManager.isAuthenticated) { _, isAuthenticated in
                if isAuthenticated, let uid = authManager.currentUser?.id {
                    // Only replay the intro for a genuine mid-session
                    // sign-in — not the cold-launch auth check, which is
                    // still in flight while `authCheckComplete` is false.
                    if authCheckComplete {
                        showPostAuthAnimation = true
                    }
                    studyService.startListening(uid: uid)
                    conversationService.startListening(uid: uid)
                    Task {
                        await DataMigrationManager.shared.migrateIfNeeded(uid: uid)
                        await flushPendingOnboardingProfileIfNeeded()
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
        // `Color.kTabBarSelected` is backed by a dynamic UIColor (see
        // Color.adaptive), so this bridges back to a dynamic UIColor that
        // stays correct in light/dark rather than being frozen at init() time.
        let accent = UIColor(Color.kTabBarSelected)

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

    /// Onboarding collects test date / score goals before login exists, so
    /// there's no `uid` to save them under at the time. Once auth succeeds,
    /// write anything pending to Firestore and clear it.
    private func flushPendingOnboardingProfileIfNeeded() async {
        guard let profile = appState.pendingOnboardingProfile else { return }
        let service = SATAnalyticsService.shared
        try? await service.saveProfile(
            mathScore: profile.mathScore,
            englishScore: profile.englishScore,
            mathGoal: profile.mathGoal,
            englishGoal: profile.englishGoal
        )
        if let testDate = profile.testDate {
            try? await service.saveTestDate(testDate)
        }
        appState.pendingOnboardingProfile = nil
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
