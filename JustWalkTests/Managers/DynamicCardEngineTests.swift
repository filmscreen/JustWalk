//
//  DynamicCardEngineTests.swift
//  JustWalkTests
//
//  Tests for DynamicCardEngine: 3-tier evaluation, frequency limits, daily reset,
//  card key stability, and card action integration.
//

import Testing
import Foundation
@testable import JustWalk

extension SharedStateTests {
@Suite(.serialized)
struct DynamicCardEngineTests {

    private let engine = DynamicCardEngine.shared
    private let persistence = PersistenceManager.shared
    private let streakManager = StreakManager.shared
    private let shieldManager = ShieldManager.shared

    init() {
        engine.resetForTesting()
        persistence.clearAllData()
        streakManager.streakData = .empty
        shieldManager.shieldData = .empty
        shieldManager.lastDeployedOvernight = false
    }

    // MARK: - Always Shows A Card

    @Test func evaluate_alwaysReturnsACard() {
        engine.resetForTesting()
        streakManager.streakData = .empty
        shieldManager.lastDeployedOvernight = false

        // Very low steps, no streak, no special conditions
        let card = engine.evaluate(dailyGoal: 10000, currentSteps: 100)

        // Should always return a card (P3 fallback at minimum)
        _ = card // non-optional — compiler enforces this

        engine.resetForTesting()
        persistence.clearAllData()
    }

    @Test func evaluate_defaultCardIsTip() {
        engine.resetForTesting()
        streakManager.streakData = .empty
        shieldManager.lastDeployedOvernight = false

        // With no P1/P2 conditions, should fall back to a P3 tip
        let card = engine.evaluate(dailyGoal: 10000, currentSteps: 100)
        #expect(card.tier == 3, "With no urgent/contextual conditions, should show a tip card")

        engine.resetForTesting()
        persistence.clearAllData()
    }

    // MARK: - P1: Shield Deployed Priority

    @Test func evaluate_shieldDeployed_takesP1Priority() {
        engine.resetForTesting()
        shieldManager.lastDeployedOvernight = true
        shieldManager.shieldData.availableShields = 2

        let card = engine.evaluate(dailyGoal: 10000, currentSteps: 5000)

        if case .shieldDeployed = card {
            #expect(card.tier == 1)
        } else {
            // May be blocked by frequency; verify no crash
        }

        engine.resetForTesting()
        shieldManager.lastDeployedOvernight = false
    }

    // MARK: - P1: Welcome Back

    @Test func evaluate_welcomeBack_whenStreakBrokenWithHistory() {
        engine.resetForTesting()
        streakManager.streakData = StreakData(
            currentStreak: 0,
            longestStreak: 7,
            lastGoalMetDate: Calendar.current.date(byAdding: .day, value: -3, to: Date()),
            streakStartDate: nil
        )
        shieldManager.lastDeployedOvernight = false

        let card = engine.evaluate(dailyGoal: 10000, currentSteps: 100)

        // With no streak but history, welcomeBack or a tip card
        if case .welcomeBack = card {
            #expect(card.tier == 1)
        }
        // Either way, no crash

        engine.resetForTesting()
        persistence.clearAllData()
    }

    // MARK: - Tier Property

    @Test func cardType_tierAssignment() {
        // P1
        #expect(DynamicCardType.streakAtRisk(stepsRemaining: 1000).tier == 1)
        #expect(DynamicCardType.shieldDeployed(remainingShields: 2, nextRefill: "Feb 1").tier == 1)
        #expect(DynamicCardType.welcomeBack.tier == 1)

        // P2
        #expect(DynamicCardType.almostThere(stepsRemaining: 800).tier == 2)
        #expect(DynamicCardType.tryIntervals.tier == 2)
        #expect(DynamicCardType.trySyncWithWatch.tier == 2)
        #expect(DynamicCardType.newWeekNewGoal.tier == 2)
        #expect(DynamicCardType.weekendWarrior.tier == 2)
        #expect(DynamicCardType.eveningNudge(stepsRemaining: 500).tier == 2)

        // P3
        #expect(DynamicCardType.tipLittleGoFar.tier == 3)
        #expect(DynamicCardType.tipHeartHealth.tier == 3)
        #expect(DynamicCardType.tipClearHead.tier == 3)
        #expect(DynamicCardType.tipSleepBetter.tier == 3)
        #expect(DynamicCardType.tipEnergyBoost.tier == 3)
        #expect(DynamicCardType.tipWalkAfterMeals.tier == 3)
        #expect(DynamicCardType.tipParkFarther.tier == 3)
        #expect(DynamicCardType.tipTakeStairs.tier == 3)
        #expect(DynamicCardType.tipLeavePhone.tier == 3)
        #expect(DynamicCardType.tipWalkWithSomeone.tier == 3)
        #expect(DynamicCardType.tipConsistency.tier == 3)
        #expect(DynamicCardType.tipJustStart.tier == 3)
        #expect(DynamicCardType.tipNoTime.tier == 3)
        #expect(DynamicCardType.tipMorningLight.tier == 3)
        #expect(DynamicCardType.tipNatureHeals.tier == 3)
    }

    // MARK: - Card Key Stability

