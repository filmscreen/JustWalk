//
//  WalkActivityAttributes.swift
//  Just Walk
//
//  Shared Activity Attributes for Classic Walk Live Activity.
//  This file must be in BOTH targets:
//  - Just Walk (main app) - for Activity.request()
//  - SimpleWalkWidgets (widget extension) - for rendering UI
//

#if os(iOS)
import ActivityKit
import Foundation

/// Attributes for the Classic Walk Live Activity
/// Static attributes are set when the activity starts and don't change
/// Dynamic content is updated via ContentState
public struct WalkActivityAttributes: ActivityAttributes {

    /// Dynamic content that updates during the activity
    public struct ContentState: Codable, Hashable {
        /// Steps taken during this walk session
        public var sessionSteps: Int

        /// Distance covered in meters during this session
        public var sessionDistance: Double

        /// Elapsed time in seconds
        public var elapsedSeconds: TimeInterval

        /// User's daily step goal
        public var dailyGoal: Int

        /// Steps the user had when the walk started
        public var stepsAtStart: Int

        /// Whether the session is paused
        public var isPaused: Bool

        /// Computed: Current total daily steps
        public var currentDailySteps: Int {
            stepsAtStart + sessionSteps
        }

        /// Computed: Progress toward daily goal (0.0 to 1.0)
        public var goalProgress: Double {
            guard dailyGoal > 0 else { return 0 }
            return min(1.0, Double(currentDailySteps) / Double(dailyGoal))
        }

        /// Computed: Goal progress percentage for display
        public var goalProgressPercent: Int {
            Int(goalProgress * 100)
        }

        /// Computed: Formatted elapsed time (MM:SS)
        public var formattedDuration: String {
            let minutes = Int(elapsedSeconds) / 60
            let seconds = Int(elapsedSeconds) % 60
            return String(format: "%02d:%02d", minutes, seconds)
        }

        /// Computed: Distance in miles
        public var distanceMiles: Double {
            sessionDistance * 0.000621371
        }

        /// Computed: Formatted distance
        public var formattedDistance: String {
            String(format: "%.1f mi", distanceMiles)
        }

        public init(
            sessionSteps: Int = 0,
            sessionDistance: Double = 0,
            elapsedSeconds: TimeInterval = 0,
            dailyGoal: Int = 10_000,
            stepsAtStart: Int = 0,
            isPaused: Bool = false
        ) {
            self.sessionSteps = sessionSteps
            self.sessionDistance = sessionDistance
            self.elapsedSeconds = elapsedSeconds
            self.dailyGoal = dailyGoal
            self.stepsAtStart = stepsAtStart
            self.isPaused = isPaused
        }
    }

    /// Session start time (static, set once)
    public var sessionStartTime: Date

    public init(sessionStartTime: Date) {
        self.sessionStartTime = sessionStartTime
    }
}
#endif
