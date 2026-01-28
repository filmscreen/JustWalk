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

    private var currentActivity: Activity<WalkActivityAttributes>?

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

    func startActivity(mode: WalkMode, intervalProgram: IntervalProgram?) {
        guard isEnabled else { return }
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }

        let attributes = WalkActivityAttributes(
            mode: mode.rawValue,
            intervalProgram: intervalProgram?.displayName,
            intervalDuration: intervalProgram?.duration
        )

        let initialState = WalkActivityAttributes.ContentState(
            elapsedSeconds: 0,
            steps: 0,
            distance: 0,
            isPaused: false
        )

        do {
            currentActivity = try Activity.request(
                attributes: attributes,
                content: .init(state: initialState, staleDate: nil)
            )
        } catch {
            print("Failed to start Live Activity: \(error)")
        }
    }

    func updateProgress(elapsedSeconds: Int, steps: Int, distance: Double) {
        let state = WalkActivityAttributes.ContentState(
            elapsedSeconds: elapsedSeconds,
            steps: steps,
            distance: distance,
            isPaused: false
        )

        Task {
            await currentActivity?.update(.init(state: state, staleDate: nil))
        }
    }

    func updatePaused(_ isPaused: Bool) {
        guard let activity = currentActivity else { return }

        var state = activity.content.state
        state.isPaused = isPaused

        Task {
            await activity.update(.init(state: state, staleDate: nil))
        }
    }

    func endActivity() {
        Task {
            await currentActivity?.end(nil, dismissalPolicy: .immediate)
            currentActivity = nil
        }
    }
}
