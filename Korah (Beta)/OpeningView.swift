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
                        .font(.system(size: 36, weight: .semibold))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                        .opacity(fadeIn ? 1 : 0)
                        .animation(.easeIn(duration: 1.0).delay(0.3), value: fadeIn)
                    
                    Text("Beta Version.")
                        .font(.system(size: 20, weight: .regular))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .opacity(fadeIn ? 1 : 0)
                        .animation(.easeIn(duration: 1.0).delay(0.5), value: fadeIn)
                    
                    Spacer()
                    
                    Button(action: {
                        navigateToMoodCheckIn = true
                    }) {
                        Text("Get Started")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(.white)
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(Color.purple)
                            .cornerRadius(12)
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
        .task {
            applyKorahAppearance()
        }
        .preferredColorScheme(.dark)
        .accentColor(.purple)
    }
}

struct OpeningView_Previews: PreviewProvider {
    static var previews: some View {
        OpeningView()
    }
}
