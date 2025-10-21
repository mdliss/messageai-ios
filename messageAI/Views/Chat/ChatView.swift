//
//  ChatView.swift
//  messageAI
//
//  Created by MessageAI Team
//  Main chat view for messaging
//

import SwiftUI

struct ChatView: View {
    let conversation: Conversation
    let currentUserId: String
    
    @StateObject private var viewModel = ChatViewModel()
    @State private var messageText = ""
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack(spacing: 0) {
            // Network status banner
            NetworkBanner()
            
            // Messages list
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 8) {
                        if viewModel.isLoading && viewModel.messages.isEmpty {
                            ProgressView()
                                .padding()
                        }
                        
                        ForEach(viewModel.messages) { message in
                            MessageBubbleView(
                                message: message,
                                isFromCurrentUser: message.isFromCurrentUser(userId: currentUserId),
                                showSenderName: conversation.type == .group
                            )
                            .id(message.id)
                            .contextMenu {
                                if message.status == .failed {
                                    Button {
                                        Task {
                                            await viewModel.retryMessage(message)
                                        }
                                    } label: {
                                        Label("retry", systemImage: "arrow.clockwise")
                                    }
                                }
                            }
                        }
                    }
                    .padding(.top, 8)
                }
                .onChange(of: viewModel.messages.count) { _, _ in
                    // Auto-scroll to bottom on new message
                    if let lastMessage = viewModel.messages.last {
                        withAnimation {
                            proxy.scrollTo(lastMessage.id, anchor: .bottom)
                        }
                    }
                }
                .onAppear {
                    // Scroll to bottom on appear
                    if let lastMessage = viewModel.messages.last {
                        proxy.scrollTo(lastMessage.id, anchor: .bottom)
                    }
                }
            }
            
            // Message input
            MessageInputView(
                text: $messageText,
                onSend: sendMessage,
                isSending: viewModel.isSending
            )
        }
        .navigationTitle(conversation.displayName(for: currentUserId))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                VStack(spacing: 2) {
                    Text(conversation.displayName(for: currentUserId))
                        .font(.headline)
                    
                    if conversation.type == .group {
                        Text("\(conversation.participantIds.count) members")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .onAppear {
            viewModel.loadMessages(
                conversationId: conversation.id,
                currentUserId: currentUserId
            )
        }
        .onDisappear {
            viewModel.cleanup()
        }
        .alert("error", isPresented: .constant(viewModel.errorMessage != nil)) {
            Button("ok") {
                viewModel.errorMessage = nil
            }
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
    }
    
    // MARK: - Send Message
    
    private func sendMessage() {
        let text = messageText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        
        // Get current user info from conversation
        let participant = conversation.participantDetails[currentUserId]
        
        Task {
            await viewModel.sendMessage(
                text: text,
                senderId: currentUserId,
                senderName: participant?.displayName ?? "You",
                senderPhotoURL: participant?.photoURL
            )
        }
    }
}

#Preview {
    NavigationStack {
        ChatView(
            conversation: Conversation(
                id: "1",
                type: .direct,
                participantIds: ["user1", "user2"],
                participantDetails: [
                    "user1": ParticipantDetail(displayName: "You"),
                    "user2": ParticipantDetail(displayName: "Alice Smith")
                ]
            ),
            currentUserId: "user1"
        )
    }
}

