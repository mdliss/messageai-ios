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
    var isHighlighted: Bool = false
    
    @ObservedObject private var networkMonitor = NetworkMonitor.shared
    
    // MARK: - Computed Properties
    
    /// Only show "Not Delivered" when offline OR explicitly failed (not during normal sending)
    /// 
    /// Expected behavior:
    /// - Online + sending → NO indicator (fast upload, will show checkmark within milliseconds)
    /// - Offline + sending → "Not Delivered" (queued locally)
    /// - Failed → "Not Delivered" (always show for retry)
    /// - Sent/Delivered → Single checkmark (gray)
    /// - Read → Double checkmark (blue)
    private var shouldShowNotDelivered: Bool {
        guard message.status == .sending || message.status == .failed else {
            return false
        }
        
        // Always show for failed messages
        if message.status == .failed {
            return true
        }
        
        // For sending messages, only show if offline
        if message.status == .sending {
            // CRITICAL: Only show "Not Delivered" when actually offline
            // When online, message sends fast enough that indicator shouldn't flash
            return !message.isSynced && !networkMonitor.isConnected
        }
        
        return false
    }
    
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
                
                // Priority indicator badge
                if let priority = message.priority {
                    switch priority {
                    case .urgent:
                        // Red hazard symbol for urgent messages
                        HStack(spacing: 4) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.caption2)
                            Text("urgent")
                                .font(.caption2.weight(.semibold))
                        }
                        .foregroundStyle(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.red)
                        .cornerRadius(12)
                        .padding(isFromCurrentUser ? .trailing : .leading, 4)
                        
                    case .high:
                        // Yellow circle for high priority
                        HStack(spacing: 4) {
                            Image(systemName: "circle.fill")
                                .font(.caption2)
                            Text("important")
                                .font(.caption2.weight(.semibold))
                        }
                        .foregroundStyle(.primary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.yellow.opacity(0.3))
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.yellow, lineWidth: 1.5)
                        )
                        .padding(isFromCurrentUser ? .trailing : .leading, 4)
                        
                    case .normal:
                        // No indicator for normal priority
                        EmptyView()
                    }
                }
                
                // Message content
                if message.type == .text {
                    textBubble
                } else if message.type == .image {
                    imageBubble
                } else if message.type == .voice {
                    voiceBubble
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
                
                // Not Delivered indicator - ONLY show when offline or explicitly failed
                if isFromCurrentUser && shouldShowNotDelivered {
                    Text("Not Delivered")
                        .font(.caption2)
                        .fontWeight(.bold)
                        .foregroundStyle(.red)
                        .padding(.horizontal, 4)
                        .padding(.top, 2)
                }
            }
            
            // Spacer on right for received messages
            if !isFromCurrentUser {
                Spacer(minLength: 60)
            }
            
            // Padding on right for sent messages
            if isFromCurrentUser {
                Spacer(minLength: 0)
                    .frame(width: 8)
            }
        }
        .padding(.vertical, 2)
        .background(
            // Highlight background for priority message navigation
            isHighlighted ? Color.yellow.opacity(0.2) : Color.clear
        )
        .cornerRadius(8)
    }
    
    // MARK: - Text Bubble

    private var textBubble: some View {
        styledMessageText
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(bubbleColor)
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(priorityBorderColor, lineWidth: message.priority != nil ? 2 : 0)
            )
    }

    /// Styled text with @mentions highlighted
    private var styledMessageText: Text {
        let text = message.text
        let pattern = "@([^\\s@]+)"

        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            return Text(text)
                .foregroundStyle(isFromCurrentUser ? .white : .primary)
        }

        let matches = regex.matches(in: text, range: NSRange(text.startIndex..., in: text))

        // If no mentions, return plain text
        guard !matches.isEmpty else {
            return Text(text)
                .foregroundStyle(isFromCurrentUser ? .white : .primary)
        }

        // Build attributed text with styled mentions
        var result = Text("")
        var lastIndex = text.startIndex

        for match in matches {
            // Add text before the mention
            if let range = Range(match.range, in: text) {
                let beforeText = String(text[lastIndex..<range.lowerBound])
                if !beforeText.isEmpty {
                    result = result + Text(beforeText)
                        .foregroundStyle(isFromCurrentUser ? .white : .primary)
                }

                // Add the mention with special styling
                let mention = String(text[range])
                result = result + Text(mention)
                    .font(.system(.body, design: .monospaced))
                    .fontWeight(.semibold)
                    .foregroundStyle(isFromCurrentUser ? Color.white.opacity(0.95) : Color.blue)
                    .underline()

                lastIndex = range.upperBound
            }
        }

        // Add remaining text after last mention
        if lastIndex < text.endIndex {
            let remainingText = String(text[lastIndex...])
            result = result + Text(remainingText)
                .foregroundStyle(isFromCurrentUser ? .white : .primary)
        }

        return result
    }
    
    /// Priority border color based on priority level
    private var priorityBorderColor: Color {
        guard let priority = message.priority else {
            return Color.clear
        }
        
        switch priority {
        case .urgent:
            return Color.red
        case .high:
            return Color.yellow
        case .normal:
            return Color.clear
        }
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

    // MARK: - Voice Bubble

    private var voiceBubble: some View {
        VoiceMessageView(message: message, isFromCurrentUser: isFromCurrentUser)
            .background(bubbleColor)
            .cornerRadius(16)
    }
    
    // MARK: - Avatar
    
    private var avatarView: some View {
        UserAvatarView(message: message, size: 32)
            .padding(.bottom, 2)
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
            showSenderName: true,
            isHighlighted: false
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
            showSenderName: false,
            isHighlighted: false
        )
        
        MessageBubbleView(
            message: Message(
                conversationId: "1",
                senderId: "user2",
                senderName: "Alice",
                text: "URGENT: we need to fix the bug ASAP!",
                status: .read,
                priority: .urgent
            ),
            isFromCurrentUser: false,
            showSenderName: true,
            isHighlighted: true
        )
        
        MessageBubbleView(
            message: Message(
                conversationId: "1",
                senderId: "user2",
                senderName: "Bob",
                text: "Important: Can you review the PR when you get a chance?",
                status: .read,
                priority: .high
            ),
            isFromCurrentUser: false,
            showSenderName: true,
            isHighlighted: false
        )
    }
    .padding()
}

