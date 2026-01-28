//
//  StepFormatter.swift
//  Just Walk (Apple Watch) Watch App
//
//  Shared formatting utilities for step display on Apple Watch.
//  Mirrors FormatUtils step methods from iOS for consistency.
//

import Foundation

/// Shared formatting utilities for the Watch app
struct StepFormatter {

    // MARK: - Step Formatting

    private static let stepNumberFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.groupingSeparator = ","
        return formatter
    }()

    /// Format steps with comma separators (e.g., 8200 → "8,200")
    static func formatSteps(_ steps: Int) -> String {
        stepNumberFormatter.string(from: NSNumber(value: steps)) ?? "\(steps)"
    }

    /// Format steps abbreviated for tight spaces (e.g., 8200 → "8.2k")
    static func formatStepsAbbreviated(_ steps: Int) -> String {
        switch steps {
        case 0..<1000:
            return "\(steps)"
        case 1000..<10000:
            let k = Double(steps) / 1000.0
            return String(format: "%.1fk", k)
        case 10000..<100000:
            let k = steps / 1000
            return "\(k)k"
        default:
            let k = steps / 1000
            return "\(k)k"
        }
    }

    /// Format remaining steps (e.g., 1800 → "1,800 to go", 0 → "Goal hit!")
    static func formatRemaining(_ steps: Int) -> String {
        if steps <= 0 {
            return "Goal hit!"
        }
        return "\(formatSteps(steps)) to go"
    }

    /// Format bonus steps (e.g., 247 → "+247 bonus steps")
    static func formatBonus(_ steps: Int) -> String {
        "+\(formatSteps(steps)) bonus steps"
    }

    /// Format bonus steps short (e.g., 247 → "+247 bonus")
    static func formatBonusShort(_ steps: Int) -> String {
        "+\(formatSteps(steps)) bonus"
    }

    // MARK: - Calorie Formatting

    /// Format calories as whole number (e.g., 287 → "287 cal")
    static func formatCalories(_ calories: Int) -> String {
        "\(calories) cal"
    }

    // MARK: - Distance Formatting

    /// Format distance in miles with one decimal (e.g., 3.847 → "3.8 mi")
    /// @deprecated Use formatDistance(_ meters:) instead for unit-aware formatting
    static func formatDistanceMiles(_ miles: Double) -> String {
        String(format: "%.1f mi", miles)
    }

    /// Format distance in meters using user's preferred unit
    static func formatDistance(_ meters: Double) -> String {
        WatchDistanceUnit.formatDistance(meters)
    }

    /// Format distance in meters with short format using user's preferred unit
    static func formatDistanceShort(_ meters: Double) -> String {
        WatchDistanceUnit.formatDistanceShort(meters)
    }

    // MARK: - Combined Stats Formatting

    /// Format distance and calories combined (e.g., "🚶 3.8 mi · 🔥 287 cal")
    /// Returns nil if neither value is available
    /// @deprecated Use formatDistanceAndCaloriesWithMeters instead for unit-aware formatting
    static func formatDistanceAndCalories(distanceMiles: Double?, calories: Int?) -> String? {
        let hasDistance = distanceMiles != nil && distanceMiles! > 0
        let hasCalories = calories != nil && calories! > 0

        switch (hasDistance, hasCalories) {
        case (true, true):
            return "🚶 \(formatDistanceMiles(distanceMiles!)) · 🔥 \(formatCalories(calories!))"
        case (true, false):
            return "🚶 \(formatDistanceMiles(distanceMiles!))"
        case (false, true):
            return "🔥 \(formatCalories(calories!))"
        case (false, false):
            return nil
        }
    }

    /// Format distance (in meters) and calories combined using user's preferred unit
    /// Returns nil if neither value is available
    static func formatDistanceAndCaloriesWithMeters(distanceMeters: Double?, calories: Int?) -> String? {
        let hasDistance = distanceMeters != nil && distanceMeters! > 0
        let hasCalories = calories != nil && calories! > 0

        switch (hasDistance, hasCalories) {
        case (true, true):
            return "🚶 \(formatDistanceShort(distanceMeters!)) · 🔥 \(formatCalories(calories!))"
        case (true, false):
            return "🚶 \(formatDistanceShort(distanceMeters!))"
        case (false, true):
            return "🔥 \(formatCalories(calories!))"
        case (false, false):
            return nil
        }
    }
}

// MARK: - Convenience Extensions

extension Int {
    /// Format this step count with commas (e.g., 8200 → "8,200")
    var formattedSteps: String {
        StepFormatter.formatSteps(self)
    }

    /// Format this step count abbreviated (e.g., 8200 → "8.2k")
    var formattedStepsAbbreviated: String {
        StepFormatter.formatStepsAbbreviated(self)
    }

    /// Format as remaining steps (e.g., 1800 → "1,800 to go")
    var formattedRemaining: String {
        StepFormatter.formatRemaining(self)
    }

    /// Format as bonus steps (e.g., 247 → "+247 bonus steps")
    var formattedBonus: String {
        StepFormatter.formatBonus(self)
    }

    /// Format as calories (e.g., 287 → "287 cal")
    var formattedCalories: String {
        StepFormatter.formatCalories(self)
    }
}
