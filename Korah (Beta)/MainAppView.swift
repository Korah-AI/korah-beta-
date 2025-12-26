import SwiftUI

struct MainAppView: View {
    var username: String
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            VStack(spacing: 20) {
                Text("Welcome, \(username) 👋")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(.white)
                
                Text("This is your main app screen.")
                    .font(.system(size: 20, weight: .regular))
                    .foregroundColor(Color.purple)
                
                Spacer()
            }
            .padding()
        }
    }
}

struct MainAppView_Previews: PreviewProvider {
    static var previews: some View {
        MainAppView(username: "Oscar")
    }
}
