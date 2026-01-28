//
//  HealthKitService.swift
//  Just Walk
//
//  Created by Randy Chia on 1/8/26.
//

import Foundation
import HealthKit
import Combine

/// Authorization state for HealthKit permissions
enum HealthKitAuthorizationState {
    case notDetermined
    case authorized
    case denied
}

/// Service for reading health data using HealthKit (READ-ONLY)
@MainActor
final class HealthKitService: ObservableObject {

    static let shared = HealthKitService()

    private let healthStore = HKHealthStore()

    @Published var isAuthorized = false
    @Published var authorizationError: Error?
    @Published var authorizationState: HealthKitAuthorizationState = .notDetermined

    /// Key for persisting authorization state (read-only apps can't check status)
    private let hasCompletedAuthorizationKey = "com.justwalk.healthkit.hasCompletedAuthorization"

    private init() {
        // For read-only apps, we can't check authorization status (Apple hides it for privacy)
        // Instead, we trust our persisted flag from when user completed authorization
        isAuthorized = UserDefaults.standard.bool(forKey: hasCompletedAuthorizationKey)
        checkAuthorizationState()
    }

    /// Mark authorization as completed (called after successful requestAuthorization)
    /// Also called by PermissionManager during onboarding to sync authorization state.
    func markAuthorizationCompleted() {
        UserDefaults.standard.set(true, forKey: hasCompletedAuthorizationKey)
        isAuthorized = true
        authorizationState = .authorized
    }

    // MARK: - Availability

    /// Check if HealthKit is available on this device
    static var isHealthDataAvailable: Bool {
        HKHealthStore.isHealthDataAvailable()
    }

    // MARK: - Authorization

    /// Request authorization to read and write health data
    func requestAuthorization() async throws {
        guard HealthKitService.isHealthDataAvailable else {
            throw HealthKitError.notAvailable
        }

        let typesToRead: Set<HKObjectType> = [
            HKObjectType.quantityType(forIdentifier: .stepCount)!,
            HKObjectType.quantityType(forIdentifier: .distanceWalkingRunning)!,
            HKObjectType.quantityType(forIdentifier: .activeEnergyBurned)!,
            HKObjectType.quantityType(forIdentifier: .heartRate)!,
            HKObjectType.workoutType(),
            HKSeriesType.workoutRoute()
        ]

        // Write permissions for workout recording
        let typesToWrite: Set<HKSampleType> = [
            HKObjectType.workoutType(),
            HKSeriesType.workoutRoute(),
            HKObjectType.quantityType(forIdentifier: .stepCount)!,
            HKObjectType.quantityType(forIdentifier: .distanceWalkingRunning)!,
            HKObjectType.quantityType(forIdentifier: .activeEnergyBurned)!
        ]

        do {
            try await healthStore.requestAuthorization(toShare: typesToWrite, read: typesToRead)
            // Persist authorization state - we can't check read status later (Apple privacy)
            markAuthorizationCompleted()
        } catch {
            authorizationError = error
            throw error
        }
    }

    // MARK: - Status
    
    func isAuthorizationDetermined() -> Bool {
        guard let stepType = HKObjectType.quantityType(forIdentifier: .stepCount) else { return false }
        // We check 'sharing' status because 'reading' status is always hidden for privacy
        // If sharing is .notDetermined, the prompt will likely show.
        // If it's .sharingAuthorized or .sharingDenied, it won't show.
        let status = healthStore.authorizationStatus(for: stepType)
        return status != .notDetermined
    }
    
    /// Check if HealthKit sharing is explicitly denied
    var isHealthKitDenied: Bool {
        guard let stepType = HKObjectType.quantityType(forIdentifier: .stepCount) else { return false }
        return healthStore.authorizationStatus(for: stepType) == .sharingDenied
    }

