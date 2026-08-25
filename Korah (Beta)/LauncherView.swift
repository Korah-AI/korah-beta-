import SwiftUI

struct LauncherView: View {
    @State private var streakManager = StreakManager.shared
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage("LastMoodCheckInDate") private var lastMoodCheckInDate: Double = 0

    var body: some View {
        // The launch animation overlay is hosted app-wide in KorahApp now.
        // Onboarding now runs before login/signup (see KorahApp), so by the
        // time this view appears the user is authenticated and ready for
        // the main app content.
        MainTabView()
            .onAppear {
                // Track app open for streak
                streakManager.checkAndUpdateStreak()
                // Cancel any pending streak reminder
                NotificationManager.shared.cancelStreakReminder()
                // Schedule new streak reminder for 18 hours from now
                NotificationManager.shared.scheduleStreakReminderNotification()
                // Rotate today's SAT reminders and queue the come back nudge
                NotificationManager.shared.refreshSchedule()
            }
            .onChange(of: scenePhase) { newPhase in
                if newPhase == .active {
                    // Track app open for streak
                    streakManager.checkAndUpdateStreak()
                    // Cancel any pending streak reminder
                    NotificationManager.shared.cancelStreakReminder()
                    // Schedule new streak reminder for 18 hours from now
                    NotificationManager.shared.scheduleStreakReminderNotification()
                    // Rotate today's SAT reminders and queue the come back nudge
                    NotificationManager.shared.refreshSchedule()
                }
            }
    }
    

}

#Preview {
    LauncherView()
}

