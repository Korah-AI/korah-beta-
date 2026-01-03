import SwiftUI

struct MoodSettingsView: View {
    @AppStorage("MoodAutoPromptEnabled") private var autoPromptEnabled: Bool = true
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationStack {
            List {
                Section {
                    Toggle(isOn: $autoPromptEnabled) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Daily Mood Check-ins")
                                .font(.headline)
                            Text("Get prompted to check in on your focus level every 24 hours")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .tint(.purple)
                } header: {
                    Text("Preferences")
                }
                
                Section {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(spacing: 8) {
                            Text("🟢")
                                .font(.title3)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Very Focused")
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                Text("Shows harder tasks first")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        HStack(spacing: 8) {
                            Text("🟡")
                                .font(.title3)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Moderately Focused")
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                Text("Shows medium & easy tasks")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        HStack(spacing: 8) {
                            Text("🔴")
                                .font(.title3)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Not Focused")
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                Text("Shows only easy tasks & focus exercises")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .padding(.vertical, 4)
                } header: {
                    Text("How Mood Affects Your Experience")
                } footer: {
                    Text("Your mood selection helps Korah recommend the right tasks and exercises for your current focus level.")
                }
            }
            .navigationTitle("Mood Settings")
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

#Preview {
    MoodSettingsView()
}
