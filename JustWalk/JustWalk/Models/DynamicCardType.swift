//
//  DynamicCardType.swift
//  JustWalk
//
//  Enum for dynamic card types on home screen — 3-tier priority system
//

import Foundation

// MARK: - Dynamic Card Type

enum DynamicCardType: Equatable {
    // P0 — Smart Walk Invitation (highest priority walk prompts)
    case smartWalkPattern(preferredMode: WalkMode)                    // "You usually walk around now"
    case smartWalkPostMeal                                             // Post-meal window (12-1:30pm or 6-8pm)
    case smartWalkEveningRescue(stepsRemaining: Int)                   // After 6pm, goal not met, < 3000 remaining
    case smartWalkCloseToGoal(stepsRemaining: Int)                     // < 1000 steps to goal
    case smartWalkMorning                                              // 6-9am invitation
    case smartWalkGoalMet                                              // Goal complete, bonus walk?
    case smartWalkDefault                                              // Fallback: "Ready for a walk?"

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

    // P2.5 — Insight (pattern-based personalization, rare)
    case insight(InsightCard)

    // P3 — Fallback / Tips (50 evergreen tips with random rotation)
    case tip(DailyTip)

    /// Stable key for frequency tracking / daily show limit
    var cardKey: String {
        switch self {
        // P0 — Smart Walk
        case .smartWalkPattern:      return "smartWalkPattern"
        case .smartWalkPostMeal:     return "smartWalkPostMeal"
        case .smartWalkEveningRescue: return "smartWalkEveningRescue"
        case .smartWalkCloseToGoal:  return "smartWalkCloseToGoal"
        case .smartWalkMorning:      return "smartWalkMorning"
        case .smartWalkGoalMet:      return "smartWalkGoalMet"
        case .smartWalkDefault:      return "smartWalkDefault"
        // P1 — Urgent
        case .streakAtRisk:          return "streakAtRisk"
        case .shieldDeployed:        return "shieldDeployed"
        case .welcomeBack:           return "welcomeBack"
        // P2 — Contextual
        case .almostThere:           return "almostThere"
        case .milestoneCelebration(let e): return "milestoneCelebration_\(e.id)"
        case .tryIntervals:          return "tryIntervals"
        case .trySyncWithWatch:      return "trySyncWithWatch"
        case .newWeekNewGoal:        return "newWeekNewGoal"
        case .weekendWarrior:        return "weekendWarrior"
        case .eveningNudge:          return "eveningNudge"
        // P2.5 — Insight
        case .insight(let card):     return "insight_\(card.id)"
        // P3 — Tips
        case .tip(let tip):          return "tip_\(tip.id)"
        }
    }

    /// Priority tier: 0 (smart walk), 1 (urgent), 2 (contextual), 2.5 (insight), 3 (fallback/tips)
    var tier: Int {
        switch self {
        case .smartWalkPattern, .smartWalkPostMeal, .smartWalkEveningRescue,
             .smartWalkCloseToGoal, .smartWalkMorning, .smartWalkGoalMet, .smartWalkDefault:
            return 0
        case .streakAtRisk, .shieldDeployed, .welcomeBack:
            return 1
        case .almostThere, .milestoneCelebration, .tryIntervals,
             .trySyncWithWatch, .newWeekNewGoal, .weekendWarrior, .eveningNudge:
            return 2
        case .insight:
            return 2 // Treat as P2 priority when available
        case .tip:
            return 3
        }
    }

    /// Whether this is a Smart Walk card (P0 tier)
    var isSmartWalkCard: Bool {
        tier == 0
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
