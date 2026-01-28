//
//  ClassicWalkLiveActivityManager.swift
//  Just Walk
//
//  Manages Live Activity lifecycle for Classic Walk (Just Walk) sessions.
//  Provides persistent background execution and visual feedback on lock screen
//  and Dynamic Island during simple walks.
//

import Foundation
#if os(iOS)
import ActivityKit
#endif
import Combine

// Import the shared attributes from the widget extension
// Note: WalkActivityAttributes is defined in ClassicWalkLiveActivity.swift
// and needs to be accessible to both the main app and widget extension

/// Manages Live Activity lifecycle for Classic Walk sessions
#if os(iOS)
@MainActor
final class ClassicWalkLiveActivityManager: ObservableObject {

    static let shared = ClassicWalkLiveActivityManager()

    // MARK: - Published State

    @Published private(set) var isActivityActive = false
    @Published private(set) var currentActivity: Activity<WalkActivityAttributes>?

    // MARK: - Internal State

    /// Last reported step count (for throttling updates)
    private var lastReportedSteps: Int = 0

    /// Minimum step change before updating Live Activity (battery optimization)
    private let updateThreshold: Int = 100

    /// Settings key for Live Activity enabled toggle
    private static let liveActivityEnabledKey = "classicWalkLiveActivityEnabled"

