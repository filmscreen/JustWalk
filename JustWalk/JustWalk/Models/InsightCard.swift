//
//  InsightCard.swift
//  JustWalk
//
//  Pattern-based insight cards that make users feel known
//  Rare. Earned. Surprising. Brief. Warm.
//

import Foundation

enum InsightType: String, Codable, CaseIterable {
    case timing            // "6pm is your time."
    case bestDay           // "Saturdays are your day."
    case hardestDay        // "Wednesdays are tough."
    case preference        // "Intervals are your thing."
    case trend             // "You're walking more."
    case consistency       // "You've never missed a Sunday."
    case hardestDayWin     // "Wednesday. Your toughest day. Not today."
}

struct InsightCard: Equatable {
    let type: InsightType
    let primaryText: String
    let secondaryText: String

    var id: String { type.rawValue }
}

// MARK: - Insight Card Manager

final class InsightCardManager {
    static let shared = InsightCardManager()

    private let patternManager = PatternManager.shared
    private let persistence = PersistenceManager.shared
    private let defaults = UserDefaults.standard
    private let calendar = Calendar.current

    private static let minimumDaysBetweenInsights = 7
    private static let minimumDaysBetweenSameType = 30
    private static let minimumWeeksOfData = 4

    private let lastInsightDateKey = "insight_last_shown_date"
    private let insightHistoryKey = "insight_type_history"

    private init() {}

    // MARK: - Public API

    /// Returns an insight to show, or nil if none appropriate
    func selectInsight() -> InsightCard? {
        guard shouldShowInsight() else { return nil }

        // Prioritized insight selection
        // Timely insights first (context-dependent)
        if let insight = checkHardestDayWin() { return insight }
        if let insight = checkHardestDayToday() { return insight }

        // Novel insights (trends, new patterns)
        if let insight = checkTrendInsight() { return insight }
        if let insight = checkConsistencyInsight() { return insight }

        // Established patterns
        if let insight = checkBestDayInsight() { return insight }
        if let insight = checkTimingInsight() { return insight }
        if let insight = checkPreferenceInsight() { return insight }

        return nil
    }

    /// Mark an insight as shown
    func markInsightShown(_ type: InsightType) {
        defaults.set(Date(), forKey: lastInsightDateKey)

        var history = loadInsightHistory()
        history[type.rawValue] = Date()
        saveInsightHistory(history)
    }

    // MARK: - Insight Checks

    private func checkTimingInsight() -> InsightCard? {
        guard !wasRecentlyShown(.timing) else { return nil }
        guard let hour = patternManager.cachedTypicalHour else { return nil }

        let copy = PatternCopy.timingInsight(hour: hour)
        return InsightCard(type: .timing, primaryText: copy.primary, secondaryText: copy.secondary)
    }

    private func checkBestDayInsight() -> InsightCard? {
        guard !wasRecentlyShown(.bestDay) else { return nil }
        guard let bestDay = patternManager.snapshot().cachedBestDay else { return nil }

        // Calculate success rate
        let rate = calculateSuccessRate(for: bestDay)
        guard rate >= 80 else { return nil } // Only show if >80% success

        let copy = PatternCopy.bestDayInsight(day: bestDay, rate: rate)
        return InsightCard(type: .bestDay, primaryText: copy.primary, secondaryText: copy.secondary)
    }

    private func checkHardestDayToday() -> InsightCard? {
        guard !wasRecentlyShown(.hardestDay) else { return nil }
        guard let hardestDay = patternManager.snapshot().cachedHardestDay else { return nil }

        // Only show on the hardest day itself
        let todayWeekday = calendar.component(.weekday, from: Date()) - 1
        guard todayWeekday == hardestDay else { return nil }

        // Only show if goal not yet met
        let goalMet = HealthKitManager.shared.todaySteps >= persistence.loadProfile().dailyStepGoal
        guard !goalMet else { return nil }

        let copy = PatternCopy.hardestDayInsight(day: hardestDay)
        return InsightCard(type: .hardestDay, primaryText: copy.primary, secondaryText: copy.secondary)
    }

    private func checkHardestDayWin() -> InsightCard? {
        guard !wasRecentlyShown(.hardestDayWin) else { return nil }
        guard let hardestDay = patternManager.snapshot().cachedHardestDay else { return nil }

        // Only show on the hardest day
        let todayWeekday = calendar.component(.weekday, from: Date()) - 1
        guard todayWeekday == hardestDay else { return nil }

        // Only show if goal WAS met today
        let goalMet = HealthKitManager.shared.todaySteps >= persistence.loadProfile().dailyStepGoal
        guard goalMet else { return nil }

        let copy = PatternCopy.hardestDayConquered(day: hardestDay)
        return InsightCard(type: .hardestDayWin, primaryText: copy.primary, secondaryText: copy.secondary)
    }

