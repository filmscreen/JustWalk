//
//  IWTService.swift
//  Just Walk
//
//  Created by Randy Chia on 1/8/26.
//

import Foundation
import Combine
import SwiftUI
import CoreHaptics
import UserNotifications

/// Walking Session Mode
public enum WalkMode: String, Codable, Sendable, Identifiable {
    case interval
    case classic
    case postMeal

    public var id: String { rawValue }
}

/// Interval Walking Technique phases
enum IWTPhase: String, CaseIterable {
    case warmup = "Warm Up"
    case brisk = "Brisk"
    case slow = "Easy"
    case cooldown = "Cool Down"
    case paused = "Paused"
    case completed = "Completed"
    case classic = "Just Walk"

    /// Short display name for space-constrained UI (Dynamic Island, compact widgets)
    var displayName: String {
        switch self {
        case .warmup: return "Warmup"
        case .brisk: return "Brisk"
        case .slow: return "Easy"
        case .cooldown: return "Cooldown"
        case .paused: return "Paused"
        case .completed: return "Complete"
        case .classic: return "Walk"
        }
    }

    var icon: String {
        switch self {
        case .warmup: return "flame"
        case .brisk: return "hare.fill"
        case .slow: return "tortoise.fill"
        case .cooldown: return "snowflake"
        case .paused: return "pause.fill"
        case .completed: return "checkmark.circle.fill"
        case .classic: return "figure.walk"
        }
    }

    var color: Color {
        switch self {
        case .warmup: return .orange
        case .brisk: return Color(hex: "FF9500")  // Orange
        case .slow: return Color(hex: "00C7BE")   // Teal
        case .cooldown: return .blue
        case .paused: return .gray
        case .completed: return .purple
        case .classic: return .cyan
        }
    }
    
    var colorHex: String {
        switch self {
        case .warmup: return "#FF9500"
        case .brisk: return "#FF9500"  // Orange
        case .slow: return "#00C7BE"   // Teal
        case .cooldown: return "#007AFF"
        case .paused: return "#8E8E93"
        case .completed: return "#AF52DE"
        case .classic: return "#32D4DE"
        }
    }

    var instructions: [String] {
        switch self {
        case .brisk:
            return ["Pick up the pace", "Walk with purpose", "Push yourself"]
        case .slow:
            return ["Walk at a comfortable pace", "Catch your breath", "Nice and easy"]
        case .warmup:
            return ["Start with an easy pace to warm up"]
        case .cooldown:
            return ["Gradually slow down to cool off"]
        case .paused:
            return ["Session paused. Tap resume to continue"]
        case .completed:
            return ["Great job! You've completed your Power Walk"]
        case .classic:
            return ["Go at your own pace"]
        }
    }

    var instruction: String { instructions.first ?? "" }
}

/// IWT Session configuration
struct IWTConfiguration: Sendable {
    let briskDuration: TimeInterval // seconds
    let slowDuration: TimeInterval // seconds
    let warmupDuration: TimeInterval // seconds
    let cooldownDuration: TimeInterval // seconds
    let totalIntervals: Int // number of brisk+slow cycles
    let enableWarmup: Bool
    let enableCooldown: Bool

    /// Standard configuration (simplified - no warmup/cooldown by default)
    static let standard = IWTConfiguration(
        briskDuration: 180, // 3 minutes
        slowDuration: 180, // 3 minutes
        warmupDuration: 0,
        cooldownDuration: 0,
        totalIntervals: 5,
        enableWarmup: false,
        enableCooldown: false
    )

    /// Legacy standard with warmup/cooldown
    static let standardWithWarmup = IWTConfiguration(
        briskDuration: 180, // 3 minutes
        slowDuration: 180, // 3 minutes
        warmupDuration: 120, // 2 minutes
        cooldownDuration: 120, // 2 minutes
        totalIntervals: 5,
        enableWarmup: true,
        enableCooldown: true
    )

    static let beginner = IWTConfiguration(
        briskDuration: 60, // 1 minute
        slowDuration: 120, // 2 minutes
        warmupDuration: 0,
        cooldownDuration: 0,
        totalIntervals: 5,
        enableWarmup: false,
        enableCooldown: false
    )

    static let advanced = IWTConfiguration(
        briskDuration: 240, // 4 minutes
        slowDuration: 120, // 2 minutes
        warmupDuration: 0,
        cooldownDuration: 0,
        totalIntervals: 6,
        enableWarmup: false,
        enableCooldown: false
    )

    var totalDuration: TimeInterval {
        let warmup = enableWarmup ? warmupDuration : 0
        let cooldown = enableCooldown ? cooldownDuration : 0
        return warmup + cooldown + (Double(totalIntervals) * (briskDuration + slowDuration))
    }
}

/// Service managing IWT session state and timing
@MainActor
final class IWTService: ObservableObject {

    static let shared = IWTService()

    // MARK: - Published Properties

    @Published var isSessionActive = false
    @Published var isPaused = false
    @Published var currentPhase: IWTPhase = .warmup
    @Published var phaseTimeRemaining: TimeInterval = 0
    @Published var totalElapsedTime: TimeInterval = 0
    @Published var currentInterval: Int = 0
    @Published var completedBriskIntervals: Int = 0
    @Published var completedSlowIntervals: Int = 0
    
    public var sessionMode: WalkMode = .interval
    
    /// Whether this session was initiated remotely (from Watch)
    var isRemoteSession: Bool = false

    // MARK: - Configuration

    var configuration: IWTConfiguration = .standard

    // MARK: - Private Properties

    private var timerTask: Task<Void, Never>?
    private var heartbeatTask: Task<Void, Never>?
    var phaseStartTime: Date?
    private var totalPausedTime: TimeInterval = 0
    private var pauseStartTime: Date?
    private var hapticEngine: CHHapticEngine?
    var sessionStartTime: Date?
    private var foregroundActivityTask: Task<Void, Never>?
    
    /// Notification identifier prefix for phase alerts
    private let phaseNotificationIdentifier = "iwt.phase.transition"

    /// All scheduled phase end times (for reliable background tracking)
    /// Computed at session start for entire session timeline
    private var allPhaseEndTimes: [(phase: IWTPhase, interval: Int, endTime: Date)] = []

    /// Index into allPhaseEndTimes for current phase
    private var currentPhaseIndex: Int = 0

