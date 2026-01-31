//
//  PersistenceManager.swift
//  JustWalk
//
//  UserDefaults-based persistence layer
//

import Foundation
import SwiftUI
import Combine

// MARK: - Persistence Notifications

extension Notification.Name {
    static let didSaveStreakData = Notification.Name("didSaveStreakData")
    static let didSaveShieldData = Notification.Name("didSaveShieldData")
    static let didSaveDailyLog = Notification.Name("didSaveDailyLog")
    static let didSaveTrackedWalk = Notification.Name("didSaveTrackedWalk")
    static let didSaveProfile = Notification.Name("didSaveProfile")
    static let didSaveFoodLog = Notification.Name("didSaveFoodLog")
}

@Observable
class PersistenceManager: ObservableObject {
    static let shared = PersistenceManager()

    private let defaults = UserDefaults.standard
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    // Keys
    private enum Keys {
        static let profile = "user_profile"
        static let streakData = "streak_data"
        static let shieldData = "shield_data"
        static let dailyLogs = "daily_logs"
        static let trackedWalks = "tracked_walks"
        static let intervalUsage = "interval_usage"
        static let fatBurnUsage = "fat_burn_usage"
        static let walkPatternData = "walk_pattern_data_v1"
        static let foodLogs = "food_logs"
    }

    /// Incremented whenever daily logs change, so views observing this
    /// property re-render when new logs are saved.
    var dailyLogVersion: Int = 0

    /// Cached metric preference to avoid per-row profile deserialization
    private(set) var cachedUseMetric: Bool = false

    // In-memory caches to avoid repeated JSON deserialization.
    // @ObservationIgnored: these are internal caches that must NOT trigger
    // SwiftUI re-renders. Without this, calling loadDailyLog() from a view's
    // computed property mutates a tracked @Observable var during body evaluation,
    // causing an infinite re-render loop (0x8BADF00D watchdog crash).
    // UI reactivity is driven by `dailyLogVersion` instead.
    @ObservationIgnored private var _cachedTrackedWalks: [TrackedWalk]?
    @ObservationIgnored private var _cachedDailyLogs: [String: DailyLog]?
    @ObservationIgnored private var _cachedFoodLogs: [FoodLog]?

    private init() {
        cachedUseMetric = (load(forKey: Keys.profile) as UserProfile?)?.useMetricUnits ?? false
    }

    // MARK: - Generic Save/Load Methods

    func save<T: Codable>(_ value: T, forKey key: String) {
        if let data = try? encoder.encode(value) {
            defaults.set(data, forKey: key)
        }
    }

    func load<T: Codable>(forKey key: String) -> T? {
        guard let data = defaults.data(forKey: key) else { return nil }
        return try? decoder.decode(T.self, from: data)
    }

    // MARK: - Profile Methods

    func saveProfile(_ profile: UserProfile) {
        save(profile, forKey: Keys.profile)
        cachedUseMetric = profile.useMetricUnits
        UserDefaults.standard.set(profile.dailyStepGoal, forKey: "dailyStepGoal")
        NotificationCenter.default.post(name: .didSaveProfile, object: nil)
        PhoneConnectivityManager.shared.syncStreakInfoToWatch()
    }

    func loadProfile() -> UserProfile {
        load(forKey: Keys.profile) ?? .default
    }

    // MARK: - Streak Data Methods

    func saveStreakData(_ data: StreakData) {
        save(data, forKey: Keys.streakData)
        NotificationCenter.default.post(name: .didSaveStreakData, object: nil)
        PhoneConnectivityManager.shared.syncStreakInfoToWatch()
    }

    func loadStreakData() -> StreakData {
        load(forKey: Keys.streakData) ?? .empty
    }

    // MARK: - Shield Data Methods

    func saveShieldData(_ data: ShieldData) {
        save(data, forKey: Keys.shieldData)
        NotificationCenter.default.post(name: .didSaveShieldData, object: nil)
    }

    func loadShieldData() -> ShieldData {
        load(forKey: Keys.shieldData) ?? .empty
    }

    // MARK: - Daily Log Methods

    func saveDailyLog(_ log: DailyLog) {
        var logs = _cachedDailyLogs ?? load(forKey: Keys.dailyLogs) ?? [:]
        logs[log.dateString] = log
        save(logs, forKey: Keys.dailyLogs)
        _cachedDailyLogs = logs
        dailyLogVersion += 1
        NotificationCenter.default.post(name: .didSaveDailyLog, object: nil)
    }

    func loadDailyLog(for date: Date) -> DailyLog? {
        if _cachedDailyLogs == nil {
            _cachedDailyLogs = load(forKey: Keys.dailyLogs) ?? [:]
        }
        let key = DailyLog.makeDayKey(for: date)
        return _cachedDailyLogs?[key]
    }

