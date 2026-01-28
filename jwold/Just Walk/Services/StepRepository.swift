//
//  StepRepository.swift
//  Just Walk
//
//  Step Repository using HealthKit as the single source of truth.
//  Uses HKStatisticsQuery and HKStatisticsCollectionQuery with .cumulativeSum
//  for Apple's built-in deduplication. Matches Apple Health app exactly.
//
//  Query Strategy:
//  - Today's data: HKStatisticsQuery (single day, live)
//  - Historical data: HKStatisticsCollectionQuery (batch, efficient)
//  - No manual iPhone + Watch deduplication - Apple handles it automatically
//

import Foundation
import HealthKit
import CoreMotion
import WidgetKit
import Combine
import SwiftData

// MARK: - Notifications

extension Notification.Name {
    /// Posted when step goal changes and historical data has been recalculated
    static let stepGoalDidChange = Notification.Name("stepGoalDidChange")
}

// MARK: - App Group Constants

enum StepRepositoryConstants {
    static let appGroupID = "group.com.onworldtech.JustWalk"

    enum Keys {
        static let todaySteps = "todaySteps"
        static let todayDistance = "todayDistance"
        static let dailyStepGoal = "dailyStepGoal"
        static let forDate = "forDate"
        static let lastUpdateDate = "lastUpdateDate"

        // Expanded widget data keys
        static let streakDays = "streakDays"
        static let weekStepsData = "weekStepsData"      // JSON [Int] - 7 days oldest to newest
        static let weekGoalsMet = "weekGoalsMet"        // JSON [Bool] - 7 days oldest to newest
        static let activeMinutes = "activeMinutes"
        static let currentRank = "currentRank"          // WalkerRank.rawValue as Int
        static let daysAsWalker = "daysAsWalker"
        static let totalLifetimeSteps = "totalLifetimeSteps"
    }

    static let widgetRefreshThrottle: TimeInterval = 1800  // 30 minutes
    static let maxReasonableSteps = 100_000
    static let healthKitRefreshThrottle: TimeInterval = 30  // 30 seconds
}

// MARK: - Step Repository

/// Step Repository using HealthKit as the single source of truth.
/// Uses HKStatisticsQuery with .cumulativeSum - Apple handles iPhone + Watch deduplication.
@MainActor
final class StepRepository: ObservableObject {

    // MARK: - Singleton

    static let shared = StepRepository()

    // MARK: - Dependencies

    private let healthStore = HKHealthStore()
    private let pedometer = CMPedometer()
    private let healthKitService = HealthKitService.shared

    // MARK: - Published State

    /// Today's step count (from HealthKit)
    @Published private(set) var todaySteps: Int = 0

    /// Today's distance in meters (from HealthKit)
    @Published private(set) var todayDistance: Double = 0

    /// User's daily step goal
    @Published var stepGoal: Int = 10_000 {
        didSet {
            saveGoalToAppGroup()
            if oldValue != stepGoal {
                Task.detached(priority: .userInitiated) { [weak self] in
                    await self?.recalculateHistoricalGoals()
                }
            }
        }
    }

    /// Whether goal has been reached
    var goalReached: Bool { todaySteps >= stepGoal }

    /// Progress toward goal (0.0 to 1.0+)
    var goalProgress: Double { stepGoal > 0 ? Double(todaySteps) / Double(stepGoal) : 0 }

    /// Steps remaining to reach goal
    var stepsRemaining: Int { max(0, stepGoal - todaySteps) }

    // MARK: - Achievement Stats (calculated from DailyStats)

    /// Lifetime total steps (sum of all DailyStats)
    @Published private(set) var lifetimeSteps: Int = 0

    /// Best single day steps (max from DailyStats)
    @Published private(set) var bestSingleDaySteps: Int = 0

    // MARK: - Diagnostic State

    @Published private(set) var healthKitSteps: Int = 0
    @Published private(set) var lastHealthKitRefresh: Date = .distantPast

    // MARK: - Authorization State

    @Published private(set) var isAuthorized: Bool = false

