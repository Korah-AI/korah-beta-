import SwiftUI
import Foundation
import UserNotifications
import UIKit
// COMMENTED OUT FOR TESTFLIGHT - AWAITING FAMILY SHARING CAPABILITY APPROVAL
// import FamilyControls
// import ManagedSettings

// TODO: BETA VERSION - Add screen time tracking integration here
// Screen time features will track app usage during focus sessions
@MainActor
@Observable
final class FocusTimerManager {
    static let shared = FocusTimerManager()
    
    var timeRemaining = 600 
    var totalTime = 600
    var isTimerRunning = false
    var showingCompletionAlert = false
    var selectedTasks: [StudyTask] = []
    // COMMENTED OUT FOR TESTFLIGHT - AWAITING FAMILY SHARING CAPABILITY APPROVAL
    // @Published var lockInModeEnabled = false
    // @Published var blockedApps = FamilyActivitySelection()
    
    private var timer: Timer?
    private var lastProgressQuarter = 0
    // COMMENTED OUT FOR TESTFLIGHT - AWAITING FAMILY SHARING CAPABILITY APPROVAL
    // private let store = ManagedSettingsStore()
    private var backgroundTaskID: UIBackgroundTaskIdentifier = .invalid
    private var pauseTime: Date?
    var onStart: (() -> Void)?
    var onStop: (() -> Void)?
    var onComplete: (() -> Void)?
    
    private init() {
        // Add observers for app lifecycle
        NotificationCenter.default.addObserver(self, selector: #selector(appDidEnterBackground), name: UIApplication.didEnterBackgroundNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(appWillEnterForeground), name: UIApplication.willEnterForegroundNotification, object: nil)
    }
    
    func startTimer() {
        guard !isTimerRunning else { return }
        isTimerRunning = true
        onStart?()
        
        // Schedule halfway notification
        scheduleHalfwayNotification()
        
        // Schedule completion notification for when timer finishes
        scheduleCompletionNotification()
        
        // COMMENTED OUT FOR TESTFLIGHT - AWAITING FAMILY SHARING CAPABILITY APPROVAL
        // Block apps if Lock-In Mode is enabled
        // if lockInModeEnabled {
        //     blockApps()
        // }
        
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            if self.timeRemaining > 0 {
                self.timeRemaining -= 1
                
                if self.timeRemaining == 0 {
                    self.timerCompleted()
                }
            } else {
                // Ensure timer is stopped if somehow timeRemaining is 0 or less
                self.timerCompleted()
            }
        }
    }
    
    func stopTimer() {
        isTimerRunning = false
        timer?.invalidate()
        timer = nil
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["focus-halfway-reminder", "timer-completion"])
        
        // COMMENTED OUT FOR TESTFLIGHT - AWAITING FAMILY SHARING CAPABILITY APPROVAL
        // Unblock apps
        // unblockApps()
        
