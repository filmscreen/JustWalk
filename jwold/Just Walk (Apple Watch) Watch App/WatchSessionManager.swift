//
//  WatchSessionManager.swift
//  Just Walk Watch App
//
//  Created by Just Walk Team.
//

import Foundation
import HealthKit
import SwiftUI
import WatchKit
import Combine
import CoreMotion // For real-time step counting during workouts
// WatchConnectivity removed - Watch and iPhone are independent
// CoreLocation/MapKit removed - route maps on iPhone only
import UserNotifications


enum WalkMode {
    case interval
    case classic
    case postMeal
}

enum WatchIWTPhase {
    case idle
    case warmup
    case brisk
    case slow
    case cooldown
    case classic // New single phase for Classic Walk
    case postMeal // Post-meal 10-minute countdown
    case completed
    case summary // New summary phase

    var title: String {
        switch self {
        case .idle: return "Ready"
        case .warmup: return "Warmup"
        case .brisk: return "Brisk Walk"
        case .slow: return "Slow Walk"
        case .cooldown: return "Cooldown"
        case .classic: return "Classic Walk"
        case .postMeal: return "Post-Meal Walk"
        case .completed: return "Done"
        case .summary: return "Summary"
        }
    }

    var color: Color {
        switch self {
        case .idle: return .gray
        case .warmup: return .orange
        case .brisk: return .green
        case .slow: return .blue
        case .cooldown: return .purple
        case .classic: return .cyan // Distinct cyan for Classic
        case .postMeal: return .orange // Post-meal orange
        case .completed: return .yellow
        case .summary: return .white
        }
    }
}

@MainActor
class WatchSessionManager: NSObject, ObservableObject, HKWorkoutSessionDelegate, HKLiveWorkoutBuilderDelegate {
    @Published var currentPhase: WatchIWTPhase = .idle
    @Published var timeRemaining: TimeInterval = 0
    @Published var currentInterval: Int = 1
    @Published var totalIntervals: Int = 5

    // Remote control
    @Published var remoteStartRequested: Bool = false

    // Pro subscription status (synced from iPhone via App Group)
    @Published var isPro: Bool = {
        #if DEBUG
        return UserDefaults(suiteName: "group.com.onworldtech.JustWalk")?.bool(forKey: "debugProOverride") ?? false
        #else
        return false
        #endif
    }()

    /// Selected Power Walk duration in minutes (persisted)
    @Published var selectedPowerWalkMinutes: Int = 30 {
        didSet {
            UserDefaults.standard.set(selectedPowerWalkMinutes, forKey: "powerWalk.selectedMinutes")
        }
    }

    // session mode
    var sessionMode: WalkMode = .interval

    // Walk Goal
    @Published var currentGoal: WalkGoal = .none

    // Metrics
    @Published var currentHeartRate: Double = 0
    @Published var activeCalories: Double = 0
    @Published var distance: Double = 0

    @Published var sessionSteps: Int = 0

    // Timer State
    @Published var isPaused: Bool = false
    private var pauseStartDate: Date?

    // MARK: - Step Milestone Tracking

    /// Last milestone reached (e.g., 1000, 2000, 3000...)
    private var lastMilestone: Int = 0

    /// Track if daily step goal was already celebrated this session
    private var goalCelebratedThisSession: Bool = false

    /// Track if workout-specific goal was already celebrated this session
    private var workoutGoalCelebratedThisSession: Bool = false

    // MARK: - Phase Haptic Tracking

    /// Track if pre-warning haptic has fired for current phase
    private var preWarningFired: Bool = false

    /// Track if halfway haptic has fired for current phase
    private var halfwayFired: Bool = false

    /// Current phase duration (for halfway calculation)
    @Published var currentPhaseDuration: TimeInterval = 0

    // MARK: - Summary Data (Captured at workout end)

    /// Steps before this workout started (to calculate contribution)
    @Published var stepsBeforeWorkout: Int = 0

    /// Whether the goal was already met before this workout
    @Published var goalWasMetBeforeWorkout: Bool = false

    /// Phases completed (for Power Walk - tracks completed intervals)
    @Published var phasesCompleted: Int = 0

