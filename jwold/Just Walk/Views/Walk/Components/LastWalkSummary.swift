//
//  LastWalkSummary.swift
//  Just Walk
//
//  Subtle info-only summary of the last walk, displayed on Walk tab.
//  Not a navigation element - just contextual information.
//

import SwiftUI

struct LastWalkSummary: View {
    @ObservedObject private var historyManager = WorkoutHistoryManager.shared

    private var lastWalk: WorkoutHistoryItem? {
        historyManager.workouts.first { walk in
            // Filter out walks under 1 minute AND under 100 steps
            // walk.duration is TimeInterval (seconds)
            // walk.steps is Int?
            return walk.duration >= 60 || (walk.steps ?? 0) >= 100
        }
    }

    var body: some View {
        if let walk = lastWalk {
            HStack(spacing: 6) {
                // Walk type icon
                Image(systemName: walk.isIWTSession ? "bolt.fill" : "figure.walk")
                    .font(.system(size: 12))
                    .foregroundStyle(.tertiary)

                // Summary text
                Text(summaryText(for: walk))
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .frame(maxWidth: .infinity)
        }
    }

    private func summaryText(for walk: WorkoutHistoryItem) -> String {
        var parts: [String] = []

        // Relative date
        parts.append("Last walk: \(walk.relativeDate)")

        // Duration
        parts.append(walk.formattedDuration)

        // Steps if available
        if let steps = walk.steps {
            parts.append("\(steps.formatted()) steps")
        }

        return parts.joined(separator: " · ")
    }
}

// MARK: - Preview

#Preview("With Walk") {
    VStack {
        Spacer()
        LastWalkSummary()
        Spacer()
    }
    .padding()
    .background(Color(.systemGroupedBackground))
}

#Preview("No Walks") {
    VStack {
        Spacer()
        LastWalkSummary()
        Spacer()
    }
    .padding()
    .background(Color(.systemGroupedBackground))
}
