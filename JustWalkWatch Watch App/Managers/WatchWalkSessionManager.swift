//
//  WatchWalkSessionManager.swift
//  JustWalkWatch Watch App
//
//  Walk tracking for watchOS with optional interval support
//

import Foundation
import WatchKit
import HealthKit
import os

// MARK: - Walk Mode

enum WalkMode: String {
    case standard
    case interval
    case fatBurn
    case postMeal
}

// MARK: - Fat Burn Zone Status

enum FatBurnZoneStatus: String {
    case below
    case inZone
    case above

    var label: String {
        switch self {
        case .below: return "SPEED UP"
        case .inZone: return "IN ZONE"
        case .above: return "SLOW DOWN"
        }
    }

    var icon: String {
        switch self {
        case .below: return "arrow.up"
        case .inZone: return "checkmark"
        case .above: return "arrow.down"
        }
    }

    var color: String {
        switch self {
        case .below: return "blue"
        case .inZone: return "green"
        case .above: return "orange"
        }
    }
}

@Observable
class WatchWalkSessionManager {
    private static let logger = Logger(subsystem: "com.justwalk.watch", category: "WalkSession")

    private let healthKit = WatchHealthKitManager.shared
    private let persistence = WatchPersistenceManager.shared

    // State
    var isWalking: Bool = false
    var isPaused: Bool = false
    var isEnding: Bool = false
    var elapsedSeconds: Int = 0
    var currentSteps: Int = 0
    var currentDistance: Double = 0

    // Heart rate (from WatchWorkoutManager HK session)
    var heartRate: Int = 0
    var averageHeartRate: Int = 0
    var activeCalories: Double = 0

    // Walk mode
    var walkMode: WalkMode = .standard

    // Interval state
    var activeInterval: WatchIntervalProgram? = nil
    var intervalTransferData: IntervalTransferData? = nil
    var intervalCompleted: Bool = false

    // Post-meal state
    static let postMealDurationSeconds = 600 // 10 minutes
    var postMealCompleted: Bool = false

    // Fat burn zone state
    var fatBurnZoneLow: Int = 0
    var fatBurnZoneHigh: Int = 0
    var fatBurnZoneStatus: FatBurnZoneStatus = .below
    var timeInZone: TimeInterval = 0

    // Internal
    private let workoutManager = WatchWorkoutManager.shared
    private var startTime: Date?
    private var pauseTime: Date?
    private var totalPausedDuration: TimeInterval = 0
    private var timer: Timer?
    private var tickCount: Int = 0
    private var lastAnnouncedPhaseIndex: Int = -1

    // Fat burn zone tracking internals
    private var zoneEntryDate: Date?
    private var lastHapticZoneStatus: FatBurnZoneStatus?
    private var lastZoneHapticTime: Date?
    private static let zoneHysteresisBPM = 3
    private static let zoneHapticCooldown: TimeInterval = 5

    // MARK: - Interval Computed Properties

    var isIntervalMode: Bool {
        activeInterval != nil || intervalTransferData != nil
    }

    var intervalTotalSeconds: Int {
        if let transfer = intervalTransferData {
            return transfer.totalDurationSeconds
        }
        return activeInterval?.durationSeconds ?? 0
    }

    var intervalTimeRemaining: Int {
        max(0, intervalTotalSeconds - elapsedSeconds)
    }

    var intervalProgress: Double {
        guard intervalTotalSeconds > 0 else { return 0 }
        return min(Double(elapsedSeconds) / Double(intervalTotalSeconds), 1.0)
    }

    // MARK: - Phase Tracking

    var currentPhase: IntervalPhaseData? {
        guard let phases = intervalTransferData?.phases else { return nil }
        for phase in phases.reversed() {
            if elapsedSeconds >= phase.startOffset {
                return phase
            }
        }
        return phases.first
    }

    var nextPhase: IntervalPhaseData? {
        guard let phases = intervalTransferData?.phases,
              let current = currentPhase else { return nil }
        guard let currentIndex = phases.firstIndex(where: { $0.startOffset == current.startOffset && $0.type == current.type }),
              currentIndex + 1 < phases.count else { return nil }
        return phases[currentIndex + 1]
    }

    var secondsRemainingInPhase: Int {
        guard let phase = currentPhase else { return 0 }
        let phaseEnd = phase.startOffset + phase.durationSeconds
        return max(0, phaseEnd - elapsedSeconds)
    }

    var currentPhaseIndex: Int {
        guard let phases = intervalTransferData?.phases,
              let current = currentPhase else { return -1 }
        return phases.firstIndex(where: { $0.startOffset == current.startOffset && $0.type == current.type }) ?? -1
    }

    // MARK: - Fat Burn Zone Computed Properties

