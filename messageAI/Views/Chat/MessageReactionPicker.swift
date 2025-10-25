//
//  MessageReactionPicker.swift
//  messageAI
//
//  Emoji reaction picker for messages
//  Long press on a message to show this picker
//

import SwiftUI

/// Emoji reaction picker shown on long press
struct MessageReactionPicker: View {
    let onReactionSelected: (String) -> Void

    // Standard emoji reactions with sentiment mapping
    private let reactions: [(emoji: String, sentiment: ReactionSentiment)] = [
        ("👍", .positive),    // Thumbs up
        ("❤️", .positive),    // Heart
        ("😂", .positive),    // Laugh
        ("😮", .neutral),     // Surprised
        ("😢", .negative),    // Sad
        ("😤", .negative)     // Frustrated/Angry
    ]

    var body: some View {
        HStack(spacing: 16) {
            ForEach(reactions, id: \.emoji) { reaction in
                Button(action: {
                    onReactionSelected(reaction.emoji)
                }) {
                    Text(reaction.emoji)
                        .font(.system(size: 32))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)  // Increased from 12 to 16 to prevent clipping
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(.ultraThinMaterial)
                .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
        )
    }
}

/// Sentiment value for each emoji reaction
enum ReactionSentiment: String, Codable {
    case positive
    case neutral
    case negative

    /// Numerical sentiment score for aggregation
    var score: Double {
        switch self {
        case .positive: return 1.0
        case .neutral: return 0.0
        case .negative: return -1.0
        }
    }
}

/// Map emoji to sentiment score
/// - Parameter emoji: Emoji string
/// - Returns: Sentiment score (-1.0 to 1.0)
func emojiToSentiment(_ emoji: String) -> Double {
    let mapping: [String: Double] = [
        // Positive reactions
        "👍": 1.0,
        "❤️": 1.0,
        "🎉": 1.0,
        "😂": 0.8,
        "😊": 0.8,
        "👏": 1.0,
        "🙌": 1.0,
        "✅": 0.6,

        // Neutral reactions
        "😮": 0.0,
        "🤔": 0.0,
        "👀": 0.0,

        // Negative reactions
        "😢": -0.8,
        "😤": -1.0,
        "😡": -1.0,
        "👎": -1.0,
        "😞": -0.8,
        "😰": -0.6
    ]

    return mapping[emoji] ?? 0.0
}

#Preview {
    VStack {
        Spacer()
        MessageReactionPicker { emoji in
            print("Selected: \(emoji)")
        }
        Spacer()
    }
    .background(Color(.systemBackground))
}
