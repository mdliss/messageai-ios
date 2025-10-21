//
//  ConversationRowView.swift
//  messageAI
//
//  Created by MessageAI Team
//  Row view for conversation list
//

import SwiftUI

struct ConversationRowView: View {
    let conversation: Conversation
    let currentUserId: String
    
    @State private var isOnline = false
    
    private let realtimeDBService = RealtimeDBService.shared
    
    var body: some View {
        HStack(spacing: 12) {
            // Avatar
            avatarView
            
            // Content
            VStack(alignment: .leading, spacing: 4) {
                // Name and timestamp
                HStack {
                    Text(conversation.displayName(for: currentUserId))
                        .font(.headline)
                        .lineLimit(1)
                    
                    Spacer()
                    
                    if let lastMessage = conversation.lastMessage {
                        Text(lastMessage.timestamp, style: .relative)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                
                // Last message preview
                if let lastMessage = conversation.lastMessage {
                    Text(lastMessage.text)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }
            
            // Unread badge (if any)
            if let unreadCount = conversation.unreadCount[currentUserId], unreadCount > 0 {
                Text("\(unreadCount)")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(.white)
                    .frame(minWidth: 20, minHeight: 20)
                    .padding(.horizontal, 6)
                    .background(Color.blue)
                    .clipShape(Capsule())
            }
        }
        .padding(.vertical, 4)
    }
    
    // MARK: - Avatar View
    
    @ViewBuilder
    private var avatarView: some View {
        ZStack(alignment: .bottomTrailing) {
            if conversation.type == .group {
                // Group avatar
                Circle()
                    .fill(Color.purple.opacity(0.3))
                    .frame(width: 50, height: 50)
                    .overlay {
                        Image(systemName: "person.3.fill")
                            .foregroundStyle(.purple)
                    }
            } else {
                // Direct chat avatar
                let otherUserId = conversation.participantIds.first { $0 != currentUserId }
                let participant = conversation.participantDetails[otherUserId ?? ""]
                
                if let photoURL = participant?.photoURL, let url = URL(string: photoURL) {
                    AsyncImage(url: url) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } placeholder: {
                        Circle()
                            .fill(Color.blue.opacity(0.3))
                            .overlay {
                                Text(participant?.displayName.prefix(1).uppercased() ?? "?")
                                    .foregroundStyle(.white)
                                    .fontWeight(.semibold)
                            }
                    }
                    .frame(width: 50, height: 50)
                    .clipShape(Circle())
                } else {
                    Circle()
                        .fill(Color.blue.opacity(0.3))
                        .frame(width: 50, height: 50)
                        .overlay {
                            Text(participant?.displayName.prefix(1).uppercased() ?? "?")
                                .foregroundStyle(.white)
                                .fontWeight(.semibold)
                        }
                }
                
                // Online indicator for direct chats
                if conversation.type == .direct {
                    Circle()
                        .fill(isOnline ? Color.green : Color.gray)
                        .frame(width: 14, height: 14)
                        .overlay {
                            Circle()
                                .stroke(Color(.systemBackground), lineWidth: 2)
                        }
                        .offset(x: 2, y: 2)
                }
            }
        }
        .onAppear {
            subscribeToPresence()
        }
    }
    
    // MARK: - Presence Subscription
    
    private func subscribeToPresence() {
        guard conversation.type == .direct else { return }
        
        let otherUserId = conversation.participantIds.first { $0 != currentUserId }
        guard let otherUserId = otherUserId else { return }
        
        Task {
            for await online in realtimeDBService.observePresence(userId: otherUserId) {
                isOnline = online
            }
        }
    }
}

#Preview {
    let conversation = Conversation(
        id: "1",
        type: .direct,
        participantIds: ["user1", "user2"],
        participantDetails: [
            "user2": ParticipantDetail(displayName: "Alice Smith")
        ],
        lastMessage: LastMessage(
            text: "hey, how's it going?",
            senderId: "user2",
            timestamp: Date().addingTimeInterval(-3600)
        ),
        unreadCount: ["user1": 2]
    )
    
    ConversationRowView(conversation: conversation, currentUserId: "user1")
        .padding()
}

