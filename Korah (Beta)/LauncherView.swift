import SwiftUI

struct LauncherView: View {
    @StateObject private var appState = AppStateManager()
    @ObservedObject private var streakManager = StreakManager.shared
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage("LastMoodCheckInDate") private var lastMoodCheckInDate: Double = 0
    @State private var showMoodCheckIn = false
    
    var body: some View {
        ZStack {
            // Main content layer - only show after launch animation completes
            if !appState.shouldShowLaunchAnimation {
                Group {
                    if !appState.hasCompletedOnboarding {
                        // Show onboarding for first-time users
                        OnboardingView(isOnboardingComplete: $appState.hasCompletedOnboarding)
                    } else if showMoodCheckIn {
                        // Show mood check-in if needed
                        MoodCheckInView()
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
            
            checkIfMoodCheckInNeeded()
        }
        .onChange(of: scenePhase) { newPhase in
            if newPhase == .active {
                // Track app open for streak
                streakManager.checkAndUpdateStreak()
                // Cancel any pending streak reminder
                NotificationManager.shared.cancelStreakReminder()
                // Schedule new streak reminder for 18 hours from now
                NotificationManager.shared.scheduleStreakReminderNotification()
                
                // Check again when app becomes active
                checkIfMoodCheckInNeeded()
            }
        }
        .onChange(of: lastMoodCheckInDate) { _ in
            // When mood is selected, hide the mood check-in view
            if showMoodCheckIn {
                showMoodCheckIn = false
            }
        }
    }
    
    private func checkIfMoodCheckInNeeded() {
        guard appState.hasCompletedOnboarding else { return }
        guard !appState.shouldShowLaunchAnimation else { return }
        
        let lastCheckIn = Date(timeIntervalSince1970: lastMoodCheckInDate)
        let hoursSinceLastCheckIn = Date().timeIntervalSince(lastCheckIn) / 3600
        
        // Show mood check-in if more than 24 hours have passed or never checked in
        showMoodCheckIn = (hoursSinceLastCheckIn >= 24 || lastMoodCheckInDate == 0)
    }
}

struct LauncherView_Previews: PreviewProvider {
    static var previews: some View {
        LauncherView()
    }
}

