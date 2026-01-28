//
//  WalkType.swift
//  Just Walk
//
//  Walk type definitions for the time-based walk selection flow.
//

import SwiftUI

/// Available walk types in the app
enum WalkType: String, CaseIterable, Identifiable, Codable {
    case justWalk       // FREE - basic GPS tracking
    case fatBurn        // PRO - interval training
    case audioGuided    // PRO - voice coaching (future)
    case explore        // PRO - route suggestions (future)

    var id: String { rawValue }

    /// Whether this walk type requires Pro subscription
    var isPro: Bool {
        switch self {
        case .justWalk: return false
        case .fatBurn, .audioGuided, .explore: return true
        }
    }

    /// Whether this walk type is currently available (not coming soon)
    var isAvailable: Bool {
        switch self {
        case .justWalk, .fatBurn: return true
        case .audioGuided, .explore: return false
        }
    }

    /// SF Symbol icon name
    var icon: String {
        switch self {
        case .justWalk: return "figure.walk"
        case .fatBurn: return "flame.fill"
        case .audioGuided: return "headphones"
        case .explore: return "map.fill"
        }
    }

    /// Display name
    var name: String {
        switch self {
        case .justWalk: return "Just Walk"
        case .fatBurn: return "Fat Burn Walk"
        case .audioGuided: return "Audio Guided"
        case .explore: return "Explore"
        }
    }

    /// One-line benefit description
    var benefit: String {
        switch self {
        case .justWalk: return "Hit your daily step goal"
        case .fatBurn: return "Burn more calories"
        case .audioGuided: return "Voice coaching & cues"
        case .explore: return "Discover a new route"
        }
    }

    /// Longer description for confirmation screen
    var description: String {
        switch self {
        case .justWalk: return "Walk at your pace"
        case .fatBurn: return "Intervals optimized for calorie burn"
        case .audioGuided: return "Voice cues keep you on track"
        case .explore: return "We'll suggest a route"
        }
    }

    /// Steps per minute estimate (for calculating total steps)
    var stepsPerMinute: Int {
        switch self {
        case .justWalk: return 107
        case .fatBurn: return 113  // Higher due to brisk intervals
        case .audioGuided: return 107
        case .explore: return 107
        }
    }

    /// Theme color for this walk type
    var themeColor: Color {
        switch self {
        case .justWalk: return Color(hex: "34C759")  // Green
        case .fatBurn: return Color(hex: "FF9500")   // Orange
        case .audioGuided: return Color(hex: "007AFF")  // Blue
        case .explore: return Color(hex: "AF52DE")   // Purple
        }
    }

    /// Badge text and style
    var badgeText: String {
        if !isAvailable {
            return "SOON"
        }
        return isPro ? "PRO" : "FREE"
    }

    var badgeColor: Color {
        if !isAvailable {
            return Color(hex: "8E8E93")  // Gray for coming soon
        }
        return isPro ? Color(hex: "00C7BE") : Color(hex: "34C759")
    }

    /// Estimate steps for a given duration
    func estimatedSteps(for durationMinutes: Int) -> Int {
        let rawSteps = durationMinutes * stepsPerMinute
        // Round to nearest 100
        return (rawSteps / 100) * 100
    }

    /// Format estimated steps as display string
    func formattedSteps(for durationMinutes: Int) -> String {
        let steps = estimatedSteps(for: durationMinutes)
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return "~\(formatter.string(from: NSNumber(value: steps)) ?? "\(steps)") steps"
    }
}

// MARK: - Walk Configuration

/// Configuration for a walk session based on duration and type
struct WalkConfiguration {
    let duration: TimeInterval  // Total walk time in seconds
    let walkType: WalkType

    var durationMinutes: Int {
        Int(duration / 60)
    }

    var estimatedSteps: Int {
        walkType.estimatedSteps(for: durationMinutes)
    }

    /// Generate interval phases for Fat Burn walks
    func generateFatBurnPhases() -> [IntervalPhaseInfo] {
        guard walkType == .fatBurn else { return [] }

        var phases: [IntervalPhaseInfo] = []
        let totalMinutes = durationMinutes

        // Fixed warm-up and cool-down durations
        let warmupMinutes = 2
        let cooldownMinutes = min(2, max(1, totalMinutes / 15))  // 1-2 min based on total

        // Remaining time for intervals
        let intervalTime = totalMinutes - warmupMinutes - cooldownMinutes

        // Each cycle is 6 minutes (3 brisk + 3 recovery)
        let cycleMinutes = 6
        let fullCycles = intervalTime / cycleMinutes
        let remainingMinutes = intervalTime % cycleMinutes

        // 1. Warm Up
        phases.append(IntervalPhaseInfo(
            name: "Warm Up",
            duration: TimeInterval(warmupMinutes * 60),
            color: Color(hex: "FF9500"),
            icon: "flame"
        ))

        // 2. Interval cycles
        for _ in 0..<fullCycles {
            // Brisk Walk (3 min)
            phases.append(IntervalPhaseInfo(
                name: "Brisk Walk",
                duration: 180,
                color: Color(hex: "FF3B30"),
                icon: "hare.fill"
            ))

            // Recovery Walk (3 min)
            phases.append(IntervalPhaseInfo(
                name: "Recovery Walk",
                duration: 180,
                color: Color(hex: "34C759"),
                icon: "tortoise.fill"
            ))
        }

        // Handle remaining time (if any) as one more brisk or split
        if remainingMinutes >= 3 {
            phases.append(IntervalPhaseInfo(
                name: "Brisk Walk",
                duration: TimeInterval(remainingMinutes * 60),
                color: Color(hex: "FF3B30"),
                icon: "hare.fill"
            ))
        } else if remainingMinutes > 0 {
            // Add remaining time to last recovery or as short brisk
            phases.append(IntervalPhaseInfo(
                name: "Brisk Walk",
                duration: TimeInterval(remainingMinutes * 60),
                color: Color(hex: "FF3B30"),
                icon: "hare.fill"
            ))
        }

        // 3. Cool Down
        phases.append(IntervalPhaseInfo(
            name: "Cool Down",
            duration: TimeInterval(cooldownMinutes * 60),
            color: Color(hex: "007AFF"),
            icon: "snowflake"
        ))

        return phases
    }

    /// Total duration formatted as MM:SS
    var formattedDuration: String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}
