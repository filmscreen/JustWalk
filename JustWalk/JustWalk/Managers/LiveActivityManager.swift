//
//  LiveActivityManager.swift
//  JustWalk
//
//  Live Activity support for lock screen and Dynamic Island during walks
//

import Foundation
import ActivityKit

@Observable
class LiveActivityManager {
    static let shared = LiveActivityManager()
    static let promptNotification = Notification.Name("liveActivity_promptNeeded")
    static let promptModeKey = "mode"

    private var currentActivity: Activity<WalkActivityAttributes>?
    private static let promptShownKey = "liveActivity_promptShown"

    /// Time interval after which the activity becomes stale if not updated.
    /// If the app crashes, is killed, or deleted, the activity will dim after this time
    /// and eventually be removed by the system. 10 minutes gives enough buffer for
    /// background execution during long walks while ensuring orphaned activities
    /// don't persist for hours.
    private static let staleInterval: TimeInterval = 600 // 10 minutes

    // MARK: - Persisted Preference

    var isEnabled: Bool {
        didSet { UserDefaults.standard.set(isEnabled, forKey: "liveActivity_isEnabled") }
    }

    private init() {
        let defaults = UserDefaults.standard
        defaults.register(defaults: [
            "liveActivity_isEnabled": true
        ])

        self.isEnabled = defaults.bool(forKey: "liveActivity_isEnabled")
    }

    // MARK: - Activity Lifecycle

    func startActivity(mode: WalkMode, intervalProgram: IntervalProgram?, intervalPhaseRemaining: Int? = nil, intervalPhaseEndDate: Date? = nil, intervalPhaseType: String? = nil) {
        guard isEnabled else { return }
        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            notifyIfPromptNeeded(mode: mode)
            return
        }

        let attributes = WalkActivityAttributes(
            mode: mode.rawValue,
            intervalProgram: intervalProgram?.displayName,
            intervalDuration: intervalProgram?.duration
        )

        let phaseEndDate = intervalPhaseEndDate ?? intervalPhaseRemaining.map { Date().addingTimeInterval(TimeInterval($0)) }
        let initialState = WalkActivityAttributes.ContentState(
            startDate: Date(),
            elapsedSeconds: 0,
            steps: 0,
            distance: 0,
            isPaused: false,
            intervalPhaseRemaining: intervalPhaseRemaining,
            intervalPhaseEndDate: phaseEndDate,
            intervalPhaseType: intervalPhaseType
        )

        do {
            // Use pushType: nil to indicate this activity only receives local updates.
            // This avoids the "Allow" / "Always Allow" lock screen authorization prompt
            // that appears when push notification capability is requested.
            currentActivity = try Activity.request(
                attributes: attributes,
                content: .init(state: initialState, staleDate: Date().addingTimeInterval(Self.staleInterval)),
                pushType: nil
            )
        } catch {
            print("Failed to start Live Activity: \(error)")
        }
    }

    func updateProgress(elapsedSeconds: Int, steps: Int, distance: Double, intervalPhaseRemaining: Int? = nil, intervalPhaseEndDate: Date? = nil, intervalPhaseType: String? = nil) {
        let phaseEndDate = intervalPhaseEndDate ?? intervalPhaseRemaining.map { Date().addingTimeInterval(TimeInterval($0)) }
        let state = WalkActivityAttributes.ContentState(
            startDate: Date().addingTimeInterval(-TimeInterval(elapsedSeconds)),
            elapsedSeconds: elapsedSeconds,
            steps: steps,
            distance: distance,
            isPaused: false,
            intervalPhaseRemaining: intervalPhaseRemaining,
            intervalPhaseEndDate: phaseEndDate,
            intervalPhaseType: intervalPhaseType
        )

        Task {
            await currentActivity?.update(.init(state: state, staleDate: Date().addingTimeInterval(Self.staleInterval)))
        }
    }

    func updatePaused(_ isPaused: Bool, elapsedSeconds: Int, intervalPhaseRemaining: Int? = nil, intervalPhaseEndDate: Date? = nil, intervalPhaseType: String? = nil) {
        guard let activity = currentActivity else { return }

        var state = activity.content.state
        state.isPaused = isPaused
        state.elapsedSeconds = elapsedSeconds
        state.startDate = Date().addingTimeInterval(-TimeInterval(elapsedSeconds))
        if let intervalPhaseRemaining {
            state.intervalPhaseRemaining = intervalPhaseRemaining
            state.intervalPhaseEndDate = isPaused ? nil : (intervalPhaseEndDate ?? Date().addingTimeInterval(TimeInterval(intervalPhaseRemaining)))
        }
        if let intervalPhaseType {
            state.intervalPhaseType = intervalPhaseType
        }

        // Use longer stale interval when paused since updates are less frequent
        let pausedStaleInterval: TimeInterval = isPaused ? Self.staleInterval * 2 : Self.staleInterval
        Task {
            await activity.update(.init(state: state, staleDate: Date().addingTimeInterval(pausedStaleInterval)))
        }
    }

    func endActivity() {
        Task {
            await endAllActivities()
        }
    }

    func endAllActivities() async {
        if let activity = currentActivity {
            await activity.end(nil, dismissalPolicy: .immediate)
            currentActivity = nil
        }

        for activity in Activity<WalkActivityAttributes>.activities {
            await activity.end(nil, dismissalPolicy: .immediate)
        }
    }

    private func notifyIfPromptNeeded(mode: WalkMode) {
        let defaults = UserDefaults.standard
        guard !defaults.bool(forKey: Self.promptShownKey) else { return }
        defaults.set(true, forKey: Self.promptShownKey)
        NotificationCenter.default.post(
            name: Self.promptNotification,
            object: nil,
            userInfo: [Self.promptModeKey: mode.rawValue]
        )
    }
}
