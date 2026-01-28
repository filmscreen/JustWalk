//
//  HealthKitManager.swift
//  JustWalk
//
//  HealthKit integration with authorization, step tracking, and Simulator mock mode
//

import Foundation
import HealthKit
import Combine

@Observable
class HealthKitManager: ObservableObject {
    static let shared = HealthKitManager()

    private let healthStore = HKHealthStore()
    private var stepQuery: HKObserverQuery?

    var todaySteps: Int = 0
    var isAuthorized: Bool = false

    // MARK: - Simulator Mock Mode
    #if targetEnvironment(simulator)
    private let isSimulator = true
    private let mockDailySteps = 4500
    private static let simulatorAuthKey = "simulatorHealthKitAuthorized"
    #else
    private let isSimulator = false
    private let mockDailySteps = 0
    #endif

    // Debug override
    var simulateWalkEnabled: Bool = false

    #if DEBUG
    var debugStepOverride: Int? = nil
    #endif

    private init() {}

    // MARK: - Health Types

    private var healthReadTypes: Set<HKObjectType> {
        [
            HKQuantityType(.stepCount),
            HKQuantityType(.distanceWalkingRunning),
            HKQuantityType(.activeEnergyBurned),
            HKQuantityType(.heartRate),
            HKWorkoutType.workoutType()
        ]
    }

    private var healthWriteTypes: Set<HKSampleType> {
        [HKWorkoutType.workoutType()]
    }

    // MARK: - Authorization

    /// Returns true if we can read step data (either previously authorized or simulator).
    func isCurrentlyAuthorized() async -> Bool {
        #if targetEnvironment(simulator)
        if isSimulator && (isAuthorized || UserDefaults.standard.bool(forKey: Self.simulatorAuthKey)) {
            return true
        }
        #endif
        guard HKHealthStore.isHealthDataAvailable() else { return false }

        do {
            let status = try await healthStore.statusForAuthorizationRequest(
                toShare: healthWriteTypes,
                read: healthReadTypes
            )
            // .unnecessary means the system already presented the dialog — user chose grant or deny
            return status == .unnecessary
        } catch {
            return false
        }
    }

    /// Initialize step observation for already-authorized returning users.
    /// Call this on app launch to start receiving step updates.
    @MainActor
    func initializeIfAuthorized() async -> Bool {
        let authorized = await isCurrentlyAuthorized()
        guard authorized else { return false }

        isAuthorized = true

        #if targetEnvironment(simulator)
        _ = await loadMockSteps()
        #else
        startObservingSteps()
        let steps = await fetchTodaySteps()
        todaySteps = steps
        #endif

        return true
    }

    @MainActor
    func requestAuthorization() async -> Bool {
        // Try real HealthKit authorization if available (works on modern simulators too)
        if HKHealthStore.isHealthDataAvailable() {
            do {
                print("[HealthKit] Requesting system authorization...")
                try await healthStore.requestAuthorization(toShare: healthWriteTypes, read: healthReadTypes)
                print("[HealthKit] Authorization completed")
                isAuthorized = true
                #if targetEnvironment(simulator)
                UserDefaults.standard.set(true, forKey: Self.simulatorAuthKey)
                _ = await loadMockSteps()
                #else
                startObservingSteps()
                let steps = await fetchTodaySteps()
                todaySteps = steps
                #endif
                return true
            } catch {
                print("[HealthKit] Authorization error: \(error.localizedDescription)")
                // On simulator, fall through to mock path below
                if !isSimulator { return false }
            }
        }

        // Simulator fallback when HealthKit is unavailable or auth failed
        if isSimulator {
            print("[HealthKit] Using simulator mock authorization")
            isAuthorized = true
            #if targetEnvironment(simulator)
            UserDefaults.standard.set(true, forKey: Self.simulatorAuthKey)
            #endif
            _ = await loadMockSteps()
            return true
        }

        print("[HealthKit] Health data not available on this device")
        return false
    }

    // MARK: - Step Tracking

    func fetchTodaySteps() async -> Int {
        #if DEBUG
        if let override = debugStepOverride {
            todaySteps = override
            return override
        }
        #endif

        if isSimulator || simulateWalkEnabled {
            return await loadMockSteps()
        }

        let stepType = HKQuantityType(.stepCount)
        let now = Date()
        let startOfDay = Calendar.current.startOfDay(for: now)
        let predicate = HKQuery.predicateForSamples(withStart: startOfDay, end: now, options: .strictStartDate)

        return await withCheckedContinuation { continuation in
            let query = HKStatisticsQuery(
                quantityType: stepType,
                quantitySamplePredicate: predicate,
                options: .cumulativeSum
            ) { _, result, error in
                guard let result = result, let sum = result.sumQuantity() else {
                    continuation.resume(returning: 0)
                    return
                }
                let steps = Int(sum.doubleValue(for: HKUnit.count()))
                continuation.resume(returning: steps)
            }
            healthStore.execute(query)
        }
    }

    @MainActor
    private func loadMockSteps() async -> Int {
        // Simulate realistic step accumulation throughout the day
        let calendar = Calendar.current
        let now = Date()
        let startOfDay = calendar.startOfDay(for: now)
        let secondsElapsed = now.timeIntervalSince(startOfDay)
        let totalDaySeconds: Double = 86400

        // Assume steps accumulate linearly (simplified)
        let progress = secondsElapsed / totalDaySeconds
        let steps = Int(Double(mockDailySteps) * progress)

        todaySteps = steps
        return steps
    }

