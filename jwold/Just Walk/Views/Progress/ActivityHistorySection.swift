//
//  ActivityHistorySection.swift
//  Just Walk
//
//  Recent Walks section for the Progress tab.
//  Shows last 5 walking sessions with "See all" link to full history.
//

import SwiftUI
import Combine

struct ActivityHistorySection: View {
    @ObservedObject var historyManager: WorkoutHistoryManager
    let isPro: Bool
    var onSelectWorkout: (WorkoutHistoryItem) -> Void = { _ in }
    var onUpgrade: () -> Void = {}

    private let maxDisplayCount = 5

    private var groupedWorkouts: [(key: String, workouts: [WorkoutHistoryItem])] {
        historyManager.groupedWorkouts(isPro: isPro)
    }

    // Show only last 5 workouts
    private var displayedWorkouts: [WorkoutHistoryItem] {
        let allWorkouts = groupedWorkouts.flatMap(\.workouts)
        return Array(allWorkouts.prefix(maxDisplayCount))
    }

    private var hasMoreWorkouts: Bool {
        let totalCount = groupedWorkouts.reduce(0) { $0 + $1.workouts.count }
        return totalCount > maxDisplayCount
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header with "See all" link
            HStack {
                Text("Recent Walks")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.primary)

                Spacer()

                if historyManager.isLoading {
                    ProgressView()
                        .scaleEffect(0.8)
                } else if hasMoreWorkouts {
                    NavigationLink(destination: AllWalksView()) {
                        HStack(spacing: 4) {
                            Text("See all")
                                .font(.system(size: 15, weight: .medium))
                            Image(systemName: "chevron.right")
                                .font(.system(size: 12, weight: .medium))
                        }
                        .foregroundStyle(Color(hex: "00C7BE"))
                    }
                }
            }

            if displayedWorkouts.isEmpty {
                emptyState
            } else {
                // Workout list using RecentWalkRow
                LazyVStack(spacing: 0) {
                    ForEach(displayedWorkouts) { workout in
                        RecentWalkRow(workout: workout) {
                            onSelectWorkout(workout)
                        }

                        if workout.id != displayedWorkouts.last?.id {
                            Divider()
                                .padding(.leading, 52)
                        }
                    }
                }

                // Free tier upsell
                if !isPro && historyManager.hasHiddenWorkouts(isPro: isPro) {
                    freeUserUpsell
                }
            }
        }
        .padding(16)
        .background(JWDesign.Colors.secondaryBackground)
        .clipShape(RoundedRectangle(cornerRadius: JWDesign.Radius.card))
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "figure.walk.circle")
                .font(.system(size: 40))
                .foregroundStyle(Color(.tertiaryLabel))

            Text("No activities yet")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(Color(.secondaryLabel))

            Text("Start a walk to track your activity")
                .font(.system(size: 13))
                .foregroundStyle(Color(.tertiaryLabel))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
    }

    // MARK: - Free User Upsell

    private var freeUserUpsell: some View {
        Button {
            onUpgrade()
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "lock.fill")
                    .font(.system(size: 14))
                    .foregroundStyle(Color(hex: "00C7BE"))

                Text("Unlock full history with Pro")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Color(hex: "00C7BE"))

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 12))
                    .foregroundStyle(Color(hex: "00C7BE"))
            }
            .padding(12)
            .background(Color(hex: "00C7BE").opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: JWDesign.Radius.medium))
        }
        .buttonStyle(.plain)
        .padding(.top, 8)
    }
}

// MARK: - Preview

#Preview("With Workouts") {
    ScrollView {
        ActivityHistorySection(
            historyManager: WorkoutHistoryManager.shared,
            isPro: true,
            onSelectWorkout: { workout in print("Selected: \(workout.id)") }
        )
        .padding()
    }
    .background(Color(.systemGroupedBackground))
}

#Preview("Empty State") {
    ScrollView {
        ActivityHistorySection(
            historyManager: WorkoutHistoryManager.shared,
            isPro: false
        )
        .padding()
    }
    .background(Color(.systemGroupedBackground))
}
