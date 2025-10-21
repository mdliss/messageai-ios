//
//  RegisterView.swift
//  messageAI
//
//  Created by MessageAI Team
//  Registration screen for new users
//

import SwiftUI

struct RegisterView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @Environment(\.dismiss) var dismiss
    
    @State private var displayName = ""
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var showPassword = false
    @State private var showConfirmPassword = false
    @FocusState private var focusedField: Field?
    
    enum Field {
        case displayName, email, password, confirmPassword
    }
    
    var body: some View {
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
                        .frame(height: 40)
                    
                    // Title
                    VStack(spacing: 8) {
                        Text("create account")
                            .font(.system(size: 32, weight: .bold))
                        
                        Text("join messageai to collaborate with your team")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.bottom, 20)
                    
                    // Form fields
                    VStack(spacing: 16) {
                        // Display name
                        HStack {
                            Image(systemName: "person")
                                .foregroundStyle(.secondary)
                                .frame(width: 20)
                            
                            TextField("display name (optional)", text: $displayName)
                                .textInputAutocapitalization(.words)
                                .focused($focusedField, equals: .displayName)
                                .submitLabel(.next)
                                .onSubmit {
                                    focusedField = .email
                                }
                        }
                        .padding()
                        .background(Color(.systemBackground))
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                        )
                        
                        // Email
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
                        
                        // Password
                        HStack {
                            Image(systemName: "lock")
                                .foregroundStyle(.secondary)
                                .frame(width: 20)
                            
                            if showPassword {
                                TextField("password (min 8 characters)", text: $password)
                                    .textInputAutocapitalization(.never)
                                    .autocorrectionDisabled()
                                    .focused($focusedField, equals: .password)
                                    .submitLabel(.next)
                                    .onSubmit {
                                        focusedField = .confirmPassword
                                    }
                            } else {
                                SecureField("password (min 8 characters)", text: $password)
                                    .textInputAutocapitalization(.never)
                                    .autocorrectionDisabled()
                                    .focused($focusedField, equals: .password)
                                    .submitLabel(.next)
                                    .onSubmit {
                                        focusedField = .confirmPassword
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
                                .stroke(passwordFieldBorderColor, lineWidth: 1)
                        )
                        
                        // Confirm password
                        HStack {
                            Image(systemName: "lock.fill")
                                .foregroundStyle(.secondary)
                                .frame(width: 20)
                            
                            if showConfirmPassword {
                                TextField("confirm password", text: $confirmPassword)
                                    .textInputAutocapitalization(.never)
                                    .autocorrectionDisabled()
                                    .focused($focusedField, equals: .confirmPassword)
                                    .submitLabel(.go)
                                    .onSubmit {
                                        handleRegister()
                                    }
                            } else {
                                SecureField("confirm password", text: $confirmPassword)
                                    .textInputAutocapitalization(.never)
                                    .autocorrectionDisabled()
                                    .focused($focusedField, equals: .confirmPassword)
                                    .submitLabel(.go)
                                    .onSubmit {
                                        handleRegister()
                                    }
                            }
                            
                            Button {
                                showConfirmPassword.toggle()
                            } label: {
                                Image(systemName: showConfirmPassword ? "eye.slash" : "eye")
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding()
                        .background(Color(.systemBackground))
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(confirmPasswordFieldBorderColor, lineWidth: 1)
                        )
                    }
                    .padding(.horizontal)
                    
                    // Validation messages
                    if !password.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            ValidationRow(
                                isValid: password.count >= 8,
                                text: "at least 8 characters"
                            )
                            
                            if !confirmPassword.isEmpty {
                                ValidationRow(
                                    isValid: password == confirmPassword,
                                    text: "passwords match"
                                )
                            }
                        }
                        .padding(.horizontal)
                        .font(.caption)
                    }
                    
                    // Sign up button
                    Button {
                        handleRegister()
                    } label: {
                        HStack {
                            if authViewModel.isLoading {
                                ProgressView()
                                    .tint(.white)
                            } else {
                                Text("sign up")
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
                    .padding(.top, 8)
                    
                    Spacer()
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .alert("error", isPresented: .constant(authViewModel.errorMessage != nil)) {
            Button("ok") {
                authViewModel.clearError()
            }
        } message: {
            Text(authViewModel.errorMessage ?? "")
        }
        .onChange(of: authViewModel.isAuthenticated) { _, isAuthenticated in
            if isAuthenticated {
                dismiss()
            }
        }
    }
    
    // MARK: - Helpers
    
    private var isFormValid: Bool {
        !email.isEmpty &&
        email.contains("@") &&
        password.count >= 8 &&
        password == confirmPassword
    }
    
    private var passwordFieldBorderColor: Color {
        if password.isEmpty {
            return Color.gray.opacity(0.2)
        }
        return password.count >= 8 ? Color.green.opacity(0.5) : Color.red.opacity(0.5)
    }
    
    private var confirmPasswordFieldBorderColor: Color {
        if confirmPassword.isEmpty {
            return Color.gray.opacity(0.2)
        }
        return password == confirmPassword ? Color.green.opacity(0.5) : Color.red.opacity(0.5)
    }
    
    private func handleRegister() {
        focusedField = nil
        Task {
            await authViewModel.signUp(
                email: email,
                password: password,
                displayName: displayName.isEmpty ? nil : displayName
            )
        }
    }
}

// MARK: - Validation Row

struct ValidationRow: View {
    let isValid: Bool
    let text: String
    
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: isValid ? "checkmark.circle.fill" : "xmark.circle.fill")
                .foregroundStyle(isValid ? .green : .red)
                .font(.caption)
            
            Text(text)
                .foregroundStyle(isValid ? .green : .red)
        }
    }
}

#Preview {
    NavigationStack {
        RegisterView()
            .environmentObject(AuthViewModel())
    }
}

