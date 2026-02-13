import SwiftUI

struct AddTaskView: View {
    @Environment(\.dismiss) var dismiss
    @Binding var tasks: [StudyTask]
    
    @State private var title: String = ""
    @State private var description: String = ""
    @State private var dueDate: Date = Date()
    @State private var difficulty: TaskDifficulty = .medium
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Header section with icon
                    VStack(spacing: 12) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 50))
                            .foregroundColor(.purple)
                            .shadow(color: .purple.opacity(0.3), radius: 10)
                        
                        Text("New Task")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                        
                        Text("Organize your work and stay on track")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 20)
                    
                    // Task Information Card
                    VStack(alignment: .leading, spacing: 14) {
                        HStack(spacing: 8) {
                            Image(systemName: "doc.text")
                                .foregroundColor(.purple)
                                .font(.headline)
                            Text("Task Information")
                                .font(.headline)
                                .foregroundColor(.white)
                        }
                        
                        VStack(spacing: 12) {
                            InputFieldView(placeholder: "Task title", text: $title)
                            InputFieldView(placeholder: "Description (optional)", text: $description, minHeight: 80)
                        }
                    }
                    .padding(16)
                    .background(Color.white.opacity(0.06))
                    .cornerRadius(14)
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(Color.purple.opacity(0.2), lineWidth: 1)
                    )
                    
                    // Due Date Card
                    VStack(alignment: .leading, spacing: 14) {
                        HStack(spacing: 8) {
                            Image(systemName: "calendar")
                                .foregroundColor(.purple)
                                .font(.headline)
                            Text("Due Date")
                                .font(.headline)
                                .foregroundColor(.white)
                        }
                        
                        DatePicker(
                            "Select date and time",
                            selection: $dueDate,
                            displayedComponents: [.date, .hourAndMinute]
                        )
                        .datePickerStyle(.compact)
                        .tint(.purple)
                    }
                    .padding(16)
                    .background(Color.white.opacity(0.06))
                    .cornerRadius(14)
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(Color.purple.opacity(0.2), lineWidth: 1)
                    )
                    
                    // Difficulty Card
                    VStack(alignment: .leading, spacing: 14) {
                        HStack(spacing: 8) {
                            Image(systemName: "gauge")
                                .foregroundColor(.purple)
                                .font(.headline)
                            Text("Difficulty Level")
                                .font(.headline)
                                .foregroundColor(.white)
                        }
                        
                        HStack(spacing: 12) {
                            ForEach(TaskDifficulty.allCases, id: \.self) { level in
                                DifficultyButton(
                                    difficulty: level,
                                    isSelected: difficulty == level,
                                    action: { difficulty = level }
                                )
                            }
                        }
                    }
                    .padding(16)
                    .background(Color.white.opacity(0.06))
                    .cornerRadius(14)
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(Color.purple.opacity(0.2), lineWidth: 1)
                    )
                    
                    // Save Button
                    Button(action: addTask) {
                        HStack(spacing: 8) {
                            Image(systemName: "checkmark.circle.fill")
                            Text("Create Task")
                        }
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(title.isEmpty ? Color.gray.opacity(0.5) : Color.purple)
                        .cornerRadius(14)
                        .shadow(color: title.isEmpty ? .clear : .purple.opacity(0.3), radius: 8, x: 0, y: 4)
                    }
                    .disabled(title.isEmpty)
                    .padding(.top, 8)
                    
                    Spacer(minLength: 20)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 20)
            }
            .scrollContentBackground(.hidden)
            .background(Color.clear)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(role: .cancel) {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .foregroundColor(.white)
                    }
                }
                ToolbarItem(placement: .principal) {
                    Text("Add Task")
                        .font(.headline)
                        .foregroundColor(.white)
                }
            }
        }
        .korahGradientBackground()
    }
    
    func addTask() {
        let newTask = StudyTask(title: title, description: description, dueDate: dueDate, difficulty: difficulty)
        tasks.append(newTask)
        HomeDataManager.shared.saveTasks()
        
        // Schedule notifications for the new task
        NotificationManager.shared.scheduleTaskNotifications(for: newTask)
        
        dismiss()
    }
}

// MARK: - Supporting Views

private struct DifficultyButton: View {
    let difficulty: TaskDifficulty
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Text(difficulty.emoji)
                    .font(.system(size: 28))
                Text(difficulty.rawValue)
                    .font(.caption)
                    .fontWeight(.semibold)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(
                isSelected
                    ? Color.purple.opacity(0.3)
                    : Color.white.opacity(0.05)
            )
            .foregroundColor(isSelected ? .purple : .white.opacity(0.8))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(
                        isSelected ? Color.purple : Color.white.opacity(0.1),
                        lineWidth: isSelected ? 2 : 1
                    )
            )
        }
    }
}
