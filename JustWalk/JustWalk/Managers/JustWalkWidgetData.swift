//
//  JustWalkWidgetData.swift
//  JustWalk
//
//  Shared data bridge between main app and widget extension via App Group.
//  Industry-leading widget refresh with smart budget management and per-widget targeting.
//

import Foundation
import WidgetKit

struct JustWalkWidgetData {
    static let appGroupID = "group.com.justwalk.shared"
    private static var lastWidgetRefresh: Date = .distantPast

    // Budget-aware refresh throttling:
    // Apple allows ~40-50 reloadAllTimelines() calls per day.
    // We target max 40/day = ~1.67/hour, so we throttle to 30 min minimum between forced reloads.
    // This ensures we never hit the daily cap while still allowing timely updates.
    private static let widgetRefreshThrottle: TimeInterval = 1800 // 30 minutes
    private static let maxDailyReloads = 40
    private static var dailyReloadCount = 0
    private static var lastReloadDate: Date = .distantPast

    // Track previous values to detect what changed
    private static var previousSteps: Int = 0
    private static var previousStreak: Int = 0
    private static var previousShields: Int = 0

    // MARK: - Widget Kind Identifiers
    // These must match the `kind` property in each Widget struct

    /// Steps-focused widgets (Today, StepsGauge, StepsInline, StepsRectangular)
    static let stepsWidgetKinds = [
        "StepsRingWidget",      // Today (systemSmall)
        "StepsGaugeWidget",     // Lock screen circular
        "StepsInlineWidget",    // Lock screen inline
        "StepsRectangularWidget" // Lock screen rectangular
    ]

    /// Streak-focused widgets
    static let streakWidgetKinds = [
        "StreakFlameWidget",    // Streak (systemSmall)
        "StreakCircularWidget", // Lock screen circular
        "StreakCountWidget"     // Lock screen inline
    ]

    /// Combined/other widgets
    static let combinedWidgetKinds = [
        "TodayStreakWidget",    // Today + Streak (systemMedium)
        "TrendsWidget",         // This Week (systemMedium)
        "ShieldsWidget"         // Shields (systemMedium)
    ]

    static var sharedDefaults: UserDefaults {
        UserDefaults(suiteName: appGroupID) ?? .standard
    }

    /// Check if we should reset daily counter (new day started)
    private static func resetDailyCounterIfNeeded() {
        let calendar = Calendar.current
        if !calendar.isDate(lastReloadDate, inSameDayAs: Date()) {
            dailyReloadCount = 0
        }
    }

    /// Returns true if we have budget remaining for a forced reload
    private static var hasBudgetRemaining: Bool {
        resetDailyCounterIfNeeded()
        return dailyReloadCount < maxDailyReloads
    }

    /// Returns remaining reload budget for today
    static var remainingDailyBudget: Int {
        resetDailyCounterIfNeeded()
        return max(0, maxDailyReloads - dailyReloadCount)
    }

    static func todaySteps() -> Int {
        sharedDefaults.integer(forKey: "widget_todaySteps")
    }

    static func stepGoal() -> Int {
        let goal = sharedDefaults.integer(forKey: "widget_stepGoal")
        return goal > 0 ? goal : 5000
    }

    static func currentStreak() -> Int {
        sharedDefaults.integer(forKey: "widget_currentStreak")
    }

    static func weekSteps() -> [Int] {
        sharedDefaults.array(forKey: "widget_weekSteps") as? [Int] ?? Array(repeating: 0, count: 7)
    }

    static func shieldCount() -> Int {
        sharedDefaults.integer(forKey: "widget_shieldCount")
    }

    static func walkTimeMinutes() -> Int {
        sharedDefaults.integer(forKey: "widget_walkTimeMinutes")
    }

    /// Call from main app to push data for widgets
    static func updateWidgetData(
        todaySteps: Int,
        stepGoal: Int,
        currentStreak: Int,
        weekSteps: [Int],
        shieldCount: Int = 0,
        walkTimeMinutes: Int = 0,
        forceRefresh: Bool = false
    ) {
        sharedDefaults.set(todaySteps, forKey: "widget_todaySteps")
        sharedDefaults.set(stepGoal, forKey: "widget_stepGoal")
        sharedDefaults.set(currentStreak, forKey: "widget_currentStreak")
        sharedDefaults.set(weekSteps, forKey: "widget_weekSteps")
        sharedDefaults.set(shieldCount, forKey: "widget_shieldCount")
        sharedDefaults.set(walkTimeMinutes, forKey: "widget_walkTimeMinutes")
        refreshWidgetsIfNeeded(force: forceRefresh)
    }

