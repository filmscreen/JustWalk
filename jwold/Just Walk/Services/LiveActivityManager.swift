//
//  LiveActivityManager.swift
//  Just Walk
//
//  Manages Live Activity lifecycle for Interval Walk sessions.
//  Uses Live Activities as the primary mechanism for background persistence
//  to ensure 100% notification reliability.
//

import Foundation
import ActivityKit
import UserNotifications
import Combine

// Import the shared attributes from the widget extension
// Note: IWTActivityAttributes is defined in SimpleWalkWidgetsLiveActivity.swift
// and needs to be accessible to both the main app and widget extension

/// Manages Live Activity lifecycle for IWT sessions
/// Decouples notification triggering from UI updates for reliability
@MainActor
final class LiveActivityManager: ObservableObject {

    static let shared = LiveActivityManager()

    // MARK: - Published State

    @Published private(set) var isActivityActive = false
    @Published private(set) var currentActivity: Activity<IWTActivityAttributes>?

    // MARK: - Phase Tracking (Decoupled from UI)

    /// Pre-calculated phase schedule with absolute times
    /// This is the source of truth for phase transitions
    private var phaseSchedule: [ScheduledPhase] = []

    /// Current phase index in the schedule
    private var currentPhaseIndex: Int = 0

    /// Background task for phase monitoring
    private var phaseMonitorTask: Task<Void, Never>?

    /// Timer for periodic phase checks
    private var phaseCheckTimer: Timer?

    // MARK: - Configuration

    private var sessionConfiguration: IWTConfiguration?

    /// Current session step count
    private var currentSessionSteps: Int = 0

    /// Last reported step milestone (for batched updates)
    private var lastReportedStepMilestone: Int = 0

    /// Settings key for Live Activity enabled toggle
    private static let liveActivityEnabledKey = "liveActivityEnabled"

