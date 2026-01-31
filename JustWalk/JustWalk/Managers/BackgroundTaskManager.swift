//
//  BackgroundTaskManager.swift
//  JustWalk
//
//  Industry-leading background refresh for widgets using BGTaskScheduler.
//  Schedules periodic HealthKit data fetches and widget updates.
//

import Foundation
import BackgroundTasks
import WidgetKit
import HealthKit
import CoreLocation

/// Manages background tasks for widget refresh and HealthKit sync.
/// Uses BGAppRefreshTask for frequent, lightweight updates (~1-4x per hour)
/// and BGProcessingTask for heavier HealthKit syncs (1-2x per day).
final class BackgroundTaskManager {

    // MARK: - Singleton

    static let shared = BackgroundTaskManager()

    // MARK: - Task Identifiers

    /// Lightweight refresh task - updates widgets with cached/quick data
    static let widgetRefreshTaskIdentifier = "com.justwalk.widget-refresh"
    /// Heavier processing task - full HealthKit sync
    static let healthKitSyncTaskIdentifier = "com.justwalk.healthkit-sync"

    // MARK: - Private Properties

    private let healthStore = HKHealthStore()
    private var locationManager: CLLocationManager?

    // MARK: - Initialization

    private init() {}

    // MARK: - Registration (Call from AppDelegate.didFinishLaunching)

    /// Register all background tasks. Must be called before app finishes launching.
    func registerBackgroundTasks() {
        // Register lightweight widget refresh task
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: Self.widgetRefreshTaskIdentifier,
            using: nil
        ) { task in
            self.handleWidgetRefreshTask(task as! BGAppRefreshTask)
        }

        // Register heavier HealthKit sync task
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: Self.healthKitSyncTaskIdentifier,
            using: nil
        ) { task in
            self.handleHealthKitSyncTask(task as! BGProcessingTask)
        }

        print("[BackgroundTaskManager] Registered background tasks")
    }

    // MARK: - Scheduling (Call when app enters background)

    /// Schedule the next widget refresh. Call this when app enters background.
    func scheduleWidgetRefresh() {
        let request = BGAppRefreshTaskRequest(identifier: Self.widgetRefreshTaskIdentifier)
        // Request earliest execution - iOS will run this 1-4 times per hour
        // based on user app usage patterns
        request.earliestBeginDate = Date(timeIntervalSinceNow: 15 * 60) // 15 minutes minimum

        do {
            try BGTaskScheduler.shared.submit(request)
            print("[BackgroundTaskManager] Scheduled widget refresh")
        } catch {
            print("[BackgroundTaskManager] Failed to schedule widget refresh: \(error)")
        }
    }

    /// Schedule the next HealthKit sync. Call this when app enters background.
    func scheduleHealthKitSync() {
        let request = BGProcessingTaskRequest(identifier: Self.healthKitSyncTaskIdentifier)
        // Processing tasks can run longer but are less frequent
        request.earliestBeginDate = Date(timeIntervalSinceNow: 60 * 60) // 1 hour minimum
        request.requiresNetworkConnectivity = false
        request.requiresExternalPower = false // Allow on battery

        do {
            try BGTaskScheduler.shared.submit(request)
            print("[BackgroundTaskManager] Scheduled HealthKit sync")
        } catch {
            print("[BackgroundTaskManager] Failed to schedule HealthKit sync: \(error)")
        }
    }

    /// Schedule all background tasks. Convenience method for app backgrounding.
    func scheduleAllBackgroundTasks() {
        scheduleWidgetRefresh()
        scheduleHealthKitSync()
    }

    // MARK: - Task Handlers

    /// Handle lightweight widget refresh task
    private func handleWidgetRefreshTask(_ task: BGAppRefreshTask) {
        // Schedule the next refresh immediately
        scheduleWidgetRefresh()

        // Set up expiration handler
        task.expirationHandler = {
            task.setTaskCompleted(success: false)
        }

        // Perform quick widget update
        Task {
            await performQuickWidgetUpdate()
            task.setTaskCompleted(success: true)
        }
    }

    /// Handle heavier HealthKit sync task
    private func handleHealthKitSyncTask(_ task: BGProcessingTask) {
        // Schedule the next sync
        scheduleHealthKitSync()

        // Set up expiration handler
        task.expirationHandler = {
            task.setTaskCompleted(success: false)
        }

        // Perform full HealthKit sync
        Task {
            await performFullHealthKitSync()
            task.setTaskCompleted(success: true)
        }
    }

    // MARK: - Update Logic

    /// Quick widget update - uses cached data or fast HealthKit query
    private func performQuickWidgetUpdate() async {
        // Fetch today's steps from HealthKit (fast query)
        let steps = await fetchTodayStepsQuick()

        // Get cached data
        let persistence = PersistenceManager.shared
        let goal = persistence.loadProfile().dailyStepGoal
        let streak = persistence.loadStreakData().currentStreak
        let shields = persistence.loadShieldData().availableShields

        // Build week steps from cache (fast)
        let weekSteps = buildWeekStepsFromCache()

        // Update widget data - this will reload widgets if budget allows
        JustWalkWidgetData.updateWidgetData(
            todaySteps: steps,
            stepGoal: goal,
            currentStreak: streak,
            weekSteps: weekSteps,
            shieldCount: shields,
            forceRefresh: true
        )

        // Also push to Watch complications if watch is paired
        PhoneConnectivityManager.shared.pushComplicationUpdate(
            todaySteps: steps,
            stepGoal: goal,
            currentStreak: streak
        )

        print("[BackgroundTaskManager] Quick widget update completed: \(steps) steps")
    }

    /// Full HealthKit sync - more comprehensive data refresh
    private func performFullHealthKitSync() async {
        // Full HealthKit authorization check and data fetch
        let authorized = await HealthKitManager.shared.initializeIfAuthorized()
        guard authorized else {
            print("[BackgroundTaskManager] HealthKit not authorized")
            return
        }

        // Fetch fresh step count
        let steps = await HealthKitManager.shared.fetchTodaySteps()

        // Backfill any missing daily logs
        let goal = PersistenceManager.shared.loadProfile().dailyStepGoal
        _ = await HealthKitManager.shared.backfillDailyLogsIfNeeded(days: 7, dailyGoal: goal)

        // Update widgets with fresh data
        let persistence = PersistenceManager.shared
        let streak = persistence.loadStreakData().currentStreak
        let shields = persistence.loadShieldData().availableShields

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

        print("[BackgroundTaskManager] Full HealthKit sync completed: \(steps) steps")
    }

    // MARK: - Helper Methods

    /// Fast step count query for background refresh
    private func fetchTodayStepsQuick() async -> Int {
        guard HKHealthStore.isHealthDataAvailable() else { return 0 }

        let stepType = HKQuantityType(.stepCount)
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: Date())
        let predicate = HKQuery.predicateForSamples(withStart: startOfDay, end: Date(), options: .strictStartDate)

        return await withCheckedContinuation { continuation in
            let query = HKStatisticsQuery(
                quantityType: stepType,
                quantitySamplePredicate: predicate,
                options: .cumulativeSum
            ) { _, result, _ in
                let steps = result?.sumQuantity()?.doubleValue(for: .count()) ?? 0
                continuation.resume(returning: Int(steps))
            }
            healthStore.execute(query)
        }
    }

    /// Build week steps from cached daily logs (fast, no HealthKit)
    private func buildWeekStepsFromCache() -> [Int] {
        let calendar = Calendar.current
        let persistence = PersistenceManager.shared
        return (-6...0).map { offset in
            guard let date = calendar.date(byAdding: .day, value: offset, to: Date()) else { return 0 }
            return persistence.loadDailyLog(for: date)?.steps ?? 0
        }
    }

    // MARK: - Significant Location Change (Additional Background Trigger)

    /// Start monitoring significant location changes to trigger widget updates.
    /// This wakes the app when the user travels ~500m, perfect for step tracking.
    func startSignificantLocationMonitoring() {
        guard CLLocationManager.significantLocationChangeMonitoringAvailable() else {
            print("[BackgroundTaskManager] Significant location changes not available")
            return
        }

        if locationManager == nil {
            locationManager = CLLocationManager()
            locationManager?.delegate = SignificantLocationDelegate.shared
        }

        locationManager?.startMonitoringSignificantLocationChanges()
        print("[BackgroundTaskManager] Started significant location monitoring")
    }

    /// Stop monitoring significant location changes.
    func stopSignificantLocationMonitoring() {
        locationManager?.stopMonitoringSignificantLocationChanges()
        print("[BackgroundTaskManager] Stopped significant location monitoring")
    }
}

