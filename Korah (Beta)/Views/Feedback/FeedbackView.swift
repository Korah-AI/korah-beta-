import SwiftUI

struct FeedbackView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    
    @State private var selectedCategory: FeedbackCategory = .general
    @State private var showMailErrorAlert = false
    
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
                                        selectedCategory = category
                                        openMailApp()
                                    }
                                }
                            }
                            .padding(.horizontal)
                        }
                        
                        // Info Text
                        Text("Select a category below to compose an email with your feedback.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                            .padding(.bottom, 8)
                        
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
            .alert("Cannot Open Mail", isPresented: $showMailErrorAlert) {
                Button("OK") { }
            } message: {
                Text("Please make sure you have the Mail app configured on your device, or email feedback directly to oscareucedaf1@gmail.com")
            }
        }
    }
    
    private func openMailApp() {
        let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown"
        let deviceId = DeviceIDManager.shared.deviceID
        
        let subject = "[Korah Beta] \(selectedCategory.rawValue)"
        let body = """
        
        
        ---
        Category: \(selectedCategory.rawValue)
        Device ID: \(deviceId)
        App Version: \(appVersion)
        """
        
        // URL encode the subject and body
        guard let subjectEncoded = subject.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let bodyEncoded = body.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let mailURL = URL(string: "mailto:oscareucedaf1@gmail.com?subject=\(subjectEncoded)&body=\(bodyEncoded)") else {
            showMailErrorAlert = true
            return
        }
        
        openURL(mailURL) { accepted in
            if !accepted {
                showMailErrorAlert = true
            }
        }
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
