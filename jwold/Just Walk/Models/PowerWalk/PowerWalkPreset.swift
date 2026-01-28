//
//  PowerWalkPreset.swift
//  Just Walk
//
//  Predefined interval configurations based on IWT research.
//  Four presets covering different user needs and fitness levels.
//

import Foundation

/// Predefined interval configurations based on IWT research
struct PowerWalkPreset: Identifiable, Codable, Equatable, Sendable {
    let id: String
    let name: String
    let description: String
    let easyDuration: TimeInterval      // seconds
    let briskDuration: TimeInterval     // seconds
    let icon: String

    // MARK: - Computed Properties

    /// Duration of one complete cycle (easy + brisk)
    var cycleDuration: TimeInterval {
        easyDuration + briskDuration
    }

    /// Format: "3:00 / 3:00"
    var formattedDurations: String {
        let easyFormatted = formatDuration(easyDuration)
        let briskFormatted = formatDuration(briskDuration)
        return "\(easyFormatted) / \(briskFormatted)"
    }

    /// Easy duration in minutes (for display)
    var easyMinutes: Int {
        Int(easyDuration / 60)
    }

    /// Brisk duration in minutes (for display)
    var briskMinutes: Int {
        Int(briskDuration / 60)
    }

    /// Short description for compact UI
    var shortDescription: String {
        "\(easyMinutes) min easy, \(briskMinutes) min brisk"
    }

    // MARK: - Helpers

    private func formatDuration(_ seconds: TimeInterval) -> String {
        let minutes = Int(seconds) / 60
        let secs = Int(seconds) % 60
        if secs == 0 {
            return "\(minutes):00"
        } else {
            return String(format: "%d:%02d", minutes, secs)
        }
    }
}

// MARK: - Predefined Presets

extension PowerWalkPreset {
    /// Japanese Standard: Original IWT protocol (3 min each)
    /// Based on research by Dr. Hiroshi Nose at Shinshu University
    static let japaneseStandard = PowerWalkPreset(
        id: "japanese_standard",
        name: "Japanese Standard",
        description: "Original IWT protocol. 3 min easy, 3 min brisk.",
        easyDuration: 180,
        briskDuration: 180,
        icon: "star.fill"
    )

    /// Quick Intervals: Faster transitions (2 min each)
    /// Good for time-constrained workouts
    static let quickIntervals = PowerWalkPreset(
        id: "quick_intervals",
        name: "Quick Intervals",
        description: "Faster pace changes. 2 min easy, 2 min brisk.",
        easyDuration: 120,
        briskDuration: 120,
        icon: "bolt.fill"
    )

    /// Beginner Friendly: Longer recovery (3 min easy, 2 min brisk)
    /// Extra recovery time for those just starting out
    static let beginnerFriendly = PowerWalkPreset(
        id: "beginner_friendly",
        name: "Beginner Friendly",
        description: "Extra recovery time. 3 min easy, 2 min brisk.",
        easyDuration: 180,
        briskDuration: 120,
        icon: "leaf.fill"
    )

    /// Endurance: Longer easy phases (4 min easy, 2 min brisk)
    /// Build stamina with longer recovery periods
    static let endurance = PowerWalkPreset(
        id: "endurance",
        name: "Endurance",
        description: "Build stamina. 4 min easy, 2 min brisk.",
        easyDuration: 240,
        briskDuration: 120,
        icon: "flame.fill"
    )

    /// All built-in presets
    static let allPresets: [PowerWalkPreset] = [
        .japaneseStandard,
        .quickIntervals,
        .beginnerFriendly,
        .endurance
    ]

    /// Default preset (Japanese Standard)
    static let `default` = japaneseStandard

    /// Find preset by ID
    static func preset(forId id: String) -> PowerWalkPreset? {
        allPresets.first { $0.id == id }
    }
}

// MARK: - Custom Preset Creation

extension PowerWalkPreset {
    /// Create a custom preset with user-defined durations (minute precision)
    /// - Parameters:
    ///   - name: Display name for the preset
    ///   - easyMinutes: Easy phase duration in minutes
    ///   - briskMinutes: Brisk phase duration in minutes
    /// - Returns: A new custom PowerWalkPreset
    static func custom(
        name: String,
        easyMinutes: Int,
        briskMinutes: Int
    ) -> PowerWalkPreset {
        PowerWalkPreset(
            id: "custom_\(UUID().uuidString.prefix(8))",
            name: name,
            description: "\(easyMinutes) min easy, \(briskMinutes) min brisk",
            easyDuration: TimeInterval(easyMinutes * 60),
            briskDuration: TimeInterval(briskMinutes * 60),
            icon: "slider.horizontal.3"
        )
    }

    /// Create a custom preset with 30-second precision
    /// Used by the Custom Interval Editor for Pro users
    /// - Parameters:
    ///   - name: Display name for the preset
    ///   - easySeconds: Easy phase duration in seconds (60-300, 30-sec increments)
    ///   - briskSeconds: Brisk phase duration in seconds (60-300, 30-sec increments)
    /// - Returns: A new custom PowerWalkPreset
    static func customWithSeconds(
        name: String,
        easySeconds: TimeInterval,
        briskSeconds: TimeInterval
    ) -> PowerWalkPreset {
        // Format description with M:SS format for non-whole minutes
        let easyDesc = formatSecondsDescription(easySeconds)
        let briskDesc = formatSecondsDescription(briskSeconds)

        return PowerWalkPreset(
            id: "custom_\(UUID().uuidString.prefix(8))",
            name: name,
            description: "\(easyDesc) easy, \(briskDesc) brisk",
            easyDuration: easySeconds,
            briskDuration: briskSeconds,
            icon: "slider.horizontal.3"
        )
    }

    /// Format seconds for description (e.g., "3:00" or "2:30")
    private static func formatSecondsDescription(_ seconds: TimeInterval) -> String {
        let mins = Int(seconds) / 60
        let secs = Int(seconds) % 60
        if secs == 0 {
            return "\(mins) min"
        } else {
            return String(format: "%d:%02d", mins, secs)
        }
    }
}
