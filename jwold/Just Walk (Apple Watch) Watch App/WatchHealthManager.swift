//
//  WatchHealthManager.swift
//  Just Walk Watch App
//
//  HealthKit-based step counting for Apple Watch.
//  Uses HKStatisticsQuery with .cumulativeSum - Apple handles deduplication.
//  HealthKit iCloud syncs step data - no WatchConnectivity needed for steps.
//

import Foundation
import CoreMotion
import HealthKit
import WatchConnectivity
import Combine
import WidgetKit
import WatchKit

// MARK: - WatchHealthManager

@MainActor
class WatchHealthManager: NSObject, ObservableObject {

    static let shared = WatchHealthManager()

    // MARK: - Dependencies

    private let pedometer = CMPedometer()
    private let healthStore = HKHealthStore()
    private let calendar = Calendar.current

    // MARK: - Published State

    @Published private(set) var todaySteps: Int = 0
    @Published private(set) var todayDistance: Double = 0

    @Published var stepGoal: Int = 10000 {
        didSet { saveToAppGroup() }
    }

    @Published private(set) var isAuthorized: Bool = false

    // MARK: - Internal Tracking

    private(set) var pedometerSteps: Int = 0
    private(set) var healthKitSteps: Int = 0

    // MARK: - Configuration

    private let healthKitRefreshThrottle: TimeInterval = 30

    // MARK: - Internal State

    private var trackingDate: Date
    private var lastHealthKitRefresh: Date = .distantPast
    private var lastComplicationUpdate: Date = .distantPast
    private let complicationUpdateInterval: TimeInterval = 900

    // MARK: - App Group

    private let appGroupID = "group.com.onworldtech.JustWalk"

    // MARK: - Extended Runtime

    private var extendedSession: WKExtendedRuntimeSession?
    private var syncTimer: Timer?

    // MARK: - Initialization

