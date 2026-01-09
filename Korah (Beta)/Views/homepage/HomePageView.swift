import SwiftUI

struct HomePageView: View {
    @State private var selectedTab: Int = 0
    @State private var showMoodPicker: Bool = false
    @State private var showMoodSettings: Bool = false
    @State private var showTimerCelebration = false
    @State private var editingTask: Task? = nil

    @AppStorage("UserMood") private var userMood: String = ""

    @ObservedObject private var dataManager = HomeDataManager.shared
    @ObservedObject private var timerManager = PomodoroTimerManager.shared
    
    private var recommendedTasks: [Task] {
        if userMood.isEmpty {
            // If no mood is set, show upcoming tasks sorted by date
            return dataManager.tasks.sorted { $0.dueDate < $1.dueDate }
        } else {
            // Get tasks sorted with recommended ones first
            return MoodHelpers.getSortedTasks(for: userMood, tasks: dataManager.tasks)
        }
    }

    var body: some View {
        ZStack {
        TabView(selection: $selectedTab) {
            NavigationStack {
                ScrollView {
                    VStack(spacing: 20) {
                        // Hero Welcome Card
                        VStack(spacing: 16) {
                            HStack {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Hello, Student! 👋")
                                        .font(.title)
                                        .fontWeight(.bold)
                                        .foregroundColor(.white)
                                    
                                    Text(greetingMessage())
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                            }
                            
                            // Stats Grid
                            HStack(spacing: 12) {
                                StatCard(icon: "checkmark.circle.fill", value: "\(dataManager.tasks.count)", label: "Tasks")
                                StatCard(icon: "book.fill", value: "\(dataManager.recentStudyItems.count)", label: "Study Items")
                                StatCard(icon: "flame.fill", value: studyStreakDays(), label: "Day Streak")
                            }
                        }
                        .padding()
                        .background(Color.white.opacity(0.08))
                        .cornerRadius(20)
                        .shadow(color: .purple.opacity(0.3), radius: 10, x: 0, y: 5)
                        .padding(.horizontal)
                        .padding(.top, 20)
                        
                        // Quick Actions Grid
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Quick Actions")
                                .font(.title3)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                                .padding(.horizontal)
                            
                            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                                QuickActionButton(icon: "plus.circle.fill", title: "New Task", color: .purple) {
                                    selectedTab = 1
                                }
                                QuickActionButton(icon: "camera.viewfinder", title: "Scan", color: .blue) {
                                    selectedTab = 2
                                }
                                QuickActionButton(icon: "message.fill", title: "Chat", color: .green) {
                                    selectedTab = 3
                                }
                                QuickActionButton(icon: "timer", title: "Study Timer", color: .orange) {
                                    selectedTab = 1
                                }
                            }
                            .padding(.horizontal)
                        }
                        .padding(.vertical)

                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            HStack(spacing: 8) {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.purple)
                                    .font(.title3)
                                Text("Recommended for You")
                                    .font(.title3)
                                    .foregroundColor(.white)
                                    .bold()
                            }

                            Spacer()

                            Button(action: {
                                showMoodPicker = true
                            }) {
                                Text(userMood.isEmpty ? "🟢" : userMood)
                                    .font(.largeTitle)
                            }
                        }
                        
                        // Mood-based recommendation message
                        if !userMood.isEmpty {
                            let recommendedCount = recommendedTasks.filter { MoodHelpers.isTaskRecommended(task: $0, for: userMood) }.count
                            Text(MoodHelpers.getRecommendationMessage(for: userMood, recommendedCount: recommendedCount, totalCount: recommendedTasks.count))
                                .font(.subheadline)
                                .foregroundColor(.yellow.opacity(0.9))
                                .padding(.bottom, 4)
                        }

                        if recommendedTasks.isEmpty && !userMood.isEmpty && userMood == "🔴" {
                            // Show exercises when no easy tasks and mood is low
                            VStack(alignment: .leading, spacing: 12) {
                                ForEach(MoodHelpers.getSuggestedExercises(for: userMood).prefix(2)) { exercise in
                                    HStack(spacing: 12) {
                                        Image(systemName: exercise.icon)
                                            .font(.title3)
                                            .foregroundColor(.purple)
                                            .frame(width: 40, height: 40)
                                            .background(Color.purple.opacity(0.15))
                                            .clipShape(Circle())
                                        
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(exercise.title)
                                                .font(.subheadline)
                                                .foregroundColor(.white)
                                            Text(exercise.duration)
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        }
                                        Spacer()
                                    }
                                    .padding(12)
                                    .background(Color.white.opacity(0.1))
                                    .cornerRadius(10)
                                }
                            }
                        } else if dataManager.tasks.isEmpty {
                            VStack(spacing: 12) {
                                Image(systemName: "checkmark.circle")
                                    .font(.system(size: 40))
                                    .foregroundColor(.purple.opacity(0.6))
                                Text("No upcoming tasks")
                                    .foregroundColor(.gray)
                                    .font(.subheadline)
                                Text("Tap Tasks tab to create your first task")
                                    .foregroundColor(.secondary)
                                    .font(.caption)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 20)
                        } else {
                            ForEach(recommendedTasks.prefix(3)) { task in
                                Button(action: {
                                    editingTask = task
                                }) {
                                    HStack(spacing: 12) {
                                        VStack(alignment: .leading, spacing: 6) {
                                            HStack {
                                                Text(task.title)
                                                    .font(.headline)
                                                    .foregroundColor(.white)
                                                Spacer()
                                                HStack(spacing: 4) {
                                                    Text(task.difficulty.emoji)
                                                    Text(task.difficulty.rawValue)
                                                        .font(.caption)
                                                        .fontWeight(.medium)
                                                }
                                                .padding(.horizontal, 6)
                                                .padding(.vertical, 3)
                                                .background(Color.purple.opacity(0.2))
                                                .foregroundColor(.purple)
                                                .cornerRadius(6)
                                            }

                                            if !task.description.isEmpty {
                                                Text(task.description)
                                                    .font(.subheadline)
                                                    .foregroundColor(.gray)
                                                    .lineLimit(1)
                                            }

                                            HStack(spacing: 4) {
                                                Image(systemName: "calendar")
                                                    .font(.caption)
                                                Text(task.dueDate.formatted(date: .abbreviated, time: .shortened))
                                                    .font(.caption)
                                            }
                                            .foregroundColor(.purple.opacity(0.8))
                                        }
                                        
                                        Image(systemName: "chevron.right")
                                            .font(.caption)
                                            .foregroundColor(.gray)
                                    }
                                    .padding(12)
                                    .background(Color.white.opacity(0.1))
                                    .cornerRadius(10)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    .padding()
                    .background(Color.white.opacity(0.06))
                    .cornerRadius(15)
                    .shadow(color: .purple.opacity(0.2), radius: 8, x: 0, y: 4)
                    .padding(.horizontal)

                    VStack(alignment: .leading, spacing: 10) {
                        HStack(spacing: 8) {
                            Image(systemName: "book.fill")
                                .foregroundColor(.purple)
                                .font(.title3)
                            Text("Study it again")
                                .font(.title3)
                                .foregroundColor(.white)
                                .bold()
                        }
                        .padding(.horizontal)

                        if dataManager.recentStudyItems.isEmpty {
                            VStack(spacing: 12) {
                                Image(systemName: "book.closed")
                                    .font(.system(size: 40))
                                    .foregroundColor(.purple.opacity(0.6))
                                Text("No recent study items")
                                    .foregroundColor(.gray)
                                    .font(.subheadline)
                                Text("Create flashcards, guides, or tests to see them here")
                                    .foregroundColor(.secondary)
                                    .font(.caption)
                                    .multilineTextAlignment(.center)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 20)
                            .padding(.horizontal)
                        } else {
                            ForEach(dataManager.recentStudyItems.prefix(3)) { item in
                                NavigationLink(destination: homeDestination(for: item.id, kind: item.kind)) {
                                    HStack {
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(item.title)
                                                .font(.headline)
                                                .foregroundColor(.white)
                                            Text(item.kind)
                                                .font(.caption2)
                                                .bold()
                                                .padding(.horizontal, 8)
                                                .padding(.vertical, 2)
                                                .background(Color.purple.opacity(0.2))
                                                .foregroundColor(.purple)
                                                .cornerRadius(8)
                                        }
                                        Spacer()
                                    }
                                    .padding(10)
                                    .background(Color.white.opacity(0.1))
                                    .cornerRadius(10)
                                    .padding(.horizontal)
                                }
                            }
                        }

                    }
                    .padding()
                    .background(Color.white.opacity(0.06))
                    .cornerRadius(15)
                    .shadow(color: .purple.opacity(0.2), radius: 8, x: 0, y: 4)
                    .padding(.horizontal)

                    VStack(spacing: 10) {
                        HStack(spacing: 8) {
                            Image(systemName: "message.fill")
                                .foregroundColor(.purple)
                                .font(.title3)
                            Text("Start a new chat with Korah")
                                .font(.title3)
                                .foregroundColor(.white)
                                .bold()
                        }

                        Button(action: {
                            selectedTab = 3 
                        }) {
                            Text("Chat Now")
                                .font(.headline)
                                .foregroundColor(.white)
                                .padding()
                                .frame(maxWidth: .infinity)
                                .background(Color.purple)
                                .cornerRadius(12)
                        }
                    }
                    .padding()
                    .background(Color.white.opacity(0.06))
                    .cornerRadius(15)
                    .shadow(color: .purple.opacity(0.2), radius: 8, x: 0, y: 4)
                    .padding(.horizontal)
                    

                    Spacer()
                    }
                }
                .background(Color.korahBackgroundStart.ignoresSafeArea())
                .refreshable {
                    dataManager.refreshAll()
                }
                .sheet(isPresented: $showMoodPicker) {
                    NavigationStack {
                        VStack(spacing: 24) {
                            VStack(spacing: 8) {
                                Image(systemName: "brain.head.profile")
                                    .font(.system(size: 50))
                                    .foregroundColor(.purple)
                                Text("How are you feeling?")
                                    .font(.title2)
                                    .fontWeight(.bold)
                                    .foregroundColor(.white)
                                Text("Help us understand your focus level")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                            .padding(.top, 20)
                        
                            VStack(spacing: 14) {
                                MoodButton(emoji: "🟢", title: "Very Focused", description: "Ready to tackle anything!", color: .green) {
                                    userMood = "🟢"
                                    UserDefaults.standard.set(Date(), forKey: "LastMoodCheckInDate")
                                    showMoodPicker = false
                                }
                                
                                MoodButton(emoji: "🟡", title: "Moderately Focused", description: "Somewhere in the middle", color: .yellow) {
                                    userMood = "🟡"
                                    UserDefaults.standard.set(Date(), forKey: "LastMoodCheckInDate")
                                    showMoodPicker = false
                                }
                                
                                MoodButton(emoji: "🔴", title: "Not Focused", description: "Having trouble concentrating", color: .red) {
                                    userMood = "🔴"
                                    UserDefaults.standard.set(Date(), forKey: "LastMoodCheckInDate")
                                    showMoodPicker = false
                                }
                            }
                            .padding(.horizontal)
                            
                            Button(action: { showMoodPicker = false }) {
                                Text("Cancel")
                                    .font(.headline)
                                    .foregroundColor(.purple)
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(Color.white.opacity(0.1))
                                    .cornerRadius(12)
                            }
                            .padding(.horizontal)
                            .padding(.top, 8)
                            
                            Spacer()
                        }
                        .padding()
                        .korahGradientBackground()
                        .toolbar {
                            ToolbarItem(placement: .navigationBarTrailing) {
                                Button(action: {
                                    showMoodSettings = true
                                }) {
                                    Image(systemName: "gearshape")
                                        .foregroundColor(.purple)
                                }
                            }
                        }
                    }
                }
            }
            .tabItem {
                Label("Home", systemImage: "house.fill")
            }
            .tag(0)

            ToDoListView()
                .tabItem {
                    Label("Tasks", systemImage: "checklist")
                }
                .tag(1)

            ScanView()
                .tabItem {
                    Label("Scan", systemImage: "camera.viewfinder")
                }
                .tag(2)

            StudyHomeView()
                .tabItem {
                    Label("Study", systemImage: "book.closed")
                }
                .tag(3)
        }
        
