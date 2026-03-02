import SwiftUI
import Foundation
import UserNotifications
import FirebaseCore

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        FirebaseApp.configure()
        return true
    }
}

@main
struct KorahApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    @State private var authCheckComplete = false
    private let authManager = AuthManager.shared
    
    init() {
        setupNotifications()
    }
    
    var body: some Scene {
        WindowGroup {
            Group {
                if authCheckComplete {
                    if authManager.isAuthenticated {
                        LauncherView()
                            .preferredColorScheme(.dark)
                    } else {
                        NavigationStack {
                            LoginView()
                                .preferredColorScheme(.dark)
                        }
                    }
                } else {
                    // Show loading state while checking auth
                    ZStack {
                        Color(.systemBackground)
                            .ignoresSafeArea()
                        
                        ProgressView()
                    }
                    .preferredColorScheme(.dark)
                }
            }
            .environment(authManager)
            .onChange(of: authManager.isAuthenticated) {
                // Handle auth state changes
            }
            .task {
                await authManager.checkAuthenticationState()
                authCheckComplete = true
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
