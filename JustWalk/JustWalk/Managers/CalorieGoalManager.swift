//
//  CalorieGoalManager.swift
//  JustWalk
//
//  Manages calorie goal settings with local persistence and CloudKit sync
//

import Foundation
import Combine
import os.log

private let logger = Logger(subsystem: "onworldtech.JustWalk", category: "CalorieGoalManager")

@MainActor
class CalorieGoalManager: ObservableObject {
    static let shared = CalorieGoalManager()

    @Published private(set) var settings: CalorieGoalSettings?

    private let persistence = PersistenceManager.shared

    private init() {
        settings = persistence.loadCalorieGoalSettings()
        logger.info("CalorieGoalManager initialized, hasGoal=\(self.hasGoal)")
    }

    // MARK: - Public API

    /// Whether a calorie goal is set
    var hasGoal: Bool {
        settings != nil
    }

    /// The daily calorie goal, or nil if not set
    var dailyGoal: Int? {
        settings?.dailyGoal
    }

    /// The calculated maintenance calories, or nil if not set
    var calculatedMaintenance: Int? {
        settings?.calculatedMaintenance
    }

    /// Save a new or updated calorie goal
    func saveGoal(_ newSettings: CalorieGoalSettings) {
        var settingsToSave = newSettings
        settingsToSave.modifiedAt = Date()
        persistence.saveCalorieGoalSettings(settingsToSave)
        settings = settingsToSave
        logger.info("Saved calorie goal: \(settingsToSave.dailyGoal) cal")
    }

    /// Delete the calorie goal
    func deleteGoal() {
        persistence.deleteCalorieGoalSettings()
        settings = nil
        logger.info("Deleted calorie goal")
    }

    /// Reload settings from persistence (e.g., after CloudKit sync)
    func refreshFromPersistence() {
        settings = persistence.loadCalorieGoalSettings()
        logger.info("Refreshed from persistence, hasGoal=\(self.hasGoal)")
    }

    // MARK: - Goal Progress Calculation

    /// Calculate calories remaining for a given intake
    /// Returns negative if over goal
    func caloriesRemaining(currentIntake: Int) -> Int? {
        guard let goal = dailyGoal else { return nil }
        return goal - currentIntake
    }

    /// Get progress percentage (0.0 to 1.0+)
    func progressPercentage(currentIntake: Int) -> Double? {
        guard let goal = dailyGoal, goal > 0 else { return nil }
        return Double(currentIntake) / Double(goal)
    }

    /// Get display state for the goal
    func goalState(currentIntake: Int) -> GoalState? {
        guard let goal = dailyGoal else { return nil }
        let remaining = goal - currentIntake

        if abs(remaining) <= 50 {
            return .onTarget
        } else if remaining > 0 {
            return .under(remaining: remaining)
        } else {
            return .over(amount: abs(remaining))
        }
    }

    enum GoalState {
        case under(remaining: Int)
        case onTarget
        case over(amount: Int)
    }
}
