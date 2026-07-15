import Foundation
import FirebaseAuth
import FirebaseFirestore
import CryptoKit
import GoogleSignIn
import AuthenticationServices

@Observable
@MainActor
final class AuthManager {
    static let shared = AuthManager()

    var currentUser: User?
    var isAuthenticated = false
    var isGuestSession = false
    var isLoading = false
    var errorMessage: String?

    private var db: Firestore {
        Firestore.firestore()
    }

    private init() {}

    private func derivedUsername(from email: String?) -> String {
        guard let email, !email.isEmpty else { return "" }
        return email.split(separator: "@").first.map(String.init) ?? email
    }

    private func buildUser(
        id: String,
        email: String?,
        firstName: String,
        lastName: String? = nil,
        createdAt: Date = Date(),
        usernameOverride: String? = nil
    ) -> User {
        User(
            id: id,
            username: usernameOverride ?? derivedUsername(from: email),
            firstName: firstName,
            lastName: lastName,
            email: email,
            createdAt: createdAt
        )
    }

    private func fetchOrCreateUserProfile(
        firebaseUser: FirebaseAuth.User,
        fallbackFirstName: String = "User",
        fallbackLastName: String? = nil
    ) async throws -> User {
        let snapshot = try await db.collection("users").document(firebaseUser.uid).getDocument()

        if snapshot.exists, let user = try? snapshot.data(as: User.self) {
            return user
        }

        let data = snapshot.data() ?? [:]
        let storedEmail = (data["email"] as? String) ?? firebaseUser.email
        let storedFirstName = (data["firstName"] as? String).flatMap { $0.isEmpty ? nil : $0 }
        let storedLastName = (data["lastName"] as? String).flatMap { $0.isEmpty ? nil : $0 }
        let storedUsername = (data["username"] as? String).flatMap { $0.isEmpty ? nil : $0 }

        let createdAt: Date
        if let timestamp = data["createdAt"] as? Timestamp {
            createdAt = timestamp.dateValue()
        } else {
            createdAt = Date()
        }

        let repairedUser = buildUser(
            id: firebaseUser.uid,
            email: storedEmail,
            firstName: storedFirstName ?? fallbackFirstName,
            lastName: storedLastName ?? fallbackLastName,
            createdAt: createdAt,
            usernameOverride: storedUsername
        )

        try db.collection("users").document(repairedUser.id).setData(from: repairedUser, merge: true)
        return repairedUser
    }

    // MARK: - Friendly Error Messages

    /// Maps raw Firebase/auth errors into warm, human-readable messages for the UI.
    private func friendlyMessage(for error: Error) -> String {
        let nsError = error as NSError
        if let code = AuthErrorCode(rawValue: nsError.code) {
            switch code {
            case .invalidEmail:
                return "Hmm, that email doesn't look quite right — mind double-checking it?"
            case .emailAlreadyInUse:
                return "You already have an account with this email. Try signing in instead!"
            case .weakPassword:
                return "Let's make that password a little stronger so your account stays safe."
            case .wrongPassword, .invalidCredential:
                return "That email or password didn't match. Give it another try!"
            case .userNotFound:
                return "We couldn't find an account with that email. Want to sign up?"
            case .userDisabled:
                return "This account has been disabled. Reach out to us if you think that's a mistake."
            case .networkError:
                return "Looks like you're offline. Check your connection and try again."
            case .tooManyRequests:
                return "Too many attempts for now — take a quick break and try again shortly."
            default:
                break
            }
        }
        return "Something went wrong on our end. Please try again in a moment."
    }

    // MARK: - Email/Password Authentication

    func signUp(
        firstName: String,
        lastName: String? = nil,
        email: String,
        password: String
    ) async throws {
        isLoading = true
        errorMessage = nil

        let normalizedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        do {
            let result = try await Auth.auth().createUser(withEmail: normalizedEmail, password: password)
            let user = buildUser(
                id: result.user.uid,
                email: normalizedEmail,
                firstName: firstName,
                lastName: lastName,
                usernameOverride: derivedUsername(from: normalizedEmail)
            )
            try await db.collection("users").document(user.id).setData(from: user)

            self.currentUser = user
            self.isAuthenticated = true
            self.isGuestSession = false
            isLoading = false
        } catch {
            isLoading = false
            if errorMessage == nil {
                errorMessage = friendlyMessage(for: error)
            }
            throw error
        }
    }

