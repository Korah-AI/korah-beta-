import SwiftUI

struct OnboardingView: View {
    @Binding var isOnboardingComplete: Bool
    @State private var currentPage = 0
    @State private var fadeIn = false
    
    let pages = [
        OnboardingPage(
            imageName: "AppIcon",
            title: "Welcome to Korah!",
            description: "Please read each of the following pages to learn how to navigate the app.",
            color: .purple,
            isAppIcon: true
        ),
        OnboardingPage(
            imageName: "checklist",
            title: "Tasks",
            description: "Create and manage your to-do list with difficulty ratings that adapt to your focus level.",
            color: .blue
        ),
        OnboardingPage(
            imageName: "camera.viewfinder",
            title: "Scan",
            description: "Quickly capture and digitize notes, assignments, and study materials using your camera.",
            color: .orange
        ),
        OnboardingPage(
            imageName: "timer",
            title: "Focus Timer",
            description: "Stay productive with deep focus sessions. Track your work time and maintain concentration. Screen time tracking features coming soon in the full beta!",
            color: .pink
        ),
        OnboardingPage(
            imageName: "message.fill",
            title: "Chat",
            description: "Get instant help with your studies. Ask questions and get answers powered by AI.",
            color: .green
        ),
        OnboardingPage(
            imageName: "book.closed",
            title: "Study",
            description: "Access flashcards, study guides, and practice tests to master your subjects.",
            color: .cyan
        ),
        OnboardingPage(
            imageName: "lock.shield.fill",
            title: "Your Data, Your Device",
            description: "This beta version is completely accountless. All your data is saved locally on your phone—no internet required, no servers involved.",
            color: .indigo
        )
    ]
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            VStack(spacing: 30) {
                Spacer()
                
                // Onboarding pages
                TabView(selection: $currentPage) {
                    ForEach(0..<pages.count, id: \.self) { index in
                        OnboardingPageView(page: pages[index])
                            .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .always))
                .indexViewStyle(.page(backgroundDisplayMode: .always))
                .frame(height: 500)
                
                Spacer()
                
                // Continue/Get Started button
                Button(action: {
                    if currentPage < pages.count - 1 {
                        withAnimation {
                            currentPage += 1
                        }
                    } else {
                        completeOnboarding()
                    }
                }) {
                    Text(currentPage < pages.count - 1 ? "Continue" : "Get Started")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(pages[currentPage].color.opacity(0.8))
                        .cornerRadius(12)
                        .padding(.horizontal, 40)
                }
                .opacity(fadeIn ? 1 : 0)
                .animation(.easeIn(duration: 0.5), value: fadeIn)
                
                Spacer()
            }
        }
        .onAppear {
            fadeIn = true
        }
    }
    
    private func completeOnboarding() {
        withAnimation(.easeInOut(duration: 0.4)) {
            isOnboardingComplete = true
        }
    }
}

struct OnboardingPage {
    let imageName: String
    let title: String
    let description: String
    let color: Color
    var isAppIcon: Bool = false
}

struct OnboardingPageView: View {
    let page: OnboardingPage
    @State private var appear = false
    
    var body: some View {
        VStack(spacing: 24) {
            if page.isAppIcon {
                Image(page.imageName)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 120, height: 120)
                    .clipShape(RoundedRectangle(cornerRadius: 26))
                    .opacity(appear ? 1 : 0)
                    .offset(y: appear ? 0 : 20)
                    .animation(.easeOut(duration: 0.6), value: appear)
            } else {
                Image(systemName: page.imageName)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 120, height: 120)
                    .foregroundColor(page.color)
                    .opacity(appear ? 1 : 0)
                    .offset(y: appear ? 0 : 20)
                    .animation(.easeOut(duration: 0.6), value: appear)
            }
            
            Text(page.title)
                .font(.system(size: 32, weight: .bold))
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
                .opacity(appear ? 1 : 0)
                .offset(y: appear ? 0 : 20)
                .animation(.easeOut(duration: 0.6).delay(0.1), value: appear)
            
            Text(page.description)
                .font(.system(size: 18, weight: .regular))
                .foregroundColor(.white.opacity(0.8))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
                .opacity(appear ? 1 : 0)
                .offset(y: appear ? 0 : 20)
                .animation(.easeOut(duration: 0.6).delay(0.2), value: appear)
        }
        .onAppear {
            appear = true
        }
    }
}

#Preview {
    OnboardingView(isOnboardingComplete: .constant(false))
}
