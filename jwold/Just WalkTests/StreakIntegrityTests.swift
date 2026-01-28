//
//  StreakIntegrityTests.swift
//  Just WalkTests
//
//  Tests for Streak Integrity architecture edge cases.
//  These tests verify the 3 "nightmare scenarios" that could break streaks:
//  1. Time Traveler - Retroactive HealthKit data on fresh install
//  2. Ghost User - App reinstall with continuous walking
//  3. Rich & Unlucky - Payment crash recovery
//

import XCTest
import SwiftData
@testable import Just_Walk

@MainActor
final class StreakIntegrityTests: XCTestCase {

    // MARK: - Test Infrastructure

    var testContainer: ModelContainer!
    var testContext: ModelContext!

    override func setUp() async throws {
        // Create in-memory SwiftData container for isolation
        let schema = Schema([DailyStats.self, StreakData.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        testContainer = try ModelContainer(for: schema, configurations: [config])
        testContext = testContainer.mainContext

        // Inject test context into services
        StreakService.shared.setModelContext(testContext)
        StreakResurrectionManager.shared.setModelContext(testContext)

        // Clear any previous test state
        clearAllTestData()
    }

    override func tearDown() async throws {
        #if DEBUG
        HealthKitService.shared.clearSimulatedData()
        #endif
        clearAllTestData()
        testContext = nil
        testContainer = nil
    }

    private func clearAllTestData() {
        do {
            let streakDescriptor = FetchDescriptor<StreakData>()
            let streaks = try testContext.fetch(streakDescriptor)
            for streak in streaks { testContext.delete(streak) }

            let statsDescriptor = FetchDescriptor<DailyStats>()
            let stats = try testContext.fetch(statsDescriptor)
            for stat in stats { testContext.delete(stat) }

            try testContext.save()
        } catch {
            print("Test cleanup failed: \(error)")
        }
    }

    // MARK: - Helper Methods

    private func createDayStepData(daysAgo: Int, steps: Int) -> DayStepData {
        let date = Calendar.current.date(byAdding: .day, value: -daysAgo, to: Date())!
        return DayStepData(date: Calendar.current.startOfDay(for: date), steps: steps, distance: nil)
    }

    @discardableResult
    private func createStreakData(
        currentStreak: Int,
        lastGoalMetDaysAgo: Int?,
        shieldedDates: [Date] = []
    ) -> StreakData {
        let streak = StreakData()
        streak.currentStreak = currentStreak
        if let daysAgo = lastGoalMetDaysAgo {
            streak.lastGoalMetDate = Calendar.current.date(byAdding: .day, value: -daysAgo, to: Calendar.current.startOfDay(for: Date()))
        }
        streak.shieldedDates = shieldedDates
        streak.longestStreak = currentStreak
        testContext.insert(streak)
        return streak
    }

    private func fetchCurrentStreak() -> Int {
        do {
            let descriptor = FetchDescriptor<StreakData>()
            let results = try testContext.fetch(descriptor)
            return results.first?.currentStreak ?? 0
        } catch {
            return 0
        }
    }

    private func fetchStreakData() -> StreakData? {
        do {
            let descriptor = FetchDescriptor<StreakData>()
            let results = try testContext.fetch(descriptor)
            return results.first
        } catch {
            return nil
        }
    }
}

// MARK: - Nightmare 1: The 'Time Traveler' (Retroactive Handshake)

extension StreakIntegrityTests {

    /// User installs app today. HealthKit has 90 days of historical data.
    /// After resurrection, streak should reflect pre-install history.
    func testTimeTraveler_RetroactiveHandshake() async throws {
        // ARRANGE: Simulate HealthKit has 90 days of consecutive goal-met data
        // User "installed" today but walked every day for 3 months prior
        let stepGoal = 10_000
        UserDefaults.standard.set(stepGoal, forKey: "dailyStepGoal")

        var historicalData: [DayStepData] = []
        for daysAgo in 0..<90 {
            // Each day has 12,000 steps (above goal)
            historicalData.append(createDayStepData(daysAgo: daysAgo, steps: 12_000))
        }

        #if DEBUG
        HealthKitService.shared.simulateDailyStepData(historicalData)
        #endif

        // Set app install date to today (simulating fresh install)
        UserDefaults.standard.set(Date(), forKey: "com.justwalk.appInstallDate")

        // Create empty StreakData (fresh install state)
        createStreakData(currentStreak: 0, lastGoalMetDaysAgo: nil)
        try testContext.save()

        // ACT: Run resurrection
        await StreakResurrectionManager.shared.forceReconciliation()

        // ASSERT: Streak should be > 0 (correctly read pre-install history)
        let finalStreak = fetchCurrentStreak()

        XCTAssertGreaterThan(finalStreak, 0, "Streak should be > 0 after resurrection with historical data")
        XCTAssertEqual(finalStreak, 90, "Streak should equal the full 90 days of historical data")

        // Verify DailyStats were created
        let statsDescriptor = FetchDescriptor<DailyStats>()
        let allStats = try testContext.fetch(statsDescriptor)
        XCTAssertEqual(allStats.count, 90, "Should have created 90 DailyStats records")
    }
}

// MARK: - Nightmare 2: The 'Ghost' User (Inactivity)

extension StreakIntegrityTests {

    /// User has 50-day streak, deletes app, reinstalls 5 days later (walked every day).
    /// After resurrection, streak should be 55 days.
    func testGhostUser_AppReinstallWithContinuedWalking() async throws {
        // ARRANGE: Simulate HealthKit has 55 days of consecutive data
        // Days 0-4: walked during "uninstall" period
        // Days 5-54: original 50-day streak before uninstall
        let stepGoal = 10_000
        UserDefaults.standard.set(stepGoal, forKey: "dailyStepGoal")

        var historicalData: [DayStepData] = []
        for daysAgo in 0..<55 {
            // Each day has 12,000 steps (above goal)
            historicalData.append(createDayStepData(daysAgo: daysAgo, steps: 12_000))
        }

        #if DEBUG
        HealthKitService.shared.simulateDailyStepData(historicalData)
        #endif

        // Set app install date to today (simulating reinstall)
        UserDefaults.standard.set(Date(), forKey: "com.justwalk.appInstallDate")

        // Create StreakData as if user had a 50-day streak before uninstall
        // But since they "reinstalled", local data is gone - start fresh
        createStreakData(currentStreak: 0, lastGoalMetDaysAgo: nil)
        try testContext.save()

        // ACT: Run resurrection (fills in the gap from HealthKit)
        await StreakResurrectionManager.shared.forceReconciliation()

        // ASSERT: Streak should be 55 days (original 50 + 5 gap days)
        let finalStreak = fetchCurrentStreak()

        XCTAssertEqual(finalStreak, 55, "Streak should be 55 days (filled in the 5-day uninstall gap)")

        // Verify all 55 days are marked as goal reached
        let statsDescriptor = FetchDescriptor<DailyStats>(
            predicate: #Predicate<DailyStats> { $0.goalReached == true }
        )
        let goalMetStats = try testContext.fetch(statsDescriptor)
        XCTAssertEqual(goalMetStats.count, 55, "All 55 days should be marked as goal reached")
    }
}

// MARK: - Nightmare 3: The 'Rich & Unlucky' User (Payment Glitch)

extension StreakIntegrityTests {

    /// Streak is broken. User pays for repair. App crashes before UI updates.
    /// On relaunch, Transaction.updates fires and streak is repaired automatically.
    ///
    /// Scenario: User missed YESTERDAY only. They pay to repair.
    /// After repair, yesterday is shielded, so streak continues from day 2 ago.
    func testRichAndUnlucky_PaymentGlitchRecovery() async throws {
        // ARRANGE: Create a broken streak scenario (missed 1 day)
        let stepGoal = 10_000
        UserDefaults.standard.set(stepGoal, forKey: "dailyStepGoal")

        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        // User had a 10-day streak, last goal met 2 days ago (streak broke yesterday)
        // daysSinceGoal = 2, which triggers break (> 1)
        let streakData = createStreakData(currentStreak: 0, lastGoalMetDaysAgo: 2)
        streakData.longestStreak = 10

        // Create DailyStats for the streak period (days 2-11 ago had goals met)
        for daysAgo in 2..<12 {
            let date = calendar.date(byAdding: .day, value: -daysAgo, to: today)!
            let stats = DailyStats(date: date, totalSteps: 12_000, goalReached: true)
            testContext.insert(stats)
        }

        // Day 0 (today): User hasn't walked yet - that's OK, still have time
        // Day 1 (yesterday): MISSED - this is the break date that needs repair

        try testContext.save()

        // Verify initial state: streak is broken (currentStreak = 0)
        XCTAssertEqual(streakData.currentStreak, 0, "Pre-condition: Streak should be broken")

        // ACT: Simulate what happens when Transaction.updates fires on relaunch
        // This is the core of attemptStreakRepair() - we call it directly
        let repairedDate = StreakService.shared.attemptStreakRepair(context: testContext)

        // ASSERT: Repair should succeed
        XCTAssertNotNil(repairedDate, "Repair should succeed and return the repaired date")

        // The break date should be yesterday (day after lastGoalMetDate which was 2 days ago)
        let expectedBreakDate = calendar.date(byAdding: .day, value: -1, to: today)!
        XCTAssertEqual(
            calendar.startOfDay(for: repairedDate!),
            expectedBreakDate,
            "Break date should be yesterday"
        )

        // Verify streak was recalculated
        // Since yesterday is now shielded, streak should count from day 2 ago onward
        let finalStreak = fetchCurrentStreak()
        XCTAssertGreaterThan(finalStreak, 0, "Streak should be restored after repair")

        // Verify the break date is now shielded
        let updatedStreakData = fetchStreakData()!

        XCTAssertTrue(
            updatedStreakData.isDateShielded(expectedBreakDate),
            "Break date should be in shieldedDates after repair"
        )

        // BONUS: Verify that second repair returns nil (streak is no longer broken)
        // After repair, lastGoalMetDate is updated so daysSinceGoal = 1, which is not > 1
        let secondRepairResult = StreakService.shared.attemptStreakRepair(context: testContext)
        XCTAssertNil(secondRepairResult, "Second repair should return nil (streak no longer broken)")
    }

    /// Verify that repair fails gracefully when streak is not actually broken
    func testRichAndUnlucky_RepairFailsWhenStreakNotBroken() async throws {
        // ARRANGE: Create an active streak (goal met today)
        let stepGoal = 10_000
        UserDefaults.standard.set(stepGoal, forKey: "dailyStepGoal")

        // User has active 10-day streak, last goal met today
        createStreakData(currentStreak: 10, lastGoalMetDaysAgo: 0)
        try testContext.save()

        // ACT: Try to repair (should fail - streak isn't broken)
        let repairedDate = StreakService.shared.attemptStreakRepair(context: testContext)

        // ASSERT: Repair should fail (returns nil)
        XCTAssertNil(repairedDate, "Repair should fail when streak is not broken")
    }
}
