//
//  RankIdentityCard.swift
//  Just Walk
//
//  Identity-first rank card for Strider and above.
//  Shows the identity statement as the hero, with rank and progress as context.
//

import SwiftUI

struct RankIdentityCard: View {
    @ObservedObject private var rankManager = RankManager.shared

    let onTap: () -> Void

    // Track first-time view per rank for pulse animation
    @State private var hasAnimated = false

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // Icon circle (44pt with rank icon)
                ZStack {
                    Circle()
                        .fill(rankColor.opacity(0.10))
                        .frame(width: 44, height: 44)

                    Image(systemName: currentRank.icon)
                        .font(.system(size: 22))
                        .foregroundStyle(rankColor)
                }

                // Text content
                VStack(alignment: .leading, spacing: 2) {
                    // Line 1: Identity statement in quotes (17pt Semibold)
                    Text("\"\(currentRank.identityStatement)\"")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(.primary)

                    // Line 2: Rank · Progress (14pt Regular, secondary)
                    Text(subtitleText)
                        .font(.system(size: 14, weight: .regular))
                        .foregroundStyle(.secondary)
                }

                Spacer()

                // Chevron (14pt, tertiary)
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .regular))
                    .foregroundStyle(Color(hex: "8E8E93"))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 16)
            .frame(height: 76)
            .background(JWDesign.Colors.secondaryBackground)
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(.plain)
        .scaleEffect(hasAnimated ? 1.0 : 1.02)
        .onAppear {
            checkFirstTimeAnimation()
        }
    }

    // MARK: - Computed Properties

    private var currentRank: WalkerRank {
        rankManager.profile.currentRank
    }

    private var isJustWalker: Bool {
        currentRank == .justWalker
    }

    private var rankColor: Color {
        currentRank.color
    }

    /// Subtitle showing rank name and progress to next rank
    private var subtitleText: String {
        if isJustWalker {
            return "Just Walker · The journey continues"
        }

        if let progress = rankManager.progressDescription() {
            return "\(currentRank.title) · \(progress)"
        }

        return currentRank.title
    }

    // MARK: - First-Time Animation

    private func checkFirstTimeAnimation() {
        let key = "hasSeenRankIdentityCard_\(currentRank.rawValue)"
        let hasSeen = UserDefaults.standard.bool(forKey: key)

        if !hasSeen {
            // Mark as seen
            UserDefaults.standard.set(true, forKey: key)

            // Start with slight scale up, then animate to normal
            hasAnimated = false
            withAnimation(.easeOut(duration: 0.4).delay(0.3)) {
                hasAnimated = true
            }
        } else {
            hasAnimated = true
        }
    }
}

// MARK: - Previews

#Preview("Strider") {
    VStack {
        RankIdentityCard(onTap: { print("Tapped") })
    }
    .padding()
    .background(Color(.systemGroupedBackground))
}