    var isFatBurnMode: Bool {
        walkMode == .fatBurn
    }

    var percentageInZone: Double {
        guard elapsedSeconds > 0 else { return 0 }
        return min(1.0, timeInZone / Double(elapsedSeconds))
    }

    // MARK: - Post-Meal Computed Properties

    var isPostMealMode: Bool {
        walkMode == .postMeal
    }

    var postMealTimeRemaining: Int {
        max(0, Self.postMealDurationSeconds - elapsedSeconds)
    }

    // MARK: - Fat Burn Zone Calculation

    /// Calculates fat burn zone from HealthKit date of birth. Falls back to generic zone if DOB unavailable.
    /// Sets fallback zone immediately so the walk starts without blocking, then reads real age in the background.
    func calculateFatBurnZone() {
        // Set fallback zone immediately so the UI is never blocked
        setFallbackZone()

        // Read real age from HealthKit off the main thread
        Task.detached { [weak self] in
            do {
                let dobComponents = try HKHealthStore().dateOfBirthComponents()
                let calendar = Calendar.current
                if let dob = calendar.date(from: dobComponents) {
                    let age = calendar.dateComponents([.year], from: dob, to: Date()).year ?? 30
                    let maxHR = 220 - age
                    let low = Int(Double(maxHR) * 0.60)
                    let high = Int(Double(maxHR) * 0.70)
                    await MainActor.run {
                        self?.fatBurnZoneLow = low
                        self?.fatBurnZoneHigh = high
                    }
                    WatchWalkSessionManager.logger.info("Fat burn zone calculated: \(low)-\(high) BPM (age \(age))")
                }
            } catch {
                WatchWalkSessionManager.logger.warning("Could not read DOB from HealthKit, using fallback zone: \(error.localizedDescription)")
                // Fallback already set above
            }
        }
    }

    private func setFallbackZone() {
        // Generic zone based on age ~30: (220-30)*0.6=114, (220-30)*0.7=133
        // Plan says 108-126, let's use that as the generic fallback
        fatBurnZoneLow = 108
        fatBurnZoneHigh = 126
        Self.logger.info("Using fallback fat burn zone: \(self.fatBurnZoneLow)-\(self.fatBurnZoneHigh) BPM")
    }

    // MARK: - Zone Evaluation

    /// Evaluates current heart rate against the fat burn zone. Called on each HR update.
    private func evaluateZoneStatus() {
        guard isFatBurnMode, heartRate > 0 else { return }

        let hysteresis = Self.zoneHysteresisBPM
        let previousStatus = fatBurnZoneStatus

        // Apply hysteresis to prevent flickering at zone boundaries
        let newStatus: FatBurnZoneStatus
        switch previousStatus {
        case .below:
            if heartRate >= fatBurnZoneLow {
                newStatus = heartRate > fatBurnZoneHigh + hysteresis ? .above : .inZone
            } else {
                newStatus = .below
            }
        case .inZone:
            if heartRate < fatBurnZoneLow - hysteresis {
                newStatus = .below
            } else if heartRate > fatBurnZoneHigh + hysteresis {
                newStatus = .above
            } else {
                newStatus = .inZone
            }
        case .above:
            if heartRate <= fatBurnZoneHigh {
                newStatus = heartRate < fatBurnZoneLow - hysteresis ? .below : .inZone
            } else {
                newStatus = .above
            }
        }

        // Track time in zone
        if previousStatus == .inZone && newStatus != .inZone {
            // Leaving zone — accumulate time
            if let entry = zoneEntryDate {
                timeInZone += Date().timeIntervalSince(entry)
                zoneEntryDate = nil
            }
        } else if previousStatus != .inZone && newStatus == .inZone {
            // Entering zone
            zoneEntryDate = Date()
        }

        fatBurnZoneStatus = newStatus

        // Play haptic on zone change
        if newStatus != previousStatus {
            playZoneChangeHaptic(newStatus)
        }
    }

    /// Finalizes zone time tracking (call when ending walk)
    private func finalizeZoneTime() {
        if fatBurnZoneStatus == .inZone, let entry = zoneEntryDate {
            timeInZone += Date().timeIntervalSince(entry)
            zoneEntryDate = nil
        }
    }

    // MARK: - Zone Haptics

    private func playZoneChangeHaptic(_ status: FatBurnZoneStatus) {
        let now = Date()
        if let lastTime = lastZoneHapticTime, now.timeIntervalSince(lastTime) < Self.zoneHapticCooldown {
            return // Cooldown active
        }
        lastZoneHapticTime = now

        switch status {
        case .below:
            WatchHaptics.speedUp()
        case .inZone:
            WatchHaptics.enteredZone()
        case .above:
            WatchHaptics.slowDown()
        }
    }

    // MARK: - Walk Control

