//
//  WatchPersistenceManager.swift
//  JustWalkWatch Watch App
//
//  UserDefaults-based persistence for watchOS
//

import Foundation
import os

@Observable
class WatchPersistenceManager {
    static let shared = WatchPersistenceManager()

    private nonisolated static let logger = Logger(subsystem: "com.justwalk.watch", category: "Persistence")

    private let defaults = UserDefaults.standard
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    private enum Keys {
        static let streakInfo = "watch_streak_info"
        static let walkRecords = "watch_walk_records"
        static let todaySteps = "watch_today_steps"
        static let todayGoalMet = "watch_today_goal_met"
        static let todayDate = "watch_today_date"
        static let useMetricUnits = "watch_use_metric_units"
        static let shieldCount = "watch_shield_count"
    }

    private init() {}

    // MARK: - Generic Save/Load

    func save<T: Codable>(_ value: T, forKey key: String) {
        do {
            let data = try encoder.encode(value)
            defaults.set(data, forKey: key)
        } catch {
            Self.logger.error("Failed to encode \(key): \(error.localizedDescription)")
        }
    }

    func load<T: Codable>(forKey key: String) -> T? {
        guard let data = defaults.data(forKey: key) else { return nil }
        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            Self.logger.error("Failed to decode \(key): \(error.localizedDescription)")
            return nil
        }
    }

    // MARK: - Streak Info

    func saveStreakInfo(_ info: WatchStreakInfo) {
        save(info, forKey: Keys.streakInfo)
    }

    func loadStreakInfo() -> WatchStreakInfo {
        load(forKey: Keys.streakInfo) ?? .empty
    }

    // MARK: - Walk Records

    func saveWalkRecord(_ record: WatchWalkRecord) {
        var records: [WatchWalkRecord] = load(forKey: Keys.walkRecords) ?? []
        records.append(record)
        save(records, forKey: Keys.walkRecords)
    }

    func loadAllWalkRecords() -> [WatchWalkRecord] {
        load(forKey: Keys.walkRecords) ?? []
    }

    // MARK: - Today Steps

    func saveTodaySteps(_ steps: Int) {
        defaults.set(steps, forKey: Keys.todaySteps)
        defaults.set(todayDateString(), forKey: Keys.todayDate)
    }

    func loadTodaySteps() -> Int {
        guard defaults.string(forKey: Keys.todayDate) == todayDateString() else {
            return 0
        }
        return defaults.integer(forKey: Keys.todaySteps)
    }

    // MARK: - Today Goal Met

    func saveTodayGoalMet(_ met: Bool) {
        defaults.set(met, forKey: Keys.todayGoalMet)
        defaults.set(todayDateString(), forKey: Keys.todayDate)
    }

    func loadTodayGoalMet() -> Bool {
        guard defaults.string(forKey: Keys.todayDate) == todayDateString() else {
            return false
        }
        return defaults.bool(forKey: Keys.todayGoalMet)
    }

    // MARK: - Shield Count

    func saveShieldCount(_ count: Int) {
        defaults.set(count, forKey: Keys.shieldCount)
    }

    func loadShieldCount() -> Int {
        defaults.integer(forKey: Keys.shieldCount)
    }

    // MARK: - Units

    func saveUseMetricUnits(_ useMetric: Bool) {
        defaults.set(useMetric, forKey: Keys.useMetricUnits)
    }

    func loadUseMetricUnits() -> Bool {
        // Default to false (imperial/miles)
        if defaults.object(forKey: Keys.useMetricUnits) == nil {
            return false
        }
        return defaults.bool(forKey: Keys.useMetricUnits)
    }

    // MARK: - Today Walk Minutes

    func loadTodayWalkMinutes() -> Int {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let records: [WatchWalkRecord] = load(forKey: Keys.walkRecords) ?? []
        return records
            .filter { calendar.isDate($0.startTime, inSameDayAs: today) }
            .reduce(0) { $0 + $1.durationMinutes }
    }

    // MARK: - Utility

    private func todayDateString() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: Date())
    }
}
