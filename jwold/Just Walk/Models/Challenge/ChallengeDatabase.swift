//
//  ChallengeDatabase.swift
//  Just Walk
//
//  Hardcoded challenge definitions generator.
//  Generates seasonal, weekly, and quick challenges dynamically based on current date.
//

import Foundation

/// Generates available challenges
enum ChallengeDatabase {

    // MARK: - Public API

    /// Get all currently available challenges
    static func availableChallenges(for date: Date = Date()) -> [Challenge] {
        var challenges: [Challenge] = []

        // Add seasonal (monthly) challenges
        challenges.append(contentsOf: generateSeasonalChallenges(for: date))

        // Add weekly challenges
        challenges.append(contentsOf: generateWeeklyChallenges(for: date))

        // Add quick challenges (always available)
        challenges.append(contentsOf: quickChallenges)

        return challenges
    }

    // MARK: - Seasonal Challenges

    /// Generate monthly challenges for current and next month
    private static func generateSeasonalChallenges(for date: Date) -> [Challenge] {
        let calendar = Calendar.current

        var challenges: [Challenge] = []

        // Current month
        if let currentMonth = createMonthlyChallenge(for: date, calendar: calendar) {
            challenges.append(currentMonth)
        }

        // Next month
        if let nextMonthDate = calendar.date(byAdding: .month, value: 1, to: date),
           let nextMonth = createMonthlyChallenge(for: nextMonthDate, calendar: calendar) {
            challenges.append(nextMonth)
        }

        return challenges
    }

    private static func createMonthlyChallenge(for date: Date, calendar: Calendar) -> Challenge? {
        let components = calendar.dateComponents([.year, .month], from: date)
        guard let year = components.year, let month = components.month else { return nil }

        let monthName = calendar.monthSymbols[month - 1]
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM"

        guard let startOfMonth = calendar.date(from: components),
              let endOfMonth = calendar.date(byAdding: DateComponents(month: 1, day: -1), to: startOfMonth) else {
            return nil
        }

        let daysInMonth = calendar.range(of: .day, in: .month, for: date)?.count ?? 30
        let id = "\(monthName.lowercased())_\(year)_steps"

        return Challenge(
            id: id,
            type: .seasonal,
            title: "\(monthName) Steps Challenge",
            description: "Hit your daily step goal every day in \(monthName).",
            iconName: seasonalIcon(for: month),
            dailyStepTarget: 10_000,
            targetDays: daysInMonth,
            requiredDaysPattern: .allDays,
            startDate: startOfMonth,
            endDate: calendar.date(bySettingHour: 23, minute: 59, second: 59, of: endOfMonth) ?? endOfMonth,
            durationHours: nil,
            badgeId: "seasonal_\(monthName.lowercased())_\(year)",
            difficultyLevel: 5
        )
    }

    private static func seasonalIcon(for month: Int) -> String {
        switch month {
        case 12, 1, 2:
            return "snowflake"
        case 3, 4, 5:
            return "leaf.fill"
        case 6, 7, 8:
            return "sun.max.fill"
        case 9, 10, 11:
            return "leaf.arrow.triangle.circlepath"
        default:
            return "calendar"
        }
    }

    // MARK: - Weekly Challenges

    /// Generate weekly challenges for current and next 3 weeks
    private static func generateWeeklyChallenges(for date: Date) -> [Challenge] {
        let calendar = Calendar.current
        var challenges: [Challenge] = []

        for weekOffset in 0..<4 {
            guard let weekDate = calendar.date(byAdding: .weekOfYear, value: weekOffset, to: date),
                  let challenge = createWeekendWarriorChallenge(for: weekDate, calendar: calendar) else {
                continue
            }
            challenges.append(challenge)
        }

        // Add weekday warrior for current week
        if let weekdayChallenge = createWeekdayWarriorChallenge(for: date, calendar: calendar) {
            challenges.append(weekdayChallenge)
        }

        return challenges
    }

