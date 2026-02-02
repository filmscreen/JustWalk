//
//  PhoneConnectivityManager.swift
//  JustWalk
//
//  Manages communication with Apple Watch from iPhone
//

import Foundation
import WatchConnectivity
import Combine
import HealthKit

final class PhoneConnectivityManager: NSObject, ObservableObject {

    // MARK: - Complication Push Keys
    /// Keys used for complication-specific data transfer
    private enum ComplicationKey {
        static let isComplicationUpdate = "isComplicationUpdate"
        static let todaySteps = "complication_todaySteps"
        static let stepGoal = "complication_stepGoal"
        static let currentStreak = "complication_currentStreak"
        static let timestamp = "complication_timestamp"
    }

    // MARK: - Singleton

    static let shared = PhoneConnectivityManager()

    // MARK: - Published State

    @Published private(set) var isWatchAppInstalled = false
    @Published private(set) var isWatchReachable = false
    @Published private(set) var isWatchPaired = false
    @Published private(set) var isWatchStateKnown = false
    @Published private(set) var watchWorkoutState: WorkoutState = .idle
    @Published private(set) var latestWatchStats: WorkoutLiveStats?
    @Published private(set) var isWatchConnectedStable = false

    // MARK: - Callbacks

    var onWorkoutStartedOnWatch: ((UUID, String?, String?) -> Void)?
    var onWorkoutPausedOnWatch: (() -> Void)?
    var onWorkoutResumedOnWatch: (() -> Void)?
    var onWorkoutEndedOnWatch: ((WorkoutSummaryData) -> Void)?
    var onWatchError: ((String) -> Void)?

    // MARK: - Private

    private var session: WCSession?
    private var pendingMessages: [[String: Any]] = []
    private var currentWalkId: UUID?
    private var pendingStart: (walkId: UUID, startTime: Date?, intervalData: IntervalTransferData?, modeRaw: String?, zoneLow: Int?, zoneHigh: Int?)?
    private let healthStore = HKHealthStore()
    private var connectionDebounceTimer: Timer?

    // MARK: - Initialization

    private override init() {
        super.init()
        setupSession()
    }

    private func setupSession() {
        guard WCSession.isSupported() else {
            print("WatchConnectivity not supported on this device")
            return
        }

        session = WCSession.default
        session?.delegate = self
        session?.activate()
    }

    // MARK: - Public API

    /// Check if we can communicate with Watch
    var canCommunicateWithWatch: Bool {
        guard let session = session else { return false }
        return session.isPaired && session.isWatchAppInstalled
    }

    /// Check if a Watch is paired (even if app not installed)
    var isWatchPairedNow: Bool {
        session?.isPaired ?? false
    }

    private func updateStableConnectionState() {
        connectionDebounceTimer?.invalidate()
        let newValue = canCommunicateWithWatch
        connectionDebounceTimer = Timer.scheduledTimer(withTimeInterval: 2.5, repeats: false) { [weak self] _ in
            guard let self else { return }
            DispatchQueue.main.async {
                self.isWatchConnectedStable = newValue
            }
        }
    }

    /// Check if Watch is immediately reachable
    var isWatchImmediatelyReachable: Bool {
        session?.isReachable ?? false
    }

    /// Start workout on Watch (called when iPhone starts a walk)
    func startWorkoutOnWatch(
        walkId: UUID,
        startTime: Date? = nil,
        intervalData: IntervalTransferData? = nil,
        modeRaw: String? = nil,
        zoneLow: Int? = nil,
        zoneHigh: Int? = nil,
        completion: ((Bool) -> Void)? = nil
    ) {
        self.currentWalkId = walkId
        pendingStart = (walkId, startTime, intervalData, modeRaw, zoneLow, zoneHigh)
        requestWatchAppLaunchIfPossible()

        let message = WatchMessage.startWorkout(
            walkId: walkId,
            startTime: startTime,
            intervalData: intervalData,
            modeRaw: modeRaw,
            intervalProgramRaw: nil,
            zoneLow: zoneLow,
            zoneHigh: zoneHigh
        )
        sendMessage(message, requiresImmediateDelivery: true) { success in
            if !success {
                // Fallback: update application context
                self.updateApplicationContext(
                    workoutState: .active,
                    walkId: walkId,
                    startTime: startTime,
                    intervalData: intervalData,
                    modeRaw: modeRaw,
                    zoneLow: zoneLow,
                    zoneHigh: zoneHigh
                )
            }
            completion?(success)
        }
    }

