//
//  RecentWalkRow.swift
//  Just Walk
//
//  Row component for displaying individual walks in Recent Walks section
//  and All Walks view. Shows walk type indicator, date, and stats.
//

import SwiftUI

struct RecentWalkRow: View {
    let workout: WorkoutHistoryItem
    var onTap: (() -> Void)? = nil

    var body: some View {
        Button {
            onTap?()
        } label: {
            HStack(spacing: 12) {
                // Walk type icon
                ZStack {
                    Circle()
                        .fill(iconColor.opacity(0.15))
                        .frame(width: 40, height: 40)

                    Image(systemName: workout.isIWTSession ? "bolt.fill" : "figure.walk")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(iconColor)
                }

                VStack(alignment: .leading, spacing: 2) {
                    // Line 1: Date + Walk type
                    HStack(spacing: 6) {
                        Text(workout.relativeDate)
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.primary)

                        Text("·")
                            .foregroundStyle(.tertiary)

                        Text(workout.isIWTSession ? "Interval" : "Just Walk")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    // Line 2: Steps · Duration · Distance
                    HStack(spacing: 6) {
                        if let steps = workout.steps {
                            Text("\(steps.formatted()) steps")
                        }
                        Text("·").foregroundStyle(.tertiary)
                        Text(workout.formattedDuration)
                        Text("·").foregroundStyle(.tertiary)
                        Text(workout.formattedDistance)
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }

                Spacer()

                // Chevron
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .regular))
                    .foregroundStyle(Color(.tertiaryLabel))
            }
            .padding(.vertical, 8)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var iconColor: Color {
        workout.isIWTSession ? Color(hex: "00C7BE") : Color(hex: "34C759")
    }
}

// MARK: - WorkoutHistoryItem Extension

extension WorkoutHistoryItem {
    /// Relative date display (Today, Yesterday, or MMM d)
    var relativeDate: String {
        let calendar = Calendar.current

        if calendar.isDateInToday(startDate) {
            return "Today"
        } else if calendar.isDateInYesterday(startDate) {
            return "Yesterday"
        } else {
            let formatter = DateFormatter()
            formatter.dateFormat = "MMM d"
            return formatter.string(from: startDate)
        }
    }
}

// MARK: - Preview

#Preview("Just Walk") {
    RecentWalkRow(
        workout: WorkoutHistoryItem(
            id: UUID(),
            startDate: Date(),
            endDate: Date().addingTimeInterval(1920),
            duration: 1920,
            distance: 2897,
            steps: 3847,
            calories: 180,
            isIWTSession: false,
            hkWorkoutId: nil
        )
    )
    .padding()
    .background(JWDesign.Colors.secondaryBackground)
}

#Preview("Interval Walk") {
    RecentWalkRow(
        workout: WorkoutHistoryItem(
            id: UUID(),
            startDate: Date().addingTimeInterval(-86400),
            endDate: Date().addingTimeInterval(-86400 + 1680),
            duration: 1680,
            distance: 3380,
            steps: 4102,
            calories: 210,
            isIWTSession: true,
            hkWorkoutId: nil
        )
    )
    .padding()
    .background(JWDesign.Colors.secondaryBackground)
}