        VStack {
            Spacer()
            HStack {
                FloatingTimerIndicator()
                    .padding(.leading, 20)
                    .padding(.bottom, 100) 
                Spacer()
            }
        }
        }
        .alert("Amazing Work! 🎉", isPresented: $showTimerCelebration) {
            Button("Great!") {
                timerManager.resetTimer()
                timerManager.showingCompletionAlert = false
            }
        } message: {
            Text(timerManager.selectedTasks.isEmpty 
                ? "You've completed your focus session. Time for a break!"
                : "You focused on \(timerManager.selectedTasks.count) task\(timerManager.selectedTasks.count == 1 ? "" : "s"). Great job!")
        }
        .onChange(of: timerManager.showingCompletionAlert) { isShowing in
            if isShowing {
                showTimerCelebration = true
            }
        }
        .sheet(item: $editingTask) { task in
            EditTaskView(task: task, tasks: $dataManager.tasks)
                .korahGradientBackground()
        }
        .sheet(isPresented: $showMoodSettings) {
            MoodSettingsView()
        }
    }
    
    private func greetingMessage() -> String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 0..<12:
            return "Good morning! Ready to learn something new?"
        case 12..<17:
            return "Good afternoon! Keep up the great work!"
        default:
            return "Good evening! Time to review what you learned!"
        }
    }
    
    private func studyStreakDays() -> String {
        // Simple streak calculation - can be enhanced later
        if dataManager.recentStudyItems.isEmpty {
            return "0"
        }
        
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let recentDates = dataManager.recentStudyItems.map { calendar.startOfDay(for: $0.createdAt) }
        
        var streak = 0
        var currentDate = today
        
        while recentDates.contains(currentDate) {
            streak += 1
            currentDate = calendar.date(byAdding: .day, value: -1, to: currentDate)!
        }
        
        return "\(streak)"
    }

    @ViewBuilder
    private func homeDestination(for id: UUID, kind: String) -> some View {
        switch kind {
        case "Flashcards":
            if let data = UserDefaults.standard.data(forKey: "FlashcardSets"),
               let sets = try? JSONDecoder().decode([FlashcardSet].self, from: data),
               let set = sets.first(where: { $0.id == id }) {
                FlashcardsView(selectedSetID: set.id)
            } else {
                FlashcardsView()
            }
        case "Study Guides":
            if let data = UserDefaults.standard.data(forKey: "StudyGuides"),
               let guides = try? JSONDecoder().decode([StudyGuide].self, from: data),
               let guide = guides.first(where: { $0.id == id }) {
                StudyGuideDetailView(guide: guide)
            } else {
                StudyGuidesView()
            }
        case "Practice Tests":
            if let data = UserDefaults.standard.data(forKey: "PracticeTests"),
               let tests = try? JSONDecoder().decode([PracticeTest].self, from: data),
               let test = tests.first(where: { $0.id == id }) {
                PracticeTestDetailLoaderView(testID: test.id)
            } else {
                PracticeTestsView()
            }
        default:
            FlashcardsView()
        }
    }
}

// MARK: - Supporting Views

struct StatCard: View {
    let icon: String
    let value: String
    let label: String
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(.purple)
            Text(value)
                .font(.title3)
                .fontWeight(.bold)
                .foregroundColor(.white)
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(Color.white.opacity(0.05))
        .cornerRadius(12)
    }
}

struct QuickActionButton: View {
    let icon: String
    let title: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 28))
                    .foregroundColor(color)
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 20)
            .background(Color.white.opacity(0.08))
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(color.opacity(0.3), lineWidth: 1)
            )
        }
    }
}

struct MoodButton: View {
    let emoji: String
    let title: String
    let description: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                Text(emoji)
                    .font(.system(size: 40))
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.headline)
                        .foregroundColor(.white)
                    Text(description)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .foregroundColor(.gray)
            }
            .padding()
            .background(color.opacity(0.2))
            .cornerRadius(14)
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(color.opacity(0.4), lineWidth: 1.5)
            )
        }
    }
}

#Preview {
    NavigationView {
        HomePageView()
    }
}
