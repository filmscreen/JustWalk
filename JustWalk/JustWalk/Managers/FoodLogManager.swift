//
//  FoodLogManager.swift
//  JustWalk
//
//  Manages CRUD operations for food log entries
//

import Foundation
import Combine
import os.log

private let foodLogLogger = Logger(subsystem: "onworldtech.JustWalk", category: "FoodLogManager")

@MainActor
class FoodLogManager: ObservableObject {
    static let shared = FoodLogManager()

    @Published var foodLogs: [FoodLog] = []
    @Published var isLoading: Bool = false

    private let calendar = Calendar.current
    private let persistence = PersistenceManager.shared

    private init() {
        foodLogLogger.info("FoodLogManager initialized")
        // Load all food logs from persistence on init
        foodLogs = persistence.loadAllFoodLogs()
    }

    // MARK: - CRUD Operations

    /// Load logs for a specific date (refreshes the published foodLogs array)
    @discardableResult
    func loadLogs(for date: Date) -> [FoodLog] {
        isLoading = true
        defer { isLoading = false }

        let logs = getLogs(for: date)
        foodLogLogger.info("Loaded \(logs.count) logs for \(date.formatted(date: .abbreviated, time: .omitted))")
        return logs
    }

    /// Add a new food log entry
    func addLog(_ log: FoodLog) {
        foodLogs.append(log)
        foodLogs.sort { $0.createdAt < $1.createdAt }
        persistence.saveFoodLog(log)
        foodLogLogger.info("Added food log: \(log.name) (\(log.calories) cal)")
    }

    /// Update an existing food log entry
    func updateLog(_ log: FoodLog) {
        guard let index = foodLogs.firstIndex(where: { $0.id == log.id }) else {
            foodLogLogger.warning("Attempted to update non-existent log: \(log.id)")
            return
        }

        var updatedLog = log
        updatedLog.modifiedAt = Date()
        foodLogs[index] = updatedLog
        persistence.saveFoodLog(updatedLog)
        foodLogLogger.info("Updated food log: \(log.name)")
    }

    /// Delete a food log entry
    func deleteLog(_ log: FoodLog) {
        foodLogs.removeAll { $0.id == log.id }
        persistence.deleteFoodLog(log)
        foodLogLogger.info("Deleted food log: \(log.name)")
    }

    // MARK: - Query Methods

    /// Get all logs for a specific date
    func getLogs(for date: Date) -> [FoodLog] {
        let startOfDay = calendar.startOfDay(for: date)
        guard let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) else {
            return []
        }

        return foodLogs.filter { log in
            log.date >= startOfDay && log.date < endOfDay
        }.sorted { $0.createdAt < $1.createdAt }
    }

    /// Get logs grouped by meal type for a specific date
    func getLogsByMeal(for date: Date) -> [MealType: [FoodLog]] {
        let logsForDate = getLogs(for: date)
        var grouped: [MealType: [FoodLog]] = [:]

        for mealType in MealType.allCases {
            let mealsOfType = logsForDate.filter { $0.mealType == mealType }
            if !mealsOfType.isEmpty {
                grouped[mealType] = mealsOfType
            }
        }

        return grouped
    }

    /// Get daily nutrition summary for a specific date
    func getDailySummary(for date: Date) -> (calories: Int, protein: Int, carbs: Int, fat: Int) {
        let logsForDate = getLogs(for: date)

        let totalCalories = logsForDate.reduce(0) { $0 + $1.calories }
        let totalProtein = logsForDate.reduce(0) { $0 + $1.protein }
        let totalCarbs = logsForDate.reduce(0) { $0 + $1.carbs }
        let totalFat = logsForDate.reduce(0) { $0 + $1.fat }

        return (calories: totalCalories, protein: totalProtein, carbs: totalCarbs, fat: totalFat)
    }

    // MARK: - Convenience Methods

    /// Get today's logs
    func getTodayLogs() -> [FoodLog] {
        return getLogs(for: Date())
    }

    /// Get today's summary
    func getTodaySummary() -> (calories: Int, protein: Int, carbs: Int, fat: Int) {
        return getDailySummary(for: Date())
    }

    /// Check if there are any logs for a date
    func hasLogs(for date: Date) -> Bool {
        return !getLogs(for: date).isEmpty
    }

    /// Get total log count
    var totalLogCount: Int {
        return foodLogs.count
    }

    // MARK: - Average Calculations

    /// Nutrition averages for a time period (only days with logged food are included)
    struct NutritionAverages {
        let calories: Double
        let protein: Double
        let carbs: Double
        let fat: Double
        let daysWithData: Int

        /// Rounded calorie average for display
        var caloriesRounded: Int { Int(calories.rounded()) }
        /// Rounded protein average for display
        var proteinRounded: Int { Int(protein.rounded()) }
        /// Rounded carbs average for display
        var carbsRounded: Int { Int(carbs.rounded()) }
        /// Rounded fat average for display
        var fatRounded: Int { Int(fat.rounded()) }

        static let zero = NutritionAverages(calories: 0, protein: 0, carbs: 0, fat: 0, daysWithData: 0)
    }

    /// Calculate weekly averages (last 7 days, only days with data)
    func getWeeklyAverages() -> NutritionAverages {
        return getAverages(forDays: 7)
    }

    /// Calculate monthly averages (last 30 days, only days with data)
    func getMonthlyAverages() -> NutritionAverages {
        return getAverages(forDays: 30)
    }

    /// Calculate averages for a custom number of days (only days with data)
    func getAverages(forDays days: Int) -> NutritionAverages {
        let today = calendar.startOfDay(for: Date())

        var totalCalories = 0
        var totalProtein = 0
        var totalCarbs = 0
        var totalFat = 0
        var daysWithData = 0

        for dayOffset in 0..<days {
            guard let date = calendar.date(byAdding: .day, value: -dayOffset, to: today) else {
                continue
            }

            let summary = getDailySummary(for: date)

            // Only include days that have logged food (any non-zero value)
            if summary.calories > 0 || summary.protein > 0 || summary.carbs > 0 || summary.fat > 0 {
                totalCalories += summary.calories
                totalProtein += summary.protein
                totalCarbs += summary.carbs
                totalFat += summary.fat
                daysWithData += 1
            }
        }

        // Avoid division by zero
        guard daysWithData > 0 else {
            return .zero
        }

        return NutritionAverages(
            calories: Double(totalCalories) / Double(daysWithData),
            protein: Double(totalProtein) / Double(daysWithData),
            carbs: Double(totalCarbs) / Double(daysWithData),
            fat: Double(totalFat) / Double(daysWithData),
            daysWithData: daysWithData
        )
    }

    /// Get daily summaries for a date range (for charts/trends)
    func getDailySummaries(forDays days: Int) -> [(date: Date, summary: (calories: Int, protein: Int, carbs: Int, fat: Int))] {
        let today = calendar.startOfDay(for: Date())
        var results: [(date: Date, summary: (calories: Int, protein: Int, carbs: Int, fat: Int))] = []

        for dayOffset in (0..<days).reversed() {
            guard let date = calendar.date(byAdding: .day, value: -dayOffset, to: today) else {
                continue
            }
            let summary = getDailySummary(for: date)
            results.append((date: date, summary: summary))
        }

        return results
    }

    // MARK: - Persistence Methods

    /// Reload all food logs from persistence (useful after CloudKit sync)
    func refreshFromPersistence() {
        foodLogs = persistence.loadAllFoodLogs()
        let count = foodLogs.count
        foodLogLogger.info("Refreshed food logs from persistence: \(count) total")
    }
}