    // MARK: - SwiftData Context

    private(set) var modelContext: ModelContext?

    func setModelContext(_ context: ModelContext) {
        self.modelContext = context
        print("✅ StepRepository: ModelContext set")
        // Calculate achievement stats now that we have the context
        updateAchievementStats()
    }

    // MARK: - Private Properties

    private var cancellables = Set<AnyCancellable>()
    private var lastWidgetRefresh: Date = .distantPast
    private let calendar = Calendar.current
    private var observerQuery: HKObserverQuery?

    /// Re-entry guard for historical data fetching
    private var isFetchingHistoricalData = false

    private var appGroupDefaults: UserDefaults? {
        UserDefaults(suiteName: StepRepositoryConstants.appGroupID)
    }

    // MARK: - Initialization

    private init() {
        loadFromAppGroup()
        setupDayChangeObserver()
    }

    // MARK: - Day Change Observer

    private func setupDayChangeObserver() {
        NotificationCenter.default.publisher(for: .NSCalendarDayChanged)
            .sink { [weak self] _ in
                Task { @MainActor [weak self] in
                    self?.handleDayChange()
                }
            }
            .store(in: &cancellables)
    }

    private func handleDayChange() {
        print("📅 StepRepository: Day changed - resetting")

        // Reset for new day
        todaySteps = 0
        todayDistance = 0
        healthKitSteps = 0

        saveToAppGroup()
        forceWidgetRefresh()

        // Refresh from HealthKit
        Task {
            await forceRefresh()
        }
    }

    // MARK: - Public API

    /// Initialize the repository and start tracking
    func initialize() async {
        isAuthorized = HealthKitService.shared.isHealthKitAuthorized

        // Initial refresh from HealthKit
        await refreshFromHealthKit()

        // Start HealthKit observer for background updates
        startHealthKitObserver()

        // Start periodic refresh
        startPeriodicRefresh()

        print("✅ StepRepository: Initialized with HealthKit as source of truth")
    }

    /// Force a full refresh from HealthKit
    func forceRefresh() async {
        lastHealthKitRefresh = .distantPast
        await refreshFromHealthKit()
    }

    /// Handle app becoming active
    func handleAppForeground() async {
        // Check for day change
        checkForDayChange()

        // Force refresh
        await forceRefresh()
    }

    /// Handle app going to background
    func handleAppBackground() {
        saveToAppGroup()
        forceWidgetRefresh()
    }

    // MARK: - HealthKit Queries (Source of Truth)

    /// Refresh step and distance data from HealthKit
    private func refreshFromHealthKit() async {
        let now = Date()

        // Throttle
        guard now.timeIntervalSince(lastHealthKitRefresh) >= StepRepositoryConstants.healthKitRefreshThrottle else {
            return
        }
        lastHealthKitRefresh = now

        // Fetch steps using HKStatisticsQuery with .cumulativeSum
        // Apple handles iPhone + Watch deduplication automatically
        let steps = await fetchTodayStepsFromHealthKit()
        let distance = await fetchTodayDistanceFromHealthKit()

        let previousSteps = todaySteps

        healthKitSteps = steps
        todaySteps = steps
        todayDistance = distance

        // Check for goal reached
        if previousSteps < stepGoal && steps >= stepGoal {
            forceWidgetRefresh()
            NotificationCenter.default.post(name: .dailyStepGoalReached, object: nil)
        }

        // Save to App Group and persist
        saveToAppGroup()
        persistToDailyStats(steps: steps)

        print("✅ StepRepository: HealthKit refresh - \(steps) steps, \(String(format: "%.0f", distance))m")
    }

