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

// Backwards-compatible named tips and tip collection for tests
extension DynamicCardType {
    static var tipLittleGoFar: DynamicCardType { .tip(DailyTip.allTips[0]) }
    static var tipHeartHealth: DynamicCardType { .tip(DailyTip.allTips[21]) }
    static var tipClearHead: DynamicCardType { .tip(DailyTip.allTips[35]) }
    static var tipSleepBetter: DynamicCardType { .tip(DailyTip.allTips[27]) }
    static var tipEnergyBoost: DynamicCardType { .tip(DailyTip.allTips[38]) }
    static var tipWalkAfterMeals: DynamicCardType { .tip(DailyTip.allTips[24]) }
    static var tipParkFarther: DynamicCardType { .tip(DailyTip.allTips[13]) }
    static var tipTakeStairs: DynamicCardType { .tip(DailyTip.allTips[14]) }
    static var tipLeavePhone: DynamicCardType { .tip(DailyTip.allTips[12]) }
    static var tipWalkWithSomeone: DynamicCardType { .tip(DailyTip.allTips[19]) }
    static var tipConsistency: DynamicCardType { .tip(DailyTip.allTips[40]) }
    static var tipJustStart: DynamicCardType { .tip(DailyTip.allTips[41]) }
    static var tipNoTime: DynamicCardType { .tip(DailyTip.allTips[29]) }
    static var tipMorningLight: DynamicCardType { .tip(DailyTip.allTips[18]) }
    static var tipNatureHeals: DynamicCardType { .tip(DailyTip.allTips[39]) }

    static var tipCards: [DynamicCardType] {
        [
            tipLittleGoFar,
            tipHeartHealth,
            tipClearHead,
            tipSleepBetter,
            tipEnergyBoost,
            tipWalkAfterMeals,
            tipParkFarther,
            tipTakeStairs,
            tipLeavePhone,
            tipWalkWithSomeone,
            tipConsistency,
            tipJustStart,
            tipNoTime,
            tipMorningLight,
            tipNatureHeals,
        ]
    }
}
