//
//  StreakShieldIntegrationTests.swift
//  JustWalkTests
//
//  Integration tests for streak + shield interactions
//

import Testing
import Foundation
@testable import JustWalk

extension SharedStateTests {
@Suite(.serialized)
struct StreakShieldIntegrationTests {

    private let persistence = PersistenceManager.shared
    private let shieldManager = ShieldManager.shared
    private let streakManager = StreakManager.shared

    init() {
        persistence.clearAllData()
        shieldManager.shieldData = .empty
        streakManager.streakData = .empty
        streakManager.streakData.consecutiveGoalDays = 0
    }

    // MARK: - Miss Day → Shield Auto-Deploys → Streak Preserved

    @Test func missDay_shieldAutoDeploys_streakPreserved() {
        let calendar = Calendar.current
        let yesterday = calendar.startOfDay(for: calendar.date(byAdding: .day, value: -1, to: Date())!)

        // Set up active streak
        streakManager.streakData = StreakData(
            currentStreak: 5,
            longestStreak: 5,
            lastGoalMetDate: calendar.date(byAdding: .day, value: -2, to: Date()),
            streakStartDate: calendar.date(byAdding: .day, value: -6, to: Date())
        )

        // Set up shields
        shieldManager.shieldData = ShieldData(
            availableShields: 2,
            lastRefillDate: Date(),
            shieldsUsedThisMonth: 0,
            purchasedShields: 0
        )

        // Auto-deploy shield for missed day
        let deployed = shieldManager.autoDeployIfAvailable(forDate: yesterday)
        #expect(deployed == true)
        #expect(shieldManager.shieldData.availableShields == 1)
        // Streak data should be updated via recordShieldUsed
        #expect(streakManager.streakData.currentStreak == 5) // Preserved, not incremented

        persistence.clearAllData()
    }

    // MARK: - Miss Day → No Shield → Streak Breaks

    @Test func missDay_noShield_streakBreaks() {
        // Set up active streak
        streakManager.streakData = StreakData(
            currentStreak: 10,
            longestStreak: 20,
            lastGoalMetDate: Calendar.current.date(byAdding: .day, value: -2, to: Date()),
            streakStartDate: Calendar.current.date(byAdding: .day, value: -11, to: Date())
        )

        // No shields available
        shieldManager.shieldData = ShieldData(
            availableShields: 0,
            lastRefillDate: Date(),
            shieldsUsedThisMonth: 3,
            purchasedShields: 0
        )

        let deployed = shieldManager.autoDeployIfAvailable(forDate: Date())
        #expect(deployed == false)

        // Break streak manually since no shield was available
        streakManager.breakStreak()
        #expect(streakManager.streakData.currentStreak == 0)
        #expect(streakManager.streakData.longestStreak == 20) // Longest preserved

        persistence.clearAllData()
    }

    // MARK: - Repair Within 7 Days

    @Test func repairWithin7Days_shieldConsumed_streakRestored() {
        let calendar = Calendar.current
        let threeDaysAgo = calendar.startOfDay(for: calendar.date(byAdding: .day, value: -3, to: Date())!)

        // Set up: create daily logs for recent days (but gap at 3 days ago)
        let twoDaysAgo = calendar.startOfDay(for: calendar.date(byAdding: .day, value: -2, to: Date())!)
        let yesterday = calendar.startOfDay(for: calendar.date(byAdding: .day, value: -1, to: Date())!)
        let today = calendar.startOfDay(for: Date())

        persistence.saveDailyLog(DailyLog(id: UUID(), date: twoDaysAgo, steps: 5000, goalMet: true, shieldUsed: false, trackedWalkIDs: []))
        persistence.saveDailyLog(DailyLog(id: UUID(), date: yesterday, steps: 5000, goalMet: true, shieldUsed: false, trackedWalkIDs: []))
        persistence.saveDailyLog(DailyLog(id: UUID(), date: today, steps: 5000, goalMet: true, shieldUsed: false, trackedWalkIDs: []))

        // Give shields
        shieldManager.shieldData = ShieldData(
            availableShields: 2,
            lastRefillDate: Date(),
            shieldsUsedThisMonth: 0,
            purchasedShields: 0
        )

        // Repair the gap day
        let canRepair = shieldManager.canRepairDate(threeDaysAgo)
        #expect(canRepair == true)

        let repaired = shieldManager.repairDate(threeDaysAgo)
        #expect(repaired == true)
        #expect(shieldManager.shieldData.availableShields == 1)

        persistence.clearAllData()
    }

    // MARK: - Repair Beyond 7 Days → Rejected

    @Test func repairBeyond7Days_rejected() {
        let calendar = Calendar.current
        let tenDaysAgo = calendar.date(byAdding: .day, value: -10, to: Date())!

        shieldManager.shieldData = ShieldData(
            availableShields: 3,
            lastRefillDate: Date(),
            shieldsUsedThisMonth: 0,
            purchasedShields: 0
        )

        let canRepair = shieldManager.canRepairDate(tenDaysAgo)
        #expect(canRepair == false)

        let repaired = shieldManager.repairDate(tenDaysAgo)
        #expect(repaired == false)
        #expect(shieldManager.shieldData.availableShields == 3) // Unchanged

        persistence.clearAllData()
    }

    // MARK: - Shield Refill Across Month Boundary

    @Test func shieldRefill_acrossMonthBoundary() {
        let calendar = Calendar.current
        // Simulate last refill was in a previous month
        let lastMonth = calendar.date(byAdding: .month, value: -1, to: Date())!

        var data = ShieldData(
            availableShields: 0,
            lastRefillDate: lastMonth,
            shieldsUsedThisMonth: 2,
            purchasedShields: 0
        )

        data.refillIfNeeded(isPro: false)
        #expect(data.availableShields == 2) // Free: 2 shields (freeMonthlyAllocation = 2)
        #expect(data.shieldsUsedThisMonth == 0) // Reset

        persistence.clearAllData()
    }

    // MARK: - Pro Upgrade Changes Shield Allocation

    @Test func proUpgrade_changesAllocationOnNextRefill() {
        let calendar = Calendar.current
        let lastMonth = calendar.date(byAdding: .month, value: -1, to: Date())!

        var data = ShieldData(
            availableShields: 0,
            lastRefillDate: lastMonth,
            shieldsUsedThisMonth: 1,
            purchasedShields: 0
        )

        // Pro refill gives 4 (proMonthlyAllocation = 4)
        data.refillIfNeeded(isPro: true)
        #expect(data.availableShields == 4)
        #expect(data.shieldsUsedThisMonth == 0)

        persistence.clearAllData()
    }
}
} // extension SharedStateTests
