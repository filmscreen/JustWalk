//
//  EmotionalMoment.swift
//  JustWalk
//
//  Quiet, meaningful moments that acknowledge user achievement
//

import Foundation

enum EmotionalMoment: Equatable, Identifiable {
    // First experiences
    case firstWalk

    // Clutch performances
    case clutchSave          // Goal met after 10:30pm
    case underTheWire        // Goal met after 11:30pm

    // Comebacks
    case comeback            // Goal met after 3+ days away
    case comebackWithRecord(days: Int)  // Same, but had streak > 14

    // Milestones (quiet acknowledgment)
    case milestone(days: Int) // 7, 30, 60, 90, 100, 180, 365

    // Walk completion
    case walkComplete(minutes: Int, steps: Int, goalHit: Bool, streakDay: Int?)

    var id: String {
        switch self {
        case .firstWalk: return "firstWalk"
        case .clutchSave: return "clutchSave"
        case .underTheWire: return "underTheWire"
        case .comeback: return "comeback"
        case .comebackWithRecord(let days): return "comebackWithRecord_\(days)"
        case .milestone(let days): return "milestone_\(days)"
        case .walkComplete(let min, let steps, let goal, let streak):
            return "walkComplete_\(min)_\(steps)_\(goal)_\(streak ?? 0)"
        }
    }
}

// MARK: - Moment Content

struct MomentContent {
    let primaryText: String
    let secondaryText: String?
    let tertiaryText: String?

    init(_ primary: String, _ secondary: String? = nil, _ tertiary: String? = nil) {
        self.primaryText = primary
        self.secondaryText = secondary
        self.tertiaryText = tertiary
    }
}

extension EmotionalMoment {
    var content: MomentContent {
        switch self {
        case .firstWalk:
            return MomentContent("Your first walk.", "That's Day 1.")

        case .clutchSave:
            return MomentContent("Clutch.")

        case .underTheWire:
            return MomentContent("Under the wire.")

        case .comeback:
            return MomentContent("Welcome back.")

        case .comebackWithRecord(let days):
            return MomentContent("Welcome back.", "Your record still stands.", "\(days) days")

        case .milestone(let days):
            return milestoneCopy(for: days)

        case .walkComplete(let minutes, let steps, let goalHit, let streakDay):
            return walkCompleteCopy(minutes: minutes, steps: steps, goalHit: goalHit, streakDay: streakDay)
        }
    }

    private func milestoneCopy(for days: Int) -> MomentContent {
        switch days {
        case 7:
            return MomentContent("One week.", "You showed up\nevery day.")
        case 14:
            return MomentContent("Two weeks.", "The habit is forming.")
        case 30:
            return MomentContent("One month.", "That's not luck.\nThat's you.")
        case 60:
            return MomentContent("Two months.", "Consistency\nbecomes identity.")
        case 90:
            return MomentContent("Ninety days.", "This is who you are now.")
        case 100:
            return MomentContent("100", "days of showing up.", "This is who you are now.")
        case 180:
            return MomentContent("Half a year.", "You just kept walking.")
        case 365:
            return MomentContent("One year.", "You said you'd try\nwalking more.", "Then you did.\nEvery. Single. Day.")
        default:
            return MomentContent("\(days) days.", "You showed up.")
        }
    }

    private func walkCompleteCopy(minutes: Int, steps: Int, goalHit: Bool, streakDay: Int?) -> MomentContent {
        let stats = "\(minutes) min · \(steps.formatted()) steps"

        if goalHit {
            return MomentContent("Done.", stats, "Goal hit. ✓")
        } else if let day = streakDay, day > 0 {
            return MomentContent("Done.", stats, "Day \(day). ✓")
        } else {
            return MomentContent("Done.", stats)
        }
    }
}

// MARK: - Trigger Logic

final class EmotionalMomentTrigger {
    static let shared = EmotionalMomentTrigger()

    private let defaults = UserDefaults.standard
    private let calendar = Calendar.current

    private init() {}

    // Keys for tracking first-time events
    private let firstWalkCompletedKey = "emotional_first_walk_completed"
    private let lastActiveGoalDateKey = "emotional_last_active_goal_date"

    var hasCompletedFirstWalk: Bool {
        get { defaults.bool(forKey: firstWalkCompletedKey) }
        set { defaults.set(newValue, forKey: firstWalkCompletedKey) }
    }

    /// Check for emotional moment after a guided walk completes
    func checkAfterWalkComplete(
        walkMinutes: Int,
        walkSteps: Int,
        isFirstWalkEver: Bool,
        goalHitThisWalk: Bool,
        currentStreak: Int,
        longestStreak: Int,
        daysInactive: Int
    ) -> EmotionalMoment? {

        // Priority 1: First walk ever
        if isFirstWalkEver && !hasCompletedFirstWalk {
            hasCompletedFirstWalk = true
            return .firstWalk
        }

        // Priority 2: Comeback (after 3+ days of inactivity)
        if daysInactive >= 3 && goalHitThisWalk {
            if longestStreak > 14 {
                return .comebackWithRecord(days: longestStreak)
            }
            return .comeback
        }

        // Priority 3: Walk completion (always for guided walks)
        return .walkComplete(
            minutes: walkMinutes,
            steps: walkSteps,
            goalHit: goalHitThisWalk,
            streakDay: currentStreak > 0 ? currentStreak : nil
        )
    }

    /// Check for milestone moments (called separately from StreakManager)
    func checkForMilestone(streak: Int) -> EmotionalMoment? {
        let milestoneDays = [7, 14, 30, 60, 90, 100, 180, 365]
        if milestoneDays.contains(streak) {
            return .milestone(days: streak)
        }
        return nil
    }

    /// Check for clutch save on goal completion
    func checkForClutchSave() -> EmotionalMoment? {
        let now = Date()
        let hour = calendar.component(.hour, from: now)
        let minute = calendar.component(.minute, from: now)

        // After 11:30pm
        if hour == 23 && minute >= 30 {
            return .underTheWire
        }

        // After 10:30pm
        if hour >= 23 || (hour == 22 && minute >= 30) {
            return .clutchSave
        }

        return nil
    }

    /// Calculate days of inactivity (days since last goal met)
    func daysOfInactivity(lastGoalMetDate: Date?) -> Int {
        guard let lastDate = lastGoalMetDate else { return 0 }
        let today = calendar.startOfDay(for: Date())
        let lastDay = calendar.startOfDay(for: lastDate)
        let components = calendar.dateComponents([.day], from: lastDay, to: today)
        return max(0, (components.day ?? 0) - 1) // -1 because we want gap days, not inclusive
    }

    /// Post an emotional moment to be displayed
    func post(_ moment: EmotionalMoment) {
        NotificationCenter.default.post(
            name: .emotionalMomentTriggered,
            object: nil,
            userInfo: ["moment": moment]
        )
    }
}

// MARK: - Notification

extension Notification.Name {
    static let emotionalMomentTriggered = Notification.Name("emotionalMomentTriggered")
}