    override private init() {
        self.trackingDate = Calendar.current.startOfDay(for: Date())
        super.init()

        loadFromAppGroup()

        // Activate WCSession (minimal - no step sync needed)
        if WCSession.isSupported() {
            WCSession.default.delegate = self
            WCSession.default.activate()
        }

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleDayChange),
            name: .NSCalendarDayChanged,
            object: nil
        )

        setupLifecycleObservers()
        startTracking()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
        syncTimer?.invalidate()
    }

    // MARK: - Public API

    func requestAuthorization() async {
        print("⌚️ HealthKit: isHealthDataAvailable = \(HKHealthStore.isHealthDataAvailable())")

        guard HKHealthStore.isHealthDataAvailable() else {
            print("⌚️ HealthKit: Not available on this device")
            isAuthorized = false
            return
        }

        let typesToRead: Set<HKObjectType> = [
            HKQuantityType.quantityType(forIdentifier: .stepCount)!,
            HKQuantityType.quantityType(forIdentifier: .distanceWalkingRunning)!,
            HKQuantityType.quantityType(forIdentifier: .heartRate)!,
            HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned)!,
            HKObjectType.workoutType(),
            HKSeriesType.workoutRoute()
        ]

        let typesToWrite: Set<HKSampleType> = [
            HKObjectType.workoutType(),
            HKSeriesType.workoutRoute()
        ]

        do {
            try await healthStore.requestAuthorization(toShare: typesToWrite, read: typesToRead)

            // Check actual authorization status for step count
            // Note: HealthKit doesn't reveal read permission status directly,
            // but we can check write permission for workouts
            let workoutStatus = healthStore.authorizationStatus(for: HKObjectType.workoutType())
            isAuthorized = (workoutStatus == .sharingAuthorized)

            if isAuthorized {
                startTracking()
            }
        } catch {
            isAuthorized = false
            print("⌚️ HealthKit auth error: \(error)")
        }
    }

    /// Check current authorization status (call on app launch)
    func checkAuthorizationStatus() {
        guard HKHealthStore.isHealthDataAvailable() else {
            isAuthorized = false
            return
        }

        // Check workout write permission as proxy for overall authorization
        let workoutStatus = healthStore.authorizationStatus(for: HKObjectType.workoutType())
        isAuthorized = (workoutStatus == .sharingAuthorized)
    }

    func startTracking() {
        Task {
            await refreshFromHealthKit()
        }
        startHealthKitObserver()
        startPedometerUpdates()
        startSyncTimer()
    }

    func handleAppBecomeActive() {
        print("⌚️ App became active")

        let today = calendar.startOfDay(for: Date())
        if trackingDate < today {
            handleDayChange()
            return
        }

        // Immediate pedometer query for instant display (avoids 0-step flash after force-quit)
        let startOfDay = calendar.startOfDay(for: Date())
        pedometer.queryPedometerData(from: startOfDay, to: Date()) { [weak self] data, _ in
            guard let data = data else { return }
            Task { @MainActor [weak self] in
                self?.pedometerSteps = data.numberOfSteps.intValue
                self?.updateDisplayValue()
            }
        }

        lastHealthKitRefresh = .distantPast

        Task {
            await refreshFromHealthKit()
        }

        updateComplications(force: true)
        startExtendedSession()
    }

    // MARK: - HealthKit Query (Simple - Apple handles deduplication)

    private func fetchTodayStepsFromHealthKit() async -> Int {
        guard let stepType = HKQuantityType.quantityType(forIdentifier: .stepCount) else {
            return 0
        }

        let startOfDay = calendar.startOfDay(for: Date())
        let predicate = HKQuery.predicateForSamples(
            withStart: startOfDay,
            end: Date(),
            options: .strictStartDate
        )

        return await withCheckedContinuation { continuation in
            let query = HKStatisticsQuery(
                quantityType: stepType,
                quantitySamplePredicate: predicate,
                options: .cumulativeSum  // Apple handles iPhone + Watch deduplication
            ) { _, statistics, error in
                if let error = error {
                    print("⌚️ HealthKit query failed: \(error)")
                    continuation.resume(returning: 0)
                    return
                }
                let steps = Int(statistics?.sumQuantity()?.doubleValue(for: .count()) ?? 0)
                continuation.resume(returning: steps)
            }
            self.healthStore.execute(query)
        }
    }

    // MARK: - HealthKit Refresh

    func refreshFromHealthKit() async {
        let now = Date()

        guard now.timeIntervalSince(lastHealthKitRefresh) >= healthKitRefreshThrottle else { return }
        lastHealthKitRefresh = now

        let steps = await fetchTodayStepsFromHealthKit()
        healthKitSteps = steps

        updateDisplayValue()
        print("⌚️ HealthKit: \(steps) steps")
    }

    // MARK: - Day Change

    @objc private func handleDayChange() {
        Task { @MainActor in
            print("⌚️ Day changed - resetting")

            pedometer.stopUpdates()

            todaySteps = 0
            todayDistance = 0
            pedometerSteps = 0
            healthKitSteps = 0

            trackingDate = calendar.startOfDay(for: Date())

            saveToAppGroup()
            updateComplications(force: true)

            try? await Task.sleep(nanoseconds: 500_000_000)

            startPedometerUpdates()
            await refreshFromHealthKit()
        }
    }

    func checkForNewDay() {
        let today = calendar.startOfDay(for: Date())
        if trackingDate < today {
            handleDayChange()
        }
    }

    // MARK: - CMPedometer

    private func startPedometerUpdates() {
        guard CMPedometer.isStepCountingAvailable() else {
            print("⌚️ Pedometer not available")
            return
        }

        let startOfDay = calendar.startOfDay(for: Date())
        trackingDate = startOfDay

        pedometer.queryPedometerData(from: startOfDay, to: Date()) { [weak self] data, error in
            guard let data = data, error == nil else { return }
            Task { @MainActor [weak self] in
                self?.pedometerSteps = data.numberOfSteps.intValue
                self?.updateDisplayValue()
            }
        }

        pedometer.startUpdates(from: startOfDay) { [weak self] data, error in
            guard let data = data, error == nil else { return }
            Task { @MainActor [weak self] in
                self?.pedometerSteps = data.numberOfSteps.intValue
                self?.updateDisplayValue()
            }
        }

        print("⌚️ Pedometer started")
    }

    // MARK: - Display Value

    private func updateDisplayValue() {
        let previousSteps = todaySteps

        // Monotonic ratchet: use max of pedometer and HealthKit
        // This ensures step count never decreases during the day
        // HealthKit provides the authoritative total (with Apple's deduplication)
        // Pedometer provides real-time updates between HealthKit refreshes
        let newSteps = max(pedometerSteps, healthKitSteps)
        todaySteps = max(todaySteps, newSteps)  // Never decrease
        todayDistance = Double(todaySteps) * 0.762

        saveToAppGroup()

        if todaySteps != previousSteps {
            updateComplications(force: false)
        }
    }

    // MARK: - HealthKit Observer

    private var healthKitObserverQuery: HKObserverQuery?

    private func startHealthKitObserver() {
        guard let stepType = HKQuantityType.quantityType(forIdentifier: .stepCount) else { return }

        if let existing = healthKitObserverQuery {
            healthStore.stop(existing)
        }

        healthStore.enableBackgroundDelivery(for: stepType, frequency: .immediate) { success, error in
            if let error = error {
                print("⌚️ Background delivery error: \(error)")
            }
        }

        let query = HKObserverQuery(sampleType: stepType, predicate: nil) { [weak self] _, completionHandler, _ in
            Task { @MainActor [weak self] in
                self?.lastHealthKitRefresh = .distantPast
                await self?.refreshFromHealthKit()
                completionHandler()
            }
        }

        healthKitObserverQuery = query
        healthStore.execute(query)
    }

    // MARK: - App Group

    private func saveToAppGroup() {
        guard let defaults = UserDefaults(suiteName: appGroupID) else { return }
        guard todaySteps <= 100_000 else { return }

        defaults.set(todaySteps, forKey: "todaySteps")
        defaults.set(todayDistance, forKey: "todayDistance")
        defaults.set(stepGoal, forKey: "dailyStepGoal")
        defaults.set(trackingDate, forKey: "forDate")
        defaults.set(Date(), forKey: "lastUpdateDate")
    }

    private func loadFromAppGroup() {
        guard let defaults = UserDefaults(suiteName: appGroupID) else { return }

        let goal = defaults.integer(forKey: "dailyStepGoal")
        if goal > 0 {
            stepGoal = goal
        }

        if let forDate = defaults.object(forKey: "forDate") as? Date,
           calendar.isDateInToday(forDate) {
            todaySteps = defaults.integer(forKey: "todaySteps")
            todayDistance = defaults.double(forKey: "todayDistance")
        }
    }

    // MARK: - Complications

    private func updateComplications(force: Bool) {
        let now = Date()
        guard force || now.timeIntervalSince(lastComplicationUpdate) >= complicationUpdateInterval else { return }
        lastComplicationUpdate = now
        WidgetCenter.shared.reloadAllTimelines()
    }

    func forceComplicationUpdate() {
        saveToAppGroup()
        updateComplications(force: true)
    }

    // MARK: - Sync Timer

    private func startSyncTimer() {
        syncTimer?.invalidate()
        syncTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.performPeriodicSync()
            }
        }
    }

    private func performPeriodicSync() {
        let startOfDay = calendar.startOfDay(for: Date())
        pedometer.queryPedometerData(from: startOfDay, to: Date()) { [weak self] data, _ in
            guard let data = data else { return }
            Task { @MainActor [weak self] in
                self?.pedometerSteps = data.numberOfSteps.intValue
                self?.updateDisplayValue()
            }
        }
    }

    // MARK: - Lifecycle

    private func setupLifecycleObservers() {
        NotificationCenter.default.addObserver(
            forName: WKExtension.applicationDidBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.handleAppBecomeActive()
            }
        }

        NotificationCenter.default.addObserver(
            forName: WKExtension.applicationWillResignActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.saveToAppGroup()
            }
        }
    }

    // MARK: - Extended Runtime

    private func startExtendedSession() {
        guard extendedSession == nil || extendedSession?.state == .invalid else { return }
        extendedSession = WKExtendedRuntimeSession()
        extendedSession?.delegate = self
        extendedSession?.start()
    }

    // MARK: - Computed Properties

    var goalProgress: Double {
        guard stepGoal > 0 else { return 0 }
        return Double(todaySteps) / Double(stepGoal)
    }
}

