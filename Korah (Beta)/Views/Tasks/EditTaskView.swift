import SwiftUI

struct EditTaskView: View {
    var task: Task
    @Binding var tasks: [Task]
    @Environment(\.dismiss) var dismiss
    
    @State private var title: String
    @State private var description: String
    @State private var dueDate: Date
    @State private var difficulty: TaskDifficulty
    @State private var showCelebration = false
    
    init(task: Task, tasks: Binding<[Task]>) {
        self.task = task
        self._tasks = tasks
        self._title = State(initialValue: task.title)
        self._description = State(initialValue: task.description)
        self._dueDate = State(initialValue: task.dueDate)
        self._difficulty = State(initialValue: task.difficulty)
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Edit Task Info")) {
                    TextField("Title", text: $title)
                    TextField("Description", text: $description)
                }
                
                Section(header: Text("Edit Due Date")) {
                    DatePicker("Select Date", selection: $dueDate, displayedComponents: [.date, .hourAndMinute])
                }
                
                Section(header: Text("Edit Difficulty")) {
                    Picker("Difficulty Level", selection: $difficulty) {
                        ForEach(TaskDifficulty.allCases, id: \.self) { level in
                            HStack {
                                Text(level.emoji)
                                Text(level.rawValue)
                            }
                            .tag(level)
                        }
                    }
                    .pickerStyle(SegmentedPickerStyle())
                }
                
                Section {
                    Button("Save Changes") {
                        saveChanges()
                        dismiss()
                    }
                    .foregroundColor(.purple)
                    
                    Button("✓ Mark as Complete") {
                        completeTask()
                    }
                    .foregroundColor(.green)
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color.clear)
            .navigationTitle("Edit Task")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
        .korahGradientBackground()
        .alert("Task Complete! 🎉", isPresented: $showCelebration) {
            Button("Great!") {
                dismiss()
            }
        } message: {
            Text("You completed \"\(title)\". Keep up the great work!")
        }
    }
    
    func saveChanges() {
        if let index = tasks.firstIndex(where: { $0.id == task.id }) {
            tasks[index].title = title
            tasks[index].description = description
            tasks[index].dueDate = dueDate
            tasks[index].difficulty = difficulty
            HomeDataManager.shared.saveTasks()
        }
    }
    
    func completeTask() {
        if let index = tasks.firstIndex(where: { $0.id == task.id }) {
            tasks.remove(at: index)
            HomeDataManager.shared.saveTasks()
        }
        
        showCelebration = true
    }
}
