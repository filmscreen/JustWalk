//
//  DashboardContextualRow.swift
//  Just Walk
//
//  Contextual content row at the bottom of the Today screen.
//  Shows last walk info if user walked today.
//

import SwiftUI

struct DashboardContextualRow: View {
    let lastWalk: WorkoutHistoryItem?
    let hasWalkedToday: Bool

    var body: some View {
        if let walk = lastWalk {
            // User has walked today - show last walk info
            lastWalkRow(walk)
        }
        // Otherwise show nothing
    }

    // MARK: - Last Walk Row

    private func lastWalkRow(_ walk: WorkoutHistoryItem) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "figure.walk")
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(Color(hex: "00C7BE"))

            Text("Last walk: \(formattedTime(walk.startDate))")
                .font(.system(size: 15, weight: .regular))
                .foregroundStyle(.secondary)

            Text("·")
                .foregroundStyle(.tertiary)

            Text(walk.formattedDuration)
                .font(.system(size: 15, weight: .regular))
                .foregroundStyle(.secondary)

            if let steps = walk.steps, steps > 0 {
                Text("·")
                    .foregroundStyle(.tertiary)
                Text("\(steps.formatted()) steps")
                    .font(.system(size: 15, weight: .regular))
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .frame(height: 52)
        .background(JWDesign.Colors.secondaryBackground)
        .clipShape(RoundedRectangle(cornerRadius: JWDesign.Radius.card))
    }

    // MARK: - Helpers

    private func formattedTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: date)
    }
}

#Preview {
    DashboardContextualRow(
        lastWalk: WorkoutHistoryItem(
            id: UUID(),
            startDate: Date().addingTimeInterval(-3600),
            endDate: Date(),
            duration: 1380,
            distance: 1609,
            steps: 2100,
            calories: 85,
            isIWTSession: false,
            hkWorkoutId: nil
        ),
        hasWalkedToday: true
    )
    .padding()
}