        onStop?()
    }
    
    func resetTimer() {
        stopTimer()
        timeRemaining = totalTime
        // COMMENTED OUT FOR TESTFLIGHT - AWAITING FAMILY SHARING CAPABILITY APPROVAL
        // Unblock apps when resetting
        // unblockApps()
    }
    
    func setDuration(_ seconds: Int) {
        guard !isTimerRunning else { return }
        timeRemaining = seconds
        totalTime = seconds
    }
    
    private func timerCompleted() {
        // Stop timer but DON'T reset showingCompletionAlert
        isTimerRunning = false
        timer?.invalidate()
        timer = nil
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["focus-halfway-reminder", "timer-completion"])
        
        let impactFeedback = UIImpactFeedbackGenerator(style: .heavy)
        impactFeedback.impactOccurred()
        
        // Set completion alert flag to true and keep it true until user dismisses
        DispatchQueue.main.async {
            self.showingCompletionAlert = true
        }
        
        onComplete?()
    }
    
    private func scheduleCompletionNotification() {
        // Remove any existing completion notification
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["timer-completion"])
        
        // Schedule notification for when timer completes
        let content = UNMutableNotificationContent()
        content.title = "✅ Focus Session Complete!"
        content.body = "Great work! You've completed your focus session."
        content.sound = .default
        content.interruptionLevel = .timeSensitive // Ensures it shows even in Do Not Disturb
        
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: TimeInterval(timeRemaining), repeats: false)
        let request = UNNotificationRequest(identifier: "timer-completion", content: content, trigger: trigger)
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Error scheduling completion notification: \(error)")
            }
        }
    }
    
    private func scheduleHalfwayNotification() {
        // Remove any existing halfway notification
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["focus-halfway-reminder"])
        
        // Only schedule if timer is longer than 2 minutes
        guard timeRemaining > 120 else { return }
        
        let halfwayTime = TimeInterval(timeRemaining / 2)
        
        let content = UNMutableNotificationContent()
        content.title = "🔥 Halfway Done!"
        content.body = "You're halfway through your focus session. Keep going!"
        content.sound = .default
        content.interruptionLevel = .timeSensitive
        
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: halfwayTime, repeats: false)
        let request = UNNotificationRequest(identifier: "focus-halfway-reminder", content: content, trigger: trigger)
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Error scheduling halfway notification: \(error)")
            }
        }
    }
    
    var progress: Double {
        guard totalTime > 0 else { return 0 }
        return 1 - Double(timeRemaining) / Double(totalTime)
    }
    
    // MARK: - Screen Time Controls
    // COMMENTED OUT FOR TESTFLIGHT - AWAITING FAMILY SHARING CAPABILITY APPROVAL
    /*
    func requestScreenTimeAuthorization() async throws {
        try await AuthorizationCenter.shared.requestAuthorization(for: .individual)
    }
    
    private func blockApps() {
        guard !blockedApps.applicationTokens.isEmpty || !blockedApps.categoryTokens.isEmpty else { return }
        store.shield.applications = blockedApps.applicationTokens.isEmpty ? nil : blockedApps.applicationTokens
        store.shield.applicationCategories = .specific(blockedApps.categoryTokens)
    }
    
    private func unblockApps() {
        store.shield.applications = nil
        store.shield.applicationCategories = nil
        store.shield.webDomains = nil
    }
    */
    
    // MARK: - Background Handling
    
    @objc private func appDidEnterBackground() {
        if isTimerRunning {
            pauseTime = Date()
            // Request background time to keep timer running
            backgroundTaskID = UIApplication.shared.beginBackgroundTask { [weak self] in
                self?.endBackgroundTask()
            }
        }
    }
    
    @objc private func appWillEnterForeground() {
        if let pauseTime = pauseTime, isTimerRunning {
            // Calculate elapsed time while in background
            let elapsedTime = Int(Date().timeIntervalSince(pauseTime))
            timeRemaining = max(0, timeRemaining - elapsedTime)
            
            if timeRemaining == 0 {
                timerCompleted()
            }
            
            self.pauseTime = nil
        }
        endBackgroundTask()
    }
    
    private func endBackgroundTask() {
        if backgroundTaskID != .invalid {
            UIApplication.shared.endBackgroundTask(backgroundTaskID)
            backgroundTaskID = .invalid
        }
    }
}

struct FocusTimerView: View {
    @State private var timerManager = FocusTimerManager.shared
    @Environment(\.dismiss) private var dismiss
    
    var onDismiss: (() -> Void)? = nil
    
    @State private var showTaskPicker = false
    @State private var showCustomTimePicker = false
    @State private var customMinutes = 10
    @State private var allTasks: [StudyTask] = []
    // COMMENTED OUT FOR TESTFLIGHT - AWAITING FAMILY SHARING CAPABILITY APPROVAL
    // @State private var showBlockedAppsPicker = false
    // @State private var screenTimeAuthorized = false
    // @State private var showAuthorizationAlert = false

