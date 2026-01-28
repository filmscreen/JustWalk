//
//  ShieldManagerTests.swift
//  JustWalkTests
//
//  Tests for ShieldManager auto-deploy, repair, and purchase logic
//

import Testing
import Foundation
@testable import JustWalk

extension SharedStateTests {
@Suite(.serialized)
struct ShieldManagerTests {

    private let manager = ShieldManager.shared
    private let persistence = PersistenceManager.shared
    private let streakManager = StreakManager.shared

    init() {
        persistence.clearAllData()
        manager.shieldData = .empty
        streakManager.streakData = .empty
        streakManager.streakData.consecutiveGoalDays = 0
    }

    // MARK: - Auto-Deploy

    @Test func autoDeployIfAvailable_usesShieldWhenAvailable() {
        manager.shieldData = ShieldData(
            availableShields: 2,
            lastRefillDate: Date(),
            shieldsUsedThisMonth: 0,
            purchasedShields: 0
        )
        // Set up a streak to protect
        streakManager.streakData = StreakData(
            currentStreak: 5,
            longestStreak: 5,
            lastGoalMetDate: Calendar.current.date(byAdding: .day, value: -1, to: Date()),
            streakStartDate: Calendar.current.date(byAdding: .day, value: -4, to: Date())
        )

        let deployed = manager.autoDeployIfAvailable(forDate: Date())
        #expect(deployed == true)
        #expect(manager.shieldData.availableShields == 1)
        #expect(manager.shieldData.shieldsUsedThisMonth == 1)

        persistence.clearAllData()
    }

    @Test func autoDeployIfAvailable_returnsFalseWhenNoShields() {
        manager.shieldData = ShieldData(
            availableShields: 0,
            lastRefillDate: Date(),
            shieldsUsedThisMonth: 3,
            purchasedShields: 0
        )

        let deployed = manager.autoDeployIfAvailable(forDate: Date())
        #expect(deployed == false)

        persistence.clearAllData()
    }

    // MARK: - Retroactive Repair

    @Test func canRepairDate_withinSevenDays_returnsTrue() {
        let calendar = Calendar.current
        let threeDaysAgo = calendar.date(byAdding: .day, value: -3, to: Date())!
        // No daily log for that date → counts as missed
        let canRepair = manager.canRepairDate(threeDaysAgo)
        #expect(canRepair == true)

        persistence.clearAllData()
    }

    @Test func canRepairDate_beyondSevenDays_returnsFalse() {
        let calendar = Calendar.current
        let tenDaysAgo = calendar.date(byAdding: .day, value: -10, to: Date())!
        let canRepair = manager.canRepairDate(tenDaysAgo)
        #expect(canRepair == false)

        persistence.clearAllData()
    }

    @Test func repairDate_consumesShieldAndFixesStreak() {
        let calendar = Calendar.current
        let twoDaysAgo = calendar.startOfDay(for: calendar.date(byAdding: .day, value: -2, to: Date())!)

        // Set up: had a streak, then missed a day
        manager.shieldData = ShieldData(
            availableShields: 2,
            lastRefillDate: Date(),
            shieldsUsedThisMonth: 0,
            purchasedShields: 0
        )

        // Create daily logs around the gap (yesterday and today met, 2 days ago missed)
        let yesterday = calendar.startOfDay(for: calendar.date(byAdding: .day, value: -1, to: Date())!)
        let today = calendar.startOfDay(for: Date())
        persistence.saveDailyLog(DailyLog(id: UUID(), date: yesterday, steps: 5000, goalMet: true, shieldUsed: false, trackedWalkIDs: []))
        persistence.saveDailyLog(DailyLog(id: UUID(), date: today, steps: 5000, goalMet: true, shieldUsed: false, trackedWalkIDs: []))

        let repaired = manager.repairDate(twoDaysAgo)
        #expect(repaired == true)
        #expect(manager.shieldData.availableShields == 1)

        persistence.clearAllData()
    }

    // MARK: - Purchase Shields

    @Test func addPurchasedShields_incrementsAvailable() {
        manager.shieldData = ShieldData(
            availableShields: 1,
            lastRefillDate: Date(),
            shieldsUsedThisMonth: 0,
            purchasedShields: 0
        )

        manager.addPurchasedShields(1)
        #expect(manager.shieldData.availableShields == 2)
        #expect(manager.shieldData.purchasedShields == 1)

        persistence.clearAllData()
    }