    private var heartRateSamples: [Double] = []

    var averageHeartRate: Double {
        guard !heartRateSamples.isEmpty else { return 0 }
        let sum = heartRateSamples.reduce(0, +)
        return sum / Double(heartRateSamples.count)
    }

    // MARK: - Goal Progress Tracking

    /// Progress towards the current goal (0.0 to 1.0+)
    var goalProgress: Double {
        switch currentGoal.type {
        case .none:
            return 0
        case .time:
            guard let startTime = sessionStartTime else { return 0 }
            let elapsed = Date().timeIntervalSince(startTime)
            return min(1.0, elapsed / (currentGoal.target * 60))
        case .distance:
            return min(1.0, distance / currentGoal.target)
        case .steps:
            return min(1.0, Double(sessionSteps) / currentGoal.target)
        }
    }

    /// Whether the current goal has been reached
    var isGoalReached: Bool {
        currentGoal.type != .none && goalProgress >= 1.0
    }

    /// Timer progress (0.0 to 1.0) for phases with a fixed duration (e.g., post-meal)
    var timerProgress: Double {
        guard currentPhaseDuration > 0 else { return 0 }
        let elapsed = currentPhaseDuration - timeRemaining
        return min(1.0, max(0, elapsed / currentPhaseDuration))
    }

    /// Next phase in the interval sequence (for countdown overlay)
    var nextPhase: WatchIWTPhase? {
        switch currentPhase {
        case .warmup: return .brisk
        case .brisk: return .slow
        case .slow:
            if currentInterval < totalIntervals {
                return .brisk
            } else {
                return .cooldown
            }
        case .cooldown: return .completed
        default: return nil
        }
    }

    // HealthKit Workout Session
    private let healthStore = HKHealthStore()
    private var workoutSession: HKWorkoutSession?
    private var builder: HKLiveWorkoutBuilder?

    // MARK: - CMPedometer for Real-Time Workout Steps

    /// CMPedometer provides 1-second step updates during workouts
    /// More responsive than HKLiveWorkoutBuilder which batches data
    private let workoutPedometer = CMPedometer()

    /// Steps counted by pedometer during current workout (separate from healthkit steps)
    private var pedometerSessionSteps: Int = 0
    
    private var timerTask: Task<Void, Never>?
    private var heartbeatTask: Task<Void, Never>?
    @Published var phaseEndTime: Date?
    @Published var sessionStartTime: Date?
    @Published var finalDuration: TimeInterval = 0
    
    // Durations (in seconds)
    private let warmupDuration: TimeInterval = 120 // 2 min
    private let intervalDuration: TimeInterval = 180 // 3 min
    private let cooldownDuration: TimeInterval = 300 // 5 min

    // MARK: - Robust Background Timing

    /// Scheduled phase end times for reliable background execution
    /// Key: phase identifier, Value: absolute Date when phase ends
    private var scheduledPhaseEndTimes: [String: Date] = [:]

    /// Last time we checked for phase transitions (prevent duplicate haptics)
    private var lastPhaseTransitionCheck: Date = .distantPast

    static let shared = WatchSessionManager()
    
    override init() {
        super.init()

        // Pro status is read from App Group (synced from iPhone debug toggle)
        // No hardcoding - respects the debug override setting

        // Load cached Power Walk duration (default 30 minutes)
        let savedMinutes = UserDefaults.standard.integer(forKey: "powerWalk.selectedMinutes")
        selectedPowerWalkMinutes = savedMinutes > 0 ? savedMinutes : 30

        // Watch Connectivity removed - devices are independent

        // Request notification permission for phase transition alerts
        requestNotificationPermission()
    }

    // MARK: - Pro Status Refresh

    /// Refresh Pro status from App Group (call when app becomes active)
    func refreshProStatus() {
        #if DEBUG
        let newStatus = UserDefaults(suiteName: "group.com.onworldtech.JustWalk")?.bool(forKey: "debugProOverride") ?? false
        if isPro != newStatus {
            isPro = newStatus
            print("⌚️ Pro status refreshed: \(newStatus)")
        }
        #endif
    }