    var navigationBar: some View {
        HStack {
            Spacer()
            
            // Timer status badge
            if timerManager.isTimerRunning {
                HStack(spacing: 6) {
                    Circle()
                        .fill(Color.green)
                        .frame(width: 8, height: 8)
                        .overlay(
                            Circle()
                                .fill(Color.green.opacity(0.3))
                                .scaleEffect(1.5)
                        )
                    Text("Active")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    Capsule()
                        .fill(Color.green.opacity(0.2))
                        .overlay(
                            Capsule()
                                .strokeBorder(Color.green.opacity(0.3), lineWidth: 1)
                        )
                )
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
    }
    
    var headerView: some View {
        VStack(spacing: 4) {
            Text("Focus Session")
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundColor(.white)
            
            HStack(spacing: 8) {
                Image(systemName: timerManager.isTimerRunning ? "flame.fill" : "moon.stars.fill")
                    .font(.system(size: 16))
                    .foregroundColor(timerManager.isTimerRunning ? .orange : .purple.opacity(0.8))
                Text(timerManager.isTimerRunning ? "Deep Work Mode" : "Ready to Focus")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(.white.opacity(0.7))
            }
        }
        .padding(.top, 8)
    }
    
    var selectedTasksView: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: "target")
                    .foregroundColor(.orange)
                Text("Focusing on:")
                    .font(.headline)
                    .foregroundColor(.white)
            }
            