    func login(email: String, password: String) async throws {
        isLoading = true
        errorMessage = nil

        let normalizedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        do {
            let result = try await Auth.auth().signIn(withEmail: normalizedEmail, password: password)
            let user = try await fetchOrCreateUserProfile(
                firebaseUser: result.user,
                fallbackFirstName: result.user.displayName?.split(separator: " ").first.map(String.init) ?? "User"
            )

            self.currentUser = user
            self.isAuthenticated = true
            self.isGuestSession = false
            isLoading = false
        } catch {
            isLoading = false
            if errorMessage == nil {
                errorMessage = friendlyMessage(for: error)
            }
            throw error
        }
    }

    // MARK: - Anonymous Authentication

    func continueAsGuest() async throws {
        isLoading = true
        errorMessage = nil

        do {
            let result = try await Auth.auth().signInAnonymously()
            let guestUser = User(
                id: result.user.uid,
                username: "guest_\(result.user.uid.prefix(6))",
                firstName: "Guest"
            )

            try await db.collection("users").document(guestUser.id).setData([
                "id": guestUser.id,
                "username": guestUser.username,
                "firstName": guestUser.firstName,
                "lastName": NSNull(),
                "email": NSNull(),
                "createdAt": Timestamp(date: guestUser.createdAt),
                "isGuest": true
            ], merge: true)

            self.currentUser = guestUser
            self.isAuthenticated = true
            self.isGuestSession = true
            isLoading = false
        } catch {
            isLoading = false
            if errorMessage == nil {
                errorMessage = friendlyMessage(for: error)
            }
            throw error
        }
    }
    
    // MARK: - Google Sign-In
    
