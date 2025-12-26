import SwiftUI
import UIKit

struct ScanFlashcardsView: View {
    @Environment(\.dismiss) private var dismiss
    
    @State private var selectedImages: [UIImage] = []
    @State private var showImageSourceAlert = false
    @State private var showImagePicker = false
    @State private var imageSourceType: UIImagePickerController.SourceType = .camera
    @State private var isGenerating = false
    @State private var errorMessage: String? = nil
    @State private var successMessage: String? = nil
    @State private var generationProgress: Double = 0.0
    
    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                HStack {
                    Button(role: .cancel) { dismiss() } label: { Image(systemName: "xmark") }
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Scan Flashcards")
                            .font(.headline)
                        Text("\(selectedImages.count) image\(selectedImages.count == 1 ? "" : "s") added")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    Button(action: { selectedImages.removeAll() }) {
                        Image(systemName: "trash")
                    }
                    .disabled(selectedImages.isEmpty)
                }
                .padding()
                .background(Color.white.opacity(0.06))
                .cornerRadius(12)
                .padding()
                
                ScrollView {
                    VStack(spacing: 20) {
                        if !selectedImages.isEmpty {
                            VStack(alignment: .leading, spacing: 12) {
                                HStack {
                                    Image(systemName: "photo.stack.fill")
                                        .foregroundColor(.purple)
                                    Text("Scanned Images")
                                        .font(.subheadline)
                                        .fontWeight(.semibold)
                                    Spacer()
                                    Text("\(selectedImages.count)")
                                        .font(.caption)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(Color.purple.opacity(0.3))
                                        .cornerRadius(6)
                                }
                                .padding(.horizontal)
                                
                                LazyVGrid(columns: [GridItem(.adaptive(minimum: 100), spacing: 8)], spacing: 8) {
                                    ForEach(selectedImages.indices, id: \.self) { idx in
                                        ZStack(alignment: .topTrailing) {
                                            Image(uiImage: selectedImages[idx])
                                                .resizable()
                                                .scaledToFill()
                                                .frame(height: 120)
                                                .cornerRadius(10)
                                                .clipped()
                                                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.purple.opacity(0.3), lineWidth: 1))
                                            
                                            Button(action: { selectedImages.remove(at: idx) }) {
                                                Image(systemName: "xmark.circle.fill")
                                                    .font(.title3)
                                                    .foregroundColor(.red)
                                                    .padding(4)
                                                    .background(Color.black.opacity(0.6))
                                                    .clipShape(Circle())
                                            }
                                            .padding(6)
                                        }
                                    }
                                }
                                .padding(.horizontal)
                            }
                        } else {
                            VStack(spacing: 16) {
                                Image(systemName: "photo.on.rectangle.angled")
                                    .font(.system(size: 56))
                                    .foregroundColor(.purple.opacity(0.4))
                                
                                VStack(spacing: 4) {
                                    Text("No images yet")
                                        .font(.headline)
                                        .foregroundColor(.white)
                                    
                                    Text("Add photos to get started")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .padding(48)
                        }
                        
                        if isGenerating {
                            VStack(spacing: 12) {
                                HStack {
                                    Image(systemName: "sparkles")
                                        .foregroundColor(.purple)
                                    Text("Generating flashcards...")
                                        .font(.subheadline)
                                    Spacer()
                                }
                                
                                ProgressView(value: generationProgress)
                                    .tint(.purple)
                                
                                Text("This may take up to 30 seconds")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .padding()
                            .background(Color.purple.opacity(0.1))
                            .cornerRadius(12)
                            .padding()
                        }
                        
                        if let error = errorMessage {
                            HStack(spacing: 12) {
                                Image(systemName: "exclamationmark.circle.fill")
                                    .foregroundColor(.red)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Error")
                                        .font(.caption)
                                        .fontWeight(.semibold)
                                        .foregroundColor(.red)
                                    Text(error)
                                        .font(.callout)
                                        .foregroundColor(.red)
                                }
                                Spacer()
                            }
                            .padding()
                            .background(Color.red.opacity(0.15))
                            .cornerRadius(12)
                            .padding()
                        }
                        
                        if let success = successMessage {
                            HStack(spacing: 12) {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Success!")
                                        .font(.caption)
                                        .fontWeight(.semibold)
                                        .foregroundColor(.green)
                                    Text(success)
                                        .font(.callout)
                                        .foregroundColor(.green)
                                }
                                Spacer()
                            }
                            .padding()
                            .background(Color.green.opacity(0.15))
                            .cornerRadius(12)
                            .padding()
                        }
                    }
                    .padding(.vertical)
                }
                
                Spacer()
                
                VStack(spacing: 12) {
                    Button(action: generateFlashcards) {
                        if isGenerating {
                            HStack(spacing: 8) {
                                ProgressView()
                                    .progressViewStyle(.circular)
                                    .tint(.white)
                                Text("Processing...")
                                Spacer()
                            }
                            .frame(maxWidth: .infinity)
                            .padding(14)
                            .background(Color.purple)
                            .foregroundColor(.white)
                            .cornerRadius(12)
                            .fontWeight(.semibold)
                        } else {
                            HStack(spacing: 8) {
                                Image(systemName: "sparkles")
                                Text("Generate Flashcards")
                                Spacer()
                            }
                            .frame(maxWidth: .infinity)
                            .padding(14)
                            .background(selectedImages.isEmpty ? Color.gray.opacity(0.4) : Color.purple)
                            .foregroundColor(.white)
                            .cornerRadius(12)
                            .fontWeight(.semibold)
                        }
                    }
                    .disabled(selectedImages.isEmpty || isGenerating)
                    
                    Button(action: { showImageSourceAlert = true }) {
                        HStack(spacing: 8) {
                            Image(systemName: "plus.circle.fill")
                            Text("Add Image")
                            Spacer()
                        }
                        .frame(maxWidth: .infinity)
                        .padding(14)
                        .background(Color.white.opacity(0.1))
                        .foregroundColor(.white)
                        .cornerRadius(12)
                        .fontWeight(.semibold)
                    }
                    .disabled(isGenerating)
                }
                .padding()
            }
        }
        .confirmationDialog("Choose Image Source", isPresented: $showImageSourceAlert) {
            Button("Camera") {
                imageSourceType = .camera
                showImagePicker = true
            }
            Button("Photo Library") {
                imageSourceType = .photoLibrary
                showImagePicker = true
            }
            Button("Cancel", role: .cancel) {}
        }
        .sheet(isPresented: $showImagePicker) {
            ImagePicker(selectedImage: Binding(
                get: { nil },
                set: { img in
                    if let img = img {
                        selectedImages.append(img)
                    }
                }
            ), sourceType: imageSourceType)
        }
        .background(Color.clear)
        .korahGradientBackground()
        .preferredColorScheme(.dark)
    }
    
    private func generateFlashcards() {
        guard !selectedImages.isEmpty else { return }
        isGenerating = true
        errorMessage = nil
        successMessage = nil
        generationProgress = 0.2
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            generationProgress = 0.4
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            generationProgress = 0.6
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            generationProgress = 0.8
        }
        
        guard let url = URL(string: "https://api.openai.com/v1/chat/completions") else {
            errorMessage = "Invalid URL"
            isGenerating = false
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue(OpenAIConfig.bearerToken, forHTTPHeaderField: "Authorization")
        
        if OpenAIConfig.bearerToken.isEmpty {
            errorMessage = "Missing or invalid API key."
            isGenerating = false
            return
        }
        
        let systemPrompt = """
You are Korah, a study assistant. Analyze the provided images and extract content to create flashcards. Return PURE JSON (no code fences, no markdown) matching this schema:

{
  "cards": [
    {"term": string, "definition": string},
    ...
  ]
}

Rules:
- Extract key terms and definitions from the images
- Create 8-20 flashcard pairs depending on content
- Make definitions clear and concise
- Return valid JSON only. No extra text.
"""
        
        let imageContents = selectedImages.compactMap { image -> String? in
            guard let data = image.jpegData(compressionQuality: 0.8) else { return nil }
            return data.base64EncodedString()
        }
        
        guard !imageContents.isEmpty else {
            errorMessage = "Failed to process images"
            isGenerating = false
            return
        }
        
        var messageContent: [[String: Any]] = [
            ["type": "text", "text": systemPrompt]
        ]
        
        for imageBase64 in imageContents {
            messageContent.append([
                "type": "image_url",
                "image_url": [
                    "url": "data:image/jpeg;base64,\(imageBase64)",
                    "detail": "high"
                ]
            ])
        }
        
        messageContent.append([
            "type": "text",
            "text": "Extract all content from these images and create flashcards using the provided JSON schema."
        ])
        
        let requestBody: [String: Any] = [
            "model": "gpt-4-turbo",
            "temperature": 0.3,
            "max_tokens": 4000,
            "messages": [
                [
                    "role": "user",
                    "content": messageContent
                ]
            ]
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
                DispatchQueue.main.async { errorMessage = "HTTP Error \(http.statusCode)" }
                return
            }
            
            do {
                if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let choices = json["choices"] as? [[String: Any]],
                   let firstChoice = choices.first,
                   let message = firstChoice["message"] as? [String: Any],
                   let content = message["content"] as? String {
                    
                    if let jsonData = content.data(using: .utf8),
                       let parsed = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
                       let cardList = parsed["cards"] as? [[String: String]] {
                        
                        var existing: [FlashcardSet] = []
                        if let existingData = UserDefaults.standard.data(forKey: "FlashcardSets"),
                           let decoded = try? JSONDecoder().decode([FlashcardSet].self, from: existingData) {
                            existing = decoded
                        }
                        
                        let newCards = cardList.map { Flashcard(front: $0["term"] ?? "", back: $0["definition"] ?? "") }
                        let newSet = FlashcardSet(title: "Flashcards from Scan", cards: newCards)
                        existing.append(newSet)
                        
                        if let encoded = try? JSONEncoder().encode(existing) {
                            UserDefaults.standard.set(encoded, forKey: "FlashcardSets")
                        }
                        
                        DispatchQueue.main.async {
                            successMessage = "Flashcards created successfully!"
                            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                                dismiss()
                            }
                        }
                        return
                    }
                }
                DispatchQueue.main.async { errorMessage = "Failed to parse response" }
            } catch {
                DispatchQueue.main.async { errorMessage = "Parse error: \(error.localizedDescription)" }
            }
        }.resume()
    }
}

#Preview {
    NavigationStack { ScanFlashcardsView() }
}
