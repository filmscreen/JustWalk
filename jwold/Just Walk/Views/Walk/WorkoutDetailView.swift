//
//  WorkoutDetailView.swift
//  Just Walk
//
//  Detail view for past workouts with map-on-top layout.
//  Fetches the HKWorkout from HealthKit and displays route + metrics.
//

import SwiftUI
import HealthKit

struct WorkoutDetailView: View {
    let workoutItem: WorkoutHistoryItem

    @Environment(\.dismiss) private var dismiss
    @StateObject private var workoutHistoryManager = WorkoutHistoryManager.shared
    @State private var hkWorkout: HKWorkout?
    @State private var isLoading = true
    @State private var steps: Int = 0
    @State private var heartRate: Double? = nil
    @State private var showDeleteConfirmation = false

    private let healthStore = HKHealthStore()

    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    loadingView
                } else if let workout = hkWorkout {
                    workoutContent(workout)
                } else {
                    errorView
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Menu {
                        Button("Delete Workout", systemImage: "trash", role: .destructive) {
                            showDeleteConfirmation = true
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .font(.title3)
                            .foregroundStyle(.secondary)
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(.primary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(.ultraThinMaterial)
                    .clipShape(Capsule())
                }
            }
            .alert("Delete Workout?", isPresented: $showDeleteConfirmation) {
                Button("Cancel", role: .cancel) { }
                Button("Delete", role: .destructive) {
                    Task {
                        await workoutHistoryManager.deleteWorkout(id: workoutItem.id)
                        dismiss()
                    }
                }
            } message: {
                Text("This workout will be permanently deleted.")
            }
        }
        .task {
            await loadWorkout()
        }
    }

    // MARK: - Loading View

    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.5)
            Text("Loading workout...")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(uiColor: .systemGroupedBackground))
    }

    // MARK: - Error View

    private var errorView: some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 48))
                .foregroundStyle(.orange)

            Text("Couldn't load workout")
                .font(.headline)

            Text("The workout data may no longer be available.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(uiColor: .systemGroupedBackground))
    }

    // MARK: - Workout Content

    private func workoutContent(_ workout: HKWorkout) -> some View {
        VStack(spacing: 16) {
            Spacer()
                .frame(height: 24)
            // Route map with stats overlay
            ZStack(alignment: .bottom) {
                RouteMapView(workout: workout)
                    .frame(height: 340)

                // Stats overlay on map
                primaryStatsSection(workout)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 16)
            }
            .clipShape(RoundedRectangle(cornerRadius: 20))

            // Date header
            dateHeader(workout)

            Spacer()
        }
        .padding(16)
        .background(Color(uiColor: .systemGroupedBackground))
    }

    // MARK: - Date Header

    private func dateHeader(_ workout: HKWorkout) -> some View {
        VStack(spacing: 4) {
            Text(workout.startDate.formatted(date: .abbreviated, time: .shortened))
                .font(.headline)
                .foregroundStyle(.primary)

            Text(formattedDuration(workout))
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Stats Sections

    private func primaryStatsSection(_ workout: HKWorkout) -> some View {
        HStack(spacing: 0) {
            statItem(
                title: "Time",
                value: formattedDuration(workout),
                icon: "clock.fill",
                color: .blue
            )

            Divider()
                .frame(height: 36)

            statItem(
                title: "Steps",
                value: "\(steps.formatted())",
                icon: "shoeprints.fill",
                color: .cyan
            )

            Divider()
                .frame(height: 36)

            statItem(
                title: "Distance",
                value: formattedDistance(workout),
                icon: "point.topleft.down.to.point.bottomright.curvepath",
                color: .teal
            )
        }
        .padding(12)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func secondaryStatsSection(_ workout: HKWorkout) -> some View {
        HStack(spacing: 0) {
            if heartRate != nil {
                statItem(
                    title: "Avg HR",
                    value: formattedHeartRate,
                    icon: "heart.fill",
                    color: .red
                )

                if workout.totalEnergyBurned != nil {
                    Divider()
                        .frame(height: 50)
                }
            }

            if workout.totalEnergyBurned != nil {
                statItem(
                    title: "Calories",
                    value: formattedCalories(workout),
                    icon: "flame.fill",
                    color: .orange
                )
            }
        }
        .padding(16)
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private func statItem(title: String, value: String, icon: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundStyle(color)

            Text(value)
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .monospacedDigit()

            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Computed Properties

    private func formattedDistance(_ workout: HKWorkout) -> String {
        if let distance = workout.totalDistance {
            let miles = distance.doubleValue(for: .mile())
            return String(format: "%.2f mi", miles)
        }
        return "0.00 mi"
    }

    private func formattedDuration(_ workout: HKWorkout) -> String {
        let totalSeconds = Int(workout.duration)
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60

        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%02d:%02d", minutes, seconds)
        }
    }

    private func formattedCalories(_ workout: HKWorkout) -> String {
        if let calories = workout.totalEnergyBurned {
            let kcal = Int(calories.doubleValue(for: .kilocalorie()))
            return "\(kcal)"
        }
        return "0"
    }

    private var formattedHeartRate: String {
        if let hr = heartRate {
            return "\(Int(hr)) BPM"
        }
        return "--"
    }

    private func hasWatchData(_ workout: HKWorkout) -> Bool {
        return heartRate != nil || workout.totalEnergyBurned != nil
    }

    // MARK: - Data Loading

    private func loadWorkout() async {
        isLoading = true

        // Fetch the HKWorkout from HealthKit using the stored ID
        if let workout = await fetchHKWorkout() {
            hkWorkout = workout
            steps = await fetchSteps(for: workout)
            heartRate = await fetchAverageHeartRate(for: workout)
        }

        isLoading = false
    }

    private func fetchHKWorkout() async -> HKWorkout? {
        // Use the HealthKit workout UUID (not the SwiftData ID)
        print("🔍 WorkoutDetailView: workoutItem.id = \(workoutItem.id)")
        print("🔍 WorkoutDetailView: workoutItem.hkWorkoutId = \(workoutItem.hkWorkoutId?.uuidString ?? "nil")")

        guard let hkWorkoutId = workoutItem.hkWorkoutId else {
            print("⚠️ No HealthKit workout ID available for this session")
            return nil
        }

        let workoutType = HKObjectType.workoutType()

        // Create predicate for this specific workout by HealthKit UUID
        let predicate = HKQuery.predicateForObject(with: hkWorkoutId)
        print("🔍 Querying HealthKit for workout with UUID: \(hkWorkoutId)")

        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: workoutType,
                predicate: predicate,
                limit: 1,
                sortDescriptors: nil
            ) { _, samples, error in
                if let error = error {
                    print("❌ HealthKit query error: \(error)")
                }
                let workout = samples?.first as? HKWorkout
                print("🔍 HealthKit query result: \(workout != nil ? "Found workout" : "No workout found")")
                continuation.resume(returning: workout)
            }

            healthStore.execute(query)
        }
    }

    private func fetchSteps(for workout: HKWorkout) async -> Int {
        guard let stepType = HKQuantityType.quantityType(forIdentifier: .stepCount) else {
            return 0
        }

        let predicate = HKQuery.predicateForSamples(
            withStart: workout.startDate,
            end: workout.endDate,
            options: .strictStartDate
        )

        return await withCheckedContinuation { continuation in
            let query = HKStatisticsQuery(
                quantityType: stepType,
                quantitySamplePredicate: predicate,
                options: .cumulativeSum
            ) { _, statistics, _ in
                let steps = statistics?.sumQuantity()?.doubleValue(for: .count()) ?? 0
                continuation.resume(returning: Int(steps))
            }

            healthStore.execute(query)
        }
    }

    private func fetchAverageHeartRate(for workout: HKWorkout) async -> Double? {
        guard let hrType = HKQuantityType.quantityType(forIdentifier: .heartRate) else {
            return nil
        }

        let predicate = HKQuery.predicateForSamples(
            withStart: workout.startDate,
            end: workout.endDate,
            options: .strictStartDate
        )

        return await withCheckedContinuation { continuation in
            let query = HKStatisticsQuery(
                quantityType: hrType,
                quantitySamplePredicate: predicate,
                options: .discreteAverage
            ) { _, statistics, _ in
                let hrUnit = HKUnit.count().unitDivided(by: HKUnit.minute())
                let avgHR = statistics?.averageQuantity()?.doubleValue(for: hrUnit)
                continuation.resume(returning: avgHR)
            }

            healthStore.execute(query)
        }
    }
}

// MARK: - Preview
// Note: Preview requires a real WorkoutHistoryItem with matching HKWorkout in HealthKit
// #Preview {
//     WorkoutDetailView(workoutItem: WorkoutHistoryItem(
//         id: UUID(),
//         startDate: Date().addingTimeInterval(-1800),
//         endDate: Date(),
//         duration: 1800,
//         distance: 2400,
//         steps: 2500,
//         calories: 120,
//         isIWTSession: false
//     ))
// }