    /// Absolute phase end time - stored directly from pre-calculated schedule
    /// Using an absolute time (rather than computing from phaseStartTime + duration)
    /// ensures accurate phase timing
    private var _phaseEndTime: Date?

    var phaseEndTime: Date? {
        // Prefer the stored absolute time if available
        if let stored = _phaseEndTime {
            return stored
        }
        // Fallback to computed (for legacy/classic mode)
        guard let start = phaseStartTime else { return nil }
        let duration = currentPhaseDuration()
        return start.addingTimeInterval(duration)
    }

    // Callbacks
    var onPhaseChange: ((IWTPhase) -> Void)?
    var onIntervalComplete: ((Int) -> Void)?
    var onSessionComplete: (() -> Void)?
    
    // MARK: - Notification Permission
    
    /// Request notification permissions for background phase alerts
    static func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if granted {
                print("✅ Notification permission granted for IWT alerts")
            } else if let error = error {
                print("⚠️ Notification permission error: \(error)")
            }
        }
    }

    private init() {
        prepareHaptics()
        startForegroundMonitoring()
    }
    
    deinit {
        foregroundActivityTask?.cancel()
    }
    
    // MARK: - Foreground Observer

    private func startForegroundMonitoring() {
        foregroundActivityTask = Task { @MainActor [weak self] in
            for await _ in NotificationCenter.default.notifications(named: UIApplication.willEnterForegroundNotification) {
                guard let self else { return }
                self.handleReturnToForeground()
            }
        }

        // Also monitor didBecomeActive for cases where app becomes active without willEnterForeground
        // (e.g., when tapping notification while app is suspended)
        Task { @MainActor [weak self] in
            for await _ in NotificationCenter.default.notifications(named: UIApplication.didBecomeActiveNotification) {
                guard let self else { return }
                // Slight delay to ensure state is settled
                try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
                self.handleReturnToForeground()
            }
        }
    }
    
    /// Called when app returns to foreground - catch up on missed phases
    private func handleReturnToForeground() {
        guard isSessionActive, !isPaused, sessionMode == .interval else { return }

        print("📱 Returning to foreground - checking for missed phases")

        // Cancel any pending notifications since we're now active
        cancelPhaseNotifications()

        // Catch up on any missed phase transitions (updates phaseStartTime to correct absolute time)
        catchUpToCurrentPhase()

        // Restart the timer for continued tracking
        startTimer()

        // NOTE: Notifications are handled by LiveActivityManager.scheduleAllPhaseNotifications()
        // which provides better titles like "SPEED UP NOW" and "SLOW DOWN"
    }
    
    /// Calculate and advance to the correct phase based on elapsed time
    /// Uses pre-calculated allPhaseEndTimes for accurate recovery after background
    private func catchUpToCurrentPhase() {
        guard let sessionStart = sessionStartTime else { return }

        let now = Date()

        // If we have pre-calculated phase times, use them for accurate catch-up
        if !allPhaseEndTimes.isEmpty {
            catchUpUsingPreCalculatedTimes(now: now)
            return
        }

        // Fallback to elapsed time calculation (for legacy/remote sessions)
        let elapsed = now.timeIntervalSince(sessionStart) - totalPausedTime
        var timeAccumulated: TimeInterval = 0

        // Walk through the session timeline to find current phase
        // Warmup
        if configuration.enableWarmup {
            timeAccumulated += configuration.warmupDuration
            if elapsed < timeAccumulated {
                if currentPhase != .warmup {
                    currentPhase = .warmup
                    phaseStartTime = sessionStart
                    playPhaseChangeHaptic()
                }
                phaseTimeRemaining = timeAccumulated - elapsed
                return
            }
        }

        // Intervals
        for interval in 1...configuration.totalIntervals {
            // Brisk
            timeAccumulated += configuration.briskDuration
            if elapsed < timeAccumulated {
                if currentPhase != .brisk || currentInterval != interval {
                    currentPhase = .brisk
                    currentInterval = interval
                    phaseStartTime = Date().addingTimeInterval(-(elapsed - (timeAccumulated - configuration.briskDuration)))
                    playPhaseChangeHaptic()
                }
                phaseTimeRemaining = timeAccumulated - elapsed
                return
            }

            // Slow
            timeAccumulated += configuration.slowDuration
            if elapsed < timeAccumulated {
                if currentPhase != .slow || currentInterval != interval {
                    currentPhase = .slow
                    currentInterval = interval
                    completedBriskIntervals = interval
                    phaseStartTime = Date().addingTimeInterval(-(elapsed - (timeAccumulated - configuration.slowDuration)))
                    playPhaseChangeHaptic()
                }
                phaseTimeRemaining = timeAccumulated - elapsed
                return
            }

            completedSlowIntervals = interval
        }

        // Cooldown
        if configuration.enableCooldown {
            timeAccumulated += configuration.cooldownDuration
            if elapsed < timeAccumulated {
                if currentPhase != .cooldown {
                    currentPhase = .cooldown
                    phaseStartTime = Date().addingTimeInterval(-(elapsed - (timeAccumulated - configuration.cooldownDuration)))
                    playPhaseChangeHaptic()
                }
                phaseTimeRemaining = timeAccumulated - elapsed
                return
            }
        }

        // Session complete
        if currentPhase != .completed {
            currentPhase = .completed
            timerTask?.cancel()
            timerTask = nil
            playCompletionHaptic()
            onSessionComplete?()
        }
    }

    /// Catch up using pre-calculated phase end times (more accurate)
    private func catchUpUsingPreCalculatedTimes(now: Date) {
        // Guard against nil sessionStartTime to prevent crash
        guard let startTime = sessionStartTime else {
            print("⚠️ catchUpUsingPreCalculatedTimes called with nil sessionStartTime")
            return
        }

        // Find the current phase based on absolute times
        // allPhaseEndTimes stores: (phase, interval, endTime) for each phase in order
        // We need to find which phase we're currently IN (now < endTime)
        var foundCurrentPhase = false

        for (index, phaseInfo) in allPhaseEndTimes.enumerated() {
            if now < phaseInfo.endTime {
                // We're currently in THIS phase (before its end time)
                // phaseInfo.phase is the phase that ENDS at phaseInfo.endTime
                // So we ARE in phaseInfo.phase right now
                let previousEndTime = index > 0 ? allPhaseEndTimes[index - 1].endTime : startTime

                // The phase we're in is directly stored in phaseInfo.phase
                let targetPhase = phaseInfo.phase

                // Calculate interval number for brisk/slow phases
                let targetInterval: Int
                if targetPhase == .warmup || targetPhase == .cooldown {
                    targetInterval = phaseInfo.interval // Usually 0 for warmup/cooldown
                } else {
                    targetInterval = phaseInfo.interval
                }

                // Update state if changed
                if currentPhase != targetPhase || currentInterval != targetInterval {
                    print("📱 Catching up: moving to \(targetPhase.rawValue) interval \(targetInterval)")
                    currentPhase = targetPhase
                    currentInterval = targetInterval
                    currentPhaseIndex = index
                    phaseStartTime = previousEndTime
                    // CRITICAL: Set the absolute phase end time from the schedule
                    _phaseEndTime = phaseInfo.endTime
                    playPhaseChangeHaptic()
                } else {
                    // Even if phase didn't change, ensure _phaseEndTime is synced
                    _phaseEndTime = phaseInfo.endTime
                }

                phaseTimeRemaining = phaseInfo.endTime.timeIntervalSince(now)
                foundCurrentPhase = true
                break
            } else {
                // This phase has passed, update completed counts
                if phaseInfo.phase == .brisk {
                    completedBriskIntervals = max(completedBriskIntervals, phaseInfo.interval)
                } else if phaseInfo.phase == .slow {
                    completedSlowIntervals = max(completedSlowIntervals, phaseInfo.interval)
                }
            }
        }

        // If no phase found, session is complete
        if !foundCurrentPhase && currentPhase != .completed {
            currentPhase = .completed
            timerTask?.cancel()
            timerTask = nil
            playCompletionHaptic()
            onSessionComplete?()
        }
    }

    // MARK: - Session Control

    /// Start a new session
    func startSession(mode: WalkMode, with config: IWTConfiguration? = nil) {
        sessionMode = mode
        configuration = config ?? .standard
        isSessionActive = true
        isPaused = false
        isRemoteSession = false

        let startTime = Date()
        sessionStartTime = startTime
        phaseStartTime = startTime

        if mode == .interval {
            // Pre-calculate all phase end times for reliable background tracking
            calculateAllPhaseEndTimes(from: startTime)

            if configuration.enableWarmup {
                currentPhase = .warmup
                phaseTimeRemaining = configuration.warmupDuration
                currentInterval = 0
                currentPhaseIndex = 0
                // Set absolute phase end time from pre-calculated schedule
                _phaseEndTime = allPhaseEndTimes.first?.endTime
            } else {
                // Skip Warmup -> Start with Easy phase (interval 1)
                currentPhase = .slow  // "Easy" in UI
                phaseTimeRemaining = configuration.slowDuration
                currentInterval = 1
                currentPhaseIndex = 0
                // Set absolute phase end time from pre-calculated schedule
                _phaseEndTime = allPhaseEndTimes.isEmpty ? nil : allPhaseEndTimes[currentPhaseIndex].endTime
            }
        } else {
            currentPhase = .classic
            phaseTimeRemaining = 0 // Classic mode counts up or is effectively infinite
            currentInterval = 0
            _phaseEndTime = nil // Classic mode doesn't use phase end times
        }
        completedBriskIntervals = 0
        completedSlowIntervals = 0
        totalElapsedTime = 0
        totalPausedTime = 0

        startTimer()
        playPhaseChangeHaptic()

        // ROBUST BACKGROUND: Use Live Activity as primary background persistence mechanism
        // This ensures notifications fire reliably even when app is suspended
        if mode == .interval {
            // Start Live Activity for background persistence
            // NOTE: LiveActivityManager.startActivity() internally calls scheduleAllPhaseNotifications()
            // so we do NOT call it here to avoid duplicate notifications
            Task {
                await LiveActivityManager.shared.startActivity(
                    startTime: startTime,
                    configuration: configuration
                )
            }

            // Start background session manager as additional backup
            IWTBackgroundManager.shared.startBackgroundSession()
        }

        // Request Apple Watch to start workout for heart rate monitoring
        // This allows the Watch to send live HR data to the iPhone during the session
        StepTrackingService.shared.requestWatchWorkoutStart(mode: mode == .interval ? "interval" : "classic")
    }

    /// Adopt an existing session from the Watch (Sync)
    func adoptRemoteSession(mode: WalkMode, startTime: Date) {
        // Prevent re-adoption if already active
        guard !isSessionActive else { return }
        
        print("Adopting remote session from Watch (Start: \(startTime))")
        
        sessionMode = mode
        configuration = .standard // Use standard for now, or fetch from settings
        isSessionActive = true
        isPaused = false
        isRemoteSession = true
        
        // Basic setup
        if mode == .interval {
            if configuration.enableWarmup {
                currentPhase = .warmup
                phaseTimeRemaining = configuration.warmupDuration
                currentInterval = 0
            } else {
                currentPhase = .brisk
                phaseTimeRemaining = configuration.briskDuration
                currentInterval = 1
            }
        } else {
            currentPhase = .classic
            phaseTimeRemaining = 0
            currentInterval = 0
        }
        
        completedBriskIntervals = 0
        completedSlowIntervals = 0
        totalElapsedTime = Date().timeIntervalSince(startTime)
        totalPausedTime = 0
        sessionStartTime = startTime
        phaseStartTime = Date() // Reset phase timer to specific phase start? Approximation for now.
        
        startTimer()
    }

    /// Pause the current session
    func pauseSession() {
        guard isSessionActive, !isPaused else { return }

        isPaused = true
        pauseStartTime = Date()
        timerTask?.cancel()
        timerTask = nil

        let previousPhase = currentPhase
        currentPhase = .paused

        playPauseHaptic()

        // Store previous phase to restore later
        UserDefaults.standard.set(previousPhase.rawValue, forKey: "iwt_paused_phase")

        // Pause Live Activity
        Task {
            await LiveActivityManager.shared.pauseActivity()
        }
    }

    /// Resume a paused session
    func resumeSession() {
        guard isSessionActive, isPaused else { return }

        let pauseDuration: TimeInterval
        if let pauseStart = pauseStartTime {
            pauseDuration = Date().timeIntervalSince(pauseStart)
            totalPausedTime += pauseDuration
        } else {
            print("⚠️ ERROR: resumeSession called but pauseStartTime is nil - phase timing may be inaccurate")
            pauseDuration = 0
        }

        isPaused = false
        pauseStartTime = nil

        // Restore previous phase
        if let phaseName = UserDefaults.standard.string(forKey: "iwt_paused_phase"),
           let phase = IWTPhase(rawValue: phaseName) {
            currentPhase = phase
        }

        // Adjust phaseStartTime to account for pause duration
        if let oldStart = phaseStartTime {
            phaseStartTime = oldStart.addingTimeInterval(pauseDuration)
        }

        // Adjust the stored absolute phase end time
        if let oldEnd = _phaseEndTime {
            _phaseEndTime = oldEnd.addingTimeInterval(pauseDuration)
        }

        // Also adjust all pre-calculated phase end times (safe copy to avoid race condition)
        allPhaseEndTimes = allPhaseEndTimes.map { (phase, interval, endTime) in
            (phase, interval, endTime.addingTimeInterval(pauseDuration))
        }

        startTimer()
        playResumeHaptic()

        // Resume Live Activity with adjusted schedule
        // NOTE: LiveActivityManager.resumeActivity() internally calls scheduleAllPhaseNotifications()
        // so we do NOT call it here to avoid duplicate notifications
        LiveActivityManager.shared.adjustScheduleForPause(pauseDuration: pauseDuration)
        Task {
            await LiveActivityManager.shared.resumeActivity(adjustedSchedule: allPhaseEndTimes.map { $0.endTime })
        }
    }

    /// End the current session
    func endSession(steps: Int = 0, distance: Double = 0, averageHeartRate: Double = 0, activeCalories: Double = 0) -> IWTSessionSummary? {
        guard isSessionActive else { return nil }

        timerTask?.cancel()
        timerTask = nil
        heartbeatTask?.cancel()
        heartbeatTask = nil

        // Cancel any pending phase notifications
        cancelPhaseNotifications()

        // End Live Activity
        let sessionCompleted = currentPhase == .completed
        Task {
            await LiveActivityManager.shared.endActivity(completed: sessionCompleted)
        }

        // Stop background session manager
        IWTBackgroundManager.shared.stopBackgroundSession()

        // Request Apple Watch to stop its workout session
        StepTrackingService.shared.requestWatchWorkoutStop()

        // Stop haptic engine to free resources
        hapticEngine?.stop()
        hapticEngine = nil

        let summary = IWTSessionSummary(
            startTime: sessionStartTime ?? Date(),
            endTime: Date(),
            totalDuration: totalElapsedTime,
            briskIntervals: completedBriskIntervals,
            slowIntervals: completedSlowIntervals,
            configuration: configuration,
            completedSuccessfully: currentPhase == .completed,
            steps: steps,
            distance: distance,
            averageHeartRate: averageHeartRate,
            activeCalories: activeCalories
        )

        // Reset state
        isSessionActive = false
        isPaused = false
        isRemoteSession = false
        currentPhase = .completed  // Show completion background while summary card is visible
        currentInterval = 0
        completedBriskIntervals = 0
        completedSlowIntervals = 0
        totalElapsedTime = 0
        phaseTimeRemaining = 0
        sessionStartTime = nil
        phaseStartTime = nil
        _phaseEndTime = nil

        // Clear scheduled phase times
        allPhaseEndTimes.removeAll()
        currentPhaseIndex = 0

        return summary
    }

    /// Skip to the next phase
    /// When manually skipping, we need to recalculate all future phase times
    /// from the current moment to avoid time accumulation
    func skipToNextPhase() {
        advancePhase(isManualSkip: true)
    }

    // MARK: - Timer Logic

    private func startTimer() {
        timerTask?.cancel()
        
        timerTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                guard !Task.isCancelled else { return }
                self?.tick()
            }
        }
    }

    private func tick() {
        guard isSessionActive, !isPaused else { return }

        // Update elapsed time
        if let start = sessionStartTime {
            totalElapsedTime = Date().timeIntervalSince(start) - totalPausedTime
        }

        // Update phase time remaining using absolute phaseEndTime
        // This ensures consistency with Live Activity which also uses phaseEndTime
        if sessionMode == .interval {
            if let endTime = phaseEndTime {
                // Calculate remaining time from absolute end time (matches Live Activity)
                phaseTimeRemaining = max(0, endTime.timeIntervalSinceNow)

                // Check if phase is complete
                if phaseTimeRemaining <= 0 {
                    advancePhase(isManualSkip: false)
                }
            }
        } else {
            // Classic mode: just running.
            phaseTimeRemaining = 0
        }
    }

    private func currentPhaseDuration() -> TimeInterval {
        switch currentPhase {
        case .warmup:
            return configuration.warmupDuration
        case .brisk:
            return configuration.briskDuration
        case .slow:
            return configuration.slowDuration
        case .cooldown:
            return configuration.cooldownDuration

        case .classic:
            return 0 // Infinite / undefined
        case .paused, .completed:
            return 0
        }
    }

    /// Advance to the next phase
    /// - Parameter isManualSkip: If true, the user manually skipped the phase (via Next button).
    ///   When manually skipping, we must recalculate phase times from NOW to prevent time accumulation.
    /// Phase order: Easy (slow) → Brisk → Easy → Brisk... (session ends after final Brisk)
    private func advancePhase(isManualSkip: Bool = false) {
        let previousPhase = currentPhase

        switch currentPhase {
        case .warmup:
            // Warmup → Easy (slow) interval 1
            currentPhase = .slow
            currentInterval = 1

        case .slow:
            // Easy → Brisk (same interval)
            completedSlowIntervals += 1
            currentPhase = .brisk

        case .brisk:
            // Brisk → check if done or continue to next Easy
            completedBriskIntervals += 1
            onIntervalComplete?(currentInterval)

            if currentInterval >= configuration.totalIntervals {
                // Completed all intervals
                if configuration.enableCooldown {
                    currentPhase = .cooldown
                } else {
                    // No cooldown -> Complete immediately
                    currentPhase = .completed
                    timerTask?.cancel()
                    timerTask = nil
                    playCompletionHaptic()
                    onSessionComplete?()
                    return
                }
            } else {
                // Start next Easy interval
                currentInterval += 1
                currentPhase = .slow
            }

        case .cooldown:
            currentPhase = .completed
            timerTask?.cancel()
            timerTask = nil
            playCompletionHaptic()
            onSessionComplete?()
            return

        case .paused, .completed, .classic:
            return
        }

        // CRITICAL FIX: When manually skipping, always recalculate from current time
        // This prevents time accumulation (e.g., 2 min remaining + 3 min = 5 min bug)
        if isManualSkip {
            // Manual skip: Start the new phase fresh from NOW with its full duration
            let now = Date()
            phaseStartTime = now
            _phaseEndTime = now.addingTimeInterval(currentPhaseDuration())
            phaseTimeRemaining = currentPhaseDuration()

            // Recalculate all remaining phase end times and reschedule notifications
            recalculateRemainingPhaseTimesFromNow()
        } else {
            // Natural transition: Use pre-calculated phase times if available for accurate timing
            // currentPhaseIndex points to the CURRENT phase in allPhaseEndTimes
            // After advancing, we need to move to the next index
            if currentPhaseIndex + 1 < allPhaseEndTimes.count, let startTime = sessionStartTime {
                // Move to the next phase in the schedule
                currentPhaseIndex += 1
                let nextPhaseInfo = allPhaseEndTimes[currentPhaseIndex]
                let previousEndTime = currentPhaseIndex > 0 ? allPhaseEndTimes[currentPhaseIndex - 1].endTime : startTime
                phaseStartTime = previousEndTime
                // CRITICAL: Set absolute phase end time from schedule for perfect sync
                _phaseEndTime = nextPhaseInfo.endTime
            } else {
                // Fallback to current time if no pre-calculated times (shouldn't happen normally)
                phaseStartTime = Date()
                _phaseEndTime = Date().addingTimeInterval(currentPhaseDuration())
            }
            phaseTimeRemaining = currentPhaseDuration()
        }

        if previousPhase != currentPhase {
            // Play phase-specific haptics
            switch currentPhase {
            case .brisk:
                playBriskStartHaptic()
            case .slow:
                playEasyStartHaptic()
            default:
                playPhaseChangeHaptic()
            }
            onPhaseChange?(currentPhase)

            // Update Live Activity immediately when phase changes
            Task {
                await LiveActivityManager.shared.updatePhase(
                    currentPhase,
                    interval: currentInterval,
                    isPaused: false
                )
            }
        }
    }
    
    // MARK: - Background Notifications

    /// Pre-calculate all phase end times for the entire session
    /// This enables scheduling all notifications upfront for reliable background alerts
    /// Pattern: Easy → Brisk → Easy → Brisk... (no warmup/cooldown in simplified flow)
    private func calculateAllPhaseEndTimes(from startTime: Date) {
        allPhaseEndTimes.removeAll()
        currentPhaseIndex = 0

        var currentTime = startTime

        // Warmup (legacy support - only if explicitly enabled)
        if configuration.enableWarmup {
            currentTime = currentTime.addingTimeInterval(configuration.warmupDuration)
            allPhaseEndTimes.append((phase: .warmup, interval: 0, endTime: currentTime))
        }

        // Intervals: Easy (slow) → Brisk pattern
        // Each cycle starts with Easy and ends with Brisk
        for interval in 1...configuration.totalIntervals {
            // Easy (slow) phase first
            currentTime = currentTime.addingTimeInterval(configuration.slowDuration)
            allPhaseEndTimes.append((phase: .slow, interval: interval, endTime: currentTime))

            // Brisk phase second
            currentTime = currentTime.addingTimeInterval(configuration.briskDuration)
            allPhaseEndTimes.append((phase: .brisk, interval: interval, endTime: currentTime))
        }

        // Cooldown (legacy support - only if explicitly enabled)
        if configuration.enableCooldown {
            currentTime = currentTime.addingTimeInterval(configuration.cooldownDuration)
            allPhaseEndTimes.append((phase: .cooldown, interval: 0, endTime: currentTime))
        }

        print("📅 Calculated \(allPhaseEndTimes.count) phase end times for session")
    }

    /// Recalculate remaining phase end times starting from NOW
    /// Called when user manually skips a phase to ensure correct timing
    /// Phase order: Easy (slow) → Brisk → Easy → Brisk...
    private func recalculateRemainingPhaseTimesFromNow() {
        let now = Date()
        var currentTime = now

        // Start with the current phase (already set with its duration)
        currentTime = currentTime.addingTimeInterval(currentPhaseDuration())

        // Rebuild allPhaseEndTimes from the current phase forward
        var newPhaseEndTimes: [(phase: IWTPhase, interval: Int, endTime: Date)] = []

        // Add current phase
        newPhaseEndTimes.append((phase: currentPhase, interval: currentInterval, endTime: currentTime))

        // Determine remaining phases based on current state
        var tempPhase = currentPhase
        var tempInterval = currentInterval
        var iterations = 0
        let maxIterations = 50 // Safety guard against infinite loop

        while iterations < maxIterations {
            iterations += 1
            // Determine what comes next (Easy → Brisk → Easy → Brisk...)
            switch tempPhase {
            case .warmup:
                // Warmup → Easy (slow)
                tempPhase = .slow
                tempInterval = 1

            case .slow:
                // Easy → Brisk (same interval)
                tempPhase = .brisk

            case .brisk:
                // Brisk → check if done or next Easy
                if tempInterval >= configuration.totalIntervals {
                    if configuration.enableCooldown {
                        tempPhase = .cooldown
                        tempInterval = 0
                    } else {
                        tempPhase = .completed
                    }
                } else {
                    tempInterval += 1
                    tempPhase = .slow
                }

            case .cooldown:
                tempPhase = .completed

            case .completed, .paused, .classic:
                break
            }

            // Stop if we've reached completion
            if tempPhase == .completed || tempPhase == .paused || tempPhase == .classic {
                break
            }

            // Calculate duration for this phase
            let duration: TimeInterval
            switch tempPhase {
            case .warmup: duration = configuration.warmupDuration
            case .brisk: duration = configuration.briskDuration
            case .slow: duration = configuration.slowDuration
            case .cooldown: duration = configuration.cooldownDuration
            default: duration = 0
            }

            currentTime = currentTime.addingTimeInterval(duration)
            newPhaseEndTimes.append((phase: tempPhase, interval: tempInterval, endTime: currentTime))
        }

        // Replace the schedule with new times
        allPhaseEndTimes = newPhaseEndTimes
        currentPhaseIndex = 0

        print("📅 Recalculated \(allPhaseEndTimes.count) remaining phase end times after manual skip")

        // Reschedule all notifications via LiveActivityManager
        // NOTE: We do NOT call our own scheduleAllPhaseNotifications() to avoid duplicate notifications
        Task {
            await LiveActivityManager.shared.rescheduleAfterManualSkip(newPhaseEndTimes: newPhaseEndTimes)
        }
    }

    /// Schedule ALL phase notifications upfront for reliable background alerts
    private func scheduleAllPhaseNotifications() {
        guard sessionMode == .interval else { return }

        // Cancel any existing notifications first
        cancelPhaseNotifications()

        // Register notification category with actions
        Self.registerNotificationCategories()

        let totalToSchedule = allPhaseEndTimes.count
        var scheduledCount = 0
        var failedCount = 0
        let dispatchGroup = DispatchGroup()

        for (index, phaseInfo) in allPhaseEndTimes.enumerated() {
            let timeInterval = phaseInfo.endTime.timeIntervalSinceNow
            guard timeInterval > 0 else { continue }

            // Determine what the NEXT phase will be (what we're transitioning TO)
            let nextPhase = nextPhaseAfter(phaseInfo.phase, interval: phaseInfo.interval)

            let content = UNMutableNotificationContent()
            content.title = notificationTitle(for: nextPhase)
            content.subtitle = "Interval \(phaseInfo.interval) of \(configuration.totalIntervals)"
            content.body = notificationBody(for: phaseInfo.phase, interval: phaseInfo.interval)

            // MAXIMUM ATTENTION: Use critical alert sound (loudest possible)
            // This plays even when phone is on silent/vibrate
            content.sound = notificationSound(for: nextPhase)

            // Time-sensitive to break through Focus modes and DND
            content.interruptionLevel = .timeSensitive

            // Add category for quick actions
            content.categoryIdentifier = "IWT_PHASE_TRANSITION"

            // Note: Don't set badge for phase notifications - these are transient alerts
            // and shouldn't persist on the app icon after the session ends

            // Use calendar-based trigger for absolute date reliability
            // This is more reliable than time interval for long-running sessions
            let dateComponents = Calendar.current.dateComponents(
                [.year, .month, .day, .hour, .minute, .second],
                from: phaseInfo.endTime
            )
            let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: false)

            let request = UNNotificationRequest(
                identifier: "\(phaseNotificationIdentifier).\(index)",
                content: content,
                trigger: trigger
            )

            dispatchGroup.enter()
            UNUserNotificationCenter.current().add(request) { error in
                if let error = error {
                    print("⚠️ Failed to schedule notification \(index): \(error)")
                    failedCount += 1
                } else {
                    scheduledCount += 1
                    let formatter = DateFormatter()
                    formatter.timeStyle = .medium
                    print("✅ Notification \(index) scheduled for \(formatter.string(from: phaseInfo.endTime)) → \(nextPhase.rawValue)")
                }
                dispatchGroup.leave()
            }
        }

        // Verify all notifications were scheduled after completion
        dispatchGroup.notify(queue: .main) { [weak self] in
            print("🔔 Scheduling complete: \(scheduledCount)/\(totalToSchedule) notifications scheduled")
            if failedCount > 0 {
                print("⚠️ \(failedCount) notifications failed to schedule")
            }

            // Verify pending notifications match expected count
            self?.verifyPendingNotifications(expected: scheduledCount)
        }
    }

    /// Verify that all expected notifications are pending in the system
    private func verifyPendingNotifications(expected: Int) {
        UNUserNotificationCenter.current().getPendingNotificationRequests { requests in
            let iwtRequests = requests.filter { $0.identifier.hasPrefix("iwt.phase") }
            print("📋 Verification: \(iwtRequests.count) IWT notifications pending (expected: \(expected))")

            if iwtRequests.count < expected {
                print("⚠️ ALERT: Some notifications may not have been scheduled correctly!")
            }

            // Log each pending notification for debugging
            for request in iwtRequests.sorted(by: { $0.identifier < $1.identifier }) {
                if let trigger = request.trigger as? UNCalendarNotificationTrigger,
                   let nextDate = trigger.nextTriggerDate() {
                    let formatter = DateFormatter()
                    formatter.timeStyle = .medium
                    print("  📅 \(request.identifier): \(formatter.string(from: nextDate))")
                } else if let trigger = request.trigger as? UNTimeIntervalNotificationTrigger {
                    print("  ⏱️ \(request.identifier): in \(Int(trigger.timeInterval))s")
                }
            }
        }
    }

    /// Determine what the next phase will be after a given phase ends
    /// Phase order: Easy (slow) → Brisk → Easy → Brisk...
    private func nextPhaseAfter(_ phase: IWTPhase, interval: Int) -> IWTPhase {
        switch phase {
        case .warmup:
            return .slow  // Warmup → Easy
        case .slow:
            return .brisk  // Easy → Brisk
        case .brisk:
            // Brisk → check if done or next Easy
            if interval >= configuration.totalIntervals {
                return configuration.enableCooldown ? .cooldown : .completed
            } else {
                return .slow  // Next Easy
            }
        case .cooldown:
            return .completed
        default:
            return .completed
        }
    }

    /// Get attention-grabbing notification title based on next phase
    private func notificationTitle(for nextPhase: IWTPhase) -> String {
        switch nextPhase {
        case .brisk:
            return "⚡️ SPEED UP NOW"
        case .slow:
            return "🚶 SLOW DOWN"
        case .cooldown:
            return "❄️ COOL DOWN"
        case .completed:
            return "🎉 SESSION COMPLETE"
        default:
            return "Just Walk"
        }
    }

    /// Get appropriate notification sound for maximum attention
    /// Uses tri-tone or other system sounds for more noticeable alerts
    /// Time-sensitive interruption level is set to break through Focus modes
    private func notificationSound(for nextPhase: IWTPhase) -> UNNotificationSound {
        // Use different system sounds based on phase for audio distinction
        // These sounds are more attention-grabbing than the default
        switch nextPhase {
        case .brisk:
            // Upbeat, energizing sound for "speed up" - tri-tone repeated
            return UNNotificationSound(named: UNNotificationSoundName("tri-tone"))
        case .slow:
            // Calmer sound for "slow down"
            return UNNotificationSound(named: UNNotificationSoundName("chime"))
        case .cooldown:
            // Gentle reminder for cooldown
            return UNNotificationSound(named: UNNotificationSoundName("glass"))
        case .completed:
            // Celebration sound
            return UNNotificationSound(named: UNNotificationSoundName("fanfare"))
        default:
            return UNNotificationSound.default
        }
    }

    /// Register notification categories for phase transitions
    /// Only dismiss action is available - no "Open" or "Pause" buttons on Apple Watch
    static func registerNotificationCategories() {
        let phaseCategory = UNNotificationCategory(
            identifier: "IWT_PHASE_TRANSITION",
            actions: [],  // No custom actions - only dismiss
            intentIdentifiers: [],
            options: []
        )

        UNUserNotificationCenter.current().setNotificationCategories([phaseCategory])
    }

    /// Schedule a local notification for the next phase transition (legacy single-phase method)
    private func schedulePhaseNotification() {
        guard isSessionActive, !isPaused, sessionMode == .interval else { return }
        guard let endTime = phaseEndTime, endTime > Date() else { return }

        let content = UNMutableNotificationContent()
        content.title = "Just Walk"
        content.body = nextPhaseNotificationBody()
        content.sound = .default
        content.interruptionLevel = .timeSensitive

        let timeInterval = endTime.timeIntervalSinceNow
        guard timeInterval > 0 else { return }

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: timeInterval, repeats: false)
        let request = UNNotificationRequest(
            identifier: phaseNotificationIdentifier,
            content: content,
            trigger: trigger
        )

        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("⚠️ Failed to schedule phase notification: \(error)")
            } else {
                print("🔔 Scheduled phase notification for \(timeInterval)s from now")
            }
        }
    }

    /// Cancel any pending phase notifications
    private func cancelPhaseNotifications() {
        // Cancel all indexed notifications (max 15 = warmup + 5 intervals × 2 + cooldown + buffer)
        let maxPhaseNotifications = 15
        let identifiers = (0..<maxPhaseNotifications).map { "\(phaseNotificationIdentifier).\($0)" } + [phaseNotificationIdentifier]
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: identifiers)
        print("🔕 Cancelled pending phase notifications")
    }

    /// Generate notification body for a specific phase
    private func notificationBody(for phase: IWTPhase, interval: Int) -> String {
        switch phase {
        case .warmup:
            return "🏃 Time for Brisk Walk! Pick up the pace."
        case .brisk:
            return "🚶 Recovery time. Slow down and catch your breath."
        case .slow:
            if interval >= configuration.totalIntervals {
                return "❄️ Final stretch - Cool Down time!"
            } else {
                return "🏃 Brisk Walk interval \(interval + 1)! Let's go!"
            }
        case .cooldown:
            return "🎉 Session Complete! Great work!"
        default:
            return "Phase transition"
        }
    }

    /// Generate notification body for next phase (legacy method)
    private func nextPhaseNotificationBody() -> String {
        notificationBody(for: currentPhase, interval: currentInterval)
    }

    // MARK: - Formatted Time

    var formattedPhaseTime: String {
        let minutes = Int(phaseTimeRemaining) / 60
        let seconds = Int(phaseTimeRemaining) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    var formattedTotalTime: String {
        let hours = Int(totalElapsedTime) / 3600
        let minutes = (Int(totalElapsedTime) % 3600) / 60
        let seconds = Int(totalElapsedTime) % 60

        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%02d:%02d", minutes, seconds)
        }
    }

    var phaseProgress: Double {
        if sessionMode == .classic { return 0 }
        let duration = currentPhaseDuration()
        guard duration > 0 else { return 0 }
        return 1.0 - (phaseTimeRemaining / duration)
    }
    
    var sessionProgress: Double {
        if sessionMode == .classic { return 0 }
        guard configuration.totalDuration > 0 else { return 0 }
        return min(1.0, totalElapsedTime / configuration.totalDuration)
    }
    
    // MARK: - Watch Sync
    
    
    // Note: startHeartbeat and sendHeartbeat removed - devices now operate independently for workout control
    
    /// Sync phase state from remote heartbeat
    func syncFromRemote(phaseName: String, phaseEndTime: Date?, interval: Int, isPaused: Bool) {
        guard isSessionActive else { return }
        guard isRemoteSession else { return } // Only sync state if we're following the Watch
        
        // Sync pause state
        if isPaused && !self.isPaused {
            self.isPaused = true
            timerTask?.cancel()
            timerTask = nil
            currentPhase = .paused
        } else if !isPaused && self.isPaused {
            self.isPaused = false
            if let savedPhase = IWTPhase(rawValue: phaseName) {
                currentPhase = savedPhase
            }
            startTimer()
        }
        
        // Sync phase for interval mode
        if sessionMode == .interval, !self.isPaused {
            if let newPhase = IWTPhase(rawValue: phaseName), currentPhase != newPhase && newPhase != .paused {
                currentPhase = newPhase
                playPhaseChangeHaptic()
                onPhaseChange?(currentPhase)
            }
            
            currentInterval = interval
            
            if let endTime = phaseEndTime {
                // Calculate phaseTimeRemaining from phaseEndTime
                phaseTimeRemaining = max(0, endTime.timeIntervalSinceNow)
                // Sync phaseStartTime for accurate countdown
                let duration = currentPhaseDuration()
                phaseStartTime = endTime.addingTimeInterval(-duration)
                // Store absolute phase end time for perfect sync
                _phaseEndTime = endTime
            }
        }
    }

    // MARK: - Haptics

    private func prepareHaptics() {
        guard CHHapticEngine.capabilitiesForHardware().supportsHaptics else { return }

        do {
            hapticEngine = try CHHapticEngine()
            try hapticEngine?.start()
        } catch {
            print("Haptic engine failed to start: \(error)")
        }
    }

    /// Brisk start: 3 quick taps (energizing pattern)
    private func playBriskStartHaptic() {
        let generator = UIImpactFeedbackGenerator(style: .heavy)
        generator.prepare()
        Task {
            for _ in 0..<3 {
                generator.impactOccurred(intensity: 1.0)
                try? await Task.sleep(nanoseconds: 100_000_000) // 0.1s
            }
        }
    }

    /// Easy start: 2 slow taps (calming pattern)
    private func playEasyStartHaptic() {
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.prepare()
        Task {
            generator.impactOccurred(intensity: 0.8)
            try? await Task.sleep(nanoseconds: 300_000_000) // 0.3s
            generator.impactOccurred(intensity: 0.6)
        }
    }

    private func playPhaseChangeHaptic() {
        guard CHHapticEngine.capabilitiesForHardware().supportsHaptics,
              let engine = hapticEngine else {
            // Fallback to UIKit haptics
            playFallbackPhaseHaptic()
            return
        }

        // Ensure engine is started
        try? engine.start()

        var events: [CHHapticEvent] = []

        // ===== INTENSE PHASE CHANGE PATTERN =====
        // Similar to notification haptic but slightly shorter for in-app use

        // OPENING DOUBLE BURST (attention grabbing)
        events.append(CHHapticEvent(
            eventType: .hapticTransient,
            parameters: [
                CHHapticEventParameter(parameterID: .hapticIntensity, value: 1.0),
                CHHapticEventParameter(parameterID: .hapticSharpness, value: 1.0)
            ],
            relativeTime: 0
        ))
        events.append(CHHapticEvent(
            eventType: .hapticTransient,
            parameters: [
                CHHapticEventParameter(parameterID: .hapticIntensity, value: 1.0),
                CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.8)
            ],
            relativeTime: 0.08
        ))

        // RISING RUMBLE
        events.append(CHHapticEvent(
            eventType: .hapticContinuous,
            parameters: [
                CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.85),
                CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.4)
            ],
            relativeTime: 0.15,
            duration: 0.2
        ))

        // TRIPLE BURST (reinforcement)
        for i in 0..<3 {
            events.append(CHHapticEvent(
                eventType: .hapticTransient,
                parameters: [
                    CHHapticEventParameter(parameterID: .hapticIntensity, value: 1.0),
                    CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.9)
                ],
                relativeTime: 0.4 + Double(i) * 0.08
            ))
        }

        // DEEP RUMBLE
        events.append(CHHapticEvent(
            eventType: .hapticContinuous,
            parameters: [
                CHHapticEventParameter(parameterID: .hapticIntensity, value: 1.0),
                CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.2)
            ],
            relativeTime: 0.7,
            duration: 0.25
        ))

        // FINAL DOUBLE TAP
        events.append(CHHapticEvent(
            eventType: .hapticTransient,
            parameters: [
                CHHapticEventParameter(parameterID: .hapticIntensity, value: 1.0),
                CHHapticEventParameter(parameterID: .hapticSharpness, value: 1.0)
            ],
            relativeTime: 1.0
        ))
        events.append(CHHapticEvent(
            eventType: .hapticTransient,
            parameters: [
                CHHapticEventParameter(parameterID: .hapticIntensity, value: 1.0),
                CHHapticEventParameter(parameterID: .hapticSharpness, value: 1.0)
            ],
            relativeTime: 1.06
        ))

        do {
            let pattern = try CHHapticPattern(events: events, parameters: [])
            let player = try engine.makePlayer(with: pattern)
            try player.start(atTime: 0)
        } catch {
            print("Failed to play haptic: \(error)")
            playFallbackPhaseHaptic()
        }
    }

    /// Fallback haptic using UIKit generators when CoreHaptics unavailable
    private func playFallbackPhaseHaptic() {
        let heavyGenerator = UIImpactFeedbackGenerator(style: .heavy)
        let notificationGenerator = UINotificationFeedbackGenerator()

        heavyGenerator.prepare()
        notificationGenerator.prepare()

        Task { @MainActor in
            heavyGenerator.impactOccurred(intensity: 1.0)
            try? await Task.sleep(nanoseconds: 100_000_000)
            heavyGenerator.impactOccurred(intensity: 1.0)
            try? await Task.sleep(nanoseconds: 150_000_000)
            notificationGenerator.notificationOccurred(.warning)
            try? await Task.sleep(nanoseconds: 150_000_000)
            heavyGenerator.impactOccurred(intensity: 1.0)
        }
    }

    private func playPauseHaptic() {
        guard CHHapticEngine.capabilitiesForHardware().supportsHaptics,
              let engine = hapticEngine else { return }

        let intensity = CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.5)
        let sharpness = CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.3)

        let event = CHHapticEvent(
            eventType: .hapticTransient,
            parameters: [intensity, sharpness],
            relativeTime: 0
        )

        do {
            let pattern = try CHHapticPattern(events: [event], parameters: [])
            let player = try engine.makePlayer(with: pattern)
            try player.start(atTime: 0)
        } catch {
            print("Failed to play haptic: \(error)")
        }
    }

    private func playResumeHaptic() {
        playPauseHaptic() // Same haptic for resume
    }

    private func playCompletionHaptic() {
        guard CHHapticEngine.capabilitiesForHardware().supportsHaptics,
              let engine = hapticEngine else { return }

        var events: [CHHapticEvent] = []

        // Celebration pattern - rising intensity
        for i in 0..<4 {
            let intensity = CHHapticEventParameter(
                parameterID: .hapticIntensity,
                value: Float(0.4 + Double(i) * 0.2)
            )
            let sharpness = CHHapticEventParameter(
                parameterID: .hapticSharpness,
                value: Float(0.3 + Double(i) * 0.15)
            )

            events.append(CHHapticEvent(
                eventType: .hapticTransient,
                parameters: [intensity, sharpness],
                relativeTime: Double(i) * 0.12
            ))
        }

        do {
            let pattern = try CHHapticPattern(events: events, parameters: [])
            let player = try engine.makePlayer(with: pattern)
            try player.start(atTime: 0)
        } catch {
            print("Failed to play haptic: \(error)")
        }
    }
}

// MARK: - Session Summary

struct IWTSessionSummary {
    let startTime: Date
    let endTime: Date
    let totalDuration: TimeInterval
    let briskIntervals: Int
    let slowIntervals: Int
    let configuration: IWTConfiguration
    let completedSuccessfully: Bool
    let steps: Int
    let distance: Double
    let averageHeartRate: Double
    let activeCalories: Double

    var formattedDuration: String {
        let minutes = Int(totalDuration) / 60
        let seconds = Int(totalDuration) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    var totalIntervalMinutes: Int {
        Int((Double(briskIntervals) * configuration.briskDuration +
             Double(slowIntervals) * configuration.slowDuration) / 60)
    }
}
