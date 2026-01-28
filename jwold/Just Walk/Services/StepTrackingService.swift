//
//  StepTrackingService.swift
//  Just Walk
//
//  Session tracking service for IWT workouts.
//  Daily step tracking is handled by StepRepository (HealthKit as source of truth).
//

import Foundation
import CoreMotion
import HealthKit
import Combine
import WidgetKit

// MARK: - App Group Data Structure

/// Data stored in App Group for widget/complication access
struct SharedStepData: Codable {
    let steps: Int
    let distance: Double // meters
    let goal: Int
    let forDate: Date
    let updatedAt: Date

    var isForToday: Bool {
        Calendar.current.isDate(forDate, inSameDayAs: Date())
    }

    static let empty = SharedStepData(steps: 0, distance: 0, goal: 10000, forDate: Date(), updatedAt: Date())
}

// MARK: - StepTrackingService

/// Service for IWT workout session tracking.
/// Daily step tracking is handled by StepRepository.
@MainActor
final class StepTrackingService: NSObject, ObservableObject {

    static let shared = StepTrackingService()

    // MARK: - Dependencies

    private let pedometer = CMPedometer()
    private let healthStore = HKHealthStore()

    // MARK: - Published State (Forwarded from StepRepository)

    /// Today's step count - forwarded from StepRepository
    var todaySteps: Int { StepRepository.shared.todaySteps }

    /// Today's distance - forwarded from StepRepository
    var todayDistance: Double { StepRepository.shared.todayDistance }

    /// Daily step goal - forwarded from StepRepository
    var stepGoal: Int {
        get { StepRepository.shared.stepGoal }
        set { StepRepository.shared.stepGoal = newValue }
    }

    /// Authorization status
    @Published private(set) var isAuthorized: Bool = false

    /// Current error (if any)
    @Published private(set) var error: Error?

    // MARK: - Session Tracking (for IWT workouts)

    @Published private(set) var isTracking: Bool = false
    @Published private(set) var sessionSteps: Int = 0
    @Published private(set) var sessionDistance: Double = 0
    @Published private(set) var currentPace: Double? = nil
    @Published private(set) var currentCadence: Double? = nil
    @Published var currentHeartRate: Double = 0
    @Published var activeCalories: Double = 0

    private var sessionStartTime: Date?
    private var sessionUpdateHandler: ((PedometerUpdate) -> Void)?
    private var heartRateSamples: [Double] = []

    // MARK: - Initialization

    override private init() {
        super.init()

        if CMPedometer.authorizationStatus() == .authorized {
            isAuthorized = true
        }
    }

    // MARK: - Authorization

    /// Request authorization for HealthKit and CoreMotion
    func requestAuthorization() async throws {
        guard HKHealthStore.isHealthDataAvailable() else {
            throw StepTrackingError.notAvailable
        }

        let typesToRead: Set<HKObjectType> = [
            HKQuantityType.quantityType(forIdentifier: .stepCount)!,
            HKQuantityType.quantityType(forIdentifier: .distanceWalkingRunning)!,
            HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned)!,
            HKQuantityType.quantityType(forIdentifier: .heartRate)!
        ]

        let typesToWrite: Set<HKSampleType> = [
            HKQuantityType.quantityType(forIdentifier: .stepCount)!,
            HKQuantityType.quantityType(forIdentifier: .distanceWalkingRunning)!,
            HKObjectType.workoutType()
        ]

        try await healthStore.requestAuthorization(toShare: typesToWrite, read: typesToRead)