    // MARK: - Notification Permission

    private func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { granted, error in
            if granted {
                print("✅ Watch notification permission granted")
            } else if let error = error {
                print("❌ Watch notification permission error: \(error.localizedDescription)")
            }
        }
    }
    
    /// Perform background refresh of daily stats
    func performBackgroundRefresh() async {
        // Fetch latest stats from HealthManager and update complications
        let steps = await MainActor.run { WatchHealthManager.shared.todaySteps }
        print("Background refresh performed. Steps: \(steps)")
        
        // Force complication update
        WatchHealthManager.shared.forceComplicationUpdate()
    }
    
    func startSession(mode: WalkMode, goal: WalkGoal = .none) {
        self.sessionMode = mode
        self.currentGoal = goal
        self.sessionStartTime = Date()
        self.finalDuration = 0

        // Reset step milestone tracking
        self.lastMilestone = 0
        self.goalCelebratedThisSession = WatchHealthManager.shared.todaySteps >= WatchHealthManager.shared.stepGoal
        self.workoutGoalCelebratedThisSession = false

        // Capture pre-workout state for summary calculations
        self.stepsBeforeWorkout = WatchHealthManager.shared.todaySteps
        self.goalWasMetBeforeWorkout = WatchHealthManager.shared.todaySteps >= WatchHealthManager.shared.stepGoal
        self.phasesCompleted = 0

        print("⌚️ Starting \(mode) session with goal: \(goal.displayString)")

        // SET PHASE FIRST - triggers view transition immediately
        // This must happen BEFORE HealthKit init to prevent UI freeze
        if mode == .interval {
            startPhase(.warmup)
        } else if mode == .postMeal {
            // Post-meal mode: 10-minute countdown that auto-completes
            startPhase(.postMeal)
        } else {
            // Classic mode just starts immediately in the classic phase with no timer limits
            startPhase(.classic)
        }

        // THEN start HealthKit session asynchronously
        // GPS/HealthKit initialization can block for 1-2+ seconds
        Task {
            await startWorkoutSessionAsync()
        }
    }
    
    func skipToNextPhase() {
        transitionToNextPhase()
    }
    
    func stopSession() {
        if let start = sessionStartTime {
            finalDuration = Date().timeIntervalSince(start)
        }
        timerTask?.cancel()
        timerTask = nil
        endWorkoutSession()
        currentPhase = .summary // Transition to summary instead of idle
    }
    
    func pauseSession() {
        // Only pause if not already paused
        guard !isPaused else { return }
        
        isPaused = true
        pauseStartDate = Date()
        
        // Stop the timer while paused
        timerTask?.cancel()
        timerTask = nil
        
        workoutSession?.pause()
    }
    
    func resumeSession() {
        guard isPaused else { return }

        if let pauseStart = pauseStartDate {
            let pauseDuration = Date().timeIntervalSince(pauseStart)

            // Adjust phase end time for intervals
            if let end = phaseEndTime {
                phaseEndTime = end.addingTimeInterval(pauseDuration)
            }

            // Adjust session start time for flow duration
            if let start = sessionStartTime {
                sessionStartTime = start.addingTimeInterval(pauseDuration)
            }

            // Also adjust all scheduled phase end times
            for key in scheduledPhaseEndTimes.keys {
                if let oldTime = scheduledPhaseEndTimes[key] {
                    scheduledPhaseEndTimes[key] = oldTime.addingTimeInterval(pauseDuration)
                }
            }
        }

        isPaused = false
        pauseStartDate = nil

        // Restart the timer
        startTimer()

        workoutSession?.resume()
    }
    
    func closeSummary() {
        currentPhase = .idle
        // Reset metrics
        currentHeartRate = 0
        activeCalories = 0
        distance = 0
        sessionSteps = 0
        pedometerSessionSteps = 0 // Reset CMPedometer workout steps
        heartRateSamples = []

        // Reset goal
        currentGoal = .none

        // Reset summary data
        stepsBeforeWorkout = 0
        goalWasMetBeforeWorkout = false
        phasesCompleted = 0

        // AGGRESSIVE: Force complication update after session ends
        // This ensures complications reflect the new step count immediately
        WatchHealthManager.shared.forceComplicationUpdate()
    }
    
    // MARK: - Workout Session Management
    
    /// Async version of workout session initialization
    /// Called off the main synchronous path to prevent UI freeze
    private func startWorkoutSessionAsync() async {
        let configuration = HKWorkoutConfiguration()
        configuration.activityType = .walking
        // GPS Route Recording: .outdoor enables automatic route collection via HKLiveWorkoutBuilder
        configuration.locationType = .outdoor

        do {
            workoutSession = try HKWorkoutSession(healthStore: healthStore, configuration: configuration)
            builder = workoutSession?.associatedWorkoutBuilder()

            workoutSession?.delegate = self
            builder?.delegate = self

            builder?.dataSource = HKLiveWorkoutDataSource(healthStore: healthStore, workoutConfiguration: configuration)

            // Setup data collection
            let dataTypes: Set<HKQuantityType> = [
                HKQuantityType.quantityType(forIdentifier: .heartRate)!,
                HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned)!,
                HKQuantityType.quantityType(forIdentifier: .distanceWalkingRunning)!,
                HKQuantityType.quantityType(forIdentifier: .stepCount)!
            ]

            for type in dataTypes {
                builder?.dataSource?.enableCollection(for: type, predicate: nil)
            }

            workoutSession?.startActivity(with: Date())
            builder?.beginCollection(withStart: Date()) { success, error in
                if let error = error {
                    print("Error starting collection: \(error)")
                }
            }

            // Start CMPedometer for real-time step updates (1-second intervals)
            // This runs alongside HKLiveWorkoutBuilder for responsive UI
            // Already on MainActor since class is @MainActor
            startWorkoutPedometer()

        } catch {
            print("Failed to start workout session: \(error)")
        }
    }
    
    private func endWorkoutSession() {
        // Stop CMPedometer first
        stopWorkoutPedometer()

        let builderToEnd = self.builder
        workoutSession?.end()

        Task {
            // End collection
            await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
                builderToEnd?.endCollection(withEnd: Date()) { _, _ in
                    continuation.resume()
                }
            }

            // Finish workout
            _ = await withCheckedContinuation { (continuation: CheckedContinuation<HKWorkout?, Never>) in
                builderToEnd?.finishWorkout { workout, _ in
                    continuation.resume(returning: workout)
                }
            }

            print("Workout finished")
        }
    }

    // MARK: - CMPedometer for Real-Time Steps

    /// Start CMPedometer alongside HKWorkoutSession for real-time step updates
    /// CMPedometer updates every second vs HealthKit's batched delivery
    private func startWorkoutPedometer() {
        guard CMPedometer.isStepCountingAvailable() else {
            print("⌚️ CMPedometer step counting not available")
            return
        }

        // Reset pedometer session steps
        pedometerSessionSteps = 0

        let now = Date()
        workoutPedometer.startUpdates(from: now) { [weak self] data, error in
            guard let data = data, error == nil else {
                if let error = error {
                    print("⌚️ Pedometer error: \(error.localizedDescription)")
                }
                return
            }

            Task { @MainActor [weak self] in
                guard let self = self else { return }

                // Real-time steps just for this workout session
                self.pedometerSessionSteps = data.numberOfSteps.intValue

                // Hybrid tracking: use higher value between pedometer and HealthKit
                // Pedometer is more real-time, HealthKit is authoritative
                self.sessionSteps = max(self.pedometerSessionSteps, self.sessionSteps)

                // Check for step milestones and play haptics
                self.checkStepMilestones()
            }
        }

        print("⌚️ Workout pedometer started for real-time step updates")
    }

    // MARK: - Step Milestone Haptics

    /// Check for step milestones and play haptics
    /// Called whenever sessionSteps updates
    func checkStepMilestones() {
        // Don't fire haptics while paused
        guard !isPaused else { return }

        let steps = sessionSteps
        let currentMilestone = (steps / 1000) * 1000

        // Check for milestone crossing
        if currentMilestone > lastMilestone && currentMilestone > 0 {
            lastMilestone = currentMilestone

            // Stronger haptic for 5,000 step milestones
            if currentMilestone % 5000 == 0 {
                playStrongerMilestoneHaptic()
            } else {
                // Standard double tap for 1,000 step milestones
                playMilestoneHaptic()
            }
        }

        // Check for daily step goal completion
        let totalSteps = WatchHealthManager.shared.todaySteps
        let goal = WatchHealthManager.shared.stepGoal

        if totalSteps >= goal && !goalCelebratedThisSession {
            goalCelebratedThisSession = true
            playGoalCompletedHaptic()
        }

        // Check for workout-specific goal completion
        checkWorkoutGoalCompletion()
    }

    /// Check if the workout-specific goal has been reached and celebrate
    private func checkWorkoutGoalCompletion() {
        guard !workoutGoalCelebratedThisSession else { return }
        guard currentGoal.type != .none else { return }

        if isGoalReached {
            workoutGoalCelebratedThisSession = true
            playWorkoutGoalReachedCelebration()
        }
    }

    /// Strong celebration haptic when workout goal is reached
    /// User can continue walking after goal is reached
    func playWorkoutGoalReachedCelebration() {
        let device = WKInterfaceDevice.current()
        Task {
            // Strong success pattern for workout goal
            device.play(.success)
            try? await Task.sleep(nanoseconds: 200_000_000)

            // Triple notification burst
            for _ in 0..<3 {
                device.play(.notification)
                try? await Task.sleep(nanoseconds: 120_000_000)
            }

            try? await Task.sleep(nanoseconds: 200_000_000)
            device.play(.success)
            try? await Task.sleep(nanoseconds: 150_000_000)
            device.play(.success)

            print("🎉 Workout goal reached celebration played!")
        }
    }

    /// Double tap haptic for 1,000 step milestones
    private func playMilestoneHaptic() {
        let device = WKInterfaceDevice.current()
        Task {
            device.play(.notification)
            try? await Task.sleep(nanoseconds: 150_000_000)
            device.play(.notification)
        }
    }

    /// Stronger haptic for 5,000 step milestones
    private func playStrongerMilestoneHaptic() {
        let device = WKInterfaceDevice.current()
        Task {
            // Triple tap with success for major milestones
            device.play(.success)
            try? await Task.sleep(nanoseconds: 150_000_000)
            device.play(.notification)
            try? await Task.sleep(nanoseconds: 100_000_000)
            device.play(.notification)
            try? await Task.sleep(nanoseconds: 100_000_000)
            device.play(.success)
        }
    }

    /// Strong celebration haptic for goal completion
    private func playGoalCompletedHaptic() {
        let device = WKInterfaceDevice.current()
        Task {
            // Victory pattern
            device.play(.success)
            try? await Task.sleep(nanoseconds: 150_000_000)

            for _ in 0..<3 {
                device.play(.notification)
                try? await Task.sleep(nanoseconds: 100_000_000)
            }

            try? await Task.sleep(nanoseconds: 150_000_000)
            device.play(.success)
        }
    }

    // MARK: - Pre-Warning Haptic

    /// Single firm tap 10 seconds before phase change
    /// Called from the view's time update handler
    func playPreWarningHaptic() {
        guard !preWarningFired else { return }
        preWarningFired = true

        WKInterfaceDevice.current().play(.notification)
    }

    // MARK: - Phase Halfway Haptic

    /// Single tap haptic at phase halfway point
    /// Skip for phases < 20 seconds (too close to pre-warning)
    func playPhaseHalfwayHaptic() {
        guard !halfwayFired else { return }
        guard currentPhaseDuration >= 20 else { return }
        halfwayFired = true

        WKInterfaceDevice.current().play(.notification)
    }

    /// Stop CMPedometer when workout ends
    private func stopWorkoutPedometer() {
        workoutPedometer.stopUpdates()
        print("⌚️ Workout pedometer stopped")
    }

    // MARK: - Phase Management

    private func startPhase(_ phase: WatchIWTPhase) {
        currentPhase = phase
        playHapticForPhase(phase)
        schedulePhaseNotification(for: phase)

        // Reset haptic flags for next phase
        preWarningFired = false
        halfwayFired = false

        var duration: TimeInterval = 0
        switch phase {
        case .warmup:
            duration = warmupDuration
        case .brisk, .slow:
            duration = intervalDuration
        case .cooldown:
            duration = cooldownDuration
        case .postMeal:
            duration = 600 // 10 minutes
        case .completed:
            currentPhaseDuration = 0
            timeRemaining = 0
            timerTask?.cancel()
            scheduledPhaseEndTimes.removeAll()
            endWorkoutSession()
            return
        case .classic:
            // Classic has no targeted end duration by default, it just runs until stopped
            duration = 0
        case .idle, .summary:
            return
        }

        // ROBUST TIMING: Store absolute end time for reliable background execution
        // This ensures phase transitions happen even if Task.sleep is delayed
        let endTime = Date().addingTimeInterval(duration)
        timeRemaining = duration
        currentPhaseDuration = duration
        phaseEndTime = endTime

        // Store in scheduled times for recovery after screen wake
        let phaseKey = "\(phase.title)_\(currentInterval)"
        scheduledPhaseEndTimes[phaseKey] = endTime

        print("⏱️ Phase \(phase.title) scheduled to end at \(endTime)")

        startTimer()
    }
    
    private func startTimer() {
        timerTask?.cancel()
        timerTask = Task { [weak self] in
            while !Task.isCancelled {
                // Update frequency - 0.5s for smooth UI updates
                try? await Task.sleep(nanoseconds: 500_000_000)
                guard !Task.isCancelled else { return }
                self?.tick()
            }
        }
    }

    private func tick() {
        guard let endTime = phaseEndTime else { return }

        let now = Date()
        let remaining = endTime.timeIntervalSince(now)

        // Update UI with remaining time
        self.timeRemaining = max(0, remaining)

        // Post-meal auto-complete: transition to summary when timer hits 0
        if sessionMode == .postMeal && remaining <= 0 {
            guard now.timeIntervalSince(lastPhaseTransitionCheck) > 1.0 else { return }
            lastPhaseTransitionCheck = now
            WKInterfaceDevice.current().play(.success)
            stopSession()
            return
        }

        // ROBUST TIMING: Check if phase should have ended (handles delayed wake-up)
        if sessionMode == .interval && remaining <= 0 {
            // Prevent duplicate transitions within 1 second
            guard now.timeIntervalSince(lastPhaseTransitionCheck) > 1.0 else { return }
            lastPhaseTransitionCheck = now

            // Check if we missed multiple phases (long sleep)
            catchUpMissedPhases()
        }
    }

    /// Catch up on any phases that were missed during screen sleep
    /// This ensures haptics fire and phases advance correctly even after long delays
    private func catchUpMissedPhases() {
        guard sessionMode == .interval else { return }
        guard let endTime = phaseEndTime else { return }

        let now = Date()

        // If current phase has ended, transition
        if now >= endTime {
            print("🔄 Catching up: Phase \(currentPhase.title) ended at \(endTime), now is \(now)")
            transitionToNextPhase()

            // Recursively check if we need to skip more phases
            // (e.g., if screen was off for 10+ minutes)
            if let newEndTime = phaseEndTime, now >= newEndTime {
                // Schedule another check shortly to avoid stack overflow
                Task { @MainActor [self] in
                    try? await Task.sleep(nanoseconds: 100_000_000) // 0.1s
                    self.catchUpMissedPhases()
                }
            }
        }
    }
    
    private func transitionToNextPhase() {
        switch currentPhase {
        case .warmup:
            currentInterval = 1
            startPhase(.brisk)

        case .brisk:
            startPhase(.slow)

        case .slow:
            // Track completed intervals for summary display
            phasesCompleted = currentInterval

            if currentInterval < totalIntervals {
                currentInterval += 1
                startPhase(.brisk)
            } else {
                startPhase(.cooldown)
            }

        case .cooldown:
            startPhase(.completed)

        default:
            // For interval mode, completion leads to stop -> summary
            stopSession()
        }
    }
    
    // MARK: - Delegates (Workout Session State Handling)
    
    nonisolated func workoutSession(_ workoutSession: HKWorkoutSession, didChangeTo toState: HKWorkoutSessionState, from fromState: HKWorkoutSessionState, date: Date) {
        print("🏃 Workout session state: \(fromState.rawValue) → \(toState.rawValue)")
        
        // Handle state changes to keep session alive
        Task { @MainActor in
            switch toState {
            case .running:
                print("✅ Workout session running - app will stay active")
            case .paused:
                print("⏸️ Workout session paused")
            case .ended:
                print("🛑 Workout session ended")
            case .stopped:
                print("⏹️ Workout session stopped")
            default:
                break
            }
        }
    }
    
    nonisolated func workoutSession(_ workoutSession: HKWorkoutSession, didFailWithError error: Error) {
        print("❌ Workout session failed: \(error.localizedDescription)")
        
        // Attempt to restart if session fails unexpectedly
        Task { @MainActor in
            // Log the error but don't auto-restart to avoid loops
            print("⚠️ Session error - user may need to restart walking session")
        }
    }
    
    nonisolated func workoutBuilder(_ workoutBuilder: HKLiveWorkoutBuilder, didCollectDataOf collectedTypes: Set<HKSampleType>) {
        for type in collectedTypes {
            guard let quantityType = type as? HKQuantityType else { continue }

            // Get statistics
            guard let statistics = workoutBuilder.statistics(for: quantityType) else { continue }

            Task { @MainActor [self] in
                let typeIdentifier = HKQuantityTypeIdentifier(rawValue: quantityType.identifier)
                switch typeIdentifier {
                case .heartRate:
                    let heartRateUnit = HKUnit.count().unitDivided(by: HKUnit.minute())
                    let value = statistics.mostRecentQuantity()?.doubleValue(for: heartRateUnit) ?? 0
                    self.currentHeartRate = value

                case .activeEnergyBurned:
                    let energyUnit = HKUnit.kilocalorie()
                    let value = statistics.sumQuantity()?.doubleValue(for: energyUnit) ?? 0
                    self.activeCalories = value

                case .distanceWalkingRunning:
                    // Currently showing miles
                     let mileUnit = HKUnit.mile()
                     let value = statistics.sumQuantity()?.doubleValue(for: mileUnit) ?? 0
                     if value > 0 {
                         self.distance = value
                     }

                case .stepCount:
                    let stepUnit = HKUnit.count()
                    let value = statistics.sumQuantity()?.doubleValue(for: stepUnit) ?? 0
                    // Preserve hybrid max - never decrease step count
                    self.sessionSteps = max(self.sessionSteps, Int(value))

                    // Fallback: If distance is 0 but we have steps, estimate it
                    // Approx 2.5 feet (0.762m) per step -> 0.000473 miles
                    if self.distance == 0 && self.sessionSteps > 0 {
                        self.distance = Double(self.sessionSteps) * 0.000473
                    }

                default:
                    break
                }

                // Track HR Samples
                if typeIdentifier == .heartRate && self.currentHeartRate > 0 {
                    self.heartRateSamples.append(self.currentHeartRate)
                }

                // Metrics are now tracked locally only
                // No WCSession sync needed
            }
        }
    }

    /// Called when health data arrives - provides redundant phase transition checking
    /// HealthKit delivers data reliably during HKWorkoutSession even when screen is dimmed
    private func checkPhaseTransitionOnHealthData() {
        guard sessionMode == .interval else { return }
        guard currentPhase != .idle && currentPhase != .summary && currentPhase != .completed else { return }
        guard let endTime = phaseEndTime else { return }

        let now = Date()

        // Check if current phase should have ended
        if now >= endTime {
            // Prevent duplicate transitions (only check every 2 seconds via this path)
            guard now.timeIntervalSince(lastPhaseTransitionCheck) > 2.0 else { return }

            print("📊 Health data triggered phase check - transitioning")
            catchUpMissedPhases()
        }
    }
    
    nonisolated func workoutBuilderDidCollectEvent(_ workoutBuilder: HKLiveWorkoutBuilder) {}
    
    // MARK: - Haptics (Simplified Phase Patterns)

    /// Play distinct haptic patterns for phase transitions
    /// Brisk = energetic (3 rapid taps), Easy = calm (2 slow taps)
    private func playHapticForPhase(_ phase: WatchIWTPhase) {
        let device = WKInterfaceDevice.current()

        Task {
            switch phase {
            case .brisk:
                // BRISK: 3 rapid strong taps (•••)
                // Energetic, urgent feel
                for _ in 0..<3 {
                    device.play(.notification)
                    try? await Task.sleep(nanoseconds: 100_000_000) // 100ms
                }

            case .slow:
                // EASY: 2 slow gentle taps (— —)
                // Calm, relief feel
                device.play(.directionDown)
                try? await Task.sleep(nanoseconds: 400_000_000) // 400ms
                device.play(.directionDown)

            case .warmup:
                // Warmup: Start signal
                device.play(.start)
                try? await Task.sleep(nanoseconds: 200_000_000) // 200ms
                device.play(.notification)

            case .cooldown:
                // Cooldown: Wind-down signal
                device.play(.notification)
                try? await Task.sleep(nanoseconds: 300_000_000) // 300ms
                device.play(.directionDown)

            case .completed:
                // Completed: Success celebration
                device.play(.success)
                try? await Task.sleep(nanoseconds: 200_000_000) // 200ms
                device.play(.success)

            case .classic:
                // CLASSIC: Strong start indication
                device.play(.start)
                try? await Task.sleep(nanoseconds: 150_000_000)

                for _ in 0..<3 {
                    device.play(.notification)
                    try? await Task.sleep(nanoseconds: 200_000_000)
                }

                device.play(.click)

            case .postMeal:
                // POST-MEAL: Gentle start
                device.play(.start)
                try? await Task.sleep(nanoseconds: 200_000_000)
                device.play(.notification)

            default:
                // Default: Single click
                device.play(.click)
            }
        }
    }
    
    var formattedTime: String {
        let minutes = Int(timeRemaining) / 60
        let seconds = Int(timeRemaining) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    // MARK: - Phase Transition Notifications

    /// Schedule a notification 2 seconds after phase transition
    /// Matches the iPhone's interval walking notification text
    private func schedulePhaseNotification(for phase: WatchIWTPhase) {
        // Only schedule notifications for interval mode phases (not classic or idle/summary)
        guard sessionMode == .interval else { return }
        guard phase != .idle && phase != .summary && phase != .classic else { return }

        let content = UNMutableNotificationContent()
        content.title = notificationTitle(for: phase)
        content.body = notificationBody(for: phase)
        content.sound = .default

        // Schedule 2 seconds after phase change
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 2.0, repeats: false)
        let identifier = "iwt.watch.phase.\(phase.title).\(currentInterval).\(Date().timeIntervalSince1970)"
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)

        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("❌ Watch notification error: \(error.localizedDescription)")
            } else {
                print("📱 Watch notification scheduled for \(phase.title) in 2 seconds")
            }
        }
    }

    /// Get notification title for phase (matches iPhone styling)
    private func notificationTitle(for phase: WatchIWTPhase) -> String {
        switch phase {
        case .brisk: return "⚡️ SPEED UP NOW"
        case .slow: return "🚶 SLOW DOWN"
        case .cooldown: return "❄️ COOL DOWN"
        case .completed: return "🎉 SESSION COMPLETE"
        case .warmup: return "🔥 WARM UP"
        default: return "Just Walk"
        }
    }

    /// Get notification body for phase (matches iPhone styling)
    private func notificationBody(for phase: WatchIWTPhase) -> String {
        switch phase {
        case .warmup:
            return "🏁 Get ready! Warmup has started."
        case .brisk:
            return "🏃 Time for Brisk Walk! Pick up the pace."
        case .slow:
            return "🚶 Recovery time. Slow down and catch your breath."
        case .cooldown:
            return "❄️ Final stretch - Cool Down time!"
        case .completed:
            return "🎉 Session Complete! Great work!"
        default:
            return "Phase transition"
        }
    }
}
