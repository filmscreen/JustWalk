//
//  StreakManager.swift
//  JustWalk
//
//  Streak logic with at-risk detection and shield integration hooks
//

import Foundation
import Combine

@Observable
class StreakManager: ObservableObject {
    static let shared = StreakManager()

    private let persistence = PersistenceManager.shared

    var streakData: StreakData = .empty

    /// Set when a milestone threshold is hit in recordGoalMet()
    var lastReachedMilestone: Int? = nil

    /// Set when weekly jackpot (7 consecutive goal days) is earned
    private(set) var weeklyJackpotJustEarned: Bool = false

    private init() {}

    // MARK: - Initialization

    func load() {
        streakData = persistence.loadStreakData()
        // Recalculate streak from daily logs to ensure accuracy
        recalculateStreak()
    }

    // MARK: - Streak Logic

    func checkAndUpdateStreak() {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        guard let lastGoalDate = streakData.lastGoalMetDate else {
            // No streak yet
            return
        }

        let lastGoalDay = calendar.startOfDay(for: lastGoalDate)
        let daysBetween = calendar.dateComponents([.day], from: lastGoalDay, to: today).day ?? 0

        if daysBetween > 1 {
            // Gap detected — ShieldManager.checkAndDeployForMissedDays()
            // handles shield deployment and streak breaking on app open.
            // See JustWalkApp.swift scenePhase(.active) handler.
        }
    }

    func recordGoalMet(forDate date: Date = Date()) {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: date)

        if let lastDate = streakData.lastGoalMetDate {
            let lastDay = calendar.startOfDay(for: lastDate)
            let daysBetween = calendar.dateComponents([.day], from: lastDay, to: today).day ?? 0

            if daysBetween == 1 {
                // Consecutive day
                streakData.currentStreak += 1
                streakData.consecutiveGoalDays += 1
            } else if daysBetween == 0 {
                // Same day, already recorded
                return
            } else {
                // Gap (shouldn't happen if shields work correctly)
                streakData.currentStreak = 1
                streakData.consecutiveGoalDays = 1
                streakData.streakStartDate = today
            }
        } else {
            // First goal ever
            streakData.currentStreak = 1
            streakData.consecutiveGoalDays = 1
            streakData.streakStartDate = today
        }

        streakData.lastGoalMetDate = today
        streakData.longestStreak = max(streakData.longestStreak, streakData.currentStreak)

        // Check for streak milestone
        let milestoneThresholds = [7, 14, 30, 60, 90, 100, 180, 365]
        if milestoneThresholds.contains(streakData.currentStreak) {
            lastReachedMilestone = streakData.currentStreak
            JustWalkHaptics.streakMilestone()
            MilestoneManager.shared.trigger("streak_\(streakData.currentStreak)")
        }

        // Check for streak restart (broke streak, now back to 3+)
        if streakData.currentStreak == 3, streakData.longestStreak > streakData.currentStreak {
            MilestoneManager.shared.trigger("streak_restart_3")
        }

        // Check for weekly jackpot (7 consecutive goal days)
        if streakData.consecutiveGoalDays > 0 && streakData.consecutiveGoalDays % 7 == 0 {
            weeklyJackpotJustEarned = true
        }

