//
//  WalkGoal.swift
//  Just Walk
//
//  Shared walk goal types, presets, and persistence.
//  Used by both iPhone and Apple Watch apps.
//

import Foundation

// MARK: - Walk Goal Type

enum WalkGoalType: String, Codable, CaseIterable {
    case none        // Just Walk - no goal
    case time        // Walk for X minutes
    case distance    // Walk X miles
    case steps       // Walk X steps

    var icon: String {
        switch self {
        case .none: return "figure.walk"
        case .time: return "timer"
        case .distance: return "point.topleft.down.to.point.bottomright.curvepath"
        case .steps: return "shoeprints.fill"
        }
    }

    var label: String {
        switch self {
        case .none: return "Open Walk"
        case .time: return "Time"
        case .distance: return "Distance"
        case .steps: return "Steps"
        }
    }
}

// MARK: - Walk Goal

struct WalkGoal: Codable, Equatable, Hashable {
    let type: WalkGoalType
    let target: Double  // minutes, miles, or steps depending on type
    let isCustom: Bool  // true if user entered custom value

    // MARK: - Convenience Initializers

    // nonisolated(unsafe) allows this to be used as default value in @MainActor classes
    nonisolated(unsafe) static let none = WalkGoal(type: .none, target: 0, isCustom: false)

    static func time(minutes: Double, isCustom: Bool = false) -> WalkGoal {
        WalkGoal(type: .time, target: minutes, isCustom: isCustom)
    }

    static func distance(miles: Double, isCustom: Bool = false) -> WalkGoal {
        WalkGoal(type: .distance, target: miles, isCustom: isCustom)
    }

    static func steps(count: Double, isCustom: Bool = false) -> WalkGoal {
        WalkGoal(type: .steps, target: count, isCustom: isCustom)
    }

    // MARK: - Display

    var displayString: String {
        switch type {
        case .none: return "Open Walk"
        case .time: return "\(Int(target)) min"
        case .distance:
            if target == floor(target) {
                return "\(Int(target)) mi"
            }
            return String(format: "%.1f mi", target)
        case .steps: return "\(Int(target).formatted()) steps"
        }
    }

    var startButtonText: String {
        switch type {
        case .none: return "Just Start"
        case .time: return "Start \(Int(target)) min Walk"
        case .distance:
            if target == floor(target) {
                return "Start \(Int(target)) mi Walk"
            }
            return "Start \(String(format: "%.1f", target)) mi Walk"
        case .steps: return "Start \(Int(target).formatted()) Step Walk"
        }
    }

    var estimateDisclaimer: String? {
        switch type {
        case .steps: return "Step count is estimated based on distance"
        default: return nil
        }
    }

    /// Returns the raw target value (minutes, miles, or step count)
    var rawValue: Double {
        return target
    }

    /// Returns the goal type if not none, nil otherwise
    var goalType: WalkGoalType? {
        type == .none ? nil : type
    }
}

// MARK: - Goal Presets

struct WalkGoalPresets {
    static let time: [Double] = [15, 30, 45, 60]           // minutes
    static let distance: [Double] = [1, 2, 3, 5]           // miles
    static let steps: [Double] = [2000, 5000, 7500, 10000] // steps

    /// Meters per mile for conversion
    static let metersPerMile: Double = 1609.34

    /// Average walking pace in mph
    static let averageWalkingPacePerHour: Double = 2.5

    /// Average steps per mile
    static let stepsPerMile: Double = 2000

    /// Convert goal to estimated distance in miles (for route generation)
    static func estimatedDistance(for goal: WalkGoal) -> Double {
        switch goal.type {
        case .none: return 0
        case .time: return goal.target / 60 * averageWalkingPacePerHour
        case .distance: return goal.target
        case .steps: return goal.target / stepsPerMile
        }
    }

    /// Convert distance to estimated step count
    static func estimatedSteps(for miles: Double) -> Int {
        return Int(miles * stepsPerMile)
    }

    /// Convert miles to meters
    static func milesToMeters(_ miles: Double) -> Double {
        return miles * metersPerMile
    }

    /// Convert meters to miles
    static func metersToMiles(_ meters: Double) -> Double {
        return meters / metersPerMile
    }

    /// Format a goal for display (convenience wrapper)
    static func label(for goal: WalkGoal) -> String {
        return goal.displayString
    }

    /// Format remaining time in MM:SS or H:MM:SS
    static func formatTimeRemaining(_ seconds: Int) -> String {
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60
        let secs = seconds % 60

        if hours > 0 {
            return String(format: "%d:%02d:%02d left", hours, minutes, secs)
        }
        return String(format: "%d:%02d left", minutes, secs)
    }
}

// MARK: - UserDefaults Persistence

extension UserDefaults {
    private enum WalkGoalKeys {
        static let lastGoalType = "lastWalkGoalType"
        static let lastGoalTarget = "lastWalkGoalTarget"
        static let lastGoalIsCustom = "lastWalkGoalIsCustom"
        static let lastTimeGoal = "lastTimeGoal"
        static let lastDistanceGoal = "lastDistanceGoal"
        static let lastStepsGoal = "lastStepsGoal"
    }

    var lastWalkGoal: WalkGoal? {
        get {
            guard let typeString = string(forKey: WalkGoalKeys.lastGoalType),
                  let type = WalkGoalType(rawValue: typeString) else {
                return nil
            }
            let target = double(forKey: WalkGoalKeys.lastGoalTarget)
            let isCustom = bool(forKey: WalkGoalKeys.lastGoalIsCustom)
            return WalkGoal(type: type, target: target, isCustom: isCustom)
        }
        set {
            guard let goal = newValue else {
                removeObject(forKey: WalkGoalKeys.lastGoalType)
                removeObject(forKey: WalkGoalKeys.lastGoalTarget)
                removeObject(forKey: WalkGoalKeys.lastGoalIsCustom)
                return
            }
            set(goal.type.rawValue, forKey: WalkGoalKeys.lastGoalType)
            set(goal.target, forKey: WalkGoalKeys.lastGoalTarget)
            set(goal.isCustom, forKey: WalkGoalKeys.lastGoalIsCustom)
        }
    }

    // Per-type last values for quick selection
    var lastTimeGoal: Double {
        get { double(forKey: WalkGoalKeys.lastTimeGoal).nonZero ?? 30 }
        set { set(newValue, forKey: WalkGoalKeys.lastTimeGoal) }
    }

    var lastDistanceGoal: Double {
        get { double(forKey: WalkGoalKeys.lastDistanceGoal).nonZero ?? 2 }
        set { set(newValue, forKey: WalkGoalKeys.lastDistanceGoal) }
    }

    var lastStepsGoal: Double {
        get { double(forKey: WalkGoalKeys.lastStepsGoal).nonZero ?? 5000 }
        set { set(newValue, forKey: WalkGoalKeys.lastStepsGoal) }
    }
}

private extension Double {
    var nonZero: Double? { self == 0 ? nil : self }
}