        // Trigger CoreMotion authorization
        if CMPedometer.isStepCountingAvailable() {
            let now = Date()
            let oneMinuteAgo = now.addingTimeInterval(-60)

            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                pedometer.queryPedometerData(from: oneMinuteAgo, to: now) { _, error in
                    if let error = error {
                        continuation.resume(throwing: error)
                    } else {
                        continuation.resume()
                    }
                }
            }
        }

        isAuthorized = true
    }

    /// Request CoreMotion pedometer authorization ONLY
    func requestPedometerAuthorization() async throws {
        guard CMPedometer.isStepCountingAvailable() else {
            throw StepTrackingError.notAvailable
        }

        let now = Date()
        let oneMinuteAgo = now.addingTimeInterval(-60)

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            pedometer.queryPedometerData(from: oneMinuteAgo, to: now) { _, error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume()
                }
            }
        }
    }

    // MARK: - Real-Time Step Queries

    /// Get today's total steps from CMPedometer (instant, no HealthKit delay).
    /// Use this at walk start to capture accurate starting steps.
    /// Falls back to nil if CMPedometer is unavailable.
    func queryTodayStepsFromPedometer() async -> Int? {
        guard CMPedometer.isStepCountingAvailable() else { return nil }

        let today = Calendar.current.startOfDay(for: Date())

        return await withCheckedContinuation { continuation in
            pedometer.queryPedometerData(from: today, to: Date()) { data, error in
                if let data = data {
                    continuation.resume(returning: data.numberOfSteps.intValue)
                } else {
                    continuation.resume(returning: nil)
                }
            }
        }
    }

    // MARK: - Session Tracking (for IWT workouts)

    func startSession(onUpdate: ((PedometerUpdate) -> Void)? = nil) {
        guard CMPedometer.isStepCountingAvailable() else {
            error = StepTrackingError.notAvailable
            return
        }

        sessionStartTime = Date()
        sessionSteps = 0
        sessionDistance = 0
        currentPace = nil
        currentCadence = nil
        heartRateSamples = []
        currentHeartRate = 0
        activeCalories = 0
        isTracking = true
        sessionUpdateHandler = onUpdate

        pedometer.startUpdates(from: Date()) { [weak self] data, error in
            guard let strongSelf = self, let data = data, error == nil else { return }

            Task { @MainActor in
                strongSelf.sessionSteps = data.numberOfSteps.intValue
                strongSelf.sessionDistance = data.distance?.doubleValue ?? 0
                strongSelf.currentPace = data.currentPace?.doubleValue
                strongSelf.currentCadence = data.currentCadence?.doubleValue

                if let startTime = strongSelf.sessionStartTime {
                    let update = PedometerUpdate(
                        steps: strongSelf.sessionSteps,
                        distance: strongSelf.sessionDistance,
                        pace: strongSelf.currentPace,
                        cadence: strongSelf.currentCadence,
                        startDate: startTime,
                        endDate: data.endDate
                    )
                    strongSelf.sessionUpdateHandler?(update)
                }
            }
        }
    }

    func stopSession() async -> SessionSummary? {
        pedometer.stopUpdates()
        isTracking = false

        guard let startTime = sessionStartTime else { return nil }

        let summary = SessionSummary(
            startTime: startTime,
            endTime: Date(),
            steps: sessionSteps,
            distance: sessionDistance
        )

        sessionStartTime = nil
        sessionSteps = 0
        sessionDistance = 0
        currentPace = nil
        currentCadence = nil
        sessionUpdateHandler = nil

        return summary
    }

    // MARK: - Computed Properties

    var goalProgress: Double {
        StepRepository.shared.goalProgress
    }

    var stepsRemaining: Int {
        StepRepository.shared.stepsRemaining
    }

    var formattedDistance: String {
        FormatUtils.formatDistance(todayDistance)
    }

    var sessionAverageHeartRate: Double {
        guard !heartRateSamples.isEmpty else { return 0 }
        return heartRateSamples.reduce(0, +) / Double(heartRateSamples.count)
    }

    // MARK: - Pace Helpers

    func currentPaceCategory() -> PaceCategory {
        guard let pace = currentPace else { return .unknown }
        let minutesPerMile = (pace * 1609.34) / 60

        switch minutesPerMile {
        case ..<13: return .veryBrisk
        case 13..<16: return .brisk
        case 16..<20: return .moderate
        case 20..<25: return .slow
        default: return .verySlow
        }
    }

    func formattedPace() -> String {
        guard let pace = currentPace, pace > 0 else { return "--:--" }
        return FormatUtils.formatPace(pace)
    }
}

// MARK: - API Compatibility

extension StepTrackingService {

    /// Start tracking - delegates to StepRepository
    func startTracking() {
        Task {
            await StepRepository.shared.initialize()
        }
    }

    /// Handle app becoming active - delegates to StepRepository
    func handleAppBecomeActive() {
        Task {
            await StepRepository.shared.handleAppForeground()
        }
    }

