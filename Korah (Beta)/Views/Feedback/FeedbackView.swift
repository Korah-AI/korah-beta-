import SwiftUI

struct FeedbackView: View {
    @Environment(\.dismiss) private var dismiss
    
    @State private var selectedCategory: FeedbackCategory = .general
    @State private var feedbackMessage: String = ""
    @State private var isSubmitting = false
    @State private var showSuccessAlert = false
    @State private var showErrorAlert = false
    @State private var errorMessage = ""
    
    enum FeedbackCategory: String, CaseIterable {
        case bug = "Bug Report"
        case feature = "Feature Request"
        case general = "General Feedback"
        case support = "Help/Support"
        
        var icon: String {
            switch self {
            case .bug: return "ladybug.fill"
            case .feature: return "lightbulb.fill"
            case .general: return "bubble.left.and.bubble.right.fill"
            case .support: return "questionmark.circle.fill"
            }
        }
        
        var color: Color {
            switch self {
            case .bug: return .red
            case .feature: return .blue
            case .general: return .purple
            case .support: return .green
            }
        }
        
        var placeholder: String {
            switch self {
            case .bug: return "Describe the bug you encountered..."
            case .feature: return "Tell us about the feature you'd like to see..."
            case .general: return "Share your thoughts with us..."
            case .support: return "How can we help you?"
            }
        }
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.korahBackgroundStart.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        // Header
                        VStack(spacing: 12) {
                            Image(systemName: "envelope.fill")
                                .font(.system(size: 50))
                                .foregroundColor(.purple)
                            
                            Text("Send Feedback")
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                            
                            Text("Help us improve Korah for everyone")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        .padding(.top, 20)
                        
                        // Category Selection
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Category")
                                .font(.headline)
                                .foregroundColor(.white)
                                .padding(.horizontal)
                            
                            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                                ForEach(FeedbackCategory.allCases, id: \.self) { category in
                                    CategoryButton(
                                        category: category,
                                        isSelected: selectedCategory == category
                                    ) {
                                        withAnimation(.spring(response: 0.3)) {
                                            selectedCategory = category
                                        }
                                    }
                                }
                            }
                            .padding(.horizontal)
                        }
                        
                        // Message Input
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Your Message")
                                .font(.headline)
                                .foregroundColor(.white)
                                .padding(.horizontal)
                            
                            ZStack(alignment: .topLeading) {
                                if feedbackMessage.isEmpty {
                                    Text(selectedCategory.placeholder)
                                        .foregroundColor(.secondary)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 12)
                                }
                                
                                TextEditor(text: $feedbackMessage)
                                    .foregroundColor(.white)
                                    .scrollContentBackground(.hidden)
                                    .frame(minHeight: 150)
                                    .padding(4)
                            }
                            .background(Color.white.opacity(0.1))
                            .cornerRadius(12)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(selectedCategory.color.opacity(0.3), lineWidth: 1)
                            )
                            .padding(.horizontal)
                        }
                        
                        // Character Count
                        HStack {
                            Spacer()
                            Text("\(feedbackMessage.count) / 1000")
                                .font(.caption)
                                .foregroundColor(feedbackMessage.count > 1000 ? .red : .secondary)
                        }
                        .padding(.horizontal, 24)
                        
                        // Submit Button
                        Button(action: submitFeedback) {
                            HStack {
                                if isSubmitting {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                } else {
                                    Image(systemName: "paperplane.fill")
                                    Text("Submit Feedback")
                                }
                            }
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(
                                feedbackMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || feedbackMessage.count > 1000 || isSubmitting
                                    ? Color.gray
                                    : selectedCategory.color
                            )
                            .cornerRadius(12)
                        }
                        .disabled(feedbackMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || feedbackMessage.count > 1000 || isSubmitting)
                        .padding(.horizontal)
                        .padding(.top, 8)
                        
                        Spacer()
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") {
                        dismiss()
                    }
                    .foregroundColor(.purple)
                }
            }
            .alert("Thank You!", isPresented: $showSuccessAlert) {
                Button("Done") {
                    dismiss()
                }
            } message: {
                Text("Your feedback has been submitted successfully. We appreciate your help in making Korah better!")
            }
            .alert("Submission Failed", isPresented: $showErrorAlert) {
                Button("OK") { }
            } message: {
                Text(errorMessage)
            }
        }
    }
    
    private func submitFeedback() {
        guard !feedbackMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              feedbackMessage.count <= 1000 else {
            return
        }
        
        isSubmitting = true
        
        let url = URL(string: "\(OpenAIConfig.proxyBaseURL)/api/feedback")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: Any] = [
            "category": selectedCategory.rawValue,
            "message": feedbackMessage,
            "deviceId": DeviceIDManager.shared.deviceID,
            "appVersion": Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown"
        ]
        
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                isSubmitting = false
                
                if let error = error {
                    errorMessage = "Network error: \(error.localizedDescription)"
                    showErrorAlert = true
                    return
                }
                
                guard let httpResponse = response as? HTTPURLResponse else {
                    errorMessage = "Invalid response from server"
                    showErrorAlert = true
                    return
                }
                
                if httpResponse.statusCode == 200 {
                    showSuccessAlert = true
                } else {
                    errorMessage = "Server returned error: \(httpResponse.statusCode)"
                    showErrorAlert = true
                }
            }
        }.resume()
    }
}

struct CategoryButton: View {
    let category: FeedbackView.FeedbackCategory
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: category.icon)
                    .font(.system(size: 28))
                    .foregroundColor(isSelected ? category.color : .white.opacity(0.6))
                
                Text(category.rawValue)
                    .font(.caption)
                    .fontWeight(isSelected ? .semibold : .regular)
                    .foregroundColor(isSelected ? .white : .white.opacity(0.6))
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 100)
            .background(
                isSelected
                    ? category.color.opacity(0.2)
                    : Color.white.opacity(0.08)
            )
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(
                        isSelected ? category.color : Color.white.opacity(0.1),
                        lineWidth: isSelected ? 2 : 1
                    )
            )
            .scaleEffect(isSelected ? 1.0 : 0.95)
        }
    }
}

#Preview {
    FeedbackView()
}
