//
//  ShareCard.swift
//  Just Walk
//
//  Data models for shareable achievement cards.
//

import Foundation
import SwiftUI
import UIKit

// MARK: - Share Card Types

enum ShareCardType: Identifiable {
    case dailyGoal(DailyGoalShareData)
    case streakMilestone(StreakMilestoneShareData)
    case weeklySnapshot(WeeklySnapshotShareData)
    case personalRecord(PersonalRecordShareData)
    case workout(WorkoutShareData)
    case walkerCard(WalkerCardData)

    var id: String {
        switch self {
        case .dailyGoal(let data): return "daily-\(data.date.timeIntervalSince1970)"
        case .streakMilestone(let data): return "streak-\(data.streakCount)"
        case .weeklySnapshot(let data): return "weekly-\(data.weekStartDate.timeIntervalSince1970)"
        case .personalRecord(let data): return "record-\(data.recordType.rawValue)"
        case .workout(let data): return "workout-\(data.date.timeIntervalSince1970)"
        case .walkerCard(let data): return "walker-\(data.rank.rawValue)"
        }
    }

    var suggestedCaption: String {
        switch self {
        case .dailyGoal(let data):
            return "Crushed my \(data.goal.formatted()) step goal today with \(data.steps.formatted()) steps! \(data.celebrationPhrase) #JustWalk #StepGoals"
        case .streakMilestone(let data):
            return "\(data.streakCount) days of walking! \(data.motivationalText) #JustWalk #WalkingStreak"
        case .weeklySnapshot(let data):
            return "My week in steps: \(data.totalSteps.formatted()) total, \(data.dailyAverage.formatted()) daily average. #JustWalk #WeeklyProgress"
        case .personalRecord(let data):
            return "New personal record! \(data.recordType.displayName): \(data.newValue) #JustWalk #PersonalBest"
        case .workout(let data):
            return "Just finished a \(data.formattedDistance) walk! #JustWalk #Walking #Fitness"
        case .walkerCard(let data):
            return "I'm a \(data.rank.title)! \(data.daysAsWalker) days walking. #JustWalk"
        }
    }

    /// Whether this card type uses square format (1080x1080) vs story format (1080x1920)
    var isSquareFormat: Bool {
        switch self {
        case .walkerCard:
            return true
        default:
            return false
        }
    }
}

// MARK: - Daily Goal Share Data

struct DailyGoalShareData {
    let date: Date
    let steps: Int
    let goal: Int
    let distanceMiles: Double
    let celebrationPhrase: String

    var formattedDate: String {
        date.formatted(date: .abbreviated, time: .omitted)
    }

    var formattedDistance: String {
        String(format: "%.1f mi", distanceMiles)
    }
}

// MARK: - Streak Milestone Share Data

struct StreakMilestoneShareData {
    let streakCount: Int
    let streakStartDate: Date?
    let motivationalText: String
    let hasShield: Bool

    var formattedStartDate: String? {
        streakStartDate?.formatted(date: .abbreviated, time: .omitted)
    }

    var milestoneEmoji: String {
        switch streakCount {
        case 7: return "7"
        case 14: return "14"
        case 30: return "30"
        case 60: return "60"
        case 90: return "90"
        case 100: return "100"
        case 180: return "180"
        case 365: return "365"
        default:
            if streakCount >= 365 { return "365+" }
            return "\(streakCount)"
        }
    }
}

// MARK: - Weekly Snapshot Share Data

struct WeeklySnapshotShareData {
    let weekStartDate: Date
    let weekEndDate: Date
    let totalSteps: Int
    let dailyAverage: Int
    let bestDayName: String?
    let bestDaySteps: Int?
    let totalMiles: Double

    var formattedDateRange: String {
        let start = weekStartDate.formatted(.dateTime.month().day())
        let end = weekEndDate.formatted(.dateTime.month().day())
        return "\(start) - \(end)"
    }

    var formattedTotalSteps: String {
        totalSteps.formatted()
    }

    var formattedDailyAverage: String {
        if dailyAverage >= 1000 {
            return String(format: "%.1fk", Double(dailyAverage) / 1000)
        }
        return dailyAverage.formatted()
    }

    var formattedBestDay: String? {
        guard let name = bestDayName, let steps = bestDaySteps else { return nil }
        let stepsFormatted = steps >= 1000 ? String(format: "%.1fk", Double(steps) / 1000) : steps.formatted()
        return "\(name) (\(stepsFormatted))"
    }

    var formattedMiles: String {
        String(format: "%.1f mi", totalMiles)
    }
}

// MARK: - Personal Record Share Data

struct PersonalRecordShareData {
    let recordType: RecordType
    let newValue: String
    let previousValue: String?
    let date: Date

    enum RecordType: String {
        case longestStreak = "longest_streak"
        case bestDaySteps = "best_day_steps"
        case bestWeekSteps = "best_week_steps"

        var displayName: String {
            switch self {
            case .longestStreak: return "Longest Streak"
            case .bestDaySteps: return "Best Day"
            case .bestWeekSteps: return "Best Week"
            }
        }

        var icon: String {
            switch self {
            case .longestStreak: return "flame.fill"
            case .bestDaySteps: return "figure.walk"
            case .bestWeekSteps: return "calendar"
            }
        }
    }

    var formattedDate: String {
        date.formatted(date: .abbreviated, time: .omitted)
    }
}

// MARK: - Workout Share Data

struct WorkoutShareData {
    let date: Date
    let duration: TimeInterval
    let distanceMeters: Double
    let steps: Int?
    let routeImage: UIImage?

    /// Conditional headline based on step count
    var headline: String {
        guard let steps = steps else {
            return "Walk Complete"
        }

        switch steps {
        case 0..<500:
            return "Quick Walk"
        case 500..<2000:
            return "Nice Walk"
        case 2000..<5000:
            return "Great Walk"
        default:
            return "Amazing Walk"
        }
    }

    var formattedDistance: String {
        let miles = distanceMeters * 0.000621371
        return String(format: "%.2f mi", miles)
    }

    var formattedDuration: String {
        let hours = Int(duration) / 3600
        let minutes = (Int(duration) % 3600) / 60
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        }
        return "\(minutes) min"
    }

    var formattedDate: String {
        date.formatted(date: .abbreviated, time: .omitted)
    }
}

// MARK: - Walker Card Share Data

struct WalkerCardData {
    let rank: WalkerRank
    let displayName: String
    let daysAsWalker: Int
    let totalMiles: Double
    let background: CardBackground
    let customColor: Color?
}

// MARK: - Share Platform

enum SharePlatform: String, CaseIterable {
    case instagram = "Instagram"
    case tiktok = "TikTok"
    case facebook = "Facebook"
    case twitter = "Twitter"
    case messages = "Messages"
    case more = "More"

    var icon: String {
        switch self {
        case .instagram: return "camera.circle.fill"
        case .tiktok: return "play.circle.fill"
        case .facebook: return "f.circle.fill"
        case .twitter: return "at.circle.fill"
        case .messages: return "message.circle.fill"
        case .more: return "square.and.arrow.up.circle.fill"
        }
    }
}
