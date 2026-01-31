import Foundation
import Combine
import WatchConnectivity
import WidgetKit

/// Manages communication with iPhone from Apple Watch
final class WatchConnectivityManager: NSObject, ObservableObject {

    // MARK: - Complication Push Keys (must match iPhone)
    private enum ComplicationKey {
        static let isComplicationUpdate = "isComplicationUpdate"
        static let todaySteps = "complication_todaySteps"
        static let stepGoal = "complication_stepGoal"
        static let currentStreak = "complication_currentStreak"
        static let timestamp = "complication_timestamp"
    }

    // MARK: - Singleton
    static let shared = WatchConnectivityManager()

    // MARK: - Published State
    @Published private(set) var isPhoneReachable = false

    // MARK: - Callbacks
    /// Callback for starting workout: (walkId, startTime, intervalData, modeRaw, zoneLow, zoneHigh)
    var onStartWorkoutCommand: ((UUID, Date?, IntervalTransferData?, String?, Int?, Int?) -> Void)?
    var onPauseWorkoutCommand: (() -> Void)?
    var onResumeWorkoutCommand: (() -> Void)?
    var onEndWorkoutCommand: (() -> Void)?

    // MARK: - Private
    private var session: WCSession?

    // MARK: - Initialization

    private override init() {
        super.init()
        setupSession()
    }

    private func setupSession() {
        guard WCSession.isSupported() else { return }

        session = WCSession.default
        session?.delegate = self
        session?.activate()
    }

    // MARK: - Send to iPhone

    func sendWorkoutStarted(walkId: UUID) {
        let message: [String: Any] = [
            WatchMessage.Key.command.rawValue: WatchMessage.Event.workoutStarted.rawValue,
            WatchMessage.Key.walkId.rawValue: walkId.uuidString
        ]
        sendMessage(message)
    }

    func sendWorkoutPaused() {
        let message: [String: Any] = [
            WatchMessage.Key.command.rawValue: WatchMessage.Event.workoutPaused.rawValue
        ]
        sendMessage(message)
    }

    func sendWorkoutResumed() {
        let message: [String: Any] = [
            WatchMessage.Key.command.rawValue: WatchMessage.Event.workoutResumed.rawValue
        ]
        sendMessage(message)
    }

    func sendWorkoutEnded(summary: WorkoutSummaryData) {
        guard let data = try? JSONEncoder().encode(summary) else { return }

        let message: [String: Any] = [
            WatchMessage.Key.command.rawValue: WatchMessage.Event.workoutEnded.rawValue,
            WatchMessage.Key.workoutData.rawValue: data
        ]
        sendMessage(message)
    }

    func sendStatsUpdate(stats: WorkoutLiveStats) {
        guard let data = try? JSONEncoder().encode(stats) else { return }

        let message: [String: Any] = [
            WatchMessage.Key.command.rawValue: WatchMessage.Event.statsUpdate.rawValue,
            WatchMessage.Key.workoutData.rawValue: data
        ]

        // Use unreliable send for frequent updates (don't queue)
        session?.sendMessage(message, replyHandler: nil, errorHandler: nil)
    }

    func sendWorkoutError(_ error: String) {
        let message: [String: Any] = [
            WatchMessage.Key.command.rawValue: WatchMessage.Event.workoutError.rawValue,
            WatchMessage.Key.error.rawValue: error
        ]
        sendMessage(message)
    }

    /// Send heart rate update to iPhone for Fat Burn Zone real-time monitoring
    func sendHeartRateUpdate(bpm: Int) {
        let message: [String: Any] = [
            WatchMessage.Key.command.rawValue: WatchMessage.Event.heartRateUpdate.rawValue,
            WatchMessage.Key.heartRate.rawValue: bpm
        ]
        // Use unreliable send for frequent HR updates (don't queue if not reachable)
        session?.sendMessage(message, replyHandler: nil, errorHandler: nil)
    }

    /// Send fat burn out-of-range (below zone) haptic trigger to iPhone
    func sendFatBurnOutOfRangeLow() {
        let message: [String: Any] = [
            WatchMessage.Key.command.rawValue: WatchMessage.Event.fatBurnOutOfRangeLow.rawValue
        ]
        // Best-effort send for haptic trigger
        session?.sendMessage(message, replyHandler: nil, errorHandler: nil)
    }

    /// Send fat burn out-of-range (above zone) haptic trigger to iPhone
    func sendFatBurnOutOfRangeHigh() {
        let message: [String: Any] = [
            WatchMessage.Key.command.rawValue: WatchMessage.Event.fatBurnOutOfRangeHigh.rawValue
        ]
        // Best-effort send for haptic trigger
        session?.sendMessage(message, replyHandler: nil, errorHandler: nil)
    }

    // MARK: - Private

    private func sendMessage(_ message: [String: Any]) {
        guard let session = session else { return }

        if session.isReachable {
            session.sendMessage(message, replyHandler: nil) { error in
                print("Failed to send message to iPhone: \(error)")
                // Fallback to transfer
                session.transferUserInfo(message)
            }
        } else {
            // Queue for delivery
            session.transferUserInfo(message)
        }
    }

    // MARK: - Streak Info Sync

