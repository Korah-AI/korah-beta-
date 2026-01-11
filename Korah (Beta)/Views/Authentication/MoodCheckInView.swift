import SwiftUI

struct MoodCheckInView: View {
    @AppStorage("UserMood") private var userMood: String = ""
    @State private var opacity: Double = 0
    
    var body: some View {
        NavigationStack {
            VStack {
                HStack {
                    Spacer()
                    Button(action: skipMoodCheckIn) {
                        Text("Skip")
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.6))
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                    }
                }
                .padding(.top, 16)
                .padding(.trailing, 16)
                
                Spacer()
                
                VStack(spacing: 32) {
                    VStack(spacing: 12) {
                        Image(systemName: "brain.head.profile")
                            .font(.system(size: 60))
                            .foregroundColor(.purple)
                        Text("How are you feeling?")
                            .font(.title)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                        Text("Help us understand your focus level")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                
                    VStack(spacing: 16) {
                        MoodButton(emoji: "🟢", title: "Very Focused", description: "Ready to tackle anything!", color: .green) {
                            selectMood("🟢")
                        }
                        
                        MoodButton(emoji: "🟡", title: "Moderately Focused", description: "Somewhere in the middle", color: .yellow) {
                            selectMood("🟡")
                        }
                        
                        MoodButton(emoji: "🔴", title: "Not Focused", description: "Having trouble concentrating", color: .red) {
                            selectMood("🔴")
                        }
                    }
                    .padding(.horizontal, 24)
                }
                
                Spacer()
            }
            .korahGradientBackground()
            .opacity(opacity)
            .onAppear {
                withAnimation(.easeIn(duration: 0.5)) {
                    opacity = 1
                }
            }
        }
    }
    
    private func selectMood(_ mood: String) {
        userMood = mood
        UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: "LastMoodCheckInDate")
    }
    
    private func skipMoodCheckIn() {
        // Mark as checked in without setting mood
        UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: "LastMoodCheckInDate")
    }
    
    struct MoodButton: View {
        let emoji: String
        let title: String
        let description: String
        let color: Color
        let action: () -> Void
        @State private var pressed = false

        var body: some View {
            Button(action: {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { pressed = true }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { pressed = false; action() }
            }) {
                HStack(spacing: 16) {
                    Text(emoji)
                        .font(.system(size: 32))
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(title)
                            .font(.headline)
                            .foregroundColor(.white)
                        Text(description)
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.7))
                    }
                    Spacer()
                }
                .padding()
                .frame(maxWidth: .infinity)
                .background(color.opacity(0.2))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(color, lineWidth: 2)
                )
                .cornerRadius(14)
                .scaleEffect(pressed ? 0.97 : 1)
            }
        }
    }
}

