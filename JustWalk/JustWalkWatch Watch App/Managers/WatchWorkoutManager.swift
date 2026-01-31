//
//  WatchWorkoutManager.swift
//  JustWalkWatch Watch App
//
//  Manages HKWorkoutSession for live workout data on Apple Watch
//

import Foundation
import HealthKit
import Combine
import os
import WidgetKit

/// Manages workout sessions on Apple Watch
@MainActor
final class WatchWorkoutManager: NSObject, ObservableObject {

    // MARK: - Singleton

    static let shared = WatchWorkoutManager()

    private nonisolated static let logger = Logger(subsystem: "com.justwalk.watch", category: "WorkoutManager")

    // MARK: - Published State

    @Published private(set) var workoutState: WorkoutState = .idle
    @Published private(set) var currentWalkId: UUID?

    // Live stats
    @Published private(set) var elapsedSeconds: TimeInterval = 0
    @Published private(set) var heartRate: Int = 0
    @Published private(set) var activeCalories: Double = 0
    @Published private(set) var steps: Int = 0
    @Published private(set) var distance: Double = 0 // meters

    // For summary
    @Published private(set) var averageHeartRate: Int = 0
    @Published private(set) var maxHeartRate: Int = 0
    @Published private(set) var minHeartRate: Int = Int.max

    // MARK: - Private Properties

    private let healthStore = HKHealthStore()
    private var workoutSession: HKWorkoutSession?
    private var workoutBuilder: HKLiveWorkoutBuilder?

    private var startTime: Date?
    private var heartRateSamples: [Int] = []
    private var timer: Timer?

    // Walk mode tracking for summary
    private var modeRaw: String?
    private var intervalProgramRaw: String?

    // MARK: - Initialization

    private override init() {
        super.init()
    }

    // MARK: - Public API

    /// Request HealthKit authorization
    func requestAuthorization() async -> Bool {
        let typesToShare: Set<HKSampleType> = [
            HKQuantityType.workoutType()
        ]

        let typesToRead: Set<HKObjectType> = [
            HKQuantityType(.heartRate),
            HKQuantityType(.activeEnergyBurned),
            HKQuantityType(.stepCount),
            HKQuantityType(.distanceWalkingRunning)
        ]

        do {
            try await healthStore.requestAuthorization(toShare: typesToShare, read: typesToRead)
            return true
        } catch {
            Self.logger.error("HealthKit authorization failed: \(error.localizedDescription)")
            return false
        }
    }

    /// Start a walking workout
    /// - Parameters:
    ///   - walkId: Unique identifier for this walk
    ///   - modeRaw: Raw string value of WalkMode (e.g., "fatBurn", "interval", "postMeal", "free")
    ///   - intervalProgramRaw: Raw string value of interval program if applicable
    func startWorkout(walkId: UUID, modeRaw: String? = nil, intervalProgramRaw: String? = nil) async throws {
        guard await requestAuthorization() else {
            throw WorkoutError.authorizationFailed
        }

        // Store mode for summary
        self.modeRaw = modeRaw
        self.intervalProgramRaw = intervalProgramRaw

        let configuration = HKWorkoutConfiguration()
        configuration.activityType = .walking
        configuration.locationType = .outdoor

        let session = try HKWorkoutSession(healthStore: healthStore, configuration: configuration)
        let builder = session.associatedWorkoutBuilder()

        session.delegate = self
        builder.delegate = self

        builder.dataSource = HKLiveWorkoutDataSource(
            healthStore: healthStore,
            workoutConfiguration: configuration
        )

        self.workoutSession = session
        self.workoutBuilder = builder
        self.currentWalkId = walkId
        self.startTime = Date()

        resetStats()

        let startDate = Date()
        session.startActivity(with: startDate)
        try await builder.beginCollection(at: startDate)

        startTimer()

        workoutState = .active

        WatchConnectivityManager.shared.sendWorkoutStarted(walkId: walkId)

        Self.logger.info("Workout started for walkId: \(walkId.uuidString)")
    }

