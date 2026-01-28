//
//  StreakCalendarView.swift
//  Just Walk
//
//  Calendar grid showing goal completion history for streak visualization.
//

import SwiftUI

/// A compact calendar grid showing which days the step goal was met
struct StreakCalendarView: View {
    /// Dates where the goal was met (normalized to start of day)
    let goalMetDates: Set<Date>

    /// Number of days to display (default 14)
    var daysToShow: Int = 14

    /// Number of columns in the grid
    var columns: Int = 7

    private let calendar = Calendar.current

    var body: some View {
        VStack(alignment: .leading, spacing: JWDesign.Spacing.sm) {
            // Weekday headers
            weekdayHeaders

            // Calendar grid
            calendarGrid
        }
    }

    // MARK: - Weekday Headers

    private var weekdayHeaders: some View {
        HStack(spacing: 0) {
            ForEach(shortWeekdaySymbols, id: \.self) { symbol in
                Text(symbol)
                    .font(JWDesign.Typography.caption2)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    private var shortWeekdaySymbols: [String] {
        // Get weekday symbols starting from the appropriate day based on locale
        let symbols = calendar.veryShortWeekdaySymbols
        let firstWeekday = calendar.firstWeekday - 1 // 0-indexed
        return Array(symbols[firstWeekday...]) + Array(symbols[..<firstWeekday])
    }

    // MARK: - Calendar Grid

    private var calendarGrid: some View {
        let days = generateDays()
        let rows = stride(from: 0, to: days.count, by: columns).map {
            Array(days[$0..<min($0 + columns, days.count)])
        }

        return VStack(spacing: JWDesign.Spacing.xs) {
            ForEach(rows.indices, id: \.self) { rowIndex in
                HStack(spacing: 0) {
                    ForEach(rows[rowIndex].indices, id: \.self) { dayIndex in
                        dayCell(for: rows[rowIndex][dayIndex])
                            .frame(maxWidth: .infinity)
                    }

                    // Fill remaining cells if row is incomplete
                    if rows[rowIndex].count < columns {
                        ForEach(0..<(columns - rows[rowIndex].count), id: \.self) { _ in
                            Color.clear
                                .frame(maxWidth: .infinity)
                                .aspectRatio(1, contentMode: .fit)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Day Cell

    @ViewBuilder
    private func dayCell(for day: DayInfo) -> some View {
        let isToday = calendar.isDateInToday(day.date)
        let goalMet = goalMetDates.contains(calendar.startOfDay(for: day.date))

        ZStack {
            // Background for today
            if isToday {
                Circle()
                    .stroke(JWDesign.Colors.brandPrimary, lineWidth: 2)
            }

            // Goal met indicator
            if goalMet {
                Circle()
                    .fill(JWDesign.Colors.warning.opacity(0.2))

                Image(systemName: "checkmark")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(JWDesign.Colors.warning)
            } else if day.date < Date() && !isToday {
                // Past day without goal met
                Circle()
                    .fill(Color.primary.opacity(0.05))

                Text("\(calendar.component(.day, from: day.date))")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.tertiary)
            } else {
                // Future day or today without goal
                Circle()
                    .fill(Color.primary.opacity(0.03))

                if isToday {
                    // Show bullet for today (in progress)
                    Circle()
                        .fill(JWDesign.Colors.brandPrimary.opacity(0.3))
                        .frame(width: 8, height: 8)
                }
            }
        }
        .aspectRatio(1, contentMode: .fit)
        .padding(2)
    }

    // MARK: - Helpers

    private func generateDays() -> [DayInfo] {
        let today = calendar.startOfDay(for: Date())

        // We want to show `daysToShow` days ending with today at end of row
        var days: [DayInfo] = []

        // Calculate start date
        guard let startDate = calendar.date(byAdding: .day, value: -(daysToShow - 1), to: today) else {
            return []
        }

        // Generate day infos
        for i in 0..<daysToShow {
            if let date = calendar.date(byAdding: .day, value: i, to: startDate) {
                days.append(DayInfo(date: date))
            }
        }

        return days
    }
}

// MARK: - Supporting Types

private struct DayInfo: Identifiable {
    let date: Date
    var id: Date { date }
}

// MARK: - Preview

#Preview("Streak Calendar - Some Days Met") {
    let calendar = Calendar.current
    let today = Date()

    // Simulate 7 days of streak (past 7 days met goal)
    var goalMetDates: Set<Date> = []
    for i in 0..<7 {
        if let date = calendar.date(byAdding: .day, value: -i, to: today) {
            goalMetDates.insert(calendar.startOfDay(for: date))
        }
    }
    // Skip a few days then add more
    for i in 10..<13 {
        if let date = calendar.date(byAdding: .day, value: -i, to: today) {
            goalMetDates.insert(calendar.startOfDay(for: date))
        }
    }

    return VStack {
        StreakCalendarView(goalMetDates: goalMetDates, daysToShow: 14)
            .padding()
            .background(JWDesign.Colors.secondaryBackground)
            .clipShape(RoundedRectangle(cornerRadius: JWDesign.Radius.card))
    }
    .padding()
    .background(JWDesign.Colors.background)
}

#Preview("Streak Calendar - Perfect Week") {
    let calendar = Calendar.current
    let today = Date()

    // Perfect 14-day streak
    var goalMetDates: Set<Date> = []
    for i in 0..<14 {
        if let date = calendar.date(byAdding: .day, value: -i, to: today) {
            goalMetDates.insert(calendar.startOfDay(for: date))
        }
    }

    return VStack {
        StreakCalendarView(goalMetDates: goalMetDates, daysToShow: 14)
            .padding()
            .background(JWDesign.Colors.secondaryBackground)
            .clipShape(RoundedRectangle(cornerRadius: JWDesign.Radius.card))
    }
    .padding()
    .background(JWDesign.Colors.background)
}

#Preview("Streak Calendar - Empty") {
    VStack {
        StreakCalendarView(goalMetDates: [], daysToShow: 14)
            .padding()
            .background(JWDesign.Colors.secondaryBackground)
            .clipShape(RoundedRectangle(cornerRadius: JWDesign.Radius.card))
    }
    .padding()
    .background(JWDesign.Colors.background)
}
