import SwiftUI

struct AIStudyGuidePromptGeneratorView: View {
    @Environment(\.dismiss) private var dismiss
    
    @State private var prompt: String = ""
    @State private var guideTitle: String = ""
    @State private var isGenerating: Bool = false
    @State private var errorMessage: String? = nil
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
                                .foregroundColor(.blue)
                                .font(.title2)
                                .shadow(color: .blue.opacity(0.3), radius: 5)
                            Text("AI Study Guide Generator")
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                        }
                        
                        Text("Describe a topic and AI will create a comprehensive study guide for you")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal)
                    
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Guide Title")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .padding(.horizontal)
                        
                        TextField("e.g., Introduction to Biology", text: $guideTitle)
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
                        Text("What topic do you need to study?")
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
                            
                            ExamplePromptButton(text: "The water cycle and its impact on climate", onTap: {
                                prompt = "The water cycle and its impact on climate"
                            })
                            
                            ExamplePromptButton(text: "Key events leading to World War I", onTap: {
                                prompt = "Key events leading to World War I"
                            })
                            
                            ExamplePromptButton(text: "Cellular respiration process in detail", onTap: {
                                prompt = "Cellular respiration process in detail"
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
                    
                    Button(action: generateStudyGuide) {
                        HStack(spacing: 8) {
                            if isGenerating {
                                ProgressView()
                                    .progressViewStyle(.circular)
                                    .tint(.white)
                                Text("Generating...")
                            } else {
                                Image(systemName: "sparkles")
                                Text("Generate Study Guide")
                            }
                        }
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(canGenerate ? Color.blue : Color.gray.opacity(0.5))
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
                ZStack {
                    Color.black.opacity(0.5).ignoresSafeArea()
                    VStack(spacing: 16) {
                        ProgressView()
                            .progressViewStyle(.circular)
                            .tint(.white)
                            .scaleEffect(1.5)
                        Text("Generating study guide...")
                            .font(.headline)
                            .foregroundColor(.white)
                        Text("This may take a few seconds")
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.8))
                    }
                    .padding(24)
                    .background(Color.white.opacity(0.1))
                    .cornerRadius(16)
                }
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
            Text("Study guide created and saved to your library!")
        }
    }
    
    private var canGenerate: Bool {
        !prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !guideTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    private func generateStudyGuide() {
        errorMessage = nil
        isGenerating = true
        
        let trimmedPrompt = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedTitle = guideTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard let url = URL(string: OpenAIConfig.chatCompletionsURL) else {
            errorMessage = "Invalid URL"
            isGenerating = false
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addDeviceIDHeader()
        
        let systemPrompt = """
You are Korah, a study coach. Create study guides from text using **PURE JSON** (no code fences, no markdown) that matches this schema exactly:

{
  "kind": "study-guide",
  "title": string,
  "summary": string,
  "steps": [string],
  "hints": [string],
  "questions": [string],
  "footer": string
}

Rules:
- Based on the user's topic/prompt, create comprehensive study guide content
- Create an engaging title for the study guide
- Write a clear 2-3 sentence summary of what this guide covers
- List 4-8 key learning objectives in "steps" (what students should know/understand)
- Include 3-6 most important concepts with brief explanations in "hints"
- Create 4-8 practice questions in "questions" that test understanding
- Add an encouraging footer message
- Keep language friendly and educational
- Return valid JSON only. No trailing commas. No extra text.
"""
        
        let userPayload: [String: Any] = [
            "title": trimmedTitle,
            "topic": trimmedPrompt
        ]
        
        let userContentData = try? JSONSerialization.data(withJSONObject: userPayload, options: [.sortedKeys])
        let userContentString = String(data: userContentData ?? Data(), encoding: .utf8) ?? "{}"
        
        let messages = [
            ["role": "system", "content": systemPrompt],
            ["role": "user", "content": userContentString]
        ]
        
        let requestBody: [String: Any] = [
            "model": "gpt-4o-mini",
            "temperature": 0.3,
            "max_tokens": 2000,
            "messages": messages
        ]
        
        request.httpBody = try? JSONSerialization.data(withJSONObject: requestBody)
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async { isGenerating = false }
            
            if let error = error {
                DispatchQueue.main.async { errorMessage = "Network error: \(error.localizedDescription)" }
                return
            }
            guard let data = data else {
                DispatchQueue.main.async { errorMessage = "No data from server" }
                return
            }
            
            if let http = response as? HTTPURLResponse, http.statusCode != 200 {
                DispatchQueue.main.async { errorMessage = "HTTP Error \(http.statusCode). Check your API key." }
                return
            }
            
            do {
                if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let choices = json["choices"] as? [[String: Any]],
                   let firstChoice = choices.first,
                   let message = firstChoice["message"] as? [String: Any],
                   let content = message["content"] as? String {
                    
                    // Extract JSON from content
                    let jsonString: String
                    if let startIndex = content.firstIndex(of: "{"),
                       let endIndex = content.lastIndex(of: "}") {
                        jsonString = String(content[startIndex...endIndex])
                    } else {
                        jsonString = content
                    }
                    
                    // Validate it's valid JSON
                    guard let jsonData = jsonString.data(using: .utf8),
                          let _ = try? JSONSerialization.jsonObject(with: jsonData) else {
                        DispatchQueue.main.async { errorMessage = "AI returned invalid JSON" }
                        return
                    }
                    
                    // Save to UserDefaults
                    var existing: [StudyGuide] = []
                    if let existingData = UserDefaults.standard.data(forKey: "StudyGuides"),
                       let decoded = try? JSONDecoder().decode([StudyGuide].self, from: existingData) {
                        existing = decoded
                    }
                    
                    let newGuide = StudyGuide(title: trimmedTitle, content: jsonString)
                    existing.append(newGuide)
                    
                    if let encoded = try? JSONEncoder().encode(existing) {
                        UserDefaults.standard.set(encoded, forKey: "StudyGuides")
                        DispatchQueue.main.async {
                            showSuccessAlert = true
                        }
                    } else {
                        DispatchQueue.main.async { errorMessage = "Failed to save study guide" }
                    }
                    return
                }
                DispatchQueue.main.async { errorMessage = "Failed to parse AI response" }
            } catch {
                DispatchQueue.main.async { errorMessage = "Parse error: \(error.localizedDescription)" }
            }
        }.resume()
    }
}

#Preview {
    NavigationStack {
        AIStudyGuidePromptGeneratorView()
    }
}
