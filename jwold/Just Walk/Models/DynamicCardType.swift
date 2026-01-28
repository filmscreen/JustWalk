//
//  DynamicCardType.swift
//  Just Walk
//
//  Priority-based dynamic card types for the Today screen.
//

import SwiftUI

// MARK: - Card Type Enum

enum DynamicCardType: Equatable {
    // Tier 1: Urgent
    case streakAtRisk(streak: Int, stepsRemaining: Int, hoursLeft: Int)

    // Tier 2: Celebration
    case dailyMilestone(milestone: DailyMilestone)
    case streakMilestone(days: Int)

    // Tier 3: Conversion
    case proTrial

    // Tier 4: Contextual
    case weeklySummary(snapshot: WeeklySummaryData)
    case goalAdjustment(currentGoal: Int, suggestedGoal: Int, consecutiveDays: Int)
    case comebackPrompt(daysSinceLastWalk: Int)
    case weatherSuggestion(temp: Int, condition: String, percentToGoal: Int)

    // Tier 5: Discovery
    case watchAppSetup

    // MARK: - Card ID (for dismissal tracking)

    var id: String {
        switch self {
        case .streakAtRisk: return "streakAtRisk"
        case .dailyMilestone(let m): return "dailyMilestone.\(m.rawValue)"
        case .streakMilestone(let d): return "streakMilestone.\(d)"
        case .proTrial: return "proTrial"
        case .weeklySummary: return "weeklySummary"
        case .goalAdjustment: return "goalAdjustment"
        case .comebackPrompt: return "comebackPrompt"
        case .weatherSuggestion: return "weatherSuggestion"
        case .watchAppSetup: return "watchAppSetup"
        }
    }

    // MARK: - Dismiss Behavior

    var dismissBehavior: DismissBehavior {
        switch self {
        case .streakAtRisk: return .hideUntilTomorrow
        case .dailyMilestone: return .hideForever
        case .streakMilestone: return .hideForever
        case .proTrial: return .hideForDays(14)
        case .weeklySummary: return .hideUntilNextWeek
        case .goalAdjustment: return .hideForDays(30)
        case .comebackPrompt: return .hideUntilNextInactive
        case .weatherSuggestion: return .hideUntilTomorrow
        case .watchAppSetup: return .hideForever
        }
    }
}

// MARK: - Daily Milestones

enum DailyMilestone: String, CaseIterable {
    case first10k = "first10k"
    case first15k = "first15k"
    case first20k = "first20k"

    var stepThreshold: Int {
        switch self {
        case .first10k: return 10_000
        case .first15k: return 15_000
        case .first20k: return 20_000
        }
    }

    var displayName: String {
        switch self {
        case .first10k: return "10,000"
        case .first15k: return "15,000"
        case .first20k: return "20,000"
        }
    }
}

// MARK: - Streak Milestones

let streakMilestones = [7, 14, 30, 60, 100, 365]

// MARK: - Weekly Summary Data

struct WeeklySummaryData: Equatable {
    let totalSteps: Int
    let percentChange: Int?
    let isUp: Bool
    let bestDayName: String?
    let bestDaySteps: Int?
}

// MARK: - Dismiss Behavior

enum DismissBehavior: Equatable {
    case hideForever
    case hideUntilTomorrow
    case hideUntilNextWeek
    case hideUntilNextInactive
    case hideForDays(Int)
}
