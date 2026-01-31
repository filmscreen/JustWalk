//
//  PatternCopy.swift
//  JustWalk
//
//  Centralized copy library for pattern-aware personalization
//  "The app gets me."
//

import Foundation

enum PatternCopy {

    // MARK: - Insight Cards

    static func timingInsight(hour: Int) -> (primary: String, secondary: String) {
        let timeString = formatHourNaturally(hour)
        return (
            "\(timeString) is your time.",
            "That's when you walk most."
        )
    }

    static func bestDayInsight(day: Int, rate: Int) -> (primary: String, secondary: String) {
        let dayName = dayOfWeekName(day)
        return (
            "\(dayName)s are your day.",
            "You hit your goal \(rate)% of the time."
        )
    }

    static func hardestDayInsight(day: Int) -> (primary: String, secondary: String) {
        let dayName = dayOfWeekName(day)
        return (
            "\(dayName)s are tough.",
            "But you've got this one."
        )
    }

    static func preferenceInsight(type: String, count: Int, total: Int) -> (primary: String, secondary: String) {
        let typeName = walkTypeDisplayName(type)
        return (
            "\(typeName) are your thing.",
            "\(count) of your last \(total) walks."
        )
    }

    static func trendInsight(percentChange: Int) -> (primary: String, secondary: String) {
        return (
            "You're walking more.",
            "\(percentChange)% more this month than last."
        )
    }

    static func consistencyInsight(day: Int, weeks: Int) -> (primary: String, secondary: String) {
        let dayName = dayOfWeekName(day)
        return (
            "You've never missed a \(dayName).",
            "\(weeks) weeks straight."
        )
    }

    static func hardestDayConquered(day: Int) -> (primary: String, secondary: String) {
        let dayName = dayOfWeekName(day)
        return (
            "\(dayName). Your toughest day.",
            "Not today."
        )
    }

    // MARK: - Headlines

    static let nearTypicalTime = "Almost your time."

    static func hardestDayConqueredHeadline(_ day: Int) -> String {
        "\(dayOfWeekName(day)), conquered."
    }

    static func hardestDayEncouragement(_ day: Int) -> String {
        "\(dayOfWeekName(day))s are tough. You've got this."
    }

    static let bestDay = "Your best day."

    // MARK: - Smart Walk Card

    static func patternBasedCard(type: String) -> (primary: String, secondary: String) {
        let typeName = walkTypeDisplayName(type)
        return (
            "\(typeName)? You usually go around now.",
            ""
        )
    }

    static func preferredTypeCard(type: String) -> (primary: String, secondary: String) {
        let typeName = walkTypeDisplayName(type)
        return (
            "\(typeName)?",
            "Your go-to."
        )
    }

    static func hardestDayCard(day: Int) -> (primary: String, secondary: String) {
        let dayName = dayOfWeekName(day)
        return (
            "Quick walk?",
            "\(dayName)s are easier when you start early."
        )
    }

    // MARK: - Notifications

    static func patternTimeNotification(hour: Int) -> (title: String, body: String) {
        let timeString = formatHourNaturally(hour)
        return (
            "Almost \(timeString).",
            "Your usual time. Ready?"
        )
    }

    static func preferredTypeNotification(type: String, duration: Int) -> (title: String, body: String) {
        let typeName = walkTypeDisplayName(type)
        return (
            "Quick \(typeName)?",
            "\(duration) minutes. Your favorite."
        )
    }

    static func hardestDayNotification(day: Int) -> (title: String, body: String) {
        let dayName = dayOfWeekName(day)
        return (
            "It's \(dayName).",
            "A quick walk makes it easier."
        )
    }

    // MARK: - Helpers

    static func dayOfWeekName(_ weekday: Int) -> String {
        // 0 = Sunday, 1 = Monday, etc.
        switch weekday {
        case 0: return "Sunday"
        case 1: return "Monday"
        case 2: return "Tuesday"
        case 3: return "Wednesday"
        case 4: return "Thursday"
        case 5: return "Friday"
        case 6: return "Saturday"
        default: return "day"
        }
    }

    static func formatHourNaturally(_ hour: Int) -> String {
        switch hour {
        case 6: return "6am"
        case 7: return "7am"
        case 8: return "8am"
        case 9: return "9am"
        case 10: return "10am"
        case 11: return "11am"
        case 12: return "noon"
        case 13: return "1pm"
        case 14: return "2pm"
        case 15: return "3pm"
        case 16: return "4pm"
        case 17: return "5pm"
        case 18: return "6pm"
        case 19: return "7pm"
        case 20: return "8pm"
        case 21: return "9pm"
        default: return "\(hour > 12 ? hour - 12 : hour)\(hour >= 12 ? "pm" : "am")"
        }
    }

    static func walkTypeDisplayName(_ type: String) -> String {
        switch type {
        case "intervals": return "Intervals"
        case "fatBurn": return "Fat Burn"
        case "postMeal": return "Post-Meal"
        default: return "Walk"
        }
    }
}
