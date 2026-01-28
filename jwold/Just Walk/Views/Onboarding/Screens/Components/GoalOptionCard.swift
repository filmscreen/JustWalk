//
//  GoalOptionCard.swift
//  Just Walk
//
//  Created by Claude on 1/22/26.
//

import SwiftUI

struct GoalOptionCard: View {
    let emoji: String
    let title: String
    let subtitle: String
    let isSuggested: Bool
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 14) {
                // Emoji
                Text(emoji)
                    .font(.system(size: 24))
                    .frame(width: 32)

                // Title + Subtitle
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 8) {
                        Text(title)
                            .font(.subheadline.weight(.semibold))

                        if isSuggested {
                            Text("SUGGESTED")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color(hex: "34C759"))
                                .clipShape(Capsule())
                        }
                    }

                    Text(subtitle)
                        .font(.caption)
                        .opacity(0.75)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                // Checkmark when selected
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 14, weight: .bold))
                }
            }
            .foregroundStyle(isSelected ? .blue : .white)
            .padding(16)
            .background(isSelected ? .white : Color.white.opacity(0.15))
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    ZStack {
        LinearGradient(
            colors: [.blue, .cyan],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()

        VStack(spacing: 12) {
            GoalOptionCard(
                emoji: "🌱",
                title: "4,000 steps",
                subtitle: "Perfect for getting started",
                isSuggested: true,
                isSelected: true,
                onTap: {}
            )

            GoalOptionCard(
                emoji: "🌿",
                title: "6,000 steps",
                subtitle: "A solid daily habit",
                isSuggested: false,
                isSelected: false,
                onTap: {}
            )
        }
        .padding(.horizontal, 24)
    }
}
