import SwiftUI

struct AIFlashcardPromptGeneratorView: View {
    @Environment(\.dismiss) private var dismiss
    
    @State private var prompt: String = ""
    @State private var setTitle: String = ""
    @State private var isGenerating: Bool = false
    @State private var errorMessage: String? = nil
    @State private var generatedCards: [Flashcard] = []
    @State private var showSuccessAlert = false
    
    var body: some View {
        ZStack {
            Color.clear.korahGradientBackground()
                .ignoresSafeArea()
            
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(spacing: 12) {
                            Image(systemName: "sparkles")
                                .foregroundColor(.purple)
                                .font(.title2)
                                .shadow(color: .purple.opacity(0.3), radius: 5)
                            Text("AI Flashcard Generator")
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                        }
                        
                        Text("Describe what you want to study and AI will generate flashcards for you")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal)
                    
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Set Title")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .padding(.horizontal)
                        
                        TextField("e.g., Spanish Vocabulary", text: $setTitle)
                            .textInputAutocapitalization(.words)
                            .padding()
                            .background(Color.white.opacity(0.08))
                            .cornerRadius(12)
                            .foregroundColor(.white)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.white.opacity(0.1), lineWidth: 1)
                            )
                            .padding(.horizontal)
                    }
                    
                    VStack(alignment: .leading, spacing: 12) {
                        Text("What do you want to learn?")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .padding(.horizontal)
                        
                        TextEditor(text: $prompt)
                            .scrollContentBackground(.hidden)
                            .frame(minHeight: 180)
                            .padding()
                            .background(Color.white.opacity(0.08))
                            .cornerRadius(12)
                            .foregroundColor(.white)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.white.opacity(0.1), lineWidth: 1)
                            )
                            .padding(.horizontal)
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Examples:")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            ExamplePromptButton(text: "Basic Spanish greetings and common phrases", onTap: {
                                prompt = "Basic Spanish greetings and common phrases"
                            })
                            
                            ExamplePromptButton(text: "Key concepts from photosynthesis", onTap: {
                                prompt = "Key concepts from photosynthesis"
                            })
                            
                            ExamplePromptButton(text: "Important dates from World War II", onTap: {
                                prompt = "Important dates from World War II"
                            })
                        }
                        .padding(.horizontal)
                    }
                    
                    if let errorMessage = errorMessage {
                        HStack(spacing: 8) {
                            Image(systemName: "exclamationmark.circle")
                                .foregroundColor(.red)
                            Text(errorMessage)
                                .font(.callout)
                                .foregroundColor(.red)
                            Spacer()
                        }
                        .padding(12)
                        .background(Color.red.opacity(0.1))
                        .cornerRadius(10)
                        .padding(.horizontal)
                    }
                    
                    Button(action: generateFlashcards) {
                        HStack(spacing: 8) {
                            if isGenerating {
                                ProgressView()
                                    .progressViewStyle(.circular)
                                    .tint(.white)
                                Text("Generating...")
                            } else {
                                Image(systemName: "sparkles")
                                Text("Generate Flashcards")
                            }
                        }
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(canGenerate ? Color.purple : Color.gray.opacity(0.5))
                        .cornerRadius(12)
                    }
                    .disabled(!canGenerate || isGenerating)
                    .padding(.horizontal)
                    
                    Spacer(minLength: 40)
                }
                .padding(.vertical)
            }
            
            // Loading overlay
            if isGenerating {
                ModernLoadingOverlay(
                    message: "Generating Flashcards",
                    subtitle: "Powered by AI • Creating your study materials",
                    accentColor: .purple
                )
            }
        }
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button(role: .cancel) { dismiss() } label: {
                    Image(systemName: "xmark")
                }
            }
            ToolbarItem(placement: .principal) {
                Text("AI Generator")
                    .font(.headline)
                    .foregroundColor(.white)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .preferredColorScheme(.dark)
        .alert("Success!", isPresented: $showSuccessAlert) {
            Button("OK") { dismiss() }
        } message: {
            Text("Generated \(generatedCards.count) flashcards and saved to your library!")
        }
    }
    
    private var canGenerate: Bool {
        !prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !setTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    private func generateFlashcards() {
        errorMessage = nil
        isGenerating = true

        let trimmedPrompt = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedTitle = setTitle.trimmingCharacters(in: .whitespacesAndNewlines)

        // /api/generate-study-item with /api/r fallback (matches web study-api.js)
        Task {
            defer { isGenerating = false }
            do {
                let pairs = try await StudyGenerationService.shared.generateFlashcards(
                    prompt: trimmedPrompt, title: trimmedTitle)
                let newCards = pairs.map { Flashcard(front: $0.front, back: $0.back) }
                let newSet = FlashcardSet(title: trimmedTitle, cards: newCards)
                try? FirestoreStudyService.shared.addFlashcardSet(newSet)
                generatedCards = newCards
                showSuccessAlert = true
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
}

struct ExamplePromptButton: View {
    let text: String
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 6) {
                Image(systemName: "lightbulb.fill")
                    .font(.caption)
                    .foregroundColor(.yellow.opacity(0.8))
                Text(text)
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.8))
                Spacer()
                Image(systemName: "arrow.right.circle")
                    .font(.caption)
                    .foregroundColor(.purple.opacity(0.6))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color.white.opacity(0.05))
            .cornerRadius(8)
        }
    }
}

#Preview {
    NavigationStack {
        AIFlashcardPromptGeneratorView()
    }
}
