import SwiftUI

struct CreateAccountView: View {
    @State private var firstName: String = ""
    @State private var username: String = ""
    @State private var email: String = ""
    @State private var password: String = ""
    
    @AppStorage("IsLoggedIn") private var isLoggedIn: Bool = false
    @AppStorage("SavedFirstName") private var savedFirstName: String = ""
    
    @State private var navigateToHome = false
    @State private var errorMessage: String?
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            VStack(spacing: 20) {
                Text("Create Account")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(.white)
                
                Group {
                    TextField("First Name", text: $firstName)
                    TextField("Username", text: $username)
                    TextField("Email", text: $email)
                        .keyboardType(.emailAddress)
                    SecureField("Password (min 6 chars)", text: $password)
                }
                .padding()
                .background(Color.white.opacity(0.1))
                .cornerRadius(8)
                .foregroundColor(.white)
                .padding(.horizontal, 40)
                
                if let error = errorMessage {
                    Text(error)
                        .foregroundColor(.red)
                        .font(.caption)
                }
                
                Button(action: {
                    if validateFields() {
                        let user = User(firstName: firstName, username: username, email: email, password: password)
                        UserDatabaseManager.saveUser(user)
                        savedFirstName = firstName
                        isLoggedIn = true
                        navigateToHome = true
                    }
                }) {
                    Text("Create Account")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(.black)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.purple)
                        .cornerRadius(12)
                        .padding(.horizontal, 40)
                }
                .disabled(firstName.isEmpty || username.isEmpty || email.isEmpty || password.isEmpty)
                
                Spacer()
            }
            .fullScreenCover(isPresented: $navigateToHome) {
                if alreadyCheckedInToday() {
                    HomePageView()
                } else {
                    MoodCheckInView(firstName: savedFirstName)
                }
            }
        }
    }
    
    func validateFields() -> Bool {
        if firstName.isEmpty || username.isEmpty || email.isEmpty || password.isEmpty {
            errorMessage = "All fields are required."
            return false
        }
        if !email.contains("@") || !email.contains(".") {
            errorMessage = "Enter a valid email (name@email.com)."
            return false
        }
        if password.count < 6 {
            errorMessage = "Password must be at least 6 characters."
            return false
        }
        errorMessage = nil
        return true
    }
}

func alreadyCheckedInToday() -> Bool {
    let lastCheckInDate = UserDefaults.standard.object(forKey: "LastMoodCheckInDate") as? Date
    let calendar = Calendar.current
    return lastCheckInDate != nil && calendar.isDateInToday(lastCheckInDate!)
}