    /// Whether Live Activity is enabled in settings
    var isLiveActivityEnabled: Bool {
        get { UserDefaults.standard.object(forKey: Self.liveActivityEnabledKey) as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: Self.liveActivityEnabledKey) }
    }

    private init() {}

    // MARK: - Phase Schedule Structure

    struct ScheduledPhase {
        let phase: IWTPhase
        let interval: Int
        let startTime: Date
        let endTime: Date
        let notificationScheduled: Bool
    }

    // MARK: - Live Activity Lifecycle

    /// Start a Live Activity for an IWT session
    /// - Parameters:
    ///   - startTime: Session start time
    ///   - configuration: IWT configuration for phase calculation
    func startActivity(startTime: Date, configuration: IWTConfiguration) async {
        // Check if Live Activity is enabled in settings
        guard isLiveActivityEnabled else {
            print("⚠️ Live Activity disabled in settings")
            return
        }

        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            print("⚠️ Live Activities are not enabled on this device")
            return
        }

        // Store configuration
        sessionConfiguration = configuration

        // Reset step tracking
        currentSessionSteps = 0
        lastReportedStepMilestone = 0

        // Calculate the complete phase schedule upfront
        calculatePhaseSchedule(from: startTime, configuration: configuration)

        // Schedule all notifications based on the phase schedule
        await scheduleAllPhaseNotifications()

        // Get first phase info
        guard let firstPhase = phaseSchedule.first else { return }
        let nextPhase = phaseSchedule[safe: 1]

        // Create initial content state with countdown timer info
        let initialState = createContentState(
            for: firstPhase.phase,
            interval: firstPhase.interval,
            isPaused: false,
            phaseEndTime: firstPhase.endTime,
            phaseDuration: firstPhase.endTime.timeIntervalSince(firstPhase.startTime),
            sessionSteps: 0,
            nextPhaseName: nextPhase?.phase.displayName,
            nextPhaseDuration: nextPhase.map { $0.endTime.timeIntervalSince($0.startTime) }
        )

        let attributes = IWTActivityAttributes(
            sessionStartTime: startTime,
            walkMode: "interval"
        )

        do {
            let activity = try Activity.request(
                attributes: attributes,
                content: .init(state: initialState, staleDate: nil),
                pushType: nil
            )

            currentActivity = activity
            isActivityActive = true

            print("✅ Live Activity started: \(activity.id)")

            // Start phase monitoring
            startPhaseMonitoring()

        } catch {
            print("❌ Failed to start Live Activity: \(error)")
        }
    }

    /// Update the Live Activity when a phase changes
    /// This is called when the phase actually transitions
    func updatePhase(_ phase: IWTPhase, interval: Int, isPaused: Bool) async {
        guard let activity = currentActivity,
              let currentSchedule = phaseSchedule[safe: currentPhaseIndex] else { return }

        // Get next phase info
        let nextPhaseSchedule = phaseSchedule[safe: currentPhaseIndex + 1]

        let newState = createContentState(
            for: phase,
            interval: interval,
            isPaused: isPaused,
            phaseEndTime: currentSchedule.endTime,
            phaseDuration: currentSchedule.endTime.timeIntervalSince(currentSchedule.startTime),
            sessionSteps: currentSessionSteps,
            nextPhaseName: nextPhaseSchedule?.phase.displayName,
            nextPhaseDuration: nextPhaseSchedule.map { $0.endTime.timeIntervalSince($0.startTime) }
        )

        await activity.update(
            ActivityContent(state: newState, staleDate: nil)
        )

        print("📱 Live Activity updated: \(phase.rawValue) - Interval \(interval)")
    }

    /// Update the step count in the Live Activity
    /// Uses batched updates (every 500 steps) to conserve battery
    func updateSteps(_ steps: Int) async {
        currentSessionSteps = steps

        // Only update Live Activity at 500-step milestones to conserve battery
        let currentMilestone = (steps / 500) * 500
        guard currentMilestone > lastReportedStepMilestone else { return }

        lastReportedStepMilestone = currentMilestone

        guard let activity = currentActivity,
              let schedule = phaseSchedule[safe: currentPhaseIndex] else { return }

        // Get next phase info
        let nextPhaseSchedule = phaseSchedule[safe: currentPhaseIndex + 1]

        let updatedState = createContentState(
            for: schedule.phase,
            interval: schedule.interval,
            isPaused: false,
            phaseEndTime: schedule.endTime,
            phaseDuration: schedule.endTime.timeIntervalSince(schedule.startTime),
            sessionSteps: steps,
            nextPhaseName: nextPhaseSchedule?.phase.displayName,
            nextPhaseDuration: nextPhaseSchedule.map { $0.endTime.timeIntervalSince($0.startTime) }
        )

        await activity.update(
            ActivityContent(state: updatedState, staleDate: nil)
        )

        print("👣 Live Activity steps updated: \(steps)")
    }

    /// Pause the Live Activity
    func pauseActivity() async {
        guard let activity = currentActivity,
              let schedule = phaseSchedule[safe: currentPhaseIndex] else { return }

        // Get next phase info
        let nextPhaseSchedule = phaseSchedule[safe: currentPhaseIndex + 1]

        let pausedState = createContentState(
            for: schedule.phase,
            interval: schedule.interval,
            isPaused: true,
            phaseEndTime: schedule.endTime,
            phaseDuration: schedule.endTime.timeIntervalSince(schedule.startTime),
            sessionSteps: currentSessionSteps,
            nextPhaseName: nextPhaseSchedule?.phase.displayName,
            nextPhaseDuration: nextPhaseSchedule.map { $0.endTime.timeIntervalSince($0.startTime) }
        )

        await activity.update(
            ActivityContent(state: pausedState, staleDate: nil)
        )

        // Stop phase monitoring while paused
        stopPhaseMonitoring()

        // Cancel pending notifications to prevent them firing during pause
        cancelAllNotifications()

        print("⏸️ Live Activity paused")
    }

    /// Resume the Live Activity
    func resumeActivity(adjustedSchedule: [Date]) async {
        guard let activity = currentActivity,
              let schedule = phaseSchedule[safe: currentPhaseIndex] else { return }

        // Get next phase info
        let nextPhaseSchedule = phaseSchedule[safe: currentPhaseIndex + 1]

        let resumedState = createContentState(
            for: schedule.phase,
            interval: schedule.interval,
            isPaused: false,
            phaseEndTime: schedule.endTime,
            phaseDuration: schedule.endTime.timeIntervalSince(schedule.startTime),
            sessionSteps: currentSessionSteps,
            nextPhaseName: nextPhaseSchedule?.phase.displayName,
            nextPhaseDuration: nextPhaseSchedule.map { $0.endTime.timeIntervalSince($0.startTime) }
        )

        await activity.update(
            ActivityContent(state: resumedState, staleDate: nil)
        )

        // Restart phase monitoring
        startPhaseMonitoring()

        // Reschedule notifications with adjusted times
        await scheduleAllPhaseNotifications()

        print("▶️ Live Activity resumed")
    }

    /// End the Live Activity
    func endActivity(completed: Bool = false) async {
        guard let activity = currentActivity else { return }

        // Stop phase monitoring
        stopPhaseMonitoring()

        // Cancel any pending notifications
        cancelAllNotifications()

        // Create final state with all new fields
        let finalState = IWTActivityAttributes.ContentState(
            phaseName: completed ? "Complete" : "Ended",
            phaseColorHex: completed ? "#AF52DE" : "#8E8E93",
            currentInterval: sessionConfiguration?.totalIntervals ?? 5,
            totalIntervals: sessionConfiguration?.totalIntervals ?? 5,
            statusMessage: completed ? "Great workout!" : "Session ended",
            isPaused: false,
            phaseIcon: completed ? "checkmark.circle.fill" : "xmark.circle.fill",
            elapsedSeconds: 0,
            phaseEndTime: Date(),
            phaseDuration: 0,
            sessionSteps: currentSessionSteps,
            nextPhaseName: nil,
            nextPhaseDuration: nil
        )

        await activity.end(
            ActivityContent(state: finalState, staleDate: nil),
            dismissalPolicy: .immediate
        )

        currentActivity = nil
        isActivityActive = false
        phaseSchedule.removeAll()
        currentPhaseIndex = 0
        currentSessionSteps = 0
        lastReportedStepMilestone = 0

        print("🏁 Live Activity ended")
    }

    // MARK: - Phase Schedule Calculation

    /// Calculate the complete phase schedule for the session
    /// This creates absolute timestamps for every phase transition
    private func calculatePhaseSchedule(from startTime: Date, configuration: IWTConfiguration) {
        phaseSchedule.removeAll()
        var currentTime = startTime

        // Warmup phase
        if configuration.enableWarmup {
            let warmupEnd = currentTime.addingTimeInterval(configuration.warmupDuration)
            phaseSchedule.append(ScheduledPhase(
                phase: .warmup,
                interval: 0,
                startTime: currentTime,
                endTime: warmupEnd,
                notificationScheduled: false
            ))
            currentTime = warmupEnd
        }

        // Interval phases (Brisk + Slow cycles)
        for interval in 1...configuration.totalIntervals {
            // Brisk phase
            let briskEnd = currentTime.addingTimeInterval(configuration.briskDuration)
            phaseSchedule.append(ScheduledPhase(
                phase: .brisk,
                interval: interval,
                startTime: currentTime,
                endTime: briskEnd,
                notificationScheduled: false
            ))
            currentTime = briskEnd

            // Slow/Recovery phase
            let slowEnd = currentTime.addingTimeInterval(configuration.slowDuration)
            phaseSchedule.append(ScheduledPhase(
                phase: .slow,
                interval: interval,
                startTime: currentTime,
                endTime: slowEnd,
                notificationScheduled: false
            ))
            currentTime = slowEnd
        }

        // Cooldown phase
        if configuration.enableCooldown {
            let cooldownEnd = currentTime.addingTimeInterval(configuration.cooldownDuration)
            phaseSchedule.append(ScheduledPhase(
                phase: .cooldown,
                interval: 0,
                startTime: currentTime,
                endTime: cooldownEnd,
                notificationScheduled: false
            ))
        }

        print("📅 Phase schedule calculated with \(phaseSchedule.count) phases")
        for (index, phase) in phaseSchedule.enumerated() {
            let formatter = DateFormatter()
            formatter.timeStyle = .medium
            print("  [\(index)] \(phase.phase.rawValue) - ends at \(formatter.string(from: phase.endTime))")
        }
    }

    // MARK: - Phase Monitoring

    /// Start monitoring for phase transitions
    /// Uses Task-based monitoring for reliable phase detection
    private func startPhaseMonitoring() {
        // Cancel any existing monitoring
        stopPhaseMonitoring()

        // Start a background task to monitor phases (single mechanism to avoid double-processing)
        phaseMonitorTask = Task { [weak self] in
            while !Task.isCancelled {
                await self?.checkForPhaseTransition()
                try? await Task.sleep(nanoseconds: 1_000_000_000) // Check every second
            }
        }

        print("👁️ Phase monitoring started")
    }

    /// Stop phase monitoring
    private func stopPhaseMonitoring() {
        phaseMonitorTask?.cancel()
        phaseMonitorTask = nil
        phaseCheckTimer?.invalidate()
        phaseCheckTimer = nil
        print("👁️ Phase monitoring stopped")
    }

    /// Check if we need to transition to a new phase
    private func checkForPhaseTransition() async {
        let now = Date()

        // Find which phase we should be in based on current time
        guard let currentScheduledPhase = phaseSchedule[safe: currentPhaseIndex] else { return }

        // Check if current phase has ended
        if now >= currentScheduledPhase.endTime {
            // Move to next phase
            let previousIndex = currentPhaseIndex
            currentPhaseIndex += 1

            if let nextPhase = phaseSchedule[safe: currentPhaseIndex] {
                // Update the Live Activity
                await updatePhase(nextPhase.phase, interval: nextPhase.interval, isPaused: false)

                // Notify IWTService of the phase change
                NotificationCenter.default.post(
                    name: .iwtPhaseDidChange,
                    object: nil,
                    userInfo: [
                        "phase": nextPhase.phase.rawValue,
                        "interval": nextPhase.interval,
                        "endTime": nextPhase.endTime
                    ]
                )

                print("⏩ Phase transition detected: \(phaseSchedule[previousIndex].phase.rawValue) → \(nextPhase.phase.rawValue)")
            } else {
                // Session complete
                await endActivity(completed: true)
                NotificationCenter.default.post(name: .iwtSessionDidComplete, object: nil)
            }
        }
    }

    // MARK: - Notification Scheduling

    /// Schedule all phase transition notifications upfront
    /// Uses calendar-based triggers for reliability
    private func scheduleAllPhaseNotifications() async {
        // Cancel existing notifications first
        cancelAllNotifications()

        // Register notification categories
        registerNotificationCategories()

        let center = UNUserNotificationCenter.current()

        for (index, scheduledPhase) in phaseSchedule.enumerated() {
            let timeUntilTransition = scheduledPhase.endTime.timeIntervalSinceNow
            guard timeUntilTransition > 0 else { continue }

            // Determine the NEXT phase (what we're transitioning TO)
            let nextPhase = phaseSchedule[safe: index + 1]?.phase ?? .completed

            let content = UNMutableNotificationContent()
            content.title = notificationTitle(for: nextPhase)
            content.subtitle = "Interval \(scheduledPhase.interval) of \(sessionConfiguration?.totalIntervals ?? 5)"
            content.body = notificationBody(transitioningFrom: scheduledPhase.phase, interval: scheduledPhase.interval)
            content.sound = notificationSound(for: nextPhase)
            content.interruptionLevel = .timeSensitive
            content.categoryIdentifier = "IWT_PHASE_TRANSITION"

            // Use time interval trigger to avoid midnight boundary issues
            // (Calendar triggers can fail for sessions spanning midnight)
            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: timeUntilTransition, repeats: false)

            let request = UNNotificationRequest(
                identifier: "iwt.phase.\(index)",
                content: content,
                trigger: trigger
            )

            do {
                try await center.add(request)
                let formatter = DateFormatter()
                formatter.timeStyle = .medium
                print("✅ Notification scheduled for \(formatter.string(from: scheduledPhase.endTime)) → \(nextPhase.rawValue)")
            } catch {
                print("⚠️ Failed to schedule notification \(index): \(error)")
            }
        }

        // Verify scheduled notifications
        await verifyScheduledNotifications()
    }

    /// Cancel all IWT notifications
    private func cancelAllNotifications() {
        // Max 15 = warmup + 5 intervals × 2 + cooldown + buffer
        let maxPhaseNotifications = 15
        let identifiers = (0..<maxPhaseNotifications).map { "iwt.phase.\($0)" }
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: identifiers)
        print("🔕 Cancelled all IWT notifications")
    }

    /// Verify notifications are properly scheduled
    private func verifyScheduledNotifications() async {
        let requests = await UNUserNotificationCenter.current().pendingNotificationRequests()
        let iwtRequests = requests.filter { $0.identifier.hasPrefix("iwt.phase") }
        print("📋 Verification: \(iwtRequests.count) IWT notifications pending")
    }

    /// Register notification action categories
    /// Only dismiss action is available - no "Open" or "Pause" buttons on Apple Watch
    private func registerNotificationCategories() {
        let category = UNNotificationCategory(
            identifier: "IWT_PHASE_TRANSITION",
            actions: [],  // No custom actions - only dismiss
            intentIdentifiers: [],
            options: []
        )

        UNUserNotificationCenter.current().setNotificationCategories([category])
    }

    // MARK: - Notification Content

    private func notificationTitle(for phase: IWTPhase) -> String {
        switch phase {
        case .brisk: return "⚡️ SPEED UP NOW"
        case .slow: return "🚶 SLOW DOWN"
        case .cooldown: return "❄️ COOL DOWN"
        case .completed: return "🎉 SESSION COMPLETE"
        case .warmup: return "🔥 WARM UP"
        default: return "Just Walk"
        }
    }

    private func notificationBody(transitioningFrom phase: IWTPhase, interval: Int) -> String {
        switch phase {
        case .warmup:
            return "🏃 Time for Brisk Walk! Pick up the pace."
        case .brisk:
            return "🚶 Recovery time. Slow down and catch your breath."
        case .slow:
            if interval >= (sessionConfiguration?.totalIntervals ?? 5) {
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

    private func notificationSound(for phase: IWTPhase) -> UNNotificationSound {
        switch phase {
        case .brisk:
            return UNNotificationSound(named: UNNotificationSoundName("tri-tone"))
        case .slow:
            return UNNotificationSound(named: UNNotificationSoundName("chime"))
        case .cooldown:
            return UNNotificationSound(named: UNNotificationSoundName("glass"))
        case .completed:
            return UNNotificationSound(named: UNNotificationSoundName("fanfare"))
        default:
            return .default
        }
    }

    // MARK: - Content State Creation

    private func createContentState(
        for phase: IWTPhase,
        interval: Int,
        isPaused: Bool,
        phaseEndTime: Date,
        phaseDuration: TimeInterval,
        sessionSteps: Int = 0,
        nextPhaseName: String? = nil,
        nextPhaseDuration: TimeInterval? = nil
    ) -> IWTActivityAttributes.ContentState {
        IWTActivityAttributes.ContentState(
            phaseName: phase.displayName,
            phaseColorHex: phase.colorHex,
            currentInterval: max(1, interval),
            totalIntervals: sessionConfiguration?.totalIntervals ?? 5,
            statusMessage: isPaused ? "Paused" : "In Progress",
            isPaused: isPaused,
            phaseIcon: phase.icon,
            elapsedSeconds: 0,
            phaseEndTime: phaseEndTime,
            phaseDuration: phaseDuration,
            sessionSteps: sessionSteps,
            nextPhaseName: nextPhaseName,
            nextPhaseDuration: nextPhaseDuration
        )
    }

    // MARK: - Adjust Schedule for Pause

    /// Adjust all remaining phase times when session is resumed after a pause
    func adjustScheduleForPause(pauseDuration: TimeInterval) {
        for i in currentPhaseIndex..<phaseSchedule.count {
            let phase = phaseSchedule[i]
            phaseSchedule[i] = ScheduledPhase(
                phase: phase.phase,
                interval: phase.interval,
                startTime: phase.startTime.addingTimeInterval(pauseDuration),
                endTime: phase.endTime.addingTimeInterval(pauseDuration),
                notificationScheduled: phase.notificationScheduled
            )
        }
        print("📅 Schedule adjusted by \(pauseDuration)s for pause")
    }

    // MARK: - Reschedule After Manual Skip

    /// Reschedule notifications after a manual phase skip
    /// Called by IWTService when user manually skips a phase
    func rescheduleAfterManualSkip(newPhaseEndTimes: [(phase: IWTPhase, interval: Int, endTime: Date)]) async {
        // Stop monitoring while we rebuild the schedule to prevent race conditions
        stopPhaseMonitoring()

        // Rebuild the internal phase schedule from the new times
        phaseSchedule.removeAll()
        var previousEndTime: Date?

        for (index, phaseInfo) in newPhaseEndTimes.enumerated() {
            let startTime: Date
            if let prev = previousEndTime {
                startTime = prev
            } else if index == 0 {
                // First phase starts from now (approximately)
                let duration: TimeInterval
                switch phaseInfo.phase {
                case .warmup: duration = sessionConfiguration?.warmupDuration ?? 120
                case .brisk: duration = sessionConfiguration?.briskDuration ?? 180
                case .slow: duration = sessionConfiguration?.slowDuration ?? 180
                case .cooldown: duration = sessionConfiguration?.cooldownDuration ?? 120
                default: duration = 0
                }
                startTime = phaseInfo.endTime.addingTimeInterval(-duration)
            } else {
                startTime = phaseInfo.endTime // Fallback
            }

            phaseSchedule.append(ScheduledPhase(
                phase: phaseInfo.phase,
                interval: phaseInfo.interval,
                startTime: startTime,
                endTime: phaseInfo.endTime,
                notificationScheduled: false
            ))

            previousEndTime = phaseInfo.endTime
        }

        currentPhaseIndex = 0

        print("📅 LiveActivityManager: Rebuilt schedule with \(phaseSchedule.count) phases after manual skip")

        // Reschedule all notifications
        await scheduleAllPhaseNotifications()

        // Restart phase monitoring with the new schedule
        startPhaseMonitoring()
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let iwtPhaseDidChange = Notification.Name("iwtPhaseDidChange")
    static let iwtSessionDidComplete = Notification.Name("iwtSessionDidComplete")
}

// MARK: - Array Safe Subscript

extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
