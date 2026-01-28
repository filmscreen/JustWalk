//
//  IntervalStyle.swift
//  Just Walk
//
//  Simplified interval style presets for Power Walk.
//  Replaces complex custom intervals with three easy-to-understand options.
//

import Foundation

/// Interval timing style for Power Walk sessions
enum IntervalStyle: String, Codable, CaseIterable, Identifiable, Sendable {
    case quick      // 2:00 easy / 2:00 brisk
    case standard   // 3:00 easy / 3:00 brisk (Japanese IWT default)
    case endurance  // 3:00 easy / 2:00 brisk (more recovery time)

    var id: String { rawValue }

    // MARK: - Display Properties

    /// Human-readable name for the style
    var displayName: String {
        switch self {
        case .quick: return "Quick"
        case .standard: return "Standard"
        case .endurance: return "Endurance"
        }
    }

    /// Short description of the timing
    var description: String {
        "\(easyFormatted) / \(briskFormatted)"
    }

    /// Detailed description for UI
    var detailedDescription: String {
        switch self {
        case .quick:
            return "Faster pace changes, great for shorter walks"
        case .standard:
            return "Classic IWT protocol, balanced intervals"
        case .endurance:
            return "More recovery time, builds stamina"
        }
    }

    // MARK: - Duration Properties

    /// Easy phase duration in seconds
    var easyDuration: TimeInterval {
        switch self {
        case .quick: return 120      // 2:00
        case .standard: return 180   // 3:00
        case .endurance: return 180  // 3:00
        }
    }

    /// Brisk phase duration in seconds
    var briskDuration: TimeInterval {
        switch self {
        case .quick: return 120      // 2:00
        case .standard: return 180   // 3:00
        case .endurance: return 120  // 2:00
        }
    }

    /// Total duration of one complete cycle (easy + brisk)
    var cycleDuration: TimeInterval {
        easyDuration + briskDuration
    }

    /// Easy duration in minutes
    var easyMinutes: Int {
        Int(easyDuration / 60)
    }

    /// Brisk duration in minutes
    var briskMinutes: Int {
        Int(briskDuration / 60)
    }

    // MARK: - Formatted Strings

    /// Easy duration formatted as M:SS
    var easyFormatted: String {
        formatDuration(easyDuration)
    }

    /// Brisk duration formatted as M:SS
    var briskFormatted: String {
        formatDuration(briskDuration)
    }

    private func formatDuration(_ seconds: TimeInterval) -> String {
        let mins = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%d:%02d", mins, secs)
    }

    // MARK: - Icon

    /// SF Symbol for the style
    var icon: String {
        switch self {
        case .quick: return "bolt.fill"
        case .standard: return "star.fill"
        case .endurance: return "flame.fill"
        }
    }
}

// MARK: - Conversion to IWTConfiguration

extension IntervalStyle {
    /// Create an IWTConfiguration for a given number of cycles
    /// Note: No warmup/cooldown - simplified flow starts directly with Easy
    func configuration(cycles: Int) -> IWTConfiguration {
        IWTConfiguration(
            briskDuration: briskDuration,
            slowDuration: easyDuration,
            warmupDuration: 0,
            cooldownDuration: 0,
            totalIntervals: cycles,
            enableWarmup: false,
            enableCooldown: false
        )
    }

    /// Calculate total duration for a given number of cycles
    func totalDuration(cycles: Int) -> TimeInterval {
        TimeInterval(cycles) * cycleDuration
    }

    /// Calculate estimated steps for a given number of cycles
    /// Based on ~90 steps/min easy, ~130 steps/min brisk
    func estimatedSteps(cycles: Int) -> Int {
        let easySteps = Int(easyDuration / 60) * 90 * cycles
        let briskSteps = Int(briskDuration / 60) * 130 * cycles
        return easySteps + briskSteps
    }
}