    /// Check if HealthKit authorization has been completed
    /// Note: For read-only apps, Apple hides the actual read permission status for privacy.
    /// We use a persisted flag instead of checking authorizationStatus.
    var isHealthKitAuthorized: Bool {
        UserDefaults.standard.bool(forKey: hasCompletedAuthorizationKey)
    }

    /// Refresh authorization status from persisted state.
    /// Called when checking permissions in Settings.
    func updateAuthorizationStatus() {
        isAuthorized = UserDefaults.standard.bool(forKey: hasCompletedAuthorizationKey)
    }

    /// Check and update the authorization state for reactive UI updates
    func checkAuthorizationState() {
        if isHealthKitAuthorized {
            authorizationState = .authorized
        } else if isHealthKitDenied {
            authorizationState = .denied
        } else {
            authorizationState = .notDetermined
        }
    }

    /// Fetch total steps for a specific date
    func fetchSteps(for date: Date) async throws -> Int {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        guard let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) else {
            throw HealthKitError.invalidDateRange
        }

        return try await fetchSteps(from: startOfDay, to: endOfDay)
    }

    /// Fetch total steps between two dates
    func fetchSteps(from startDate: Date, to endDate: Date) async throws -> Int {
        guard let stepType = HKQuantityType.quantityType(forIdentifier: .stepCount) else {
            throw HealthKitError.invalidType
        }

        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictStartDate)

        return try await withCheckedThrowingContinuation { continuation in
            let query = HKStatisticsQuery(
                quantityType: stepType,
                quantitySamplePredicate: predicate,
                options: .cumulativeSum
            ) { _, statistics, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }

                let steps = statistics?.sumQuantity()?.doubleValue(for: .count()) ?? 0
                continuation.resume(returning: Int(steps))
            }

            healthStore.execute(query)
        }
    }

    // MARK: - Failsafe Fetch (No Caching)

    /// Fetch steps for a specific date directly from HealthKit (no throttle/cache).
    /// Used for critical streak validation before breaking.
    /// This is intentionally separate from fetchSteps(for:) to ensure no future caching affects it.
    func fetchStepsFresh(for date: Date) async throws -> Int {
        guard let stepType = HKQuantityType.quantityType(forIdentifier: .stepCount) else {
            throw HealthKitError.invalidType
        }

        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        guard let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) else {
            throw HealthKitError.invalidDateRange
        }

        let predicate = HKQuery.predicateForSamples(
            withStart: startOfDay,
            end: endOfDay,
            options: .strictStartDate
        )

        return try await withCheckedThrowingContinuation { continuation in
            let query = HKStatisticsQuery(
                quantityType: stepType,
                quantitySamplePredicate: predicate,
                options: .cumulativeSum
            ) { _, statistics, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }

                let steps = statistics?.sumQuantity()?.doubleValue(for: .count()) ?? 0
                continuation.resume(returning: Int(steps))
            }

            self.healthStore.execute(query)
        }
    }

    /// Fetch daily step data for multiple days
    func fetchDailySteps(forPastDays days: Int) async throws -> [DayStepData] {
        let calendar = Calendar.current
        var results: [DayStepData] = []

        // Get current goal - default to 10k only if not set (0)
        let savedGoal = UserDefaults.standard.integer(forKey: "dailyStepGoal")
        let currentGoal = savedGoal > 0 ? savedGoal : 10_000

        for dayOffset in 0..<days {
            guard let date = calendar.date(byAdding: .day, value: -dayOffset, to: Date()) else { continue }
            let startOfDay = calendar.startOfDay(for: date)

            do {
                let steps = try await fetchSteps(for: startOfDay)
                let distance = try? await fetchDistance(for: startOfDay)
                results.append(DayStepData(date: startOfDay, steps: steps, distance: distance, historicalGoal: currentGoal))
            } catch {
                // Continue even if one day fails
                results.append(DayStepData(date: startOfDay, steps: 0, distance: 0, historicalGoal: currentGoal))
            }
        }

        return results.reversed()
    }

    /// Fetch step data grouped by day for a date range
    func fetchDailyStepStatistics(from startDate: Date, to endDate: Date) async throws -> [DayStepData] {
        #if DEBUG
        // Return simulated data if available (for unit testing)
        if let simulated = simulatedDailySteps {
            return simulated.filter { $0.date >= startDate && $0.date <= endDate }
        }
        #endif

        guard let stepType = HKQuantityType.quantityType(forIdentifier: .stepCount) else {
            throw HealthKitError.invalidType
        }

        let calendar = Calendar.current
        let interval = DateComponents(day: 1)

        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictStartDate)

        return try await withCheckedThrowingContinuation { continuation in
            let query = HKStatisticsCollectionQuery(
                quantityType: stepType,
                quantitySamplePredicate: predicate,
                options: .cumulativeSum,
                anchorDate: calendar.startOfDay(for: startDate),
                intervalComponents: interval
            )

            query.initialResultsHandler = { _, statisticsCollection, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }

                // Get current goal to snapshot for historical data
                // Use saved goal, defaulting to 10k only if no goal set (0)
                let savedGoal = UserDefaults.standard.integer(forKey: "dailyStepGoal")
                let currentGoal = savedGoal > 0 ? savedGoal : 10_000

                var results: [DayStepData] = []

                statisticsCollection?.enumerateStatistics(from: startDate, to: endDate) { statistics, _ in
                    let steps = statistics.sumQuantity()?.doubleValue(for: .count()) ?? 0
                    results.append(DayStepData(date: statistics.startDate, steps: Int(steps), distance: nil, historicalGoal: currentGoal))
                }

                continuation.resume(returning: results)
            }

            healthStore.execute(query)
        }
    }

    // MARK: - Background Delivery
    
    func enableBackgroundDelivery(for type: HKObjectType, frequency: HKUpdateFrequency, completion: @escaping @Sendable (Bool, Error?) -> Void) {
        healthStore.enableBackgroundDelivery(for: type, frequency: frequency, withCompletion: completion)
    }
    
    func execute(_ query: HKQuery) {
        healthStore.execute(query)
    }
    
    // MARK: - Reading Distance Data

    /// Fetch total walking/running distance for a specific date
    func fetchDistance(for date: Date) async throws -> Double {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        guard let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) else {
            throw HealthKitError.invalidDateRange
        }

        return try await fetchDistance(from: startOfDay, to: endOfDay)
    }

    /// Fetch total walking/running distance between two dates (in meters)
    func fetchDistance(from startDate: Date, to endDate: Date) async throws -> Double {
        guard let distanceType = HKQuantityType.quantityType(forIdentifier: .distanceWalkingRunning) else {
            throw HealthKitError.invalidType
        }

        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictStartDate)

        return try await withCheckedThrowingContinuation { continuation in
            let query = HKStatisticsQuery(
                quantityType: distanceType,
                quantitySamplePredicate: predicate,
                options: .cumulativeSum
            ) { _, statistics, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }

                let distance = statistics?.sumQuantity()?.doubleValue(for: .meter()) ?? 0
                continuation.resume(returning: distance)
            }

            healthStore.execute(query)
        }
    }

    // MARK: - Walking Workouts

    /// Fetch all walking workouts from HealthKit (includes Watch + iPhone)
    func fetchWalkingWorkouts(from startDate: Date, to endDate: Date) async throws -> [HKWorkout] {
        let workoutType = HKObjectType.workoutType()

        // Use HKQuery.predicateForWorkouts instead of NSPredicate format string
        // The format string approach is no longer supported in iOS 26+
        let activityPredicate = HKQuery.predicateForWorkouts(with: .walking)
        let datePredicate = HKQuery.predicateForSamples(
            withStart: startDate,
            end: endDate,
            options: .strictStartDate
        )

        let compoundPredicate = NSCompoundPredicate(
            andPredicateWithSubpredicates: [datePredicate, activityPredicate]
        )

        let sortDescriptor = NSSortDescriptor(
            key: HKSampleSortIdentifierStartDate,
            ascending: false
        )

        return try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: workoutType,
                predicate: compoundPredicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [sortDescriptor]
            ) { _, samples, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                let workouts = samples?.compactMap { $0 as? HKWorkout } ?? []
                continuation.resume(returning: workouts)
            }
            self.healthStore.execute(query)
        }
    }

    // MARK: - Active Calories

    /// Fetch today's active energy burned from HealthKit
    /// Returns nil if unavailable or unauthorized
    func fetchTodayActiveCalories() async -> Double? {
        guard authorizationState == .authorized else { return nil }

        guard let energyType = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned) else {
            return nil
        }

        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: Date())
        let predicate = HKQuery.predicateForSamples(
            withStart: startOfDay,
            end: Date(),
            options: .strictStartDate
        )

        return await withCheckedContinuation { continuation in
            let query = HKStatisticsQuery(
                quantityType: energyType,
                quantitySamplePredicate: predicate,
                options: .cumulativeSum
            ) { _, result, error in
                guard error == nil,
                      let sum = result?.sumQuantity() else {
                    continuation.resume(returning: nil)
                    return
                }
                let calories = sum.doubleValue(for: .kilocalorie())
                continuation.resume(returning: calories)
            }
            self.healthStore.execute(query)
        }
    }

    // MARK: - Weekly Summary

    /// Get weekly step statistics for coaching
    func fetchWeeklySummary() async throws -> WeeklySummary {
        let calendar = Calendar.current
        let today = Date()
        guard let weekAgo = calendar.date(byAdding: .day, value: -7, to: today) else {
            throw HealthKitError.invalidDateRange
        }

        let dailyData = try await fetchDailyStepStatistics(from: weekAgo, to: today)

        let totalSteps = dailyData.reduce(0) { $0 + $1.steps }
        let daysActive = dailyData.filter { $0.steps > 0 }.count
        let avgSteps = daysActive > 0 ? totalSteps / daysActive : 0
        let daysAtGoal = dailyData.filter { $0.isGoalMet }.count

        return WeeklySummary(
            totalSteps: totalSteps,
            daysActive: daysActive,
            averageSteps: avgSteps,
            daysAtGoal: daysAtGoal,
            dailyData: dailyData
        )
    }
    
    // MARK: - De-Duplicated Fetching (For Circles Leaderboard)
    
    /// Fetch de-duplicated step count for a specific date.
    /// Uses HKStatisticsQuery with .cumulativeSum to automatically merge data from
    /// multiple sources (iPhone, Apple Watch) and prevent double-counting.
    func fetchDeDuplicatedSteps(for date: Date) async throws -> Int {
        return try await fetchSteps(for: date)
    }
    
    /// Fetch de-duplicated distance for a specific date.
    /// Uses HKStatisticsQuery with .cumulativeSum for automatic source merging.
    func fetchDeDuplicatedDistance(for date: Date) async throws -> Double {
        return try await fetchDistance(for: date)
    }
    
    // MARK: - Anti-Cheat Verified Fetching (Excludes Manual Entry)
    
    /// Fetch verified steps for a specific date, excluding manually entered data.
    /// This is the "Gold Standard" for Social Ledger integrity.
    /// - Parameter date: The date to fetch steps for
    /// - Returns: Step count from verified device sources only
    func fetchVerifiedSteps(for date: Date) async throws -> Int {
        guard let stepType = HKQuantityType.quantityType(forIdentifier: .stepCount) else {
            throw HealthKitError.invalidType
        }
        
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        guard let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) else {
            throw HealthKitError.invalidDateRange
        }
        
        // Create compound predicate: date range AND not user-entered
        let datePredicate = HKQuery.predicateForSamples(withStart: startOfDay, end: endOfDay, options: .strictStartDate)
        let notUserEntered = NSPredicate(format: "metadata.%K != YES", HKMetadataKeyWasUserEntered)
        let compoundPredicate = NSCompoundPredicate(andPredicateWithSubpredicates: [datePredicate, notUserEntered])
        
        return try await withCheckedThrowingContinuation { continuation in
            let query = HKStatisticsQuery(
                quantityType: stepType,
                quantitySamplePredicate: compoundPredicate,
                options: .cumulativeSum
            ) { _, statistics, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                
                let steps = statistics?.sumQuantity()?.doubleValue(for: .count()) ?? 0
                continuation.resume(returning: Int(steps))
            }
            
            healthStore.execute(query)
        }
    }
    
    /// Fetch verified distance for a specific date, excluding manually entered data.
    func fetchVerifiedDistance(for date: Date) async throws -> Double {
        guard let distanceType = HKQuantityType.quantityType(forIdentifier: .distanceWalkingRunning) else {
            throw HealthKitError.invalidType
        }
        
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        guard let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) else {
            throw HealthKitError.invalidDateRange
        }
        
        let datePredicate = HKQuery.predicateForSamples(withStart: startOfDay, end: endOfDay, options: .strictStartDate)
        let notUserEntered = NSPredicate(format: "metadata.%K != YES", HKMetadataKeyWasUserEntered)
        let compoundPredicate = NSCompoundPredicate(andPredicateWithSubpredicates: [datePredicate, notUserEntered])
        
        return try await withCheckedThrowingContinuation { continuation in
            let query = HKStatisticsQuery(
                quantityType: distanceType,
                quantitySamplePredicate: compoundPredicate,
                options: .cumulativeSum
            ) { _, statistics, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                
                let distance = statistics?.sumQuantity()?.doubleValue(for: .meter()) ?? 0
                continuation.resume(returning: distance)
            }
            
            healthStore.execute(query)
        }
    }
    
    // MARK: - Historical Backfill (For Tournament Join)
    
    /// Fetch verified daily step totals for a date range.
    /// Used when a user joins an existing tournament to backfill their historical data.
    /// - Parameters:
    ///   - startDate: Tournament start date
    ///   - endDate: End date (typically today)
    /// - Returns: Dictionary of [Date: Steps] with verified data only
    func fetchVerifiedStepsForDateRange(from startDate: Date, to endDate: Date) async throws -> [Date: Int] {
        guard let stepType = HKQuantityType.quantityType(forIdentifier: .stepCount) else {
            throw HealthKitError.invalidType
        }
        
        let calendar = Calendar.current
        let interval = DateComponents(day: 1)
        
        // Anti-cheat: Exclude user-entered data
        let datePredicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictStartDate)
        let notUserEntered = NSPredicate(format: "metadata.%K != YES", HKMetadataKeyWasUserEntered)
        let compoundPredicate = NSCompoundPredicate(andPredicateWithSubpredicates: [datePredicate, notUserEntered])
        
        return try await withCheckedThrowingContinuation { continuation in
            let query = HKStatisticsCollectionQuery(
                quantityType: stepType,
                quantitySamplePredicate: compoundPredicate,
                options: .cumulativeSum,
                anchorDate: calendar.startOfDay(for: startDate),
                intervalComponents: interval
            )
            
            query.initialResultsHandler = { _, statisticsCollection, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                
                var results: [Date: Int] = [:]
                
                statisticsCollection?.enumerateStatistics(from: startDate, to: endDate) { statistics, _ in
                    let steps = statistics.sumQuantity()?.doubleValue(for: .count()) ?? 0
                    let date = calendar.startOfDay(for: statistics.startDate)
                    results[date] = Int(steps)
                }
                
                continuation.resume(returning: results)
            }
            
            healthStore.execute(query)
        }
    }
    
    /// Fetch verified daily distance totals for a date range.
    func fetchVerifiedDistanceForDateRange(from startDate: Date, to endDate: Date) async throws -> [Date: Double] {
        guard let distanceType = HKQuantityType.quantityType(forIdentifier: .distanceWalkingRunning) else {
            throw HealthKitError.invalidType
        }
        
        let calendar = Calendar.current
        let interval = DateComponents(day: 1)
        
        let datePredicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictStartDate)
        let notUserEntered = NSPredicate(format: "metadata.%K != YES", HKMetadataKeyWasUserEntered)
        let compoundPredicate = NSCompoundPredicate(andPredicateWithSubpredicates: [datePredicate, notUserEntered])
        
        return try await withCheckedThrowingContinuation { continuation in
            let query = HKStatisticsCollectionQuery(
                quantityType: distanceType,
                quantitySamplePredicate: compoundPredicate,
                options: .cumulativeSum,
                anchorDate: calendar.startOfDay(for: startDate),
                intervalComponents: interval
            )
            
            query.initialResultsHandler = { _, statisticsCollection, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                
                var results: [Date: Double] = [:]
                
                statisticsCollection?.enumerateStatistics(from: startDate, to: endDate) { statistics, _ in
                    let distance = statistics.sumQuantity()?.doubleValue(for: .meter()) ?? 0
                    let date = calendar.startOfDay(for: statistics.startDate)
                    results[date] = distance
                }
                
                continuation.resume(returning: results)
            }
            
            healthStore.execute(query)
        }
    }
    
    // MARK: - Observer Query (For Live Leaderboard Updates)
    
    private var stepObserverQuery: HKObserverQuery?
    
    /// Start observing HealthKit step count changes.
    /// When new step data is written to HealthKit (from any source), the callback is invoked.
    /// - Parameter onUpdate: Callback invoked when step data changes. Called on a background thread.
    func startStepObserverQuery(onUpdate: @escaping () -> Void) {
        guard let stepType = HKQuantityType.quantityType(forIdentifier: .stepCount) else { return }
        
        // Stop existing query if any
        stopStepObserverQuery()
        
        let query = HKObserverQuery(sampleType: stepType, predicate: nil) { _, completionHandler, error in
            if let error = error {
                print("Step Observer Query Error: \(error.localizedDescription)")
                completionHandler()
                return
            }
            
            // Invoke callback
            onUpdate()
            
            // Must call completion handler to allow future updates
            completionHandler()
        }
        
        stepObserverQuery = query
        healthStore.execute(query)
        
        print("Step Observer Query started for live leaderboard updates.")
    }
    
    /// Stop the active step observer query.
    func stopStepObserverQuery() {
        if let query = stepObserverQuery {
            healthStore.stop(query)
            stepObserverQuery = nil
            print("Step Observer Query stopped.")
        }
    }

    // MARK: - Test Simulation (DEBUG only)

    #if DEBUG
    /// Simulated step data for unit tests (bypasses HealthKit)
    private var simulatedDailySteps: [DayStepData]?

    /// Inject simulated daily step data (for testing only)
    func simulateDailyStepData(_ data: [DayStepData]) {
        simulatedDailySteps = data
    }

    /// Clear simulated data
    func clearSimulatedData() {
        simulatedDailySteps = nil
    }

    /// Check if simulation is active
    var isSimulatingData: Bool {
        simulatedDailySteps != nil
    }
    #endif
}

// MARK: - Supporting Types

struct WeeklySummary {
    let totalSteps: Int
    let daysActive: Int
    let averageSteps: Int
    let daysAtGoal: Int
    let dailyData: [DayStepData]
}

enum HealthKitError: LocalizedError {
    case notAvailable
    case invalidType
    case invalidDateRange
    case authorizationDenied

    var errorDescription: String? {
        switch self {
        case .notAvailable:
            return "HealthKit is not available on this device."
        case .invalidType:
            return "Invalid health data type."
        case .invalidDateRange:
            return "Invalid date range specified."
        case .authorizationDenied:
            return "Health data access was denied. Please enable it in Settings."
        }
    }
}