            ForEach(timerManager.selectedTasks) { task in
                HStack {
                    Text(task.difficulty.emoji)
                        .font(.title3)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(task.title)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                        Text(task.difficulty.rawValue)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    if !timerManager.isTimerRunning {
                        Button(action: {
                            timerManager.selectedTasks.removeAll { $0.id == task.id }
                        }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.red.opacity(0.7))
                                .font(.title3)
                        }
                    }
                }
                .padding(12)
                .kGlassEffect()
            }
        }
        .padding(16)
        .kGlassEffect()
        .padding(.horizontal)
    }
    
    var timerCircle: some View {
        ZStack {
            // Outer glow
            Circle()
                .fill(
                    RadialGradient(
                        colors: [Color.purple.opacity(0.3), Color.clear],
                        center: .center,
                        startRadius: 140,
                        endRadius: 180
                    )
                )
                .frame(width: 320, height: 320)
                .blur(radius: 20)
            
            // Background circle
            Circle()
                .stroke(
                    LinearGradient(
                        colors: [Color.white.opacity(0.1), Color.white.opacity(0.05)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 20
                )
                .frame(width: 260, height: 260)
                .shadow(color: .black.opacity(0.3), radius: 15, x: 0, y: 10)

            // Progress circle
            Circle()
                .trim(from: 0, to: CGFloat(timerManager.progress))
                .stroke(
                    AngularGradient(
                        colors: timerManager.isTimerRunning 
                            ? [Color.orange, Color.pink, Color.purple, Color.blue, Color.orange]
                            : [Color.purple, Color.blue, Color.cyan, Color.purple],
                        center: .center
                    ),
                    style: StrokeStyle(lineWidth: 20, lineCap: .round)
                )
                .frame(width: 260, height: 260)
                .rotationEffect(.degrees(-90))
                .animation(.linear(duration: 1), value: timerManager.timeRemaining)
                .shadow(color: timerManager.isTimerRunning ? .orange.opacity(0.6) : .purple.opacity(0.6), radius: 10, x: 0, y: 0)

            // Inner content
            VStack(spacing: 12) {
                Text(timeString(from: timerManager.timeRemaining))
                    .font(.system(size: 68, weight: .bold, design: .rounded))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.white, .white.opacity(0.9)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .shadow(color: .black.opacity(0.2), radius: 2, x: 0, y: 2)
                
                Text(timerManager.isTimerRunning ? "Stay Locked In" : "Ready When You Are")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white.opacity(0.6))
                    .textCase(.uppercase)
                    .tracking(1.2)
            }
        }
        .padding(.vertical, 30)
    }
    
    var durationButtons: some View {
        VStack(spacing: 12) {
            Text("Session Duration")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.white.opacity(0.5))
                .textCase(.uppercase)
                .tracking(1)
            
            HStack(spacing: 10) {
                ForEach([300, 600, 1500], id: \.self) { seconds in
                    Button(action: { timerManager.setDuration(seconds) }) {
                        VStack(spacing: 6) {
                            Text("\(seconds/60)")
                                .font(.system(size: 24, weight: .bold, design: .rounded))
                            Text("min")
                                .font(.system(size: 11, weight: .medium))
                                .opacity(0.7)
                        }
                        .foregroundColor(timerManager.timeRemaining == seconds && !timerManager.isTimerRunning ? .white : .white.opacity(0.7))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(
                                    timerManager.timeRemaining == seconds && !timerManager.isTimerRunning
                                        ? Color.purple.opacity(0.5)
                                        : Color.white.opacity(0.08)
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16)
                                        .strokeBorder(
                                            timerManager.timeRemaining == seconds && !timerManager.isTimerRunning
                                                ? Color.purple.opacity(0.6)
                                                : Color.white.opacity(0.1),
                                            lineWidth: 1.5
                                        )
                                )
                        )
                        .shadow(color: timerManager.timeRemaining == seconds && !timerManager.isTimerRunning ? .purple.opacity(0.3) : .clear, radius: 10, x: 0, y: 5)
                    }
                    .disabled(timerManager.isTimerRunning)
                }
                
                Button(action: { showCustomTimePicker = true }) {
                    VStack(spacing: 6) {
                        Image(systemName: "slider.horizontal.3")
                            .font(.system(size: 20, weight: .semibold))
                        Text("Custom")
                            .font(.system(size: 11, weight: .medium))
                            .opacity(0.7)
                    }
                    .foregroundColor(.white.opacity(0.7))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color.white.opacity(0.08))
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .strokeBorder(Color.white.opacity(0.1), lineWidth: 1.5)
                            )
                    )
                }
                .disabled(timerManager.isTimerRunning)
            }
            .padding(.horizontal, 20)
        }
    }
    
    // COMMENTED OUT FOR TESTFLIGHT - AWAITING FAMILY SHARING CAPABILITY APPROVAL
    /*
    var lockInModeSection: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                // Lock-In Mode icon and badge
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(
                            LinearGradient(
                                colors: timerManager.lockInModeEnabled 
                                    ? [Color.orange.opacity(0.3), Color.orange.opacity(0.2)]
                                    : [Color.white.opacity(0.1), Color.white.opacity(0.05)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 50, height: 50)
                    
                    Image(systemName: timerManager.lockInModeEnabled ? "lock.shield.fill" : "lock.open")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundColor(timerManager.lockInModeEnabled ? .orange : .white.opacity(0.5))
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Lock-In Mode")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.white)
                    Text("Block apps during focus")
                        .font(.system(size: 13, weight: .regular))
                        .foregroundColor(.white.opacity(0.5))
                }
                
                Spacer()
                
                Toggle("", isOn: $timerManager.lockInModeEnabled)
                    .labelsHidden()
                    .tint(.orange)
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.white.opacity(0.06))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .strokeBorder(
                                timerManager.lockInModeEnabled ? Color.orange.opacity(0.3) : Color.white.opacity(0.1),
                                lineWidth: 1.5
                            )
                    )
            )
            
            if timerManager.lockInModeEnabled {
                Button(action: {
                    if screenTimeAuthorized {
                        showBlockedAppsPicker = true
                    } else {
                        showAuthorizationAlert = true
                    }
                }) {
                    HStack(spacing: 10) {
                        Image(systemName: "apps.iphone")
                            .font(.system(size: 18, weight: .semibold))
                        
                        let appCount = timerManager.blockedApps.applicationTokens.count + timerManager.blockedApps.categoryTokens.count
                        Text(appCount > 0 ? "\(appCount) App\(appCount == 1 ? "" : "s") to Block" : "Choose Apps to Block")
                            .font(.system(size: 15, weight: .semibold))
                        
                        Spacer()
                        
                        Image(systemName: "chevron.right")
                            .font(.system(size: 14, weight: .semibold))
                            .opacity(0.5)
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                    .background(
                        RoundedRectangle(cornerRadius: 14)
                            .fill(Color.orange.opacity(0.2))
                    )
                }
                .padding(.top, 8)
            }
        }
        .padding(.horizontal, 20)
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: timerManager.lockInModeEnabled)
    }
    */
    
    var controlButtons: some View {
        VStack(spacing: 12) {
            // Primary action button
            Button(action: toggleTimer) {
                HStack(spacing: 12) {
                    Image(systemName: timerManager.isTimerRunning ? "pause.circle.fill" : "play.circle.fill")
                        .font(.system(size: 24, weight: .semibold))
                    Text(timerManager.isTimerRunning ? "Pause Session" : "Start Focus")
                        .font(.system(size: 18, weight: .bold))
                }
                .foregroundColor(timerManager.isTimerRunning ? .white : .black)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 18)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(
                            timerManager.isTimerRunning 
                                ? Color.orange
                                : Color.green
                        )
                        .shadow(color: timerManager.isTimerRunning ? .orange.opacity(0.4) : .green.opacity(0.4), radius: 15, x: 0, y: 8)
                )
            }
            
            // Secondary actions
            HStack(spacing: 12) {
                Button(action: { timerManager.resetTimer() }) {
                    HStack(spacing: 8) {
                        Image(systemName: "arrow.counterclockwise")
                            .font(.system(size: 16, weight: .semibold))
                        Text("Reset")
                            .font(.system(size: 15, weight: .semibold))
                    }
                    .foregroundColor(.white.opacity(0.8))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                }
                .buttonStyle(.kGlass)
                
                if !timerManager.isTimerRunning {
                    Button(action: { showTaskPicker = true }) {
                        HStack(spacing: 8) {
                            Image(systemName: "checklist")
                                .font(.system(size: 16, weight: .semibold))
                            Text("Tasks (\(timerManager.selectedTasks.count))")
                                .font(.system(size: 15, weight: .semibold))
                        }
                        .foregroundColor(.white.opacity(0.8))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                    }
                    .buttonStyle(.kGlass)
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 10)
    }
    
    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 24) {
                navigationBar
                
                headerView
                
                if !timerManager.selectedTasks.isEmpty {
                    selectedTasksView
                        .transition(.move(edge: .top).combined(with: .opacity))
                }

                timerCircle
                
                durationButtons
                
                // COMMENTED OUT FOR TESTFLIGHT - AWAITING FAMILY SHARING CAPABILITY APPROVAL
                // if !timerManager.isTimerRunning {
                //     lockInModeSection
                //         .transition(.move(edge: .top).combined(with: .opacity))
                // }
                
                controlButtons
                
                Spacer(minLength: 20)
            }
            .padding(.vertical, 8)
        }
        .kBackground(withStars: true)
        .navigationBarBackButtonHidden(true)
        .onAppear {
            requestNotificationPermission()
            loadTasks()
            // COMMENTED OUT FOR TESTFLIGHT - AWAITING FAMILY SHARING CAPABILITY APPROVAL
            // checkScreenTimeAuthorization()
        }
        .alert("Amazing Work! 🎉", isPresented: $timerManager.showingCompletionAlert) {
            Button("Great!") {
                // Explicitly dismiss the alert first
                timerManager.showingCompletionAlert = false
                // Then reset the timer
                timerManager.timeRemaining = timerManager.totalTime
            }
        } message: {
            Text(timerManager.selectedTasks.isEmpty 
                ? "You've completed your focus session. Time for a break!"
                : "You focused on \(timerManager.selectedTasks.count) task\(timerManager.selectedTasks.count == 1 ? "" : "s"). Great job!")
        }
        .sheet(isPresented: $showTaskPicker) {
            ImprovedTaskPickerSheet(selectedTasks: $timerManager.selectedTasks, allTasks: allTasks)
        }
        .sheet(isPresented: $showCustomTimePicker) {
            CustomTimePickerSheet(customMinutes: $customMinutes, onSet: {
                timerManager.setDuration(customMinutes * 60)
                showCustomTimePicker = false
            })
        }
        // COMMENTED OUT FOR TESTFLIGHT - AWAITING FAMILY SHARING CAPABILITY APPROVAL
        /*
        .familyActivityPicker(
            isPresented: $showBlockedAppsPicker,
            selection: $timerManager.blockedApps
        )
        .alert("Screen Time Authorization Required", isPresented: $showAuthorizationAlert) {
            Button("Authorize") {
                requestScreenTimeAuth()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("To use Lock-In Mode, Korah needs permission to manage Screen Time settings. This allows the app to block selected apps during your focus sessions.")
        }
        */
    }

    func toggleTimer() {
        if timerManager.isTimerRunning {
            timerManager.stopTimer()
        } else {
            timerManager.startTimer()
        }
    }

    func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { _, error in
            if let error = error {
                print("Notification permission error: \(error)")
            }
        }
    }
    
    func loadTasks() {
        if let data = UserDefaults.standard.data(forKey: "SavedTasks"),
           let decoded = try? JSONDecoder().decode([StudyTask].self, from: data) {
            allTasks = decoded
        }
    }
    
    // COMMENTED OUT FOR TESTFLIGHT - AWAITING FAMILY SHARING CAPABILITY APPROVAL
    /*
    func checkScreenTimeAuthorization() {
        screenTimeAuthorized = AuthorizationCenter.shared.authorizationStatus == .approved
    }
    
    func requestScreenTimeAuth() {
        AsyncTask {
            do {
                try await timerManager.requestScreenTimeAuthorization()
                await MainActor.run {
                    screenTimeAuthorized = true
                    showBlockedAppsPicker = true
                }
            } catch {
                print("Authorization failed: \(error)")
            }
        }
    }
    */

    func timeString(from seconds: Int) -> String {
        let minutes = seconds / 60
        let seconds = seconds % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    func label(for seconds: Int) -> String {
        switch seconds {
        case 300: return "5 min"
        case 600: return "10 min"
        case 1500: return "25 min"
        default: return "\(seconds/60) min"
        }
    }
}

