//
//  WatchHealthKitManager.swift
//  JustWalkWatch Watch App
//
//  HealthKit integration for watchOS with simulator fallback
//

import Foundation
import HealthKit
import WidgetKit
import os

// MARK: - Step Data State Machine

enum StepDataState: Equatable {
    case loading
    case available(steps: Int)
    case unavailable(reason: UnavailableReason)
}

enum UnavailableReason: Equatable {
    case notAuthorized
    case noHealthData
}

@Observable
class WatchHealthKitManager {
    static let shared = WatchHealthKitManager()

    private nonisolated static let logger = Logger(subsystem: "com.justwalk.watch", category: "HealthKit")

    private let healthStore = HKHealthStore()
    private nonisolated static let widgetAppGroupID = "group.com.justwalk.shared"

    private var widgetDefaults: UserDefaults {
        UserDefaults(suiteName: Self.widgetAppGroupID) ?? .standard
    }

    var todaySteps: Int = 0
    var isAuthorized: Bool = false
    var healthDataUnavailable: Bool = false
    var isRefreshing: Bool = false

    /// State machine for step data availability
    var stepDataState: StepDataState = .loading

    /// Tracks when steps were last fetched to detect day changes
    private var lastFetchDate: Date?

    /// Last known steps for timeout fallback
    private var lastKnownSteps: Int?

    /// Observer query that fires when new step data is written
    private var stepObserverQuery: HKObserverQuery?

    #if targetEnvironment(simulator)
    private let isSimulator = true
    private let mockDailySteps = 4500
    #else
    private let isSimulator = false
    private let mockDailySteps = 0
    #endif

    private init() {}

    // MARK: - Authorization

    func requestAuthorization() async -> Bool {
        if isSimulator {
            isAuthorized = true
            todaySteps = mockStepsForTimeOfDay()
            stepDataState = .available(steps: todaySteps)
            return true
        }

        guard HKHealthStore.isHealthDataAvailable() else {
            healthDataUnavailable = true
            stepDataState = .unavailable(reason: .noHealthData)
            Self.logger.warning("HealthKit not available on this device")
            return false
        }
        healthDataUnavailable = false

        let stepType = HKQuantityType(.stepCount)
        let distanceType = HKQuantityType(.distanceWalkingRunning)
        let dobType = HKObjectType.characteristicType(forIdentifier: .dateOfBirth)!
        let typesToRead: Set<HKObjectType> = [stepType, distanceType, dobType]

        do {
            try await healthStore.requestAuthorization(toShare: [], read: typesToRead)
            isAuthorized = true
            return true
        } catch {
            Self.logger.error("HealthKit authorization failed: \(error.localizedDescription)")
            stepDataState = .unavailable(reason: .notAuthorized)
            return false
        }
    }

    /// Combined authorization and fetch for clean first-launch experience
    func requestAuthorizationAndFetch() async {
        stepDataState = .loading

        let authorized = await requestAuthorization()
        if authorized {
            _ = await fetchTodaySteps()
        }
        // State is already set by requestAuthorization or fetchTodaySteps
    }

    // MARK: - Step Observer

    /// Sets up an observer query that fires when new step data is written to HealthKit.
    /// Call once at app launch after authorization.
    func setupStepObserver() {
        guard !isSimulator else { return }
        guard stepObserverQuery == nil else { return } // Already set up

        let stepType = HKQuantityType(.stepCount)

        let query = HKObserverQuery(sampleType: stepType, predicate: nil) { [weak self] _, completionHandler, error in
            if let error = error {
                Self.logger.error("Step observer error: \(error.localizedDescription)")
                completionHandler()
                return
            }

            Self.logger.debug("Step observer triggered - new step data available")
            Task { @MainActor in
                _ = await self?.fetchTodaySteps()
            }
            completionHandler()
        }

        healthStore.execute(query)
        stepObserverQuery = query
        Self.logger.info("Step observer query started")
    }

    // MARK: - Today Steps

    /// Checks if the day has changed since last fetch and refreshes if needed.
    /// Also re-fetches data to detect if user enabled permissions in Settings.
    /// Call this on foreground/wrist raise to ensure fresh data.
    func refreshIfDayChanged() async {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        if let lastFetch = lastFetchDate {
            let lastFetchDay = calendar.startOfDay(for: lastFetch)
            if lastFetchDay != today {
                Self.logger.info("Day changed - clearing stale steps and fetching fresh data")
                // Clear stale data immediately to prevent flashing yesterday's count
                todaySteps = 0
                lastKnownSteps = nil
                stepDataState = .loading
                _ = await fetchTodaySteps()
            } else if case .unavailable = stepDataState {
                // Was unavailable - user might have enabled permissions in Settings
                Self.logger.info("Re-checking after unavailable state")
                _ = await fetchTodaySteps()
            }
        } else {
            // No previous fetch - fetch now
            _ = await fetchTodaySteps()
        }
    }

