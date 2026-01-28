//
//  AvailableChallengeCard.swift
//  Just Walk
//
//  Compact row for available challenges (follows RankMiniCard pattern)
//

import SwiftUI

struct AvailableChallengeCard: View {
    let challenge: Challenge
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

                // Title and subtitle
                VStack(alignment: .leading, spacing: 2) {
                    Text(challenge.title)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)

                    Text(subtitleText)
                        .font(.system(size: 13, weight: .regular))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer()

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

    private var subtitleText: String {
        if challenge.isQuickChallenge {
            return "\(challenge.dailyStepTarget.formatted()) steps in \(challenge.durationDescription)"
        } else {
            return "\(challenge.dailyStepTarget.formatted()) steps daily"
        }
    }
}

#Preview {
    VStack(spacing: 12) {
        AvailableChallengeCard(
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
            onTap: {}
        )

        AvailableChallengeCard(
            challenge: Challenge(
                id: "preview-quick",
                type: .quick,
                title: "Lunch Break Sprint",
                description: "Get 2,000 steps in 1 hour",
                iconName: "bolt.fill",
                dailyStepTarget: 2000,
                targetDays: 1,
                requiredDaysPattern: .allDays,
                startDate: Date(),
                endDate: Date().addingTimeInterval(86400),
                durationHours: 1,
                badgeId: nil,
                difficultyLevel: 1
            ),
            onTap: {}
        )
    }
    .padding()
    .background(Color(.systemGroupedBackground))
}
