import SwiftUI
import Foundation
import UserNotifications
import UIKit
import Combine

class PomodoroTimerManager: ObservableObject {
    static let shared = PomodoroTimerManager()
    
    @Published var timeRemaining = 600 
    @Published var totalTime = 600
    @Published var isTimerRunning = false
    @Published var showingCompletionAlert = false
    @Published var selectedTasks: [Task] = []
    
    private var timer: Timer?
    private var lastProgressQuarter = 0
    var onStart: (() -> Void)?
    var onStop: (() -> Void)?
    var onComplete: (() -> Void)?
    
    private init() {}
    
    func startTimer() {
        guard !isTimerRunning else { return }
        isTimerRunning = true
        lastProgressQuarter = 0
        onStart?()
        scheduleFocusReminderLoop()
        updateBraceletProgress() 
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            if self.timeRemaining > 0 {
                self.timeRemaining -= 1
                self.checkAndUpdateBraceletProgress()
            } else {
                self.stopTimer()
                self.showCompletionFeedback()
            }
        }
    }
    
    func stopTimer() {
        isTimerRunning = false
        timer?.invalidate()
        timer = nil
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["focus-minute-reminder"])
        onStop?()
    }
    
    func resetTimer() {
        stopTimer()
        timeRemaining = totalTime
    }
    
    func setDuration(_ seconds: Int) {
        guard !isTimerRunning else { return }
        timeRemaining = seconds
        totalTime = seconds
    }
    
    func showCompletionFeedback() {
        let impactFeedback = UIImpactFeedbackGenerator(style: .heavy)
        impactFeedback.impactOccurred()
        
        DispatchQueue.main.async {
            self.showingCompletionAlert = true
        }
        
        onComplete?()
        
        BLEManager.shared.sendCommand("CELEBRATE")
        
        let content = UNMutableNotificationContent()
        content.title = "✅ Focus Session Complete!"
        content.body = "Nice work! Take a short break."
        content.sound = .default
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(identifier: "session-complete", content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request)
    }
    
    func scheduleFocusReminderLoop() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["focus-minute-reminder"])
        let content = UNMutableNotificationContent()
        content.title = "🍅 Stay Focused"
        content.body = "Remember your focus session!"
        content.sound = .default
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 60, repeats: true)
        let request = UNNotificationRequest(identifier: "focus-minute-reminder", content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request)
    }
    
    var progress: Double {
        guard totalTime > 0 else { return 0 }
        return 1 - Double(timeRemaining) / Double(totalTime)
    }
    
    private func checkAndUpdateBraceletProgress() {
        let currentProgress = progress
        let currentQuarter = Int(currentProgress * 4)
        
        if currentQuarter > lastProgressQuarter {
            lastProgressQuarter = currentQuarter
            updateBraceletProgress()
        }
    }
    
    private func updateBraceletProgress() {
        let bleManager = BLEManager.shared
        guard bleManager.isConnected else { return }
        
        let progressPercent = Int(progress * 100)
        let rgb = bleManager.themeColor.rgbComponents
        let r = Int(rgb.red * 255)
        let g = Int(rgb.green * 255)
        let b = Int(rgb.blue * 255)
        
        bleManager.sendCommand("PROGRESS:\(progressPercent),\(r),\(g),\(b)")
    }
}

struct PomodoroTimerView: View {
    @ObservedObject private var timerManager = PomodoroTimerManager.shared
    @Environment(\.dismiss) private var dismiss
    
    var onDismiss: (() -> Void)? = nil
    
    @State private var showTaskPicker = false
    @State private var showCustomTimePicker = false
    @State private var customMinutes = 10
    @State private var allTasks: [Task] = []
    @State private var showCelebration = false
    @State private var goHome = false

