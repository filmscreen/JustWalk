//
//  LegacyBadge.swift
//  JustWalk
//
//  Core data model for legacy streak badges
//

import Foundation

struct LegacyBadge: Codable, Identifiable, Equatable {
    let id: UUID
    let streakLength: Int
    let earnedAt: Date

    var name: String {
        "The \(streakLength) Club"
    }

    static let thresholds = [30, 50, 100, 200, 365, 500, 1000]

    static func badge(for streakLength: Int) -> LegacyBadge? {
        guard streakLength >= 30 else { return nil }
        let tier = thresholds.last { streakLength >= $0 } ?? 30
        return LegacyBadge(id: UUID(), streakLength: tier, earnedAt: Date())
    }
}
