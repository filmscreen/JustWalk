//
//  DynamicCardPriorityManager.swift
//  Just Walk
//
//  Priority-based manager for dynamic cards on the Today screen.
//  Evaluates conditions and returns the highest-priority card to show.
//

import SwiftUI
import Combine
import WatchConnectivity

@MainActor
final class DynamicCardPriorityManager: ObservableObject {
    static let shared = DynamicCardPriorityManager()

    // MARK: - Published State

    @Published private(set) var currentCard: DynamicCardType?

    // MARK: - Dependencies

    private let dismissalStore = DynamicCardDismissalStore.shared
    private let streakService = StreakService.shared

    // MARK: - App State (injected when evaluating)

    private var todaySteps: Int = 0
    private var stepGoal: Int = 10_000
    private var goalReached: Bool = false
    private var consecutiveGoalDays: Int = 0
    private var weeklySnapshot: WeeklySummaryData?
    private var lastActiveDate: Date?
    private var appLaunchCount: Int = 0

    private init() {}

    // MARK: - Evaluate Cards

    func evaluate(
        todaySteps: Int,
        stepGoal: Int,
        goalReached: Bool,
        consecutiveGoalDays: Int,
        weeklySnapshot: WeeklySummaryData?,
        lastActiveDate: Date?,
        appLaunchCount: Int
    ) {
        self.todaySteps = todaySteps
        self.stepGoal = stepGoal
        self.goalReached = goalReached
        self.consecutiveGoalDays = consecutiveGoalDays
        self.weeklySnapshot = weeklySnapshot
        self.lastActiveDate = lastActiveDate
        self.appLaunchCount = appLaunchCount

        currentCard = getCardToShow()
    }

    // MARK: - Priority Logic

    private func getCardToShow() -> DynamicCardType? {
        // ============================================
        // TIER 1: URGENT
        // ============================================

        if let card = checkStreakAtRisk() {
            return card
        }

        // ============================================
        // TIER 2: CELEBRATION
        // ============================================

        if let card = checkDailyMilestone() {
            return card
        }

        if let card = checkStreakMilestone() {
            return card
        }

        // ============================================
        // TIER 3: CONVERSION
        // ============================================

        if let card = checkProTrial() {
            return card
        }

        // ============================================
        // TIER 4: CONTEXTUAL
        // ============================================

        if let card = checkWeeklySummary() {
            return card
        }

        if let card = checkGoalAdjustment() {
            return card
        }

        if let card = checkComebackPrompt() {
            return card
        }

        // Weather suggestion (future - requires API)
        // if let card = checkWeatherSuggestion() {
        //     return card
        // }

        // ============================================
        // TIER 5: DISCOVERY
        // ============================================

        if let card = checkWatchAppSetup() {
            return card
        }

        return nil
    }

    // MARK: - Dismiss Current Card

    func dismissCurrentCard() {
        guard let card = currentCard else { return }
        dismissalStore.dismiss(card)
        currentCard = getCardToShow() // Re-evaluate for next card
    }

    // MARK: - Mark Milestone Seen (without dismissing)

    func markMilestoneSeen(_ milestone: DailyMilestone) {
        dismissalStore.markMilestoneSeen(milestone.rawValue)
    }

    func markStreakMilestoneSeen(_ days: Int) {
        dismissalStore.markStreakMilestoneSeen(days)
    }
}

// MARK: - Condition Checks

extension DynamicCardPriorityManager {

    // TIER 1: Streak at Risk
    private func checkStreakAtRisk() -> DynamicCardType? {
        let streak = streakService.currentStreak
        guard streak > 0 else { return nil }
        guard !goalReached else { return nil }

        let hoursUntilMidnight = calculateHoursUntilMidnight()
        guard hoursUntilMidnight < 4 else { return nil }

        let card = DynamicCardType.streakAtRisk(
            streak: streak,
            stepsRemaining: max(0, stepGoal - todaySteps),
            hoursLeft: hoursUntilMidnight
        )

        guard !dismissalStore.isDismissed(card) else { return nil }
        return card
    }

