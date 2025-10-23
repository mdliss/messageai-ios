//
//  ProfileView.swift
//  messageAI
//
//  Created by MessageAI Team
//  User profile screen with settings
//

import SwiftUI
import FirebaseFirestore

struct ProfileView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @State private var showSignOutConfirmation = false
    @State private var showAvatarSelection = false
    @State private var showNameEditor = false
    @State private var editedName = ""
    @StateObject private var editViewModel = ProfileEditingViewModel()
    @State private var userListener: ListenerRegistration?
    
    private let db = FirebaseConfig.shared.db
    
    var body: some View {
        NavigationStack {
            List {
                // User info section
                Section {
                    HStack(spacing: 16) {
                        // Avatar - Tappable for editing
                        Button {
                            showAvatarSelection = true
                        } label: {
                            ZStack(alignment: .bottomTrailing) {
                                // Display avatar based on type
                                if let avatarType = authViewModel.currentUser?.avatarType {
                                    switch avatarType {
                                    case .builtIn:
                                        // Show built-in avatar
                                        if let avatarId = authViewModel.currentUser?.avatarId,
                                           let avatar = BuiltInAvatars.avatar(for: avatarId) {
                                            BuiltInAvatarView(avatar: avatar, size: 60)
                                        } else {
                                            defaultAvatarView
                                        }
                                        
                                    case .custom:
                                        // Show custom photo
                                        if let photoURL = authViewModel.currentUser?.photoURL,
                                           let url = URL(string: photoURL) {
                                            AsyncImage(url: url) { image in
                                                image
                                                    .resizable()
                                                    .aspectRatio(contentMode: .fill)
                                            } placeholder: {
                                                defaultAvatarView
                                            }
                                            .frame(width: 60, height: 60)
                                            .clipShape(Circle())
                                        } else {
                                            defaultAvatarView
                                        }
                                    }
                                } else {
                                    // Fallback to photo URL or default avatar
                                    if let photoURL = authViewModel.currentUser?.photoURL,
                                       let url = URL(string: photoURL) {
                                        AsyncImage(url: url) { image in
                                            image
                                                .resizable()
                                                .aspectRatio(contentMode: .fill)
                                        } placeholder: {
                                            defaultAvatarView
                                        }
                                        .frame(width: 60, height: 60)
                                        .clipShape(Circle())
                                    } else {
                                        defaultAvatarView
                                    }
                                }
                                
                                // Edit icon overlay
                                Circle()
                                    .fill(Color.blue)
                                    .frame(width: 20, height: 20)
                                    .overlay {
                                        Image(systemName: "pencil")
                                            .font(.system(size: 10, weight: .semibold))
                                            .foregroundStyle(.white)
                                    }
                                    .offset(x: 2, y: 2)
                            }
                        }
                        .buttonStyle(.plain)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            // Display name - Tappable for editing
                            Button {
                                editedName = authViewModel.currentUser?.displayName ?? ""
                                showNameEditor = true
                            } label: {
                                HStack(spacing: 6) {
                                    Text(authViewModel.currentUser?.displayName ?? "user")
                                        .font(.headline)
                                        .foregroundStyle(.primary)
                                    
                                    Image(systemName: "pencil.circle.fill")
                                        .font(.caption)
                                        .foregroundStyle(.blue)
                                }
                            }
                            .buttonStyle(.plain)
                            
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
            .sheet(isPresented: $showAvatarSelection) {
                if let currentUserId = authViewModel.currentUser?.id {
                    AvatarSelectionView(
                        currentUserId: currentUserId,
                        isPresented: $showAvatarSelection,
                        onAvatarSelected: {
                            print("✅ Avatar selected, Firestore listeners will update automatically")
                        }
                    )
                }
            }
            .alert("edit display name", isPresented: $showNameEditor) {
                TextField("display name", text: $editedName)
                    .textInputAutocapitalization(.words)
                
                Button("cancel", role: .cancel) {
                    editedName = ""
                }
                
                Button("save") {
                    saveDisplayName()
                }
            } message: {
                Text("enter your new display name")
            }
            .alert("error", isPresented: .constant(editViewModel.errorMessage != nil)) {
                Button("ok") {
                    editViewModel.errorMessage = nil
                }
            } message: {
                Text(editViewModel.errorMessage ?? "")
            }
            .overlay {
                if editViewModel.isLoading {
                    ZStack {
                        Color.black.opacity(0.3)
                            .ignoresSafeArea()
                        
                        VStack(spacing: 12) {
                            ProgressView()
                                .scaleEffect(1.5)
                            
                            Text("saving...")
                                .font(.subheadline)
                                .foregroundStyle(.white)
                        }
                        .padding(24)
                        .background(Color(.systemGray3))
                        .cornerRadius(16)
                    }
                }
            }
        }
        .onAppear {
            setupUserListener()
        }
        .onDisappear {
            userListener?.remove()
            userListener = nil
        }
    }
    
    // MARK: - Firestore Listener
    
    /// Set up real-time listener for user document changes
    private func setupUserListener() {
        guard let userId = authViewModel.currentUser?.id else { return }
        
        print("👂 Setting up user document listener for: \(userId)")
        
        // Remove existing listener if any
        userListener?.remove()
        
        // Set up new listener
        userListener = db.collection("users").document(userId)
            .addSnapshotListener { documentSnapshot, error in
                if let error = error {
                    print("❌ Error listening to user document: \(error.localizedDescription)")
                    return
                }
                
                guard let document = documentSnapshot, document.exists else {
                    print("⚠️ User document does not exist")
                    return
                }
                
                do {
                    let updatedUser = try document.data(as: User.self)
                    print("🔄 User document updated - refreshing profile view")
                    print("   Avatar Type: \(updatedUser.avatarType?.rawValue ?? "nil")")
                    print("   Avatar ID: \(updatedUser.avatarId ?? "nil")")
                    print("   Display Name: \(updatedUser.displayName)")
                    
                    // Update AuthViewModel's current user
                    Task { @MainActor in
                        authViewModel.currentUser = updatedUser
                    }
                } catch {
                    print("❌ Error decoding user document: \(error.localizedDescription)")
                }
            }
    }
    
    // MARK: - Helper Views
    
    private var defaultAvatarView: some View {
        Circle()
            .fill(Color.blue.opacity(0.3))
            .frame(width: 60, height: 60)
            .overlay {
                Text(authViewModel.currentUser?.displayName.prefix(1).uppercased() ?? "U")
                    .font(.title)
                    .foregroundStyle(.white)
            }
    }
    
    // MARK: - Save Display Name
    
    private func saveDisplayName() {
        guard let userId = authViewModel.currentUser?.id else { return }
        
        print("💾 Saving display name: \(editedName)")
        
        Task {
            do {
                try await editViewModel.updateDisplayName(userId: userId, newDisplayName: editedName)
                
                print("✅ Display name saved successfully - Firestore listeners will update automatically")
                
                await MainActor.run {
                    editedName = ""
                }
            } catch {
                print("❌ Failed to save display name: \(error.localizedDescription)")
                
                await MainActor.run {
                    editViewModel.errorMessage = error.localizedDescription
                }
            }
        }
    }
}

#Preview {
    ProfileView()
        .environmentObject(AuthViewModel())
}

