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

    private static let dailyLogDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

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
        NotificationCenter.default.post(name: .didSaveProfile, object: nil)
    }

    func loadProfile() -> UserProfile {
        load(forKey: Keys.profile) ?? .default
    }

    // MARK: - Streak Data Methods

    func saveStreakData(_ data: StreakData) {
        save(data, forKey: Keys.streakData)
        NotificationCenter.default.post(name: .didSaveStreakData, object: nil)
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
        let key = Self.dailyLogDateFormatter.string(from: date)
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

    // MARK: - Tracked Walk Methods

    func saveTrackedWalk(_ walk: TrackedWalk) {
        var walks = _cachedTrackedWalks ?? load(forKey: Keys.trackedWalks) ?? []
        walks.append(walk)
        save(walks, forKey: Keys.trackedWalks)
        _cachedTrackedWalks = walks
        NotificationCenter.default.post(name: .didSaveTrackedWalk, object: nil)
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

    // MARK: - Utility Methods

    func clearAllData() {
        let keys = [
            Keys.profile,
            Keys.streakData,
            Keys.shieldData,
            Keys.dailyLogs,
            Keys.trackedWalks,
            Keys.intervalUsage,
            Keys.fatBurnUsage
        ]
        keys.forEach { defaults.removeObject(forKey: $0) }
        invalidateCaches()
    }

    /// Invalidate in-memory caches (e.g. after CloudKit sync or data reset)
    func invalidateCaches() {
        _cachedTrackedWalks = nil
        _cachedDailyLogs = nil
        cachedUseMetric = loadProfile().useMetricUnits
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
