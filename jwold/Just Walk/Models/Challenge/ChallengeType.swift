//
//  ChallengeType.swift
//  Just Walk
//
//  Challenge types categorizing different challenge durations and difficulty levels.
//

import Foundation

/// Types of challenges available in the app
enum ChallengeType: String, Codable, CaseIterable {
    /// Monthly challenges (e.g., "January Steps Challenge")
    case seasonal

    /// Weekly challenges (e.g., "Weekend Warrior")
    case weekly

    /// Short-term challenges lasting hours (e.g., "Speed Demon")
    case quick

    /// Display name for the challenge type
    var displayName: String {
        switch self {
        case .seasonal:
            return "Seasonal"
        case .weekly:
            return "Weekly"
        case .quick:
            return "Quick"
        }
    }

    /// Icon name for the challenge type
    var iconName: String {
        switch self {
        case .seasonal:
            return "calendar"
        case .weekly:
            return "calendar.badge.clock"
        case .quick:
            return "bolt.fill"
        }
    }

    /// Typical reward range description
    var rewardDescription: String {
        switch self {
        case .seasonal:
            return "Up to 10 bonus walks"
        case .weekly:
            return "Up to 3 bonus walks"
        case .quick:
            return "1 bonus walk"
        }
    }
}
