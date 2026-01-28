//
//  PastWalksSheet.swift
//  Just Walk
//
//  Half-sheet for displaying past walks history.
//

import SwiftUI

struct PastWalksSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @StateObject private var workoutHistoryManager = WorkoutHistoryManager.shared

    @State private var selectedWorkout: WorkoutHistoryItem?

    var body: some View {
        NavigationStack {
            Group {
                if workoutHistoryManager.isLoading {
                    loadingView
                } else if workoutHistoryManager.workouts.isEmpty {
                    emptyView
                } else {
                    workoutsList
                }
            }
            .navigationTitle("Past Walks")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .task {
            workoutHistoryManager.setModelContext(modelContext)
            await workoutHistoryManager.fetchWorkouts()
        }
        .onReceive(NotificationCenter.default.publisher(for: .workoutSaved)) { _ in
            Task {
                await workoutHistoryManager.fetchWorkouts()
            }
        }
        .sheet(item: $selectedWorkout) { workout in
            WorkoutDetailView(workoutItem: workout)
                .presentationDetents([.fraction(0.6)])
        }
    }

    // MARK: - Loading View

    private var loadingView: some View {
        VStack {
            Spacer()
            ProgressView()
                .scaleEffect(1.2)
            Text("Loading...")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .padding(.top, 8)
            Spacer()
        }
    }

    // MARK: - Empty View

    private var emptyView: some View {
        ContentUnavailableView {
            Label("No Walks Yet", systemImage: "figure.walk")
        } description: {
            Text("Start a walk to see your history here.")
        }
    }

    // MARK: - Workouts List

    private var workoutsList: some View {
        List {
            ForEach(workoutHistoryManager.workouts) { workout in
                Button {
                    selectedWorkout = workout
                } label: {
                    WorkoutHistoryRow(workout: workout)
                }
                .buttonStyle(.plain)
                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                    Button(role: .destructive) {
                        Task {
                            await workoutHistoryManager.deleteWorkout(id: workout.id)
                        }
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
            }
        }
        .listStyle(.plain)
    }
}

#Preview {
    PastWalksSheet()
}
