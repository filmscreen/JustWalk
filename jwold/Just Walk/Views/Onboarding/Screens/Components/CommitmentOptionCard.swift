//
//  CommitmentOptionCard.swift
//  Just Walk
//
//  Created by Claude on 1/22/26.
//

import SwiftUI

struct CommitmentOptionCard: View {
    let icon: String
    let iconColor: Color
    let title: String
    let subtitle: String
    let identityStatement: String?
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 14) {
                // Icon in colored circle
                ZStack {
                    Circle()
                        .fill(iconColor)
                        .frame(width: 36, height: 36)

                    Image(systemName: icon)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white)
                }

                // Title + Subtitle + Identity statement
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.subheadline.weight(.semibold))

                    Text(subtitle)
                        .font(.footnote)
                        .opacity(0.85)

                    if let identity = identityStatement {
                        Text("\"\(identity)\"")
                            .font(.footnote.italic())
                            .opacity(0.75)
                            .padding(.top, 2)
                    }
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
            CommitmentOptionCard(
                icon: "flame.fill",
                iconColor: Color(hex: "FF9500"),
                title: "7-Day Streak",
                subtitle: "Earn the title \"Strider\"",
                identityStatement: "I've found my rhythm.",
                isSelected: true,
                onTap: {}
            )

            CommitmentOptionCard(
                icon: "flame.fill",
                iconColor: Color(hex: "FF9500"),
                title: "30-Day Streak",
                subtitle: "Earn the title \"Wayfarer\"",
                identityStatement: "I'm on a path.",
                isSelected: false,
                onTap: {}
            )

            CommitmentOptionCard(
                icon: "rocket.fill",
                iconColor: Color(hex: "00C7BE"),
                title: "Just get started",
                subtitle: "No pressure — I'll explore",
                identityStatement: nil,
                isSelected: false,
                onTap: {}
            )
        }
        .padding(.horizontal, 24)
    }
}
