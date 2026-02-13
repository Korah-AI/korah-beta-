import SwiftUI

struct OpeningView: View {
    @State private var fadeIn = false
    @State private var navigateToMoodCheckIn = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                VStack(spacing: 30) {
                    Image("monster")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 150, height: 150) 
                        .opacity(fadeIn ? 1 : 0)
                        .animation(.easeIn(duration: 1.0).delay(0.1), value: fadeIn)
                    
                    Text("Welcome to Korah")
                        .font(.largeTitle.weight(.semibold))
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)
                        .opacity(fadeIn ? 1 : 0)
                        .animation(.easeIn(duration: 1.0).delay(0.3), value: fadeIn)
                    
                    Text("Beta Version.")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .opacity(fadeIn ? 1 : 0)
                        .animation(.easeIn(duration: 1.0).delay(0.5), value: fadeIn)
                    
                    Spacer()
                    
                    Button(action: {
                        navigateToMoodCheckIn = true
                    }) {
                        Text("Get Started")
                            .font(.headline)
                            .foregroundStyle(.white)
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(Color.purple)
                            .clipShape(.rect(cornerRadius: 12))
                            .padding(.horizontal, 40)
                    }
                    .opacity(fadeIn ? 1 : 0)
                    .animation(.easeIn(duration: 1.0).delay(0.7), value: fadeIn)
                    
                    Spacer()
                }
                .onAppear {
                    fadeIn = true
                }
            }
            .korahGradientBackground()
            .fullScreenCover(isPresented: $navigateToMoodCheckIn) {
                MoodCheckInView()
            }
        }
        .preferredColorScheme(.dark)
        .accentColor(.purple)
    }
}

#Preview {
    OpeningView()
}
