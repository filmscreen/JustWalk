//
//  StepDataManager.swift
//  JustWalk
//
//  Manages step data using the new persistence layer
//

import Foundation

@Observable
@MainActor
final class StepDataManager {
    // MARK: - Published State

    var todayLog: DailyLog?
    var weekHistory: [DailyLog] = []
    var isLoading: Bool = false

    // MARK: - Dependencies

    private let persistence = PersistenceManager.shared

    private var hasPlayedApproachingHaptic = false

    init() {}

    // MARK: - Today's Log

    func fetchToday() {
        isLoading = true
        defer { isLoading = false }

        let today = Calendar.current.startOfDay(for: Date())

        hasPlayedApproachingHaptic = false

        if let existing = persistence.loadDailyLog(for: today) {
            todayLog = existing
        } else {
            let newLog = DailyLog(
                id: UUID(),
                date: today,
                steps: 0,
                goalMet: false,
                shieldUsed: false,
                trackedWalkIDs: []
            )
            persistence.saveDailyLog(newLog)
            todayLog = newLog
        }
    }

    func updateTodaySteps(_ steps: Int, goalTarget: Int) {
        guard var today = todayLog else {
            fetchToday()
            return
        }

        let wasGoalMet = today.goalMet
        today.steps = steps
        today.goalMet = steps >= goalTarget

        persistence.saveDailyLog(today)
        todayLog = today

        // Goal approaching haptic (90% threshold)
        if steps >= Int(Double(goalTarget) * 0.9) && steps < goalTarget && !hasPlayedApproachingHaptic {
            hasPlayedApproachingHaptic = true
            JustWalkHaptics.progressMilestone()
        }

        // First time goal met today — trigger gamification rewards
        if today.goalMet && !wasGoalMet {
            onDailyGoalMet(dailyGoal: goalTarget, currentSteps: steps)
        }
    }

    /// Called when the daily step goal is met for the first time today.
    /// Wires streak updates and celebration cards.
    private func onDailyGoalMet(dailyGoal: Int, currentSteps: Int) {
        JustWalkHaptics.goalComplete()

        let streakManager = StreakManager.shared

        // Record goal met → increments streak
        streakManager.recordGoalMet()

        // Send goal achieved notification
        NotificationManager.shared.sendGoalAchievedNotification(streak: streakManager.streakData.currentStreak)

        // Check step milestones
        checkStepMilestones(currentSteps: currentSteps)

        // Refresh dynamic card engine to show celebration cards immediately
        DynamicCardEngine.shared.refresh(dailyGoal: dailyGoal, currentSteps: currentSteps)
    }

    // MARK: - Step Milestones

    private func checkStepMilestones(currentSteps: Int) {
        let milestoneManager = MilestoneManager.shared

        // First 10,000-step day
        if currentSteps >= 10_000 {
            milestoneManager.trigger("steps_first_10k")
        }

        // Personal best steps — compare against all historical daily logs
        let allLogs = persistence.loadAllDailyLogs()
        let previousBest = allLogs
            .filter { todayLog == nil || $0.id != todayLog!.id }
            .map(\.steps)
            .max() ?? 0

        if currentSteps > previousBest && previousBest > 0 {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            let dateString = formatter.string(from: Date())
            milestoneManager.trigger("steps_personal_best_\(dateString)")
        }
    }

    // MARK: - History

    func fetchHistory(days: Int = 7) {
        isLoading = true
        defer { isLoading = false }

        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        weekHistory = persistence.loadAllDailyLogs()
            .filter { log in
                guard let daysAgo = calendar.dateComponents([.day], from: log.date, to: today).day else {
                    return false
                }
                return daysAgo >= 0 && daysAgo < days
            }
            .sorted { $0.date > $1.date }
    }

}
