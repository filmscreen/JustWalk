//
//  WorkoutSummaryCard.swift
//  Just Walk
//
//  Live preview card showing workout stats that update in real-time
//  as the user adjusts interval settings.
//

import SwiftUI

/// Live preview card showing computed workout statistics
struct WorkoutSummaryCard: View {
    let totalDuration: String
    let estimatedSteps: String
    let numberOfCycles: Int
    let workoutDescription: String

    var body: some View {
        VStack(alignment: .leading, spacing: JWDesign.Spacing.md) {
            // Header
            HStack {
                Text("WALK PREVIEW")
                    .font(JWDesign.Typography.caption)
                    .foregroundStyle(Color(.secondaryLabel))
                    .tracking(1)

                Spacer()

                // Live indicator
                HStack(spacing: 4) {
                    Circle()
                        .fill(JWDesign.Colors.success)
                        .frame(width: 6, height: 6)

                    Text("Live")
                        .font(JWDesign.Typography.caption)
                        .foregroundStyle(Color(.secondaryLabel))
                }
            }

            // Stats grid
            HStack(spacing: 0) {
                // Duration
                StatItem(
                    icon: "clock.fill",
                    value: totalDuration,
                    label: "Duration"
                )

                Divider()
                    .frame(height: 40)
                    .padding(.horizontal, JWDesign.Spacing.md)

                // Steps
                StatItem(
                    icon: "figure.walk",
                    value: estimatedSteps,
                    label: "Est. Steps"
                )

                Divider()
                    .frame(height: 40)
                    .padding(.horizontal, JWDesign.Spacing.md)

                // Cycles
                StatItem(
                    icon: "arrow.triangle.2.circlepath",
                    value: "\(numberOfCycles)",
                    label: "Intervals"
                )
            }

            // Workout description
            HStack(alignment: .top, spacing: JWDesign.Spacing.xs) {
                Image(systemName: "info.circle.fill")
                    .font(.system(size: 12))
                    .foregroundStyle(Color(.secondaryLabel))

                Text(workoutDescription)
                    .font(JWDesign.Typography.caption)
                    .foregroundStyle(Color(.secondaryLabel))
                    .lineLimit(2)
            }
            .padding(JWDesign.Spacing.sm)
            .background(JWDesign.Colors.secondaryBackground)
            .clipShape(RoundedRectangle(cornerRadius: JWDesign.Radius.small))
        }
        .padding(JWDesign.Spacing.md)
        .background(JWDesign.Colors.secondaryBackground)
        .clipShape(RoundedRectangle(cornerRadius: JWDesign.Radius.medium))
    }
}

// MARK: - Stat Item

/// Individual statistic display item
private struct StatItem: View {
    let icon: String
    let value: String
    let label: String

    var body: some View {
        VStack(spacing: JWDesign.Spacing.xs) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundStyle(JWDesign.Colors.brandSecondary)

            Text(value)
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundStyle(.primary)

            Text(label)
                .font(JWDesign.Typography.caption)
                .foregroundStyle(Color(.secondaryLabel))
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Preview

#Preview("Workout Summary") {
    VStack(spacing: 20) {
        WorkoutSummaryCard(
            totalDuration: "32 min",
            estimatedSteps: "~4,200",
            numberOfCycles: 5,
            workoutDescription: "2 min warmup → 5x (3:00 easy + 3:00 brisk) → 2 min cooldown"
        )

        WorkoutSummaryCard(
            totalDuration: "24 min",
            estimatedSteps: "~3,100",
            numberOfCycles: 4,
            workoutDescription: "4x (2:30 easy + 3:30 brisk)"
        )
    }
    .padding()
    .background(JWDesign.Colors.background)
}
