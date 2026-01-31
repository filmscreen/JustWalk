//
//  WalkSessionManager.swift
//  JustWalk
//
//  GPS tracking with Eco-Track battery optimization and anti-cheat measures
//

import Foundation
import CoreLocation
import CoreMotion
import UIKit
import Combine

class WalkSessionManager: NSObject, ObservableObject {
    static let shared = WalkSessionManager()

    private let locationManager = CLLocationManager()
    private var healthKitManager = HealthKitManager.shared
    private let pedometer = CMPedometer()
    private let watchConnectivity = PhoneConnectivityManager.shared
    private var stepsBeforePause: Int = 0

    // State
    @Published var isWalking: Bool = false
    @Published var isPaused: Bool = false
    @Published var currentMode: WalkMode = .free
    @Published var currentIntervalProgram: IntervalProgram?
    @Published var currentCustomInterval: CustomIntervalConfig?
    @Published var currentWalkId: UUID?

    // Tracking data
    @Published var startTime: Date?
    @Published var pauseTime: Date?
    @Published var totalPausedDuration: TimeInterval = 0
    @Published var routeCoordinates: [CLLocationCoordinate2D] = []
    @Published var currentLocation: CLLocationCoordinate2D?
    @Published var elapsedSeconds: Int = 0
    @Published var currentSteps: Int = 0
    @Published var currentDistance: Double = 0 // meters

    // Eco-Track state
    private var screenLockedTime: Date?
    private var isEcoTrackActive: Bool = false
    private let ecoTrackThreshold: TimeInterval = 300 // 5 minutes

    // Walk completion
    @Published var completedWalk: TrackedWalk?

    // Cross-device state
    private var isEndingWalk = false
    @Published var isWatchInitiated: Bool = false

    // Post-meal duration (10 minutes)
    static let postMealDurationSeconds = 600

    // Anti-cheat
    private var lastStepCount: Int = 0
    private var zeroStepsStartTime: Date?
    private var ghostMinutesDetected: Int = 0
    private let ghostCheckThreshold: TimeInterval = 300 // 5 minutes
    private let maxSpeedMPS: Double = 6.7 // ~15 mph
    private var speedViolationTime: Date?
    private let speedCooldown: TimeInterval = 30 // 30-second cooldown after speed violation

    // MARK: - Auto-End System (Forgotten Walk Protection)

    /// Inactivity tracking for auto-end
    private var stepCountAtLastActivity: Int = 0
    private var lastActivityTime: Date = Date()
    private let inactivityThreshold: TimeInterval = 10 * 60 // 10 minutes of no steps
    private let minimumStepsForActivity: Int = 50 // Need at least 50 steps to count as "active"
    private var inactivityCheckTimer: Timer?

    /// Hard time limits by walk mode (backstop protection)
    private let hardTimeLimits: [WalkMode: TimeInterval] = [
        .free: 3 * 60 * 60,      // 3 hours
        .interval: 2 * 60 * 60,  // 2 hours
        .fatBurn: 2 * 60 * 60,   // 2 hours
        .postMeal: 1 * 60 * 60   // 1 hour
    ]

    /// Reason for auto-ending a walk
    enum AutoEndReason {
        case inactivity
        case hardTimeLimit
    }

    // Timer
    private var timer: Timer?

    // Background task
    private var backgroundTaskID: UIBackgroundTaskIdentifier = .invalid

    // State persistence key
    private static let savedStateKey = "walk_session_state"

    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.distanceFilter = 10 // Only deliver updates after 10m movement (saves battery)
        locationManager.allowsBackgroundLocationUpdates = true
        locationManager.pausesLocationUpdatesAutomatically = false

        locationAuthorizationStatus = locationManager.authorizationStatus

