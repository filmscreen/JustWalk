//
//  WatchIntervalProgram.swift
//  JustWalkWatch Watch App
//
//  Interval programs for timed walks (mirrors iPhone IntervalProgram)
//

import Foundation

enum WatchIntervalProgram: String, Codable, CaseIterable, Identifiable {
    case short
    case medium

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .short: "Quick"
        case .medium: "Standard"
        }
    }

    /// Advertised duration (slightly less than actual for marketing)
    var durationMinutes: Int {
        switch self {
        case .short: 18   // Actual: 20 min
        case .medium: 30  // Actual: 32 min
        }
    }

    /// Actual duration in seconds based on interval structure
    var durationSeconds: Int {
        // 1m warmup + (intervalCount * 6m) + 1m cooldown
        return 60 + (intervalCount * 6 * 60) + 60
    }

    /// Number of fast/slow interval pairs
    var intervalCount: Int {
        switch self {
        case .short: 3
        case .medium: 5
        }
    }

    var fastMinutes: Int { 3 }

    var slowMinutes: Int { 3 }
}

