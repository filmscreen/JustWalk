//
//  UserState.swift
//  Just Walk
//
//  Captures user's current state for insight evaluation.
//

import Foundation

struct UserState {
    // Step metrics
    let stepsToday: Int
    let stepGoal: Int
    let stepsRemaining: Int
    let percentComplete: Double
    let distanceToday: Double // in miles
    let caloriesToday: Int

    // Streak metrics
    let currentStreak: Int
    let longestStreak: Int
    let hasStreakShield: Bool
    let shieldsRemaining: Int

    // Comparison metrics
    let stepsYesterdaySameTime: Int
    let stepsYesterdayTotal: Int
    let averageDailySteps: Int // 7-day average
    let daysActiveThisWeek: Int

    // Time context
    let hourOfDay: Int // 0-23
    let minutesUntilMidnight: Int
    let dayOfWeek: Int // 1=Sunday, 7=Saturday
    let isWeekend: Bool

    // Insight tracking
    let lastInsightShownId: String?
    let lastInsightShownDate: Date?

    // User status
    let isPro: Bool
    let goalMetToday: Bool
    let goalMetYesterday: Bool
    let justHitGoal: Bool // true if goal was hit in the last 5 minutes
}
