//
//  AuthService.swift
//  messageAI
//
//  Created by MessageAI Team
//  Authentication service using Firebase Auth
//

import Foundation
import FirebaseAuth
import FirebaseFirestore
import FirebaseCore
import GoogleSignIn

/// Authentication service handling all user authentication operations
class AuthService {
    static let shared = AuthService()
    
    private let auth: Auth
    private let db: Firestore
    private var authStateListener: AuthStateDidChangeListenerHandle?
    
    /// Current Firebase user
    var currentFirebaseUser: FirebaseAuth.User? {
        return auth.currentUser
    }
    
    /// Current user ID
    var currentUserId: String? {
        return auth.currentUser?.uid
    }
    
    private init() {
        self.auth = FirebaseConfig.shared.auth
        self.db = FirebaseConfig.shared.db
    }
    
    // MARK: - Auth State Listener
    
    /// Start listening to authentication state changes
    /// - Parameter completion: Callback with User or nil
    func startAuthStateListener(completion: @escaping (User?) -> Void) {
        authStateListener = auth.addStateDidChangeListener { [weak self] _, firebaseUser in
            guard let self = self else { return }
            
            if let firebaseUser = firebaseUser {
                // User is signed in, fetch full profile
                Task {
                    do {
                        let user = try await self.getUser(userId: firebaseUser.uid)
                        completion(user)
                    } catch {
                        print("❌ Error fetching user profile: \(error.localizedDescription)")
                        // Fall back to creating user from Firebase Auth
                        let user = User(from: firebaseUser)
                        completion(user)
                    }
                }
            } else {
                // User is signed out
                completion(nil)
            }
        }
    }
    
    /// Stop listening to auth state changes
    func stopAuthStateListener() {
        if let listener = authStateListener {
            auth.removeStateDidChangeListener(listener)
            authStateListener = nil
        }
    }
    
    // MARK: - Sign Up
    
    /// Sign up with email and password
    /// - Parameters:
    ///   - email: User email
    ///   - password: User password (min 8 characters)
    ///   - displayName: Optional display name
    /// - Returns: Created User
    func signUp(email: String, password: String, displayName: String? = nil) async throws -> User {
        // Validate password length
        guard password.count >= 8 else {
            throw AuthError.weakPassword
        }
        
        // Create Firebase Auth user
        let authResult = try await auth.createUser(withEmail: email, password: password)
        
        // Update profile with display name
        let changeRequest = authResult.user.createProfileChangeRequest()
        changeRequest.displayName = displayName ?? User.generateDisplayName(from: email)
        try await changeRequest.commitChanges()
        
        // Reload user to get updated profile
        try await authResult.user.reload()
        
        // Create User object
        let user = User(from: authResult.user)
        
        // Create user profile in Firestore
        try await createUserProfile(user: user)
        
        print("✅ User signed up successfully: \(user.email)")
        return user
    }
    
    // MARK: - Sign In
    
    /// Sign in with email and password
    /// - Parameters:
    ///   - email: User email
    ///   - password: User password
    /// - Returns: Signed in User
    func signIn(email: String, password: String) async throws -> User {
        let authResult = try await auth.signIn(withEmail: email, password: password)
        
        // Get user profile from Firestore
        let user = try await getUser(userId: authResult.user.uid)
        
        // Update online status
        try await updateUserOnlineStatus(userId: user.id, isOnline: true)
        
        print("✅ User signed in successfully: \(user.email)")
        return user
    }
    
    // MARK: - Google Sign In
    