        persistence.saveStreakData(streakData)
    }

    func recordShieldUsed(forDate date: Date) {
        // Shield protects streak but doesn't increment streakData.consecutiveGoalDays
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: date)

        // Streak count stays same, just update the last date
        streakData.lastGoalMetDate = today
        streakData.consecutiveGoalDays = 0 // Reset weekly jackpot progress

        persistence.saveStreakData(streakData)
    }

    /// Recalculates the streak from daily logs (useful after retroactive shield repairs)
    func recalculateStreak() {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        var currentDate = today
        var streakCount = 0
        var streakStart: Date? = nil
        var lastGoalDate: Date? = nil

        // Check if today has goal met
        let todayLog = persistence.loadDailyLog(for: today)
        let todayGoalMet = todayLog?.goalMet ?? false

        // If today's goal isn't met yet, start counting from yesterday
        if !todayGoalMet {
            guard let yesterday = calendar.date(byAdding: .day, value: -1, to: today) else {
                persistence.saveStreakData(streakData)
                return
            }
            currentDate = yesterday
        }

        // Walk backwards counting consecutive goal-met days
        while true {
            if let log = persistence.loadDailyLog(for: currentDate), log.goalMet {
                streakCount += 1
                streakStart = currentDate
                if lastGoalDate == nil {
                    lastGoalDate = currentDate
                }
            } else {
                // Gap found - streak ends here
                break
            }

            // Move to previous day
            guard let previousDay = calendar.date(byAdding: .day, value: -1, to: currentDate) else {
                break
            }
            currentDate = previousDay
        }

        // Update streak data
        streakData.currentStreak = streakCount
        streakData.streakStartDate = streakStart
        streakData.lastGoalMetDate = lastGoalDate
        streakData.longestStreak = max(streakData.longestStreak, streakCount)

        persistence.saveStreakData(streakData)
    }

    @discardableResult
    func breakStreak() -> LegacyBadge? {
        JustWalkHaptics.streakBroken()
        var earnedBadge: LegacyBadge?

        // Check for Legacy Badge
        if streakData.currentStreak >= 30 {
            earnedBadge = LegacyBadge.badge(for: streakData.currentStreak)

            // Save legacy badge to user profile
            if let badge = earnedBadge {
                var profile = persistence.loadProfile()
                // Only add if not already earned at this tier
                if !profile.legacyBadges.contains(where: { $0.streakLength == badge.streakLength }) {
                    profile.legacyBadges.append(badge)
                    persistence.saveProfile(profile)
                }
            }
        }

        // Reset streak
        streakData.currentStreak = 0
        streakData.streakStartDate = nil
        streakData.lastGoalMetDate = nil
        streakData.consecutiveGoalDays = 0

        persistence.saveStreakData(streakData)

        return earnedBadge
    }

    func repairStreak(toLength: Int, startDate: Date) {
        // Used for retroactive shield repair
        streakData.currentStreak = toLength
        streakData.streakStartDate = startDate
        streakData.lastGoalMetDate = Calendar.current.startOfDay(for: Date())
        streakData.longestStreak = max(streakData.longestStreak, toLength)

        persistence.saveStreakData(streakData)
    }

    // MARK: - Queries

    var isAtRisk: Bool {
        let calendar = Calendar.current
        let now = Date()
        let hour = calendar.component(.hour, from: now)

        // At risk if: after 6pm AND goal not met today AND have an active streak
        guard hour >= 18, streakData.currentStreak > 0 else { return false }

        if let lastDate = streakData.lastGoalMetDate {
            return !calendar.isDateInToday(lastDate)
        }
        return true
    }

    var weeklyJackpotProgress: Int {
        return streakData.consecutiveGoalDays % 7
    }

    var weeklyJackpotEarned: Bool {
        return streakData.consecutiveGoalDays > 0 && streakData.consecutiveGoalDays % 7 == 0
    }

    // MARK: - Utility

    var daysUntilNextMilestone: Int? {
        let milestones = LegacyBadge.thresholds
        guard let nextMilestone = milestones.first(where: { $0 > streakData.currentStreak }) else {
            return nil
        }
        return nextMilestone - streakData.currentStreak
    }

    var nextMilestone: Int? {
        return LegacyBadge.thresholds.first(where: { $0 > streakData.currentStreak })
    }

    func streakStatusMessage() -> String {
        if streakData.currentStreak == 0 {
            return "Start your streak today!"
        } else if isAtRisk {
            return "Your \(streakData.currentStreak)-day streak is at risk!"
        } else if let days = daysUntilNextMilestone {
            return "\(days) days until your next milestone"
        } else {
            return "You're a walking legend!"
        }
    }

    // MARK: - Event Flag Clearing

    func clearLastReachedMilestone() {
        lastReachedMilestone = nil
    }

    func clearWeeklyJackpotFlag() {
        weeklyJackpotJustEarned = false
    }
}
