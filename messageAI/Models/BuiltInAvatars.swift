//
//  BuiltInAvatars.swift
//  messageAI
//
//  Created by MessageAI Team
//  Built-in avatar options for profile pictures
//

import SwiftUI

/// Built-in avatar definition
struct BuiltInAvatar: Identifiable, Equatable {
    let id: String
    let name: String
    let type: AvatarDisplayType
    
    enum AvatarDisplayType: Equatable {
        case colorCircle(Color)
        case gradient(Color, Color)
        case symbol(String, Color)
    }
}

/// Collection of built-in avatars
struct BuiltInAvatars {
    static let all: [BuiltInAvatar] = [
        // Solid color circles
        BuiltInAvatar(id: "blue_circle", name: "Blue Circle", type: .colorCircle(.blue)),
        BuiltInAvatar(id: "red_circle", name: "Red Circle", type: .colorCircle(.red)),
        BuiltInAvatar(id: "green_circle", name: "Green Circle", type: .colorCircle(.green)),
        BuiltInAvatar(id: "purple_circle", name: "Purple Circle", type: .colorCircle(.purple)),
        BuiltInAvatar(id: "orange_circle", name: "Orange Circle", type: .colorCircle(.orange)),
        BuiltInAvatar(id: "pink_circle", name: "Pink Circle", type: .colorCircle(.pink)),
        BuiltInAvatar(id: "teal_circle", name: "Teal Circle", type: .colorCircle(.teal)),
        BuiltInAvatar(id: "indigo_circle", name: "Indigo Circle", type: .colorCircle(.indigo)),
        
        // Gradient circles
        BuiltInAvatar(id: "blue_purple_gradient", name: "Blue-Purple Gradient", type: .gradient(.blue, .purple)),
        BuiltInAvatar(id: "orange_red_gradient", name: "Orange-Red Gradient", type: .gradient(.orange, .red)),
        BuiltInAvatar(id: "green_teal_gradient", name: "Green-Teal Gradient", type: .gradient(.green, .teal)),
        BuiltInAvatar(id: "pink_purple_gradient", name: "Pink-Purple Gradient", type: .gradient(.pink, .purple)),
        
        // SF Symbol based avatars
        BuiltInAvatar(id: "person_symbol", name: "Person", type: .symbol("person.fill", .blue)),
        BuiltInAvatar(id: "star_symbol", name: "Star", type: .symbol("star.fill", .yellow)),
        BuiltInAvatar(id: "heart_symbol", name: "Heart", type: .symbol("heart.fill", .red)),
        BuiltInAvatar(id: "moon_symbol", name: "Moon", type: .symbol("moon.stars.fill", .purple)),
        BuiltInAvatar(id: "bolt_symbol", name: "Bolt", type: .symbol("bolt.fill", .orange)),
        BuiltInAvatar(id: "leaf_symbol", name: "Leaf", type: .symbol("leaf.fill", .green)),
        BuiltInAvatar(id: "flame_symbol", name: "Flame", type: .symbol("flame.fill", .orange)),
        BuiltInAvatar(id: "sparkles_symbol", name: "Sparkles", type: .symbol("sparkles", .yellow))
    ]
    
    /// Get avatar by ID
    static func avatar(for id: String) -> BuiltInAvatar? {
        return all.first { $0.id == id }
    }
}

/// View that renders a built-in avatar
struct BuiltInAvatarView: View {
    let avatar: BuiltInAvatar
    let size: CGFloat
    
    var body: some View {
        ZStack {
            // Background circle
            switch avatar.type {
            case .colorCircle(let color):
                Circle()
                    .fill(color)
                    .frame(width: size, height: size)
                
            case .gradient(let start, let end):
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [start, end],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: size, height: size)
                
            case .symbol(_, let color):
                Circle()
                    .fill(color)
                    .frame(width: size, height: size)
            }
            
            // Symbol overlay (if applicable)
            if case .symbol(let symbolName, _) = avatar.type {
                Image(systemName: symbolName)
                    .font(.system(size: size * 0.5))
                    .foregroundStyle(.white)
            }
        }
    }
}

#Preview {
    ScrollView {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 80))], spacing: 16) {
            ForEach(BuiltInAvatars.all) { avatar in
                VStack {
                    BuiltInAvatarView(avatar: avatar, size: 60)
                    Text(avatar.name)
                        .font(.caption2)
                        .multilineTextAlignment(.center)
                }
            }
        }
        .padding()
    }
}