    // TIER 2: Daily Milestone
    private func checkDailyMilestone() -> DynamicCardType? {
        for milestone in DailyMilestone.allCases {
            if todaySteps >= milestone.stepThreshold {
                if !dismissalStore.hasSeenMilestone(milestone.rawValue) {
                    let card = DynamicCardType.dailyMilestone(milestone: milestone)
                    if !dismissalStore.isDismissed(card) {
                        return card
                    }
                }
            }
        }
        return nil
    }

    // TIER 2: Streak Milestone
    private func checkStreakMilestone() -> DynamicCardType? {
        let streak = streakService.currentStreak
        guard streakMilestones.contains(streak) else { return nil }
        guard !dismissalStore.hasSeenStreakMilestone(streak) else { return nil }

        let card = DynamicCardType.streakMilestone(days: streak)
        guard !dismissalStore.isDismissed(card) else { return nil }
        return card
    }

    // TIER 3: Pro Trial
    private func checkProTrial() -> DynamicCardType? {
        guard !FreeTierManager.shared.isPro else { return nil }
        guard appLaunchCount >= 3 else { return nil }

        let card = DynamicCardType.proTrial
        guard !dismissalStore.isDismissed(card) else { return nil }
        return card
    }

    // TIER 4: Weekly Summary
    private func checkWeeklySummary() -> DynamicCardType? {
        guard let snapshot = weeklySnapshot else { return nil }

        let dayOfWeek = Calendar.current.component(.weekday, from: Date())
        // Sunday = 1, Monday = 2
        guard dayOfWeek == 1 || dayOfWeek == 2 else { return nil }

        let card = DynamicCardType.weeklySummary(snapshot: snapshot)
        guard !dismissalStore.isDismissed(card) else { return nil }
        return card
    }

    // TIER 4: Goal Adjustment
    private func checkGoalAdjustment() -> DynamicCardType? {
        guard consecutiveGoalDays >= 5 else { return nil }

        let suggestedGoal = calculateSuggestedGoal()
        let card = DynamicCardType.goalAdjustment(
            currentGoal: stepGoal,
            suggestedGoal: suggestedGoal,
            consecutiveDays: consecutiveGoalDays
        )

        guard !dismissalStore.isDismissed(card) else { return nil }
        return card
    }

    // TIER 4: Comeback Prompt
    private func checkComebackPrompt() -> DynamicCardType? {
        guard let lastActive = lastActiveDate else { return nil }

        let daysSince = Calendar.current.dateComponents(
            [.day],
            from: lastActive,
            to: Date()
        ).day ?? 0

        guard daysSince >= 3 else { return nil }

        let card = DynamicCardType.comebackPrompt(daysSinceLastWalk: daysSince)
        guard !dismissalStore.isDismissed(card) else { return nil }
        return card
    }

    // TIER 5: Watch App Setup
    private func checkWatchAppSetup() -> DynamicCardType? {
        // Check if user has Apple Watch paired
        guard hasAppleWatch() else { return nil }
        guard !hasSetUpWatchApp() else { return nil }

        let card = DynamicCardType.watchAppSetup
        guard !dismissalStore.isDismissed(card) else { return nil }
        return card
    }

    // MARK: - Helpers

    private func calculateHoursUntilMidnight() -> Int {
        let now = Date()
        let calendar = Calendar.current
        let tomorrow = calendar.startOfDay(for: calendar.date(byAdding: .day, value: 1, to: now)!)
        let seconds = tomorrow.timeIntervalSince(now)
        return Int(seconds / 3600)
    }

    private func calculateSuggestedGoal() -> Int {
        // Suggest 2,000 more steps, rounded to nearest 1,000
        let suggested = stepGoal + 2000
        return (suggested / 1000) * 1000
    }

    private func hasAppleWatch() -> Bool {
        // Check if WCSession is supported and paired
        if WCSession.isSupported() {
            return WCSession.default.isPaired
        }
        return false
    }

    private func hasSetUpWatchApp() -> Bool {
        // Check if Watch app has been launched via WCSession
        if WCSession.isSupported() && WCSession.default.isPaired {
            return WCSession.default.isWatchAppInstalled
        }
        return UserDefaults.standard.bool(forKey: "hasSetUpWatchApp")
    }
}