    private func checkPreferenceInsight() -> InsightCard? {
        guard !wasRecentlyShown(.preference) else { return nil }
        guard let preferredType = patternManager.cachedPreferredWalkType else { return nil }

        let snapshot = patternManager.snapshot()
        let counts = snapshot.walkTypeCounts
        let total = counts.values.reduce(0, +)
        guard total >= 15 else { return nil } // Need enough walks

        let count = counts[preferredType] ?? 0
        let share = Double(count) / Double(total)
        guard share >= 0.60 else { return nil } // >60% of walks

        let copy = PatternCopy.preferenceInsight(type: preferredType, count: count, total: total)
        return InsightCard(type: .preference, primaryText: copy.primary, secondaryText: copy.secondary)
    }

    private func checkTrendInsight() -> InsightCard? {
        guard !wasRecentlyShown(.trend) else { return nil }

        let snapshot = patternManager.snapshot()
        guard snapshot.cachedWeeklyTrend == .improving else { return nil }

        // Calculate actual percent change
        let percentChange = calculateTrendPercentage(from: snapshot.weeklyStepTotals)
        guard percentChange >= 10 else { return nil } // At least 10% improvement

        let copy = PatternCopy.trendInsight(percentChange: percentChange)
        return InsightCard(type: .trend, primaryText: copy.primary, secondaryText: copy.secondary)
    }

    private func checkConsistencyInsight() -> InsightCard? {
        guard !wasRecentlyShown(.consistency) else { return nil }

        // Find a day with 4+ consecutive weeks of success
        let snapshot = patternManager.snapshot()
        guard let (day, weeks) = findConsistentDay(from: snapshot.dailyGoalHistory) else { return nil }
        guard weeks >= 4 else { return nil }

        let copy = PatternCopy.consistencyInsight(day: day, weeks: weeks)
        return InsightCard(type: .consistency, primaryText: copy.primary, secondaryText: copy.secondary)
    }

    // MARK: - Helpers

    private func shouldShowInsight() -> Bool {
        // Check if shown recently
        if let lastShown = defaults.object(forKey: lastInsightDateKey) as? Date {
            let daysSince = calendar.dateComponents([.day], from: lastShown, to: Date()).day ?? 0
            if daysSince < Self.minimumDaysBetweenInsights {
                return false
            }
        }
        return true
    }

    private func wasRecentlyShown(_ type: InsightType) -> Bool {
        let history = loadInsightHistory()
        guard let lastShown = history[type.rawValue] else { return false }
        let daysSince = calendar.dateComponents([.day], from: lastShown, to: Date()).day ?? 0
        return daysSince < Self.minimumDaysBetweenSameType
    }

    private func loadInsightHistory() -> [String: Date] {
        guard let data = defaults.data(forKey: insightHistoryKey),
              let decoded = try? JSONDecoder().decode([String: Date].self, from: data) else {
            return [:]
        }
        return decoded
    }

    private func saveInsightHistory(_ history: [String: Date]) {
        if let data = try? JSONEncoder().encode(history) {
            defaults.set(data, forKey: insightHistoryKey)
        }
    }

    private func calculateSuccessRate(for weekday: Int) -> Int {
        let snapshot = patternManager.snapshot()
        let history = snapshot.dailyGoalHistory

        var total = 0
        var success = 0

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"

        for (key, met) in history {
            guard let date = formatter.date(from: key) else { continue }
            let dayOfWeek = calendar.component(.weekday, from: date) - 1
            if dayOfWeek == weekday {
                total += 1
                if met { success += 1 }
            }
        }

        guard total > 0 else { return 0 }
        return Int(Double(success) / Double(total) * 100)
    }

    private func calculateTrendPercentage(from weeklyTotals: [String: Int]) -> Int {
        let sorted = weeklyTotals
            .compactMap { key, value -> (String, Int)? in (key, value) }
            .sorted { $0.0 < $1.0 }

        guard sorted.count >= 4 else { return 0 }
        let lastFour = Array(sorted.suffix(4)).map { $0.1 }

        let firstTwo = Double(lastFour[0] + lastFour[1]) / 2.0
        let lastTwo = Double(lastFour[2] + lastFour[3]) / 2.0

        guard firstTwo > 0 else { return lastTwo > 0 ? 100 : 0 }
        return Int(((lastTwo - firstTwo) / firstTwo) * 100)
    }

    private func findConsistentDay(from history: [String: Bool]) -> (day: Int, weeks: Int)? {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"

        // Group by weekday and week
        var weekdayWeeks: [Int: Set<String>] = [:]

        for (key, met) in history where met {
            guard let date = formatter.date(from: key) else { continue }
            let weekday = calendar.component(.weekday, from: date) - 1
            let weekOfYear = calendar.component(.weekOfYear, from: date)
            let year = calendar.component(.year, from: date)
            let weekKey = "\(year)-\(weekOfYear)"

            weekdayWeeks[weekday, default: []].insert(weekKey)
        }

        // Find day with most consecutive weeks (simplified: just count weeks)
        var best: (day: Int, weeks: Int)?
        for (day, weeks) in weekdayWeeks {
            if best == nil || weeks.count > best!.weeks {
                best = (day, weeks.count)
            }
        }

        return best
    }
}
