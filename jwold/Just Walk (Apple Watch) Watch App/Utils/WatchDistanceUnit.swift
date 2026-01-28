//
//  WatchDistanceUnit.swift
//  Just Walk (Apple Watch) Watch App
//
//  Distance unit preference for miles/kilometers display.
//  Synced from iPhone via App Group.
//

import Foundation

enum WatchDistanceUnit: String, CaseIterable {
    case miles = "Miles"
    case kilometers = "Kilometers"

    var abbreviation: String {
        switch self {
        case .miles: return "mi"
        case .kilometers: return "km"
        }
    }

    var conversionFromMeters: Double {
        switch self {
        case .miles: return 0.000621371
        case .kilometers: return 0.001
        }
    }

    var metersPerUnit: Double {
        switch self {
        case .miles: return 1609.34
        case .kilometers: return 1000.0
        }
    }

    /// Get the user's preferred distance unit (synced from iPhone via App Group)
    static var preferred: WatchDistanceUnit {
        let sharedDefaults = UserDefaults(suiteName: "group.com.onworldtech.JustWalk")
        guard let raw = sharedDefaults?.string(forKey: "preferredDistanceUnit"),
              let unit = WatchDistanceUnit(rawValue: raw) else {
            return .miles
        }
        return unit
    }

    // MARK: - Formatting Helpers

    /// Format distance in meters to human-readable string using preferred unit
    static func formatDistance(_ meters: Double) -> String {
        let unit = preferred
        let value = meters * unit.conversionFromMeters
        return String(format: "%.2f %@", value, unit.abbreviation)
    }

    /// Format distance in meters with one decimal place
    static func formatDistanceShort(_ meters: Double) -> String {
        let unit = preferred
        let value = meters * unit.conversionFromMeters
        return String(format: "%.1f %@", value, unit.abbreviation)
    }

    /// Convert meters to the preferred unit value (without formatting)
    static func convertMeters(_ meters: Double) -> Double {
        return meters * preferred.conversionFromMeters
    }

    /// Format pace in seconds per meter to min/unit string using preferred unit
    static func formatPace(_ secondsPerMeter: Double) -> String {
        guard secondsPerMeter > 0 else { return "--:--" }

        let unit = preferred
        let secondsPerUnit = secondsPerMeter * unit.metersPerUnit
        let minutesPerUnit = secondsPerUnit / 60

        let minutes = Int(minutesPerUnit)
        let seconds = Int((minutesPerUnit - Double(minutes)) * 60)

        return String(format: "%d:%02d /%@", minutes, seconds, unit.abbreviation)
    }
}
