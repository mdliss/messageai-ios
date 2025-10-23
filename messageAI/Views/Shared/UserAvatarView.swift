//
//  UserAvatarView.swift
//  messageAI
//
//  Created by MessageAI Team
//  Reusable avatar view component for all user avatars
//

import SwiftUI

/// Reusable view component that handles rendering all avatar types
/// Supports built-in avatars, custom photos, and fallback initials
struct UserAvatarView: View {
    // Avatar data
    let avatarType: AvatarType?
    let avatarId: String?
    let photoURL: String?
    let displayName: String
    
    // Display options
    let size: CGFloat
    let showOnlineIndicator: Bool
    let isOnline: Bool
    
    /// Initialize with all avatar parameters
    /// - Parameters:
    ///   - avatarType: Type of avatar (built-in or custom)
    ///   - avatarId: ID of built-in avatar
    ///   - photoURL: URL of custom photo
    ///   - displayName: Display name for fallback initials
    ///   - size: Avatar dimensions
    ///   - showOnlineIndicator: Whether to show online status
    ///   - isOnline: Online status
    init(
        avatarType: AvatarType? = nil,
        avatarId: String? = nil,
        photoURL: String? = nil,
        displayName: String,
        size: CGFloat = 50,
        showOnlineIndicator: Bool = false,
        isOnline: Bool = false
    ) {
        self.avatarType = avatarType
        self.avatarId = avatarId
        self.photoURL = photoURL
        self.displayName = displayName
        self.size = size
        self.showOnlineIndicator = showOnlineIndicator
        self.isOnline = isOnline
    }
    
    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            // Main avatar content
            avatarContent
            
            // Optional online indicator
            if showOnlineIndicator {
                Circle()
                    .fill(isOnline ? Color.green : Color.gray)
                    .frame(width: size * 0.28, height: size * 0.28)
                    .overlay {
                        Circle()
                            .stroke(Color(.systemBackground), lineWidth: 2)
                    }
                    .offset(x: size * 0.04, y: size * 0.04)
            }
        }
    }
    
    // MARK: - Avatar Content
    
    @ViewBuilder
    private var avatarContent: some View {
        if let avatarType = avatarType {
            switch avatarType {
            case .builtIn:
                // Render built-in avatar
                if let avatarId = avatarId,
                   let builtInAvatar = BuiltInAvatars.avatar(for: avatarId) {
                    BuiltInAvatarView(avatar: builtInAvatar, size: size)
                } else {
                    // Fallback if avatar ID is invalid
                    fallbackInitialsAvatar
                }
                
            case .custom:
                // Render custom photo
                if let photoURL = photoURL, let url = URL(string: photoURL) {
                    AsyncImage(url: url) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } placeholder: {
                        // Show placeholder while loading
                        fallbackInitialsAvatar
                    }
                    .frame(width: size, height: size)
                    .clipShape(Circle())
                } else {
                    // Fallback if photo URL is missing
                    fallbackInitialsAvatar
                }
            }
        } else {
            // No avatar type specified, use fallback
            fallbackInitialsAvatar
        }
    }
    
    // MARK: - Fallback Avatar
    
    private var fallbackInitialsAvatar: some View {
        Circle()
            .fill(Color.blue.opacity(0.3))
            .frame(width: size, height: size)
            .overlay {
                Text(displayName.prefix(1).uppercased())
                    .font(.system(size: size * 0.4))
                    .foregroundStyle(.white)
                    .fontWeight(.semibold)
            }
    }
}

// MARK: - Convenience Initializers

extension UserAvatarView {
    /// Initialize from User model
    /// - Parameters:
    ///   - user: User model
    ///   - size: Avatar dimensions
    ///   - showOnlineIndicator: Whether to show online status
    init(user: User, size: CGFloat = 50, showOnlineIndicator: Bool = false) {
        self.init(
            avatarType: user.avatarType,
            avatarId: user.avatarId,
            photoURL: user.photoURL,
            displayName: user.displayName,
            size: size,
            showOnlineIndicator: showOnlineIndicator,
            isOnline: user.isOnline
        )
    }
    
    /// Initialize from ParticipantDetail
    /// - Parameters:
    ///   - participant: Participant detail from conversation
    ///   - size: Avatar dimensions
    ///   - showOnlineIndicator: Whether to show online status
    ///   - isOnline: Online status (must be provided separately for ParticipantDetail)
    init(participant: ParticipantDetail, size: CGFloat = 50, showOnlineIndicator: Bool = false, isOnline: Bool = false) {
        self.init(
            avatarType: participant.avatarType,
            avatarId: participant.avatarId,
            photoURL: participant.photoURL,
            displayName: participant.displayName,
            size: size,
            showOnlineIndicator: showOnlineIndicator,
            isOnline: isOnline
        )
    }
    
    /// Initialize from Message (for message bubbles)
    /// - Parameters:
    ///   - message: Message containing sender info
    ///   - size: Avatar dimensions
    init(message: Message, size: CGFloat = 32) {
        self.init(
            avatarType: message.senderAvatarType,
            avatarId: message.senderAvatarId,
            photoURL: message.senderPhotoURL,
            displayName: message.senderName,
            size: size,
            showOnlineIndicator: false,
            isOnline: false
        )
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 20) {
        // Built-in avatar example
        if let blueAvatar = BuiltInAvatars.avatar(for: "blue_circle") {
            UserAvatarView(
                avatarType: .builtIn,
                avatarId: "blue_circle",
                photoURL: nil,
                displayName: "John Doe",
                size: 80,
                showOnlineIndicator: true,
                isOnline: true
            )
        }
        
        // Fallback initials example
        UserAvatarView(
            avatarType: nil,
            avatarId: nil,
            photoURL: nil,
            displayName: "Alice Smith",
            size: 80,
            showOnlineIndicator: true,
            isOnline: false
        )
        
        // Custom photo example (would need real URL)
        UserAvatarView(
            avatarType: .custom,
            avatarId: nil,
            photoURL: "https://example.com/photo.jpg",
            displayName: "Bob Jones",
            size: 80
        )
    }
    .padding()
}

