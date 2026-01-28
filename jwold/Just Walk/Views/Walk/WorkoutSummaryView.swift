//
//  WorkoutSummaryView.swift
//  Just Walk
//
//  Displays workout summary with map-on-top hero layout.
//  Shows route visualization and key metrics.
//

import SwiftUI
import HealthKit

struct WorkoutSummaryView: View {
    let workout: HKWorkout
    var originalRoute: RouteGenerator.GeneratedRoute? = nil
    var walkMode: WalkMode? = nil

    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var savedRouteManager = SavedRouteManager.shared
    @State private var steps: Int = 0
    @State private var heartRate: Double? = nil
    @State private var isLoadingStats = true
    @State private var showSavePrompt = true
    @State private var showPaywall = false

    private let healthStore = HKHealthStore()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Route map (hero position - top)
                    RouteMapView(workout: workout)
                        .frame(height: 280)
                        .clipShape(RoundedRectangle(cornerRadius: 20))

                    // Celebration header
                    celebrationHeader

                    // Primary stats grid
                    primaryStatsSection

                    // Save route prompt (if walking a generated route)
                    if let route = originalRoute, showSavePrompt {
                        SaveRoutePromptCard(
                            route: route,
                            onSave: { name in
                                savedRouteManager.saveRoute(from: route, name: name)
                            },
                            onSkip: {
                                withAnimation {
                                    showSavePrompt = false
                                }
                            },
                            onShowPaywall: {
                                showPaywall = true
                            }
                        )
                    }

                    // Post-Meal insight card
                    if walkMode == .postMeal {
                        postMealInsightCard
                    }

                    // Secondary stats (HR/Calories - only if available)
                    if hasWatchData {
                        secondaryStatsSection
                    }
                }
                .padding(16)
            }
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        NotificationCenter.default.post(name: .workoutSaved, object: nil)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
        .task {
            await loadAdditionalStats()
        }
        .sheet(isPresented: $showPaywall) {
            ProPaywallView {
                showPaywall = false
            }
        }
    }

    // MARK: - Celebration Header

    private var celebrationHeader: some View {
        VStack(spacing: 8) {
            Text(walkMode == .postMeal ? "Post-Meal Walk Complete" : "Great Job!")
                .font(.system(size: 32, weight: .bold, design: .rounded))
                .foregroundStyle(
                    LinearGradient(
                        colors: walkMode == .postMeal ? [Color(hex: "34C759"), .green] : [.green, .cyan],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )

            if walkMode != .postMeal {
                Text("You completed a \(formattedDuration) walk")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Computed Properties

    private var formattedDistance: String {
        if let distance = workout.totalDistance {
            let miles = distance.doubleValue(for: .mile())
            return String(format: "%.2f mi", miles)
        }
        return "0.00 mi"
    }

    private var formattedDuration: String {
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

    private var formattedCalories: String {
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

    private var hasWatchData: Bool {
        return heartRate != nil
    }

    // MARK: - Views

    private var primaryStatsSection: some View {
        HStack(spacing: 0) {
            statItem(
                title: "Time",
                value: formattedDuration,
                icon: "clock.fill",
                color: .blue
            )

            Divider()
                .frame(height: 50)

            statItem(
                title: "Steps",
                value: "\(steps.formatted())",
                icon: "shoeprints.fill",
                color: .cyan
            )

            Divider()
                .frame(height: 50)

            statItem(
                title: "Distance",
                value: formattedDistance,
                icon: "point.topleft.down.to.point.bottomright.curvepath",
                color: .teal
            )
        }
        .padding(16)
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private var secondaryStatsSection: some View {
        HStack(spacing: 0) {
            statItem(
                title: "Avg HR",
                value: formattedHeartRate,
                icon: "heart.fill",
                color: .red
            )
        }
        .padding(16)
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private func statItem(title: String, value: String, icon: String, color: Color) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 24))
                .foregroundStyle(color)

            Text(value)
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .monospacedDigit()

            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Post-Meal Insight Card

    private var postMealInsightCard: some View {
        let completedFull = workout.duration >= 570  // ~9.5 min considered full
        let message = completedFull
            ? "That 10 minutes can reduce your blood sugar response by up to 30%. Well done."
            : "Every minute counts. Even a short walk helps with digestion."

        return VStack(spacing: 8) {
            Image(systemName: "leaf.fill")
                .font(.system(size: 24))
                .foregroundStyle(Color(hex: "34C759"))

            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(16)
        .frame(maxWidth: .infinity)
        .background(Color(hex: "34C759").opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Data Loading

    private func loadAdditionalStats() async {
        isLoadingStats = true

        steps = await fetchSteps()
        heartRate = await fetchAverageHeartRate()

        isLoadingStats = false
    }

    private func fetchSteps() async -> Int {
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

    private func fetchAverageHeartRate() async -> Double? {
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
// Note: Preview requires a real HKWorkout from HealthKit, disabled to avoid deprecation warning
// #Preview {
//     WorkoutSummaryView(workout: HKWorkout(activityType: .walking, start: Date().addingTimeInterval(-1800), end: Date()))
// }