        // Monitor screen lock
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(screenDidLock),
            name: UIApplication.protectedDataWillBecomeUnavailableNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(screenDidUnlock),
            name: UIApplication.protectedDataDidBecomeAvailableNotification,
            object: nil
        )

        setupWatchCallbacks()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    // MARK: - Location Authorization

    func requestLocationAuthorization() {
        locationManager.requestWhenInUseAuthorization()
    }

    func requestAlwaysAuthorization() {
        locationManager.requestAlwaysAuthorization()
    }

    @Published var locationAuthorizationStatus: CLAuthorizationStatus = .notDetermined

    // MARK: - Walk Control

    func startWalk(mode: WalkMode, intervalProgram: IntervalProgram? = nil, customInterval: CustomIntervalConfig? = nil, walkId: UUID? = nil) {
        guard !isWalking else { return }

        // Reset cached phases for new session (ensures fresh UUIDs for phase tracking)
        IntervalProgram.resetCachedPhases()

        let id = walkId ?? UUID()
        currentWalkId = id
        isWalking = true
        isPaused = false
        currentMode = mode
        currentIntervalProgram = intervalProgram
        currentCustomInterval = customInterval
        isWatchInitiated = walkId != nil
        JustWalkHaptics.walkStart()

        startTime = Date()
        routeCoordinates = []
        elapsedSeconds = 0
        currentSteps = 0
        currentDistance = 0
        totalPausedDuration = 0
        stepsBeforePause = 0
        lastStepCount = 0
        zeroStepsStartTime = nil
        ghostMinutesDetected = 0
        speedViolationTime = nil
        completedWalk = nil

        // Request location authorization if not yet determined, then start updates
        let status = locationManager.authorizationStatus
        if status == .notDetermined {
            locationManager.requestWhenInUseAuthorization()
            // Location updates will start when authorization is granted (see delegate)
        } else if status == .authorizedWhenInUse || status == .authorizedAlways {
            locationManager.startUpdatingLocation()
        }

        startTimer()
        startPedometer()
        startInactivityMonitoring()

        // Schedule walk reminder notification
        let expectedDuration = getExpectedDurationSeconds(mode: mode, intervalProgram: intervalProgram, customInterval: customInterval)
        NotificationManager.shared.scheduleWalkReminder(mode: mode, expectedDurationSeconds: expectedDuration)

        // Start Live Activity with countdown data for interval and post-meal modes
        let countdownRemaining: Int?
        let countdownEndDate: Date?
        let phaseType: String?

        if mode == .interval {
            countdownRemaining = getSecondsRemainingInPhase()
            countdownEndDate = getCurrentIntervalPhaseEndDate()
            phaseType = getCurrentIntervalPhaseTypeLabel()
        } else if mode == .postMeal {
            countdownRemaining = Self.postMealDurationSeconds
            countdownEndDate = Date().addingTimeInterval(TimeInterval(Self.postMealDurationSeconds))
            phaseType = nil
        } else {
            countdownRemaining = nil
            countdownEndDate = nil
            phaseType = nil
        }

        LiveActivityManager.shared.startActivity(
            mode: mode,
            intervalProgram: intervalProgram,
            intervalPhaseRemaining: countdownRemaining,
            intervalPhaseEndDate: countdownEndDate,
            intervalPhaseType: phaseType
        )

        // Start Watch workout silently if available (only when iPhone-initiated).
        // Interval/fat burn/post-meal flows start Watch with additional context elsewhere.
        if !isWatchInitiated && watchConnectivity.canCommunicateWithWatch, mode == .free {
            watchConnectivity.startWorkoutOnWatch(walkId: id, startTime: startTime, modeRaw: "free")
        }
    }

    func pauseWalk() {
        pauseWalkInternal()
        watchConnectivity.pauseWorkoutOnWatch()
    }

    /// Internal pause logic — does NOT notify Watch (used when Watch initiated the pause)
    private func pauseWalkInternal() {
        guard isWalking, !isPaused else { return }
        isPaused = true
        pauseTime = Date()
        JustWalkHaptics.walkPause()
        timer?.invalidate()
        locationManager.stopUpdatingLocation()
        stepsBeforePause = currentSteps
        stopPedometer()
        stopInactivityMonitoring() // Pause inactivity timer while walk is paused

        // Calculate countdown remaining for interval and post-meal modes
        let countdownRemaining: Int?
        let phaseType: String?

        if currentMode == .interval {
            countdownRemaining = getSecondsRemainingInPhase()
            phaseType = getCurrentIntervalPhaseTypeLabel()
        } else if currentMode == .postMeal {
            countdownRemaining = max(0, Self.postMealDurationSeconds - elapsedSeconds)
            phaseType = nil
        } else {
            countdownRemaining = nil
            phaseType = nil
        }

        LiveActivityManager.shared.updatePaused(
            true,
            elapsedSeconds: elapsedSeconds,
            intervalPhaseRemaining: countdownRemaining,
            intervalPhaseEndDate: nil,
            intervalPhaseType: phaseType
        )
    }

    func resumeWalk() {
        resumeWalkInternal()
        watchConnectivity.resumeWorkoutOnWatch()
    }

    /// Internal resume logic — does NOT notify Watch (used when Watch initiated the resume)
    private func resumeWalkInternal() {
        guard isWalking, isPaused else { return }
        if let pauseStart = pauseTime {
            totalPausedDuration += Date().timeIntervalSince(pauseStart)
        }
        isPaused = false
        pauseTime = nil
        JustWalkHaptics.walkResume()

        locationManager.startUpdatingLocation()
        startTimer()
        startPedometer()
        startInactivityMonitoring() // Resume inactivity monitoring

        // Calculate countdown data for interval and post-meal modes
        let countdownRemaining: Int?
        let countdownEndDate: Date?
        let phaseType: String?

        if currentMode == .interval {
            countdownRemaining = getSecondsRemainingInPhase()
            countdownEndDate = getCurrentIntervalPhaseEndDate()
            phaseType = getCurrentIntervalPhaseTypeLabel()
        } else if currentMode == .postMeal {
            countdownRemaining = max(0, Self.postMealDurationSeconds - elapsedSeconds)
            countdownEndDate = Date().addingTimeInterval(TimeInterval(countdownRemaining ?? 0))
            phaseType = nil
        } else {
            countdownRemaining = nil
            countdownEndDate = nil
            phaseType = nil
        }

        LiveActivityManager.shared.updatePaused(
            false,
            elapsedSeconds: elapsedSeconds,
            intervalPhaseRemaining: countdownRemaining,
            intervalPhaseEndDate: countdownEndDate,
            intervalPhaseType: phaseType
        )
    }

    func endWalk() async -> TrackedWalk? {
        guard isWalking, !isEndingWalk, let start = startTime else {
            LiveActivityManager.shared.endActivity()
            return nil
        }
        isEndingWalk = true
        defer { isEndingWalk = false }

        timer?.invalidate()
        locationManager.stopUpdatingLocation()
        stopPedometer()
        stopInactivityMonitoring()
        NotificationManager.shared.cancelWalkReminder()

        let end = Date()
        let duration = Int(end.timeIntervalSince(start) - totalPausedDuration) / 60

        // Use pedometer step count (real-time, no delay) with HealthKit fallback
        let steps = currentSteps > 0 ? currentSteps : await healthKitManager.fetchStepsDuring(start: start, end: end)
        let distance = await healthKitManager.fetchDistanceDuring(start: start, end: end)

        let intervalDuration = currentIntervalProgram?.duration ?? currentCustomInterval?.totalMinutes
        let isInterval = currentIntervalProgram != nil || currentCustomInterval != nil
        let intervalCompleted = isInterval && duration >= (intervalDuration ?? 0)

        // Fetch calories for the walk
        let calories = await healthKitManager.fetchCaloriesDuring(start: start, end: end)

        let walk = TrackedWalk(
            id: currentWalkId ?? UUID(),
            startTime: start,
            endTime: end,
            durationMinutes: duration,
            steps: steps,
            distanceMeters: distance,
            mode: currentMode,
            intervalProgram: currentIntervalProgram,
            intervalCompleted: isInterval ? intervalCompleted : nil,
            routeCoordinates: routeCoordinates.map { CodableCoordinate(latitude: $0.latitude, longitude: $0.longitude) },
            customIntervalConfig: currentCustomInterval,
            activeCalories: calories > 0 ? calories : nil
        )

        // Save workout to Apple Health (skip if Watch-initiated, Watch already saves to Health)
        if !isWatchInitiated && duration >= 1 {
            let _ = await healthKitManager.saveWorkout(
                startDate: start,
                endDate: end,
                totalDistance: distance,
                totalCalories: calories > 0 ? calories : nil
            )
        }

        // Store completed walk for WalkTabView to process
        if intervalCompleted {
            JustWalkHaptics.intervalComplete()
        }
        JustWalkHaptics.walkComplete()
        self.completedWalk = walk

        // Reset state
        isWalking = false
        isPaused = false
        startTime = nil
        currentMode = .free
        currentIntervalProgram = nil
        currentCustomInterval = nil
        currentWalkId = nil
        isWatchInitiated = false
        isEcoTrackActive = false

        // End Live Activity
        LiveActivityManager.shared.endActivity()

        // End Watch workout if active
        if watchConnectivity.watchWorkoutState == .active || watchConnectivity.watchWorkoutState == .paused {
            watchConnectivity.endWorkoutOnWatch()
        }

        // Clear persisted state and background task
        clearSavedState()
        endBackgroundTask()

        return walk
    }

    // MARK: - Pedometer

    private func startPedometer() {
        #if targetEnvironment(simulator)
        // CMPedometer unavailable on simulator — use mock timer
        startMockPedometerTimer()
        #else
        guard CMPedometer.isStepCountingAvailable() else { return }
        pedometer.startUpdates(from: Date()) { [weak self] data, error in
            guard let self, let data, error == nil else { return }
            DispatchQueue.main.async {
                self.currentSteps = self.stepsBeforePause + data.numberOfSteps.intValue
            }
        }
        #endif
    }

    private func stopPedometer() {
        #if targetEnvironment(simulator)
        mockPedometerTimer?.invalidate()
        mockPedometerTimer = nil
        #else
        pedometer.stopUpdates()
        #endif
    }

    // Simulator mock: increment steps at ~100 steps/min
    private var mockPedometerTimer: Timer?

    private func startMockPedometerTimer() {
        mockPedometerTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            guard let self, self.isWalking, !self.isPaused else { return }
            // ~100 steps per minute = ~1.67 steps/sec
            self.currentSteps += 2
        }
    }

    // MARK: - Timer

    private func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            self?.tick()
        }
    }

    private func tick() {
        guard let start = startTime, !isPaused else { return }
        elapsedSeconds = Int(Date().timeIntervalSince(start) - totalPausedDuration)

        if shouldAutoEndInterval() {
            Task { await endWalk() }
            return
        }

        // Update Live Activity every second for countdown modes (interval/postMeal), every 5s otherwise
        let isCountdownMode = currentMode == .interval || currentMode == .postMeal

        if isCountdownMode || elapsedSeconds % 5 == 0 {
            let countdownRemaining: Int?
            let countdownEndDate: Date?
            let phaseType: String?

            if currentMode == .interval {
                countdownRemaining = getSecondsRemainingInPhase()
                countdownEndDate = getCurrentIntervalPhaseEndDate()
                phaseType = getCurrentIntervalPhaseTypeLabel()
            } else if currentMode == .postMeal {
                countdownRemaining = max(0, Self.postMealDurationSeconds - elapsedSeconds)
                countdownEndDate = startTime?.addingTimeInterval(TimeInterval(Self.postMealDurationSeconds) + totalPausedDuration)
                phaseType = nil
            } else {
                countdownRemaining = nil
                countdownEndDate = nil
                phaseType = nil
            }

            LiveActivityManager.shared.updateProgress(
                elapsedSeconds: elapsedSeconds,
                steps: currentSteps,
                distance: currentDistance,
                intervalPhaseRemaining: countdownRemaining,
                intervalPhaseEndDate: countdownEndDate,
                intervalPhaseType: phaseType
            )
        }

        // Check for ghost (anti-cheat)
        checkForGhost()
    }

    // MARK: - Eco-Track

    @objc private func screenDidLock() {
        screenLockedTime = Date()
    }

    @objc private func screenDidUnlock() {
        screenLockedTime = nil
        if isEcoTrackActive {
            // Restore high accuracy
            locationManager.desiredAccuracy = kCLLocationAccuracyBest
            isEcoTrackActive = false
        }
    }

    private func checkEcoTrack() {
        guard isWalking, let lockedTime = screenLockedTime else { return }

        if Date().timeIntervalSince(lockedTime) > ecoTrackThreshold && !isEcoTrackActive {
            // Downgrade GPS accuracy
            locationManager.desiredAccuracy = kCLLocationAccuracyThreeKilometers
            isEcoTrackActive = true
        }
    }

    // MARK: - Anti-Cheat

    private func checkForGhost() {
        // Check if steps have been static
        if currentSteps == lastStepCount {
            if zeroStepsStartTime == nil {
                zeroStepsStartTime = Date()
            } else if let start = zeroStepsStartTime,
                      Date().timeIntervalSince(start) > ghostCheckThreshold {
                ghostMinutesDetected += Int(ghostCheckThreshold) / 60
                zeroStepsStartTime = Date() // Reset timer for next ghost period
            }
        } else {
            zeroStepsStartTime = nil
        }
        lastStepCount = currentSteps
    }

    // MARK: - Auto-End System (Forgotten Walk Protection)

    /// Start monitoring for inactivity to auto-end forgotten walks
    private func startInactivityMonitoring() {
        // Reset activity tracking
        stepCountAtLastActivity = currentSteps
        lastActivityTime = Date()

        // Check every 2 minutes for inactivity
        inactivityCheckTimer?.invalidate()
        inactivityCheckTimer = Timer.scheduledTimer(withTimeInterval: 120, repeats: true) { [weak self] _ in
            self?.checkForInactivityAndLimits()
        }
    }

    /// Stop inactivity monitoring
    private func stopInactivityMonitoring() {
        inactivityCheckTimer?.invalidate()
        inactivityCheckTimer = nil
    }

    /// Check for inactivity and hard time limits
    private func checkForInactivityAndLimits() {
        guard isWalking, !isPaused, !isEndingWalk else { return }

        // Check hard time limit first (backstop)
        if let start = startTime {
            let elapsed = Date().timeIntervalSince(start) - totalPausedDuration
            let limit = hardTimeLimits[currentMode] ?? (3 * 60 * 60)

            if elapsed >= limit {
                autoEndWalk(reason: .hardTimeLimit)
                return
            }
        }

        // Check for inactivity
        let stepsSinceLastActivity = currentSteps - stepCountAtLastActivity

        if stepsSinceLastActivity >= minimumStepsForActivity {
            // User is still walking — reset activity tracker
            stepCountAtLastActivity = currentSteps
            lastActivityTime = Date()
        } else {
            // Check if inactive for too long
            let inactiveDuration = Date().timeIntervalSince(lastActivityTime)
            if inactiveDuration >= inactivityThreshold {
                autoEndWalk(reason: .inactivity)
            }
        }
    }

    /// Auto-end the walk due to inactivity or time limit
    private func autoEndWalk(reason: AutoEndReason) {
        guard isWalking, !isEndingWalk else { return }

        Task {
            // For inactivity, use the last activity time as the effective end time
            // This gives accurate walk duration (not inflated by forgotten time)
            if reason == .inactivity {
                // The endWalk method will use the current time, but the walk data
                // will still be meaningful because steps stopped accumulating
                print("[WalkSessionManager] Auto-ending walk due to inactivity. Last activity: \(lastActivityTime)")
                NotificationManager.shared.sendWalkAutoEndedNotification(reason: .inactivity)
            } else {
                print("[WalkSessionManager] Auto-ending walk due to hard time limit")
                NotificationManager.shared.sendWalkAutoEndedNotification(reason: .timeLimit)
            }

            _ = await endWalk()
        }
    }

    /// Get expected duration in seconds for walk reminder scheduling
    private func getExpectedDurationSeconds(mode: WalkMode, intervalProgram: IntervalProgram?, customInterval: CustomIntervalConfig?) -> Int? {
        switch mode {
        case .free:
            return nil // No expected duration for quick walk
        case .interval:
            if let program = intervalProgram {
                return program.duration * 60
            } else if let custom = customInterval {
                return custom.totalMinutes * 60
            }
            return 20 * 60 // Default 20 minutes
        case .fatBurn:
            // Fat burn typically uses custom interval configs
            if let custom = customInterval {
                return custom.totalMinutes * 60
            }
            return 20 * 60 // Default 20 minutes
        case .postMeal:
            return Self.postMealDurationSeconds
        }
    }

    // MARK: - Interval Support

    var totalCycles: Int {
        guard let phases = activePhases else { return 0 }
        return phases.filter { $0.type == .fast }.count
    }

    var currentCycleIndex: Int {
        guard let phases = activePhases,
              let _ = getCurrentIntervalPhase() else { return 0 }
        let fastPhases = phases.filter { $0.type == .fast }
        let started = fastPhases.filter { elapsedSeconds >= $0.startOffset }.count
        return max(0, started - 1)
    }

    var completedCycles: Int {
        guard let phases = activePhases else { return 0 }
        let slowPhases = phases.filter { $0.type == .slow }
        return slowPhases.filter { elapsedSeconds >= $0.startOffset + $0.durationSeconds }.count
    }

    var activePhases: [IntervalPhase]? {
        if let program = currentIntervalProgram {
            return program.phases
        } else if let custom = currentCustomInterval {
            return custom.phases
        }
        return nil
    }

    func getCurrentIntervalPhase() -> IntervalPhase? {
        guard let phases = activePhases else { return nil }

        for phase in phases.reversed() {
            if elapsedSeconds >= phase.startOffset {
                return phase
            }
        }
        return phases.first
    }

    func getNextIntervalPhase() -> IntervalPhase? {
        guard let phases = activePhases,
              let currentPhase = getCurrentIntervalPhase() else { return nil }

        guard let currentIndex = phases.firstIndex(where: { $0.id == currentPhase.id }),
              currentIndex + 1 < phases.count else { return nil }

        return phases[currentIndex + 1]
    }

    func getSecondsRemainingInPhase() -> Int {
        guard let currentPhase = getCurrentIntervalPhase() else { return 0 }
        let phaseEnd = currentPhase.startOffset + currentPhase.durationSeconds
        return max(0, phaseEnd - elapsedSeconds)
    }

    private func getCurrentIntervalPhaseTypeLabel() -> String? {
        guard let currentPhase = getCurrentIntervalPhase() else { return nil }
        switch currentPhase.type {
        case .warmup:   return "WARM UP"
        case .fast:     return "FAST"
        case .slow:     return "SLOW"
        case .cooldown: return "COOL DOWN"
        }
    }

    private func getCurrentIntervalPhaseEndDate() -> Date? {
        guard let start = startTime,
              let currentPhase = getCurrentIntervalPhase() else { return nil }
        let phaseEnd = currentPhase.startOffset + currentPhase.durationSeconds
        // Account for any accumulated pause time so Live Activity stays in sync
        return start.addingTimeInterval(TimeInterval(phaseEnd) + totalPausedDuration)
    }

    private func shouldAutoEndInterval() -> Bool {
        guard isWalking,
              !isEndingWalk,
              currentMode == .interval,
              let phases = activePhases,
              let lastPhase = phases.last else { return false }
        let totalSeconds = lastPhase.startOffset + lastPhase.durationSeconds
        return elapsedSeconds >= totalSeconds
    }

    // MARK: - State Persistence

    private struct SavedWalkState: Codable {
        let startTime: Date
        let mode: WalkMode
        let intervalProgram: IntervalProgram?
        let totalPausedDuration: TimeInterval
        let isPaused: Bool
        let pauseTime: Date?
        let currentSteps: Int
        let currentDistance: Double
    }

    func saveStateIfNeeded() {
        guard isWalking, let start = startTime else {
            clearSavedState()
            return
        }

        let state = SavedWalkState(
            startTime: start,
            mode: currentMode,
            intervalProgram: currentIntervalProgram,
            totalPausedDuration: totalPausedDuration,
            isPaused: isPaused,
            pauseTime: pauseTime,
            currentSteps: currentSteps,
            currentDistance: currentDistance
        )

        if let data = try? JSONEncoder().encode(state) {
            UserDefaults.standard.set(data, forKey: Self.savedStateKey)
        }

        beginBackgroundTaskIfNeeded()
    }

    /// Cleans up any orphaned walk state left over from a previous process.
    /// Called on app launch — does NOT auto-resume; the user always starts fresh.
    func cleanupOrphanedState() {
        guard !isWalking else { return }

        if UserDefaults.standard.data(forKey: Self.savedStateKey) != nil {
            clearSavedState()
        }

        // End any lingering Live Activity from a previous session
        LiveActivityManager.shared.endActivity()
    }

    private func clearSavedState() {
        UserDefaults.standard.removeObject(forKey: Self.savedStateKey)
    }

    // MARK: - Watch Callbacks

    private func setupWatchCallbacks() {
        // Scenario 2: Watch starts walk → iPhone follows
        watchConnectivity.onWorkoutStartedOnWatch = { [weak self] walkId, modeRaw, intervalRaw in
            self?.handleWatchWorkoutStarted(walkId: walkId, modeRaw: modeRaw, intervalRaw: intervalRaw)
        }

        // Watch pauses walk → iPhone follows
        watchConnectivity.onWorkoutPausedOnWatch = { [weak self] in
            self?.handleWatchWorkoutPaused()
        }

        // Watch resumes walk → iPhone follows
        watchConnectivity.onWorkoutResumedOnWatch = { [weak self] in
            self?.handleWatchWorkoutResumed()
        }

        // Scenario 4: Watch ends walk → iPhone stops tracking
        watchConnectivity.onWorkoutEndedOnWatch = { [weak self] summary in
            self?.handleWatchWorkoutEnded(summary)
        }

        // Watch error
        watchConnectivity.onWatchError = { [weak self] error in
            print("Watch workout error: \(error)")
            _ = self // Suppress unused warning
        }
    }

    private func handleWatchWorkoutPaused() {
        guard isWalking, !isPaused else { return }
        pauseWalkInternal()
    }

    private func handleWatchWorkoutResumed() {
        guard isWalking, isPaused else { return }
        resumeWalkInternal()
    }

    private func handleWatchWorkoutStarted(walkId: UUID, modeRaw: String?, intervalRaw: String?) {
        guard !isWalking else { return }

        // Start iPhone tracking to complement Watch
        let mode = WalkMode(rawValue: modeRaw ?? "") ?? .free
        let intervalProgram = IntervalProgram(rawValue: intervalRaw ?? "")
        startWalk(mode: mode, intervalProgram: intervalProgram, walkId: walkId)

    }

    private func handleWatchWorkoutEnded(_ watchSummary: WorkoutSummaryData) {
        // Ensure any live activity is dismissed even if iPhone wasn't actively tracking.
        LiveActivityManager.shared.endActivity()
        if isWalking {
            // Scenario A: Watch ended while iPhone was still tracking — end iPhone walk
            Task {
                if await endWalk() != nil {
                    self.enhanceCompletedWalkWithWatchData(summary: watchSummary)
                }

            }
        } else if completedWalk?.id == watchSummary.walkId {
            // Scenario B: iPhone already ended this walk — enhance with Watch data (no duplicate)
            enhanceCompletedWalkWithWatchData(summary: watchSummary)
        } else {
            // Scenario C: iPhone wasn't tracking — create walk from Watch data alone
            // First check if this walk was already saved (prevents duplicate creation)
            if PersistenceManager.shared.loadTrackedWalk(by: watchSummary.walkId) != nil {
                // Walk already exists — just enhance it with Watch data
                enhanceCompletedWalkWithWatchData(summary: watchSummary)
                return
            }

            let duration = Int(watchSummary.totalSeconds) / 60

            let mode = WalkMode(rawValue: watchSummary.modeRaw ?? "") ?? .free
            let intervalProgram = IntervalProgram(rawValue: watchSummary.intervalProgramRaw ?? "")

            let walk = TrackedWalk(
                id: watchSummary.walkId,
                startTime: watchSummary.startTime,
                endTime: watchSummary.endTime,
                durationMinutes: duration,
                steps: watchSummary.totalSteps,
                distanceMeters: watchSummary.totalDistance,
                mode: mode,
                intervalProgram: intervalProgram,
                intervalCompleted: nil,
                routeCoordinates: [],
                heartRateAvg: watchSummary.averageHeartRate,
                heartRateMax: watchSummary.maxHeartRate,
                activeCalories: watchSummary.totalActiveCalories
            )

            PersistenceManager.shared.saveTrackedWalk(walk)
            completedWalk = walk

            // Stop Live Activity
            LiveActivityManager.shared.endActivity()
        }
    }

    /// Enhance the completed walk with Watch-provided health data (heart rate, calories).
    /// Updates both the in-memory `completedWalk` and PersistenceManager if already saved.
    private func enhanceCompletedWalkWithWatchData(summary: WorkoutSummaryData) {
        // Update in-memory completed walk
        if var walk = completedWalk, walk.id == summary.walkId {
            walk.heartRateAvg = summary.averageHeartRate
            walk.heartRateMax = summary.maxHeartRate
            walk.activeCalories = summary.totalActiveCalories
            if let mode = WalkMode(rawValue: summary.modeRaw ?? "") {
                walk.mode = mode
            }
            if let intervalProgram = IntervalProgram(rawValue: summary.intervalProgramRaw ?? "") {
                walk.intervalProgram = intervalProgram
            }
            completedWalk = walk
        }

        // Also update in PersistenceManager if already saved
        if var savedWalk = PersistenceManager.shared.loadTrackedWalk(by: summary.walkId) {
            savedWalk.heartRateAvg = summary.averageHeartRate
            savedWalk.heartRateMax = summary.maxHeartRate
            savedWalk.activeCalories = summary.totalActiveCalories
            if let mode = WalkMode(rawValue: summary.modeRaw ?? "") {
                savedWalk.mode = mode
            }
            if let intervalProgram = IntervalProgram(rawValue: summary.intervalProgramRaw ?? "") {
                savedWalk.intervalProgram = intervalProgram
            }
            PersistenceManager.shared.updateTrackedWalk(savedWalk)
        }
    }

    // MARK: - Background Task

    private func beginBackgroundTaskIfNeeded() {
        guard backgroundTaskID == .invalid else { return }
        backgroundTaskID = UIApplication.shared.beginBackgroundTask { [weak self] in
            self?.endBackgroundTask()
        }
    }

    private func endBackgroundTask() {
        guard backgroundTaskID != .invalid else { return }
        UIApplication.shared.endBackgroundTask(backgroundTaskID)
        backgroundTaskID = .invalid
    }
}