    /// Pause the workout
    func pauseWorkout() {
        workoutSession?.pause()
        timer?.invalidate()
        workoutState = .paused

        WatchConnectivityManager.shared.sendWorkoutPaused()
    }

    /// Resume the workout
    func resumeWorkout() {
        workoutSession?.resume()
        startTimer()
        workoutState = .active

        WatchConnectivityManager.shared.sendWorkoutResumed()
    }

    /// End the workout
    func endWorkout() async -> WorkoutSummaryData? {
        guard let session = workoutSession,
              let builder = workoutBuilder,
              let startTime = startTime,
              let walkId = currentWalkId else {
            return nil
        }

        timer?.invalidate()

        // Immediately end the HK session — stops green workout indicator and HR monitoring
        session.end()

        // Builder cleanup (endCollection + finishWorkout) writes to the HealthKit store
        // and can be very slow on watchOS. Run both in the background so endWorkout()
        // returns immediately after session.end().
        let endDate = Date()
        Task.detached { [builder] in
            do {
                try await builder.endCollection(at: endDate)
                try await builder.finishWorkout()
            } catch {
                // Workout data already collected — save failure is non-critical
            }
        }

        let summary = WorkoutSummaryData(
            walkId: walkId,
            startTime: startTime,
            endTime: endDate,
            totalSeconds: elapsedSeconds,
            totalSteps: steps,
            totalDistance: distance,
            totalActiveCalories: activeCalories,
            averageHeartRate: heartRateSamples.isEmpty ? nil : averageHeartRate,
            maxHeartRate: heartRateSamples.isEmpty ? nil : maxHeartRate,
            minHeartRate: heartRateSamples.isEmpty ? nil : (minHeartRate == Int.max ? nil : minHeartRate),
            modeRaw: self.modeRaw,
            intervalProgramRaw: self.intervalProgramRaw
        )

        workoutState = .idle
        self.workoutSession = nil
        self.workoutBuilder = nil
        self.currentWalkId = nil
        self.startTime = nil
        self.modeRaw = nil
        self.intervalProgramRaw = nil

        WatchConnectivityManager.shared.sendWorkoutEnded(summary: summary)

        Self.logger.info("Workout ended: \(summary.durationMinutes) min, \(summary.totalSteps) steps")

        return summary
    }

    // MARK: - Private Methods

    private func resetStats() {
        elapsedSeconds = 0
        heartRate = 0
        activeCalories = 0
        steps = 0
        distance = 0
        averageHeartRate = 0
        maxHeartRate = 0
        minHeartRate = Int.max
        heartRateSamples = []
    }

    private func startTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor [self] in
                guard let startTime = self.startTime else { return }
                self.elapsedSeconds = Date().timeIntervalSince(startTime)

                // Send stats update to iPhone periodically
                if Int(self.elapsedSeconds) % 3 == 0 {
                    self.sendStatsUpdate()
                }
            }
        }
    }

    private func sendStatsUpdate() {
        guard let walkId = currentWalkId else { return }

        let stats = WorkoutLiveStats(
            walkId: walkId,
            elapsedSeconds: elapsedSeconds,
            heartRate: heartRate > 0 ? heartRate : nil,
            steps: steps,
            activeCalories: activeCalories,
            distance: distance,
            timestamp: Date()
        )

        WatchConnectivityManager.shared.sendStatsUpdate(stats: stats)

        // During active workouts, aggressively update complications every 30 seconds.
        // This is industry-leading refresh since the app is actively running and has
        // more runtime. Users expect to see live step counts during walks.
        if Int(elapsedSeconds) % 30 == 0 {
            updateWidgetsForWorkout()
        }
    }

    /// Update widget data during active workout (aggressive refresh)
    private func updateWidgetsForWorkout() {
        let defaults = UserDefaults(suiteName: "group.com.justwalk.shared")

        // Get today's total steps (watch health data + current workout steps)
        let todaySteps = WatchHealthKitManager.shared.todaySteps

        defaults?.set(todaySteps, forKey: "widget_todaySteps")
        defaults?.set(steps, forKey: "widget_workoutSteps") // Current workout steps

        // Reload immediately - during active workout we have runtime budget
        WidgetCenter.shared.reloadAllTimelines()
    }

    private func updateHeartRate(_ value: Int) {
        heartRate = value
        heartRateSamples.append(value)

        if value > maxHeartRate {
            maxHeartRate = value
        }
        if value < minHeartRate {
            minHeartRate = value
        }

        averageHeartRate = heartRateSamples.reduce(0, +) / heartRateSamples.count

        // Send immediate heart rate update to iPhone for Fat Burn Zone
        WatchConnectivityManager.shared.sendHeartRateUpdate(bpm: value)
    }
}

