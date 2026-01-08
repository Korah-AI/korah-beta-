import SwiftUI

struct LaunchAnimationView: View {
    let onComplete: () -> Void
    @State private var textOpacity: Double = 0
    @State private var fadeOut: Bool = false
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            VStack(spacing: 20) {
                Image("AppIcon")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 120, height: 120)
                    .clipShape(RoundedRectangle(cornerRadius: 26))
                    .opacity(fadeOut ? 0 : 1)
                
                Text("Korah")
                    .font(.system(size: 48, weight: .bold))
                    .foregroundColor(.white)
                    .opacity(fadeOut ? 0 : textOpacity)
            }
        }
        .onAppear {
            // Fade in the text after a brief delay
            withAnimation(.easeIn(duration: 0.8).delay(0.2)) {
                textOpacity = 1.0
            }
            
            // Auto-dismiss after animation completes
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                withAnimation(.easeOut(duration: 0.3)) {
                    fadeOut = true
                }
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    onComplete()
                }
            }
        }
    }
}

struct LaunchAnimationView_Previews: PreviewProvider {
    static var previews: some View {
        LaunchAnimationView(onComplete: {})
    }
}