    private func requestWatchAppLaunchIfPossible() {
        guard canCommunicateWithWatch, HKHealthStore.isHealthDataAvailable() else { return }
        let configuration = HKWorkoutConfiguration()
        configuration.activityType = .walking
        configuration.locationType = .outdoor
        healthStore.startWatchApp(with: configuration) { _, _ in }
    }

    /// Pause workout on Watch
    func pauseWorkoutOnWatch() {
        guard let walkId = currentWalkId else { return }

        let message: [String: Any] = [
            WatchMessage.Key.command.rawValue: WatchMessage.Command.pauseWorkout.rawValue,
            WatchMessage.Key.walkId.rawValue: walkId.uuidString
        ]
        sendMessage(message, requiresImmediateDelivery: true)
    }

    /// Resume workout on Watch
    func resumeWorkoutOnWatch() {
        guard let walkId = currentWalkId else { return }

        let message: [String: Any] = [
            WatchMessage.Key.command.rawValue: WatchMessage.Command.resumeWorkout.rawValue,
            WatchMessage.Key.walkId.rawValue: walkId.uuidString
        ]
        sendMessage(message, requiresImmediateDelivery: true)
    }

    /// End workout on Watch (called when iPhone ends a walk)
    func endWorkoutOnWatch(completion: ((Bool) -> Void)? = nil) {
        guard let walkId = currentWalkId else {
            completion?(false)
            return
        }

        let message = WatchMessage.endWorkout(walkId: walkId)
        sendMessage(message, requiresImmediateDelivery: true) { success in
            if !success {
                // Fallback: update application context
                self.updateApplicationContext(workoutState: .ending, walkId: walkId)
            }
            self.currentWalkId = nil
            self.pendingStart = nil
            completion?(success)
        }
    }

    /// Trigger a strong phase-change haptic on Watch (best-effort)
    func triggerPhaseChangeHapticOnWatch() {
        let message: [String: Any] = [
            WatchMessage.Key.command.rawValue: WatchMessage.Command.phaseChangeHaptic.rawValue,
            WatchMessage.Key.timestamp.rawValue: Date().timeIntervalSince1970
        ]
        sendMessage(message, requiresImmediateDelivery: true)
    }

    /// Trigger a countdown warning haptic on Watch (10 seconds before phase change)
    func triggerCountdownWarningOnWatch() {
        let message: [String: Any] = [
            WatchMessage.Key.command.rawValue: WatchMessage.Command.countdownWarningHaptic.rawValue,
            WatchMessage.Key.timestamp.rawValue: Date().timeIntervalSince1970
        ]
        sendMessage(message, requiresImmediateDelivery: true)
    }

    /// Trigger a milestone haptic on Watch (e.g., 5-minute halfway point)
    func triggerMilestoneHapticOnWatch() {
        let message: [String: Any] = [
            WatchMessage.Key.command.rawValue: WatchMessage.Command.milestoneHaptic.rawValue,
            WatchMessage.Key.timestamp.rawValue: Date().timeIntervalSince1970
        ]
        sendMessage(message, requiresImmediateDelivery: true)
    }

    /// Sync streak + goal data to Watch (for watch app + complications)
    func syncStreakInfoToWatch() {
        let streak = StreakManager.shared.streakData
        let goal = PersistenceManager.shared.loadProfile().dailyStepGoal
        let shields = ShieldManager.shared.availableShields
        let todayCalories = FoodLogManager.shared.getTodaySummary().calories
        let calorieGoal = CalorieGoalManager.shared.dailyGoal

        var message: [String: Any] = [
            WatchMessage.Key.command.rawValue: WatchMessage.Command.syncStreakInfo.rawValue,
            WatchMessage.Key.streakCurrent.rawValue: streak.currentStreak,
            WatchMessage.Key.streakLongest.rawValue: streak.longestStreak,
            WatchMessage.Key.dailyGoal.rawValue: goal,
            WatchMessage.Key.availableShields.rawValue: shields,
            WatchMessage.Key.todayCalories.rawValue: todayCalories,
            WatchMessage.Key.timestamp.rawValue: Date().timeIntervalSince1970
        ]

        if let calorieGoal {
            message[WatchMessage.Key.calorieGoal.rawValue] = calorieGoal
        }

        // Best-effort immediate send + guaranteed context update
        sendMessage(message, requiresImmediateDelivery: false)
        updateApplicationContextForStreak(message)
    }

    // MARK: - Complication Push (Industry-Leading Refresh)

