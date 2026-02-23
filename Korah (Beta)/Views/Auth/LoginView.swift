import SwiftUI

struct LoginView: View {
    @State private var email = ""
    @State private var password = ""
    @Environment(AuthManager.self) private var authManager
    @FocusState private var focusedField: Field?
    
    enum Field {
        case email
        case password
    }
    
    var body: some View {
        ZStack {
            Color(.systemBackground)
                .ignoresSafeArea()
            
            VStack(spacing: 24) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Welcome Back")
                        .font(.system(size: 32, weight: .bold))
                    
                    Text("Sign in to continue")
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, 32)
                
                VStack(spacing: 16) {
                    // Email Field
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Email")
                            .font(.system(size: 14, weight: .semibold))
                        
                        TextField("name@example.com", text: $email)
                            .textInputAutocapitalization(.never)
                            .keyboardType(.emailAddress)
                            .focused($focusedField, equals: .email)
                            .padding(12)
                            .background(Color(.secondarySystemBackground))
                            .clipShape(.rect(cornerRadius: 8))
                    }
                    
                    // Password Field
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Password")
                            .font(.system(size: 14, weight: .semibold))
                        
                        SecureField("••••••••", text: $password)
                            .focused($focusedField, equals: .password)
                            .padding(12)
                            .background(Color(.secondarySystemBackground))
                            .clipShape(.rect(cornerRadius: 8))
                    }
                }
                
                // Error Message
                if let error = authManager.errorMessage {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(error)
                            .font(.system(size: 13))
                            .foregroundStyle(.red)
                            .lineLimit(3)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
                    .background(Color.red.opacity(0.1))
                    .clipShape(.rect(cornerRadius: 8))
                }
                
                // Login Button
                Button(action: handleLogin) {
                    if authManager.isLoading {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Text("Sign In")
                            .font(.system(size: 16, weight: .semibold))
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 44)
                .foregroundStyle(.white)
                .background(email.isEmpty || password.isEmpty || authManager.isLoading ? Color.gray : Color.blue)
                .clipShape(.rect(cornerRadius: 8))
                .disabled(email.isEmpty || password.isEmpty || authManager.isLoading)
                
                Divider()
                    .padding(.vertical, 8)
                
                // OAuth Buttons
                VStack(spacing: 12) {
                    Button(action: {}) {
                        HStack {
                            Image(systemName: "g.circle.fill")
                                .font(.system(size: 20))
                            
                            Text("Continue with Google")
                                .font(.system(size: 16, weight: .semibold))
                            
                            Spacer()
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
                    .foregroundStyle(.primary)
                    .background(Color(.secondarySystemBackground))
                    .clipShape(.rect(cornerRadius: 8))
                    
                    Button(action: {}) {
                        HStack {
                            Image(systemName: "apple.logo")
                                .font(.system(size: 18))
                            
                            Text("Continue with Apple")
                                .font(.system(size: 16, weight: .semibold))
                            
                            Spacer()
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
                    .foregroundStyle(.primary)
                    .background(Color(.secondarySystemBackground))
                    .clipShape(.rect(cornerRadius: 8))
                }
                
                Spacer()
                
                // Sign Up Link
                HStack {
                    Text("Don't have an account?")
                        .foregroundStyle(.secondary)
                    
                    NavigationLink("Sign up") {
                        SignupView()
                    }
                    .foregroundStyle(.blue)
                }
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.bottom, 32)
            }
            .padding(.horizontal, 20)
        }
        .navigationBarTitleDisplayMode(.inline)
    }
    
    private func handleLogin() {
        Task {
            do {
                try await authManager.login(email: email, password: password)
            } catch {
                // Error is already handled in AuthManager
            }
        }
    }
}

#Preview {
    NavigationStack {
        LoginView()
            .environment(AuthManager.shared)
    }
}
