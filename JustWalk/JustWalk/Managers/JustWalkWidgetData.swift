//
//  JustWalkWidgetData.swift
//  JustWalk
//
//  Shared data bridge between main app and widget extension via App Group
//

import Foundation
import WidgetKit

struct JustWalkWidgetData {
    static let appGroupID = "group.com.justwalk.shared"

    static var sharedDefaults: UserDefaults {
        UserDefaults(suiteName: appGroupID) ?? .standard
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
        walkTimeMinutes: Int = 0
    ) {
        sharedDefaults.set(todaySteps, forKey: "widget_todaySteps")
        sharedDefaults.set(stepGoal, forKey: "widget_stepGoal")
        sharedDefaults.set(currentStreak, forKey: "widget_currentStreak")
        sharedDefaults.set(weekSteps, forKey: "widget_weekSteps")
        sharedDefaults.set(shieldCount, forKey: "widget_shieldCount")
        sharedDefaults.set(walkTimeMinutes, forKey: "widget_walkTimeMinutes")
        WidgetCenter.shared.reloadAllTimelines()
    }
}
