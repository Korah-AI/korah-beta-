import SwiftUI

// MARK: - Test Options Sheet

struct TestOptionsSheet: View {
    let set: FlashcardSet
    @Binding var isGenerating: Bool
    let onMultipleChoice: () -> Void
    let onAIGenerated: () -> Void
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                Text("Choose Test Type")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .padding(.top)
                
                Button(action: {
                    onMultipleChoice()
                    dismiss()
                }) {
                    HStack {
                        Image(systemName: "checkmark.circle")
                            .font(.title3)
                        Text("Multiple Choice")
                            .font(.headline)
                        Spacer()
                    }
                    .foregroundStyle(.white)
                    .padding()
                    .background(Color.purple.opacity(0.3))
                    .clipShape(.rect(cornerRadius: 10))
                }
                
                Button(action: {
                    onAIGenerated()
                    dismiss()
                }) {
                    HStack {
                        Image(systemName: "sparkles")
                            .font(.title3)
                        Text("AI Generated")
                            .font(.headline)
                        Spacer()
                    }
                    .foregroundStyle(.white)
                    .padding()
                    .background(Color.purple.opacity(0.3))
                    .clipShape(.rect(cornerRadius: 10))
                }
                
                Spacer()
            }
            .padding()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
        .korahGradientBackground()
    }
}

// MARK: - Error Alert View

struct ErrorAlertView: View {
    @Binding var isPresented: Bool
    let message: String
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                Image(systemName: "exclamationmark.circle")
                    .font(.largeTitle)
                    .foregroundStyle(.red)
                
                Text("Error")
                    .font(.headline)
                    .foregroundStyle(.white)
                
                Text(message)
                    .font(.body)
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                
                Button(action: { isPresented = false }) {
                    Text("OK")
                        .font(.headline)
                        .foregroundStyle(.white)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.purple)
                        .clipShape(.rect(cornerRadius: 10))
                }
                
                Spacer()
            }
            .padding()
        }
        .korahGradientBackground()
    }
}
