//
//  NotificationManager.swift
//  Just Walk
//
//  Manages local notifications for streaks, milestones, and weekly summaries.
//

import Foundation
import SwiftUI
import UserNotifications
import Combine

@MainActor
final class NotificationManager: ObservableObject {

    // MARK: - Singleton

    static let shared = NotificationManager()

    // MARK: - Published Properties

    @Published private(set) var unreadCount: Int = 0

    // MARK: - Initialization

    private init() {
        // NOTE: Do NOT request permissions here!
        // Permissions should only be requested during onboarding when user taps "Allow"
    }

    // MARK: - Permissions

    func requestNotificationPermissions() async {
        do {
            let center = UNUserNotificationCenter.current()
            let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge])
            print("📬 Notification permission: \(granted ? "granted" : "denied")")
        } catch {
            print("❌ Failed to request notification permissions: \(error)")
        }
    }

    // MARK: - Badge Management

    func updateAppBadge() async {
        let center = UNUserNotificationCenter.current()

        do {
            try await center.setBadgeCount(unreadCount)
            print("📬 Updated app badge to: \(unreadCount)")
        } catch {
            print("❌ Failed to update app badge: \(error)")
        }
    }

    func clearAppBadge() async {
        let center = UNUserNotificationCenter.current()

        do {
            try await center.setBadgeCount(0)
            print("📬 Cleared app badge")
        } catch {
            print("❌ Failed to clear app badge: \(error)")
        }
    }

    // MARK: - Local Push Notification

    func scheduleLocalNotification(
        title: String,
        body: String,
        delay: TimeInterval = 0,
        identifier: String = UUID().uuidString
    ) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(
            timeInterval: max(delay, 1),
            repeats: false
        )

        let request = UNNotificationRequest(
            identifier: identifier,
            content: content,
            trigger: trigger
        )

        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("❌ Failed to schedule local notification: \(error)")
            } else {
                print("📬 Scheduled local notification: \(title)")
            }
        }
    }

    // MARK: - Reminder Time

    /// Get the user's preferred reminder time (defaults to 6 PM)
    private var reminderTimeComponents: DateComponents {
        let reminderTimeInterval = UserDefaults.standard.double(forKey: "streakReminderTime")

        if reminderTimeInterval > 0 {
            let date = Date(timeIntervalSinceReferenceDate: reminderTimeInterval)
            return Calendar.current.dateComponents([.hour, .minute], from: date)
        }

        // Default: 6 PM
        var components = DateComponents()
        components.hour = 18
        components.minute = 0
        return components
    }

    /// Reschedule streak reminders with new time setting
    func rescheduleStreakReminders() {
        // Cancel existing and reschedule will happen on next streak check
        cancelStreakAtRiskNotification()
        print("📬 Streak reminders rescheduled for new time")
    }

    // MARK: - Streak Notifications

    /// Schedule a "streak at risk" notification for user's preferred time
    func scheduleStreakAtRiskNotification(
        currentStreak: Int,
        stepsRemaining: Int,
        stepGoal: Int
    ) {
        // Check user preference
        guard UserDefaults.standard.object(forKey: "notif.streakAtRisk.enabled") as? Bool ?? true else { return }

        guard currentStreak > 0 else { return }
        guard stepsRemaining > 0 else {
            cancelStreakAtRiskNotification()
            return
        }

        let content = UNMutableNotificationContent()
        content.title = "Streak at Risk!"
        content.body = "\(stepsRemaining.formatted()) steps to keep your \(currentStreak)-day streak"
        content.sound = .default
        content.interruptionLevel = .timeSensitive

        // Use user's preferred reminder time
        let timeComponents = reminderTimeComponents
        var components = Calendar.current.dateComponents([.year, .month, .day], from: Date())
        components.hour = timeComponents.hour
        components.minute = timeComponents.minute

        if let scheduledTime = Calendar.current.date(from: components),
           scheduledTime > Date() {

            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)

            let request = UNNotificationRequest(
                identifier: "streak.at.risk",
                content: content,
                trigger: trigger
            )

            UNUserNotificationCenter.current().add(request) { error in
                if let error = error {
                    print("❌ Failed to schedule streak notification: \(error)")
                } else {
                    let hour = timeComponents.hour ?? 18
                    let minute = timeComponents.minute ?? 0
                    print("🔥 Scheduled streak-at-risk notification for \(hour):\(String(format: "%02d", minute))")
                }
            }
        }
    }

    func cancelStreakAtRiskNotification() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(
            withIdentifiers: ["streak.at.risk"]
        )
        print("🔥 Cancelled streak-at-risk notification")
    }

    func scheduleStreakMilestoneNotification(newStreak: Int) {
        // Check user preference
        guard UserDefaults.standard.object(forKey: "notif.milestones.enabled") as? Bool ?? true else { return }

        let milestones = [7, 14, 30, 60, 90, 100, 180, 365]

        guard milestones.contains(newStreak) else { return }

        let content = UNMutableNotificationContent()
        content.title = milestoneTitle(for: newStreak)
        content.body = milestoneBody(for: newStreak)
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)

        let request = UNNotificationRequest(
            identifier: "streak.milestone.\(newStreak)",
            content: content,
            trigger: trigger
        )

        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("❌ Failed to schedule milestone notification: \(error)")
            } else {
                print("🏆 Scheduled streak milestone notification for \(newStreak) days")
            }
        }
    }

    private func milestoneTitle(for streak: Int) -> String {
        switch streak {
        case 7: return "1 Week Streak!"
        case 14: return "2 Week Streak!"
        case 30: return "1 Month Streak!"
        case 60: return "2 Month Streak!"
        case 90: return "3 Month Streak!"
        case 100: return "100 Day Streak!"
        case 180: return "6 Month Streak!"
        case 365: return "1 Year Streak!"
        default: return "\(streak) Day Streak!"
        }
    }

    private func milestoneBody(for streak: Int) -> String {
        switch streak {
        case 7: return "One week of consistency. You're building a real habit!"
        case 14: return "Two weeks strong! Your dedication is paying off."
        case 30: return "A full month! You've proven walking is part of your life."
        case 60: return "Two months of daily walks. Incredible commitment!"
        case 90: return "Three months! You're a walking champion."
        case 100: return "Triple digits! You're unstoppable."
        case 180: return "Half a year of daily walks. You're inspiring!"
        case 365: return "A full year! You're a walking legend."
        default: return "Keep up the amazing work!"
        }
    }

    // MARK: - Streak Lost Notification

    /// Schedule "Streak Lost" notification for morning after a miss
    /// Called when streak is broken (e.g., during validateStreakOnAppOpen)
    func scheduleStreakLostNotification(previousStreak: Int) {
        // Only notify if they had a meaningful streak (3+ days)
        guard previousStreak >= 3 else { return }

        // Check user preference (default: enabled)
        guard UserDefaults.standard.object(forKey: "notif.streakLost.enabled") as? Bool ?? true else { return }

        let content = UNMutableNotificationContent()
        content.title = "Your streak ended"
        content.body = "Your \(previousStreak)-day streak is over, but today is a fresh start. Let's build a new one!"
        content.sound = .default

        // Schedule for 9 AM today
        var dateComponents = Calendar.current.dateComponents([.year, .month, .day], from: Date())
        dateComponents.hour = 9
        dateComponents.minute = 0

        // If it's already past 9 AM, schedule for immediate delivery
        let now = Date()
        let calendar = Calendar.current
        let currentHour = calendar.component(.hour, from: now)

        let trigger: UNNotificationTrigger
        if currentHour >= 9 {
            // Already past 9 AM, deliver in 5 seconds
            trigger = UNTimeIntervalNotificationTrigger(timeInterval: 5, repeats: false)
        } else {
            // Schedule for 9 AM
            trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: false)
        }

        let request = UNNotificationRequest(
            identifier: "streak.lost",
            content: content,
            trigger: trigger
        )

        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("❌ Failed to schedule streak lost notification: \(error)")
            } else {
                print("💔 Scheduled streak lost notification (previous streak: \(previousStreak) days)")
            }
        }
    }

    func cancelStreakLostNotification() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(
            withIdentifiers: ["streak.lost"]
        )
    }

    // MARK: - Weekly Snapshot Notification

    func scheduleWeeklySnapshotNotification() {
        let content = UNMutableNotificationContent()
        content.title = "Your Weekly Snapshot is ready!"
        content.body = "See how you did last week 🏆"
        content.sound = .default

        var components = DateComponents()
        components.weekday = 2  // Monday
        components.hour = 9
        components.minute = 0

        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)

        let request = UNNotificationRequest(
            identifier: "weekly.snapshot",
            content: content,
            trigger: trigger
        )

        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("❌ Failed to schedule weekly snapshot notification: \(error)")
            } else {
                print("🏆 Weekly snapshot notification scheduled for Mondays at 9 AM")
            }
        }
    }

    func cancelWeeklySnapshotNotification() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(
            withIdentifiers: ["weekly.snapshot"]
        )
    }
}
