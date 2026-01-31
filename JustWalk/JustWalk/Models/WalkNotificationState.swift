//
//  WalkNotificationState.swift
//  JustWalk
//
//  Persistent state for daily walk reminders
//

import Foundation

struct WalkNotificationState: Codable {
    var lastNotificationSentDate: Date?
    var lastNotificationScheduledDate: Date?
    var notificationTappedToday: Bool
    var userPreferredTime: Date?
    var notificationsEnabled: Bool
    var smartTimingEnabled: Bool

    static let empty = WalkNotificationState(
        lastNotificationSentDate: nil,
        lastNotificationScheduledDate: nil,
        notificationTappedToday: false,
        userPreferredTime: nil,
        notificationsEnabled: true,
        smartTimingEnabled: true
    )
}
