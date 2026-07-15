import SwiftUI

struct LauncherView: View {
    @State private var appState = AppStateManager()
    @State private var streakManager = StreakManager.shared
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage("LastMoodCheckInDate") private var lastMoodCheckInDate: Double = 0
    
    var body: some View {
        // The launch animation overlay is hosted app-wide in KorahApp now.
        ZStack {
            if !appState.hasCompletedOnboarding {
                // Show onboarding for first-time users
                OnboardingView(isOnboardingComplete: $appState.hasCompletedOnboarding)
                    .transition(.opacity)
            } else {
                // Show main app content
                MainTabView()
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.4), value: appState.hasCompletedOnboarding)
        .onAppear {
            // Track app open for streak
            streakManager.checkAndUpdateStreak()
            // Cancel any pending streak reminder
            NotificationManager.shared.cancelStreakReminder()
            // Schedule new streak reminder for 18 hours from now
            NotificationManager.shared.scheduleStreakReminderNotification()

        }
        .onChange(of: scenePhase) { newPhase in
            if newPhase == .active {
                // Track app open for streak
                streakManager.checkAndUpdateStreak()
                // Cancel any pending streak reminder
                NotificationManager.shared.cancelStreakReminder()
                // Schedule new streak reminder for 18 hours from now
                NotificationManager.shared.scheduleStreakReminderNotification()
            }
        }

    }
    

}

#Preview {
    LauncherView()
}

