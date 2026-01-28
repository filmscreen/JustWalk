//
//  NotificationManager.swift
//  JustWalk
//
//  "Quiet Partner" notification system — only 3 essential notification types
//

import Foundation
import UserNotifications

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

        let celebration = UNNotificationCategory(
            identifier: "CELEBRATION",
            actions: [viewAction],
            intentIdentifiers: []
        )

        center.setNotificationCategories([streakRisk, celebration])
    }

    // MARK: - Helpers

    private func scheduleNotification(content: UNMutableNotificationContent, identifier: String) {
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        center.add(request)
    }

    func cancelAllPendingNotifications() {
        center.removeAllPendingNotificationRequests()
    }

    func clearAllDeliveredNotifications() {
        center.removeAllDeliveredNotifications()
    }
}
