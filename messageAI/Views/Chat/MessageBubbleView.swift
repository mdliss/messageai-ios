//
//  MessageBubbleView.swift
//  messageAI
//
//  Created by MessageAI Team
//  Message bubble view for chat messages
//

import SwiftUI

struct MessageBubbleView: View {
    let message: Message
    let isFromCurrentUser: Bool
    let showSenderName: Bool
    
    var body: some View {
        HStack(alignment: .bottom, spacing: 6) {
            // Spacer on left for sent messages
            if isFromCurrentUser {
                Spacer(minLength: 60)
            }
            
            if !isFromCurrentUser {
                // Avatar for received messages
                avatarView
                    .padding(.leading, 8)
            }
            
            VStack(alignment: isFromCurrentUser ? .trailing : .leading, spacing: 2) {
                // Sender name (for group chats)
                if showSenderName && !isFromCurrentUser {
                    Text(message.senderName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.leading, 4)
                }
                
                // Message content
                if message.type == .text {
                    textBubble
                } else if message.type == .image {
                    imageBubble
                }
                
                // Timestamp and status
                HStack(spacing: 4) {
                    Text(message.createdAt, style: .relative)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    
                    if isFromCurrentUser {
                        statusIndicator
                    }
                }
                .padding(.horizontal, 4)
            }
            
            // Padding on right for sent messages
            if isFromCurrentUser {
                Spacer(minLength: 0)
                    .frame(width: 8)
            } else {
                Spacer()
            }
        }
        .padding(.vertical, 2)
    }
    
    // MARK: - Text Bubble
    
    private var textBubble: some View {
        Text(message.text)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(bubbleColor)
            .foregroundStyle(isFromCurrentUser ? .white : .primary)
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(message.priority == true ? Color.red : Color.clear, lineWidth: 2)
            )
    }
    
    // MARK: - Image Bubble
    
    private var imageBubble: some View {
        VStack(alignment: isFromCurrentUser ? .trailing : .leading, spacing: 4) {
            if let imageURL = message.imageURL, let url = URL(string: imageURL) {
                AsyncImage(url: url) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(maxWidth: 250, maxHeight: 250)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                } placeholder: {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.gray.opacity(0.2))
                        .frame(width: 250, height: 250)
                        .overlay {
                            ProgressView()
                        }
                }
            }
            
            if !message.text.isEmpty {
                Text(message.text)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(bubbleColor)
                    .foregroundStyle(isFromCurrentUser ? .white : .primary)
                    .cornerRadius(16)
            }
        }
    }
    
    // MARK: - Avatar
    
    private var avatarView: some View {
        Group {
            if let photoURL = message.senderPhotoURL, let url = URL(string: photoURL) {
                AsyncImage(url: url) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    Circle()
                        .fill(Color.gray.opacity(0.3))
                        .overlay {
                            Text(message.senderName.prefix(1).uppercased())
                                .font(.caption)
                                .foregroundStyle(.white)
                        }
                }
                .frame(width: 32, height: 32)
                .clipShape(Circle())
            } else {
                Circle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 32, height: 32)
                    .overlay {
                        Text(message.senderName.prefix(1).uppercased())
                            .font(.caption)
                            .foregroundStyle(.white)
                    }
            }
        }
    }
    
    // MARK: - Status Indicator
    
    @ViewBuilder
    private var statusIndicator: some View {
        switch message.status {
        case .sending:
            Image(systemName: "clock")
                .font(.caption2)
                .foregroundStyle(.secondary)
        case .sent:
            Image(systemName: "checkmark")
                .font(.caption2)
                .foregroundStyle(.secondary)
        case .delivered:
            HStack(spacing: -4) {
                Image(systemName: "checkmark")
                Image(systemName: "checkmark")
            }
            .font(.caption2)
            .foregroundStyle(.secondary)
        case .read:
            HStack(spacing: -4) {
                Image(systemName: "checkmark")
                Image(systemName: "checkmark")
            }
            .font(.caption2)
            .foregroundStyle(.blue)
        case .failed:
            Image(systemName: "exclamationmark.circle")
                .font(.caption2)
                .foregroundStyle(.red)
        }
        
        // Priority indicator
        if message.priority == true {
            Image(systemName: "flag.fill")
                .font(.caption2)
                .foregroundStyle(.red)
        }
    }
    
    // MARK: - Computed Properties
    
    private var bubbleColor: Color {
        if isFromCurrentUser {
            return .blue
        } else {
            return Color(.systemGray5)
        }
    }
}

#Preview {
    VStack(spacing: 16) {
        MessageBubbleView(
            message: Message(
                conversationId: "1",
                senderId: "user2",
                senderName: "Alice",
                text: "hey, how's it going?",
                status: .read
            ),
            isFromCurrentUser: false,
            showSenderName: true
        )
        
        MessageBubbleView(
            message: Message(
                conversationId: "1",
                senderId: "user1",
                senderName: "You",
                text: "pretty good! working on the new feature",
                status: .delivered
            ),
            isFromCurrentUser: true,
            showSenderName: false
        )
        
        MessageBubbleView(
            message: Message(
                conversationId: "1",
                senderId: "user2",
                senderName: "Alice",
                text: "URGENT: we need to fix the bug ASAP!",
                status: .read,
                priority: true
            ),
            isFromCurrentUser: false,
            showSenderName: true
        )
    }
    .padding()
}

