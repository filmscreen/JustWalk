//
//  ChallengeProgressRow.swift
//  Just Walk
//
//  Reusable row component for displaying challenge progress.
//

import SwiftUI

struct ChallengeProgressRow: View {
    let challenge: Challenge
    let progress: ChallengeProgress?
    var onTap: () -> Void = {}

    private var progressPercentage: Double {
        guard let progress = progress else { return 0 }
        return progress.progressPercentage(for: challenge)
    }

    private var isActive: Bool {
        progress?.status == .active
    }

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // Challenge icon
                ZStack {
                    Circle()
                        .fill(iconColor.opacity(0.15))
                        .frame(width: 44, height: 44)

                    Image(systemName: challenge.iconName)
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(iconColor)
                }

                VStack(alignment: .leading, spacing: 4) {
                    // Title and type
                    HStack(spacing: 6) {
                        Text(challenge.title)
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.primary)
                            .lineLimit(1)

                        if isActive {
                            Text("Active")
                                .font(.caption2.weight(.medium))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color(hex: "00C7BE"))
                                .clipShape(Capsule())
                        }
                    }

                    // Progress info
                    if let progress = progress, isActive {
                        if challenge.isQuickChallenge {
                            // Quick challenge: show time remaining
                            HStack(spacing: 4) {
                                Image(systemName: "timer")
                                    .font(.caption2)
                                Text(progress.quickChallengeTimeRemainingFormatted ?? "")
                                    .font(.caption)
                            }
                            .foregroundStyle(.secondary)
                        } else {
                            // Multi-day: show days completed
                            Text("\(progress.daysCompleted)/\(challenge.targetDays) days completed")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    } else {
                        // Not started: show duration
                        Text(challenge.durationDescription)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    // Progress bar for active challenges
                    if isActive {
                        GeometryReader { geometry in
                            ZStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 2)
                                    .fill(Color(.systemGray5))
                                    .frame(height: 4)

                                RoundedRectangle(cornerRadius: 2)
                                    .fill(progressColor)
                                    .frame(width: geometry.size.width * progressPercentage, height: 4)
                            }
                        }
                        .frame(height: 4)
                    }
                }

                Spacer()

                // Chevron
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .regular))
                    .foregroundStyle(Color(.tertiaryLabel))
            }
            .padding(.vertical, 10)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

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

    private var progressColor: Color {
        if progressPercentage >= 1.0 {
            return Color(hex: "34C759") // Green - completed
        }
        return Color(hex: "00C7BE") // Teal - in progress
    }
}

// MARK: - Preview

#Preview("Available Challenge") {
    ChallengeProgressRow(
        challenge: Challenge(
            id: "weekend_warrior",
            type: .weekly,
            title: "Weekend Warrior",
            description: "Hit your goal both weekend days",
            iconName: "figure.run",
            dailyStepTarget: 12500,
            targetDays: 2,
            requiredDaysPattern: .weekendsOnly,
            startDate: Date(),
            endDate: Date().addingTimeInterval(86400 * 3),
            durationHours: nil,
            badgeId: nil,
            difficultyLevel: 3
        ),
        progress: nil
    )
    .padding()
}

#Preview("Active Challenge") {
    ChallengeProgressRow(
        challenge: Challenge(
            id: "speed_demon",
            type: .quick,
            title: "Speed Demon",
            description: "5,000 steps in 3 hours",
            iconName: "bolt.fill",
            dailyStepTarget: 5000,
            targetDays: 1,
            requiredDaysPattern: .allDays,
            startDate: Date(),
            endDate: Date().addingTimeInterval(86400),
            durationHours: 3,
            badgeId: nil,
            difficultyLevel: 2
        ),
        progress: ChallengeProgress(
            challengeId: "speed_demon",
            status: .active,
            startedAt: Date().addingTimeInterval(-3600),
            dailyProgress: [DailyProgress(date: Date(), steps: 2500, goalMet: false)],
            quickChallengeStartTime: Date().addingTimeInterval(-3600),
            quickChallengeEndTime: Date().addingTimeInterval(7200)
        )
    )
    .padding()
}
