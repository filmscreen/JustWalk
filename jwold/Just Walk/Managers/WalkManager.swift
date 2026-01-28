//
//  WalkManager.swift
//  Just Walk
//
//  Singleton manager for walk state and session tracking.
//  Shared between iPhone and Apple Watch apps.
//

import SwiftUI
import Combine

class WalkManager: ObservableObject {
    static let shared = WalkManager()
    private init() {}

    // MARK: - Published State

    @Published var activeSession: WalkSession?
    @Published var selectedGoal: WalkGoal?

    // MARK: - Persisted Preferences

    @AppStorage("lastGoalType") private var lastGoalTypeRaw: String = WalkGoalType.none.rawValue

    var lastGoalType: WalkGoalType {
        get { WalkGoalType(rawValue: lastGoalTypeRaw) ?? .none }
        set { lastGoalTypeRaw = newValue.rawValue }
    }

    // MARK: - Walk Lifecycle

    /// Start a new walk session
    /// - Parameters:
    ///   - goal: Optional walk goal (time, distance, steps, or none)
    ///   - route: Optional generated route data for guided walks
    /// - Returns: The newly created walk session
    @discardableResult
    func startWalk(goal: WalkGoal? = nil, route: GeneratedRouteData? = nil) -> WalkSession {
        let session = WalkSession(
            id: UUID(),
            startTime: Date(),
            goal: goal,
            generatedRoute: route
        )
        activeSession = session

        // Save goal type for next time
        if let goal = goal {
            lastGoalType = goal.type
            UserDefaults.standard.lastWalkGoal = goal

            // Also save per-type values
            switch goal.type {
            case .time:
                UserDefaults.standard.lastTimeGoal = goal.target
            case .distance:
                UserDefaults.standard.lastDistanceGoal = goal.target
            case .steps:
                UserDefaults.standard.lastStepsGoal = goal.target
            case .none:
                break
            }
        }

        return session
    }

    /// Update progress for the active session
    /// - Parameters:
    ///   - steps: Current step count (optional)
    ///   - distance: Current distance in miles (optional)
    ///   - duration: Current duration in seconds (optional)
    func updateProgress(steps: Int? = nil, distance: Double? = nil, duration: TimeInterval? = nil) {
        guard var session = activeSession else { return }

        if let steps = steps {
            session.currentSteps = steps
        }
        if let distance = distance {
            session.currentDistance = distance
        }
        if let duration = duration {
            session.currentDuration = duration
        }

        activeSession = session
    }

    /// End the current walk session
    /// - Returns: The completed session, or nil if no active session
    @discardableResult
    func endWalk() -> WalkSession? {
        guard var session = activeSession else { return nil }
        session.endTime = Date()
        activeSession = nil
        return session
    }

    /// Cancel the current walk without saving
    func cancelWalk() {
        activeSession = nil
    }

    // MARK: - Goal Convenience

    /// Get the last used goal value for a specific type
    func lastValue(for type: WalkGoalType) -> Double {
        switch type {
        case .time: return UserDefaults.standard.lastTimeGoal
        case .distance: return UserDefaults.standard.lastDistanceGoal
        case .steps: return UserDefaults.standard.lastStepsGoal
        case .none: return 0
        }
    }

    /// Create a goal from the last used value for a type
    func goalFromLastValue(for type: WalkGoalType, isCustom: Bool = false) -> WalkGoal {
        let target = lastValue(for: type)
        return WalkGoal(type: type, target: target, isCustom: isCustom)
    }

    // MARK: - Session State

    var isWalkActive: Bool {
        activeSession?.isActive ?? false
    }

    var currentGoalProgress: Double? {
        activeSession?.goalProgress
    }

    var hasReachedGoal: Bool {
        activeSession?.goalReached ?? false
    }
}