// MARK: - Significant Location Delegate

/// Handles significant location change events to trigger widget updates.
/// Runs on a separate delegate to avoid retain cycles with BackgroundTaskManager.
final class SignificantLocationDelegate: NSObject, CLLocationManagerDelegate {

    static let shared = SignificantLocationDelegate()

    private override init() {
        super.init()
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        // User has moved significantly (~500m) - great time to update widgets!
        // This is a free background execution opportunity.
        Task {
            await BackgroundTaskManager.shared.performLocationTriggeredUpdate()
        }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("[SignificantLocationDelegate] Location error: \(error.localizedDescription)")
    }
}

// MARK: - Location-Triggered Update Extension

extension BackgroundTaskManager {

    /// Perform widget update triggered by significant location change.
    /// This is a free background execution opportunity - use it!
    @MainActor
    func performLocationTriggeredUpdate() async {
        let steps = await fetchTodayStepsQuick()

        let persistence = PersistenceManager.shared
        let goal = persistence.loadProfile().dailyStepGoal
        let streak = persistence.loadStreakData().currentStreak
        let shields = persistence.loadShieldData().availableShields
        let weekSteps = buildWeekStepsFromCache()

        // Force refresh since this is a free background opportunity
        JustWalkWidgetData.updateWidgetData(
            todaySteps: steps,
            stepGoal: goal,
            currentStreak: streak,
            weekSteps: weekSteps,
            shieldCount: shields,
            forceRefresh: true
        )

        // Also update watch
        PhoneConnectivityManager.shared.pushComplicationUpdate(
            todaySteps: steps,
            stepGoal: goal,
            currentStreak: streak
        )

        print("[BackgroundTaskManager] Location-triggered widget update: \(steps) steps")
    }
}
