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
    static let shared = StepDataManager()
    // MARK: - Published State

    var todayLog: DailyLog?
    var weekHistory: [DailyLog] = []
    var isLoading: Bool = false

    // MARK: - Dependencies

    private let persistence = PersistenceManager.shared

    private var hasPlayedApproachingHaptic = false

    private init() {}

    // MARK: - Today's Log

    func fetchToday() {
        isLoading = true
        defer { isLoading = false }

        let today = Calendar.current.startOfDay(for: Date())

        hasPlayedApproachingHaptic = false

        if let existing = persistence.loadDailyLog(for: today) {
            todayLog = existing
        } else {
            let goal = persistence.loadProfile().dailyStepGoal
            let newLog = DailyLog(
                id: UUID(),
                date: today,
                steps: 0,
                goalMet: false,
                shieldUsed: false,
                trackedWalkIDs: [],
                goalTarget: goal
            )
            persistence.saveDailyLog(newLog)
            todayLog = newLog
        }
    }

    /// Refreshes the cached todayLog from persistence.
    /// Call this after external changes to today's log (e.g., shield applied).
    func refreshTodayCache() {
        let today = Calendar.current.startOfDay(for: Date())
        if let existing = persistence.loadDailyLog(for: today) {
            todayLog = existing
        }
    }

    func updateTodaySteps(_ steps: Int, goalTarget: Int) {
        if todayLog == nil {
            fetchToday()
        }
        guard var today = todayLog else { return }
        let calendar = Calendar.current
        if !calendar.isDateInToday(today.date) {
            fetchToday()
            guard let refreshed = todayLog else { return }
            today = refreshed
        }

        let wasGoalMet = today.goalMet
        let previousSteps = today.steps
        let previousGoalTarget = today.goalTarget

        today.steps = steps
        today.goalTarget = goalTarget
        today.goalMet = steps >= goalTarget

        // Avoid unnecessary writes that can trigger UI loops.
        let didChange = previousSteps != today.steps ||
            previousGoalTarget != today.goalTarget ||
            wasGoalMet != today.goalMet

        guard didChange else { return }

        // CRITICAL: Preserve shieldUsed flag from persistence
        // The cached todayLog may be stale if a shield was applied elsewhere
        if let persistedLog = persistence.loadDailyLog(for: today.date) {
            today.shieldUsed = persistedLog.shieldUsed
        }

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
        } else if wasGoalMet && !today.goalMet {
            // Handle goal corrections (e.g., HK corrections or goal changes).
            StreakManager.shared.recalculateStreak()
        }

        WalkNotificationManager.shared.scheduleNotificationIfNeeded()
    }

    /// Called when the daily step goal is met for the first time today.
    /// Wires streak updates and celebration cards.
    private func onDailyGoalMet(dailyGoal: Int, currentSteps: Int) {
        JustWalkHaptics.goalComplete()

        let streakManager = StreakManager.shared

        // Record goal met → increments streak
        streakManager.recordGoalMet()

        triggerClutchAndComebackIfNeeded()

        // Send goal achieved notification
        NotificationManager.shared.sendGoalAchievedNotification(streak: streakManager.streakData.currentStreak)

        // Check step milestones
        checkStepMilestones(currentSteps: currentSteps)

        // Refresh dynamic card engine to show celebration cards immediately
        DynamicCardEngine.shared.refresh(dailyGoal: dailyGoal, currentSteps: currentSteps)
    }

    private func triggerClutchAndComebackIfNeeded() {
        let defaults = UserDefaults.standard
        let calendar = Calendar.current
        let now = Date()

        // Clutch save / under the wire (once per day)
        let lastClutchKey = "lastClutchMomentDate"
        if let last = defaults.object(forKey: lastClutchKey) as? Date,
           calendar.isDateInToday(last) == false {
            defaults.removeObject(forKey: lastClutchKey)
        }
        let hour = calendar.component(.hour, from: now)
        let minute = calendar.component(.minute, from: now)
        if defaults.object(forKey: lastClutchKey) == nil {
            if hour == 23 && minute >= 30 {
                EmotionalMomentTrigger.shared.post(.underTheWire)
                defaults.set(now, forKey: lastClutchKey)
            } else if hour >= 23 || (hour == 22 && minute >= 30) {
                EmotionalMomentTrigger.shared.post(.clutchSave)
                defaults.set(now, forKey: lastClutchKey)
            }
        }

        // Comeback (3+ days inactive)
        let lastGoalKey = "lastGoalMetDate"
        let lastComebackKey = "lastComebackMomentDate"
        if let last = defaults.object(forKey: lastComebackKey) as? Date,
           calendar.isDateInToday(last) == false {
            defaults.removeObject(forKey: lastComebackKey)
        }

        if let lastActive = defaults.object(forKey: lastGoalKey) as? Date {
            let daysSinceActive = calendar.dateComponents([.day], from: lastActive, to: now).day ?? 0
            if daysSinceActive >= 3, defaults.object(forKey: lastComebackKey) == nil {
                let longest = StreakManager.shared.streakData.longestStreak
                if longest > 14 {
                    EmotionalMomentTrigger.shared.post(.comebackWithRecord(days: longest))
                } else {
                    EmotionalMomentTrigger.shared.post(.comeback)
                }
                defaults.set(now, forKey: lastComebackKey)
            }
        }

        // Update last active date
        defaults.set(now, forKey: lastGoalKey)
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
