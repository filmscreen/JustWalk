//
//  AllWalksView.swift
//  Just Walk
//
//  Full-screen view showing complete walk history, grouped by month.
//  Accessed via "See all" from the Recent Walks section in Progress tab.
//

import SwiftUI

struct AllWalksView: View {
    @ObservedObject private var historyManager = WorkoutHistoryManager.shared
    @ObservedObject private var freeTierManager = FreeTierManager.shared
    @State private var selectedWorkout: WorkoutHistoryItem?

    private var isPro: Bool {
        freeTierManager.isPro
    }

    private var groupedWorkouts: [(key: String, workouts: [WorkoutHistoryItem])] {
        historyManager.groupedWorkouts(isPro: isPro)
    }

    var body: some View {
        Group {
            if historyManager.isLoading && historyManager.workouts.isEmpty {
                loadingView
            } else if groupedWorkouts.isEmpty {
                emptyView
            } else {
                workoutsList
            }
        }
        .navigationTitle("All Walks")
        .navigationBarTitleDisplayMode(.large)
        .sheet(item: $selectedWorkout) { workout in
            WorkoutDetailView(workoutItem: workout)
        }
    }

    // MARK: - Loading View

    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
            Text("Loading walks...")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Empty View

    private var emptyView: some View {
        ContentUnavailableView {
            Label("No Walks Yet", systemImage: "figure.walk.circle")
        } description: {
            Text("Complete a walk to see it here")
        }
    }

    // MARK: - Workouts List

    private var workoutsList: some View {
        List {
            ForEach(groupedWorkouts, id: \.key) { group in
                Section {
                    ForEach(group.workouts) { workout in
                        RecentWalkRow(workout: workout) {
                            selectedWorkout = workout
                        }
                        .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                    }
                    .onDelete { indexSet in
                        deleteWorkouts(at: indexSet, in: group.workouts)
                    }
                } header: {
                    Text(group.key)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .textCase(nil)
                }
            }

            // Free tier upsell
            if !isPro && historyManager.hasHiddenWorkouts(isPro: isPro) {
                Section {
                    freeUserUpsell
                }
            }
        }
        .listStyle(.insetGrouped)
    }

    // MARK: - Free User Upsell

    private var freeUserUpsell: some View {
        HStack(spacing: 12) {
            Image(systemName: "lock.fill")
                .font(.system(size: 16))
                .foregroundStyle(Color(hex: "00C7BE"))

            VStack(alignment: .leading, spacing: 2) {
                Text("Unlock Full History")
                    .font(.subheadline.weight(.medium))

                Text("See all your past walks with Pro")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 14))
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .onTapGesture {
            // TODO: Show paywall
        }
    }

    // MARK: - Actions

    private func deleteWorkouts(at indexSet: IndexSet, in workouts: [WorkoutHistoryItem]) {
        for index in indexSet {
            let workout = workouts[index]
            Task {
                await historyManager.deleteWorkout(id: workout.id)
            }
        }
    }
}

// MARK: - Preview

#Preview("With Workouts") {
    NavigationStack {
        AllWalksView()
    }
}

#Preview("Empty") {
    NavigationStack {
        AllWalksView()
    }
}
