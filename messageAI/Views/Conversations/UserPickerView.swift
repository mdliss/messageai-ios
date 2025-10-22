//
//  UserPickerView.swift
//  messageAI
//
//  Created by MessageAI Team
//  View for selecting a user to start a conversation
//

import SwiftUI

struct UserPickerView: View {
    let currentUser: User
    let onSelectUser: (User) -> Void
    
    @Environment(\.dismiss) private var dismiss
    @State private var users: [User] = []
    @State private var isLoading = false
    @State private var searchText = ""
    @State private var errorMessage: String?
    @State private var onlineStatuses: [String: Bool?] = [:]  // Use Bool? to distinguish unknown from offline
    @State private var presenceTasks: [String: Task<Void, Never>] = [:]  // Track tasks for cleanup
    
    private let firestoreService = FirestoreService.shared
    private let realtimeDBService = RealtimeDBService.shared
    
    var body: some View {
        NavigationStack {
            ZStack {
                if isLoading {
                    ProgressView()
                } else if filteredUsers.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "person.2.slash")
                            .font(.system(size: 60))
                            .foregroundStyle(.gray.opacity(0.3))
                        
                        Text(searchText.isEmpty ? "no users found" : "no matching users")
                            .font(.headline)
                            .foregroundStyle(.secondary)
                    }
                } else {
                    List(filteredUsers) { user in
                        Button {
                            onSelectUser(user)
                            dismiss()
                        } label: {
                            HStack(spacing: 12) {
                                // Avatar
                                if let photoURL = user.photoURL, let url = URL(string: photoURL) {
                                    AsyncImage(url: url) { image in
                                        image
                                            .resizable()
                                            .aspectRatio(contentMode: .fill)
                                    } placeholder: {
                                        Circle()
                                            .fill(Color.blue.opacity(0.3))
                                            .overlay {
                                                Text(user.displayName.prefix(1).uppercased())
                                                    .foregroundStyle(.white)
                                            }
                                    }
                                    .frame(width: 44, height: 44)
                                    .clipShape(Circle())
                                } else {
                                    Circle()
                                        .fill(Color.blue.opacity(0.3))
                                        .frame(width: 44, height: 44)
                                        .overlay {
                                            Text(user.displayName.prefix(1).uppercased())
                                                .foregroundStyle(.white)
                                        }
                                }
                                
                                // User info
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(user.displayName)
                                        .font(.headline)
                                    
                                    Text(user.email)
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                }
                                
                                Spacer()
                                
                                // Online indicator (from real-time presence)
                                // Only show green dot if explicitly online (true), not nil/unknown or false
                                if let isOnline = onlineStatuses[user.id], isOnline == true {
                                    Circle()
                                        .fill(Color.green)
                                        .frame(width: 10, height: 10)
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("new message")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("cancel") {
                        dismiss()
                    }
                }
            }
            .searchable(text: $searchText, prompt: "search users")
            .onAppear {
                loadUsers()
            }
            .onDisappear {
                // CRITICAL: Clean up presence listeners to prevent memory leaks
                cleanupPresenceListeners()
            }
            .onChange(of: users) { _, newUsers in
                // Start observing presence for all users
                observePresenceForUsers(newUsers)
            }
            .alert("error", isPresented: .constant(errorMessage != nil)) {
                Button("ok") {
                    errorMessage = nil
                }
            } message: {
                Text(errorMessage ?? "")
            }
        }
    }
    
    // MARK: - Filtered Users
    
    private var filteredUsers: [User] {
        let otherUsers = users.filter { $0.id != currentUser.id }
        
        if searchText.isEmpty {
            return otherUsers
        } else {
            return otherUsers.filter { user in
                user.displayName.localizedCaseInsensitiveContains(searchText) ||
                user.email.localizedCaseInsensitiveContains(searchText)
            }
        }
    }
    
    // MARK: - Load Users
    
    private func loadUsers() {
        isLoading = true
        
        Task {
            do {
                let fetchedUsers = try await firestoreService.getAllUsers()
                users = fetchedUsers
                isLoading = false
                
                print("✅ Loaded \(fetchedUsers.count) users")
            } catch {
                errorMessage = "Failed to load users: \(error.localizedDescription)"
                isLoading = false
            }
        }
    }
    
    // MARK: - Observe Presence
    
    private func observePresenceForUsers(_ users: [User]) {
        print("👀 Starting presence observation for \(users.count) users")
        
        // CRITICAL FIX: Initialize ALL presence states as nil (unknown) first
        // This prevents the UI from showing "everyone is online" flash
        for user in users {
            onlineStatuses[user.id] = nil
        }
        print("✅ Initialized all presence states as unknown")
        
        // Now attach RTDB listeners - updates will come through async
        // Store tasks for proper cleanup on view dismissal
        for user in users {
            let task = Task {
                for await isOnline in realtimeDBService.observePresence(userId: user.id) {
                    await MainActor.run {
                        onlineStatuses[user.id] = isOnline
                        print("📍 Updated presence for \(user.displayName): \(isOnline ? "ONLINE" : "OFFLINE")")
                    }
                }
            }
            presenceTasks[user.id] = task
        }
    }
    
    /// Clean up presence listeners when view is dismissed
    private func cleanupPresenceListeners() {
        print("🧹 Cleaning up \(presenceTasks.count) presence listeners")
        for (_, task) in presenceTasks {
            task.cancel()
        }
        presenceTasks.removeAll()
        onlineStatuses.removeAll()
    }
}

#Preview {
    UserPickerView(
        currentUser: User(
            id: "user1",
            email: "test@example.com",
            displayName: "Test User"
        ),
        onSelectUser: { _ in }
    )
}

