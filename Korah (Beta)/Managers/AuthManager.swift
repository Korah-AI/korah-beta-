import Foundation
import FirebaseAuth
import FirebaseFirestore
import CryptoKit

@Observable
@MainActor
final class AuthManager {
    static let shared = AuthManager()
    
    var currentUser: User?
    var isAuthenticated = false
    var isLoading = false
    var errorMessage: String?
    
    private var db: Firestore {
        Firestore.firestore()
    }
    
    private init() {}
    
    // MARK: - Email/Password Authentication
    
    func signUp(firstName: String, lastName: String, email: String, password: String) async throws {
        isLoading = true
        errorMessage = nil
        
        do {
            // Create Firebase Auth user
            let result = try await Auth.auth().createUser(withEmail: email, password: password)
            
            // Create user profile in Firestore
            let user = User(
                id: result.user.uid,
                firstName: firstName,
                lastName: lastName,
                email: email,
                createdAt: Date()
            )
            
            try db.collection("users").document(user.id).setData(from: user)
            
            self.currentUser = user
            self.isAuthenticated = true
            isLoading = false
        } catch {
            isLoading = false
            errorMessage = error.localizedDescription
            throw error
        }
    }
    
    func login(email: String, password: String) async throws {
        isLoading = true
        errorMessage = nil
        
        do {
            let result = try await Auth.auth().signIn(withEmail: email, password: password)
            
            // Fetch user profile from Firestore
            let snapshot = try await db.collection("users").document(result.user.uid).getDocument()
            let user = try snapshot.data(as: User.self)
            
            self.currentUser = user
            self.isAuthenticated = true
            isLoading = false
        } catch {
            isLoading = false
            errorMessage = error.localizedDescription
            throw error
        }
    }
    
    // MARK: - Google Sign-In
    
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
            } else {
                // Create new user profile
                let names = (result.user.displayName ?? "").split(separator: " ")
                let first = firstName.isEmpty ? String(names.first ?? "") : firstName
                let last = lastName.isEmpty ? String(names.dropFirst().joined(separator: " ")) : lastName
                
                let user = User(
                    id: result.user.uid,
                    firstName: first.isEmpty ? "User" : first,
                    lastName: last,
                    email: result.user.email ?? "",
                    createdAt: Date()
                )
                
                try db.collection("users").document(user.id).setData(from: user)
                self.currentUser = user
            }
            
            self.isAuthenticated = true
            isLoading = false
        } catch {
            isLoading = false
            errorMessage = error.localizedDescription
            throw error
        }
    }
    
    // MARK: - Apple Sign-In
    
    func signInWithApple(identityToken: Data, nonce: String, firstName: String = "", lastName: String = "") async throws {
        isLoading = true
        errorMessage = nil
        
        do {
            let tokenString = String(data: identityToken, encoding: .utf8) ?? ""
            let credential = OAuthProvider.appleCredential(
                withIDToken: tokenString,
                rawNonce: nonce,
                fullName: nil
            )
            
            let result = try await Auth.auth().signIn(with: credential)
            
            // Check if user exists in Firestore
            let snapshot = try await db.collection("users").document(result.user.uid).getDocument()
            
            if snapshot.exists {
                let user = try snapshot.data(as: User.self)
                self.currentUser = user
            } else {
                // Create new user profile
                let user = User(
                    id: result.user.uid,
                    firstName: firstName.isEmpty ? "User" : firstName,
                    lastName: lastName,
                    email: result.user.email ?? "",
                    createdAt: Date()
                )
                
                try db.collection("users").document(user.id).setData(from: user)
                self.currentUser = user
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
            do {
                let snapshot = try await db.collection("users").document(firebaseUser.uid).getDocument()
                let user = try snapshot.data(as: User.self)
                self.currentUser = user
                self.isAuthenticated = true
            } catch {
                errorMessage = error.localizedDescription
                self.isAuthenticated = false
            }
        } else {
            self.isAuthenticated = false
            self.currentUser = nil
        }
    }
    
    func logout() throws {
        do {
            try Auth.auth().signOut()
            self.currentUser = nil
            self.isAuthenticated = false
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