    /// Push step data directly to Watch complications using the dedicated complication channel.
    /// This uses `transferCurrentComplicationUserInfo()` which has its OWN SEPARATE BUDGET
    /// from WidgetKit's reloadAllTimelines(). Apple provides ~50 complication pushes per day
    /// specifically for this purpose, making it the most reliable way to update complications.
    ///
    /// Call this whenever step data changes significantly (e.g., every 500 steps or 5 minutes).
    func pushComplicationUpdate(todaySteps: Int, stepGoal: Int, currentStreak: Int) {
        guard let session = session, session.isWatchAppInstalled else { return }

        // Check remaining complication transfers to avoid wasting budget
        #if os(iOS)
        guard session.remainingComplicationUserInfoTransfers > 0 else {
            print("Complication budget exhausted for today")
            return
        }
        #endif

        let complicationData: [String: Any] = [
            ComplicationKey.isComplicationUpdate: true,
            ComplicationKey.todaySteps: todaySteps,
            ComplicationKey.stepGoal: stepGoal,
            ComplicationKey.currentStreak: currentStreak,
            ComplicationKey.timestamp: Date().timeIntervalSince1970
        ]

        // This method has PRIORITY delivery and separate budget from regular transfers.
        // It will wake the watch app/extension and trigger complication reload.
        session.transferCurrentComplicationUserInfo(complicationData)
        print("Pushed complication update: \(todaySteps) steps (budget remaining: \(session.remainingComplicationUserInfoTransfers))")
    }

    /// Check how many complication pushes remain today
    var remainingComplicationBudget: Int {
        #if os(iOS)
        return session?.remainingComplicationUserInfoTransfers ?? 0
        #else
        return 0
        #endif
    }

    // MARK: - Private Methods

    private func sendMessage(_ message: [String: Any], requiresImmediateDelivery: Bool, completion: ((Bool) -> Void)? = nil) {
        guard let session = session else {
            completion?(false)
            return
        }

        if session.isReachable && requiresImmediateDelivery {
            // Send interactive message (immediate)
            session.sendMessage(message, replyHandler: { _ in
                completion?(true)
            }, errorHandler: { error in
                print("Failed to send message: \(error.localizedDescription)")
                // Queue for later if failed
                self.pendingMessages.append(message)
                completion?(false)
            })
        } else {
            // Use transferUserInfo for guaranteed delivery (not immediate)
            session.transferUserInfo(message)
            completion?(true) // Will be delivered eventually
        }
    }

    private func updateApplicationContext(
        workoutState: WorkoutState,
        walkId: UUID?,
        startTime: Date? = nil,
        intervalData: IntervalTransferData? = nil,
        modeRaw: String? = nil,
        zoneLow: Int? = nil,
        zoneHigh: Int? = nil
    ) {
        guard let session = session else { return }
        var context: [String: Any] = [
            WatchMessage.Key.command.rawValue: workoutState == .ending
                ? WatchMessage.Command.endWorkout.rawValue
                : WatchMessage.Command.startWorkout.rawValue,
            WatchMessage.Key.walkId.rawValue: walkId?.uuidString ?? "",
            "workoutState": workoutState.rawValue,
            "isPro": SubscriptionManager.shared.isPro,
            "lastSyncTime": Date()
        ]
        if let startTime {
            context[WatchMessage.Key.startTime.rawValue] = startTime.timeIntervalSince1970
        }
        if let intervalData, let data = try? JSONEncoder().encode(intervalData) {
            context[WatchMessage.Key.intervalData.rawValue] = data
        }
        if let modeRaw {
            context[WatchMessage.Key.modeRaw.rawValue] = modeRaw
        }
        if let zoneLow {
            context[WatchMessage.Key.zoneLow.rawValue] = zoneLow
        }
        if let zoneHigh {
            context[WatchMessage.Key.zoneHigh.rawValue] = zoneHigh
        }
        do {
            try session.updateApplicationContext(context)
        } catch {
            print("Failed to update application context: \(error)")
        }
    }

    private func updateApplicationContextForStreak(_ message: [String: Any]) {
        guard let session = session else { return }
        do {
            try session.updateApplicationContext(message)
        } catch {
            print("Failed to update streak context: \(error)")
        }
    }

