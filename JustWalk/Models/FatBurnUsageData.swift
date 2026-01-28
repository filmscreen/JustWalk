//
//  FatBurnUsageData.swift
//  JustWalk
//
//  Weekly fat burn usage tracking for free-tier gating
//

import Foundation

struct FatBurnUsageData: Codable {
    var weekStartDate: Date // Monday of current tracking week
    var fatBurnsUsedThisWeek: Int

    static let freeWeeklyLimit = 1

    var remainingFree: Int {
        max(0, Self.freeWeeklyLimit - fatBurnsUsedThisWeek)
    }

    var canStartFatBurn: Bool {
        remainingFree > 0
    }

    mutating func resetIfNewWeek() {
        let currentMonday = Self.mondayOfCurrentWeek()
        if weekStartDate < currentMonday {
            weekStartDate = currentMonday
            fatBurnsUsedThisWeek = 0
        }
    }

    mutating func recordUsage() {
        resetIfNewWeek()
        fatBurnsUsedThisWeek += 1
    }

    static func empty() -> FatBurnUsageData {
        FatBurnUsageData(
            weekStartDate: mondayOfCurrentWeek(),
            fatBurnsUsedThisWeek: 0
        )
    }

    /// Compute Monday 00:00 of the current ISO week.
    private static func mondayOfCurrentWeek() -> Date {
        var calendar = Calendar(identifier: .iso8601)
        calendar.firstWeekday = 2 // Monday
        let components = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: Date())
        return calendar.date(from: components) ?? Date()
    }
}
