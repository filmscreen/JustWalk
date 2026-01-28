//
//  Insight.swift
//  Just Walk
//
//  Insight model with conditions for the rule engine.
//

import Foundation

struct Insight: Codable, Identifiable {
    let id: String
    let category: InsightCategory
    let priority: Int // Lower number = higher priority
    let conditions: InsightConditions
    let messages: [String]
    let proOnly: Bool
    let cooldownHours: Int

    enum InsightCategory: String, Codable {
        case streakUrgent = "streak_urgent"
        case celebration = "celebration"
        case milestone = "milestone"
        case paceComparison = "pace_comparison"
        case timeNudge = "time_nudge"
        case recovery = "recovery"
        case general = "general"
    }
}

struct InsightConditions: Codable {
    // Step conditions
    var stepsToday: RangeCondition?
    var stepsRemaining: RangeCondition?
    var percentComplete: RangeCondition?

    // Streak conditions
    var currentStreak: RangeCondition?
    var streakAtRisk: Bool? // true if steps remaining > 0 and < 4 hours left

    // Comparison conditions
    var aheadOfYesterday: Bool?
    var aheadOfYesterdayPercent: RangeCondition?
    var aboveWeeklyAverage: Bool?

    // Time conditions
    var hourOfDay: RangeCondition?
    var minutesUntilMidnight: RangeCondition?
    var isWeekend: Bool?

    // State conditions
    var goalMetToday: Bool?
    var goalMetYesterday: Bool?
    var justHitGoal: Bool?
    var isPro: Bool?

    /// Default initializer with all conditions nil (matches any state)
    init(
        stepsToday: RangeCondition? = nil,
        stepsRemaining: RangeCondition? = nil,
        percentComplete: RangeCondition? = nil,
        currentStreak: RangeCondition? = nil,
        streakAtRisk: Bool? = nil,
        aheadOfYesterday: Bool? = nil,
        aheadOfYesterdayPercent: RangeCondition? = nil,
        aboveWeeklyAverage: Bool? = nil,
        hourOfDay: RangeCondition? = nil,
        minutesUntilMidnight: RangeCondition? = nil,
        isWeekend: Bool? = nil,
        goalMetToday: Bool? = nil,
        goalMetYesterday: Bool? = nil,
        justHitGoal: Bool? = nil,
        isPro: Bool? = nil
    ) {
        self.stepsToday = stepsToday
        self.stepsRemaining = stepsRemaining
        self.percentComplete = percentComplete
        self.currentStreak = currentStreak
        self.streakAtRisk = streakAtRisk
        self.aheadOfYesterday = aheadOfYesterday
        self.aheadOfYesterdayPercent = aheadOfYesterdayPercent
        self.aboveWeeklyAverage = aboveWeeklyAverage
        self.hourOfDay = hourOfDay
        self.minutesUntilMidnight = minutesUntilMidnight
        self.isWeekend = isWeekend
        self.goalMetToday = goalMetToday
        self.goalMetYesterday = goalMetYesterday
        self.justHitGoal = justHitGoal
        self.isPro = isPro
    }
}

struct RangeCondition: Codable {
    let min: Double?
    let max: Double?

    func evaluate(_ value: Double) -> Bool {
        if let min = min, value < min { return false }
        if let max = max, value > max { return false }
        return true
    }
}
