//
//  ChallengeDetailSheet.swift
//  Just Walk
//
//  Challenge details and progress sheet.
//

import SwiftUI

struct ChallengeDetailSheet: View {
    let challenge: Challenge
    @ObservedObject private var challengeManager = ChallengeManager.shared

    var onDismiss: () -> Void = {}

    private var progress: ChallengeProgress? {
        challengeManager.getProgress(forChallengeId: challenge.id)
    }

    private var isActive: Bool {
        progress?.status == .active
    }

    private var isCompleted: Bool {
        challengeManager.isChallengeCompleted(challenge.id)
    }

    private var progressPercentage: Double {
        guard let progress = progress else { return 0 }
        return progress.progressPercentage(for: challenge)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Hero section
                    heroSection

                    // Progress section (if active)
                    if isActive, let progress = progress {
                        progressSection(progress)
                    }

                    // Requirements section
                    requirementsSection

                    // Rewards section
                    rewardsSection

                    // Action button
                    if !isCompleted {
                        actionButton
                    }

                    Spacer(minLength: 40)
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle(challenge.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        onDismiss()
                    }
                }
            }
        }
    }

    // MARK: - Hero Section

    private var heroSection: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(iconColor.opacity(0.15))
                    .frame(width: 80, height: 80)

                Image(systemName: challenge.iconName)
                    .font(.system(size: 36, weight: .medium))
                    .foregroundStyle(iconColor)
            }

            VStack(spacing: 4) {
                HStack(spacing: 6) {
                    Text(challenge.type.displayName)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)

                    Text("·")
                        .foregroundStyle(.tertiary)

                    difficultyView
                }

                Text(challenge.description)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            if isCompleted {
                HStack(spacing: 4) {
                    Image(systemName: "checkmark.circle.fill")
                    Text("Completed")
                }
                .font(.subheadline.weight(.medium))
                .foregroundStyle(Color(hex: "34C759"))
            }
        }
        .padding(.vertical, 16)
    }

    private var difficultyView: some View {
        HStack(spacing: 2) {
            ForEach(1...5, id: \.self) { level in
                Image(systemName: level <= challenge.difficultyLevel ? "star.fill" : "star")
                    .font(.system(size: 10))
                    .foregroundStyle(level <= challenge.difficultyLevel ? Color(hex: "FFD60A") : Color(.tertiaryLabel))
            }
        }
    }

    // MARK: - Progress Section

    private func progressSection(_ progress: ChallengeProgress) -> some View {
        VStack(spacing: 12) {
            HStack {
                Text("Progress")
                    .font(.headline)
                Spacer()
            }

            VStack(spacing: 8) {
                // Progress bar
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color(.systemGray5))
                            .frame(height: 8)

                        RoundedRectangle(cornerRadius: 4)
                            .fill(progressPercentage >= 1.0 ? Color(hex: "34C759") : Color(hex: "00C7BE"))
                            .frame(width: geometry.size.width * min(1.0, progressPercentage), height: 8)
                    }
                }
                .frame(height: 8)

                HStack {
                    if challenge.isQuickChallenge {
                        Text("\(progress.totalSteps.formatted()) / \(challenge.dailyStepTarget.formatted()) steps")
                        Spacer()
                        if let timeRemaining = progress.quickChallengeTimeRemainingFormatted {
                            HStack(spacing: 4) {
                                Image(systemName: "timer")
                                    .font(.caption)
                                Text(timeRemaining)
                            }
                        }
                    } else {
                        Text("\(progress.daysCompleted) / \(challenge.targetDays) days")
                        Spacer()
                        Text("\(Int(progressPercentage * 100))%")
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)

                // Daily progress list for multi-day challenges
                if !challenge.isQuickChallenge && !progress.dailyProgress.isEmpty {
                    VStack(spacing: 8) {
                        ForEach(progress.dailyProgress.sorted(by: { $0.date > $1.date }).prefix(7)) { daily in
                            HStack {
                                Text(formatDate(daily.date))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)

                                Spacer()

                                Text("\(daily.steps.formatted()) steps")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)

                                Image(systemName: daily.goalMet ? "checkmark.circle.fill" : "circle")
                                    .font(.caption)
                                    .foregroundStyle(daily.goalMet ? Color(hex: "34C759") : Color(.tertiaryLabel))
                            }
                        }
                    }
                    .padding(12)
                    .background(Color(.secondarySystemGroupedBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }
            .padding(16)
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }

    // MARK: - Requirements Section

    private var requirementsSection: some View {
        VStack(spacing: 12) {
            HStack {
                Text("Requirements")
                    .font(.headline)
                Spacer()
            }

            VStack(spacing: 0) {
                requirementRow(
                    icon: "figure.walk",
                    title: "Daily Target",
                    value: "\(challenge.dailyStepTarget.formatted()) steps"
                )

                Divider().padding(.leading, 44)

                requirementRow(
                    icon: "calendar",
                    title: "Duration",
                    value: challenge.durationDescription
                )

                if !challenge.isQuickChallenge {
                    Divider().padding(.leading, 44)

                    requirementRow(
                        icon: "calendar.badge.clock",
                        title: "Qualifying Days",
                        value: challenge.requiredDaysPattern.displayName
                    )
                }

                if challenge.daysUntilExpiration > 0 && challenge.daysUntilExpiration < 365 {
                    Divider().padding(.leading, 44)

                    requirementRow(
                        icon: "hourglass",
                        title: "Expires In",
                        value: "\(challenge.daysUntilExpiration) day\(challenge.daysUntilExpiration == 1 ? "" : "s")"
                    )
                }
            }
            .padding(.vertical, 4)
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }

    private func requirementRow(icon: String, title: String, value: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundStyle(.secondary)
                .frame(width: 24)

            Text(title)
                .font(.subheadline)
                .foregroundStyle(.primary)

            Spacer()

            Text(value)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    // MARK: - Rewards Section

    private var rewardsSection: some View {
        Group {
            // Only show rewards section if there's a badge
            if challenge.badgeId != nil {
                VStack(spacing: 12) {
                    HStack {
                        Text("Rewards")
                            .font(.headline)
                        Spacer()
                    }

                    VStack(spacing: 4) {
                        Image(systemName: "medal.fill")
                            .font(.system(size: 24))
                            .foregroundStyle(Color(hex: "FFD60A"))

                        Text("Badge")
                            .font(.title3.weight(.semibold))

                        Text("Exclusive")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color(.secondarySystemGroupedBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
        }
    }

    // MARK: - Action Button

    private var actionButton: some View {
        Group {
            if isActive {
                Button {
                    challengeManager.abandonChallenge(challenge.id)
                    onDismiss()
                } label: {
                    Text("Abandon Challenge")
                        .font(.headline)
                        .foregroundStyle(.red)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color(.secondarySystemGroupedBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            } else {
                Button {
                    if challengeManager.startChallenge(challenge) {
                        HapticService.shared.playSuccess()
                    }
                } label: {
                    Text("Start Challenge")
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color(hex: "00C7BE"))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
        }
    }

    // MARK: - Helpers

    private var iconColor: Color {
        switch challenge.type {
        case .seasonal:
            return Color(hex: "FF9500")
        case .weekly:
            return Color(hex: "00C7BE")
        case .quick:
            return Color(hex: "34C759")
        }
    }

    private func formatDate(_ date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) {
            return "Today"
        } else if calendar.isDateInYesterday(date) {
            return "Yesterday"
        } else {
            let formatter = DateFormatter()
            formatter.dateFormat = "MMM d"
            return formatter.string(from: date)
        }
    }
}

// MARK: - Preview

#Preview {
    ChallengeDetailSheet(
        challenge: Challenge(
            id: "weekend_warrior",
            type: .weekly,
            title: "Weekend Warrior",
            description: "Hit your step goal both Saturday and Sunday.",
            iconName: "figure.run",
            dailyStepTarget: 12500,
            targetDays: 2,
            requiredDaysPattern: .weekendsOnly,
            startDate: Date(),
            endDate: Date().addingTimeInterval(86400 * 3),
            durationHours: nil,
            badgeId: nil,
            difficultyLevel: 3
        )
    )
}
