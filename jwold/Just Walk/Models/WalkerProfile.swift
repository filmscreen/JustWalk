//
//  WalkerProfile.swift
//  Just Walk
//
//  Tracks user's walking identity progression metrics.
//

import Foundation

struct WalkerProfile: Codable {
    var currentRank: WalkerRank = .walker
    var rankAchievedDate: Date = Date()
    var firstWalkDate: Date?
    var totalWalks: Int = 0
    var totalMiles: Double = 0
    var longestStreak: Int = 0
    var currentStreak: Int = 0

    var daysAsWalker: Int {
        guard let firstWalk = firstWalkDate else { return 0 }
        return Calendar.current.dateComponents([.day], from: firstWalk, to: Date()).day ?? 0
    }
}