    /// Sign in with Google
    /// - Returns: Signed in User
    func signInWithGoogle() async throws -> User {
        // Get the client ID from Firebase config
        guard let clientID = FirebaseApp.app()?.options.clientID else {
            throw AuthError.googleSignInFailed
        }
        
        // Configure Google Sign In
        let config = GIDConfiguration(clientID: clientID)
        GIDSignIn.sharedInstance.configuration = config
        
        // Get the root view controller
        guard let windowScene = await UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootViewController = await windowScene.windows.first?.rootViewController else {
            throw AuthError.googleSignInFailed
        }
        
        // Start Google Sign In flow
        let result = try await GIDSignIn.sharedInstance.signIn(withPresenting: rootViewController)
        
        guard let idToken = result.user.idToken?.tokenString else {
            throw AuthError.googleSignInFailed
        }
        
        let accessToken = result.user.accessToken.tokenString
        
        // Create Firebase credential
        let credential = GoogleAuthProvider.credential(withIDToken: idToken, accessToken: accessToken)
        
        // Sign in with Firebase
        let authResult = try await auth.signIn(with: credential)
        
        // Check if user already exists
        let userExists = try await checkUserExists(userId: authResult.user.uid)
        
        let user = User(from: authResult.user)
        
        if !userExists {
            // Create new user profile
            try await createUserProfile(user: user)
        } else {
            // Update online status
            try await updateUserOnlineStatus(userId: user.id, isOnline: true)
        }
        
        print("✅ User signed in with Google: \(user.email)")
        return user
    }
    
    // MARK: - Sign Out
    
    /// Sign out current user
    func signOut() throws {
        guard let userId = currentUserId else {
            throw AuthError.notAuthenticated
        }
        
        // Update online status before signing out
        Task {
            try? await updateUserOnlineStatus(userId: userId, isOnline: false)
        }
        
        // Sign out from Firebase
        try auth.signOut()
        
        // Sign out from Google
        GIDSignIn.sharedInstance.signOut()
        
        print("✅ User signed out successfully")
    }
    
    // MARK: - Firestore Operations
    
    /// Create user profile in Firestore
    /// - Parameter user: User to create
    func createUserProfile(user: User) async throws {
        let userRef = db.collection("users").document(user.id)
        try await userRef.setData(user.toDictionary())
        print("✅ User profile created in Firestore: \(user.id)")
    }
    
    /// Get user from Firestore
    /// - Parameter userId: User ID
    /// - Returns: User object
    func getUser(userId: String) async throws -> User {
        let userRef = db.collection("users").document(userId)
        let document = try await userRef.getDocument()
        
        guard document.exists else {
            throw AuthError.userNotFound
        }
        
        let user = try document.data(as: User.self)
        return user
    }
    
    /// Check if user exists in Firestore
    /// - Parameter userId: User ID
    /// - Returns: True if user exists
    func checkUserExists(userId: String) async throws -> Bool {
        let userRef = db.collection("users").document(userId)
        let document = try await userRef.getDocument()
        return document.exists
    }
    
    /// Update user online status
    /// - Parameters:
    ///   - userId: User ID
    ///   - isOnline: Online status
    func updateUserOnlineStatus(userId: String, isOnline: Bool) async throws {
        let userRef = db.collection("users").document(userId)
        try await userRef.updateData([
            "isOnline": isOnline,
            "lastSeen": Date()
        ])
    }
    
    /// Update FCM token
    /// - Parameters:
    ///   - userId: User ID
    ///   - token: FCM token
    func updateFCMToken(userId: String, token: String) async throws {
        let userRef = db.collection("users").document(userId)
        try await userRef.updateData([
            "fcmToken": token
        ])
        print("✅ FCM token updated for user: \(userId)")
    }
}

// MARK: - Auth Errors

enum AuthError: LocalizedError {
    case weakPassword
    case googleSignInFailed
    case notAuthenticated
    case userNotFound
    case invalidCredentials
    
    var errorDescription: String? {
        switch self {
        case .weakPassword:
            return "Password must be at least 8 characters long"
        case .googleSignInFailed:
            return "Google Sign In failed. Please try again"
        case .notAuthenticated:
            return "You must be signed in to perform this action"
        case .userNotFound:
            return "User not found"
        case .invalidCredentials:
            return "Invalid email or password"
        }
    }
}