    private func startObservingSteps() {
        guard !isSimulator else { return }

        let stepType = HKQuantityType(.stepCount)

        stepQuery = HKObserverQuery(sampleType: stepType, predicate: nil) { [weak self] _, _, error in
            guard error == nil, let self = self else { return }
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                let steps = await self.fetchTodaySteps()
                self.todaySteps = steps
            }
        }

        if let query = stepQuery {
            healthStore.execute(query)
        }
    }

    func stopObservingSteps() {
        if let query = stepQuery {
            healthStore.stop(query)
            stepQuery = nil
        }
    }

    // MARK: - Walk Data

    func fetchStepsDuring(start: Date, end: Date) async -> Int {
        if isSimulator || simulateWalkEnabled {
            // Mock: ~100 steps per minute
            let minutes = end.timeIntervalSince(start) / 60
            return Int(minutes * 100)
        }

        let stepType = HKQuantityType(.stepCount)
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)

        return await withCheckedContinuation { continuation in
            let query = HKStatisticsQuery(
                quantityType: stepType,
                quantitySamplePredicate: predicate,
                options: .cumulativeSum
            ) { _, result, error in
                guard let result = result, let sum = result.sumQuantity() else {
                    continuation.resume(returning: 0)
                    return
                }
                let steps = Int(sum.doubleValue(for: HKUnit.count()))
                continuation.resume(returning: steps)
            }
            healthStore.execute(query)
        }
    }

    func fetchDistanceDuring(start: Date, end: Date) async -> Double {
        if isSimulator || simulateWalkEnabled {
            // Mock: ~80 meters per minute walking
            let minutes = end.timeIntervalSince(start) / 60
            return minutes * 80
        }

        let distanceType = HKQuantityType(.distanceWalkingRunning)
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)

        return await withCheckedContinuation { continuation in
            let query = HKStatisticsQuery(
                quantityType: distanceType,
                quantitySamplePredicate: predicate,
                options: .cumulativeSum
            ) { _, result, error in
                guard let result = result, let sum = result.sumQuantity() else {
                    continuation.resume(returning: 0)
                    return
                }
                let meters = sum.doubleValue(for: HKUnit.meter())
                continuation.resume(returning: meters)
            }
            healthStore.execute(query)
        }
    }

    // MARK: - Average Daily Steps (Onboarding Calibration)

    func fetchAverageDailySteps(days: Int = 30) async -> Int {
        if isSimulator || simulateWalkEnabled {
            return 4500
        }

        guard HKHealthStore.isHealthDataAvailable() else { return 5000 }

        let stepType = HKQuantityType(.stepCount)
        let calendar = Calendar.current
        let now = Date()
        guard let startDate = calendar.date(byAdding: .day, value: -days, to: calendar.startOfDay(for: now)) else {
            return 5000
        }

        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: now, options: .strictStartDate)
        let interval = DateComponents(day: 1)

        return await withCheckedContinuation { continuation in
            let query = HKStatisticsCollectionQuery(
                quantityType: stepType,
                quantitySamplePredicate: predicate,
                options: .cumulativeSum,
                anchorDate: calendar.startOfDay(for: now),
                intervalComponents: interval
            )

            query.initialResultsHandler = { _, results, error in
                guard let results = results else {
                    continuation.resume(returning: 5000)
                    return
                }

                var totalSteps: Double = 0
                var daysWithData: Int = 0

                results.enumerateStatistics(from: startDate, to: now) { statistics, _ in
                    if let sum = statistics.sumQuantity() {
                        let steps = sum.doubleValue(for: HKUnit.count())
                        if steps > 0 {
                            totalSteps += steps
                            daysWithData += 1
                        }
                    }
                }

                guard daysWithData > 0 else {
                    continuation.resume(returning: 5000)
                    return
                }

                let average = Int(totalSteps / Double(daysWithData))
                continuation.resume(returning: max(average, 1000))
            }

            self.healthStore.execute(query)
        }
    }

    // MARK: - Historical Data

    /// Returns the earliest date that has step data in HealthKit, or nil if none found.
    func fetchEarliestStepDate() async -> Date? {
        if isSimulator || simulateWalkEnabled {
            // Simulator mock: pretend data goes back 45 days
            return Calendar.current.date(byAdding: .day, value: -45, to: Date())
        }

        guard HKHealthStore.isHealthDataAvailable() else { return nil }

        let stepType = HKQuantityType(.stepCount)
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)

        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: stepType,
                predicate: nil,
                limit: 1,
                sortDescriptors: [sortDescriptor]
            ) { _, samples, error in
                guard let sample = samples?.first else {
                    continuation.resume(returning: nil)
                    return
                }
                continuation.resume(returning: sample.startDate)
            }
            healthStore.execute(query)
        }
    }

    // MARK: - Utility

    func fetchCaloriesDuring(start: Date, end: Date) async -> Double {
        if isSimulator || simulateWalkEnabled {
            // Mock: ~5 calories per minute walking
            let minutes = end.timeIntervalSince(start) / 60
            return minutes * 5
        }

        let calorieType = HKQuantityType(.activeEnergyBurned)
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)

        return await withCheckedContinuation { continuation in
            let query = HKStatisticsQuery(
                quantityType: calorieType,
                quantitySamplePredicate: predicate,
                options: .cumulativeSum
            ) { _, result, error in
                guard let result = result, let sum = result.sumQuantity() else {
                    continuation.resume(returning: 0)
                    return
                }
                let calories = sum.doubleValue(for: HKUnit.kilocalorie())
                continuation.resume(returning: calories)
            }
            healthStore.execute(query)
        }
    }
}
