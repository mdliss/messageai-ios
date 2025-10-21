//
//  ProfileView.swift
//  messageAI
//
//  Created by MessageAI Team
//  User profile screen with settings
//

import SwiftUI

struct ProfileView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @State private var showSignOutConfirmation = false
    
    var body: some View {
        NavigationStack {
            List {
                // User info section
                Section {
                    HStack(spacing: 16) {
                        // Avatar
                        if let photoURL = authViewModel.currentUser?.photoURL,
                           let url = URL(string: photoURL) {
                            AsyncImage(url: url) { image in
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                            } placeholder: {
                                Circle()
                                    .fill(Color.blue.opacity(0.3))
                                    .overlay {
                                        Text(authViewModel.currentUser?.displayName.prefix(1).uppercased() ?? "U")
                                            .font(.title)
                                            .foregroundStyle(.white)
                                    }
                            }
                            .frame(width: 60, height: 60)
                            .clipShape(Circle())
                        } else {
                            Circle()
                                .fill(Color.blue.opacity(0.3))
                                .frame(width: 60, height: 60)
                                .overlay {
                                    Text(authViewModel.currentUser?.displayName.prefix(1).uppercased() ?? "U")
                                        .font(.title)
                                        .foregroundStyle(.white)
                                }
                        }
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text(authViewModel.currentUser?.displayName ?? "user")
                                .font(.headline)
                            
                            Text(authViewModel.currentUser?.email ?? "")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 8)
                }
                
                // Settings section
                Section("settings") {
                    HStack {
                        Image(systemName: "sparkles")
                            .foregroundStyle(.purple)
                        Text("ai features")
                        Spacer()
                        Text("enabled")
                            .foregroundStyle(.secondary)
                    }
                    
                    Button {
                        // Open iOS Settings app for this app
                        if let appSettings = URL(string: UIApplication.openSettingsURLString) {
                            UIApplication.shared.open(appSettings)
                        }
                    } label: {
                        HStack {
                            Image(systemName: "bell.badge")
                                .foregroundStyle(.orange)
                            Text("notifications")
                            Spacer()
                            Image(systemName: "chevron.right")
                                .foregroundStyle(.secondary)
                                .font(.caption)
                        }
                    }
                    .buttonStyle(.plain)
                }
                
                // About section
                Section("about") {
                    HStack {
                        Image(systemName: "info.circle")
                            .foregroundStyle(.blue)
                        Text("version")
                        Spacer()
                        Text("1.0.0")
                            .foregroundStyle(.secondary)
                    }
                    
                    HStack {
                        Image(systemName: "doc.text")
                            .foregroundStyle(.blue)
                        Text("privacy policy")
                        Spacer()
                        Image(systemName: "chevron.right")
                            .foregroundStyle(.secondary)
                            .font(.caption)
                    }
                    
                    HStack {
                        Image(systemName: "doc.plaintext")
                            .foregroundStyle(.blue)
                        Text("terms of service")
                        Spacer()
                        Image(systemName: "chevron.right")
                            .foregroundStyle(.secondary)
                            .font(.caption)
                    }
                }
                
                // Sign out section
                Section {
                    Button(role: .destructive) {
                        showSignOutConfirmation = true
                    } label: {
                        HStack {
                            Image(systemName: "rectangle.portrait.and.arrow.right")
                            Text("sign out")
                        }
                        .frame(maxWidth: .infinity, alignment: .center)
                    }
                }
            }
            .navigationTitle("profile")
            .confirmationDialog("sign out", isPresented: $showSignOutConfirmation) {
                Button("sign out", role: .destructive) {
                    authViewModel.signOut()
                }
                Button("cancel", role: .cancel) {}
            } message: {
                Text("are you sure you want to sign out?")
            }
        }
    }
}

#Preview {
    ProfileView()
        .environmentObject(AuthViewModel())
}