    @Test func addPurchasedShields_capsAtMaxBanked() {
        manager.shieldData = ShieldData(
            availableShields: 2,
            lastRefillDate: Date(),
            shieldsUsedThisMonth: 0,
            purchasedShields: 0
        )

        manager.addPurchasedShields(5) // Try adding 5
        #expect(manager.shieldData.availableShields == ShieldData.maxBanked(isPro: false))

        persistence.clearAllData()
    }

    // MARK: - Queries

    @Test func canBuyMoreShields_whenUnderMax() {
        manager.shieldData = ShieldData(
            availableShields: 1,
            lastRefillDate: Date(),
            shieldsUsedThisMonth: 0,
            purchasedShields: 0
        )
        #expect(manager.canBuyMoreShields == true)

        persistence.clearAllData()
    }

    @Test func canBuyMoreShields_whenAtMax() {
        manager.shieldData = ShieldData(
            availableShields: 3,
            lastRefillDate: Date(),
            shieldsUsedThisMonth: 0,
            purchasedShields: 0
        )
        #expect(manager.canBuyMoreShields == false)

        persistence.clearAllData()
    }

    // MARK: - checkAndDeployForMissedDays

    @Test func noStreak_doesNothing() {
        streakManager.streakData = .empty
        manager.shieldData = ShieldData(
            availableShields: 2,
            lastRefillDate: Date(),
            shieldsUsedThisMonth: 0,
            purchasedShields: 0
        )

        let result = manager.checkAndDeployForMissedDays()
        #expect(result.shieldsDeployed == 0)
        #expect(result.streakBroken == false)

        persistence.clearAllData()
    }

    @Test func oneDayGap_deploysOneShield() {
        let calendar = Calendar.current
        let twoDaysAgo = calendar.startOfDay(for: calendar.date(byAdding: .day, value: -2, to: Date())!)

        streakManager.streakData = StreakData(
            currentStreak: 5,
            longestStreak: 5,
            lastGoalMetDate: twoDaysAgo,
            streakStartDate: calendar.date(byAdding: .day, value: -6, to: Date())
        )
        manager.shieldData = ShieldData(
            availableShields: 2,
            lastRefillDate: Date(),
            shieldsUsedThisMonth: 0,
            purchasedShields: 0
        )

        let result = manager.checkAndDeployForMissedDays()
        #expect(result.shieldsDeployed == 1)
        #expect(result.streakBroken == false)
        #expect(manager.shieldData.availableShields == 1)

        persistence.clearAllData()
    }

    @Test func multiDayGap_deploysMultiple() {
        let calendar = Calendar.current
        let fourDaysAgo = calendar.startOfDay(for: calendar.date(byAdding: .day, value: -4, to: Date())!)

        streakManager.streakData = StreakData(
            currentStreak: 10,
            longestStreak: 10,
            lastGoalMetDate: fourDaysAgo,
            streakStartDate: calendar.date(byAdding: .day, value: -13, to: Date())
        )
        manager.shieldData = ShieldData(
            availableShields: 3,
            lastRefillDate: Date(),
            shieldsUsedThisMonth: 0,
            purchasedShields: 0
        )

        let result = manager.checkAndDeployForMissedDays()
        #expect(result.shieldsDeployed == 3)
        #expect(result.streakBroken == false)
        #expect(manager.shieldData.availableShields == 0)

        persistence.clearAllData()
    }

    @Test func moreMissedThanShields_breaksStreak() {
        let calendar = Calendar.current
        let fourDaysAgo = calendar.startOfDay(for: calendar.date(byAdding: .day, value: -4, to: Date())!)

        streakManager.streakData = StreakData(
            currentStreak: 10,
            longestStreak: 10,
            lastGoalMetDate: fourDaysAgo,
            streakStartDate: calendar.date(byAdding: .day, value: -13, to: Date())
        )
        manager.shieldData = ShieldData(
            availableShields: 2,
            lastRefillDate: Date(),
            shieldsUsedThisMonth: 0,
            purchasedShields: 0
        )

        let result = manager.checkAndDeployForMissedDays()
        #expect(result.shieldsDeployed == 2)
        #expect(result.streakBroken == true)
        #expect(streakManager.streakData.currentStreak == 0)

        persistence.clearAllData()
    }

