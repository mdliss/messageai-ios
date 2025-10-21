//
//  ConversationListView.swift
//  messageAI
//
//  Created by MessageAI Team
//  List of conversations for the user
//

import SwiftUI

struct ConversationListView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @StateObject private var viewModel = ConversationViewModel()
    @State private var showUserPicker = false
    @State private var showGroupCreation = false
    @State private var showSearch = false
    @State private var selectedConversation: Conversation?
    
    var body: some View {
        NavigationStack {
            ZStack {
                if viewModel.isLoading && viewModel.conversations.isEmpty {
                    // Loading state
                    VStack {
                        ProgressView()
                        Text("loading conversations")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .padding(.top, 8)
                    }
                } else if viewModel.conversations.isEmpty {
                    // Empty state
                    VStack(spacing: 16) {
                        Image(systemName: "message.fill")
                            .font(.system(size: 60))
                            .foregroundStyle(.blue.opacity(0.3))
                            .padding()
                        
                        Text("no conversations yet")
                            .font(.title2)
                            .fontWeight(.semibold)
                        
                        Text("tap the + button to start a new conversation")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                } else {
                    // Conversations list
                    List {
                        ForEach(viewModel.conversations) { conversation in
                            Button {
                                selectedConversation = conversation
                            } label: {
                                ConversationRowView(
                                    conversation: conversation,
                                    currentUserId: authViewModel.currentUser?.id ?? ""
                                )
                            }
                            .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                        }
                    }
                    .listStyle(.plain)
                    .refreshable {
                        // Pull to refresh
                        if let userId = authViewModel.currentUser?.id {
                            viewModel.loadConversations(userId: userId)
                        }
                    }
                }
            }
            .navigationTitle("chats")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        showSearch = true
                    } label: {
                        Image(systemName: "magnifyingglass")
                    }
                }
                
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button {
                            showUserPicker = true
                        } label: {
                            Label("new message", systemImage: "message")
                        }
                        
                        Button {
                            showGroupCreation = true
                        } label: {
                            Label("new group", systemImage: "person.3")
                        }
                    } label: {
                        Image(systemName: "square.and.pencil")
                    }
                }
            }
            .sheet(isPresented: $showUserPicker) {
                if let currentUser = authViewModel.currentUser {
                    UserPickerView(
                        currentUser: currentUser,
                        onSelectUser: { otherUser in
                            Task {
                                await createConversation(with: otherUser)
                            }
                        }
                    )
                }
            }
            .sheet(isPresented: $showGroupCreation) {
                if let currentUser = authViewModel.currentUser {
                    GroupCreationView(
                        currentUser: currentUser,
                        onCreateGroup: { conversation in
                            selectedConversation = conversation
                        }
                    )
                }
            }
            .sheet(isPresented: $showSearch) {
                SearchView()
            }
            .navigationDestination(item: $selectedConversation) { conversation in
                if let currentUserId = authViewModel.currentUser?.id {
                    ChatView(
                        conversation: conversation,
                        currentUserId: currentUserId
                    )
                }
            }
            .onAppear {
                if let userId = authViewModel.currentUser?.id {
                    viewModel.loadConversations(userId: userId)
                }
            }
            .alert("error", isPresented: .constant(viewModel.errorMessage != nil)) {
                Button("ok") {
                    viewModel.errorMessage = nil
                }
            } message: {
                Text(viewModel.errorMessage ?? "")
            }
        }
    }
    
    // MARK: - Create Conversation
    
    private func createConversation(with otherUser: User) async {
        guard let currentUser = authViewModel.currentUser else { return }
        
        do {
            let conversation = try await viewModel.createConversation(
                currentUserId: currentUser.id,
                otherUserId: otherUser.id
            )
            
            // Dismiss picker and navigate to chat
            showUserPicker = false
            selectedConversation = conversation
        } catch {
            print("❌ Failed to create conversation: \(error.localizedDescription)")
        }
    }
}

#Preview {
    ConversationListView()
        .environmentObject(AuthViewModel())
}