struct TaskPickerSheet: View {
    @Binding var selectedTasks: [StudyTask]
    let allTasks: [StudyTask]
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            VStack {
                if allTasks.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "checklist")
                            .font(.system(size: 60))
                            .foregroundColor(.gray)
                        Text("No tasks available")
                            .font(.headline)
                            .foregroundColor(.white)
                        Text("Create tasks to focus on them during your session")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                            .multilineTextAlignment(.center)
                    }
                    .padding()
                } else {
                    List {
                        ForEach(allTasks) { task in
                            Button(action: {
                                if selectedTasks.contains(where: { $0.id == task.id }) {
                                    selectedTasks.removeAll { $0.id == task.id }
                                } else {
                                    selectedTasks.append(task)
                                }
                            }) {
                                HStack {
                                    Image(systemName: selectedTasks.contains(where: { $0.id == task.id }) ? "checkmark.circle.fill" : "circle")
                                        .foregroundColor(selectedTasks.contains(where: { $0.id == task.id }) ? .purple : .gray)
                                    
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(task.title)
                                            .foregroundColor(.white)
                                        Text(task.difficulty.emoji + " " + task.difficulty.rawValue)
                                            .font(.caption)
                                            .foregroundColor(.gray)
                                    }
                                    
                                    Spacer()
                                }
                            }
                            .listRowBackground(Color.white.opacity(0.06))
                        }
                    }
                    .scrollContentBackground(.hidden)
                }
            }
            .kBackground(withStars: true)
            .navigationTitle("Select Tasks")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(.purple)
                }
            }
        }
    }
}