// MARK: - CLLocationManagerDelegate

extension WalkSessionManager: CLLocationManagerDelegate {
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard isWalking, !isPaused, let location = locations.last else { return }

        // Anti-cheat: speed check with cooldown
        if location.speed > maxSpeedMPS {
            if speedViolationTime == nil {
                speedViolationTime = Date()
            }
            return
        }

        // Enforce speed cooldown — ignore locations during cooldown
        if let violationTime = speedViolationTime,
           Date().timeIntervalSince(violationTime) < speedCooldown {
            return
        }
        speedViolationTime = nil

        currentLocation = location.coordinate

        // Only record high-accuracy locations for route
        if location.horizontalAccuracy < 50 {
            routeCoordinates.append(location.coordinate)
        }

        // Update distance
        if routeCoordinates.count > 1 {
            let lastIndex = routeCoordinates.count - 1
            let lastLocation = CLLocation(latitude: routeCoordinates[lastIndex - 1].latitude,
                                          longitude: routeCoordinates[lastIndex - 1].longitude)
            let newLocation = CLLocation(latitude: location.coordinate.latitude,
                                         longitude: location.coordinate.longitude)
            currentDistance += newLocation.distance(from: lastLocation)
        }

        // Check Eco-Track
        checkEcoTrack()
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("Location manager error: \(error.localizedDescription)")
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        locationAuthorizationStatus = manager.authorizationStatus

        switch manager.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            // If a walk is active but location updates haven't started yet, start them now
            if isWalking && !isPaused {
                locationManager.startUpdatingLocation()
            }
        case .denied, .restricted:
            break
        case .notDetermined:
            break
        @unknown default:
            break
        }
    }
}
