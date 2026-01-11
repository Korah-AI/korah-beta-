import SwiftUI

struct ToDoListView: View {
    @ObservedObject private var dataManager = HomeDataManager.shared
    @State private var showingAddTask = false
    @State private var editingTask: Task? = nil
    @State private var taskToDelete: Task? = nil
    @State private var showDeleteConfirmation = false
    @State private var taskToComplete: Task? = nil
    @State private var showCompleteConfirmation = false
    @ObservedObject private var timerManager = FocusTimerManager.shared
    @State private var showTimerDropdown = false
    @State private var searchText: String = ""
    @State private var selectedDifficulty: TaskDifficulty? = nil
    @State private var showCompletionCelebration = false
    @State private var completedTaskTitle = ""
    @State private var collapsedSections: Set<String> = []
    @State private var showMoodPicker: Bool = false
    
    @AppStorage("UserMood") private var userMood: String = ""

    private var greyGradient: LinearGradient {
        let colors: [Color] = [
            Color.korahBackgroundStart,
            Color.korahBackgroundEnd.opacity(0.98)
        ]
        return LinearGradient(
            colors: colors,
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var taskStatsCard: some View {
        HStack(spacing: 12) {
            StatBox(icon: "checkmark.circle.fill", value: "\(dataManager.tasks.count)", label: "Total", color: .purple)
            StatBox(icon: "clock.badge.exclamationmark.fill", value: "\(overdueTasksCount)", label: "Overdue", color: .red)
            StatBox(icon: "calendar.badge.clock", value: "\(todayTasksCount)", label: "Today", color: .orange)
        }
        .padding()
        .background(Color.white.opacity(0.08))
        .cornerRadius(16)
        .shadow(color: .purple.opacity(0.2), radius: 8, x: 0, y: 4)
        .padding(.horizontal)
        .padding(.top)
    }
    
    private var overdueTasksCount: Int {
        dataManager.tasks.filter { $0.dueDate < Date() }.count
    }
    
    private var todayTasksCount: Int {
        let calendar = Calendar.current
        return dataManager.tasks.filter { calendar.isDateInToday($0.dueDate) }.count
    }
    
    private var filteredTasks: [Task] {
        var tasks = dataManager.tasks
        
        if !searchText.isEmpty {
            tasks = tasks.filter { task in
                task.title.localizedCaseInsensitiveContains(searchText) ||
                task.description.localizedCaseInsensitiveContains(searchText)
            }
        }
        
        if let difficulty = selectedDifficulty {
            tasks = tasks.filter { $0.difficulty == difficulty }
        }
        
        // Apply mood-based sorting if no search or difficulty filter is active
        if searchText.isEmpty && selectedDifficulty == nil && !userMood.isEmpty {
            tasks = MoodHelpers.getSortedTasks(for: userMood, tasks: tasks)
        } else {
            tasks = tasks.sorted { $0.dueDate < $1.dueDate }
        }
        
        return tasks
    }
    
    private var groupedTasks: [(String, [Task])] {
        let calendar = Calendar.current
        let now = Date()
        
        var groups: [String: [Task]] = [
            "Overdue": [],
            "Today": [],
            "Tomorrow": [],
            "This Week": [],
            "Later": []
        ]
        
        for task in filteredTasks {
            if task.dueDate < now {
                groups["Overdue"]?.append(task)
            } else if calendar.isDateInToday(task.dueDate) {
                groups["Today"]?.append(task)
            } else if calendar.isDateInTomorrow(task.dueDate) {
                groups["Tomorrow"]?.append(task)
            } else if let weekEnd = calendar.date(byAdding: .day, value: 7, to: now),
                      task.dueDate < weekEnd {
                groups["This Week"]?.append(task)
            } else {
                groups["Later"]?.append(task)
            }
        }
        
        let order = ["Overdue", "Today", "Tomorrow", "This Week", "Later"]
        return order.compactMap { key in
            if let tasks = groups[key], !tasks.isEmpty {
                return (key, tasks)
            }
            return nil
        }
    }
    
    private var studyTimerButton: some View {
        VStack(spacing: 0) {
            Button(action: {
                withAnimation(.spring(response: 0.3)) {
                    showTimerDropdown.toggle()
                }
            }) {
                timerButtonContent
            }
            .buttonStyle(.plain)
            .padding(.horizontal)
            
            if showTimerDropdown {
                compactTimerDropdown
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
    }
    
    private var compactTimerDropdown: some View {
        VStack(spacing: 12) {
            Text("Quick Start Focus Session")
                .font(.headline)
                .foregroundColor(.white)
                .padding(.top, 16)
            
            // Duration options
            HStack(spacing: 12) {
                timerDurationButton(minutes: 5, icon: "5.circle")
                timerDurationButton(minutes: 15, icon: "15.circle")
                timerDurationButton(minutes: 25, icon: "25.circle")
            }
            .padding(.horizontal)
            
            // Active timer controls
            if timerManager.isTimerRunning || timerManager.timeRemaining < timerManager.totalTime {
                VStack(spacing: 8) {
                    Divider()
                        .background(Color.white.opacity(0.2))
                        .padding(.horizontal)
                    
                    HStack(spacing: 12) {
                        if timerManager.isTimerRunning {
                            Button(action: {
                                timerManager.stopTimer()
                            }) {
                                Label("Pause", systemImage: "pause.circle.fill")
                                    .font(.subheadline)
                                    .foregroundColor(.orange)
                            }
                        } else {
                            Button(action: {
                                timerManager.startTimer()
                            }) {
                                Label("Resume", systemImage: "play.circle.fill")
                                    .font(.subheadline)
                                    .foregroundColor(.green)
                            }
                        }
                        
                        Button(action: {
                            timerManager.resetTimer()
                        }) {
                            Label("Reset", systemImage: "arrow.counterclockwise")
                                .font(.subheadline)
                                .foregroundColor(.red.opacity(0.8))
                        }
                    }
                }
            }
            
            Button(action: {
                withAnimation(.spring(response: 0.3)) {
                    showTimerDropdown = false
                }
            }) {
                Text("Close")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .padding(.vertical, 8)
            }
        }
        .padding(.bottom, 16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .strokeBorder(Color.purple.opacity(0.3), lineWidth: 1)
                )
        )
        .padding(.horizontal)
        .padding(.top, 4)
    }
    
    private func timerDurationButton(minutes: Int, icon: String) -> some View {
        Button(action: {
            timerManager.setDuration(minutes * 60)
            timerManager.startTimer()
            withAnimation(.spring(response: 0.3)) {
                showTimerDropdown = false
            }
        }) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 32))
                    .foregroundColor(.purple)
                Text("\(minutes) min")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.8))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.purple.opacity(0.2))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .strokeBorder(Color.purple.opacity(0.4), lineWidth: 1)
                    )
            )
        }
    }
    
    private var timerButtonContent: some View {
        Group {
            HStack(spacing: 16) {
                // Timer icon with progress ring
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Color.purple.opacity(0.3), Color.blue.opacity(0.2)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 60, height: 60)
                    
                    if timerManager.timeRemaining < timerManager.totalTime || timerManager.isTimerRunning {
                        Circle()
                            .trim(from: 0, to: CGFloat(timerManager.progress))
                            .stroke(
                                AngularGradient(
                                    colors: timerManager.isTimerRunning
                                        ? [Color.orange, Color.pink, Color.purple]
                                        : [Color.purple, Color.blue, Color.cyan],
                                    center: .center
                                ),
                                style: StrokeStyle(lineWidth: 4, lineCap: .round)
                            )
                            .frame(width: 56, height: 56)
                            .rotationEffect(.degrees(-90))
                            .animation(.linear(duration: 1), value: timerManager.timeRemaining)
                    }
                    
                    Image(systemName: timerManager.isTimerRunning ? "flame.fill" : "timer")
                        .font(.system(size: 26, weight: .semibold))
                        .foregroundColor(timerManager.isTimerRunning ? .orange : .purple)
                }
                
                VStack(alignment: .leading, spacing: 6) {
                    Text("Focus Timer")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.white)
                    
                    if timerManager.timeRemaining < timerManager.totalTime || timerManager.isTimerRunning {
                        HStack(spacing: 6) {
                            Text(timeString(from: timerManager.timeRemaining))
                                .font(.system(size: 16, weight: .semibold, design: .rounded))
                                .foregroundColor(timerManager.isTimerRunning ? .orange : .purple)
                            
                            if timerManager.isTimerRunning {
                                Text("• Active")
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundColor(.green)
                            } else {
                                Text("• Paused")
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundColor(.white.opacity(0.6))
                            }
                        }
                    } else {
                        Text("Start a focus session")
                            .font(.system(size: 15))
                            .foregroundColor(.white.opacity(0.7))
                    }
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white.opacity(0.4))
            }
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 18)
                    .fill(Color.white.opacity(0.08))
                    .overlay(
                        RoundedRectangle(cornerRadius: 18)
                            .strokeBorder(
                                timerManager.isTimerRunning
                                    ? Color.orange.opacity(0.5)
                                    : Color.purple.opacity(0.3),
                                lineWidth: 2
                            )
                    )
            )
            .shadow(
                color: timerManager.isTimerRunning ? .orange.opacity(0.3) : .purple.opacity(0.2),
                radius: 12,
                x: 0,
                y: 6
            )
        }
    }
    
    private func timeString(from seconds: Int) -> String {
        let minutes = seconds / 60
        let secs = seconds % 60
        return String(format: "%02d:%02d", minutes, secs)
    }

    private var emptyStateView: some View {
        ScrollView {
            VStack(spacing: 24) {
                VStack(spacing: 16) {
                    Image(systemName: "checkmark.circle")
                        .font(.system(size: 60))
                        .foregroundColor(.purple)
                        .shadow(color: .purple.opacity(0.3), radius: 10)
                    
                    Text("Start Your Day Right")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                    
                    Text("Create tasks to organize your work and boost productivity")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                    
                    Button(action: { showingAddTask = true }) {
                        HStack(spacing: 8) {
                            Image(systemName: "list.bullet.circle.fill")
                            Text("Create Your First Task")
                        }
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            LinearGradient(
                                colors: [Color.purple, Color.purple.opacity(0.8)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .cornerRadius(12)
                        .shadow(color: .purple.opacity(0.4), radius: 8, x: 0, y: 4)
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 8)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 32)
                .padding(.bottom, 100)
            }
            .frame(maxWidth: .infinity)
        }
        .padding(.top, 40)
    }

    private func taskIconView(task: Task, isOverdue: Bool, showRecommendation: Bool, isRecommended: Bool) -> some View {
        ZStack(alignment: .topTrailing) {
            Image(systemName: difficultyIcon(for: task.difficulty))
                .font(.system(size: 28))
                .foregroundColor(isOverdue ? .red : .purple)
                .frame(width: 50, height: 50)
                .background((isOverdue ? Color.red : Color.purple).opacity(0.15))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            
            if showRecommendation && isRecommended {
                Image(systemName: "star.fill")
                    .font(.system(size: 12))
                    .foregroundColor(.yellow)
                    .background(
                        Circle()
                            .fill(Color.black.opacity(0.7))
                            .frame(width: 18, height: 18)
                    )
                    .offset(x: 4, y: -4)
            }
        }
    }
    
    private func taskContentView(task: Task, isOverdue: Bool, showRecommendation: Bool, isRecommended: Bool) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(task.title)
                    .font(.headline)
                    .foregroundColor(.white)
                    .lineLimit(2)
                Spacer()
                
                if showRecommendation && isRecommended {
                    HStack(spacing: 4) {
                        Image(systemName: "star.fill")
                            .font(.system(size: 10))
                        Text("Recommended")
                            .font(.caption2)
                            .fontWeight(.semibold)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.yellow.opacity(0.3))
                    .foregroundColor(.yellow)
                    .cornerRadius(8)
                }
                
                HStack(spacing: 4) {
                    Text(task.difficulty.emoji)
                    Text(task.difficulty.rawValue)
                        .font(.caption)
                        .fontWeight(.medium)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.purple.opacity(0.2))
                .foregroundColor(.purple)
                .cornerRadius(8)
            }
            
            if !task.description.isEmpty {
                Text(task.description)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }
            
            HStack {
                if isOverdue {
                    HStack(spacing: 4) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.caption2)
                        Text("OVERDUE")
                            .font(.caption2)
                            .fontWeight(.bold)
                    }
                    .foregroundColor(.red)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.red.opacity(0.2))
                    .cornerRadius(6)
                }
                
                Image(systemName: "calendar")
                    .font(.caption)
                Text(task.dueDate.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption)
                Spacer()
                Button(action: {
                    taskToDelete = task
                    showDeleteConfirmation = true
                }) {
                    Image(systemName: "trash")
                        .font(.caption)
                        .foregroundColor(.red.opacity(0.8))
                }
                .buttonStyle(.plain)
            }
            .foregroundColor(.secondary)
        }
    }
    
    private func taskRow(for task: Task) -> some View {
        let isOverdue = task.dueDate < Date()
        let isRecommended = !userMood.isEmpty && MoodHelpers.isTaskRecommended(task: task, for: userMood)
        let showRecommendation = !userMood.isEmpty && searchText.isEmpty && selectedDifficulty == nil
        let backgroundOpacity = showRecommendation && isRecommended ? 0.12 : 0.08
        let strokeColor = isOverdue ? Color.red.opacity(0.3) : (showRecommendation && isRecommended ? Color.yellow.opacity(0.4) : Color.purple.opacity(0.3))
        let strokeWidth = isOverdue ? 2.0 : (showRecommendation && isRecommended ? 1.5 : 1.0)
        let shadowColor = isOverdue ? Color.red.opacity(0.2) : (showRecommendation && isRecommended ? Color.yellow.opacity(0.3) : Color.purple.opacity(0.2))
        
        return Button(action: { editingTask = task }) {
            HStack(spacing: 16) {
                Button(action: {
                    taskToComplete = task
                    showCompleteConfirmation = true
                }) {
                    Image(systemName: "circle")
                        .font(.system(size: 24))
                        .foregroundColor(isOverdue ? .red : .purple)
                }
                .buttonStyle(.plain)
                
                taskIconView(task: task, isOverdue: isOverdue, showRecommendation: showRecommendation, isRecommended: isRecommended)
                
                taskContentView(task: task, isOverdue: isOverdue, showRecommendation: showRecommendation, isRecommended: isRecommended)
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color.white.opacity(backgroundOpacity))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(strokeColor, lineWidth: strokeWidth)
            )
            .shadow(color: shadowColor, radius: 6, x: 0, y: 3)
        }
        .buttonStyle(.plain)
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button(role: .destructive) {
                taskToDelete = task
                showDeleteConfirmation = true
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
        .swipeActions(edge: .leading, allowsFullSwipe: true) {
            Button {
                taskToComplete = task
                showCompleteConfirmation = true
            } label: {
                Label("Complete", systemImage: "checkmark")
            }
            .tint(.green)
        }
    }
    
    private func difficultyIcon(for difficulty: TaskDifficulty) -> String {
        switch difficulty {
        case .easy: return "checkmark.circle"
        case .medium: return "circle.lefthalf.filled"
        case .hard: return "exclamationmark.circle"
        }
    }
    
    private func completeTask(_ task: Task) {
        completedTaskTitle = task.title
        dataManager.deleteTask(task)
        showCompletionCelebration = true
    }
    
    private func sectionIcon(for section: String) -> String {
        switch section {
        case "Overdue": return "exclamationmark.triangle.fill"
        case "Today": return "sun.max.fill"
        case "Tomorrow": return "moon.fill"
        case "This Week": return "calendar"
        case "Later": return "calendar.badge.clock"
        default: return "calendar"
        }
    }
    
    private func sectionColor(for section: String) -> Color {
        switch section {
        case "Overdue": return .red
        case "Today": return .orange
        case "Tomorrow": return .blue
        case "This Week": return .green
        case "Later": return .purple
        default: return .purple
        }
    }
    
    private var headerSection: some View {
        VStack(spacing: 0) {
            taskStatsCard
            
            // Search and filter bar
            VStack(spacing: 12) {
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                    TextField("Search tasks...", text: $searchText)
                        .foregroundColor(.white)
                }
                .padding(12)
                .background(Color.white.opacity(0.1))
                .cornerRadius(12)
                
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        FilterChip(title: "All", isSelected: selectedDifficulty == nil) {
                            selectedDifficulty = nil
                        }
                        ForEach(TaskDifficulty.allCases, id: \.self) { difficulty in
                            FilterChip(title: "\(difficulty.emoji) \(difficulty.rawValue)", isSelected: selectedDifficulty == difficulty) {
                                selectedDifficulty = difficulty
                            }
                        }
                    }
                }
                
                // Mood indicator
                if !userMood.isEmpty && searchText.isEmpty && selectedDifficulty == nil {
                    Button(action: {
                        showMoodPicker = true
                    }) {
                        HStack(spacing: 8) {
                            Text(userMood)
                                .font(.title3)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(MoodHelpers.getMoodDescription(for: userMood))
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                Text("Tap to change mood")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .foregroundColor(.white)
                        .padding(12)
                        .background(Color.white.opacity(0.08))
                        .cornerRadius(12)
                    }
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 12)
        }
    }
    
    private var mainContentView: some View {
        ZStack(alignment: .bottomTrailing) {
            ScrollView {
                VStack(spacing: 16) {
                    // Move header section inside ScrollView
                    headerSection
                    
                    studyTimerButton

                    if filteredTasks.isEmpty {
                        emptyOrNoResultsView
                    } else {
                        taskListView
                    }
                }
            }
            .background(Color.clear)
            .refreshable {
                dataManager.loadTasks()
            }
            
            // Floating Action Button
            floatingAddButton
        }
    }
    
    @ViewBuilder
    private var emptyOrNoResultsView: some View {
        if dataManager.tasks.isEmpty {
            emptyStateView
        } else {
            VStack(spacing: 16) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 50))
                    .foregroundColor(.gray)
                Text("No tasks found")
                    .font(.headline)
                    .foregroundColor(.white)
                Text("Try adjusting your search or filters")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .padding(.vertical, 40)
        }
    }
    
    private var taskListView: some View {
        VStack(spacing: 16) {
            // Mood-based message
            if !userMood.isEmpty && searchText.isEmpty && selectedDifficulty == nil {
                let recommendedCount = filteredTasks.filter { MoodHelpers.isTaskRecommended(task: $0, for: userMood) }.count
                HStack {
                    Text(MoodHelpers.getRecommendationMessage(for: userMood, recommendedCount: recommendedCount, totalCount: filteredTasks.count))
                        .font(.subheadline)
                        .foregroundColor(.yellow.opacity(0.9))
                    Spacer()
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
                .background(Color.yellow.opacity(0.1))
                .cornerRadius(8)
                .padding(.horizontal)
            }
            
            ForEach(groupedTasks, id: \.0) { section in
                taskSectionView(section: section)
            }
            
            exerciseSuggestionsView
        }
        .padding(.vertical)
        .padding(.bottom, 80)
    }
    
    private func taskSectionView(section: (String, [Task])) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            // Section Header
            Button(action: {
                if collapsedSections.contains(section.0) {
                    collapsedSections.remove(section.0)
                } else {
                    collapsedSections.insert(section.0)
                }
            }) {
                HStack {
                    Image(systemName: sectionIcon(for: section.0))
                        .foregroundColor(sectionColor(for: section.0))
                        .font(.title3)
                    
                    Text(section.0)
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                    
                    Text("(\(section.1.count))")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Image(systemName: collapsedSections.contains(section.0) ? "chevron.down" : "chevron.up")
                        .foregroundColor(.secondary)
                        .font(.caption)
                }
                .padding(.horizontal)
            }
            .buttonStyle(.plain)
            
            // Section Content
            if !collapsedSections.contains(section.0) {
                VStack(spacing: 10) {
                    ForEach(section.1) { task in
                        taskRow(for: task)
                            .padding(.horizontal)
                    }
                }
            }
        }
    }
    
    @ViewBuilder
    private var exerciseSuggestionsView: some View {
        if !userMood.isEmpty && (userMood == "🔴" || userMood == "🟡") && searchText.isEmpty && selectedDifficulty == nil {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "heart.circle.fill")
                        .foregroundColor(.purple)
                    Text("Boost Your Focus")
                        .font(.headline)
                        .foregroundColor(.white)
                }
                .padding(.horizontal)
                .padding(.top, 8)
                
                ForEach(MoodHelpers.getSuggestedExercises(for: userMood).prefix(3)) { exercise in
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
                    .background(Color.white.opacity(0.08))
                    .cornerRadius(10)
                    .padding(.horizontal)
                }
            }
            .padding(.vertical)
            .background(Color.white.opacity(0.05))
            .cornerRadius(14)
            .padding(.horizontal)
        }
    }
    
    private var floatingAddButton: some View {
        Button(action: {
            showingAddTask = true
        }) {
            Image(systemName: "plus")
                .font(.system(size: 24, weight: .semibold))
                .foregroundColor(.white)
                .frame(width: 60, height: 60)
                .background(Color.purple)
                .clipShape(Circle())
                .shadow(color: .purple.opacity(0.5), radius: 10, x: 0, y: 5)
        }
        .padding(.trailing, 20)
        .padding(.bottom, 20)
    }

    var body: some View {
        NavigationStack {
            mainContentView
            .navigationTitle("Your Tasks")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarBackground(.visible, for: .tabBar)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Your Tasks")
                        .font(.headline)
                        .foregroundColor(.white)
                        .lineLimit(2)
                        .multilineTextAlignment(.center)
                        .minimumScaleFactor(0.7)
                }
            }
            .preferredColorScheme(.dark)
            .accentColor(.purple)
            .korahGradientBackground()
            .background(Color.clear)
            .onAppear {
            let tabBarAppearance = UITabBarAppearance()
            tabBarAppearance.configureWithTransparentBackground()
            UITabBar.appearance().standardAppearance = tabBarAppearance
            UITabBar.appearance().scrollEdgeAppearance = tabBarAppearance

            let navAppearance = UINavigationBarAppearance()
            navAppearance.configureWithTransparentBackground()
            navAppearance.backgroundEffect = nil
            UINavigationBar.appearance().standardAppearance = navAppearance
            UINavigationBar.appearance().scrollEdgeAppearance = navAppearance
        }
        .sheet(isPresented: $showingAddTask) {
            AddTaskView(tasks: $dataManager.tasks)
                .korahGradientBackground()
                .onAppear { UITableView.appearance().backgroundColor = .clear }
        }
        .sheet(item: $editingTask) { task in
            EditTaskView(task: task, tasks: $dataManager.tasks)
                .korahGradientBackground()
                .onAppear { UITableView.appearance().backgroundColor = .clear }
        }
        .alert("Delete Task", isPresented: $showDeleteConfirmation) {
            Button("Delete", role: .destructive) {
                if let task = taskToDelete { dataManager.deleteTask(task) }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            if let task = taskToDelete {
                Text("Are you sure you want to delete \"\(task.title)\"?")
            }
        }
        .alert("Complete Task?", isPresented: $showCompleteConfirmation) {
            Button("Complete", role: .none) {
                if let task = taskToComplete {
                    completeTask(task)
                }
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            if let task = taskToComplete {
                Text("Are you sure you've completed \"\(task.title)\"?")
            }
        }
        .alert("Task Complete! 🎉", isPresented: $showCompletionCelebration) {
            Button("Awesome!") { }
        } message: {
            Text("You completed \"\(completedTaskTitle)\". Keep up the great work!")
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
                        Text("We'll recommend tasks based on your focus level")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top, 20)
                    
                    VStack(spacing: 14) {
                        MoodPickerButton(emoji: "🟢", title: "Very Focused", description: "Ready to tackle hard tasks!", color: .green) {
                            userMood = "🟢"
                            UserDefaults.standard.set(Date(), forKey: "LastMoodCheckInDate")
                            showMoodPicker = false
                        }
                        
                        MoodPickerButton(emoji: "🟡", title: "Moderately Focused", description: "Medium & easy tasks work best", color: .yellow) {
                            userMood = "🟡"
                            UserDefaults.standard.set(Date(), forKey: "LastMoodCheckInDate")
                            showMoodPicker = false
                        }
                        
                        MoodPickerButton(emoji: "🔴", title: "Not Focused", description: "Let's start with easier tasks", color: .red) {
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
            }
        }
        }
    }
}

// MARK: - Mood Picker Button
struct MoodPickerButton: View {
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

// MARK: - Supporting Views

struct StatBox: View {
    let icon: String
    let value: String
    let label: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(color)
            Text(value)
                .font(.title2)
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

struct FilterChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(isSelected ? .white : .secondary)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(isSelected ? Color.purple : Color.white.opacity(0.1))
                .cornerRadius(20)
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(Color.purple.opacity(isSelected ? 0 : 0.3), lineWidth: 1)
                )
        }
    }
}
