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
            VStack(alignment: .leading, spacing: 10) {
                Text("No tasks yet")
                    .font(.title3)
                    .foregroundColor(.purple)
                    .bold()
                Text("Create your first task to get started.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                Button(action: { showingAddTask = true }) {
                    Text("Add Task")
                        .font(.headline)
                        .foregroundColor(.black)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.purple)
                        .cornerRadius(12)
                }
                .padding(.top, 4)
            }
            .padding()
            .background(Color.white.opacity(0.06))
            .cornerRadius(15)
            .padding(.horizontal)

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .padding(.top, 40)
    }

    private func taskRow(for task: Task) -> some View {
        Button(action: { editingTask = task }) {
            VStack(alignment: .leading, spacing: 8) {
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
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.purple.opacity(0.2))
                    .foregroundColor(.purple)
                    .cornerRadius(8)
                }
                if !task.description.isEmpty {
                    Text(task.description)
                        .font(.subheadline)
                        .foregroundColor(.gray)
                }
                Text("Due: \(task.dueDate.formatted(date: .abbreviated, time: .shortened))")
                    .font(.caption)
                    .foregroundColor(.purple)
                HStack {
                    Spacer()
                    Button(action: {
                        taskToDelete = task
                        showDeleteConfirmation = true
                    }) {
                        Image(systemName: "trash")
                            .foregroundColor(.red)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(10)
            .background(Color.white.opacity(0.06))
            .cornerRadius(10)
        }
        .buttonStyle(.plain)
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
                            List {
                                ForEach(dataManager.tasks) { task in
                                    taskRow(for: task)
                                }
                                .onDelete { indexSet in
                                    indexSet.map { dataManager.tasks[$0] }.forEach { dataManager.deleteTask($0) }
                                }
                                .listRowBackground(Color.clear)
                            }
                            .scrollContentBackground(.hidden)
                            .background(Color.clear)
                            .listStyle(.insetGrouped)
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
