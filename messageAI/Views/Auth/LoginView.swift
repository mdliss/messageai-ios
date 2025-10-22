//
//  LoginView.swift
//  messageAI
//
//  Created by MessageAI Team
//  Login screen with email/password and Google Sign In
//

import SwiftUI

struct LoginView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @State private var email = ""
    @State private var password = ""
    @State private var showPassword = false
    @FocusState private var focusedField: Field?
    
    enum Field {
        case email, password
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Background gradient
                LinearGradient(
                    gradient: Gradient(colors: [Color.blue.opacity(0.1), Color.purple.opacity(0.1)]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        Spacer()
                            .frame(height: 60)
                        
                        // Logo and title
                        VStack(spacing: 12) {
                            Image(systemName: "message.fill")
                                .font(.system(size: 60))
                                .foregroundStyle(.blue)
                            
                            Text("MessageAI")
                                .font(.system(size: 36, weight: .bold))
                            
                            Text("intelligent messaging for remote teams")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.bottom, 40)
                        
                        // Email and password fields
                        VStack(spacing: 16) {
                            // Email field
                            HStack {
                                Image(systemName: "envelope")
                                    .foregroundStyle(.secondary)
                                    .frame(width: 20)
                                
                                TextField("email", text: $email)
                                    .textInputAutocapitalization(.never)
                                    .keyboardType(.emailAddress)
                                    .autocorrectionDisabled()
                                    .focused($focusedField, equals: .email)
                                    .submitLabel(.next)
                                    .onSubmit {
                                        focusedField = .password
                                    }
                            }
                            .padding()
                            .background(Color(.systemBackground))
                            .cornerRadius(12)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                            )
                            
                            // Password field
                            HStack {
                                Image(systemName: "lock")
                                    .foregroundStyle(.secondary)
                                    .frame(width: 20)
                                
                                if showPassword {
                                    TextField("password", text: $password)
                                        .textInputAutocapitalization(.never)
                                        .autocorrectionDisabled()
                                        .focused($focusedField, equals: .password)
                                        .submitLabel(.go)
                                        .onSubmit {
                                            handleSignIn()
                                        }
                                } else {
                                    SecureField("password", text: $password)
                                        .textInputAutocapitalization(.never)
                                        .autocorrectionDisabled()
                                        .focused($focusedField, equals: .password)
                                        .submitLabel(.go)
                                        .onSubmit {
                                            handleSignIn()
                                        }
                                }
                                
                                Button {
                                    showPassword.toggle()
                                } label: {
                                    Image(systemName: showPassword ? "eye.slash" : "eye")
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .padding()
                            .background(Color(.systemBackground))
                            .cornerRadius(12)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                            )
                        }
                        .padding(.horizontal)
                        
                        // Sign in button
                        Button {
                            handleSignIn()
                        } label: {
                            HStack {
                                if authViewModel.isLoading {
                                    ProgressView()
                                        .tint(.white)
                                } else {
                                    Text("sign in")
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(isFormValid ? Color.blue : Color.gray)
                            .foregroundStyle(.white)
                            .cornerRadius(12)
                        }
                        .disabled(!isFormValid || authViewModel.isLoading)
                        .padding(.horizontal)
                        
                        // Google Sign In - Disabled for MVP (simulator OAuth issues)
                        // TODO: Enable after testing on physical device
                        /*
                        // Divider
                        HStack {
                            Rectangle()
                                .frame(height: 1)
                                .foregroundStyle(Color.gray.opacity(0.3))
                            
                            Text("or")
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, 8)
                            
                            Rectangle()
                                .frame(height: 1)
                                .foregroundStyle(Color.gray.opacity(0.3))
                        }
                        .padding(.horizontal)
                        .padding(.vertical, 8)
                        
                        // Google Sign In
                        Button {
                            Task {
                                await authViewModel.signInWithGoogle()
                            }
                        } label: {
                            HStack {
                                Image(systemName: "globe")
                                Text("sign in with google")
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color(.systemBackground))
                            .foregroundStyle(.primary)
                            .cornerRadius(12)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                            )
                        }
                        .disabled(authViewModel.isLoading)
                        .padding(.horizontal)
                        */
                        
                        // Register link
                        NavigationLink {
                            RegisterView()
                        } label: {
                            Text("don't have an account? **sign up**")
                                .font(.subheadline)
                        }
                        .padding(.top, 8)
                        
                        Spacer()
                    }
                }
            }
            .alert("error", isPresented: .constant(authViewModel.errorMessage != nil)) {
                Button("ok") {
                    authViewModel.clearError()
                }
            } message: {
                Text(authViewModel.errorMessage ?? "")
            }
        }
    }
    
    // MARK: - Helpers
    
    private var isFormValid: Bool {
        !email.isEmpty && !password.isEmpty && email.contains("@")
    }
    
    private func handleSignIn() {
        focusedField = nil
        Task {
            await authViewModel.signIn(email: email, password: password)
        }
    }
}

#Preview {
    LoginView()
        .environmentObject(AuthViewModel())
}