// MARK: - Extended Runtime Session Delegate

extension WatchHealthManager: WKExtendedRuntimeSessionDelegate {
    nonisolated func extendedRuntimeSessionDidStart(_ session: WKExtendedRuntimeSession) {
        Task { @MainActor in
            print("⌚️ Extended session started")
            self.forceComplicationUpdate()
        }
    }

    nonisolated func extendedRuntimeSessionWillExpire(_ session: WKExtendedRuntimeSession) {
        Task { @MainActor in
            print("⌚️ Extended session expiring")
            self.saveToAppGroup()
        }
    }

    nonisolated func extendedRuntimeSession(_ session: WKExtendedRuntimeSession, didInvalidateWith reason: WKExtendedRuntimeSessionInvalidationReason, error: Error?) {
        Task { @MainActor in
            self.extendedSession = nil
            print("⌚️ Extended session ended: \(reason)")
        }
    }
}

// MARK: - WCSessionDelegate (Minimal)

extension WatchHealthManager: WCSessionDelegate {
    nonisolated func session(_ session: WCSession,
                             activationDidCompleteWith activationState: WCSessionActivationState,
                             error: Error?) {
        if let error = error {
            print("⌚️ WCSession error: \(error)")
        } else {
            print("⌚️ WCSession activated: \(activationState.rawValue)")
        }
    }
}