    func fetchTodaySteps() async -> Int {
        isRefreshing = true
        defer { isRefreshing = false }

        if isSimulator {
            let steps = mockStepsForTimeOfDay()
            todaySteps = steps
            lastKnownSteps = steps
            lastFetchDate = Date()
            stepDataState = .available(steps: steps)
            updateWidgetSteps(steps)
            return steps
        }

        guard HKHealthStore.isHealthDataAvailable() else {
            healthDataUnavailable = true
            stepDataState = .unavailable(reason: .noHealthData)
            Self.logger.warning("HealthKit not available on device")
            return 0
        }
        healthDataUnavailable = false

        // Fetch with timeout to handle hung queries
        let result = await fetchStepsWithTimeout()

        if let steps = result {
            todaySteps = steps
            lastKnownSteps = steps
            lastFetchDate = Date()
            stepDataState = .available(steps: steps)
            updateWidgetSteps(steps)
            Self.logger.info("Today's steps: \(steps)")
            return steps
        } else {
            // Query timed out - use last known or 0
            let fallback = lastKnownSteps ?? 0
            todaySteps = fallback
            stepDataState = .available(steps: fallback)
            Self.logger.warning("Step query timed out, using fallback: \(fallback)")
            return fallback
        }
    }

    /// Fetches steps with a 5-second timeout to prevent hung queries
    private func fetchStepsWithTimeout() async -> Int? {
        let stepType = HKQuantityType(.stepCount)
        let now = Date()
        let startOfDay = Calendar.current.startOfDay(for: now)
        Self.logger.debug("Fetching steps from \(startOfDay) to \(now)")
        let predicate = HKQuery.predicateForSamples(withStart: startOfDay, end: now, options: .strictStartDate)

        return await withTaskGroup(of: Int?.self) { group in
            group.addTask {
                let steps = await self.querySum(type: stepType, predicate: predicate, unit: .count())
                return Int(steps)
            }

            group.addTask {
                try? await Task.sleep(nanoseconds: 5_000_000_000) // 5 seconds
                return nil
            }

            // Return first completed result
            if let first = await group.next() {
                group.cancelAll()
                return first
            }
            return nil
        }
    }

    // MARK: - Walk Data

    func fetchStepsDuring(start: Date, end: Date) async -> Int {
        if isSimulator {
            let minutes = end.timeIntervalSince(start) / 60
            return Int(minutes * 100)
        }

        let stepType = HKQuantityType(.stepCount)
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)
        return Int(await querySum(type: stepType, predicate: predicate, unit: .count()))
    }

    func fetchDistanceDuring(start: Date, end: Date) async -> Double {
        if isSimulator {
            let minutes = end.timeIntervalSince(start) / 60
            return minutes * 80
        }

        let distanceType = HKQuantityType(.distanceWalkingRunning)
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)
        return await querySum(type: distanceType, predicate: predicate, unit: .meter())
    }

    // MARK: - Private

    private func querySum(type: HKQuantityType, predicate: NSPredicate, unit: HKUnit) async -> Double {
        await withCheckedContinuation { continuation in
            Self.logger.debug("Executing HealthKit query for \(type.identifier)")
            let query = HKStatisticsQuery(
                quantityType: type,
                quantitySamplePredicate: predicate,
                options: .cumulativeSum
            ) { _, result, error in
                if let error = error {
                    Self.logger.error("HealthKit query failed for \(type.identifier): \(error.localizedDescription)")
                    continuation.resume(returning: 0)
                    return
                }
                guard let result = result else {
                    Self.logger.warning("HealthKit query returned nil result for \(type.identifier) - likely no read permission")
                    continuation.resume(returning: 0)
                    return
                }
                guard let sum = result.sumQuantity() else {
                    Self.logger.info("HealthKit query returned no data for \(type.identifier) (sumQuantity is nil)")
                    continuation.resume(returning: 0)
                    return
                }
                let value = sum.doubleValue(for: unit)
                Self.logger.debug("HealthKit query for \(type.identifier) returned: \(value)")
                continuation.resume(returning: value)
            }
            healthStore.execute(query)
        }
    }

    private func mockStepsForTimeOfDay() -> Int {
        let calendar = Calendar.current
        let now = Date()
        let startOfDay = calendar.startOfDay(for: now)
        let secondsElapsed = now.timeIntervalSince(startOfDay)
        let progress = secondsElapsed / 86400
        return Int(Double(mockDailySteps) * progress)
    }

    private func updateWidgetSteps(_ steps: Int) {
        widgetDefaults.set(steps, forKey: "widget_todaySteps")
        WidgetCenter.shared.reloadAllTimelines()
    }
}