    @Test func alreadyDeployed_skips() {
        let calendar = Calendar.current
        let twoDaysAgo = calendar.startOfDay(for: calendar.date(byAdding: .day, value: -2, to: Date())!)
        let yesterday = calendar.startOfDay(for: calendar.date(byAdding: .day, value: -1, to: Date())!)

        streakManager.streakData = StreakData(
            currentStreak: 5,
            longestStreak: 5,
            lastGoalMetDate: twoDaysAgo,
            streakStartDate: calendar.date(byAdding: .day, value: -6, to: Date())
        )
        manager.shieldData = ShieldData(
            availableShields: 2,
            lastRefillDate: Date(),
            shieldsUsedThisMonth: 0,
            purchasedShields: 0
        )
        // Yesterday already has a shield used
        persistence.saveDailyLog(DailyLog(id: UUID(), date: yesterday, steps: 0, goalMet: false, shieldUsed: true, trackedWalkIDs: []))

        let result = manager.checkAndDeployForMissedDays()
        #expect(result.shieldsDeployed == 0)
        #expect(result.streakBroken == false)
        #expect(manager.shieldData.availableShields == 2)

        persistence.clearAllData()
    }

    @Test func goalMetDay_skips() {
        let calendar = Calendar.current
        let twoDaysAgo = calendar.startOfDay(for: calendar.date(byAdding: .day, value: -2, to: Date())!)
        let yesterday = calendar.startOfDay(for: calendar.date(byAdding: .day, value: -1, to: Date())!)

        streakManager.streakData = StreakData(
            currentStreak: 5,
            longestStreak: 5,
            lastGoalMetDate: twoDaysAgo,
            streakStartDate: calendar.date(byAdding: .day, value: -6, to: Date())
        )
        manager.shieldData = ShieldData(
            availableShields: 2,
            lastRefillDate: Date(),
            shieldsUsedThisMonth: 0,
            purchasedShields: 0
        )
        // Yesterday goal was met (e.g. HealthKit sync lag)
        persistence.saveDailyLog(DailyLog(id: UUID(), date: yesterday, steps: 10000, goalMet: true, shieldUsed: false, trackedWalkIDs: []))

        let result = manager.checkAndDeployForMissedDays()
        #expect(result.shieldsDeployed == 0)
        #expect(result.streakBroken == false)
        #expect(manager.shieldData.availableShields == 2)

        persistence.clearAllData()
    }

    @Test func setsLastDeployedFlag() {
        let calendar = Calendar.current
        let twoDaysAgo = calendar.startOfDay(for: calendar.date(byAdding: .day, value: -2, to: Date())!)

        streakManager.streakData = StreakData(
            currentStreak: 5,
            longestStreak: 5,
            lastGoalMetDate: twoDaysAgo,
            streakStartDate: calendar.date(byAdding: .day, value: -6, to: Date())
        )
        manager.shieldData = ShieldData(
            availableShields: 2,
            lastRefillDate: Date(),
            shieldsUsedThisMonth: 0,
            purchasedShields: 0
        )
        manager.lastDeployedOvernight = false

        _ = manager.checkAndDeployForMissedDays()
        #expect(manager.lastDeployedOvernight == true)

        persistence.clearAllData()
    }

    @Test func idempotent_secondCallNoOp() {
        let calendar = Calendar.current
        let twoDaysAgo = calendar.startOfDay(for: calendar.date(byAdding: .day, value: -2, to: Date())!)

        streakManager.streakData = StreakData(
            currentStreak: 5,
            longestStreak: 5,
            lastGoalMetDate: twoDaysAgo,
            streakStartDate: calendar.date(byAdding: .day, value: -6, to: Date())
        )
        manager.shieldData = ShieldData(
            availableShields: 2,
            lastRefillDate: Date(),
            shieldsUsedThisMonth: 0,
            purchasedShields: 0
        )

        let result1 = manager.checkAndDeployForMissedDays()
        #expect(result1.shieldsDeployed == 1)

        // Second call should be a no-op (shield already used for yesterday)
        let result2 = manager.checkAndDeployForMissedDays()
        #expect(result2.shieldsDeployed == 0)
        #expect(result2.streakBroken == false)

        persistence.clearAllData()
    }
}
} // extension SharedStateTests