// MARK: - HKWorkoutSessionDelegate

extension WatchWorkoutManager: HKWorkoutSessionDelegate {

    nonisolated func workoutSession(_ workoutSession: HKWorkoutSession, didChangeTo toState: HKWorkoutSessionState, from fromState: HKWorkoutSessionState, date: Date) {
        Task { @MainActor in
            switch toState {
            case .running:
                workoutState = .active
            case .paused:
                workoutState = .paused
            case .ended:
                workoutState = .idle
            default:
                break
            }
        }
    }

    nonisolated func workoutSession(_ workoutSession: HKWorkoutSession, didFailWithError error: Error) {
        Self.logger.error("Workout session failed: \(error.localizedDescription)")
        Task { @MainActor in
            workoutState = .idle
            WatchConnectivityManager.shared.sendWorkoutError(error.localizedDescription)
        }
    }
}

// MARK: - HKLiveWorkoutBuilderDelegate

extension WatchWorkoutManager: HKLiveWorkoutBuilderDelegate {

    nonisolated func workoutBuilder(_ workoutBuilder: HKLiveWorkoutBuilder, didCollectDataOf collectedTypes: Set<HKSampleType>) {
        for type in collectedTypes {
            guard let quantityType = type as? HKQuantityType else { continue }

            let statistics = workoutBuilder.statistics(for: quantityType)

            Task { @MainActor in
                updateForStatistics(statistics, type: quantityType)
            }
        }
    }

    nonisolated func workoutBuilderDidCollectEvent(_ workoutBuilder: HKLiveWorkoutBuilder) {
        // Handle workout events if needed
    }

    @MainActor
    private func updateForStatistics(_ statistics: HKStatistics?, type: HKQuantityType) {
        guard let statistics = statistics else { return }

        switch type {
        case HKQuantityType(.heartRate):
            let heartRateUnit = HKUnit.count().unitDivided(by: .minute())
            if let value = statistics.mostRecentQuantity()?.doubleValue(for: heartRateUnit) {
                updateHeartRate(Int(value))
            }

        case HKQuantityType(.activeEnergyBurned):
            let energyUnit = HKUnit.kilocalorie()
            if let value = statistics.sumQuantity()?.doubleValue(for: energyUnit) {
                activeCalories = value
            }

        case HKQuantityType(.stepCount):
            let stepsUnit = HKUnit.count()
            if let value = statistics.sumQuantity()?.doubleValue(for: stepsUnit) {
                steps = Int(value)
            }

        case HKQuantityType(.distanceWalkingRunning):
            let distanceUnit = HKUnit.meter()
            if let value = statistics.sumQuantity()?.doubleValue(for: distanceUnit) {
                distance = value
            }

        default:
            break
        }
    }
}

// MARK: - Errors

enum WorkoutError: Error {
    case authorizationFailed
    case sessionCreationFailed
    case alreadyActive
}
