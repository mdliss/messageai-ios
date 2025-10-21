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
    
    private let firestoreService = FirestoreService.shared
    
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
                                
                                // Online indicator
                                if user.isOnline {
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
            } catch {
                errorMessage = "Failed to load users: \(error.localizedDescription)"
                isLoading = false
            }
        }
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

