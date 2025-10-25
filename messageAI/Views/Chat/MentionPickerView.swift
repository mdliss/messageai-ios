//
//  MentionPickerView.swift
//  messageAI
//
//  Simple mention picker for selecting conversation participants
//

import SwiftUI

struct MentionPickerView: View {
    let participantDetails: [String: ParticipantDetail]
    let currentUserId: String
    let onSelect: (String, String) -> Void  // userId, displayName

    private var sortedParticipants: [(String, ParticipantDetail)] {
        participantDetails
            .filter { $0.key != currentUserId }
            .sorted { $0.value.displayName < $1.value.displayName }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(sortedParticipants, id: \.0) { userId, participant in
                Button {
                    onSelect(userId, participant.displayName)
                } label: {
                    HStack(spacing: 12) {
                        // Avatar with proper profile picture
                        UserAvatarView(
                            participant: participant,
                            size: 32
                        )

                        Text(participant.displayName)
                            .font(.body)
                            .foregroundStyle(.primary)

                        Spacer()
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(Color(.systemBackground))
                }
                .buttonStyle(.plain)

                if userId != sortedParticipants.last?.0 {
                    Divider()
                        .padding(.leading, 60)
                }
            }
        }
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 2)
        .padding(.horizontal, 8)
    }
}

#Preview {
    MentionPickerView(
        participantDetails: [
            "user1": ParticipantDetail(displayName: "Alice Smith"),
            "user2": ParticipantDetail(displayName: "Bob Jones")
        ],
        currentUserId: "current",
        onSelect: { userId, name in
            print("Selected: \(name)")
        }
    )
}
