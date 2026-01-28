//
//  Challenge.swift
//  Just Walk
//
//  Challenge template definition with requirements and rewards.
//

import Foundation

/// Pattern for which days count toward challenge completion
enum DaysPattern: String, Codable {
    /// All days of the week count
    case allDays

    /// Only Saturday and Sunday count
    case weekendsOnly

    /// Only Monday through Friday count
    case weekdaysOnly

    /// Display name for the pattern
    var displayName: String {
        switch self {
        case .allDays:
            return "Every day"
        case .weekendsOnly:
            return "Weekends only"
        case .weekdaysOnly:
            return "Weekdays only"
        }
    }

    /// Check if a given date matches this pattern
    func matches(date: Date) -> Bool {
        let calendar = Calendar.current
        let weekday = calendar.component(.weekday, from: date)
        // Sunday = 1, Saturday = 7

        switch self {
        case .allDays:
            return true
        case .weekendsOnly:
            return weekday == 1 || weekday == 7
        case .weekdaysOnly:
            return weekday >= 2 && weekday <= 6
        }
    }
}

/// Challenge template defining requirements and rewards
struct Challenge: Identifiable, Codable, Equatable {
    /// Unique identifier for the challenge (e.g., "january_2026_steps")
    let id: String

    /// Type of challenge (seasonal, weekly, quick)
    let type: ChallengeType

    /// Display title for the challenge
    let title: String

    /// Description of the challenge
    let description: String

    /// SF Symbol icon name
    let iconName: String

    // MARK: - Requirements

    /// Daily step target required to complete a qualifying day
    let dailyStepTarget: Int

    /// Number of days that must meet the target to complete the challenge
    let targetDays: Int

    /// Which days count toward the challenge
    let requiredDaysPattern: DaysPattern

    // MARK: - Time Constraints

    /// When the challenge becomes available
    let startDate: Date

    /// When the challenge expires
    let endDate: Date

    /// Duration in hours for quick challenges (nil for multi-day challenges)
    let durationHours: Int?

    // MARK: - Rewards

    /// Optional badge ID awarded on completion
    let badgeId: String?

    /// Difficulty level 1-5
    let difficultyLevel: Int

    // MARK: - Computed Properties

    /// Whether this challenge is currently available to start
    var isCurrentlyAvailable: Bool {
        let now = Date()
        return now >= startDate && now <= endDate
    }

    /// Total steps required to complete the challenge
    var totalStepsRequired: Int {
        dailyStepTarget * targetDays
    }

    /// Whether this is a quick (timed) challenge
    var isQuickChallenge: Bool {
        durationHours != nil
    }

    /// Formatted duration string
    var durationDescription: String {
        if let hours = durationHours {
            if hours == 1 {
                return "1 hour"
            } else {
                return "\(hours) hours"
            }
        } else if targetDays == 1 {
            return "1 day"
        } else {
            return "\(targetDays) days"
        }
    }

    /// Days remaining until challenge expires
    var daysUntilExpiration: Int {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.day], from: Date(), to: endDate)
        return max(0, components.day ?? 0)
    }

    // MARK: - Equatable

    static func == (lhs: Challenge, rhs: Challenge) -> Bool {
        lhs.id == rhs.id
    }
}
