import SwiftUI

struct MoodCheckInView: View {
    @AppStorage("UserMood") private var userMood: String = ""
    @State private var navigateToHome = false
    var firstName: String
    
    var body: some View {
        ZStack {
            LinearGradient(colors: [Color.black, Color.purple.opacity(0.35)], startPoint: .topLeading, endPoint: .bottomTrailing)
                .ignoresSafeArea()

            VStack(spacing: 24) {
                VStack(spacing: 8) {
                    Text("How are you feeling today?")
                        .font(.largeTitle).bold()
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                    Text("Pick one to tailor your focus plan.")
                        .foregroundColor(.white.opacity(0.7))
                }
                .padding(.top, 20)

                VStack(spacing: 16) {
                    MoodButton(title: "Very focused, ready to go", emoji: "🟢", color: .green) {
                        selectMood("🟢")
                    }
                    MoodButton(title: "I feel okay, somewhere near the middle", emoji: "🟡", color: .yellow) {
                        selectMood("🟡")
                    }
                    MoodButton(title: "Not very focused, not good", emoji: "🔴", color: .red) {
                        selectMood("🔴")
                    }
                }
                .padding(.horizontal)

                Spacer()
            }
            .padding()
        }
        .fullScreenCover(isPresented: $navigateToHome) {
            HomePageView()
        }
    }
    
    private func selectMood(_ mood: String) {
        userMood = mood
        UserDefaults.standard.set(Date(), forKey: "LastMoodCheckInDate")
        navigateToHome = true
    }
    
    struct MoodButton: View {
        let title: String
        let emoji: String
        let color: Color
        let action: () -> Void
        @State private var pressed = false

        var body: some View {
            Button(action: {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { pressed = true }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { pressed = false; action() }
            }) {
                HStack(spacing: 12) {
                    Text(emoji).font(.largeTitle)
                    Text(title)
                        .font(.headline)
                        .foregroundColor(.black)
                        .multilineTextAlignment(.leading)
                }
                .padding()
                .frame(maxWidth: .infinity)
                .background(color)
                .cornerRadius(14)
                .scaleEffect(pressed ? 0.97 : 1)
                .shadow(color: color.opacity(0.4), radius: 8, x: 0, y: 6)
            }
        }
    }
}