    private static func refreshWidgetsIfNeeded(force: Bool = false) {
        let now = Date()

        // Always respect the throttle interval unless forcing
        if !force && now.timeIntervalSince(lastWidgetRefresh) < widgetRefreshThrottle {
            return
        }

        // Check budget before reload - skip if we've hit daily limit
        guard hasBudgetRemaining else {
            return
        }

        // Perform the reload and update tracking
        lastWidgetRefresh = now
        lastReloadDate = now
        dailyReloadCount += 1
        WidgetCenter.shared.reloadAllTimelines()
    }

    // MARK: - Smart Per-Widget Refresh (Budget Optimization)

    /// Refresh only widgets affected by step changes. More budget-efficient than reloadAll.
    static func refreshStepsWidgetsOnly() {
        guard hasBudgetRemaining else { return }

        for kind in stepsWidgetKinds {
            WidgetCenter.shared.reloadTimelines(ofKind: kind)
        }
        // Combined widgets also show steps
        for kind in combinedWidgetKinds {
            WidgetCenter.shared.reloadTimelines(ofKind: kind)
        }

        dailyReloadCount += 1
        lastReloadDate = Date()
    }

    /// Refresh only widgets affected by streak changes.
    static func refreshStreakWidgetsOnly() {
        guard hasBudgetRemaining else { return }

        for kind in streakWidgetKinds {
            WidgetCenter.shared.reloadTimelines(ofKind: kind)
        }
        // Combined widgets also show streak
        WidgetCenter.shared.reloadTimelines(ofKind: "TodayStreakWidget")

        dailyReloadCount += 1
        lastReloadDate = Date()
    }

    /// Refresh only the shields widget.
    static func refreshShieldsWidgetOnly() {
        guard hasBudgetRemaining else { return }

        WidgetCenter.shared.reloadTimelines(ofKind: "ShieldsWidget")
        WidgetCenter.shared.reloadTimelines(ofKind: "TodayStreakWidget") // Also shows shields

        dailyReloadCount += 1
        lastReloadDate = Date()
    }

    /// Smart refresh that only updates affected widgets based on what changed.
    /// This is more budget-efficient than always calling reloadAllTimelines().
    static func smartRefresh(
        stepsChanged: Bool = false,
        streakChanged: Bool = false,
        shieldsChanged: Bool = false,
        weekDataChanged: Bool = false
    ) {
        guard hasBudgetRemaining else { return }

        var refreshedAny = false

        if stepsChanged {
            for kind in stepsWidgetKinds {
                WidgetCenter.shared.reloadTimelines(ofKind: kind)
            }
            refreshedAny = true
        }

        if streakChanged {
            for kind in streakWidgetKinds {
                WidgetCenter.shared.reloadTimelines(ofKind: kind)
            }
            refreshedAny = true
        }

        if shieldsChanged {
            WidgetCenter.shared.reloadTimelines(ofKind: "ShieldsWidget")
            refreshedAny = true
        }

        if weekDataChanged {
            WidgetCenter.shared.reloadTimelines(ofKind: "TrendsWidget")
            refreshedAny = true
        }

        // Combined widget needs refresh if any core data changed
        if stepsChanged || streakChanged || shieldsChanged {
            WidgetCenter.shared.reloadTimelines(ofKind: "TodayStreakWidget")
            refreshedAny = true
        }

        if refreshedAny {
            dailyReloadCount += 1
            lastReloadDate = Date()
        }
    }

    /// Detect what changed and perform targeted refresh. Call this instead of
    /// refreshWidgetsIfNeeded for more efficient budget usage.
    static func detectChangesAndRefresh(
        newSteps: Int,
        newStreak: Int,
        newShields: Int
    ) {
        let stepsChanged = newSteps != previousSteps
        let streakChanged = newStreak != previousStreak
        let shieldsChanged = newShields != previousShields

        // Update tracking
        previousSteps = newSteps
        previousStreak = newStreak
        previousShields = newShields

        // Only refresh if something actually changed
        if stepsChanged || streakChanged || shieldsChanged {
            smartRefresh(
                stepsChanged: stepsChanged,
                streakChanged: streakChanged,
                shieldsChanged: shieldsChanged
            )
        }
    }
}
