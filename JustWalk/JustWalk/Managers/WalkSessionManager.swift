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

@Observable
class WalkSessionManager: NSObject, ObservableObject {
    static let shared = WalkSessionManager()

    private let locationManager = CLLocationManager()
    private var healthKitManager = HealthKitManager.shared
    private let pedometer = CMPedometer()
    private let watchConnectivity = PhoneConnectivityManager.shared
    private var stepsBeforePause: Int = 0

    // State
    var isWalking: Bool = false
    var isPaused: Bool = false
    var currentMode: WalkMode = .free
    var currentIntervalProgram: IntervalProgram?
    var currentCustomInterval: CustomIntervalConfig?
    var currentWalkId: UUID?

    // Tracking data
    var startTime: Date?
    var pauseTime: Date?
    var totalPausedDuration: TimeInterval = 0
    var routeCoordinates: [CLLocationCoordinate2D] = []
    var currentLocation: CLLocationCoordinate2D?
    var elapsedSeconds: Int = 0
    var currentSteps: Int = 0
    var currentDistance: Double = 0 // meters

    // Eco-Track state
    private var screenLockedTime: Date?
    private var isEcoTrackActive: Bool = false
    private let ecoTrackThreshold: TimeInterval = 300 // 5 minutes

    // Walk completion
    var completedWalk: TrackedWalk?

    // Cross-device state
    private var isEndingWalk = false
    var isWatchInitiated: Bool = false

    // Anti-cheat
    private var lastStepCount: Int = 0
    private var zeroStepsStartTime: Date?
    private var ghostMinutesDetected: Int = 0
    private let ghostCheckThreshold: TimeInterval = 300 // 5 minutes
    private let maxSpeedMPS: Double = 6.7 // ~15 mph
    private var speedViolationTime: Date?
    private let speedCooldown: TimeInterval = 30 // 30-second cooldown after speed violation

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

    var locationAuthorizationStatus: CLAuthorizationStatus = .notDetermined

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

        // Start Live Activity
        LiveActivityManager.shared.startActivity(mode: mode, intervalProgram: intervalProgram)

        // Start Watch workout silently if available (only when iPhone-initiated)
        if !isWatchInitiated && watchConnectivity.canCommunicateWithWatch {
            watchConnectivity.startWorkoutOnWatch(walkId: id)
        }
    }

    func pauseWalk() {
        guard isWalking, !isPaused else { return }
        isPaused = true
        pauseTime = Date()
        JustWalkHaptics.walkPause()
        timer?.invalidate()
        locationManager.stopUpdatingLocation()
        stepsBeforePause = currentSteps
        stopPedometer()

        LiveActivityManager.shared.updatePaused(true)
        watchConnectivity.pauseWorkoutOnWatch()
    }

    func resumeWalk() {
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

        LiveActivityManager.shared.updatePaused(false)
        watchConnectivity.resumeWorkoutOnWatch()
    }

    func endWalk() async -> TrackedWalk? {
        guard isWalking, !isEndingWalk, let start = startTime else { return nil }
        isEndingWalk = true
        defer { isEndingWalk = false }

        timer?.invalidate()
        locationManager.stopUpdatingLocation()
        stopPedometer()

        let end = Date()
        let duration = Int(end.timeIntervalSince(start) - totalPausedDuration) / 60

        // Use pedometer step count (real-time, no delay) with HealthKit fallback
        let steps = currentSteps > 0 ? currentSteps : await healthKitManager.fetchStepsDuring(start: start, end: end)
        let distance = await healthKitManager.fetchDistanceDuring(start: start, end: end)

        let intervalDuration = currentIntervalProgram?.duration ?? currentCustomInterval?.totalMinutes
        let isInterval = currentIntervalProgram != nil || currentCustomInterval != nil
        let intervalCompleted = isInterval && duration >= (intervalDuration ?? 0)

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
            customIntervalConfig: currentCustomInterval
        )

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

        // Update Live Activity every 5 seconds (reduces battery drain)
        if elapsedSeconds % 5 == 0 {
            LiveActivityManager.shared.updateProgress(
                elapsedSeconds: elapsedSeconds,
                steps: currentSteps,
                distance: currentDistance
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
        watchConnectivity.onWorkoutStartedOnWatch = { [weak self] walkId in
            self?.handleWatchWorkoutStarted(walkId: walkId)
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

    private func handleWatchWorkoutStarted(walkId: UUID) {
        guard !isWalking else { return }

        // Start iPhone tracking to complement Watch
        startWalk(mode: .free, walkId: walkId)

    }

    private func handleWatchWorkoutEnded(_ watchSummary: WorkoutSummaryData) {
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
            let duration = Int(watchSummary.totalSeconds) / 60

            let walk = TrackedWalk(
                id: watchSummary.walkId,
                startTime: watchSummary.startTime,
                endTime: watchSummary.endTime,
                durationMinutes: duration,
                steps: watchSummary.totalSteps,
                distanceMeters: watchSummary.totalDistance,
                mode: .free,
                intervalProgram: nil,
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
            completedWalk = walk
        }

        // Also update in PersistenceManager if already saved
        if var savedWalk = PersistenceManager.shared.loadTrackedWalk(by: summary.walkId) {
            savedWalk.heartRateAvg = summary.averageHeartRate
            savedWalk.heartRateMax = summary.maxHeartRate
            savedWalk.activeCalories = summary.totalActiveCalories
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
            speedViolationTime = Date()
            pauseWalk()
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