    func initiateGoogleSignIn() async throws {
        isLoading = true
        errorMessage = nil
        
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootViewController = windowScene.windows.first?.rootViewController else {
            isLoading = false
            throw NSError(domain: "AuthManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "Could not find root view controller"])
        }
        
        do {
            let result = try await GIDSignIn.sharedInstance.signIn(withPresenting: rootViewController)
            guard let idToken = result.user.idToken?.tokenString else {
                isLoading = false
                throw NSError(domain: "AuthManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "Could not get ID Token"])
            }
            
            let accessToken = result.user.accessToken.tokenString
            
            try await signInWithGoogle(idToken: idToken, accessToken: accessToken)
        } catch {
            isLoading = false
            errorMessage = friendlyMessage(for: error)
            throw error
        }
    }
    
    func signInWithGoogle(idToken: String, accessToken: String, firstName: String = "", lastName: String = "") async throws {
        isLoading = true
        errorMessage = nil
        
        do {
            let credential = GoogleAuthProvider.credential(withIDToken: idToken, accessToken: accessToken)
            let result = try await Auth.auth().signIn(with: credential)

            let names = (result.user.displayName ?? "").split(separator: " ")
            let first = firstName.isEmpty ? String(names.first ?? "") : firstName
            let last = lastName.isEmpty ? String(names.dropFirst().joined(separator: " ")) : lastName
            let user = try await fetchOrCreateUserProfile(
                firebaseUser: result.user,
                fallbackFirstName: first.isEmpty ? "User" : first,
                fallbackLastName: last.isEmpty ? nil : last
            )

            self.currentUser = user
            self.isGuestSession = false
            self.isAuthenticated = true
            isLoading = false
        } catch {
            isLoading = false
            errorMessage = friendlyMessage(for: error)
            throw error
        }
    }
    
    // MARK: - Apple Sign-In
    
    func initiateAppleSignIn() async throws {
        isLoading = true
        errorMessage = nil
        
        do {
            let coordinator = AppleSignInCoordinator()
            let result = try await coordinator.startSignIn()
            try await signInWithApple(result: result)
        } catch {
            isLoading = false
            errorMessage = friendlyMessage(for: error)
            throw error
        }
    }
    
    private func signInWithApple(result: AppleSignInResult) async throws {
        let credential = result.credential
        
        guard let appleIDToken = credential.identityToken,
              let idTokenString = String(data: appleIDToken, encoding: .utf8) else {
            isLoading = false
            let error = AuthError.credentialError
            errorMessage = friendlyMessage(for: error)
            throw error
        }
        
        let appleCredential = OAuthProvider.appleCredential(
            withIDToken: idTokenString,
            rawNonce: result.nonce,
            fullName: credential.fullName
        )
        
        if let firebaseUser: FirebaseAuth.User = Auth.auth().currentUser, !firebaseUser.isAnonymous {
            do {
                let linkedResult = try await firebaseUser.link(with: appleCredential)
                let user = try await fetchOrCreateUserProfile(firebaseUser: linkedResult.user)
                self.currentUser = user
                self.isGuestSession = false
                self.isAuthenticated = true
                isLoading = false
                return
            } catch let error as NSError {
                if let authError = AuthErrorCode(rawValue: error.code) {
                    switch authError {
                    case .credentialAlreadyInUse:
                        errorMessage = "This Apple account is already linked to another account."
                    case .invalidCredential:
                        errorMessage = "The Apple credential is invalid."
                    default:
                        errorMessage = "Unable to link Apple account: \(error.localizedDescription)"
                    }
                }
                isLoading = false
                throw error
            }
        }
        
        do {
            let result = try await Auth.auth().signIn(with: appleCredential)
            let fullName = credential.fullName
            let firstName = [fullName?.givenName, fullName?.familyName]
                .compactMap { $0 }
                .filter { !$0.isEmpty }
                .first ?? "User"
            let lastName = fullName?.familyName
            
            let user = try await fetchOrCreateUserProfile(
                firebaseUser: result.user,
                fallbackFirstName: firstName,
                fallbackLastName: lastName
            )
            
            self.currentUser = user
            self.isGuestSession = false
            self.isAuthenticated = true
            isLoading = false
        } catch {
            isLoading = false
            errorMessage = friendlyMessage(for: error)
            throw error
        }
    }
    
    // MARK: - Session Management
    
    func checkAuthenticationState() async {
        if let firebaseUser = Auth.auth().currentUser {
            if firebaseUser.isAnonymous {
                do {
                    let snapshot = try await db.collection("users").document(firebaseUser.uid).getDocument()

                    if snapshot.exists, let user = try? snapshot.data(as: User.self) {
                        self.currentUser = user
                    } else {
                        let guestUser = User(
                            id: firebaseUser.uid,
                            username: "guest_\(firebaseUser.uid.prefix(6))",
                            firstName: "Guest"
                        )

                        try await db.collection("users").document(guestUser.id).setData([
                            "id": guestUser.id,
                            "username": guestUser.username,
                            "firstName": guestUser.firstName,
                            "lastName": NSNull(),
                            "email": NSNull(),
                            "createdAt": Timestamp(date: guestUser.createdAt),
                            "isGuest": true
                        ], merge: true)

                        self.currentUser = guestUser
                    }

                    self.isAuthenticated = true
                    self.isGuestSession = true
                    self.errorMessage = nil
                } catch {
                    errorMessage = friendlyMessage(for: error)
                    self.isAuthenticated = false
                    self.currentUser = nil
                    self.isGuestSession = false
                }
                return
            }

            do {
                let names = (firebaseUser.displayName ?? "").split(separator: " ")
                let user = try await fetchOrCreateUserProfile(
                    firebaseUser: firebaseUser,
                    fallbackFirstName: String(names.first ?? "User"),
                    fallbackLastName: names.dropFirst().isEmpty ? nil : String(names.dropFirst().joined(separator: " "))
                )
                self.currentUser = user
                self.isAuthenticated = true
                self.isGuestSession = false
                self.errorMessage = nil
            } catch {
                errorMessage = friendlyMessage(for: error)
                self.isAuthenticated = false
                self.currentUser = nil
                self.isGuestSession = false
            }
        } else {
            self.isAuthenticated = false
            self.currentUser = nil
            self.isGuestSession = false
        }
    }
    
    func logout() throws {
        do {
            try Auth.auth().signOut()
            self.currentUser = nil
            self.isAuthenticated = false
            self.isGuestSession = false
            self.errorMessage = nil
        } catch {
            errorMessage = friendlyMessage(for: error)
            throw error
        }
    }
    
    func clearError() {
        errorMessage = nil
    }
}
