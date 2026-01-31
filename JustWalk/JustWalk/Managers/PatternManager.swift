//
//  PatternManager.swift
//  JustWalk
//
//  Data foundation for user pattern detection
//

import Foundation

final class PatternManager {
    static let shared = PatternManager()

    private let persistence = PersistenceManager.shared
    private let calendar = Calendar.current

    private var data: WalkPatternData

    private static let recentWalkCap = 30
    private static let dailyHistoryDays = 90
    private static let weeklyTotalsCap = 12
    private static let cacheMaxAge: TimeInterval = 12 * 60 * 60

    private static let dayKeyFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = .current
        return formatter
    }()

    private static let isoCalendar = Calendar(identifier: .iso8601)

    private init() {
        data = persistence.loadWalkPatternData()
        if data.schemaVersion != WalkPatternData.currentSchemaVersion {
            data = .empty
        }

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleTrackedWalkSaved),
            name: .didSaveTrackedWalk,
            object: nil
        )

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleDailyLogSaved),
            name: .didSaveDailyLog,
            object: nil
        )
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    // MARK: - Public API

    func refreshIfNeeded() {
        recordMissedDailyGoalStatusesIfNeeded()
        recordWeeklyTotalsIfNeeded()
        recalculateCachedPatternsIfNeeded()
    }

    var cachedTypicalHour: Int? {
        data.cachedTypicalHour
    }

    var cachedPreferredWalkType: String? {
        data.cachedPreferredWalkType
    }

    func recordWalkCompleted(type: WalkMode, at time: Date) {
        guard let key = walkTypeKey(for: type) else { return }

        data.recentWalkTimes.append(time)
        if data.recentWalkTimes.count > Self.recentWalkCap {
            data.recentWalkTimes = Array(data.recentWalkTimes.suffix(Self.recentWalkCap))
        }

        data.walkTypeCounts[key, default: 0] += 1
        persist()
        recalculateCachedPatternsIfNeeded(force: true)
    }

    func recordDailyGoalStatus(met: Bool, for date: Date) {
        let today = calendar.startOfDay(for: Date())
        let day = calendar.startOfDay(for: date)
        guard day < today else { return }

        let key = Self.dayKeyFormatter.string(from: day)
        data.dailyGoalHistory[key] = met
        pruneDailyHistory()
        data.lastDailyGoalRecordedDate = day
        persist()
        recalculateCachedPatternsIfNeeded(force: true)
    }

    func recordWeeklyTotal(steps: Int, for weekKey: String) {
        data.weeklyStepTotals[weekKey] = steps
        pruneWeeklyTotals()
        data.lastWeeklyTotalRecordedWeek = weekKey
        persist()
        recalculateCachedPatternsIfNeeded(force: true)
    }

    func recalculateCachedPatternsIfNeeded(force: Bool = false) {
        if !force, let last = data.cacheLastUpdated, Date().timeIntervalSince(last) < Self.cacheMaxAge {
            return
        }
        data.cachedTypicalHour = computeTypicalWalkHour(from: data.recentWalkTimes)
        data.cachedPreferredWalkType = computePreferredWalkType(from: data.walkTypeCounts)
        let dayPatterns = computeDayPatterns(from: data.dailyGoalHistory)
        data.cachedBestDay = dayPatterns.best
        data.cachedHardestDay = dayPatterns.hardest
        data.cachedWeeklyTrend = computeWeeklyTrend(from: data.weeklyStepTotals)
        data.cacheLastUpdated = Date()
        persist()
    }

    // MARK: - Computation

    func computeTypicalWalkHour(from walkTimes: [Date]) -> Int? {
        guard walkTimes.count >= 5 else { return nil }
        var counts: [Int: Int] = [:]
        var latestTimeForHour: [Int: Date] = [:]

        for time in walkTimes {
            let hour = calendar.component(.hour, from: time)
            counts[hour, default: 0] += 1
            if let existing = latestTimeForHour[hour] {
                if time > existing { latestTimeForHour[hour] = time }
            } else {
                latestTimeForHour[hour] = time
            }
        }

        let maxCount = counts.values.max() ?? 0
        let tiedHours = counts.filter { $0.value == maxCount }.map { $0.key }
        guard let hour = tiedHours.max(by: { (a, b) in
            let aDate = latestTimeForHour[a] ?? .distantPast
            let bDate = latestTimeForHour[b] ?? .distantPast
            if aDate == bDate { return a < b }
            return aDate < bDate
        }) else { return nil }
        return hour
    }

    func computePreferredWalkType(from counts: [String: Int]) -> String? {
        let total = counts.values.reduce(0, +)
        guard total >= 5 else { return nil }
        guard let maxValue = counts.values.max() else { return nil }

        let topTypes = counts.filter { $0.value == maxValue }.map { $0.key }
        if topTypes.count != 1 {
            return nil
        }

        let winner = topTypes[0]
        let share = Double(maxValue) / Double(total)
        return share > 0.40 ? winner : nil
    }

    func computeDayPatterns(from history: [String: Bool]) -> (best: Int?, hardest: Int?) {
        let days = parseDayHistory(history)
        let totalWeeks = days.totalWeeks
        guard totalWeeks >= 4 else { return (nil, nil) }

        var rates: [Int: Double] = [:]
        for (weekday, stats) in days.dayStats {
            guard stats.total >= 4 else { continue }
            rates[weekday] = stats.successRate
        }
        guard rates.count >= 2 else { return (nil, nil) }

        let maxRate = rates.values.max() ?? 0
        let minRate = rates.values.min() ?? 0
        if maxRate == minRate {
            return (nil, nil)
        }

        let bestCandidates = rates.filter { $0.value == maxRate }.map { $0.key }
        let hardestCandidates = rates.filter { $0.value == minRate }.map { $0.key }

        let best = bestCandidates.min()
        let hardest = hardestCandidates.min()
        return (best, hardest)
    }

    func computeWeeklyTrend(from weeklyTotals: [String: Int]) -> TrendDirection {
        let sorted = weeklyTotals
            .compactMap { key, value -> (Date, Int)? in
                guard let start = weekStartDate(from: key) else { return nil }
                return (start, value)
            }
            .sorted { $0.0 < $1.0 }

        guard sorted.count >= 4 else { return .insufficientData }
        let lastFour = Array(sorted.suffix(4)).map { $0.1 }
        let firstTwo = Double(lastFour[0] + lastFour[1]) / 2.0
        let lastTwo = Double(lastFour[2] + lastFour[3]) / 2.0

        if firstTwo == 0 {
            return lastTwo > 0 ? .improving : .stable
        }

        let change = (lastTwo - firstTwo) / firstTwo
        if change > 0.10 { return .improving }
        if change < -0.10 { return .declining }
        return .stable
    }

    // MARK: - Notifications

    @objc private func handleTrackedWalkSaved() {
        guard let latest = persistence.loadAllTrackedWalks().last else { return }
        recordWalkCompleted(type: latest.mode, at: latest.startTime)
    }

    @objc private func handleDailyLogSaved() {
        // Only process past days; today is too volatile.
        let today = calendar.startOfDay(for: Date())
        guard let latest = persistence.loadAllDailyLogs().first else { return }
        let day = calendar.startOfDay(for: latest.date)
        guard day < today else { return }

        recordDailyGoalStatus(met: latest.goalMet, for: day)
        recordWeeklyTotalForDateIfNeeded(day)
    }

    // MARK: - Incremental Catch-up

    private func recordMissedDailyGoalStatusesIfNeeded() {
        let today = calendar.startOfDay(for: Date())
        let lastRecorded = data.lastDailyGoalRecordedDate ??
            calendar.date(byAdding: .day, value: -Self.dailyHistoryDays, to: today) ?? today

        let start = min(lastRecorded, today)
        guard let dayCount = calendar.dateComponents([.day], from: start, to: today).day else { return }
        guard dayCount > 1 else { return }

        for offset in 1..<dayCount {
            guard let date = calendar.date(byAdding: .day, value: offset, to: start) else { continue }
            let day = calendar.startOfDay(for: date)
            if day >= today { continue }

            if let log = persistence.loadDailyLog(for: day) {
                recordDailyGoalStatus(met: log.goalMet, for: day)
            } else {
                recordDailyGoalStatus(met: false, for: day)
            }
        }
    }

    private func recordWeeklyTotalsIfNeeded() {
        guard let lastWeekKey = data.lastWeeklyTotalRecordedWeek,
              let lastWeekStart = weekStartDate(from: lastWeekKey) else {
            // No weekly totals yet; seed the last 4 weeks from daily logs
            seedRecentWeeklyTotals()
            return
        }

        let currentWeekKey = weekKey(for: Date())
        guard currentWeekKey != lastWeekKey else { return }

        // Fill any missing weeks between last and current
        var cursor = lastWeekStart
        while let next = Self.isoCalendar.date(byAdding: .weekOfYear, value: 1, to: cursor) {
            let key = weekKey(for: next)
            if key == currentWeekKey { break }
            recordWeeklyTotalForDateIfNeeded(next)
            cursor = next
        }
    }

    private func seedRecentWeeklyTotals() {
        let now = Date()
        for offset in 0..<4 {
            guard let weekStart = Self.isoCalendar.date(byAdding: .weekOfYear, value: -offset, to: now) else { continue }
            recordWeeklyTotalForDateIfNeeded(weekStart)
        }
    }

    private func recordWeeklyTotalForDateIfNeeded(_ date: Date) {
        let key = weekKey(for: date)
        let total = weeklyTotalFromDailyLogs(for: date)
        recordWeeklyTotal(steps: total, for: key)
    }

    // MARK: - Helpers

    private func walkTypeKey(for mode: WalkMode) -> String? {
        switch mode {
        case .interval:
            return "intervals"
        case .fatBurn:
            return "fatBurn"
        case .postMeal:
            return "postMeal"
        case .free:
            return nil
        }
    }

    private func pruneDailyHistory() {
        let cutoff = calendar.date(byAdding: .day, value: -Self.dailyHistoryDays, to: Date()) ?? Date()
        data.dailyGoalHistory = data.dailyGoalHistory.filter { key, _ in
            guard let date = Self.dayKeyFormatter.date(from: key) else { return false }
            return date >= calendar.startOfDay(for: cutoff)
        }
    }

    private func pruneWeeklyTotals() {
        let sorted = data.weeklyStepTotals
            .compactMap { key, value -> (Date, String, Int)? in
                guard let start = weekStartDate(from: key) else { return nil }
                return (start, key, value)
            }
            .sorted { $0.0 > $1.0 }

        let keep = sorted.prefix(Self.weeklyTotalsCap)
        data.weeklyStepTotals = Dictionary(uniqueKeysWithValues: keep.map { ($0.1, $0.2) })
    }

    private func weekKey(for date: Date) -> String {
        let week = Self.isoCalendar.component(.weekOfYear, from: date)
        let year = Self.isoCalendar.component(.yearForWeekOfYear, from: date)
        return String(format: "%04d-W%02d", year, week)
    }

    private func weekStartDate(from key: String) -> Date? {
        let parts = key.split(separator: "W")
        guard parts.count == 2,
              let year = Int(parts[0].trimmingCharacters(in: CharacterSet(charactersIn: "-"))),
              let week = Int(parts[1]) else { return nil }

        var components = DateComponents()
        components.yearForWeekOfYear = year
        components.weekOfYear = week
        components.weekday = 2 // Monday
        return Self.isoCalendar.date(from: components)
    }

    private func weeklyTotalFromDailyLogs(for date: Date) -> Int {
        let startOfWeek = Self.isoCalendar.dateInterval(of: .weekOfYear, for: date)?.start ?? date
        guard let endOfWeek = Self.isoCalendar.date(byAdding: .day, value: 7, to: startOfWeek) else {
            return 0
        }
        let logs = persistence.loadAllDailyLogs()
        return logs
            .filter { $0.date >= startOfWeek && $0.date < endOfWeek }
            .reduce(0) { $0 + $1.steps }
    }

    private func parseDayHistory(_ history: [String: Bool]) -> (dayStats: [Int: (total: Int, success: Int, successRate: Double)], totalWeeks: Int) {
        var perDay: [Int: (total: Int, success: Int)] = [:]
        var weekKeys: Set<String> = []

        for (key, met) in history {
            guard let date = Self.dayKeyFormatter.date(from: key) else { continue }
            let weekday = calendar.component(.weekday, from: date) - 1 // 0=Sun
            var stats = perDay[weekday] ?? (0, 0)
            stats.total += 1
            if met { stats.success += 1 }
            perDay[weekday] = stats
            weekKeys.insert(weekKey(for: date))
        }

        var results: [Int: (total: Int, success: Int, successRate: Double)] = [:]
        for (weekday, stats) in perDay {
            let rate = stats.total > 0 ? Double(stats.success) / Double(stats.total) : 0
            results[weekday] = (stats.total, stats.success, rate)
        }

        return (results, weekKeys.count)
    }

    private func persist() {
        persistence.saveWalkPatternData(data)
    }

    // MARK: - Testing Hooks

    func snapshot() -> WalkPatternData {
        data
    }

    func resetDataForTesting(_ newData: WalkPatternData = .empty) {
        data = newData
        persist()
    }
}
