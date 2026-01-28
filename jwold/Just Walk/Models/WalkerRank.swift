//
//  WalkerRank.swift
//  Just Walk
//
//  Identity-based progression system - users evolve through ranks
//  until becoming a "Just Walker" who walks because it's who they are.
//

import SwiftUI

enum WalkerRank: Int, Codable, CaseIterable, Comparable {
    case walker = 1
    case strider = 2
    case wayfarer = 3
    case centurion = 4
    case justWalker = 5

    var title: String {
        switch self {
        case .walker: return "Walker"
        case .strider: return "Strider"
        case .wayfarer: return "Wayfarer"
        case .centurion: return "Centurion"
        case .justWalker: return "Just Walker"
        }
    }

    var identityStatement: String {
        switch self {
        case .walker: return "I walk."
        case .strider: return "I've found my rhythm."
        case .wayfarer: return "I'm on a path."
        case .centurion: return "Nothing stops me."
        case .justWalker: return "I just walk."
        }
    }

    var icon: String {
        switch self {
        case .walker: return "figure.walk"
        case .strider: return "figure.walk.circle"
        case .wayfarer: return "figure.walk.motion"
        case .centurion: return "figure.walk.diamond"
        case .justWalker: return "figure.walk"  // Full circle - back to simple
        }
    }

    var color: Color {
        switch self {
        case .walker: return Color(hex: "00C7BE")      // Teal
        case .strider: return Color(hex: "007AFF")     // Blue
        case .wayfarer: return Color(hex: "AF52DE")    // Purple
        case .centurion: return Color(hex: "FF9500")   // Orange
        case .justWalker: return Color(hex: "FFD700")  // Gold
        }
    }

    static func < (lhs: WalkerRank, rhs: WalkerRank) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    /// Returns the next rank in progression, or nil if at max rank
    var nextRank: WalkerRank? {
        switch self {
        case .walker: return .strider
        case .strider: return .wayfarer
        case .wayfarer: return .centurion
        case .centurion: return .justWalker
        case .justWalker: return nil
        }
    }

    /// Determine rank based on lifetime steps
    /// Thresholds:
    /// - Walker: 0 - 99,999 steps
    /// - Strider: 100,000 - 499,999 steps
    /// - Wayfarer: 500,000 - 999,999 steps
    /// - Centurion: 1,000,000 - 4,999,999 steps
    /// - Just Walker: 5,000,000+ steps
    static func rank(forLifetimeSteps steps: Int) -> WalkerRank {
        switch steps {
        case 0..<100_000:
            return .walker
        case 100_000..<500_000:
            return .strider
        case 500_000..<1_000_000:
            return .wayfarer
        case 1_000_000..<5_000_000:
            return .centurion
        default:
            return .justWalker
        }
    }
}
