import Foundation
import FirebaseAuth
import FirebaseFirestore
import CryptoKit
import GoogleSignIn

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

    // MARK: - Username/Password Authentication

    /// Signs up a new user with a unique username.
    /// Firebase Auth requires an email, so we use the synthetic address
    /// `{username}@korah.app` internally. The user's real email (if provided)
    /// is stored only in the private `users/{uid}` document.
    func signUp(
        username: String,
        firstName: String,
        lastName: String? = nil,
        email: String? = nil,
        password: String
    ) async throws {
        isLoading = true
        errorMessage = nil

        let normalizedUsername = username.lowercased()
        let authEmail = "\(normalizedUsername)@korah.app"

        do {
            // 1. Check username availability (pre-auth read — allowed by rules).
            let usernameDoc = try await db
                .collection("usernames")
                .document(normalizedUsername)
                .getDocument()

            if usernameDoc.exists {
                isLoading = false
                let usernameError = NSError(
                    domain: "AuthManager",
                    code: -1,
                    userInfo: [NSLocalizedDescriptionKey: "That username is already taken."]
                )
                errorMessage = usernameError.localizedDescription
                throw usernameError
            }

            // 2. Create Firebase Auth account using the synthetic email.
            let result = try await Auth.auth().createUser(withEmail: authEmail, password: password)

            // 3. Reserve the username (create is blocked by rules if the doc already exists).
            try await db.collection("usernames").document(normalizedUsername).setData([
                "uid": result.user.uid,
                "authEmail": authEmail
            ])

            // 4. Write the user profile.
            let user = User(
                id: result.user.uid,
                username: normalizedUsername,
                firstName: firstName,
                lastName: lastName,
                email: email
            )
            try await db.collection("users").document(user.id).setData(from: user)

            self.currentUser = user
            self.isAuthenticated = true
            self.isGuestSession = false
            isLoading = false
        } catch {
            isLoading = false
            if errorMessage == nil {
                errorMessage = error.localizedDescription
            }
            throw error
        }
    }

    /// Signs in using a username and password.
    /// Resolves the username to the internal synthetic auth email, then
    /// authenticates with Firebase Auth.
    func login(username: String, password: String) async throws {
        isLoading = true
        errorMessage = nil

        let normalizedUsername = username.lowercased()

        do {
            // 1. Look up the auth email for this username.
            let usernameDoc = try await db
                .collection("usernames")
                .document(normalizedUsername)
                .getDocument()

            guard usernameDoc.exists,
                  let authEmail = usernameDoc.data()?["authEmail"] as? String else {
                let notFoundError = NSError(
                    domain: "AuthManager",
                    code: -1,
                    userInfo: [NSLocalizedDescriptionKey: "No account found for that username."]
                )
                isLoading = false
                errorMessage = notFoundError.localizedDescription
                throw notFoundError
            }

            // 2. Sign in with Firebase Auth.
            let result = try await Auth.auth().signIn(withEmail: authEmail, password: password)

            // 3. Fetch the user profile.
            let snapshot = try await db
                .collection("users")
                .document(result.user.uid)
                .getDocument()
            let user = try snapshot.data(as: User.self)

            self.currentUser = user
            self.isAuthenticated = true
            self.isGuestSession = false
            isLoading = false
        } catch {
            isLoading = false
            if errorMessage == nil {
                errorMessage = error.localizedDescription
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
                errorMessage = error.localizedDescription
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
            errorMessage = error.localizedDescription
            throw error
        }
    }
    
    func signInWithGoogle(idToken: String, accessToken: String, firstName: String = "", lastName: String = "") async throws {
        isLoading = true
        errorMessage = nil
        
        do {
            let credential = GoogleAuthProvider.credential(withIDToken: idToken, accessToken: accessToken)
            let result = try await Auth.auth().signIn(with: credential)
            
            // Check if user exists in Firestore
            let snapshot = try await db.collection("users").document(result.user.uid).getDocument()
            
            if snapshot.exists {
                let user = try snapshot.data(as: User.self)
                self.currentUser = user
                self.isGuestSession = false
            } else {
                // Create new user profile
                let names = (result.user.displayName ?? "").split(separator: " ")
                let first = firstName.isEmpty ? String(names.first ?? "") : firstName
                let last = lastName.isEmpty ? String(names.dropFirst().joined(separator: " ")) : lastName
                
                let user = User(
                    id: result.user.uid,
                    username: "",
                    firstName: first.isEmpty ? "User" : first,
                    lastName: last.isEmpty ? nil : last,
                    email: result.user.email
                )
                
                try db.collection("users").document(user.id).setData(from: user)
                self.currentUser = user
                self.isGuestSession = false
            }
            
            self.isAuthenticated = true
            isLoading = false
        } catch {
            isLoading = false
            errorMessage = error.localizedDescription
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
                    errorMessage = error.localizedDescription
                    self.isAuthenticated = false
                    self.currentUser = nil
                    self.isGuestSession = false
                }
                return
            }

            do {
                let snapshot = try await db.collection("users").document(firebaseUser.uid).getDocument()
                let user = try snapshot.data(as: User.self)
                self.currentUser = user
                self.isAuthenticated = true
                self.isGuestSession = false
                self.errorMessage = nil
            } catch {
                errorMessage = error.localizedDescription
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
            errorMessage = error.localizedDescription
            throw error
        }
    }
    
    func clearError() {
        errorMessage = nil
    }
}
