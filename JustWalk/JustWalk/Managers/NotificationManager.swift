//
//  NotificationManager.swift
//  JustWalk
//
//  "Quiet Partner" notification system — only 3 essential notification types
//

import Foundation
import UserNotifications
import UIKit

@Observable
class NotificationManager {
    static let shared = NotificationManager()

    private let center = UNUserNotificationCenter.current()

    // MARK: - Persisted Preferences

    var isEnabled: Bool {
        didSet { UserDefaults.standard.set(isEnabled, forKey: "notif_isEnabled") }
    }

    var streakRemindersEnabled: Bool {
        didSet { UserDefaults.standard.set(streakRemindersEnabled, forKey: "notif_streakReminders") }
    }

    var streakReminderHour: Int {
        didSet { UserDefaults.standard.set(streakReminderHour, forKey: "notif_streakReminderHour") }
    }

    var streakReminderMinute: Int {
        didSet { UserDefaults.standard.set(streakReminderMinute, forKey: "notif_streakReminderMinute") }
    }

    var goalCelebrationsEnabled: Bool {
        didSet { UserDefaults.standard.set(goalCelebrationsEnabled, forKey: "notif_goalCelebrations") }
    }

    private init() {
        let defaults = UserDefaults.standard

        // Register defaults for first launch — notifications default ON
        defaults.register(defaults: [
            "notif_isEnabled": true,
            "notif_streakReminders": true,
            "notif_streakReminderHour": 19,
            "notif_streakReminderMinute": 0,
            "notif_goalCelebrations": true
        ])

        self.isEnabled = defaults.bool(forKey: "notif_isEnabled")
        self.streakRemindersEnabled = defaults.bool(forKey: "notif_streakReminders")
        self.streakReminderHour = defaults.integer(forKey: "notif_streakReminderHour")
        self.streakReminderMinute = defaults.integer(forKey: "notif_streakReminderMinute")
        self.goalCelebrationsEnabled = defaults.bool(forKey: "notif_goalCelebrations")
    }

    // MARK: - Authorization

    func requestAuthorization() async -> Bool {
        do {
            return try await center.requestAuthorization(options: [.alert, .sound, .badge])
        } catch {
            return false
        }
    }

    // MARK: - 1. Streak Reminder (Evening)

    /// Scheduled at user's configured time when streak is at risk
    func scheduleStreakAtRiskReminder(streak: Int) {
        guard isEnabled, streakRemindersEnabled else { return }

        // Suppress if user was active in app within the last 5 minutes
        if let lastOpen = UserDefaults.standard.object(forKey: "lastAppOpenTime") as? Date,
           Date().timeIntervalSince(lastOpen) < 300 {
            return
        }

        let content = UNMutableNotificationContent()
        content.title = "Still time for a walk."
        content.body = "Keep your \(streak)-day streak alive."
        content.sound = .default
        content.categoryIdentifier = "STREAK_RISK"

        var dateComponents = DateComponents()
        dateComponents.hour = streakReminderHour
        dateComponents.minute = streakReminderMinute

        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: false)

        let request = UNNotificationRequest(
            identifier: "streak_at_risk",
            content: content,
            trigger: trigger
        )

