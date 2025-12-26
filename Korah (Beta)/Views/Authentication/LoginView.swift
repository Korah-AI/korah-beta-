import SwiftUI

struct LoginView: View {
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
                Text("Log In")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.top, 60)
                
                if let saved = SavedAccount.load() {
                    VStack(spacing: 8) {
                        HStack(spacing: 8) {
                            Image(systemName: "person.crop.circle.fill")
                                .foregroundColor(.white)
                            Text(saved.username.isEmpty ? saved.email : saved.username)
                                .foregroundColor(.white)
                                .font(.subheadline)
                            Spacer()
                            Button {
                                quickLogin(with: saved)
                            } label: {
                                Label("Log In", systemImage: "arrow.right.circle.fill")
                                    .foregroundColor(.black)
                                    .padding(.vertical, 8)
                                    .padding(.horizontal, 12)
                                    .background(Color.purple)
                                    .cornerRadius(10)
                            }
                        }
                        .padding()
                        .background(Color.white.opacity(0.06))
                        .cornerRadius(12)
                        .padding(.horizontal, 40)

                        Button(role: .destructive) {
                            SavedAccount.clear()
                        } label: {
                            Text("Not you? Remove saved account")
                                .font(.caption)
                                .foregroundColor(.red)
                        }
                    }
                }
                
                TextField("Email", text: $email)
                    .padding()
                    .background(Color.white.opacity(0.1))
                    .cornerRadius(8)
                    .foregroundColor(.white)
                    .keyboardType(.emailAddress)
                    .padding(.horizontal, 40)
                
                SecureField("Password", text: $password)
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
                    if validateCredentials() {
                        navigateToHome = true
                    }
                }) {
                    Text("Log In")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(.black)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.purple)
                        .cornerRadius(12)
                        .padding(.horizontal, 40)
                }
                .disabled(email.isEmpty || password.isEmpty)
                
                Spacer()
            }
        }
        .fullScreenCover(isPresented: $navigateToHome) {
            if alreadyCheckedInToday() {
                HomePageView()
            } else {
                MoodCheckInView(firstName: savedFirstName)
            }
        }
    }
    
    func validateCredentials() -> Bool {
        if let user = UserDatabaseManager.getUser(email: email) {
            if user.password == password {
                SavedAccount.save(email: user.email, username: user.username)
                savedFirstName = user.firstName
                isLoggedIn = true
                errorMessage = nil
                return true
            } else {
                errorMessage = "Incorrect password."
                return false
            }
        } else {
            errorMessage = "No account found for this email."
            return false
        }
    }
    
    func alreadyCheckedInToday() -> Bool {
        let lastCheckInDate = UserDefaults.standard.object(forKey: "LastMoodCheckInDate") as? Date
        let calendar = Calendar.current
        return lastCheckInDate != nil && calendar.isDateInToday(lastCheckInDate!)
    }
    
    struct SavedAccount: Codable {
        let email: String
        let username: String

        private static let key = "SavedAccount"

        static func load() -> SavedAccount? {
            if let data = UserDefaults.standard.data(forKey: key),
               let acct = try? JSONDecoder().decode(SavedAccount.self, from: data) {
                return acct
            }
            return nil
        }

        static func save(email: String, username: String) {
            let acct = SavedAccount(email: email, username: username)
            if let data = try? JSONEncoder().encode(acct) {
                UserDefaults.standard.set(data, forKey: key)
            }
        }

        static func clear() {
            UserDefaults.standard.removeObject(forKey: key)
        }
    }

    private func quickLogin(with saved: SavedAccount) {
        if let user = UserDatabaseManager.getUser(email: saved.email) {
            savedFirstName = user.firstName
            isLoggedIn = true
            navigateToHome = true
            errorMessage = nil
        } else {
            errorMessage = "Saved account not found. Please log in manually."
            SavedAccount.clear()
        }
    }
}