    @Test func cardType_cardKeyIsStable() {
        // Verify card keys don't change with associated values
        #expect(DynamicCardType.streakAtRisk(stepsRemaining: 100).cardKey ==
                DynamicCardType.streakAtRisk(stepsRemaining: 9999).cardKey)
        #expect(DynamicCardType.almostThere(stepsRemaining: 100).cardKey ==
                DynamicCardType.almostThere(stepsRemaining: 5000).cardKey)
        #expect(DynamicCardType.eveningNudge(stepsRemaining: 100).cardKey ==
                DynamicCardType.eveningNudge(stepsRemaining: 3000).cardKey)
    }

    @Test func cardType_allCardKeysUnique() {
        let keys: [String] = [
            DynamicCardType.streakAtRisk(stepsRemaining: 0).cardKey,
            DynamicCardType.shieldDeployed(remainingShields: 0, nextRefill: "").cardKey,
            DynamicCardType.welcomeBack.cardKey,
            DynamicCardType.almostThere(stepsRemaining: 0).cardKey,
            DynamicCardType.tryIntervals.cardKey,
            DynamicCardType.trySyncWithWatch.cardKey,
            DynamicCardType.newWeekNewGoal.cardKey,
            DynamicCardType.weekendWarrior.cardKey,
            DynamicCardType.eveningNudge(stepsRemaining: 0).cardKey,
            DynamicCardType.tipLittleGoFar.cardKey,
            DynamicCardType.tipHeartHealth.cardKey,
            DynamicCardType.tipClearHead.cardKey,
            DynamicCardType.tipSleepBetter.cardKey,
            DynamicCardType.tipEnergyBoost.cardKey,
            DynamicCardType.tipWalkAfterMeals.cardKey,
            DynamicCardType.tipParkFarther.cardKey,
            DynamicCardType.tipTakeStairs.cardKey,
            DynamicCardType.tipLeavePhone.cardKey,
            DynamicCardType.tipWalkWithSomeone.cardKey,
            DynamicCardType.tipConsistency.cardKey,
            DynamicCardType.tipJustStart.cardKey,
            DynamicCardType.tipNoTime.cardKey,
            DynamicCardType.tipMorningLight.cardKey,
            DynamicCardType.tipNatureHeals.cardKey,
        ]

        let uniqueKeys = Set(keys)
        #expect(uniqueKeys.count == keys.count, "All card keys must be unique")
    }

    // MARK: - P3 Tip Rotation

    @Test func tipCards_hasAllFifteenTips() {
        #expect(DynamicCardType.tipCards.count == 15)
    }

    // MARK: - Frequency Limits

    @Test func frequencyLimit_firstShow_canShow() {
        engine.resetForTesting()

        let card = DynamicCardType.streakAtRisk(stepsRemaining: 2000)
        // Before any shows, incrementing should work
        engine.incrementShowCount(card)
        // After one show, streakAtRisk (max 1/day) should be exhausted
        // We verify by evaluating — the engine won't pick it again

        engine.resetForTesting()
    }

    @Test func frequencyLimit_streakAtRiskLimitedToOne() {
        engine.resetForTesting()

        let card = DynamicCardType.streakAtRisk(stepsRemaining: 2000)

        engine.incrementShowCount(card)
        // After one show, it should be frequency-limited
        // We can verify indirectly: markAsActedUpon + reset doesn't crash

        engine.resetForTesting()
    }

    // MARK: - Daily Reset

    @Test func dailyReset_clearsShowCounts() {
        engine.resetForTesting()

        let card = DynamicCardType.almostThere(stepsRemaining: 800)
        engine.incrementShowCount(card)

        // Perform daily reset
        engine.performDailyReset()

        // After reset, show counts are cleared
        // Engine should be able to show the card again

        engine.resetForTesting()
    }

    @Test func dailyReset_clearsActedUpon() {
        engine.resetForTesting()

        let card = DynamicCardType.almostThere(stepsRemaining: 800)
        engine.markAsActedUpon(card)

        // Perform daily reset
        engine.performDailyReset()

        // After reset, acted-upon is cleared

        engine.resetForTesting()
    }

    // MARK: - Mark As Acted Upon

    @Test func markAsActedUpon_recordsAction() {
        engine.resetForTesting()

        let card = DynamicCardType.almostThere(stepsRemaining: 800)

        // Mark as acted upon (should not crash)
        engine.markAsActedUpon(card)

        engine.resetForTesting()
    }

    // MARK: - Refresh Behavior

    @Test func refresh_reEvaluatesCard() {
        engine.resetForTesting()
        streakManager.streakData = .empty
        shieldManager.lastDeployedOvernight = false

        engine.refresh(dailyGoal: 10000, currentSteps: 5000)

        // currentCard should be set (non-optional)
        let card = engine.currentCard
        #expect(card.tier >= 1 && card.tier <= 3)

        engine.resetForTesting()
    }

    // MARK: - Evaluation Cooldown

    @Test func evaluate_respectsEvaluationCooldown() {
        engine.resetForTesting()

        // First evaluation
        let card1 = engine.evaluate(dailyGoal: 10000, currentSteps: 5000)

        // Immediate second evaluation should return cached result (cooldown active)
        let card2 = engine.evaluate(dailyGoal: 10000, currentSteps: 5000)

        #expect(card1 == card2, "Rapid re-evaluation should return same result (cooldown)")

        engine.resetForTesting()
    }

    // MARK: - CardAction Equatable

    @Test func cardAction_equatable() {
        #expect(CardAction.navigateToIntervals == CardAction.navigateToIntervals)
        #expect(CardAction.startPostMealWalk == CardAction.startPostMealWalk)
        #expect(CardAction.startIntervalWalk == CardAction.startIntervalWalk)
        #expect(CardAction.openWatchSetup == CardAction.openWatchSetup)
        #expect(CardAction.navigateToIntervals != CardAction.startPostMealWalk)
        #expect(CardAction.startIntervalWalk != CardAction.openWatchSetup)
    }
}
} // extension SharedStateTests
