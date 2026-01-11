import SwiftUI
import Foundation
import UserNotifications

@main
struct KorahApp: App {
    init() {
        applyKorahAppearance()
        setupNotifications()
    }
    
    var body: some Scene {
        WindowGroup {
            LauncherView()
                .preferredColorScheme(.dark)
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