    private func handleStreakInfoSync(_ message: [String: Any]) {
        let currentStreak = message[WatchMessage.Key.streakCurrent.rawValue] as? Int ?? 0
        let longestStreak = message[WatchMessage.Key.streakLongest.rawValue] as? Int ?? 0
        let dailyGoal = message[WatchMessage.Key.dailyGoal.rawValue] as? Int ?? 5000

        let streakInfo = WatchStreakInfo(
            currentStreak: currentStreak,
            longestStreak: longestStreak,
            lastGoalMetDate: nil,
            dailyStepGoal: dailyGoal
        )

        WatchPersistenceManager.shared.saveStreakInfo(streakInfo)
        print("Watch: Synced streak info - streak: \(currentStreak), goal: \(dailyGoal)")
    }

    // MARK: - Complication Push Handler (Industry-Leading Refresh)

    /// Handle complication data pushed from iPhone via transferCurrentComplicationUserInfo().
    /// This is the fastest path to update complications - it has priority delivery and
    /// uses a separate budget from WidgetKit reloads.
    private func handleComplicationPush(_ userInfo: [String: Any]) -> Bool {
        // Check if this is a complication update
        guard userInfo[ComplicationKey.isComplicationUpdate] as? Bool == true else {
            return false
        }

        let todaySteps = userInfo[ComplicationKey.todaySteps] as? Int ?? 0
        let stepGoal = userInfo[ComplicationKey.stepGoal] as? Int ?? 5000
        let currentStreak = userInfo[ComplicationKey.currentStreak] as? Int ?? 0

        // Update shared App Group data for widgets
        let defaults = UserDefaults(suiteName: "group.com.justwalk.shared")
        defaults?.set(todaySteps, forKey: "widget_todaySteps")
        defaults?.set(stepGoal, forKey: "widget_stepGoal")
        defaults?.set(currentStreak, forKey: "widget_currentStreak")

        // Immediately reload all widget timelines - this is the key to fast updates!
        WidgetCenter.shared.reloadAllTimelines()

        print("Watch: Complication push received - \(todaySteps) steps, reloading widgets immediately")
        return true
    }

    private func handleReceivedMessage(_ message: [String: Any]) {
        guard let commandString = message[WatchMessage.Key.command.rawValue] as? String,
              let command = WatchMessage.Command(rawValue: commandString) else { return }

        DispatchQueue.main.async {
            switch command {
            case .startWorkout:
                if let walkIdString = message[WatchMessage.Key.walkId.rawValue] as? String,
                   let walkId = UUID(uuidString: walkIdString) {
                    // Parse authoritative start time from initiating device
                    var startTime: Date?
                    if let timestamp = message[WatchMessage.Key.startTime.rawValue] as? TimeInterval {
                        startTime = Date(timeIntervalSince1970: timestamp)
                    }
                    // Parse interval data if present
                    var intervalData: IntervalTransferData?
                    if let data = message[WatchMessage.Key.intervalData.rawValue] as? Data {
                        intervalData = try? JSONDecoder().decode(IntervalTransferData.self, from: data)
                    }
                    // Extract mode and fat burn zone data
                    let modeRaw = message[WatchMessage.Key.modeRaw.rawValue] as? String
                    let zoneLow = message[WatchMessage.Key.zoneLow.rawValue] as? Int
                    let zoneHigh = message[WatchMessage.Key.zoneHigh.rawValue] as? Int

                    print("Watch: Received startWorkout - mode: \(modeRaw ?? "nil"), startTime: \(startTime?.description ?? "nil")")
                    self.onStartWorkoutCommand?(walkId, startTime, intervalData, modeRaw, zoneLow, zoneHigh)
                }

            case .pauseWorkout:
                self.onPauseWorkoutCommand?()

            case .resumeWorkout:
                self.onResumeWorkoutCommand?()

            case .endWorkout:
                self.onEndWorkoutCommand?()

            case .syncState:
                // Handle state sync request
                break

            case .phaseChangeHaptic:
                WatchHaptics.phaseChange()

            case .countdownWarningHaptic:
                WatchHaptics.countdownWarning()

            case .milestoneHaptic:
                WatchHaptics.progressMilestone()

            case .syncStreakInfo:
                self.handleStreakInfoSync(message)
            }
        }
    }
}

// MARK: - WCSessionDelegate

extension WatchConnectivityManager: WCSessionDelegate {

    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        DispatchQueue.main.async {
            self.isPhoneReachable = session.isReachable
        }
    }

    func sessionReachabilityDidChange(_ session: WCSession) {
        DispatchQueue.main.async {
            self.isPhoneReachable = session.isReachable
        }
    }

    func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        handleReceivedMessage(message)
    }

    func session(_ session: WCSession, didReceiveMessage message: [String: Any], replyHandler: @escaping ([String: Any]) -> Void) {
        handleReceivedMessage(message)
        replyHandler(["received": true])
    }

    func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any]) {
        // Priority: Check for complication push first (from transferCurrentComplicationUserInfo)
        if handleComplicationPush(userInfo) {
            return // Complication update handled, don't process as regular message
        }
        handleReceivedMessage(userInfo)
    }

    func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        // Handle app context if needed
        // This can trigger workout start even if app was not running
        handleReceivedMessage(applicationContext)
    }
}
