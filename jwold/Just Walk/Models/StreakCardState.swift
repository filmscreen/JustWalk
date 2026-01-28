//
//  StreakCardState.swift
//  Just Walk
//
//  State enum for the Streak Card on the Today screen.
//

import SwiftUI

// MARK: - Streak Card State

enum StreakCardState: Equatable {
    case loading
    case noStreak
    case active(days: Int, isSecured: Bool)
    case atRisk(days: Int, stepsRemaining: Int)
    case protected(days: Int)
    case lost(previousStreak: Int)
    case milestone(days: Int)

    // MARK: - Convenience Properties

    var isMilestone: Bool {
        if case .milestone = self { return true }
        return false
    }

    var isActive: Bool {
        switch self {
        case .active, .protected, .milestone:
            return true
        default:
            return false
        }
    }

    var streakDays: Int? {
        switch self {
        case .active(let days, _): return days
        case .atRisk(let days, _): return days
        case .protected(let days): return days
        case .milestone(let days): return days
        default: return nil
        }
    }
}

// MARK: - Streak Milestones

enum StreakMilestone: Int, CaseIterable {
    case week = 7
    case twoWeeks = 14
    case threeWeeks = 21
    case month = 30
    case twoMonths = 60
    case quarter = 90
    case hundred = 100
    case fiveMonths = 150
    case twoHundred = 200
    case year = 365

    var title: String {
        "\(rawValue)-day streak!"
    }

    var subtitle: String {
        switch self {
        case .week: return "One whole week. Amazing!"
        case .twoWeeks: return "Two weeks strong!"
        case .threeWeeks: return "Three weeks. A habit is forming!"
        case .month: return "A full month. You're unstoppable!"
        case .twoMonths: return "Two months of consistency!"
        case .quarter: return "A quarter year. Incredible!"
        case .hundred: return "Triple digits! You're in the top 1%!"
        case .fiveMonths: return "Five months. Legend status!"
        case .twoHundred: return "Almost a year. Keep going!"
        case .year: return "A FULL YEAR. You're a walking legend!"
        }
    }

    static func from(days: Int) -> StreakMilestone? {
        StreakMilestone(rawValue: days)
    }

    static let allValues: [Int] = allCases.map(\.rawValue)
}
