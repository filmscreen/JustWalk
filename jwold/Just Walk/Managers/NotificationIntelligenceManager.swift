//
//  NotificationIntelligenceManager.swift
//  Just Walk
//
//  Smart Notifications that act like a Coach, not an Alarm Clock.
//  Evaluates user progress before deciding to speak.
//

import Foundation
import SwiftUI
import UserNotifications

@MainActor
final class NotificationIntelligenceManager {

    // MARK: - Singleton

    static let shared = NotificationIntelligenceManager()

    private init() {}

    // MARK: - Notification Identifiers

    private let closerNotificationId = "smart.coach.closer"
    private let streakSaverNotificationId = "smart.coach.streakSaver"
    private let highFiveNotificationId = "smart.coach.highFive"

    // MARK: - Anti-Nag Tracking

    /// Date string of the last High Five sent (prevents multiple per day)
    @AppStorage("smartCoach.lastHighFiveDate") private var lastHighFiveDateString: String = ""

    /// Whether The Closer fired today (for no-double-dipping logic)
    @AppStorage("smartCoach.closerFiredToday") private var closerFiredToday: Bool = false

    /// Last date we reset daily flags
    @AppStorage("smartCoach.lastResetDate") private var lastResetDateString: String = ""


    // MARK: - Helper Methods

    /// Estimate walking time based on 100 steps per minute
    func estimateWalkingTime(steps: Int) -> Int {
        max(1, steps / 100)
    }

    /// Format step count with comma separator
    private func formatSteps(_ steps: Int) -> String {
        steps.formatted(.number)
    }