        center.add(request)
    }

    // MARK: - 2. Goal Celebration

    /// Fires immediately when daily goal is achieved
    func sendGoalAchievedNotification(streak: Int) {
        guard isEnabled, goalCelebrationsEnabled else { return }
        let content = UNMutableNotificationContent()
        content.title = "Goal hit."
        content.body = "Day \(streak) in the books."
        content.sound = .default
        content.categoryIdentifier = "CELEBRATION"

        scheduleNotification(content: content, identifier: "goal_achieved")
    }

    // MARK: - 3. Shield Deployed

    /// Always-on notification when shield auto-deploys overnight
    func sendShieldDeployedNotification(remainingShields: Int) {
        guard isEnabled else { return }
        let content = UNMutableNotificationContent()
        content.title = "Your streak is safe."
        content.body = "We used a shield. \(remainingShields) remaining."
        content.sound = .default

        scheduleNotification(content: content, identifier: "shield_deployed")
    }

    // MARK: - 4. Walk Reminder (Forgotten Walk)

    /// Schedule a reminder notification for when a walk exceeds expected duration.
    /// Only one reminder per walk — if the walk ends before it fires, cancel it.
    func scheduleWalkReminder(mode: WalkMode, expectedDurationSeconds: Int?) {
        guard isEnabled else { return }

        let reminderDelay: TimeInterval

        switch mode {
        case .free:
            // Quick Walk: 45 minutes
            reminderDelay = 45 * 60
        case .interval, .fatBurn:
            // Intervals/Fat Burn: expected duration + 15 minutes
            let expected = TimeInterval(expectedDurationSeconds ?? (20 * 60))
            reminderDelay = expected + (15 * 60)
        case .postMeal:
            // Post-Meal: expected duration + 10 minutes
            let expected = TimeInterval(expectedDurationSeconds ?? (10 * 60))
            reminderDelay = expected + (10 * 60)
        }

        let content = UNMutableNotificationContent()
        content.title = "Still walking?"
        content.body = "Tap to end your walk when you're done."
        content.sound = .default
        content.categoryIdentifier = "WALK_ACTIVE"

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: reminderDelay, repeats: false)
        let request = UNNotificationRequest(identifier: "walk_reminder", content: content, trigger: trigger)

        center.add(request)
    }

    /// Cancel the walk reminder notification (called when walk ends normally)
    func cancelWalkReminder() {
        center.removePendingNotificationRequests(withIdentifiers: ["walk_reminder"])
    }

    // MARK: - 5. Interval Phase Change Notification

    /// Fires when interval phase changes to inform user what to do.
    /// Always fires (regardless of screen state or Watch) to provide clear text instruction.
    /// Watch haptics provide attention; this notification provides the instruction.
    func sendIntervalPhaseChangeNotification(isFastPhase: Bool) {
        print("🔔 sendIntervalPhaseChangeNotification called - isEnabled=\(isEnabled), isFastPhase=\(isFastPhase)")
        guard isEnabled else {
            print("🔔 Notification skipped - isEnabled is false")
            return
        }

        let content = UNMutableNotificationContent()
        content.title = isFastPhase ? "Speed up!" : "Slow down"
        content.body = isFastPhase ? "Time to pick up the pace." : "Recovery phase — easy pace."
        content.sound = .default
        content.interruptionLevel = .timeSensitive

        let identifier = "interval_phase_\(UUID().uuidString)"
        print("🔔 Scheduling notification with identifier: \(identifier)")
        scheduleNotification(content: content, identifier: identifier)
    }

    // MARK: - 6. Fat Burn Zone Alerts

    /// Fires when heart rate goes out of fat burn zone to inform user what to do.
    /// Always fires (regardless of screen state or Watch) to provide clear text instruction.
    /// Watch haptics provide attention; this notification provides the instruction.
    func sendFatBurnOutOfRangeNotification(isBelowZone: Bool) {
        guard isEnabled else { return }

        let content = UNMutableNotificationContent()
        if isBelowZone {
            content.title = "Pick up the pace"
            content.body = "Heart rate is below your fat burn zone."
        } else {
            content.title = "Ease up a bit"
            content.body = "Heart rate is above your fat burn zone."
        }
        content.sound = .default
        content.interruptionLevel = .timeSensitive

        scheduleNotification(content: content, identifier: "fatburn_zone_\(UUID().uuidString)")
    }

    // MARK: - 7. Walk Auto-End Notification

    /// Fires when a walk is automatically ended due to inactivity or time limit.
    /// Ensures user knows their walk has stopped tracking.
    func sendWalkAutoEndedNotification(reason: WalkAutoEndReason) {
        guard isEnabled else { return }

        let content = UNMutableNotificationContent()
        switch reason {
        case .inactivity:
            content.title = "Walk ended"
            content.body = "No activity detected for 10 minutes."
        case .timeLimit:
            content.title = "Walk ended"
            content.body = "Maximum walk duration reached."
        }
        content.sound = .default
        content.interruptionLevel = .timeSensitive

        scheduleNotification(content: content, identifier: "walk_auto_ended")
    }

    enum WalkAutoEndReason {
        case inactivity
        case timeLimit
    }

    // MARK: - Notification Categories

    func registerCategories() {
        let startWalkAction = UNNotificationAction(
            identifier: "START_WALK",
            title: "Start Walk",
            options: .foreground
        )

        let viewAction = UNNotificationAction(
            identifier: "VIEW",
            title: "View",
            options: .foreground
        )

        let streakRisk = UNNotificationCategory(
            identifier: "STREAK_RISK",
            actions: [startWalkAction],
            intentIdentifiers: []
        )

        let walkReminder = UNNotificationCategory(
            identifier: "WALK_REMINDER",
            actions: [startWalkAction],
            intentIdentifiers: []
        )

        let celebration = UNNotificationCategory(
            identifier: "CELEBRATION",
            actions: [viewAction],
            intentIdentifiers: []
        )

        let endWalkAction = UNNotificationAction(
            identifier: "END_WALK",
            title: "End Walk",
            options: .foreground
        )

        let walkActive = UNNotificationCategory(
            identifier: "WALK_ACTIVE",
            actions: [endWalkAction],
            intentIdentifiers: []
        )

        center.setNotificationCategories([streakRisk, walkReminder, celebration, walkActive])
    }

    // MARK: - Helpers

    private func scheduleNotification(content: UNMutableNotificationContent, identifier: String) {
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        center.add(request) { error in
            if let error = error {
                print("🔔 ERROR scheduling notification: \(error.localizedDescription)")
            } else {
                print("🔔 Notification scheduled successfully: \(identifier)")
            }
        }
    }

    func cancelAllPendingNotifications() {
        center.removeAllPendingNotificationRequests()
    }

    func clearAllDeliveredNotifications() {
        center.removeAllDeliveredNotifications()
    }
}