    private static func createWeekendWarriorChallenge(for date: Date, calendar: Calendar) -> Challenge? {
        let weekOfYear = calendar.component(.weekOfYear, from: date)
        let year = calendar.component(.year, from: date)

        // Find the Saturday of this week
        guard let saturday = nextWeekend(from: date, calendar: calendar) else { return nil }
        guard let sunday = calendar.date(byAdding: .day, value: 1, to: saturday) else { return nil }
        guard let sundayEnd = calendar.date(bySettingHour: 23, minute: 59, second: 59, of: sunday) else { return nil }

        let id = "weekend_warrior_week_\(weekOfYear)_\(year)"

        return Challenge(
            id: id,
            type: .weekly,
            title: "Weekend Warrior",
            description: "Complete 12,500 steps each day this weekend (Sat & Sun).",
            iconName: "figure.run",
            dailyStepTarget: 12_500,
            targetDays: 2,
            requiredDaysPattern: .weekendsOnly,
            startDate: saturday,
            endDate: sundayEnd,
            durationHours: nil,
            badgeId: nil,
            difficultyLevel: 3
        )
    }

    private static func createWeekdayWarriorChallenge(for date: Date, calendar: Calendar) -> Challenge? {
        let weekOfYear = calendar.component(.weekOfYear, from: date)
        let year = calendar.component(.year, from: date)

        // Find Monday of this week
        guard let monday = startOfWeek(from: date, calendar: calendar) else { return nil }
        guard let friday = calendar.date(byAdding: .day, value: 4, to: monday) else { return nil }
        guard let fridayEnd = calendar.date(bySettingHour: 23, minute: 59, second: 59, of: friday) else { return nil }

        let id = "weekday_warrior_week_\(weekOfYear)_\(year)"

        return Challenge(
            id: id,
            type: .weekly,
            title: "Weekday Warrior",
            description: "Hit 10,000 steps every weekday (Mon-Fri).",
            iconName: "briefcase.fill",
            dailyStepTarget: 10_000,
            targetDays: 5,
            requiredDaysPattern: .weekdaysOnly,
            startDate: monday,
            endDate: fridayEnd,
            durationHours: nil,
            badgeId: nil,
            difficultyLevel: 3
        )
    }

    private static func nextWeekend(from date: Date, calendar: Calendar) -> Date? {
        var components = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)
        components.weekday = 7 // Saturday
        return calendar.date(from: components)
    }

    private static func startOfWeek(from date: Date, calendar: Calendar) -> Date? {
        var components = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)
        components.weekday = 2 // Monday
        return calendar.date(from: components)
    }

    // MARK: - Quick Challenges

    /// Quick challenges that are always available
    static var quickChallenges: [Challenge] {
        [
            Challenge(
                id: "speed_demon",
                type: .quick,
                title: "Speed Demon",
                description: "Complete 5,000 steps within 3 hours. Ready, set, walk!",
                iconName: "bolt.fill",
                dailyStepTarget: 5_000,
                targetDays: 1,
                requiredDaysPattern: .allDays,
                startDate: .distantPast,
                endDate: .distantFuture,
                durationHours: 3,
                badgeId: nil,
                difficultyLevel: 2
            ),
            Challenge(
                id: "morning_rush",
                type: .quick,
                title: "Morning Rush",
                description: "Get 3,000 steps before noon. Start your day strong!",
                iconName: "sunrise.fill",
                dailyStepTarget: 3_000,
                targetDays: 1,
                requiredDaysPattern: .allDays,
                startDate: .distantPast,
                endDate: .distantFuture,
                durationHours: nil, // Special handling - ends at noon
                badgeId: nil,
                difficultyLevel: 1
            ),
            Challenge(
                id: "power_hour",
                type: .quick,
                title: "Power Hour",
                description: "Walk 2,000 steps in just 1 hour. An intense burst of activity!",
                iconName: "timer",
                dailyStepTarget: 2_000,
                targetDays: 1,
                requiredDaysPattern: .allDays,
                startDate: .distantPast,
                endDate: .distantFuture,
                durationHours: 1,
                badgeId: nil,
                difficultyLevel: 2
            ),
            Challenge(
                id: "lunch_walker",
                type: .quick,
                title: "Lunch Walker",
                description: "Take 4,000 steps during your lunch break (2 hours).",
                iconName: "takeoutbag.and.cup.and.straw.fill",
                dailyStepTarget: 4_000,
                targetDays: 1,
                requiredDaysPattern: .allDays,
                startDate: .distantPast,
                endDate: .distantFuture,
                durationHours: 2,
                badgeId: nil,
                difficultyLevel: 2
            )
        ]
    }
}
