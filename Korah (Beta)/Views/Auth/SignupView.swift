import SwiftUI

struct SignupView: View {
    @State private var firstName = ""
    @State private var lastName = ""
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @Environment(AuthManager.self) private var authManager
    @Environment(\.dismiss) private var dismiss
    @FocusState private var focusedField: Field?
    
    enum Field {
        case firstName
        case lastName
        case email
        case password
        case confirmPassword
    }
    
    private var isPasswordValid: Bool {
        password.count >= 8 && password == confirmPassword
    }
    
    private var isFormValid: Bool {
        !firstName.isEmpty && !lastName.isEmpty && !email.isEmpty && isPasswordValid && email.contains("@")
    }
    
    var body: some View {
        ZStack {
            Color(.systemBackground)
                .ignoresSafeArea()
            
            VStack(spacing: 24) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Create Account")
                        .font(.system(size: 32, weight: .bold))
                    
                    Text("Join us to get started")
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, 24)
                
                ScrollView {
                    VStack(spacing: 16) {
                        // First Name
                        VStack(alignment: .leading, spacing: 6) {
                            Text("First Name")
                                .font(.system(size: 14, weight: .semibold))
                            
                            TextField("John", text: $firstName)
                                .focused($focusedField, equals: .firstName)
                                .padding(12)
                                .background(Color(.secondarySystemBackground))
                                .clipShape(.rect(cornerRadius: 8))
                        }
                        
                        // Last Name
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Last Name")
                                .font(.system(size: 14, weight: .semibold))
                            
                            TextField("Doe", text: $lastName)
                                .focused($focusedField, equals: .lastName)
                                .padding(12)
                                .background(Color(.secondarySystemBackground))
                                .clipShape(.rect(cornerRadius: 8))
                        }
                        
                        // Email
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
                        
                        // Password
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Password")
                                .font(.system(size: 14, weight: .semibold))
                            
                            SecureField("••••••••", text: $password)
                                .focused($focusedField, equals: .password)
                                .padding(12)
                                .background(Color(.secondarySystemBackground))
                                .clipShape(.rect(cornerRadius: 8))
                            
                            if !password.isEmpty {
                                Text(password.count >= 8 ? "✓ At least 8 characters" : "⚠ At least 8 characters required")
                                    .font(.system(size: 12))
                                    .foregroundStyle(password.count >= 8 ? .green : .orange)
                            }
                        }
                        
                        // Confirm Password
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Confirm Password")
                                .font(.system(size: 14, weight: .semibold))
                            
                            SecureField("••••••••", text: $confirmPassword)
                                .focused($focusedField, equals: .confirmPassword)
                                .padding(12)
                                .background(Color(.secondarySystemBackground))
                                .clipShape(.rect(cornerRadius: 8))
                            
                            if !confirmPassword.isEmpty && password != confirmPassword {
                                Text("⚠ Passwords do not match")
                                    .font(.system(size: 12))
                                    .foregroundStyle(.orange)
                            }
                        }
                    }
                    .padding(.bottom, 16)
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
                
                // Sign Up Button
                Button(action: handleSignup) {
                    if authManager.isLoading {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Text("Create Account")
                            .font(.system(size: 16, weight: .semibold))
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 44)
                .foregroundStyle(.white)
                .background(!isFormValid || authManager.isLoading ? Color.gray : Color.blue)
                .clipShape(.rect(cornerRadius: 8))
                .disabled(!isFormValid || authManager.isLoading)
                
                Divider()
                    .padding(.vertical, 8)
                
                // OAuth Buttons
                VStack(spacing: 12) {
                    Button(action: handleGoogleSignIn) {
                        HStack {
                            Image(systemName: "g.circle.fill")
                                .font(.system(size: 20))
                            
                            Text("Sign up with Google")
                                .font(.system(size: 16, weight: .semibold))
                            
                            Spacer()
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
                    .foregroundStyle(.primary)
                    .background(Color(.secondarySystemBackground))
                    .clipShape(.rect(cornerRadius: 8))
                    .disabled(authManager.isLoading)
                }
                
                Spacer()
                
                // Login Link
                HStack {
                    Text("Already have an account?")
                        .foregroundStyle(.secondary)
                    
                    Button("Sign in") {
                        dismiss()
                    }
                    .foregroundStyle(.blue)
                }
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.bottom, 24)
            }
            .padding(.horizontal, 20)
        }
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(false)
    }
    
    private func handleSignup() {
        Task {
            do {
                try await authManager.signUp(
                    firstName: firstName,
                    lastName: lastName,
                    email: email,
                    password: password
                )
            } catch {
                // Error is already handled in AuthManager
            }
        }
    }
    
    private func handleGoogleSignIn() {
        Task {
            do {
                try await authManager.initiateGoogleSignIn()
            } catch {
                // Error is already handled in AuthManager
            }
        }
    }
}

#Preview {
    NavigationStack {
        SignupView()
            .environment(AuthManager.shared)
    }
}
