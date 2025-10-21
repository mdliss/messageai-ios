//
//  TypingIndicatorView.swift
//  messageAI
//
//  Created by MessageAI Team
//  Animated typing indicator view
//

import SwiftUI

struct TypingIndicatorView: View {
    let typingUsers: [String]
    let participantNames: [String: String]
    
    @State private var animationPhase = 0
    
    var body: some View {
        if !typingUsers.isEmpty {
            HStack(spacing: 8) {
                // Avatar
                Circle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 32, height: 32)
                    .overlay {
                        Image(systemName: "keyboard")
                            .font(.caption)
                            .foregroundStyle(.gray)
                    }
                
                VStack(alignment: .leading, spacing: 2) {
                    // Typing text
                    Text(typingText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    // Animated dots
                    HStack(spacing: 4) {
                        ForEach(0..<3) { index in
                            Circle()
                                .fill(Color.gray)
                                .frame(width: 6, height: 6)
                                .opacity(animationPhase == index ? 1.0 : 0.3)
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color(.systemGray6))
                    .cornerRadius(16)
                }
                
                Spacer()
            }
            .padding(.horizontal)
            .padding(.vertical, 4)
            .onAppear {
                startAnimation()
            }
        }
    }
    
    // MARK: - Typing Text
    
    private var typingText: String {
        guard !typingUsers.isEmpty else { return "" }
        
        let names = typingUsers.compactMap { userId in
            participantNames[userId] ?? "someone"
        }
        
        if names.count == 1 {
            return "\(names[0]) is typing"
        } else if names.count == 2 {
            return "\(names[0]), \(names[1]) are typing"
        } else if names.count > 2 {
            let firstTwo = names.prefix(2).joined(separator: ", ")
            let remaining = names.count - 2
            return "\(firstTwo), and \(remaining) \(remaining == 1 ? "other" : "others") are typing"
        }
        
        return ""
    }
    
    // MARK: - Animation
    
    private func startAnimation() {
        Timer.scheduledTimer(withTimeInterval: 0.4, repeats: true) { _ in
            withAnimation(.easeInOut(duration: 0.3)) {
                animationPhase = (animationPhase + 1) % 3
            }
        }
    }
}

#Preview {
    VStack {
        TypingIndicatorView(
            typingUsers: ["user1"],
            participantNames: ["user1": "Alice"]
        )
        
        TypingIndicatorView(
            typingUsers: ["user1", "user2"],
            participantNames: ["user1": "Alice", "user2": "Bob"]
        )
        
        TypingIndicatorView(
            typingUsers: ["user1", "user2", "user3", "user4"],
            participantNames: [
                "user1": "Alice",
                "user2": "Bob",
                "user3": "Carol",
                "user4": "David"
            ]
        )
    }
}