    func startWalk(interval: WatchIntervalProgram? = nil, transferData: IntervalTransferData? = nil, mode: WalkMode = .standard) {
        guard !isWalking else { return }

        isWalking = true
        isPaused = false
        startTime = Date()
        elapsedSeconds = 0
        currentSteps = 0
        currentDistance = 0
        totalPausedDuration = 0
        pauseTime = nil
        tickCount = 0
        activeInterval = interval
        intervalCompleted = false
        postMealCompleted = false
        heartRate = 0
        averageHeartRate = 0
        activeCalories = 0
        lastAnnouncedPhaseIndex = -1

        // Set walk mode
        if interval != nil || transferData != nil {
            walkMode = .interval
        } else {
            walkMode = mode
        }

        // Fat burn zone setup
        if walkMode == .fatBurn {
            calculateFatBurnZone()
            fatBurnZoneStatus = .below
            timeInZone = 0
            zoneEntryDate = nil
            lastHapticZoneStatus = nil
            lastZoneHapticTime = nil
        }

        // If we have transfer data from iPhone, use it. Otherwise generate phases from WatchIntervalProgram.
        if let transferData = transferData {
            intervalTransferData = transferData
        } else if let interval = interval {
            intervalTransferData = Self.generateTransferData(from: interval)
        } else {
            intervalTransferData = nil
        }

        WatchHaptics.walkResumed()
        startTimer()

        // Start HK workout session for HR, calories, and iPhone connectivity
        Task { @MainActor in
            do {
                try await workoutManager.startWorkout(walkId: UUID())
            } catch {
                Self.logger.warning("HK workout session failed to start — walk continues without HR: \(error.localizedDescription)")
            }
        }

        if walkMode == .fatBurn {
            Self.logger.info("Fat burn walk started (zone: \(self.fatBurnZoneLow)-\(self.fatBurnZoneHigh) BPM)")
        } else if let transfer = intervalTransferData {
            Self.logger.info("Walk started with interval: \(transfer.programName)")
        } else {
            Self.logger.info("Standard walk started")
        }
    }

    /// Generate IntervalTransferData with phases from a WatchIntervalProgram
    private static func generateTransferData(from program: WatchIntervalProgram) -> IntervalTransferData {
        var phases: [IntervalPhaseData] = []
        var offset = 0

        // 1-minute warmup
        phases.append(IntervalPhaseData(type: "warmup", durationSeconds: 60, startOffset: offset))
        offset += 60

        // Fast/slow interval pairs
        for _ in 0..<program.intervalCount {
            // Fast phase (3 min)
            let fastDuration = program.fastMinutes * 60
            phases.append(IntervalPhaseData(type: "fast", durationSeconds: fastDuration, startOffset: offset))
            offset += fastDuration

            // Slow phase (3 min)
            let slowDuration = program.slowMinutes * 60
            phases.append(IntervalPhaseData(type: "slow", durationSeconds: slowDuration, startOffset: offset))
            offset += slowDuration
        }

        // 1-minute cooldown
        phases.append(IntervalPhaseData(type: "cooldown", durationSeconds: 60, startOffset: offset))

        return IntervalTransferData(
            programName: program.displayName,
            totalDurationSeconds: program.durationSeconds,
            phases: phases
        )
    }

    func pauseWalk() {
        guard isWalking, !isPaused else { return }
        isPaused = true
        pauseTime = Date()
        timer?.invalidate()
        timer = nil
        workoutManager.pauseWorkout()
    }

    func resumeWalk() {
        guard isWalking, isPaused else { return }
        if let pauseStart = pauseTime {
            totalPausedDuration += Date().timeIntervalSince(pauseStart)
        }
        isPaused = false
        pauseTime = nil
        startTimer()
        workoutManager.resumeWorkout()
    }

    /// Restarts the timer if it was killed by the system (e.g., after returning from background).
    /// Safe to call at any time — does nothing if timer is already running or walk is paused/not active.
    func ensureTimerRunning() {
        guard isWalking, !isPaused, timer == nil else { return }
        // Update elapsed from wall clock so display catches up immediately
        if let start = startTime {
            elapsedSeconds = Int(Date().timeIntervalSince(start) - totalPausedDuration)
        }
        startTimer()
        Self.logger.info("Timer restarted after background")
    }

