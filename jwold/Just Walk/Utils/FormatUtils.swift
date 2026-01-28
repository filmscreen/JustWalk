//
//  FormatUtils.swift
//  Just Walk
//
//  Created by Randy Chia on 1/8/26.
//

import Foundation

/// Shared formatting utilities for the app
struct FormatUtils {

    // MARK: - Unit Preference

    /// Get the user's preferred distance unit
    static var preferredUnit: DistanceUnit {
        guard let rawValue = UserDefaults.standard.string(forKey: "preferredDistanceUnit"),
              let unit = DistanceUnit(rawValue: rawValue) else {
            return .miles
        }
        return unit
    }

    // MARK: - Distance Formatting

    /// Format distance in meters to human-readable string using preferred unit
    static func formatDistance(_ meters: Double) -> String {
        let unit = preferredUnit
        let value = meters * unit.conversionFromMeters
        return String(format: "%.2f %@", value, unit.abbreviation)
    }

    // MARK: - Duration Formatting

    /// Format time interval to MM:SS format
    static func formatDuration(_ seconds: TimeInterval) -> String {
        let minutes = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%02d:%02d", minutes, secs)
    }

    /// Format time interval to HH:MM:SS or MM:SS format
    static func formatDurationLong(_ seconds: TimeInterval) -> String {
        let hours = Int(seconds) / 3600
        let minutes = (Int(seconds) % 3600) / 60
        let secs = Int(seconds) % 60

        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, secs)
        } else {
            return String(format: "%02d:%02d", minutes, secs)
        }
    }

    /// Format time interval to human-readable string (e.g., "2h 15m", "45m")
    static func formatDurationHumanReadable(_ seconds: TimeInterval) -> String {
        let hours = Int(seconds) / 3600
        let minutes = (Int(seconds) % 3600) / 60

        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }

    // MARK: - Pace Formatting

    /// Format pace in seconds per meter to min/unit string using preferred unit
    static func formatPace(_ secondsPerMeter: Double) -> String {
        guard secondsPerMeter > 0 else { return "--:--" }

        let unit = preferredUnit
        let secondsPerUnit = secondsPerMeter * unit.metersPerUnit
        let minutesPerUnit = secondsPerUnit / 60

        let minutes = Int(minutesPerUnit)
        let seconds = Int((minutesPerUnit - Double(minutes)) * 60)

        return String(format: "%d:%02d /%@", minutes, seconds, unit.abbreviation)
    }

    // MARK: - Number Formatting

    /// Format large numbers with K/M suffix (e.g., 1.5K, 2.3M)
    static func formatLargeNumber(_ number: Int) -> String {
        if number >= 1_000_000 {
            return String(format: "%.1fM", Double(number) / 1_000_000)
        } else if number >= 1000 {
            return String(format: "%.1fK", Double(number) / 1000)
        }
        return number.formatted()
    }

    /// Format steps axis for charts (e.g., 1K, 2K, 5K, 10K)
    static func formatStepsAxis(_ steps: Int) -> String {
        if steps >= 1000 {
            return "\(steps / 1000)K"
        }
        return "\(steps)"
    }

    // MARK: - Percentage Formatting

    /// Format progress as percentage (0.0 to 1.0 → "75%")
    static func formatPercentage(_ progress: Double) -> String {
        String(format: "%.0f%%", progress * 100)
    }

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

    // MARK: - Calorie Formatting

    /// Format calories as whole number (e.g., 287 → "287 cal")
    static func formatCalories(_ calories: Int) -> String {
        "\(calories) cal"
    }

    // MARK: - Distance in Miles Formatting

    /// Format distance in miles with one decimal (e.g., 3.847 → "3.8 mi")
    static func formatDistanceMiles(_ miles: Double) -> String {
        String(format: "%.1f mi", miles)
    }

    /// Format distance value (in miles) using preferred unit
    static func formatDistanceInPreferredUnit(_ valueInMiles: Double) -> String {
        let unit = preferredUnit
        if unit == .kilometers {
            let km = valueInMiles * 1.60934
            return String(format: "%.1f km", km)
        }
        return String(format: "%.1f mi", valueInMiles)
    }

    // MARK: - Combined Stats Formatting

    /// Format distance and calories combined (e.g., "🚶 3.8 mi · 🔥 287 cal")
    /// Returns nil if neither value is available
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
}

// MARK: - Convenience Extensions

extension Double {
    /// Format this distance value in meters
    var formattedDistance: String {
        FormatUtils.formatDistance(self)
    }

    /// Format this time interval
    var formattedDuration: String {
        FormatUtils.formatDuration(self)
    }

    /// Format this time interval (long format with hours)
    var formattedDurationLong: String {
        FormatUtils.formatDurationLong(self)
    }

    /// Format this pace value (seconds per meter)
    var formattedPace: String {
        FormatUtils.formatPace(self)
    }
}

extension Int {
    /// Format this number with K/M suffix
    var formattedLarge: String {
        FormatUtils.formatLargeNumber(self)
    }

    /// Format this step count with commas (e.g., 8200 → "8,200")
    var formattedSteps: String {
        FormatUtils.formatSteps(self)
    }

    /// Format this step count abbreviated (e.g., 8200 → "8.2k")
    var formattedStepsAbbreviated: String {
        FormatUtils.formatStepsAbbreviated(self)
    }

    /// Format as remaining steps (e.g., 1800 → "1,800 to go")
    var formattedRemaining: String {
        FormatUtils.formatRemaining(self)
    }

    /// Format as bonus steps (e.g., 247 → "+247 bonus steps")
    var formattedBonus: String {
        FormatUtils.formatBonus(self)
    }

    /// Format as calories (e.g., 287 → "287 cal")
    var formattedCalories: String {
        FormatUtils.formatCalories(self)
    }
}

extension TimeInterval {
    /// Format as MM:SS
    var formatted: String {
        FormatUtils.formatDuration(self)
    }

    /// Format as HH:MM:SS or MM:SS
    var formattedLong: String {
        FormatUtils.formatDurationLong(self)
    }

    /// Format as human-readable (e.g., "2h 15m")
    var formattedHumanReadable: String {
        FormatUtils.formatDurationHumanReadable(self)
    }
}