    var body: some View {
        ZStack {
            VStack(spacing: 28) {
                HStack {
                    Button(action: {
                        goHome = true
                    }) {
                        Image(systemName: "chevron.left")
                            .font(.title2)
                            .foregroundColor(.white)
                    }
                    .padding(.leading)
                    
                    Spacer()
                }
                
                VStack(spacing: 6) {
                    Text("Study Timer")
                        .font(.largeTitle).bold()
                        .foregroundColor(.white)
                    Text(timerManager.isTimerRunning ? "Focus Time" : "Ready to Focus")
                        .font(.headline)
                        .foregroundColor(.white.opacity(0.8))
                }
                .padding(.top, 12)
                
                if !timerManager.selectedTasks.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Focusing on:")
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.7))
                        
                        ForEach(timerManager.selectedTasks) { task in
                            HStack {
                                Text(task.difficulty.emoji)
                                Text(task.title)
                                    .font(.subheadline)
                                    .foregroundColor(.white)
                                Spacer()
                                if !timerManager.isTimerRunning {
                                    Button(action: {
                                        timerManager.selectedTasks.removeAll { $0.id == task.id }
                                    }) {
                                        Image(systemName: "xmark.circle.fill")
                                            .foregroundColor(.white.opacity(0.5))
                                    }
                                }
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.white.opacity(0.1))
                            .cornerRadius(8)
                        }
                    }
                    .padding(.horizontal)
                }

                ZStack {
                    Circle()
                        .stroke(Color.white.opacity(0.15), lineWidth: 16)
                        .frame(width: 260, height: 260)
                        .shadow(color: .black.opacity(0.5), radius: 8, x: 0, y: 8)

                    Circle()
                        .trim(from: 0, to: CGFloat(timerManager.progress))
                        .stroke(AngularGradient(gradient: Gradient(colors: [Color.purple, Color.blue, Color.purple]), center: .center), style: StrokeStyle(lineWidth: 16, lineCap: .round))
                        .frame(width: 260, height: 260)
                        .rotationEffect(.degrees(-90))
                        .animation(.linear(duration: 1), value: timerManager.timeRemaining)

                    VStack(spacing: 8) {
                        Text(timeString(from: timerManager.timeRemaining))
                            .font(.system(size: 56, weight: .bold, design: .monospaced))
                            .foregroundColor(.white)
                        HStack(spacing: 8) {
                            Image(systemName: "flame.fill").foregroundColor(.orange)
                            Text(timerManager.isTimerRunning ? "Stay focused" : "Tap start")
                                .foregroundColor(.white.opacity(0.8))
                                .font(.subheadline)
                        }
                    }
                }
                .padding(.vertical, 8)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach([300, 600, 1500], id: \.self) { seconds in
                            Button(action: { timerManager.setDuration(seconds) }) {
                                Text(label(for: seconds))
                                    .font(.subheadline).bold()
                                    .foregroundColor(.white)
                                    .padding(.vertical, 10)
                                    .padding(.horizontal, 14)
                                    .background(Color.white.opacity(timerManager.timeRemaining == seconds && !timerManager.isTimerRunning ? 0.25 : 0.12))
                                    .cornerRadius(10)
                            }
                            .disabled(timerManager.isTimerRunning)
                        }
                        
                        Button(action: { showCustomTimePicker = true }) {
                            HStack(spacing: 4) {
                                Image(systemName: "clock.badge.questionmark")
                                Text("Custom")
                            }
                            .font(.subheadline).bold()
                            .foregroundColor(.white)
                            .padding(.vertical, 10)
                            .padding(.horizontal, 14)
                            .background(Color.white.opacity(0.12))
                            .cornerRadius(10)
                        }
                        .disabled(timerManager.isTimerRunning)
                    }
                    .padding(.horizontal)
                }

                VStack(spacing: 12) {
                    HStack(spacing: 16) {
                        Button(action: toggleTimer) {
                            HStack {
                                Image(systemName: timerManager.isTimerRunning ? "pause.fill" : "play.fill")
                                Text(timerManager.isTimerRunning ? "Pause" : "Start")
                                    .bold()
                            }
                            .foregroundColor(.black)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(timerManager.isTimerRunning ? Color.orange : Color.green)
                            .cornerRadius(14)
                            .shadow(color: .black.opacity(0.3), radius: 6, x: 0, y: 4)
                        }

                        Button(action: { timerManager.resetTimer() }) {
                            HStack { Image(systemName: "arrow.counterclockwise"); Text("Reset").bold() }
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.white.opacity(0.15))
                                .cornerRadius(14)
                                .shadow(color: .black.opacity(0.3), radius: 6, x: 0, y: 4)
                        }
                    }
                    
                    if !timerManager.isTimerRunning {
                        Button(action: { showTaskPicker = true }) {
                            HStack {
                                Image(systemName: "checklist")
                                Text("Select Tasks (\(timerManager.selectedTasks.count))")
                                    .bold()
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.purple.opacity(0.7))
                            .cornerRadius(14)
                            .shadow(color: .black.opacity(0.3), radius: 6, x: 0, y: 4)
                        }
                    }
                }

                Spacer()
            }
            .padding()
        }
        .korahGradientBackground()
        .background(Color.clear)
        .navigationBarBackButtonHidden(true)
        .onAppear {
            requestNotificationPermission()
            loadTasks()
        }
        .fullScreenCover(isPresented: $showCelebration) {
            CongratulationsView(
                title: "Amazing Work!",
                message: timerManager.selectedTasks.isEmpty 
                    ? "You've completed your focus session. Time for a break!"
                    : "You focused on \(timerManager.selectedTasks.count) task\(timerManager.selectedTasks.count == 1 ? "" : "s"). Great job!"
            )
            .onDisappear {
                timerManager.resetTimer()
                timerManager.showingCompletionAlert = false
            }
        }
        .onChange(of: timerManager.showingCompletionAlert) { isShowing in
            if isShowing {
                showCelebration = true
            }
        }
        .sheet(isPresented: $showTaskPicker) {
            TaskPickerSheet(selectedTasks: $timerManager.selectedTasks, allTasks: allTasks)
        }
        .sheet(isPresented: $showCustomTimePicker) {
            CustomTimePickerSheet(customMinutes: $customMinutes, onSet: {
                timerManager.setDuration(customMinutes * 60)
                showCustomTimePicker = false
            })
        }
        .fullScreenCover(isPresented: $goHome) {
            HomePageView()
        }
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
           let decoded = try? JSONDecoder().decode([Task].self, from: data) {
            allTasks = decoded
        }
    }

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
    @Binding var selectedTasks: [Task]
    let allTasks: [Task]
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
            .korahGradientBackground()
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
            .korahGradientBackground()
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

struct PomodoroTimerView_Previews: PreviewProvider {
    static var previews: some View {
        PomodoroTimerView()
    }
}