    func endWalk() async -> WatchWalkRecord? {
        guard isWalking, !isEnding, let start = startTime else {
            Self.logger.warning("endWalk called but no active walk (isWalking=\(self.isWalking), isEnding=\(self.isEnding))")
            // Reset state to recover from inconsistent state (only if not mid-ending)
            if !isEnding {
                isWalking = false
                isPaused = false
            }
            return nil
        }

        isEnding = true
        defer { isEnding = false }

        timer?.invalidate()
        timer = nil

        // Finalize fat burn zone time
        if isFatBurnMode {
            finalizeZoneTime()
        }

        let end = Date()
        let duration = Int(end.timeIntervalSince(start) - totalPausedDuration) / 60

        // Capture HR/calories from workout manager before ending HK session
        let finalAvgHR = workoutManager.averageHeartRate
        let finalCalories = workoutManager.activeCalories

        // Fetch steps and distance in parallel (not sequentially)
        async let fetchedSteps = healthKit.fetchStepsDuring(start: start, end: end)
        async let fetchedDistance = healthKit.fetchDistanceDuring(start: start, end: end)
        let steps = await fetchedSteps
        let distance = await fetchedDistance

        // End HK workout session — session.end() fires immediately inside endWorkout(),
        // while slow HealthKit store writes (endCollection + finishWorkout) run in the background.
        _ = await workoutManager.endWorkout()

        let intervalName = intervalTransferData?.programName ?? activeInterval?.rawValue

        let record = WatchWalkRecord(
            id: UUID(),
            startTime: start,
            endTime: end,
            durationMinutes: duration,
            steps: steps,
            distanceMeters: distance,
            intervalProgram: intervalName,
            intervalCompleted: isIntervalMode ? intervalCompleted : nil,
            averageHeartRate: finalAvgHR > 0 ? finalAvgHR : nil,
            activeCalories: finalCalories > 0 ? finalCalories : nil,
            isFatBurnWalk: isFatBurnMode,
            fatBurnZoneLow: isFatBurnMode ? fatBurnZoneLow : nil,
            fatBurnZoneHigh: isFatBurnMode ? fatBurnZoneHigh : nil,
            timeInZone: isFatBurnMode ? timeInZone : nil,
            percentageInZone: isFatBurnMode ? percentageInZone : nil
        )

        // Persist
        persistence.saveWalkRecord(record)

        Self.logger.info("Walk ended: \(duration) min, \(steps) steps")

        // Reset state
        let savedMode = walkMode
        isWalking = false
        isPaused = false
        startTime = nil
        pauseTime = nil
        totalPausedDuration = 0
        activeInterval = nil
        intervalTransferData = nil
        intervalCompleted = false
        postMealCompleted = false
        heartRate = 0
        averageHeartRate = 0
        activeCalories = 0
        lastAnnouncedPhaseIndex = -1

        // Reset fat burn state but keep walkMode for summary view
        if savedMode == .fatBurn {
            fatBurnZoneStatus = .below
            zoneEntryDate = nil
            lastHapticZoneStatus = nil
            lastZoneHapticTime = nil
        }

        return record
    }

    // MARK: - Timer

    private func startTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            self?.tick()
        }
    }

    private func tick() {
        guard let start = startTime, !isPaused else { return }
        elapsedSeconds = Int(Date().timeIntervalSince(start) - totalPausedDuration)
        tickCount += 1

        // Interval countdown haptics
        if isIntervalMode && !intervalCompleted {
            let remaining = intervalTotalSeconds - elapsedSeconds
            if remaining <= 0 {
                intervalCompleted = true
                WatchHaptics.walkCompleted()
            } else if remaining <= 3 && remaining > 0 {
                WatchHaptics.countdownTick()
            }
        }

        // Post-meal countdown haptics
        if isPostMealMode && !postMealCompleted {
            let remaining = postMealTimeRemaining
            if remaining <= 0 {
                postMealCompleted = true
                WatchHaptics.walkCompleted()
            } else if remaining <= 3 && remaining > 0 {
                WatchHaptics.countdownTick()
            }
        }

        // Phase transition haptics - strong burst pattern for maximum feel during workout
        if intervalTransferData != nil {
            let phaseIdx = currentPhaseIndex
            if phaseIdx != lastAnnouncedPhaseIndex && lastAnnouncedPhaseIndex >= 0 {
                // Play a strong 3-tap burst pattern that's unmistakable during movement
                WatchHaptics.phaseChange()
            }
            lastAnnouncedPhaseIndex = phaseIdx
        }

        // Read HR and calories from workout manager every tick
        heartRate = workoutManager.heartRate
        activeCalories = workoutManager.activeCalories

        // Evaluate fat burn zone status on each HR update
        if isFatBurnMode {
            evaluateZoneStatus()
        }

        // Poll HealthKit every 5 seconds
        if tickCount % 5 == 0 {
            Task { @MainActor [weak self] in
                guard let self = self, let start = self.startTime else { return }
                let now = Date()
                self.currentSteps = await self.healthKit.fetchStepsDuring(start: start, end: now)
                self.currentDistance = await self.healthKit.fetchDistanceDuring(start: start, end: now)
            }
        }
    }

}
