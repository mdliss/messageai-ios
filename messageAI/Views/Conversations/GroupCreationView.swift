//
//  GroupCreationView.swift
//  messageAI
//
//  Created by MessageAI Team
//  View for creating group conversations
//

import SwiftUI

struct GroupCreationView: View {
    let currentUser: User
    let onCreateGroup: (Conversation) -> Void
    
    @Environment(\.dismiss) private var dismiss
    @State private var users: [User] = []
    @State private var selectedUserIds: Set<String> = []
    @State private var groupName = ""
    @State private var isLoading = false
    @State private var isCreating = false
    @State private var searchText = ""
    @State private var errorMessage: String?
    
    private let firestoreService = FirestoreService.shared
    private let conversationViewModel = ConversationViewModel()
    
    var body: some View {
        NavigationStack {
            ZStack {
                VStack(spacing: 0) {
                    // Group name input
                    VStack(alignment: .leading, spacing: 8) {
                        Text("group name (optional)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal)
                        
                        TextField("enter group name", text: $groupName)
                            .textFieldStyle(.plain)
                            .padding()
                            .background(Color(.systemGray6))
                            .cornerRadius(10)
                            .padding(.horizontal)
                    }
                    .padding(.vertical, 12)
                    
                    Divider()
                    
                    // Selected users count
                    if !selectedUserIds.isEmpty {
                        HStack {
                            Text("\(selectedUserIds.count) \(selectedUserIds.count == 1 ? "person" : "people") selected")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            
                            Spacer()
                            
                            if selectedUserIds.count < 2 {
                                Text("select at least 2 people")
                                    .font(.caption)
                                    .foregroundStyle(.orange)
                            }
                        }
                        .padding(.horizontal)
                        .padding(.vertical, 8)
                        .background(Color(.systemGray6))
                    }
                    
                    // Users list
                    if isLoading {
                        Spacer()
                        ProgressView()
                        Spacer()
                    } else {
                        List(filteredUsers) { user in
                            Button {
                                toggleUserSelection(user)
                            } label: {
                                HStack(spacing: 12) {
                                    // Checkbox
                                    Image(systemName: selectedUserIds.contains(user.id) ? "checkmark.circle.fill" : "circle")
                                        .foregroundStyle(selectedUserIds.contains(user.id) ? .blue : .gray)
                                        .font(.title3)
                                    
                                    // Avatar
                                    UserAvatarView(user: user, size: 44)
                                    
                                    // User info
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(user.displayName)
                                            .font(.headline)
                                        
                                        Text(user.email)
                                            .font(.subheadline)
                                            .foregroundStyle(.secondary)
                                    }
                                    
                                    Spacer()
                                }
                                .padding(.vertical, 4)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                        }
                        .listStyle(.plain)
                    }
                }
                
                // Creating overlay
                if isCreating {
                    Color.black.opacity(0.3)
                        .ignoresSafeArea()
                    
                    VStack(spacing: 16) {
                        ProgressView()
                            .tint(.white)
                        Text("creating group")
                            .foregroundStyle(.white)
                    }
                }
            }
            .navigationTitle("new group")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("cancel") {
                        dismiss()
                    }
                    .disabled(isCreating)
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("create") {
                        createGroup()
                    }
                    .disabled(!canCreateGroup || isCreating)
                    .fontWeight(.semibold)
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
    
    // MARK: - Computed Properties
    
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
    
    private var canCreateGroup: Bool {
        selectedUserIds.count >= 2
    }
    
    // MARK: - Actions
    
    private func toggleUserSelection(_ user: User) {
        if selectedUserIds.contains(user.id) {
            selectedUserIds.remove(user.id)
        } else {
            selectedUserIds.insert(user.id)
        }
    }
    
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
    
    private func createGroup() {
        guard canCreateGroup else { return }
        
        isCreating = true
        
        Task {
            do {
                // Include current user in participants
                var participantIds = Array(selectedUserIds)
                participantIds.append(currentUser.id)
                
                let conversation = try await conversationViewModel.createGroupConversation(
                    participantIds: participantIds,
                    groupName: groupName.isEmpty ? nil : groupName
                )
                
                isCreating = false
                onCreateGroup(conversation)
                dismiss()
            } catch {
                errorMessage = "Failed to create group: \(error.localizedDescription)"
                isCreating = false
            }
        }
    }
}

#Preview {
    GroupCreationView(
        currentUser: User(
            id: "user1",
            email: "test@example.com",
            displayName: "Test User"
        ),
        onCreateGroup: { _ in }
    )
}

