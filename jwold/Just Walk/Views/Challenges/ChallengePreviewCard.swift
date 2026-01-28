//
//  ChallengePreviewCard.swift
//  Just Walk
//
//  Dashboard widget showing active challenge or featured available challenge.
//

import SwiftUI

struct ChallengePreviewCard: View {
    @ObservedObject private var challengeManager = ChallengeManager.shared

    var onTap: () -> Void = {}

    private var displayChallenge: Challenge? {
        // Priority: Show first active challenge, then first available
        if let activeProgress = challengeManager.activeChallenges.first,
           let challenge = challengeManager.getChallenge(byId: activeProgress.challengeId) {
            return challenge
        }
        return challengeManager.availableChallenges.first
    }

    private var displayProgress: ChallengeProgress? {
        challengeManager.activeChallenges.first
    }

    private var isActive: Bool {
        displayProgress?.status == .active
    }

    var body: some View {
        if let challenge = displayChallenge {
            Button(action: onTap) {
                HStack(spacing: 12) {
                    // Icon
                    ZStack {
                        Circle()
                            .fill(iconColor(for: challenge).opacity(0.15))
                            .frame(width: 48, height: 48)

                        Image(systemName: challenge.iconName)
                            .font(.system(size: 20, weight: .medium))
                            .foregroundStyle(iconColor(for: challenge))
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text(isActive ? "Active Challenge" : "Challenge Available")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(isActive ? Color(hex: "00C7BE") : .secondary)

                        Text(challenge.title)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.primary)
                            .lineLimit(1)

                        if isActive, let progress = displayProgress {
                            // Progress bar
                            GeometryReader { geometry in
                                ZStack(alignment: .leading) {
                                    RoundedRectangle(cornerRadius: 2)
                                        .fill(Color(.systemGray5))
                                        .frame(height: 4)

                                    RoundedRectangle(cornerRadius: 2)
                                        .fill(Color(hex: "00C7BE"))
                                        .frame(width: geometry.size.width * progress.progressPercentage(for: challenge), height: 4)
                                }
                            }
                            .frame(height: 4)
                        } else {
                            // Duration preview
                            Text(challenge.durationDescription)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .regular))
                        .foregroundStyle(Color(.tertiaryLabel))
                }
                .padding(12)
                .background(Color(.systemGray6))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
    }

    private func iconColor(for challenge: Challenge) -> Color {
        switch challenge.type {
        case .seasonal:
            return Color(hex: "FF9500")
        case .weekly:
            return Color(hex: "00C7BE")
        case .quick:
            return Color(hex: "34C759")
        }
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 16) {
        ChallengePreviewCard()
    }
    .padding()
}