    /// Whether Live Activity is enabled in settings
    var isLiveActivityEnabled: Bool {
        get { UserDefaults.standard.object(forKey: Self.liveActivityEnabledKey) as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: Self.liveActivityEnabledKey) }
    }

    private init() {}

    // MARK: - Live Activity Lifecycle

    /// Start a Live Activity for a Classic Walk session
    /// - Parameters:
    ///   - startTime: Session start time
    ///   - stepsAtStart: Daily step count when walk started
    ///   - dailyGoal: User's daily step goal
    func startActivity(startTime: Date, stepsAtStart: Int, dailyGoal: Int) async {
        print("🎯 ClassicWalk LA: Starting - stepsAtStart=\(stepsAtStart), goal=\(dailyGoal)")

        // Check if Live Activity is enabled in settings
        guard isLiveActivityEnabled else {
            print("⚠️ ClassicWalk LA: Disabled in settings")
            return
        }

        // Check if ActivityKit is available
        print("🎯 ClassicWalk LA: ActivityKit enabled=\(ActivityAuthorizationInfo().areActivitiesEnabled)")
        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            print("⚠️ ClassicWalk LA: Live Activities not enabled on this device")
            return
        }

        // End any existing activity first
        if currentActivity != nil {
            await endActivity(finalSteps: 0, finalDistance: 0, completed: false)
        }

        // Reset tracking
        lastReportedSteps = 0

        // Create initial content state
        let initialState = WalkActivityAttributes.ContentState(
            sessionSteps: 0,
            sessionDistance: 0,
            elapsedSeconds: 0,
            dailyGoal: dailyGoal,
            stepsAtStart: stepsAtStart,
            isPaused: false
        )

        let attributes = WalkActivityAttributes(sessionStartTime: startTime)

        do {
            let activity = try Activity.request(
                attributes: attributes,
                content: .init(state: initialState, staleDate: nil),
                pushType: nil
            )

            currentActivity = activity
            isActivityActive = true

            print("✅ ClassicWalk LA: Started - id=\(activity.id)")

        } catch {
            print("❌ ClassicWalk LA: Failed to start - \(error)")
        }
    }

    /// Update the Live Activity with current session stats
    /// Updates are throttled to every ~100 steps for battery efficiency
    /// - Parameters:
    ///   - sessionSteps: Current step count during session
    ///   - sessionDistance: Distance in meters
    ///   - elapsedSeconds: Elapsed time in seconds
    ///   - isPaused: Whether the session is paused
    func updateActivity(sessionSteps: Int, sessionDistance: Double, elapsedSeconds: TimeInterval, isPaused: Bool) async {
        guard let activity = currentActivity else { return }

        // Throttle updates to every 100 steps (unless paused state changes)
        let stepChange = abs(sessionSteps - lastReportedSteps)
        guard stepChange >= updateThreshold || isPaused else { return }

        lastReportedSteps = sessionSteps

        let updatedState = WalkActivityAttributes.ContentState(
            sessionSteps: sessionSteps,
            sessionDistance: sessionDistance,
            elapsedSeconds: elapsedSeconds,
            dailyGoal: activity.content.state.dailyGoal,
            stepsAtStart: activity.content.state.stepsAtStart,
            isPaused: isPaused
        )

        await activity.update(
            ActivityContent(state: updatedState, staleDate: nil)
        )

        print("📱 ClassicWalk LA: Update - steps=\(sessionSteps)")
    }

    /// Pause the Live Activity
    func pauseActivity(sessionSteps: Int, sessionDistance: Double, elapsedSeconds: TimeInterval) async {
        guard let activity = currentActivity else { return }

        let pausedState = WalkActivityAttributes.ContentState(
            sessionSteps: sessionSteps,
            sessionDistance: sessionDistance,
            elapsedSeconds: elapsedSeconds,
            dailyGoal: activity.content.state.dailyGoal,
            stepsAtStart: activity.content.state.stepsAtStart,
            isPaused: true
        )

        await activity.update(
            ActivityContent(state: pausedState, staleDate: nil)
        )

        print("⏸️ ClassicWalk LA: Paused")
    }

    /// Resume the Live Activity
    func resumeActivity(sessionSteps: Int, sessionDistance: Double, elapsedSeconds: TimeInterval) async {
        guard let activity = currentActivity else { return }

        let resumedState = WalkActivityAttributes.ContentState(
            sessionSteps: sessionSteps,
            sessionDistance: sessionDistance,
            elapsedSeconds: elapsedSeconds,
            dailyGoal: activity.content.state.dailyGoal,
            stepsAtStart: activity.content.state.stepsAtStart,
            isPaused: false
        )

        await activity.update(
            ActivityContent(state: resumedState, staleDate: nil)
        )

        print("▶️ ClassicWalk LA: Resumed")
    }

    /// End the Live Activity
    /// - Parameters:
    ///   - finalSteps: Final step count
    ///   - finalDistance: Final distance in meters
    ///   - completed: Whether the walk was completed normally (vs cancelled)
    func endActivity(finalSteps: Int, finalDistance: Double, completed: Bool) async {
        guard let activity = currentActivity else { return }

        // Create final state
        let finalState = WalkActivityAttributes.ContentState(
            sessionSteps: finalSteps,
            sessionDistance: finalDistance,
            elapsedSeconds: activity.content.state.elapsedSeconds,
            dailyGoal: activity.content.state.dailyGoal,
            stepsAtStart: activity.content.state.stepsAtStart,
            isPaused: false
        )

        await activity.end(
            ActivityContent(state: finalState, staleDate: nil),
            dismissalPolicy: .immediate
        )

        currentActivity = nil
        isActivityActive = false
        lastReportedSteps = 0

        print("🏁 ClassicWalk LA: Ended - completed=\(completed), steps=\(finalSteps)")
    }

    /// Force update (bypasses throttling) - use sparingly
    func forceUpdate(sessionSteps: Int, sessionDistance: Double, elapsedSeconds: TimeInterval, isPaused: Bool) async {
        guard let activity = currentActivity else { return }

        lastReportedSteps = sessionSteps

        let updatedState = WalkActivityAttributes.ContentState(
            sessionSteps: sessionSteps,
            sessionDistance: sessionDistance,
            elapsedSeconds: elapsedSeconds,
            dailyGoal: activity.content.state.dailyGoal,
            stepsAtStart: activity.content.state.stepsAtStart,
            isPaused: isPaused
        )

        await activity.update(
            ActivityContent(state: updatedState, staleDate: nil)
        )
    }
}
#endif