    /// Get today's date as a string for comparison
    private var todayDateString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: Date())
    }

    // MARK: - Daily Reset

    /// Reset daily tracking flags at midnight
    func resetDailyFlagsIfNeeded() {
        let today = todayDateString

        if lastResetDateString != today {
            closerFiredToday = false
            lastResetDateString = today
            print("🔄 Smart Coach: Reset daily flags for \(today)")
        }
    }

    // MARK: - Main Entry Point

    /// Evaluate user progress and schedule appropriate evening notifications.
    /// Called from background task or when app goes to background.
    func scheduleSmartEveningUpdate() {
        resetDailyFlagsIfNeeded()

        let steps = StepRepository.shared.todaySteps
        let goal = StepRepository.shared.stepGoal
        let streak = StreakService.shared.currentStreak

        guard goal > 0 else { return }

        let percentage = Double(steps) / Double(goal)
        let remaining = goal - steps

        print("🧠 Smart Coach: Evaluating - \(steps)/\(goal) steps (\(Int(percentage * 100))%), streak: \(streak)")

        // Cancel any existing smart notifications first
        cancelPendingSmartNotifications()

        // SILENCE RULE: < 40% = rest day, no notifications
        guard percentage >= 0.40 else {
            print("🤫 Smart Coach: Silence rule - rest day detected (<40%)")
            return
        }

        // Already met goal? No evening notifications needed
        guard steps < goal else {
            print("✅ Smart Coach: Goal already met, no evening notifications needed")
            return
        }

        // TYPE A: The Closer (6:00 PM) - 70-99% of goal
        if percentage >= 0.70 {
            scheduleCloserNotification(remaining: remaining)
        }

        // TYPE B: The Streak Saver (8:30 PM) - only if streak > 2
        // NO DOUBLE DIPPING: Skip if Closer fires unless streak > 7 (high-value streak)
        let closerWillFire = percentage >= 0.70
        let highValueStreak = streak > 7

        if streak > 2 && (!closerWillFire || highValueStreak) {
            scheduleStreakSaverNotification(streak: streak)
        }
    }

    // MARK: - Type A: The Closer (6:00 PM)

    private func scheduleCloserNotification(remaining: Int) {
        // Check user preference (uses same setting as streak at risk)
        guard UserDefaults.standard.object(forKey: "notif.streakAtRisk.enabled") as? Bool ?? true else {
            print("🔇 Smart Coach: Closer notification disabled by user preference")
            return
        }

        let minutes = estimateWalkingTime(steps: remaining)

        let content = UNMutableNotificationContent()
        content.title = "You're So Close!"
        content.body = "You're only \(formatSteps(remaining)) steps away! A quick \(minutes)-min walk finishes the job."
        content.sound = .default
        content.interruptionLevel = .timeSensitive

        // Schedule for 6:00 PM today
        var components = Calendar.current.dateComponents([.year, .month, .day], from: Date())
        components.hour = 18
        components.minute = 0

        guard let scheduledTime = Calendar.current.date(from: components),
              scheduledTime > Date() else {
            print("⏰ Smart Coach: 6 PM already passed, skipping Closer notification")
            return
        }

        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)

        let request = UNNotificationRequest(
            identifier: closerNotificationId,
            content: content,
            trigger: trigger
        )

        // Mark as fired before scheduling (safe because we're on MainActor)
        closerFiredToday = true

        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("❌ Smart Coach: Failed to schedule Closer: \(error)")
            } else {
                print("🎯 Smart Coach: Scheduled 'The Closer' for 6 PM - \(remaining) steps remaining")
            }
        }
    }

    // MARK: - Type B: The Streak Saver (8:30 PM)

    private func scheduleStreakSaverNotification(streak: Int) {
        // Check user preference
        guard UserDefaults.standard.object(forKey: "notif.streakAtRisk.enabled") as? Bool ?? true else {
            print("🔇 Smart Coach: Streak Saver notification disabled by user preference")
            return
        }

        let content = UNMutableNotificationContent()
        content.title = "Protect Your Streak!"
        content.body = "⚠️ Your \(streak)-day streak is at risk! You're close—don't let it slip."
        content.sound = .default
        content.interruptionLevel = .timeSensitive

        // Schedule for 8:30 PM today
        var components = Calendar.current.dateComponents([.year, .month, .day], from: Date())
        components.hour = 20
        components.minute = 30

        guard let scheduledTime = Calendar.current.date(from: components),
              scheduledTime > Date() else {
            print("⏰ Smart Coach: 8:30 PM already passed, skipping Streak Saver notification")
            return
        }

        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)

        let request = UNNotificationRequest(
            identifier: streakSaverNotificationId,
            content: content,
            trigger: trigger
        )

        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("❌ Smart Coach: Failed to schedule Streak Saver: \(error)")
            } else {
                print("🔥 Smart Coach: Scheduled 'The Streak Saver' for 8:30 PM - \(streak)-day streak")
            }
        }
    }

    // MARK: - Type C: The High Five (Immediate)

    /// Trigger immediately when goal is reached.
    /// Called from .dailyStepGoalReached notification observer.
    func triggerGoalReachedNotification() {
        // Check user preference
        guard UserDefaults.standard.object(forKey: "notif.goalCelebrations.enabled") as? Bool ?? true else {
            print("🔇 Smart Coach: Goal celebration notification disabled by user preference")
            return
        }

        resetDailyFlagsIfNeeded()

        // ONE HIGH FIVE PER DAY: Check if already sent today
        guard lastHighFiveDateString != todayDateString else {
            print("🙌 Smart Coach: High Five already sent today, skipping")
            return
        }

        // Cancel any pending evening notifications since goal is met
        cancelPendingSmartNotifications()

        let content = UNMutableNotificationContent()
        content.title = "Goal Reached!"
        content.body = "You crushed it today! 🔥"
        content.sound = .default

        // Immediate notification (1 second delay minimum required)
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)

        let request = UNNotificationRequest(
            identifier: highFiveNotificationId,
            content: content,
            trigger: trigger
        )

        // Mark as sent before scheduling (safe because we're on MainActor)
        lastHighFiveDateString = todayDateString

        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("❌ Smart Coach: Failed to send High Five: \(error)")
            } else {
                print("🙌 Smart Coach: Sent 'The High Five' - Goal reached!")
            }
        }
    }

    // MARK: - Cancel Notifications

    /// Cancel all pending smart coach notifications
    func cancelPendingSmartNotifications() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(
            withIdentifiers: [closerNotificationId, streakSaverNotificationId]
        )
        print("🧹 Smart Coach: Cancelled pending evening notifications")
    }

    /// Cancel the High Five notification (if somehow pending)
    func cancelHighFiveNotification() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(
            withIdentifiers: [highFiveNotificationId]
        )
    }
}
