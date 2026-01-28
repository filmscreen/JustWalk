//
//  ActiveChallengeCard.swift
//  Just Walk
//
//  Expanded card showing active challenge progress
//

import SwiftUI

struct ActiveChallengeCard: View {
    let challenge: Challenge
    let progress: ChallengeProgress
    let onTap: () -> Void

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 12) {
                // Header row
                HStack(spacing: 12) {
                    // Icon with circular background
                    ZStack {
                        Circle()
                            .fill(iconColor.opacity(colorScheme == .dark ? 0.15 : 0.08))
                            .frame(width: 40, height: 40)
                        Image(systemName: challenge.iconName)
                            .font(.system(size: 18))
                            .foregroundStyle(iconColor)
                    }

                    // Title and subtitle
                    VStack(alignment: .leading, spacing: 2) {
                        Text(challenge.title)
                            .font(.system(size: 17, weight: .semibold))
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

                // Progress section
                VStack(alignment: .leading, spacing: 8) {
                    // Progress label
                    HStack {
                        Text(progressLabel)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(.secondary)

                        Spacer()

                        // Progress fraction with checkmark
                        HStack(spacing: 4) {
                            Text(progressFraction)
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(.secondary)

                            if progressPercentage >= 1.0 {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 13))
                                    .foregroundStyle(Color(hex: "34C759"))
                            }
                        }
                    }

                    // Progress bar
                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 3)
                                .fill(Color(.systemGray5))
                                .frame(height: 6)

                            RoundedRectangle(cornerRadius: 3)
                                .fill(progressBarColor)
                                .frame(width: geometry.size.width * min(1.0, progressPercentage), height: 6)
                        }
                    }
                    .frame(height: 6)
                }

                // Motivational message
                Text(motivationalMessage)
                    .font(.system(size: 13, weight: .regular))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .padding(16)
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

    private var progressBarColor: Color {
        Color(hex: "00C7BE") // Teal for progress bar
    }

    private var subtitleText: String {
        if challenge.isQuickChallenge {
            return "\(challenge.dailyStepTarget.formatted()) steps in \(challenge.durationDescription)"
        } else {
            return "\(challenge.dailyStepTarget.formatted()) steps daily"
        }
    }

    private var progressPercentage: Double {
        progress.progressPercentage(for: challenge)
    }

    private var progressLabel: String {
        if challenge.isQuickChallenge {
            if let timeRemaining = progress.quickChallengeTimeRemainingFormatted {
                return timeRemaining
            }
            return "In progress"
        } else {
            return "Day \(progress.daysCompleted + 1) of \(challenge.targetDays)"
        }
    }

    private var progressFraction: String {
        if challenge.isQuickChallenge {
            return "\(progress.totalSteps.formatted())/\(challenge.dailyStepTarget.formatted())"
        } else {
            return "\(progress.daysCompleted)/\(challenge.targetDays)"
        }
    }

    private var motivationalMessage: String {
        let percentage = progressPercentage

        if challenge.isQuickChallenge {
            if percentage >= 1.0 {
                return "Challenge complete! Great work!"
            } else if percentage >= 0.75 {
                return "Almost there! Keep pushing!"
            } else if percentage >= 0.5 {
                return "Halfway there! You've got this!"
            } else if percentage >= 0.25 {
                return "Great start! Keep moving!"
            } else {
                return "Let's get those steps in!"
            }
        } else {
            if percentage >= 1.0 {
                return "Challenge complete! Amazing dedication!"
            } else if percentage >= 0.9 {
                return "Final stretch! Don't stop now!"
            } else if percentage >= 0.75 {
                return "Three quarters done! Keep it alive!"
            } else if percentage >= 0.5 {
                return "Halfway there! Stay consistent!"
            } else if percentage > 0 && progress.daysCompleted == progress.dailyProgress.count {
                return "Perfect so far! Keep it alive."
            } else if percentage > 0 {
                return "You're making progress! Stay consistent."
            } else {
                return "Day 1 starts now! Let's go!"
            }
        }
    }
}

#Preview {
    VStack(spacing: 16) {
        ActiveChallengeCard(
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
                dailyProgress: (0..<15).map { day in
                    DailyProgress(
                        date: Date().addingTimeInterval(-86400 * Double(14 - day)),
                        steps: 10500,
                        goalMet: true,
                        lastUpdated: Date()
                    )
                },
                quickChallengeStartTime: nil,
                quickChallengeEndTime: nil
            ),
            onTap: {}
        )
    }
    .padding()
    .background(Color(.systemGroupedBackground))
}
