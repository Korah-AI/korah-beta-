import SwiftUI

struct ToDoListView: View {
    @ObservedObject private var dataManager = HomeDataManager.shared
    @State private var showingAddTask = false
    @State private var editingTask: Task? = nil
    @State private var taskToDelete: Task? = nil
    @State private var showDeleteConfirmation = false
    @State private var timerExpanded: Bool = false

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

    private var addTaskButton: some View {
        Button {
            showingAddTask = true
        } label: {
            HStack {
                Image(systemName: "plus.circle.fill")
                Text("Add Task")
            }
            .font(.headline)
            .foregroundColor(.white)
            .padding()
            .frame(maxWidth: .infinity)
            .background(Color.purple)
            .cornerRadius(12)
            .padding(.horizontal)
            .padding(.top)
            .padding(.bottom, 4)
        }
    }

    private var studyTimerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Study Timer")
                .font(.title3)
                .foregroundColor(.purple)
                .bold()
                .padding(.horizontal)
                .padding(.top, 4)
                .padding(.bottom, 6)

            CompactStudyTimerView(isExpanded: $timerExpanded)
                .padding(.horizontal)
        }
        .padding(.bottom, 8)
    }

    private var emptyStateView: some View {
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
                        Image(systemName: "plus.circle.fill")
                        Text("Create Your First Task")
                    }
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color.purple)
                    .cornerRadius(12)
                }
                .padding(.horizontal, 24)
                .padding(.top, 8)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 32)

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .padding(.top, 40)
    }

    private func taskRow(for task: Task) -> some View {
        Button(action: { editingTask = task }) {
            HStack(spacing: 16) {
                // Icon based on task difficulty
                Image(systemName: difficultyIcon(for: task.difficulty))
                    .font(.system(size: 28))
                    .foregroundColor(.purple)
                    .frame(width: 50, height: 50)
                    .background(Color.purple.opacity(0.15))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(task.title)
                            .font(.headline)
                            .foregroundColor(.white)
                            .lineLimit(2)
                        Spacer()
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
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color.white.opacity(0.08))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(Color.purple.opacity(0.2), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
    
    private func difficultyIcon(for difficulty: TaskDifficulty) -> String {
        switch difficulty {
        case .easy: return "checkmark.circle"
        case .medium: return "circle.lefthalf.filled"
        case .hard: return "exclamationmark.circle"
        }
    }

    var body: some View {
        NavigationStack {
            Group {
                if timerExpanded {
                    CompactStudyTimerView(isExpanded: $timerExpanded)
                        .padding(.horizontal)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                } else {
                    VStack {
                        addTaskButton

                        studyTimerSection

                        if dataManager.tasks.isEmpty {
                            emptyStateView
                        } else {
                            ScrollView {
                                VStack(spacing: 10) {
                                    ForEach(dataManager.tasks) { task in
                                        taskRow(for: task)
                                            .padding(.horizontal)
                                    }
                                }
                                .padding(.vertical)
                            }
                            .background(Color.clear)
                        }
                    }
                }
            }
            .navigationTitle(timerExpanded ? "" : "Your Tasks")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarBackground(.visible, for: .tabBar)
            .toolbar {
                if !timerExpanded {
                    ToolbarItem(placement: .principal) {
                        Text("Your Tasks")
                            .font(.headline)
                            .foregroundColor(.white)
                            .lineLimit(2)
                            .multilineTextAlignment(.center)
                            .minimumScaleFactor(0.7)
                    }
                }
            }
            .toolbar(timerExpanded ? .hidden : .visible, for: .navigationBar)
            .toolbar(timerExpanded ? .hidden : .visible, for: .tabBar)
            .preferredColorScheme(.dark)
            .accentColor(.purple)
            .korahGradientBackground()
        }
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
    }
}
