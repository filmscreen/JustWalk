//
//  StreakManagerTests.swift
//  JustWalkTests
//
//  Tests for StreakManager streak logic, weekly jackpot, and persistence
//

import Testing
import Foundation
@testable import JustWalk

extension SharedStateTests {
@Suite(.serialized)
struct StreakManagerTests {

    private let manager = StreakManager.shared
    private let persistence = PersistenceManager.shared

    init() {
        persistence.clearAllData()
        manager.streakData = .empty
        manager.streakData.consecutiveGoalDays = 0
    }

    // MARK: - Record Goal Met

    @Test func recordGoalMet_incrementsCurrentStreak() {
        manager.streakData = .empty
        manager.streakData.consecutiveGoalDays = 0

        manager.recordGoalMet(forDate: Date())
        #expect(manager.streakData.currentStreak == 1)

        persistence.clearAllData()
    }

    @Test func recordGoalMet_consecutiveDays_streakGrows() {
        let calendar = Calendar.current
        let yesterday = calendar.startOfDay(for: calendar.date(byAdding: .day, value: -1, to: Date())!)

        manager.streakData = .empty
        manager.streakData.consecutiveGoalDays = 0

        // Record yesterday
        manager.recordGoalMet(forDate: yesterday)
        #expect(manager.streakData.currentStreak == 1)

        // Record today
        let today = calendar.startOfDay(for: Date())
        manager.recordGoalMet(forDate: today)
        #expect(manager.streakData.currentStreak == 2)

        persistence.clearAllData()
    }

    // MARK: - Break Streak

    @Test func breakStreak_resetsCurrentStreakToZero() {
        manager.streakData = StreakData(
            currentStreak: 10,
            longestStreak: 10,
            lastGoalMetDate: Date(),
            streakStartDate: Date()
        )
        manager.breakStreak()
        #expect(manager.streakData.currentStreak == 0)
        #expect(manager.streakData.streakStartDate == nil)
        #expect(manager.streakData.lastGoalMetDate == nil)

        persistence.clearAllData()
    }

    // MARK: - Longest Streak

    @Test func longestStreak_updatesWhenCurrentExceedsIt() {
        manager.streakData = .empty
        manager.streakData.consecutiveGoalDays = 0

        let calendar = Calendar.current
        let twoDaysAgo = calendar.startOfDay(for: calendar.date(byAdding: .day, value: -2, to: Date())!)
        let yesterday = calendar.startOfDay(for: calendar.date(byAdding: .day, value: -1, to: Date())!)
        let today = calendar.startOfDay(for: Date())

        manager.recordGoalMet(forDate: twoDaysAgo)
        manager.recordGoalMet(forDate: yesterday)
        manager.recordGoalMet(forDate: today)

        #expect(manager.streakData.currentStreak == 3)
        #expect(manager.streakData.longestStreak == 3)

        persistence.clearAllData()
    }

    @Test func longestStreak_preservedWhenCurrentStreakBreaks() {
        manager.streakData = StreakData(
            currentStreak: 5,
            longestStreak: 15,
            lastGoalMetDate: Date(),
            streakStartDate: Date()
        )
        manager.breakStreak()
        #expect(manager.streakData.currentStreak == 0)
        #expect(manager.streakData.longestStreak == 15)

        persistence.clearAllData()
    }

    // MARK: - Repair Streak

    @Test func repairStreak_restoresStreakToLength() {
        manager.streakData = .empty

        let startDate = Calendar.current.date(byAdding: .day, value: -9, to: Date())!
        manager.repairStreak(toLength: 10, startDate: startDate)

        #expect(manager.streakData.currentStreak == 10)
        #expect(manager.streakData.longestStreak == 10)

        persistence.clearAllData()
    }

    // MARK: - Weekly Jackpot

    @Test func weeklyJackpotProgress_tracksConsecutiveGoalDays() {
        manager.streakData.consecutiveGoalDays = 5
        #expect(manager.weeklyJackpotProgress == 5)
    }

    @Test func weeklyJackpotEarned_at7ConsecutiveDays() {
        manager.streakData.consecutiveGoalDays = 7
        #expect(manager.weeklyJackpotEarned == true)
    }

    @Test func weeklyJackpotEarned_notAt6Days() {
        manager.streakData.consecutiveGoalDays = 6
        #expect(manager.weeklyJackpotEarned == false)
    }

    // MARK: - Persistence

    @Test func streakData_persistsAcrossReloads() {
        manager.streakData = .empty
        manager.streakData.consecutiveGoalDays = 0

        manager.recordGoalMet(forDate: Date())
        #expect(manager.streakData.currentStreak == 1)

        // Simulate reload
        let loadedStreak = persistence.loadStreakData()
        #expect(loadedStreak.currentStreak == 1)

        persistence.clearAllData()
    }

    // MARK: - Shield Used

    @Test func recordShieldUsed_resetsWeeklyJackpotProgress() {
        manager.streakData.consecutiveGoalDays = 5
        manager.streakData = StreakData(
            currentStreak: 5,
            longestStreak: 5,
            lastGoalMetDate: Calendar.current.date(byAdding: .day, value: -1, to: Date()),
            streakStartDate: Calendar.current.date(byAdding: .day, value: -4, to: Date())
        )

        manager.recordShieldUsed(forDate: Date())
        #expect(manager.streakData.consecutiveGoalDays == 0)

        persistence.clearAllData()
    }
}
} // extension SharedStateTests
