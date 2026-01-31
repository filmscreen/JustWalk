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
    static let historySyncDays = 90

    private let healthStore = HKHealthStore()
    private var stepQuery: HKObserverQuery?

    var todaySteps: Int = 0
    var isAuthorized: Bool = false
    private var lastTodayStepsFetch: Date?
    private let todayStepsCacheTTL: TimeInterval = 15
    private var lastWidgetUpdate: Date?
    private let widgetUpdateTTL: TimeInterval = 30

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
    #if DEBUG
    var simulateWalkEnabled: Bool = false
    #else
    private let simulateWalkEnabled = false
    #endif

    #if DEBUG
    var debugStepOverride: Int? = nil
    #endif

    private init() {}

    // MARK: - Authorization Guard

    private func ensureAuthorizedIfNeeded() async -> Bool {
        if isSimulator || simulateWalkEnabled {
            return true
        }
        let authorized = await isCurrentlyAuthorized()
        if !authorized {
            isAuthorized = false
            stopObservingSteps()
        }
        return authorized
    }

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
        [
            HKWorkoutType.workoutType(),
            HKQuantityType(.distanceWalkingRunning),
            HKQuantityType(.activeEnergyBurned)
        ]
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
        let steps = await loadMockSteps()
        StepDataManager.shared.updateTodaySteps(steps, goalTarget: PersistenceManager.shared.loadProfile().dailyStepGoal)
        #else
        startObservingSteps()
        _ = await fetchTodaySteps(force: true)
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
                let steps = await loadMockSteps()
                StepDataManager.shared.updateTodaySteps(steps, goalTarget: PersistenceManager.shared.loadProfile().dailyStepGoal)
                #else
                startObservingSteps()
                _ = await fetchTodaySteps(force: true)
                #endif
                // Note: Don't backfill here - during onboarding, the goal isn't set yet.
                // HealthKitSyncView handles the explicit sync with the user's chosen goal.
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
            // Note: Don't backfill here - during onboarding, the goal isn't set yet.
            // HealthKitSyncView handles the explicit sync with the user's chosen goal.
            return true
        }

        print("[HealthKit] Health data not available on this device")
        return false
    }

    // MARK: - Step Tracking

    func fetchTodaySteps(force: Bool = false) async -> Int {
        #if DEBUG
        if let override = debugStepOverride {
            await MainActor.run {
                todaySteps = override
                StepDataManager.shared.updateTodaySteps(override, goalTarget: PersistenceManager.shared.loadProfile().dailyStepGoal)
            }
            lastTodayStepsFetch = Date()
            return override
        }
        #endif
        if !force,
           let lastFetch = lastTodayStepsFetch,
           Date().timeIntervalSince(lastFetch) < todayStepsCacheTTL {
            return todaySteps
        }
        guard await ensureAuthorizedIfNeeded() else { return 0 }

        if isSimulator || simulateWalkEnabled {
            let steps = await loadMockSteps()
            lastTodayStepsFetch = Date()
            await MainActor.run {
                todaySteps = steps
                StepDataManager.shared.updateTodaySteps(steps, goalTarget: PersistenceManager.shared.loadProfile().dailyStepGoal)
                updateWidgetsForSteps(steps)
            }
            return steps
        }

        let stepType = HKQuantityType(.stepCount)
        let now = Date()
        let startOfDay = Calendar.current.startOfDay(for: now)
        let predicate = HKQuery.predicateForSamples(withStart: startOfDay, end: now, options: .strictStartDate)

        let steps = await withCheckedContinuation { continuation in
            let query = HKStatisticsQuery(
                quantityType: stepType,
                quantitySamplePredicate: predicate,
                options: .cumulativeSum
            ) { _, result, error in
                guard let result = result, let sum = result.sumQuantity() else {
                    continuation.resume(returning: 0)
                    return
                }
                continuation.resume(returning: Int(sum.doubleValue(for: HKUnit.count())))
            }
            healthStore.execute(query)
        }
        lastTodayStepsFetch = Date()
        await MainActor.run {
            todaySteps = steps
            StepDataManager.shared.updateTodaySteps(steps, goalTarget: PersistenceManager.shared.loadProfile().dailyStepGoal)
            updateWidgetsForSteps(steps)
        }
        return steps
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

        healthStore.enableBackgroundDelivery(for: stepType, frequency: .immediate) { success, error in
            if !success {
                print("[HealthKit] Background delivery not enabled: \(error?.localizedDescription ?? "unknown")")
            }
        }

        stepQuery = HKObserverQuery(sampleType: stepType, predicate: nil) { [weak self] _, completionHandler, error in
            guard error == nil, let self = self else {
                completionHandler()
                return
            }
            Task { @MainActor [weak self] in
                guard let self = self else {
                    completionHandler()
                    return
                }
                _ = await self.fetchTodaySteps(force: true)
                completionHandler()
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
        let stepType = HKQuantityType(.stepCount)
        healthStore.disableBackgroundDelivery(for: stepType) { _, _ in }
    }

    /// Track last step count for complication push delta
    private var lastComplicationPushSteps: Int = 0
    /// Minimum step change to trigger complication push (conserve budget)
    private let complicationPushStepThreshold = 500

    @MainActor
    private func updateWidgetsForSteps(_ steps: Int) {
        if let lastUpdate = lastWidgetUpdate,
           Date().timeIntervalSince(lastUpdate) < widgetUpdateTTL {
            return
        }
        lastWidgetUpdate = Date()
        let persistence = PersistenceManager.shared
        let goal = persistence.loadProfile().dailyStepGoal
        let streak = StreakManager.shared.streakData.currentStreak
        let shields = ShieldManager.shared.availableShields

        let calendar = Calendar.current
        let weekSteps = (-6...0).map { offset -> Int in
            guard let date = calendar.date(byAdding: .day, value: offset, to: Date()) else { return 0 }
            return persistence.loadDailyLog(for: date)?.steps ?? 0
        }

        JustWalkWidgetData.updateWidgetData(
            todaySteps: steps,
            stepGoal: goal,
            currentStreak: streak,
            weekSteps: weekSteps,
            shieldCount: shields,
            forceRefresh: true
        )

        // Push to Watch complications via dedicated channel for faster updates.
        // Only push on significant step changes to conserve the daily budget (~50/day).
        let stepDelta = abs(steps - lastComplicationPushSteps)
        let isGoalJustMet = steps >= goal && lastComplicationPushSteps < goal
        if stepDelta >= complicationPushStepThreshold || isGoalJustMet {
            lastComplicationPushSteps = steps
            PhoneConnectivityManager.shared.pushComplicationUpdate(
                todaySteps: steps,
                stepGoal: goal,
                currentStreak: streak
            )
        }
    }

    // MARK: - Walk Data

    func fetchStepsDuring(start: Date, end: Date) async -> Int {
        guard await ensureAuthorizedIfNeeded() else { return 0 }
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
        guard await ensureAuthorizedIfNeeded() else { return 0 }
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
        guard await ensureAuthorizedIfNeeded() else { return 0 }
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

    /// Returns daily step totals for the last N days (including today), oldest → newest.
    func fetchDailyStepCounts(days: Int) async -> [(Date, Int)] {
        guard days > 0 else { return [] }
        guard await ensureAuthorizedIfNeeded() else { return [] }

        if isSimulator || simulateWalkEnabled {
            let calendar = Calendar.current
            let today = calendar.startOfDay(for: Date())
            return (0..<days).map { offset in
                let date = calendar.date(byAdding: .day, value: -(days - 1 - offset), to: today) ?? today
                return (date, mockDailySteps)
            }
        }

        guard HKHealthStore.isHealthDataAvailable() else { return [] }

        let stepType = HKQuantityType(.stepCount)
        let calendar = Calendar.current
        let now = Date()
        let endDate = now
        guard let startDate = calendar.date(byAdding: .day, value: -(days - 1), to: calendar.startOfDay(for: now)) else {
            return []
        }

        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictStartDate)
        let interval = DateComponents(day: 1)

        return await withCheckedContinuation { continuation in
            let query = HKStatisticsCollectionQuery(
                quantityType: stepType,
                quantitySamplePredicate: predicate,
                options: .cumulativeSum,
                anchorDate: calendar.startOfDay(for: now),
                intervalComponents: interval
            )

            query.initialResultsHandler = { _, results, _ in
                guard let results = results else {
                    continuation.resume(returning: [])
                    return
                }

                var output: [(Date, Int)] = []
                results.enumerateStatistics(from: startDate, to: endDate) { statistics, _ in
                    let steps = Int(statistics.sumQuantity()?.doubleValue(for: HKUnit.count()) ?? 0)
                    output.append((statistics.startDate, steps))
                }

                // Ensure chronological order
                output.sort { $0.0 < $1.0 }
                continuation.resume(returning: output)
            }

            self.healthStore.execute(query)
        }
    }

    /// Backfills persisted DailyLogs from HealthKit for recent days if history is missing.
    func backfillDailyLogsIfNeeded(days: Int, dailyGoal: Int) async -> Int {
        guard await ensureAuthorizedIfNeeded() else { return 0 }

        let persistence = PersistenceManager.shared
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let hasHistoricalLogs = persistence.loadAllDailyLogs().contains { log in
            calendar.startOfDay(for: log.date) < today
        }

        guard !hasHistoricalLogs else { return 0 }

        let history = await fetchDailyStepCounts(days: days)
        var saved = 0

        for (date, steps) in history {
            if persistence.loadDailyLog(for: date) == nil {
                let log = DailyLog(
                    id: UUID(),
                    date: calendar.startOfDay(for: date),
                    steps: steps,
                    goalMet: steps >= dailyGoal,
                    shieldUsed: false,
                    trackedWalkIDs: [],
                    goalTarget: dailyGoal
                )
                persistence.saveDailyLog(log)
                saved += 1
            }
        }

        return saved
    }

    /// Manually sync HealthKit history - fills gaps and updates days with 0 steps.
    /// Unlike backfillDailyLogsIfNeeded, this always runs and updates existing logs.
    func syncHealthKitHistory(days: Int, dailyGoal: Int) async -> (synced: Int, total: Int) {
        guard await ensureAuthorizedIfNeeded() else { return (0, 0) }

        let persistence = PersistenceManager.shared
        let calendar = Calendar.current
        let history = await fetchDailyStepCounts(days: days)

        var synced = 0
        var didChangeGoalState = false
        for (date, steps) in history {
            let dayStart = calendar.startOfDay(for: date)

            if let existingLog = persistence.loadDailyLog(for: dayStart) {
                // IMPORTANT: Preserve historical goalTarget - never overwrite with current goal
                // Only set goalTarget if it was never set (nil), otherwise keep it frozen
                let goal = existingLog.goalTarget ?? dailyGoal
                let goalMet = existingLog.shieldUsed ? true : (steps >= goal)

                // Only update steps and goalMet; preserve goalTarget if already set
                let needsUpdate = existingLog.steps != steps ||
                    existingLog.goalMet != goalMet ||
                    (existingLog.goalTarget == nil)

                if needsUpdate {
                    var updatedLog = existingLog
                    updatedLog.steps = steps
                    // Only set goalTarget if it was nil - never overwrite existing historical goal
                    if existingLog.goalTarget == nil {
                        updatedLog.goalTarget = dailyGoal
                    }
                    updatedLog.goalMet = goalMet
                    persistence.saveDailyLog(updatedLog)
                    synced += 1
                    didChangeGoalState = true
                }
            } else {
                // Create new log for missing day
                let log = DailyLog(
                    id: UUID(),
                    date: dayStart,
                    steps: steps,
                    goalMet: steps >= dailyGoal,
                    shieldUsed: false,
                    trackedWalkIDs: [],
                    goalTarget: dailyGoal
                )
                persistence.saveDailyLog(log)
                synced += 1
                didChangeGoalState = true
            }
        }

        if didChangeGoalState {
            StreakManager.shared.recalculateStreak()
        }

        // Trigger UI refresh only when changes were applied
        if synced > 0 {
            persistence.dailyLogVersion += 1
        }

        return (synced, history.count)
    }

    /// Returns the earliest date that has step data in HealthKit, or nil if none found.
    func fetchEarliestStepDate() async -> Date? {
        guard await ensureAuthorizedIfNeeded() else { return nil }
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

    // MARK: - Workout Saving

    /// Saves a completed walk as an HKWorkout to Apple Health/Fitness.
    /// Returns true if successfully saved.
    func saveWorkout(
        startDate: Date,
        endDate: Date,
        totalDistance: Double,
        totalCalories: Double?
    ) async -> Bool {
        guard await ensureAuthorizedIfNeeded() else {
            print("[HealthKit] Not authorized to save workouts")
            return false
        }

        // Skip saving on simulator
        if isSimulator || simulateWalkEnabled {
            print("[HealthKit] Skipping workout save on simulator")
            return true
        }

        guard HKHealthStore.isHealthDataAvailable() else {
            print("[HealthKit] Health data not available")
            return false
        }

        // Build the workout
        let workoutConfiguration = HKWorkoutConfiguration()
        workoutConfiguration.activityType = .walking
        workoutConfiguration.locationType = .outdoor

        let builder = HKWorkoutBuilder(healthStore: healthStore, configuration: workoutConfiguration, device: .local())

        do {
            try await builder.beginCollection(at: startDate)

            // Add distance sample
            if totalDistance > 0 {
                let distanceType = HKQuantityType(.distanceWalkingRunning)
                let distanceQuantity = HKQuantity(unit: .meter(), doubleValue: totalDistance)
                let distanceSample = HKQuantitySample(
                    type: distanceType,
                    quantity: distanceQuantity,
                    start: startDate,
                    end: endDate
                )
                try await builder.addSamples([distanceSample])
            }

            // Add calories sample if available
            if let calories = totalCalories, calories > 0 {
                let calorieType = HKQuantityType(.activeEnergyBurned)
                let calorieQuantity = HKQuantity(unit: .kilocalorie(), doubleValue: calories)
                let calorieSample = HKQuantitySample(
                    type: calorieType,
                    quantity: calorieQuantity,
                    start: startDate,
                    end: endDate
                )
                try await builder.addSamples([calorieSample])
            }

            try await builder.endCollection(at: endDate)

            // Finish and save the workout
            let workout = try await builder.finishWorkout()
            print("[HealthKit] Workout saved successfully: \(workout?.uuid.uuidString ?? "unknown")")
            return true
        } catch {
            print("[HealthKit] Failed to save workout: \(error.localizedDescription)")
            return false
        }
    }

    // MARK: - Utility

    func fetchCaloriesDuring(start: Date, end: Date) async -> Double {
        guard await ensureAuthorizedIfNeeded() else { return 0 }
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
