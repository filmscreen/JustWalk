//
//  ProgressSummaryCard.swift
//  Just Walk
//
//  Summary stats card for the Progress tab.
//  Shows Total Steps, Distance, Average Daily, and Days Goal Met.
//

import SwiftUI

struct ProgressSummaryCard: View {
    let totalSteps: Int
    let totalDistance: Double // In meters
    let averageDailySteps: Int
    let daysGoalMet: Int
    let totalDays: Int

    // Streak banner props
    var currentStreak: Int = 0
    var longestStreak: Int = 0
    var onStreakTap: () -> Void = {}

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(spacing: 0) {
            // Top row: Total Steps | Distance
            HStack(spacing: 0) {
                statItem(
                    value: formattedSteps(totalSteps),
                    label: "Total Steps",
                    icon: "figure.walk"
                )
                Divider()
                    .frame(height: 50)
                statItem(
                    value: formattedDistance(totalDistance),
                    label: "Distance",
                    icon: "location"
                )
            }

            Divider()

            // Bottom row: Daily Avg | Goals Met
            HStack(spacing: 0) {
                statItem(
                    value: formattedSteps(averageDailySteps),
                    label: "Daily Average",
                    icon: "chart.bar"
                )
                Divider()
                    .frame(height: 50)
                statItem(
                    value: "\(daysGoalMet)/\(totalDays)",
                    label: "Goals Met",
                    icon: "checkmark.circle"
                )
            }

            // Streak banner row
            Divider()

            StreakBannerRow(
                currentStreak: currentStreak,
                longestStreak: longestStreak
            )
            .onTapGesture {
                onStreakTap()
            }
        }
        .padding(.vertical, 12)
        .background(JWDesign.Colors.secondaryBackground)
        .clipShape(RoundedRectangle(cornerRadius: JWDesign.Radius.card))
    }

    // MARK: - Stat Item

    private func statItem(value: String, label: String, icon: String) -> some View {
        VStack(spacing: 4) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 14))
                    .foregroundStyle(Color(hex: "00C7BE"))
                Text(value)
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)
                    .contentTransition(.numericText())
            }
            Text(label)
                .font(.system(size: 13, weight: .regular))
                .foregroundStyle(Color(.secondaryLabel))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
    }

    // MARK: - Formatting

    private func formattedSteps(_ steps: Int) -> String {
        if steps >= 1_000_000 {
            return String(format: "%.1fM", Double(steps) / 1_000_000)
        } else if steps >= 10_000 {
            return String(format: "%.0fK", Double(steps) / 1_000)
        } else if steps >= 1_000 {
            return String(format: "%.1fK", Double(steps) / 1_000)
        }
        return steps.formatted()
    }

    private func formattedDistance(_ meters: Double) -> String {
        let miles = meters * 0.000621371
        if miles >= 100 {
            return String(format: "%.0f mi", miles)
        }
        return String(format: "%.1f mi", miles)
    }
}

// MARK: - Streak Banner Row

private struct StreakBannerRow: View {
    let currentStreak: Int
    let longestStreak: Int

    private var isPersonalBest: Bool {
        currentStreak > 0 && currentStreak >= longestStreak
    }

    private var streakText: String {
        if currentStreak == 0 {
            return "No active streak"
        } else {
            return "\(currentStreak)-day streak"
        }
    }

    private var subtitleText: String? {
        if currentStreak == 0 && longestStreak > 0 {
            return "Longest: \(longestStreak) days"
        } else if isPersonalBest && currentStreak > 0 {
            return "Personal best!"
        } else if longestStreak > currentStreak {
            return "Longest: \(longestStreak) days"
        }
        return nil
    }

    var body: some View {
        HStack(spacing: 12) {
            Text("🔥")
                .font(.title2)
                .opacity(currentStreak > 0 ? 1.0 : 0.4)

            HStack(spacing: 4) {
                Text(streakText)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(currentStreak > 0 ? .primary : .secondary)

                if let subtitle = subtitleText {
                    Text("·")
                        .foregroundColor(.secondary)
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundColor(isPersonalBest ? Color(hex: "FF9500") : .secondary)
                }
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.secondary)
        }
        .padding(16)
        .contentShape(Rectangle())
    }
}

// MARK: - Preview

#Preview("Week Stats - Active Streak") {
    VStack {
        ProgressSummaryCard(
            totalSteps: 52_450,
            totalDistance: 36_000,
            averageDailySteps: 7_493,
            daysGoalMet: 5,
            totalDays: 7,
            currentStreak: 14,
            longestStreak: 14
        )
    }
    .padding()
    .background(Color(.systemGroupedBackground))
}

#Preview("Month Stats - Not Personal Best") {
    VStack {
        ProgressSummaryCard(
            totalSteps: 285_000,
            totalDistance: 196_000,
            averageDailySteps: 9_500,
            daysGoalMet: 22,
            totalDays: 30,
            currentStreak: 7,
            longestStreak: 21
        )
    }
    .padding()
    .background(Color(.systemGroupedBackground))
}

#Preview("No Active Streak") {
    VStack {
        ProgressSummaryCard(
            totalSteps: 3_650_000,
            totalDistance: 2_500_000,
            averageDailySteps: 10_000,
            daysGoalMet: 280,
            totalDays: 365,
            currentStreak: 0,
            longestStreak: 14
        )
    }
    .padding()
    .background(Color(.systemGroupedBackground))
}

#Preview("Never Had Streak") {
    VStack {
        ProgressSummaryCard(
            totalSteps: 10_000,
            totalDistance: 7_000,
            averageDailySteps: 5_000,
            daysGoalMet: 1,
            totalDays: 2,
            currentStreak: 0,
            longestStreak: 0
        )
    }
    .padding()
    .background(Color(.systemGroupedBackground))
}
