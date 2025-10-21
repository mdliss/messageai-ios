//
//  AuthViewModel.swift
//  messageAI
//
//  Created by MessageAI Team
//  ViewModel managing authentication state and operations
//

import Foundation
import SwiftUI
import Combine
import FirebaseFirestore

/// ViewModel managing authentication state
@MainActor
class AuthViewModel: ObservableObject {
    @Published var currentUser: User?
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var isAuthenticated = false
    
    private let authService = AuthService.shared
    private let realtimeDBService = RealtimeDBService.shared
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        setupAuthStateListener()
    }
    
    // MARK: - Auth State Listener
    
    /// Set up listener for authentication state changes
    private func setupAuthStateListener() {
        authService.startAuthStateListener { [weak self] user in
            Task { @MainActor in
                self?.currentUser = user
                self?.isAuthenticated = user != nil
                
                if user != nil {
                    print("✅ User authenticated: \(user?.email ?? "")")
                } else {
                    print("ℹ️ User not authenticated")
                }
            }
        }
    }
    
    // MARK: - Sign Up
    
    /// Sign up with email and password
    /// - Parameters:
    ///   - email: User email
    ///   - password: User password
    ///   - displayName: Optional display name
    func signUp(email: String, password: String, displayName: String? = nil) async {
        isLoading = true
        errorMessage = nil
        
        do {
            let user = try await authService.signUp(email: email, password: password, displayName: displayName)
            currentUser = user
            isAuthenticated = true
            print("✅ Sign up successful")
        } catch let error as AuthError {
            errorMessage = error.errorDescription
            print("❌ Sign up failed: \(error.errorDescription ?? "")")
        } catch {
            errorMessage = error.localizedDescription
            print("❌ Sign up failed: \(error.localizedDescription)")
        }
        
        isLoading = false
    }
    
    // MARK: - Sign In
    
    /// Sign in with email and password
    /// - Parameters:
    ///   - email: User email
    ///   - password: User password
    func signIn(email: String, password: String) async {
        isLoading = true
        errorMessage = nil
        
        do {
            let user = try await authService.signIn(email: email, password: password)
            currentUser = user
            isAuthenticated = true
            
            // Set user online in Realtime DB
            await realtimeDBService.setUserOnline(userId: user.id)
            
            print("✅ Sign in successful")
        } catch {
            // Firebase error handling
            if error.localizedDescription.contains("invalid-credential") || 
               error.localizedDescription.contains("wrong-password") ||
               error.localizedDescription.contains("user-not-found") {
                errorMessage = "Invalid email or password"
            } else if error.localizedDescription.contains("network") {
                errorMessage = "Network error. Please check your connection"
            } else {
                errorMessage = error.localizedDescription
            }
            print("❌ Sign in failed: \(error.localizedDescription)")
        }
        
        isLoading = false
    }
    
    // MARK: - Google Sign In
    
    /// Sign in with Google
    func signInWithGoogle() async {
        isLoading = true
        errorMessage = nil
        
        do {
            let user = try await authService.signInWithGoogle()
            currentUser = user
            isAuthenticated = true
            print("✅ Google sign in successful")
        } catch let error as AuthError {
            errorMessage = error.errorDescription
            print("❌ Google sign in failed: \(error.errorDescription ?? "")")
        } catch {
            errorMessage = "Google Sign In failed. Please try again"
            print("❌ Google sign in failed: \(error.localizedDescription)")
        }
        
        isLoading = false
    }
    
    // MARK: - Sign Out
    
    /// Sign out current user
    func signOut() {
        // Set user offline before signing out
        if let userId = currentUser?.id {
            Task {
                await realtimeDBService.setUserOffline(userId: userId)
            }
        }
        
        do {
            try authService.signOut()
            currentUser = nil
            isAuthenticated = false
            errorMessage = nil
            print("✅ Sign out successful")
        } catch {
            errorMessage = "Failed to sign out: \(error.localizedDescription)"
            print("❌ Sign out failed: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Error Handling
    
    /// Clear error message
    func clearError() {
        errorMessage = nil
    }
}

