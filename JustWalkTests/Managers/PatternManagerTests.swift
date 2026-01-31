//
//  PatternManagerTests.swift
//  JustWalkTests
//
//  Tests for PatternManager computations and persistence
//

import Testing
import Foundation
@testable import JustWalk

extension SharedStateTests {
@Suite(.serialized)
struct PatternManagerTests {

    private let manager = PatternManager.shared
    private let persistence = PersistenceManager.shared
    private let calendar = Calendar.current

    init() {
        persistence.clearAllData()
        manager.resetDataForTesting()
    }

    // MARK: - Typical Walk Hour

    @Test func computeTypicalWalkHour_singlePeak() {
        let base = Date(timeIntervalSince1970: 1_700_000_000)
        let times = (0..<10).compactMap { offset in
            dateBySettingHour(18, on: calendar.date(byAdding: .day, value: offset, to: base) ?? base)
        }
        #expect(manager.computeTypicalWalkHour(from: times) == 18)
    }

    @Test func computeTypicalWalkHour_tiePicksMostRecent() {
        let base = Date(timeIntervalSince1970: 1_700_000_000)
        var times: [Date] = []
        for offset in 0..<5 {
            if let date = calendar.date(byAdding: .day, value: offset, to: base) {
                times.append(dateBySettingHour(18, on: date))
            }
        }
        for offset in 5..<10 {
            if let date = calendar.date(byAdding: .day, value: offset, to: base) {
                times.append(dateBySettingHour(7, on: date))
            }
        }
        #expect(manager.computeTypicalWalkHour(from: times) == 7)
    }

    @Test func computeTypicalWalkHour_insufficientData() {
        let base = Date(timeIntervalSince1970: 1_700_000_000)
        let times = (0..<3).map { offset in
            dateBySettingHour(9, on: calendar.date(byAdding: .day, value: offset, to: base) ?? base)
        }
        #expect(manager.computeTypicalWalkHour(from: times) == nil)
    }

    // MARK: - Preferred Walk Type

    @Test func computePreferredWalkType_returnsWinner() {
        let counts = ["intervals": 8, "postMeal": 2]
        #expect(manager.computePreferredWalkType(from: counts) == "intervals")
    }

    @Test func computePreferredWalkType_noClearPreference() {
        let counts = ["intervals": 4, "postMeal": 3, "fatBurn": 3]
        #expect(manager.computePreferredWalkType(from: counts) == nil)
    }

    @Test func computePreferredWalkType_insufficientData() {
        let counts = ["intervals": 3]
        #expect(manager.computePreferredWalkType(from: counts) == nil)
    }

    // MARK: - Day Patterns

    @Test func computeDayPatterns_bestAndHardest() {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = .current

        let baseSunday = dateBySettingHour(10, on: Date(timeIntervalSince1970: 1_700_000_000))
        var history: [String: Bool] = [:]

        for week in 0..<4 {
            if let sunday = calendar.date(byAdding: .weekOfYear, value: week, to: baseSunday) {
                history[formatter.string(from: sunday)] = true
            }
            if let monday = calendar.date(byAdding: .day, value: 1, to: calendar.date(byAdding: .weekOfYear, value: week, to: baseSunday) ?? baseSunday) {
                history[formatter.string(from: monday)] = (week < 2)
            }
        }

        let result = manager.computeDayPatterns(from: history)
        #expect(result.best == 0)
        #expect(result.hardest == 1)
    }

    @Test func computeDayPatterns_insufficientWeeks() {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = .current

        let base = Date(timeIntervalSince1970: 1_700_000_000)
        var history: [String: Bool] = [:]
        for day in 0..<10 {
            if let date = calendar.date(byAdding: .day, value: day, to: base) {
                history[formatter.string(from: date)] = true
            }
        }
        let result = manager.computeDayPatterns(from: history)
        #expect(result.best == nil)
        #expect(result.hardest == nil)
    }

    // MARK: - Weekly Trend

    @Test func computeWeeklyTrend_improving() {
        let totals = [
            weekKey(forWeeksAgo: 3): 10000,
            weekKey(forWeeksAgo: 2): 12000,
            weekKey(forWeeksAgo: 1): 15000,
            weekKey(forWeeksAgo: 0): 17000
        ]
        #expect(manager.computeWeeklyTrend(from: totals) == .improving)
    }

    @Test func computeWeeklyTrend_insufficientData() {
        let totals = [weekKey(forWeeksAgo: 0): 12000]
        #expect(manager.computeWeeklyTrend(from: totals) == .insufficientData)
    }

    // MARK: - Persistence

    @Test func patternData_persistsAcrossReloads() {
        var data = WalkPatternData.empty
        data.recentWalkTimes = [Date()]
        data.walkTypeCounts = ["intervals": 2]
        persistence.saveWalkPatternData(data)

        let loaded = persistence.loadWalkPatternData()
        #expect(loaded.recentWalkTimes.count == 1)
        #expect(loaded.walkTypeCounts["intervals"] == 2)
    }

    // MARK: - Cache Invalidation

    @Test func cacheRecalculatesWhenStale() {
        let base = Date(timeIntervalSince1970: 1_700_000_000)
        let times = (0..<5).map { offset in
            dateBySettingHour(6, on: calendar.date(byAdding: .day, value: offset, to: base) ?? base)
        }

        var data = WalkPatternData.empty
        data.recentWalkTimes = times
        data.cacheLastUpdated = Date(timeIntervalSinceNow: -13 * 60 * 60)
        manager.resetDataForTesting(data)

        manager.recalculateCachedPatternsIfNeeded()
        let snapshot = manager.snapshot()
        #expect(snapshot.cachedTypicalHour == 6)
    }

    // MARK: - Helpers

    private func dateBySettingHour(_ hour: Int, on date: Date) -> Date {
        var components = calendar.dateComponents([.year, .month, .day], from: date)
        components.hour = hour
        components.minute = 0
        components.second = 0
        return calendar.date(from: components) ?? date
    }

    private func weekKey(forWeeksAgo weeks: Int) -> String {
        let iso = Calendar(identifier: .iso8601)
        let date = iso.date(byAdding: .weekOfYear, value: -weeks, to: Date()) ?? Date()
        let week = iso.component(.weekOfYear, from: date)
        let year = iso.component(.yearForWeekOfYear, from: date)
        return String(format: "%04d-W%02d", year, week)
    }
}
}
