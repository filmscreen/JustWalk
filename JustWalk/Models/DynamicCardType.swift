//
//  DynamicCardType.swift
//  JustWalk
//
//  Enum for dynamic card types on home screen — 3-tier priority system
//

import Foundation

// MARK: - Dynamic Card Type

enum DynamicCardType: Equatable {
    // P1 — Urgent
    case streakAtRisk(stepsRemaining: Int)
    case shieldDeployed(remainingShields: Int, nextRefill: String)
    case welcomeBack

    // P2 — Contextual
    case almostThere(stepsRemaining: Int)
    case milestoneCelebration(event: MilestoneEvent)
    case tryIntervals
    case trySyncWithWatch
    case newWeekNewGoal
    case weekendWarrior
    case eveningNudge(stepsRemaining: Int)

    // P3 — Fallback / Tips (50 evergreen tips with random rotation)
    case tip(DailyTip)

    /// Stable key for frequency tracking / daily show limit
    var cardKey: String {
        switch self {
        case .streakAtRisk:          return "streakAtRisk"
        case .shieldDeployed:        return "shieldDeployed"
        case .welcomeBack:           return "welcomeBack"
        case .almostThere:           return "almostThere"
        case .milestoneCelebration(let e): return "milestoneCelebration_\(e.id)"
        case .tryIntervals:          return "tryIntervals"
        case .trySyncWithWatch:      return "trySyncWithWatch"
        case .newWeekNewGoal:        return "newWeekNewGoal"
        case .weekendWarrior:        return "weekendWarrior"
        case .eveningNudge:          return "eveningNudge"
        case .tip(let tip):          return "tip_\(tip.id)"
        }
    }

    /// Priority tier: 1 (urgent), 2 (contextual), 3 (fallback/tips)
    var tier: Int {
        switch self {
        case .streakAtRisk, .shieldDeployed, .welcomeBack:
            return 1
        case .almostThere, .milestoneCelebration, .tryIntervals,
             .trySyncWithWatch, .newWeekNewGoal, .weekendWarrior, .eveningNudge:
            return 2
        case .tip:
            return 3
        }
    }
}
