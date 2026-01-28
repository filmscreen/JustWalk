//
//  RankCardVisibility.swift
//  Just Walk
//
//  Determines what rank card to show on the Today screen.
//  Progressive disclosure: ranks appear only when meaningful.
//

import Foundation

// MARK: - Visibility Enum

enum RankCardVisibility {
    /// Walker rank, not close to ranking up - hide the card
    case hidden
    /// Walker rank, close to Strider (streak >= 5 OR walks >= 10)
    case teaser
    /// Strider or above - show full identity card
    case shown
}

// MARK: - RankManager Extension

extension RankManager {

    /// Determines what rank card should be shown on the Today screen
    var rankCardVisibility: RankCardVisibility {
        if profile.currentRank == .walker {
            // Show teaser when approaching first rank-up
            if profile.currentStreak >= 5 || profile.totalWalks >= 10 {
                return .teaser
            }
            return .hidden
        }
        return .shown
    }

    /// Returns the next rank in progression, or nil if at max rank
    var nextRank: WalkerRank? {
        profile.currentRank.nextRank
    }

    /// Returns a user-friendly progress description for the identity card
    /// Example: "16 days to Wayfarer"
    func progressDescription() -> String? {
        // No progress description for max rank
        guard let next = nextRank, let closest = closestPathToNextRank() else {
            return nil
        }

        let remaining = Int(closest.required - closest.current)

        switch closest.metric {
        case "day streak":
            return "\(remaining) days to \(next.title)"
        case "walks":
            return "\(remaining) walks to \(next.title)"
        case "miles":
            return "\(remaining) mi to \(next.title)"
        default:
            return nil
        }
    }

    /// Returns days remaining to first rank-up (for teaser card)
    func daysToStrider() -> Int? {
        guard profile.currentRank == .walker else { return nil }
        return max(0, 7 - profile.currentStreak)
    }
}