    func loadAllDailyLogs() -> [DailyLog] {
        if _cachedDailyLogs == nil {
            _cachedDailyLogs = load(forKey: Keys.dailyLogs) ?? [:]
        }
        return _cachedDailyLogs?.values.sorted { $0.date > $1.date } ?? []
    }

    func loadDailyLogs(forMonth date: Date) -> [DailyLog] {
        let calendar = Calendar.current
        return loadAllDailyLogs().filter {
            calendar.isDate($0.date, equalTo: date, toGranularity: .month)
        }
    }

    // MARK: - Migrations

    func migrateDailyLogGoalTargetsIfNeeded() {
        let migrationKey = "daily_log_goal_target_migrated_v1"
        guard !defaults.bool(forKey: migrationKey) else { return }

        var logs: [String: DailyLog] = load(forKey: Keys.dailyLogs) ?? [:]
        var changed = false

        for (key, var log) in logs {
            if log.goalTarget == nil {
                if log.goalMet {
                    log.goalTarget = log.steps > 0 ? log.steps : 0
                } else {
                    log.goalTarget = max(log.steps + 1, 1)
                }
                logs[key] = log
                changed = true
            }
        }

        if changed {
            save(logs, forKey: Keys.dailyLogs)
            _cachedDailyLogs = logs
            dailyLogVersion += 1
        }

        defaults.set(true, forKey: migrationKey)
    }

    /// Repair migration: fixes goalTarget values that were corrupted by HealthKit sync bug.
    /// Only fixes cases where goalTarget CONTRADICTS goalMet (clearly wrong data).
    /// Does NOT try to infer goals for missing data - we can't know what the goal was.
    func repairCorruptedGoalTargets() {
        let migrationKey = "daily_log_goal_target_repair_v2"
        guard !defaults.bool(forKey: migrationKey) else { return }

        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        var logs: [String: DailyLog] = load(forKey: Keys.dailyLogs) ?? [:]
        var changed = false

        for (key, var log) in logs {
            // Skip today - today's goal can still change
            guard calendar.startOfDay(for: log.date) < today else { continue }
            // Skip if no goalTarget set - we can't fix missing data
            guard let goalTarget = log.goalTarget else { continue }
            // Skip shielded days - goalMet might be true even with low steps
            guard !log.shieldUsed else { continue }

            // Only fix clearly corrupted data where goalTarget contradicts goalMet
            let isCorrupted: Bool
            if log.goalMet && goalTarget > log.steps && log.steps > 0 {
                // Claimed to meet goal but goalTarget > steps - impossible
                // This means goalTarget was corrupted (overwritten with higher current goal)
                // We don't know the original goal, but we know it was <= steps
                isCorrupted = true
            } else if !log.goalMet && goalTarget <= log.steps && log.steps > 0 {
                // Claimed to miss goal but goalTarget <= steps - should have met it
                // This means goalTarget was corrupted (overwritten with lower current goal)
                isCorrupted = true
            } else {
                isCorrupted = false
            }

            if isCorrupted {
                // Clear the corrupted goalTarget - views will fall back to current goal
                // This is better than showing clearly wrong data
                log.goalTarget = nil
                logs[key] = log
                changed = true
            }
        }

        if changed {
            save(logs, forKey: Keys.dailyLogs)
            _cachedDailyLogs = logs
            dailyLogVersion += 1
        }

        defaults.set(true, forKey: migrationKey)
    }

    // MARK: - Tracked Walk Methods

    func saveTrackedWalk(_ walk: TrackedWalk) {
        var walks = _cachedTrackedWalks ?? load(forKey: Keys.trackedWalks) ?? []
        walks.append(walk)
        save(walks, forKey: Keys.trackedWalks)
        _cachedTrackedWalks = walks
        NotificationCenter.default.post(name: .didSaveTrackedWalk, object: nil)
    }

    // MARK: - Walk Pattern Data

    func saveWalkPatternData(_ data: WalkPatternData) {
        save(data, forKey: Keys.walkPatternData)
    }

    func loadWalkPatternData() -> WalkPatternData {
        load(forKey: Keys.walkPatternData) ?? .empty
    }

    func loadAllTrackedWalks() -> [TrackedWalk] {
        if _cachedTrackedWalks == nil {
            _cachedTrackedWalks = load(forKey: Keys.trackedWalks) ?? []
        }
        return _cachedTrackedWalks ?? []
    }

    func loadTrackedWalks(forMonth date: Date) -> [TrackedWalk] {
        let calendar = Calendar.current
        return loadAllTrackedWalks().filter {
            calendar.isDate($0.startTime, equalTo: date, toGranularity: .month)
        }
    }

    func loadTrackedWalks(forDay date: Date) -> [TrackedWalk] {
        let calendar = Calendar.current
        return loadAllTrackedWalks().filter {
            calendar.isDate($0.startTime, equalTo: date, toGranularity: .day)
        }
    }

    func loadTrackedWalk(by id: UUID) -> TrackedWalk? {
        loadAllTrackedWalks().first { $0.id == id }
    }

