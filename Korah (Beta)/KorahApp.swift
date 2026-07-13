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
    /// Resets to `false` on every app launch — onboarding is shown once
    /// per session before the user reaches LoginView.
    @State private var hasSeenOnboardingThisSession = false
    private let authManager = AuthManager.shared
    private let studyService = FirestoreStudyService.shared
    private let conversationService = FirestoreConversationService.shared
    @State private var themeManager = ThemeManager.shared

    init() {
        setupNotifications()
    }

    var body: some Scene {
        WindowGroup {
            ZStack {
                if !authCheckComplete {
                    // Brief loading state while Firebase checks auth
                    ZStack {
                        TwinklingStarsBackground(starCount: 80)
                            .ignoresSafeArea()
                        ProgressView()
                            .tint(.white)
                    }
                    .transition(.opacity)

                } else if authManager.isAuthenticated {
                    // Authenticated: straight to launcher (has its own first-run onboarding)
                    LauncherView()
                        .transition(.opacity)

                } else if !hasSeenOnboardingThisSession {
                    // Unauthenticated + first open this session: show onboarding
                    OnboardingView(isOnboardingComplete: $hasSeenOnboardingThisSession)
                        .transition(.opacity)

                } else {
                    // Unauthenticated + onboarding done: show login.
                    // Make NavigationStack the container and apply star background behind it.
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
