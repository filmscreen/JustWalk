//
//  RankTeaserCard.swift
//  Just Walk
//
//  Subtle teaser card shown when user is approaching their first rank-up.
//  Creates anticipation without revealing confusing rank jargon.
//

import SwiftUI

struct RankTeaserCard: View {
    @ObservedObject private var rankManager = RankManager.shared

    let onTap: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            // Sparkles icon in teal
            Image(systemName: "sparkles")
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(Color(hex: "00C7BE"))

            // Text content
            VStack(alignment: .leading, spacing: 2) {
                Text("Keep walking...")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.primary)

                Text(teaserText)
                    .font(.system(size: 13, weight: .regular))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            // Dismiss button
            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.tertiary)
                    .frame(width: 28, height: 28)
                    .background(Color.primary.opacity(0.05))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .frame(height: 56)
        .background(JWDesign.Colors.secondaryBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .contentShape(Rectangle())
        .onTapGesture {
            onTap()
        }
    }

    // MARK: - Computed Properties

    private var teaserText: String {
        if let daysRemaining = rankManager.daysToStrider(), daysRemaining > 0 {
            return "Something unlocks at Day \(7)"
        }
        return "Something special awaits"
    }
}

// MARK: - Previews

#Preview("Teaser Card") {
    VStack {
        RankTeaserCard(
            onTap: { print("Tapped body") },
            onDismiss: { print("Dismissed") }
        )
    }
    .padding()
    .background(Color(.systemGroupedBackground))
}
