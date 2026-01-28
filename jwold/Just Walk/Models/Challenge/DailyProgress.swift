//
//  DailyProgress.swift
//  Just Walk
//
//  Per-day step tracking for multi-day challenges.
//

import Foundation

/// Tracks step progress for a single day within a challenge
struct DailyProgress: Identifiable, Codable, Equatable {
    /// Unique identifier for this daily entry
    let id: UUID

    /// The date this progress is for (normalized to start of day)
    let date: Date

    /// Number of steps recorded for this day
    var steps: Int

    /// Whether the daily goal was met
    var goalMet: Bool

    /// When this entry was last updated
    var lastUpdated: Date

    /// Initialize a new daily progress entry
    init(
        id: UUID = UUID(),
        date: Date,
        steps: Int = 0,
        goalMet: Bool = false,
        lastUpdated: Date = Date()
    ) {
        self.id = id
        self.date = Calendar.current.startOfDay(for: date)
        self.steps = steps
        self.goalMet = goalMet
        self.lastUpdated = lastUpdated
    }

    /// Check if this progress is for today
    var isToday: Bool {
        Calendar.current.isDateInToday(date)
    }
}