struct ImprovedTaskPickerSheet: View {
    @Binding var selectedTasks: [StudyTask]
    let allTasks: [StudyTask]
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        ZStack {
            Color.korahBackgroundStart.ignoresSafeArea()
            TwinklingStarsBackground()
            
            NavigationStack {
                ZStack {
                    Color.clear
                    
                    if allTasks.isEmpty {
                        VStack(spacing: 20) {
                            Image(systemName: "checklist.unchecked")
                                .font(.system(size: 70))
                                .foregroundColor(.purple.opacity(0.6))
                            
                            Text("No Tasks Yet")
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                            
                            Text("Create tasks in the Tasks tab to select them for your focus sessions")
                                .font(.body)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 40)
                        }
                    } else {
                        ScrollView {
                            VStack(spacing: 16) {
                                // Selected count header
                                if !selectedTasks.isEmpty {
                                    HStack {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundColor(.green)
                                        Text("\(selectedTasks.count) task\(selectedTasks.count == 1 ? "" : "s") selected")
                                            .font(.subheadline)
                                            .foregroundColor(.white)
                                        Spacer()
                                        Button("Clear All") {
                                            withAnimation {
                                                selectedTasks.removeAll()
                                            }
                                        }
                                        .font(.caption)
                                        .foregroundColor(.red.opacity(0.8))
                                    }
                                    .padding()
                                    .background(
                                        RoundedRectangle(cornerRadius: 12)
                                            .fill(Color.white.opacity(0.08))
                                    )
                                    .kGlassEffect()
                                    .padding(.horizontal)
                                    .padding(.top)
                                }
                                
                                // Task list
                                ForEach(allTasks) { task in
                                    TaskSelectionRow(
                                        task: task,
                                        isSelected: selectedTasks.contains(where: { $0.id == task.id })
                                    ) {
                                        withAnimation(.spring(response: 0.3)) {
                                            if selectedTasks.contains(where: { $0.id == task.id }) {
                                                selectedTasks.removeAll { $0.id == task.id }
                                            } else {
                                                selectedTasks.append(task)
                                            }
                                        }
                                    }
                                }
                                .padding(.horizontal)
                            }
                            .padding(.bottom, 100)
                        }
                    }
                }
                .navigationTitle("Select Tasks to Focus On")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") {
                            dismiss()
                        }
                        .font(.headline)
                        .foregroundColor(.purple)
                    }
                    
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") {
                            dismiss()
                        }
                        .foregroundColor(.secondary)
                    }
                }
            }
        }
    }
}