    private func handleReceivedMessage(_ message: [String: Any]) {
        guard let commandString = message[WatchMessage.Key.command.rawValue] as? String else { return }

        // Handle events from Watch
        if let event = WatchMessage.Event(rawValue: commandString) {
            switch event {
            case .workoutStarted:
                if let walkIdString = message[WatchMessage.Key.walkId.rawValue] as? String,
                   let walkId = UUID(uuidString: walkIdString) {
                    let modeRaw = message[WatchMessage.Key.modeRaw.rawValue] as? String
                    let intervalRaw = message[WatchMessage.Key.intervalProgramRaw.rawValue] as? String
                    DispatchQueue.main.async {
                        self.watchWorkoutState = .active
                        self.pendingStart = nil
                        self.onWorkoutStartedOnWatch?(walkId, modeRaw, intervalRaw)
                    }
                }

            case .workoutPaused:
                DispatchQueue.main.async {
                    self.watchWorkoutState = .paused
                    self.onWorkoutPausedOnWatch?()
                }

            case .workoutResumed:
                DispatchQueue.main.async {
                    self.watchWorkoutState = .active
                    self.onWorkoutResumedOnWatch?()
                }

            case .workoutEnded:
                if let data = message[WatchMessage.Key.workoutData.rawValue] as? Data,
                   let summary = try? JSONDecoder().decode(WorkoutSummaryData.self, from: data) {
                    DispatchQueue.main.async {
                        self.watchWorkoutState = .idle
                        self.currentWalkId = nil
                        self.pendingStart = nil
                        self.onWorkoutEndedOnWatch?(summary)
                    }
                }

            case .statsUpdate:
                if let data = message[WatchMessage.Key.workoutData.rawValue] as? Data,
                   let stats = try? JSONDecoder().decode(WorkoutLiveStats.self, from: data) {
                    DispatchQueue.main.async {
                        self.latestWatchStats = stats
                    }
                }

            case .heartRateUpdate:
                if let hr = message[WatchMessage.Key.heartRate.rawValue] as? Int {
                    DispatchQueue.main.async {
                        FatBurnZoneManager.shared.updateHeartRate(hr)
                    }
                }

            case .fatBurnOutOfRangeLow:
                DispatchQueue.main.async {
                    JustWalkHaptics.fatBurnOutOfRangeLow()
                }

            case .fatBurnOutOfRangeHigh:
                DispatchQueue.main.async {
                    JustWalkHaptics.fatBurnOutOfRangeHigh()
                }

            case .workoutError:
                if let error = message[WatchMessage.Key.error.rawValue] as? String {
                    DispatchQueue.main.async {
                        self.onWatchError?(error)
                    }
                }
            }
        }
    }

    private func retryPendingStartIfNeeded() {
        guard let pendingStart = pendingStart else { return }
        let message = WatchMessage.startWorkout(
            walkId: pendingStart.walkId,
            startTime: pendingStart.startTime,
            intervalData: pendingStart.intervalData,
            modeRaw: pendingStart.modeRaw,
            intervalProgramRaw: nil,
            zoneLow: pendingStart.zoneLow,
            zoneHigh: pendingStart.zoneHigh
        )
        sendMessage(message, requiresImmediateDelivery: true)
    }
}

// MARK: - WCSessionDelegate

extension PhoneConnectivityManager: WCSessionDelegate {

    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        DispatchQueue.main.async {
            self.isWatchAppInstalled = session.isWatchAppInstalled
            self.isWatchReachable = session.isReachable
            self.isWatchPaired = session.isPaired
            self.isWatchStateKnown = true
        }
        updateStableConnectionState()

        // Send any pending messages
        if activationState == .activated && session.isReachable {
            pendingMessages.forEach { sendMessage($0, requiresImmediateDelivery: false) }
            pendingMessages.removeAll()
            retryPendingStartIfNeeded()
        }
    }

    func sessionDidBecomeInactive(_ session: WCSession) {
        // iOS only
    }

    func sessionDidDeactivate(_ session: WCSession) {
        // iOS only — reactivate
        session.activate()
    }

    func sessionWatchStateDidChange(_ session: WCSession) {
        DispatchQueue.main.async {
            self.isWatchAppInstalled = session.isWatchAppInstalled
            self.isWatchReachable = session.isReachable
            self.isWatchPaired = session.isPaired
            self.isWatchStateKnown = true
        }
        updateStableConnectionState()
    }

    func sessionReachabilityDidChange(_ session: WCSession) {
        DispatchQueue.main.async {
            self.isWatchReachable = session.isReachable
        }
        updateStableConnectionState()

        // Watch reconnected during an active walk — sync state
        if session.isReachable {
            if watchWorkoutState == .active, let walkId = currentWalkId {
                updateApplicationContext(workoutState: .active, walkId: walkId)
            } else {
                retryPendingStartIfNeeded()
            }
        }
    }

    // Receive interactive message
    func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        handleReceivedMessage(message)
    }

    func session(_ session: WCSession, didReceiveMessage message: [String: Any], replyHandler: @escaping ([String: Any]) -> Void) {
        handleReceivedMessage(message)
        replyHandler(["received": true])
    }

    // Receive transferred user info (guaranteed delivery)
    func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any]) {
        handleReceivedMessage(userInfo)
    }

    // Receive application context update
    func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        // Handle context updates from Watch (e.g., workout ended fallback)
        handleReceivedMessage(applicationContext)
    }
}
