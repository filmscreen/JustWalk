//
//  DailyLog.swift
//  JustWalk
//
//  Core data model for daily activity logs
//

import Foundation

struct DailyLog: Codable, Identifiable {
    let id: UUID
    let date: Date // Normalized to start of day
    var steps: Int
    var goalMet: Bool
    var shieldUsed: Bool
    var trackedWalkIDs: [UUID]

    var dateString: String {
        // "2026-01-25"
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }
}
