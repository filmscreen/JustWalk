//
//  ActiveChallengeMiniCard.swift
//  Just Walk
//
//  Ultra-compact card for Today screen (matches RankMiniCard exactly)
//

import SwiftUI

struct ActiveChallengeMiniCard: View {
    let challenge: Challenge
    let progress: ChallengeProgress
    let onTap: () -> Void

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // Icon with circular background
                ZStack {
                    Circle()
                        .fill(iconColor.opacity(colorScheme == .dark ? 0.15 : 0.08))
                        .frame(width: 32, height: 32)
                    Image(systemName: challenge.iconName)
                        .font(.system(size: 16))
                        .foregroundStyle(iconColor)
                }

                // Truncated title
                Text(truncatedTitle)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                Spacer()

                // Progress indicator
                Text(progressText)
                    .font(.system(size: 13, weight: .regular))
                    .foregroundStyle(.secondary)

                // Navigation chevron
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .regular))
                    .foregroundStyle(Color(hex: "8E8E93"))
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 16)
            .background(JWDesign.Colors.secondaryBackground)
            .clipShape(RoundedRectangle(cornerRadius: JWDesign.Radius.card))
            .shadow(color: .black.opacity(0.04), radius: 4, y: 2)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Computed Properties

    private var iconColor: Color {
        switch challenge.type {
        case .seasonal:
            return Color(hex: "FF9500") // Orange
        case .weekly:
            return Color(hex: "00C7BE") // Teal
        case .quick:
            return Color(hex: "34C759") // Green
        }
    }

    private var truncatedTitle: String {
        // Shorten title for mini card if needed
        let words = challenge.title.split(separator: " ")
        if words.count > 2 {
            return words.prefix(2).joined(separator: " ")
        }
        return challenge.title
    }

    private var progressText: String {
        if challenge.isQuickChallenge {
            if let timeRemaining = progress.quickChallengeTimeRemainingFormatted {
                return timeRemaining
            }
            return "\(progress.totalSteps.formatted()) steps"
        } else {
            return "Day \(progress.daysCompleted)/\(challenge.targetDays)"
        }
    }
}

#Preview {
    VStack(spacing: 12) {
        ActiveChallengeMiniCard(
            challenge: Challenge(
                id: "preview-seasonal",
                type: .seasonal,
                title: "January Steps Challenge",
                description: "Hit 10,000 steps every day this month",
                iconName: "flame.fill",
                dailyStepTarget: 10000,
                targetDays: 31,
                requiredDaysPattern: .allDays,
                startDate: Date(),
                endDate: Date().addingTimeInterval(86400 * 31),
                durationHours: nil,
                badgeId: nil,
                difficultyLevel: 3
            ),
            progress: ChallengeProgress(
                id: UUID(),
                challengeId: "preview-seasonal",
                status: .active,
                startedAt: Date().addingTimeInterval(-86400 * 15),
                completedAt: nil,
                dailyProgress: [],
                quickChallengeStartTime: nil,
                quickChallengeEndTime: nil
            ),
            onTap: {}
        )
    }
    .padding()
    .background(Color(.systemGroupedBackground))
}
