//
//  WorkoutHistoryRow.swift
//  Just Walk
//
//  3-line row for displaying individual workout history items.
//  Layout: Date > Distance•Steps (bold) > TimeRange•Duration (secondary)
//

import SwiftUI

struct WorkoutHistoryRow: View {

    let workout: WorkoutHistoryItem

    private var iconColor: Color {
        workout.isIWTSession ? JWDesign.Colors.brandPrimary : .green
    }

    private var iconName: String {
        workout.isIWTSession ? "figure.run" : "figure.walk"
    }

    var body: some View {
        HStack(spacing: 12) {
            // Icon - changes based on walk type
            ZStack {
                Circle()
                    .fill(iconColor.opacity(0.15))
                    .frame(width: 40, height: 40)
                Image(systemName: iconName)
                    .font(.system(size: 18))
                    .foregroundStyle(iconColor)
            }

            // Content - 3 lines
            VStack(alignment: .leading, spacing: 3) {
                // Line 1: Date
                Text(workout.shortDate)
                    .font(.subheadline)
                    .foregroundStyle(.primary)

                // Line 2: Primary metrics (bold) - Distance + Steps
                HStack(spacing: 8) {
                    Text(workout.formattedDistance)

                    Text("|")
                        .foregroundStyle(.quaternary)

                    if let steps = workout.steps {
                        Text("\(steps.formatted()) steps")
                    }
                }
                .font(.subheadline.bold())
                .foregroundStyle(.primary)

                // Line 3: Time range + Duration (secondary)
                HStack(spacing: 8) {
                    Text(workout.timeRange)

                    Text("|")
                        .foregroundStyle(.quaternary)

                    Text(workout.formattedDuration)
                }
                .font(.footnote)
                .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding(.vertical, 10)
    }
}

#Preview {
    VStack(spacing: 0) {
        // Classic Walk
        WorkoutHistoryRow(
            workout: WorkoutHistoryItem(
                id: UUID(),
                startDate: Date(),
                endDate: Date().addingTimeInterval(2700),
                duration: 2700,
                distance: 3218.69,
                steps: 4521,
                calories: 180,
                isIWTSession: false,
                hkWorkoutId: nil
            )
        )

        Divider()
            .padding(.leading, 52)

        // Interval Walk
        WorkoutHistoryRow(
            workout: WorkoutHistoryItem(
                id: UUID(),
                startDate: Calendar.current.date(byAdding: .day, value: -1, to: Date())!,
                endDate: Calendar.current.date(byAdding: .day, value: -1, to: Date())!.addingTimeInterval(5400),
                duration: 5400,
                distance: 6437.38,
                steps: 8932,
                calories: 320,
                isIWTSession: true,
                hkWorkoutId: nil
            )
        )

        Divider()
            .padding(.leading, 52)

        // Classic Walk (short)
        WorkoutHistoryRow(
            workout: WorkoutHistoryItem(
                id: UUID(),
                startDate: Calendar.current.date(byAdding: .day, value: -2, to: Date())!,
                endDate: Calendar.current.date(byAdding: .day, value: -2, to: Date())!.addingTimeInterval(15),
                duration: 15,
                distance: 50,
                steps: nil,
                calories: 5,
                isIWTSession: false,
                hkWorkoutId: nil
            )
        )
    }
    .padding()
}