    func updateTrackedWalk(_ updatedWalk: TrackedWalk) {
        var walks = _cachedTrackedWalks ?? load(forKey: Keys.trackedWalks) ?? []
        if let index = walks.firstIndex(where: { $0.id == updatedWalk.id }) {
            walks[index] = updatedWalk
            save(walks, forKey: Keys.trackedWalks)
            _cachedTrackedWalks = walks
        }
    }

    func deleteTrackedWalk(_ walk: TrackedWalk) {
        var walks = _cachedTrackedWalks ?? load(forKey: Keys.trackedWalks) ?? []
        walks.removeAll { $0.id == walk.id }
        save(walks, forKey: Keys.trackedWalks)
        _cachedTrackedWalks = walks

        // Also remove walk ID from any DailyLog that references it
        let calendar = Calendar.current
        let walkDate = calendar.startOfDay(for: walk.startTime)
        if var dailyLog = loadDailyLog(for: walkDate) {
            dailyLog.trackedWalkIDs.removeAll { $0 == walk.id }
            saveDailyLog(dailyLog)
        }

        NotificationCenter.default.post(name: .didSaveTrackedWalk, object: nil)
    }

    // MARK: - Interval Usage Methods

    func saveIntervalUsage(_ data: IntervalUsageData) {
        save(data, forKey: Keys.intervalUsage)
    }

    func loadIntervalUsage() -> IntervalUsageData {
        var usage: IntervalUsageData = load(forKey: Keys.intervalUsage) ?? .empty()
        usage.resetIfNewWeek()
        return usage
    }

    // MARK: - Fat Burn Usage Methods

    func saveFatBurnUsage(_ data: FatBurnUsageData) {
        save(data, forKey: Keys.fatBurnUsage)
    }

    func loadFatBurnUsage() -> FatBurnUsageData {
        var usage: FatBurnUsageData = load(forKey: Keys.fatBurnUsage) ?? .empty()
        usage.resetIfNewWeek()
        return usage
    }

    // MARK: - Food Log Methods

    func saveFoodLog(_ log: FoodLog) {
        var logs = _cachedFoodLogs ?? load(forKey: Keys.foodLogs) ?? []
        if let index = logs.firstIndex(where: { $0.id == log.id }) {
            logs[index] = log
        } else {
            logs.append(log)
        }
        save(logs, forKey: Keys.foodLogs)
        _cachedFoodLogs = logs
        NotificationCenter.default.post(name: .didSaveFoodLog, object: nil)
    }

    func loadAllFoodLogs() -> [FoodLog] {
        if _cachedFoodLogs == nil {
            _cachedFoodLogs = load(forKey: Keys.foodLogs) ?? []
        }
        return _cachedFoodLogs ?? []
    }

    func loadFoodLogs(for date: Date) -> [FoodLog] {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        guard let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) else {
            return []
        }
        return loadAllFoodLogs().filter { log in
            log.date >= startOfDay && log.date < endOfDay
        }.sorted { $0.createdAt < $1.createdAt }
    }

    func loadFoodLog(by id: UUID) -> FoodLog? {
        loadAllFoodLogs().first { $0.id == id }
    }

    func deleteFoodLog(_ log: FoodLog) {
        var logs = _cachedFoodLogs ?? load(forKey: Keys.foodLogs) ?? []
        logs.removeAll { $0.id == log.id }
        save(logs, forKey: Keys.foodLogs)
        _cachedFoodLogs = logs
        NotificationCenter.default.post(name: .didSaveFoodLog, object: nil)
    }

    // MARK: - Utility Methods

    func clearAllData() {
        let keys = [
            Keys.profile,
            Keys.streakData,
            Keys.shieldData,
            Keys.dailyLogs,
            Keys.trackedWalks,
            Keys.intervalUsage,
            Keys.fatBurnUsage,
            Keys.walkPatternData,
            Keys.foodLogs
        ]
        keys.forEach { defaults.removeObject(forKey: $0) }
        invalidateCaches()
    }

    /// Invalidate in-memory caches (e.g. after CloudKit sync or data reset)
    func invalidateCaches() {
        _cachedTrackedWalks = nil
        _cachedDailyLogs = nil
        _cachedFoodLogs = nil
        cachedUseMetric = loadProfile().useMetricUnits
        // Increment version to trigger UI refresh for views observing this property
        dailyLogVersion += 1
    }

    /// Load all app state from persistence
    func loadAppState() -> AppState {
        let state = AppState()
        state.profile = loadProfile()
        state.streakData = loadStreakData()
        state.shieldData = loadShieldData()
        state.todayLog = loadDailyLog(for: Date())
        return state
    }

    /// Save all app state to persistence
    func saveAppState(_ state: AppState) {
        saveProfile(state.profile)
        saveStreakData(state.streakData)
        saveShieldData(state.shieldData)
        if let todayLog = state.todayLog {
            saveDailyLog(todayLog)
        }
    }
}