    /// Fetch today's steps from HealthKit using .cumulativeSum (Apple's deduplication)
    private func fetchTodayStepsFromHealthKit() async -> Int {
        guard let stepType = HKQuantityType.quantityType(forIdentifier: .stepCount) else { return 0 }

        let startOfDay = calendar.startOfDay(for: Date())
        let predicate = HKQuery.predicateForSamples(withStart: startOfDay, end: Date(), options: .strictStartDate)

        return await withCheckedContinuation { continuation in
            let query = HKStatisticsQuery(
                quantityType: stepType,
                quantitySamplePredicate: predicate,
                options: .cumulativeSum  // Apple handles iPhone + Watch deduplication
            ) { _, statistics, error in
                if let error = error as NSError?, error.code != 11 {
                    print("⚠️ StepRepository: Step query error: \(error.localizedDescription)")
                }
                let steps = Int(statistics?.sumQuantity()?.doubleValue(for: .count()) ?? 0)
                continuation.resume(returning: steps)
            }
            healthStore.execute(query)
        }
    }

    /// Fetch today's distance from HealthKit
    private func fetchTodayDistanceFromHealthKit() async -> Double {
        guard let distanceType = HKQuantityType.quantityType(forIdentifier: .distanceWalkingRunning) else { return 0 }

        let startOfDay = calendar.startOfDay(for: Date())
        let predicate = HKQuery.predicateForSamples(withStart: startOfDay, end: Date(), options: .strictStartDate)

        return await withCheckedContinuation { continuation in
            let query = HKStatisticsQuery(
                quantityType: distanceType,
                quantitySamplePredicate: predicate,
                options: .cumulativeSum
            ) { _, statistics, error in
                if let error = error as NSError?, error.code != 11 {
                    print("⚠️ StepRepository: Distance query error: \(error.localizedDescription)")
                }
                let distance = statistics?.sumQuantity()?.doubleValue(for: .meter()) ?? 0
                continuation.resume(returning: distance)
            }
            healthStore.execute(query)
        }
    }

    // MARK: - Batch Historical Queries (HKStatisticsCollectionQuery)

    /// Fetch daily step totals for a date range using HKStatisticsCollectionQuery
    /// This is the standard Apple pattern - one query returns all daily totals with automatic deduplication
    private func fetchBatchStepsFromHealthKit(forPastDays days: Int) async -> [Date: Int] {
        guard let stepType = HKQuantityType.quantityType(forIdentifier: .stepCount) else { return [:] }

        // Check authorization first - query handler may not be called if not authorized
        guard HealthKitService.shared.isHealthKitAuthorized else {
            print("⚠️ StepRepository: HealthKit not authorized, skipping batch step query")
            return [:]
        }

        let today = calendar.startOfDay(for: Date())
        guard let startDate = calendar.date(byAdding: .day, value: -(days - 1), to: today) else { return [:] }

        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: Date(), options: .strictStartDate)
        let interval = DateComponents(day: 1)

