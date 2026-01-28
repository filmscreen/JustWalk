//
//  PersistenceTests.swift
//  JustWalkTests
//
//  Tests for PersistenceManager UserDefaults-based storage
//

import Testing
import Foundation
@testable import JustWalk

extension SharedStateTests {
@Suite(.serialized)
struct PersistenceTests {

    private let persistence = PersistenceManager.shared

    init() {
        persistence.clearAllData()
    }

    // MARK: - UserProfile

    @Test func saveAndLoadProfile_roundTrip() {
        var profile = UserProfile.default
        profile.displayName = "Test Walker"
        profile.dailyStepGoal = 7500
        profile.hasCompletedOnboarding = true

        persistence.saveProfile(profile)
        let loaded = persistence.loadProfile()

        #expect(loaded.displayName == "Test Walker")
        #expect(loaded.dailyStepGoal == 7500)
        #expect(loaded.hasCompletedOnboarding == true)

        persistence.clearAllData()
    }

    // MARK: - DailyLog

    @Test func saveAndLoadDailyLog_forSpecificDate() {
        let today = Calendar.current.startOfDay(for: Date())
        let log = DailyLog(
            id: UUID(),
            date: today,
            steps: 8000,
            goalMet: true,
            shieldUsed: false,
                        trackedWalkIDs: [UUID()]
        )

        persistence.saveDailyLog(log)
        let loaded = persistence.loadDailyLog(for: today)

        #expect(loaded != nil)
        #expect(loaded?.steps == 8000)
        #expect(loaded?.goalMet == true)

        persistence.clearAllData()
    }

    // MARK: - TrackedWalk

    @Test func saveAndLoadTrackedWalk_byID() {
        let walkID = UUID()
        let walk = TrackedWalk(
            id: walkID,
            startTime: Date().addingTimeInterval(-1800),
            endTime: Date(),
            durationMinutes: 30,
            steps: 3500,
            distanceMeters: 2400,
                        mode: .free,

            intervalProgram: nil,
            intervalCompleted: nil,
            routeCoordinates: []
        )

        persistence.saveTrackedWalk(walk)
        let loaded = persistence.loadTrackedWalk(by: walkID)

        #expect(loaded != nil)
        #expect(loaded?.id == walkID)
        #expect(loaded?.durationMinutes == 30)

        persistence.clearAllData()
    }

    // MARK: - StreakData

    @Test func saveAndLoadStreakData_roundTrip() {
        let streakData = StreakData(
            currentStreak: 15,
            longestStreak: 30,
            lastGoalMetDate: Date(),
            streakStartDate: Calendar.current.date(byAdding: .day, value: -14, to: Date())
        )

        persistence.saveStreakData(streakData)
        let loaded = persistence.loadStreakData()

        #expect(loaded.currentStreak == 15)
        #expect(loaded.longestStreak == 30)

        persistence.clearAllData()
    }

    // MARK: - ShieldData

    @Test func saveAndLoadShieldData_roundTrip() {
        let shieldData = ShieldData(
            availableShields: 2,
            lastRefillDate: Date(),
            shieldsUsedThisMonth: 1,
            purchasedShields: 3
        )

        persistence.saveShieldData(shieldData)
        let loaded = persistence.loadShieldData()

        #expect(loaded.availableShields == 2)
        #expect(loaded.shieldsUsedThisMonth == 1)
        #expect(loaded.purchasedShields == 3)

        persistence.clearAllData()
    }

    // MARK: - Clear All Data

    @Test func clearAllData_removesAllStoredData() {
        // Save various data
        persistence.saveProfile(UserProfile.default)
        persistence.saveStreakData(StreakData(currentStreak: 5, longestStreak: 5, lastGoalMetDate: Date(), streakStartDate: Date()))
        persistence.saveShieldData(ShieldData(availableShields: 2, lastRefillDate: Date(), shieldsUsedThisMonth: 0, purchasedShields: 0))

        persistence.clearAllData()

        // After clearing, loads should return defaults
        let streak = persistence.loadStreakData()
        #expect(streak.currentStreak == 0)
        let shield = persistence.loadShieldData()
        #expect(shield.availableShields == 0)
    }

    // MARK: - Loading Nonexistent Data

    @Test func loadingNonexistentData_returnsNilOrDefault() {
        persistence.clearAllData()

        let dailyLog = persistence.loadDailyLog(for: Date())
        #expect(dailyLog == nil)

        let walk = persistence.loadTrackedWalk(by: UUID())
        #expect(walk == nil)

        // Typed loads return defaults
        let streak = persistence.loadStreakData()
        #expect(streak.currentStreak == 0)
    }

    // MARK: - Multiple Daily Logs

    @Test func multipleDailyLogs_forDifferentDates_coexist() {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today)!

        let todayLog = DailyLog(id: UUID(), date: today, steps: 8000, goalMet: true, shieldUsed: false, trackedWalkIDs: [])
        let yesterdayLog = DailyLog(id: UUID(), date: yesterday, steps: 6000, goalMet: false, shieldUsed: true, trackedWalkIDs: [])

        persistence.saveDailyLog(todayLog)
        persistence.saveDailyLog(yesterdayLog)

        let loadedToday = persistence.loadDailyLog(for: today)
        let loadedYesterday = persistence.loadDailyLog(for: yesterday)

        #expect(loadedToday?.steps == 8000)
        #expect(loadedYesterday?.steps == 6000)
        #expect(loadedToday?.goalMet == true)
        #expect(loadedYesterday?.shieldUsed == true)

        persistence.clearAllData()
    }

    // MARK: - TrackedWalk with All Fields

    @Test func trackedWalk_withAllOptionalFieldsPopulated() {
        let walkID = UUID()
        let walk = TrackedWalk(
            id: walkID,
            startTime: Date().addingTimeInterval(-2700),
            endTime: Date(),
            durationMinutes: 45,
            steps: 5000,
            distanceMeters: 3800,
                        mode: .interval,
            intervalProgram: .medium,
            intervalCompleted: true,
            routeCoordinates: [
                CodableCoordinate(latitude: 37.7749, longitude: -122.4194),
                CodableCoordinate(latitude: 37.7750, longitude: -122.4195)
            ]
        )

        persistence.saveTrackedWalk(walk)
        let loaded = persistence.loadTrackedWalk(by: walkID)

        #expect(loaded != nil)
        #expect(loaded?.mode == .interval)
        #expect(loaded?.intervalProgram == .medium)
        #expect(loaded?.intervalCompleted == true)
        #expect(loaded?.routeCoordinates.count == 2)

        persistence.clearAllData()
    }
}
} // extension SharedStateTests
