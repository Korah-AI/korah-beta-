import SwiftUI

struct AddTaskView: View {
    @Environment(\.dismiss) var dismiss
    @Binding var tasks: [Task]
    
    @State private var title: String = ""
    @State private var description: String = ""
    @State private var dueDate: Date = Date()
    @State private var difficulty: TaskDifficulty = .medium
    
    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Task Info")) {
                    TextField("Title", text: $title)
                    TextField("Description", text: $description)
                }
                
                Section(header: Text("Due Date")) {
                    DatePicker("Select Date", selection: $dueDate, displayedComponents: [.date, .hourAndMinute])
                }
                
                Section(header: Text("Difficulty")) {
                    Picker("Difficulty Level", selection: $difficulty) {
                        ForEach(TaskDifficulty.allCases, id: \.self) { level in
                            Text("\(level.rawValue) \(level.emoji)")
                                .tag(level)                            }
                    }
                    .pickerStyle(SegmentedPickerStyle())
                }
                
                Section {
                    Button(action: addTask) {
                        Text("Save Task")
                            .frame(maxWidth: .infinity, alignment: .center)
                            .foregroundColor(.purple)
                    }
                    .disabled(title.isEmpty)
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color.clear)
            .navigationTitle("Add Task")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
        .korahGradientBackground()
    }
    
    func addTask() {
        let newTask = Task(title: title, description: description, dueDate: dueDate, difficulty: difficulty)
        tasks.append(newTask)
        HomeDataManager.shared.saveTasks()
        dismiss()
    }
}
