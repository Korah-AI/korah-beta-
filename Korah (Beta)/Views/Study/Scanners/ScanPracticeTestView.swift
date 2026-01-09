import SwiftUI
import UIKit

struct ScanPracticeTestView: View {
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
        NavigationStack {
            ZStack {
                VStack(spacing: 0) {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Scan Practice Test")
                                .font(.headline)
                                .foregroundColor(.white)
                            Text("\(selectedImages.count) image\(selectedImages.count == 1 ? "" : "s") added")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        Button(action: { selectedImages.removeAll() }) {
                            Image(systemName: "trash")
                                .foregroundColor(.white)
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
                                    Image(systemName: "checkmark.square.fill")
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
                                    Text("Creating practice test...")
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
                        Button(action: generatePracticeTest) {
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
                                    Text("Generate Practice Test")
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
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(role: .cancel) { dismiss() } label: { Image(systemName: "xmark") }
                }
                ToolbarItem(placement: .principal) {
                    Text("Scan Practice Test").font(.headline).foregroundColor(.white)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .background(Color.clear)
            .korahGradientBackground()
            .preferredColorScheme(.dark)
        }
    }
    
    private func generatePracticeTest() {
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
You are Korah, a study assistant. Analyze the provided images and create practice test questions. Return PURE JSON (no code fences, no markdown) matching this schema:

{
  "questions": [
    {
      "prompt": string,
      "option1": string,
      "option2": string,
      "option3": string,
      "option4": string,
      "correctOption": int (0-3)
    },
    ...
  ]
}

Rules:
- Extract content from the images to create multiple choice questions
- Create 8-15 practice questions
- Ensure each question has exactly 4 options
- correctOption is the 0-based index of the correct answer
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
            "text": "Create multiple choice practice questions from these images using the provided JSON schema."
        ])
        
        let requestBody: [String: Any] = [
            "model": "gpt-4-turbo",
            "temperature": 0.3,
            "max_tokens": 4000,
            "messages": [
                ["role": "user", "content": messageContent]
            ]
        ]
        
        request.httpBody = try? JSONSerialization.data(withJSONObject: requestBody)
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async { isGenerating = false }
            
            if let error = error {
                DispatchQueue.main.async { errorMessage = "I'm having trouble connecting. Please check your internet connection and try again." }
                return
            }
            guard let data = data else {
                DispatchQueue.main.async { errorMessage = "I didn't get a response. Please try again in a moment." }
                return
            }
            
            if let http = response as? HTTPURLResponse, http.statusCode != 200 {
                var message = "Oops! Something went wrong. "
                if http.statusCode == 401 {
                    message += "There's an authentication issue. Please contact support."
                } else if http.statusCode == 429 {
                    message += "Too many requests right now. Please wait a moment and try again."
                } else if http.statusCode >= 500 {
                    message += "The service is having trouble. Please try again in a few minutes."
                } else {
                    message += "Please try again."
                }
                DispatchQueue.main.async { errorMessage = message }
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
                       let questionList = parsed["questions"] as? [[String: Any]] {
                        
                        let questions = questionList.compactMap { dict -> PracticeTestQuestion? in
                            let prompt = dict["prompt"] as? String ?? ""
                            let opt1 = dict["option1"] as? String ?? ""
                            let opt2 = dict["option2"] as? String ?? ""
                            let opt3 = dict["option3"] as? String ?? ""
                            let opt4 = dict["option4"] as? String ?? ""
                            let correctIdx = dict["correctOption"] as? Int ?? 0
                            
                            guard !prompt.isEmpty, !opt1.isEmpty, !opt2.isEmpty, !opt3.isEmpty, !opt4.isEmpty else {
                                return nil
                            }
                            
                            return PracticeTestQuestion(
                                prompt: prompt,
                                options: [opt1, opt2, opt3, opt4],
                                correctIndex: correctIdx
                            )
                        }
                        
                        guard !questions.isEmpty else {
                            DispatchQueue.main.async { errorMessage = "I couldn't generate questions from that. Please try again." }
                            return
                        }
                        
                        var existing: [PracticeTest] = []
                        if let existingData = UserDefaults.standard.data(forKey: "PracticeTests"),
                           let decoded = try? JSONDecoder().decode([PracticeTest].self, from: existingData) {
                            existing = decoded
                        }
                        
                        let newTest = PracticeTest(
                            title: "Practice Test from Scan",
                            questions: questions
                        )
                        existing.append(newTest)
                        
                        if let encoded = try? JSONEncoder().encode(existing) {
                            UserDefaults.standard.set(encoded, forKey: "PracticeTests")
                        }
                        
                        DispatchQueue.main.async {
                            successMessage = "Practice test created successfully!"
                            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                                dismiss()
                            }
                        }
                        return
                    }
                }
                DispatchQueue.main.async { errorMessage = "I had trouble understanding the response. Please try again." }
            } catch {
                DispatchQueue.main.async { errorMessage = "I had trouble processing that. Please try again." }
            }
        }.resume()
    }
}

#Preview {
    NavigationStack { ScanPracticeTestView() }
}
