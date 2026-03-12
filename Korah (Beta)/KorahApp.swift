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
                    // TwinklingStarsBackground lives here (behind the NavigationStack)
                    // so iOS 26's NavigationStack root-view background layer cannot
                    // cover the stars.  LoginView and SignupView are transparent.
                    ZStack {
                        TwinklingStarsBackground(starCount: 80)
                            .ignoresSafeArea()
                        NavigationStack {
                            LoginView()
                        }
                    }
                    .transition(.opacity)
                }
            }
            .preferredColorScheme(.dark)
            .environment(authManager)
            .onOpenURL { url in
                GIDSignIn.sharedInstance.handle(url)
            }
            .task {
                await authManager.checkAuthenticationState()
                withAnimation(.easeInOut(duration: 0.4)) {
                    authCheckComplete = true
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
