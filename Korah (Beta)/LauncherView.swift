import SwiftUI

struct LauncherView: View {
    @State private var appState = AppStateManager()
    @State private var streakManager = StreakManager.shared
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage("LastMoodCheckInDate") private var lastMoodCheckInDate: Double = 0
    
    var body: some View {
        ZStack {
            // Main content layer - only show after launch animation completes
            if !appState.shouldShowLaunchAnimation {
                Group {
                    if !appState.hasCompletedOnboarding {
                        // Show onboarding for first-time users
                        OnboardingView(isOnboardingComplete: $appState.hasCompletedOnboarding)
                    } else {
                        // Show main app content
                        HomePageView()
                    }
                }
                .transition(.opacity)
            }
            
            // Launch animation overlay (shows first on fresh app launch)
            if appState.shouldShowLaunchAnimation {
                LaunchAnimationView(onComplete: {
                    appState.dismissLaunchAnimation()
                })
                .transition(.opacity)
                .zIndex(1)
            }
        }
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