        return await withCheckedContinuation { continuation in
            let query = HKStatisticsCollectionQuery(
                quantityType: stepType,
                quantitySamplePredicate: predicate,
                options: .cumulativeSum,
                anchorDate: startDate,
                intervalComponents: interval
            )

            query.initialResultsHandler = { _, statisticsCollection, error in
                if let error = error {
                    print("⚠️ StepRepository: Batch step query error: \(error.localizedDescription)")
                    continuation.resume(returning: [:])
                    return
                }

                var results: [Date: Int] = [:]

                statisticsCollection?.enumerateStatistics(from: startDate, to: Date()) { statistics, _ in
                    let date = self.calendar.startOfDay(for: statistics.startDate)
                    let steps = Int(statistics.sumQuantity()?.doubleValue(for: .count()) ?? 0)
                    results[date] = steps
                }

                continuation.resume(returning: results)
            }

            healthStore.execute(query)
        }
    }

    /// Fetch daily distance totals for a date range using HKStatisticsCollectionQuery
    private func fetchBatchDistanceFromHealthKit(forPastDays days: Int) async -> [Date: Double] {
        guard let distanceType = HKQuantityType.quantityType(forIdentifier: .distanceWalkingRunning) else { return [:] }

        // Check authorization first - query handler may not be called if not authorized
        guard HealthKitService.shared.isHealthKitAuthorized else {
            print("⚠️ StepRepository: HealthKit not authorized, skipping batch distance query")
            return [:]
        }

        let today = calendar.startOfDay(for: Date())
        guard let startDate = calendar.date(byAdding: .day, value: -(days - 1), to: today) else { return [:] }

        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: Date(), options: .strictStartDate)
        let interval = DateComponents(day: 1)

        return await withCheckedContinuation { continuation in
            let query = HKStatisticsCollectionQuery(
                quantityType: distanceType,
                quantitySamplePredicate: predicate,
                options: .cumulativeSum,
                anchorDate: startDate,
                intervalComponents: interval
            )

            query.initialResultsHandler = { _, statisticsCollection, error in
                if let error = error {
                    print("⚠️ StepRepository: Batch distance query error: \(error.localizedDescription)")
                    continuation.resume(returning: [:])
                    return
                }

                var results: [Date: Double] = [:]

                statisticsCollection?.enumerateStatistics(from: startDate, to: Date()) { statistics, _ in
                    let date = self.calendar.startOfDay(for: statistics.startDate)
                    let distance = statistics.sumQuantity()?.doubleValue(for: .meter()) ?? 0
                    results[date] = distance
                }

                continuation.resume(returning: results)
            }

            healthStore.execute(query)
        }
    }

    // MARK: - HealthKit Observer

    private func startHealthKitObserver() {
        guard let stepType = HKQuantityType.quantityType(forIdentifier: .stepCount) else { return }

        // Stop existing observer
        if let existing = observerQuery {
            healthStore.stop(existing)
        }

        // Enable background delivery
        healthStore.enableBackgroundDelivery(for: stepType, frequency: .immediate) { success, error in
            if let error = error {
                print("⚠️ StepRepository: Background delivery error: \(error)")
            } else if success {
                print("✅ StepRepository: Background delivery enabled")
            }
        }

        // Create observer query
        observerQuery = HKObserverQuery(sampleType: stepType, predicate: nil) { [weak self] _, completionHandler, error in
            guard error == nil else {
                completionHandler()
                return
            }

            Task { @MainActor [weak self] in
                // Respect 30-second throttle for stability (prevents jittering)
                await self?.refreshFromHealthKit()
                completionHandler()
            }
        }

        if let query = observerQuery {
            healthStore.execute(query)
            print("✅ StepRepository: HealthKit observer started")
        }
    }

    // MARK: - Periodic Refresh

    private func startPeriodicRefresh() {
        Timer.publish(every: 30, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                Task { [weak self] in
                    await self?.refreshFromHealthKit()
                }
            }
            .store(in: &cancellables)
    }

    // MARK: - Day Change Check

    private func checkForDayChange() {
        if let forDate = appGroupDefaults?.object(forKey: StepRepositoryConstants.Keys.forDate) as? Date,
           !calendar.isDate(forDate, inSameDayAs: Date()) {
            handleDayChange()
        }
    }

    // MARK: - SwiftData Persistence

    private func persistToDailyStats(steps: Int) {
        guard let context = modelContext else { return }

        let today = calendar.startOfDay(for: Date())

        let predicate = #Predicate<DailyStats> { stats in
            stats.date == today
        }
        let descriptor = FetchDescriptor<DailyStats>(predicate: predicate)

        do {
            if let existingStats = try context.fetch(descriptor).first {
                existingStats.totalSteps = steps
                existingStats.totalDistance = todayDistance
                existingStats.goalReached = steps >= stepGoal
                existingStats.historicalGoal = stepGoal
                existingStats.lastMergedAt = Date()
            } else {
                let newStats = DailyStats(
                    date: today,
                    totalSteps: steps,
                    totalDistance: todayDistance,
                    totalDuration: 0,
                    sessionsCompleted: 0,
                    iwtSessionsCompleted: 0,
                    goalReached: steps >= stepGoal,
                    caloriesBurned: 0,
                    historicalGoal: stepGoal,
                    lastMergedAt: Date()
                )
                context.insert(newStats)
            }

            try context.save()

            // Update achievement stats after persisting
            updateAchievementStats()
        } catch {
            print("❌ StepRepository: Failed to persist DailyStats: \(error)")
        }
    }

    // MARK: - Historical Data

    /// Fetch historical step data using efficient batch HealthKit query
    /// HKStatisticsCollectionQuery is fast - no complex caching needed
    func fetchHistoricalStepData(forPastDays days: Int) async -> [DayStepData] {
        guard !isFetchingHistoricalData else {
            // Re-entry guard - another fetch is in progress
            print("⚠️ StepRepository: fetchHistoricalStepData re-entry blocked (another fetch in progress)")
            return []
        }
        isFetchingHistoricalData = true
        defer { isFetchingHistoricalData = false }

        let today = calendar.startOfDay(for: Date())

        // Batch fetch all historical data in two efficient queries
        let stepsDict = await fetchBatchStepsFromHealthKit(forPastDays: days)
        let distanceDict = await fetchBatchDistanceFromHealthKit(forPastDays: days)

        var results: [DayStepData] = []

        for dayOffset in 0..<days {
            guard let date = calendar.date(byAdding: .day, value: -dayOffset, to: today) else {
                continue
            }

            let normalizedDate = calendar.startOfDay(for: date)
            let steps: Int
            let distance: Double

            if calendar.isDateInToday(date) {
                // Today: use live values
                steps = todaySteps
                distance = todayDistance
            } else {
                // Historical: use batch query results
                steps = stepsDict[normalizedDate] ?? 0
                distance = distanceDict[normalizedDate] ?? 0
            }

            results.append(DayStepData(
                date: date,
                steps: steps,
                distance: distance,
                historicalGoal: stepGoal
            ))
        }

        return results
    }

    /// Hydrate historical data for charts
    func hydrateHistoricalData() async {
        _ = await fetchHistoricalStepData(forPastDays: 14)
        print("✅ StepRepository: Historical data hydrated (14 days)")
    }

    // MARK: - Achievement Stats

    /// Update lifetime and best single day stats from DailyStats
    func updateAchievementStats() {
        guard let context = modelContext else { return }

        do {
            let descriptor = FetchDescriptor<DailyStats>()
            let allStats = try context.fetch(descriptor)

            // Calculate lifetime total
            var total = 0
            var best = 0
            for stat in allStats {
                total += stat.totalSteps
                best = max(best, stat.totalSteps)
            }

            // Also consider today's steps (may not be persisted yet)
            total = total + (allStats.contains { calendar.isDateInToday($0.date) } ? 0 : todaySteps)
            best = max(best, todaySteps)

            lifetimeSteps = total
            bestSingleDaySteps = best

            print("✅ StepRepository: Achievement stats updated - lifetime: \(total), best day: \(best)")
        } catch {
            print("❌ StepRepository: Failed to calculate achievement stats: \(error)")
        }
    }

    // MARK: - Goal Recalculation

    private func recalculateHistoricalGoals() async {
        guard let context = modelContext else { return }

        let goal = stepGoal

        do {
            let descriptor = FetchDescriptor<DailyStats>()
            let allStats = try context.fetch(descriptor)

            for stat in allStats {
                let newGoalReached = stat.totalSteps >= goal
                if stat.goalReached != newGoalReached {
                    stat.goalReached = newGoalReached
                    stat.historicalGoal = goal
                }
            }

            try context.save()
            print("✅ StepRepository: Historical goals recalculated")

            await MainActor.run {
                StreakService.shared.recalculateStreakFromDailyStats(context: context)
                WidgetCenter.shared.reloadAllTimelines()
                NotificationCenter.default.post(name: .stepGoalDidChange, object: nil)
            }
        } catch {
            print("❌ StepRepository: Goal recalculation failed: \(error)")
        }
    }

    // MARK: - App Group

    private func loadFromAppGroup() {
        guard let defaults = appGroupDefaults else { return }

        let savedGoal = defaults.integer(forKey: StepRepositoryConstants.Keys.dailyStepGoal)
        if savedGoal > 0 {
            stepGoal = savedGoal
        }

        // Load cached steps for initial display
        if let forDate = defaults.object(forKey: StepRepositoryConstants.Keys.forDate) as? Date,
           calendar.isDateInToday(forDate) {
            let savedSteps = defaults.integer(forKey: StepRepositoryConstants.Keys.todaySteps)
            if savedSteps > 0 {
                todaySteps = savedSteps
            }
        }
    }

    private func saveToAppGroup() {
        guard let defaults = appGroupDefaults else { return }

        defaults.set(todaySteps, forKey: StepRepositoryConstants.Keys.todaySteps)
        defaults.set(todayDistance, forKey: StepRepositoryConstants.Keys.todayDistance)
        defaults.set(stepGoal, forKey: StepRepositoryConstants.Keys.dailyStepGoal)
        defaults.set(Date(), forKey: StepRepositoryConstants.Keys.forDate)
        defaults.set(Date(), forKey: StepRepositoryConstants.Keys.lastUpdateDate)

        // Force immediate sync to disk for widget access
        defaults.synchronize()

        // Also save expanded widget data for redesigned widgets
        saveExpandedWidgetData()

        // Refresh widgets to show updated data
        forceWidgetRefresh()
    }

    private func saveGoalToAppGroup() {
        guard let defaults = appGroupDefaults else { return }
        defaults.set(stepGoal, forKey: StepRepositoryConstants.Keys.dailyStepGoal)
    }

    // MARK: - Widget Refresh

    func forceWidgetRefresh() {
        lastWidgetRefresh = .distantPast
        WidgetCenter.shared.reloadAllTimelines()
    }

    // MARK: - Shared Step Data (for Widgets)

    func getSharedStepData() -> SharedStepData {
        SharedStepData(
            steps: todaySteps,
            distance: todayDistance,
            goal: stepGoal,
            forDate: Date(),
            updatedAt: Date()
        )
    }

    // MARK: - Expanded Widget Data (for redesigned widgets)

    /// Save expanded widget data for the redesigned home screen widgets.
    /// Called from saveToAppGroup() and handleAppBackground().
    func saveExpandedWidgetData() {
        guard let defaults = appGroupDefaults else { return }

        // Get streak from StreakService
        let streakDays = StreakService.shared.currentStreak

        // Get rank based on lifetime steps
        let rank = WalkerRank.rank(forLifetimeSteps: lifetimeSteps)

        // Calculate days as walker (since first recorded walk)
        let daysAsWalker = calculateDaysAsWalker()

        // Get today's active minutes from HealthKit
        Task {
            let activeMinutes = await fetchTodayActiveMinutes()

            // Get last 7 days of step data
            let weekData = await fetchWeekStepData()

            // Save to App Group
            await MainActor.run {
                defaults.set(streakDays, forKey: StepRepositoryConstants.Keys.streakDays)
                defaults.set(activeMinutes, forKey: StepRepositoryConstants.Keys.activeMinutes)
                defaults.set(rank.rawValue, forKey: StepRepositoryConstants.Keys.currentRank)
                defaults.set(daysAsWalker, forKey: StepRepositoryConstants.Keys.daysAsWalker)
                defaults.set(lifetimeSteps, forKey: StepRepositoryConstants.Keys.totalLifetimeSteps)

                // Encode week data as JSON
                if let stepsJSON = try? JSONEncoder().encode(weekData.steps) {
                    defaults.set(stepsJSON, forKey: StepRepositoryConstants.Keys.weekStepsData)
                }
                if let goalsJSON = try? JSONEncoder().encode(weekData.goalsMet) {
                    defaults.set(goalsJSON, forKey: StepRepositoryConstants.Keys.weekGoalsMet)
                }

                defaults.synchronize()
            }
        }
    }

    /// Calculate days since first walk (for "X days as a Walker" display)
    private func calculateDaysAsWalker() -> Int {
        guard let context = modelContext else { return 0 }

        do {
            let descriptor = FetchDescriptor<DailyStats>(
                sortBy: [SortDescriptor(\.date, order: .forward)]
            )
            let allStats = try context.fetch(descriptor)

            guard let firstRecord = allStats.first else { return 0 }

            let daysSinceFirst = calendar.dateComponents([.day], from: firstRecord.date, to: Date()).day ?? 0
            return max(1, daysSinceFirst + 1)  // Include today
        } catch {
            print("❌ StepRepository: Failed to calculate days as walker: \(error)")
            return 0
        }
    }

    /// Fetch last 7 days of step data for widget week chart
    private func fetchWeekStepData() async -> (steps: [Int], goalsMet: [Bool]) {
        let today = calendar.startOfDay(for: Date())

        // Get last 7 days of data from HealthKit batch query
        let stepsDict = await fetchBatchStepsFromHealthKit(forPastDays: 7)

        var steps: [Int] = []
        var goalsMet: [Bool] = []

        // Build arrays from oldest to newest (6 days ago -> today)
        for dayOffset in (0..<7).reversed() {
            guard let date = calendar.date(byAdding: .day, value: -dayOffset, to: today) else {
                steps.append(0)
                goalsMet.append(false)
                continue
            }

            let daySteps: Int
            if calendar.isDateInToday(date) {
                daySteps = todaySteps
            } else {
                daySteps = stepsDict[date] ?? 0
            }

            steps.append(daySteps)
            goalsMet.append(daySteps >= stepGoal)
        }

        return (steps, goalsMet)
    }

    /// Fetch today's active minutes from HealthKit
    private func fetchTodayActiveMinutes() async -> Int {
        guard let exerciseType = HKQuantityType.quantityType(forIdentifier: .appleExerciseTime) else { return 0 }

        let startOfDay = calendar.startOfDay(for: Date())
        let predicate = HKQuery.predicateForSamples(withStart: startOfDay, end: Date(), options: .strictStartDate)

        return await withCheckedContinuation { continuation in
            let query = HKStatisticsQuery(
                quantityType: exerciseType,
                quantitySamplePredicate: predicate,
                options: .cumulativeSum
            ) { _, statistics, error in
                if let error = error as NSError?, error.code != 11 {
                    print("⚠️ StepRepository: Active minutes query error: \(error.localizedDescription)")
                }
                let minutes = Int(statistics?.sumQuantity()?.doubleValue(for: .minute()) ?? 0)
                continuation.resume(returning: minutes)
            }
            healthStore.execute(query)
        }
    }

    // MARK: - Debug (Testing Only)

    #if DEBUG
    func debugSetSteps(_ steps: Int, distance: Double) {
        todaySteps = steps
        todayDistance = distance
        saveToAppGroup()
        forceWidgetRefresh()
        print("🧪 StepRepository: Debug set steps to \(steps)")
    }

    func debugSetStepsForDate(_ steps: Int, distance: Double, date: Date) {
        guard let context = modelContext else {
            print("❌ StepRepository: No model context for debug")
            return
        }

        let targetDate = calendar.startOfDay(for: date)

        if calendar.isDateInToday(date) {
            todaySteps = steps
            todayDistance = distance
            saveToAppGroup()
        }

        let predicate = #Predicate<DailyStats> { stats in
            stats.date == targetDate
        }
        let descriptor = FetchDescriptor<DailyStats>(predicate: predicate)

        do {
            if let existing = try context.fetch(descriptor).first {
                existing.totalSteps = steps
                existing.totalDistance = distance
                existing.goalReached = steps >= stepGoal
                existing.historicalGoal = stepGoal
                existing.lastMergedAt = Date()
            } else {
                let newStats = DailyStats(
                    date: targetDate,
                    totalSteps: steps,
                    totalDistance: distance,
                    goalReached: steps >= stepGoal,
                    historicalGoal: stepGoal,
                    lastMergedAt: Date()
                )
                context.insert(newStats)
            }
            try context.save()
            print("🧪 StepRepository: Debug set \(steps) steps for \(targetDate)")
        } catch {
            print("❌ StepRepository: Debug save failed: \(error)")
        }

        forceWidgetRefresh()
    }
    #endif
}

// MARK: - Notifications

extension Notification.Name {
    static let dailyStepGoalReached = Notification.Name("dailyStepGoalReached")
}
