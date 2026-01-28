//
//  StreakDataTests.swift
//  JustWalkTests
//
//  Tests for StreakData model
//

import Testing
import Foundation
@testable import JustWalk

struct StreakDataTests {

    @Test func defaultStreakData_hasZeroStreaks() {
        let data = StreakData.empty
        #expect(data.currentStreak == 0)
        #expect(data.longestStreak == 0)
        #expect(data.lastGoalMetDate == nil)
        #expect(data.streakStartDate == nil)
    }

    @Test func codableRoundTrip() throws {
        let original = StreakData(
            currentStreak: 10,
            longestStreak: 25,
            lastGoalMetDate: Date(),
            streakStartDate: Calendar.current.date(byAdding: .day, value: -9, to: Date())
        )
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()

        let data = try encoder.encode(original)
        let decoded = try decoder.decode(StreakData.self, from: data)

        #expect(decoded.currentStreak == original.currentStreak)
        #expect(decoded.longestStreak == original.longestStreak)
    }
}