    /// Check for new day - delegates to StepRepository
    func checkForNewDay() -> Bool {
        // StepRepository handles day changes automatically
        return false
    }

    /// Refresh from HealthKit - delegates to StepRepository
    func refreshHealthKitData() {
        Task {
            await StepRepository.shared.forceRefresh()
        }
    }

    /// Load today's steps - delegates to StepRepository
    func loadTodaySteps() {
        Task {
            await StepRepository.shared.forceRefresh()
        }
    }

    /// Start today updates - no-op (StepRepository handles this)
    func startTodayUpdates() {
        // StepRepository handles daily updates
    }

    /// Stop today updates - no-op
    func stopTodayUpdates() {
        // StepRepository handles daily updates
    }

    /// Force widget update
    func forceWidgetUpdate() {
        StepRepository.shared.forceWidgetRefresh()
    }

    /// Watch workout commands (no-op - Watch is independent)
    func requestWatchWorkoutStart(mode: String = "interval") {
        print("ℹ️ Watch manages workouts independently")
    }

    func requestWatchWorkoutStop() {
        print("ℹ️ Watch manages workouts independently")
    }

    /// Simulate today data (debug)
    func simulateTodayData(steps: Int, distance: Double) {
        #if DEBUG
        StepRepository.shared.debugSetSteps(steps, distance: distance)
        #endif
    }

    /// Simulate history (debug)
    func simulateHistory(steps: Int, for date: Date) {
        #if DEBUG
        let distance = Double(steps) * 0.762
        StepRepository.shared.debugSetStepsForDate(steps, distance: distance, date: date)
        #endif
    }
}

// MARK: - Static Helpers

extension StepTrackingService {

    static var isAvailable: Bool {
        CMPedometer.isStepCountingAvailable()
    }

    static var authorizationStatus: CMAuthorizationStatus {
        CMPedometer.authorizationStatus()
    }
}

// MARK: - Supporting Types

struct SessionSummary {
    let startTime: Date
    let endTime: Date
    let steps: Int
    let distance: Double

    var duration: TimeInterval {
        endTime.timeIntervalSince(startTime)
    }

    var formattedDuration: String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}

struct PedometerUpdate {
    let steps: Int
    let distance: Double
    let pace: Double?
    let cadence: Double?
    let startDate: Date
    let endDate: Date

    var duration: TimeInterval {
        endDate.timeIntervalSince(startDate)
    }

    var formattedDuration: String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}

enum PaceCategory: String {
    case veryBrisk = "Very Brisk"
    case brisk = "Brisk"
    case moderate = "Moderate"
    case slow = "Slow"
    case verySlow = "Very Slow"
    case unknown = "Unknown"

    var description: String {
        switch self {
        case .veryBrisk: return "Excellent pace! You're power walking."
        case .brisk: return "Great brisk walking pace for IWT."
        case .moderate: return "Good moderate walking pace."
        case .slow: return "Perfect recovery pace for IWT."
        case .verySlow: return "Easy stroll pace."
        case .unknown: return "Keep walking to measure pace."
        }
    }

    var isBriskForIWT: Bool {
        self == .veryBrisk || self == .brisk
    }

    var isSlowForIWT: Bool {
        self == .moderate || self == .slow || self == .verySlow
    }
}

enum StepTrackingError: LocalizedError {
    case notAvailable
    case notAuthorized

    var errorDescription: String? {
        switch self {
        case .notAvailable:
            return "Step counting is not available on this device."
        case .notAuthorized:
            return "Motion & Fitness access has not been authorized."
        }
    }
}

extension Notification.Name {
    static let remoteSessionStarted = Notification.Name("RemoteSessionStarted")
    static let remoteSessionStopped = Notification.Name("RemoteSessionStopped")
    static let remoteSessionPaused = Notification.Name("RemoteSessionPaused")
    static let remoteSessionResumed = Notification.Name("RemoteSessionResumed")
    static let scrollToTop = Notification.Name("ScrollToTop")
    static let switchToProgressTab = Notification.Name("SwitchToProgressTab")
    static let switchToWalkTab = Notification.Name("SwitchToWalkTab")
    static let startWalkFromDashboard = Notification.Name("StartWalkFromDashboard")
}