struct TaskSelectionRow: View {
    let task: StudyTask
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                // Checkbox
                ZStack {
                    Circle()
                        .strokeBorder(isSelected ? Color.purple : Color.white.opacity(0.3), lineWidth: 2)
                        .frame(width: 28, height: 28)
                    
                    if isSelected {
                        Image(systemName: "checkmark")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.purple)
                    }
                }
                
                // Task icon
                Text(task.difficulty.emoji)
                    .font(.title2)
                
                // Task info
                VStack(alignment: .leading, spacing: 4) {
                    Text(task.title)
                        .font(.body)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .lineLimit(2)
                    
                    HStack(spacing: 8) {
                        Text(task.difficulty.rawValue)
                            .font(.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Color.purple.opacity(0.2))
                            .foregroundColor(.purple)
                            .cornerRadius(6)
                        
                        if !task.description.isEmpty {
                            Text(task.description)
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                        }
                    }
                }
                
                Spacer()
            }
            .padding(16)
            .kGlassEffect(interactive: isSelected)
        }
        .buttonStyle(.plain)
    }
}

struct CustomTimePickerSheet: View {
    @Binding var customMinutes: Int
    let onSet: () -> Void
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Text("Set Custom Duration")
                    .font(.title2)
                    .bold()
                    .foregroundColor(.white)
                    .padding(.top, 40)
                
                Text("\(customMinutes) minutes")
                    .font(.system(size: 48, weight: .bold, design: .rounded))
                    .foregroundColor(.purple)
                
                Picker("Minutes", selection: $customMinutes) {
                    ForEach(1...360, id: \.self) { minute in
                        Text("\(minute) min").tag(minute)
                    }
                }
                .pickerStyle(.wheel)
                .frame(height: 200)
                
                Button(action: onSet) {
                    Text("Set Timer")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.purple)
                        .cornerRadius(14)
                }
                .padding(.horizontal)
                
                Spacer()
            }
            .kBackground(withStars: true)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(.white)
                }
            }
        }
    }
}

#Preview {
    FocusTimerView()
}
