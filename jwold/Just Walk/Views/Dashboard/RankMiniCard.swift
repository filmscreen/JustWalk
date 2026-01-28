//
//  RankMiniCard.swift
//  Just Walk
//
//  Compact rank indicator card for the Today screen.
//  Shows current walker rank and days as a walker.
//

import SwiftUI

struct RankMiniCard: View {
    @ObservedObject private var rankManager = RankManager.shared

    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // Icon circle (40pt with 20pt icon)
                ZStack {
                    Circle()
                        .fill(rankColor.opacity(0.10))
                        .frame(width: 40, height: 40)

                    Image(systemName: rankManager.profile.currentRank.icon)
                        .font(.system(size: 20))
                        .foregroundStyle(rankColor)
                }

                // Text content
                VStack(alignment: .leading, spacing: 2) {
                    // Rank title (17pt Semibold)
                    Text(rankManager.profile.currentRank.title)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(titleColor)

                    // Progress subtitle (14pt Regular)
                    Text(progressSubtitle)
                        .font(.system(size: 14, weight: .regular))
                        .foregroundStyle(.secondary)
                }

                Spacer()

                // Chevron (14pt, secondary)
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .regular))
                    .foregroundStyle(Color(hex: "8E8E93"))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 16)
            .frame(height: 72)
            .background(JWDesign.Colors.secondaryBackground)
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Computed Properties

    private var isJustWalker: Bool {
        rankManager.profile.currentRank == .justWalker
    }

    private var rankColor: Color {
        rankManager.profile.currentRank.color
    }

    private var titleColor: Color {
        isJustWalker ? Color(hex: "FFD700") : .primary
    }

    /// Subtitle showing progress to next rank
    private var progressSubtitle: String {
        // Check if at max rank
        guard let nextRank = rankManager.profile.currentRank.nextRank else {
            return "The journey is the destination."
        }

        // Get closest path to next rank
        guard let closest = rankManager.closestPathToNextRank() else {
            return "Keep walking!"
        }

        let remaining = Int(closest.required - closest.current)

        switch closest.metric {
        case "day streak":
            return "\(remaining) days to \(nextRank.title)"
        case "walks":
            return "\(remaining) walks to \(nextRank.title)"
        case "miles":
            return "\(remaining) mi to \(nextRank.title)"
        default:
            return "Keep walking!"
        }
    }
}

// MARK: - Previews

#Preview("Walker") {
    VStack {
        RankMiniCard(onTap: { print("Tapped") })
    }
    .padding()
    .background(Color(.systemGroupedBackground))
}
