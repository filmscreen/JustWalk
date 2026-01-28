//
//  BarChartDataPoint.swift
//  Just Walk
//
//  Data model for bar chart visualization.
//  Used by ScrollableStepBarChart and ProgressTrendsChart.
//

import Foundation

/// Represents a single bar in a step trends bar chart
struct BarChartDataPoint: Identifiable {
    let id = UUID()
    let label: String       // "Mon", "15", "W12", "Mar"
    let steps: Int          // Total or average steps
    let goalMet: Bool       // For bar color (teal vs gray)
    let isHighlighted: Bool // Today/current period highlight
    let date: Date          // For sorting and identification
}

// MARK: - Aggregation Helpers

extension BarChartDataPoint {

    /// Create daily bar chart data from DayStepData array
    /// - Parameters:
    ///   - data: Array of daily step data
    ///   - period: The display period (affects label formatting)
    /// - Returns: Array of BarChartDataPoint sorted oldest first
    static func dailyData(from data: [DayStepData], period: ProgressPeriod) -> [BarChartDataPoint] {
        let calendar = Calendar.current

        // Sort oldest first for proper chart display
        let sortedData = data.sorted { $0.date < $1.date }

        return sortedData.map { day in
            let isToday = calendar.isDateInToday(day.date)

            // Format label based on period
            let label: String
            switch period {
            case .week:
                let formatter = DateFormatter()
                formatter.dateFormat = "EEE"
                label = formatter.string(from: day.date)
            case .month:
                label = "\(calendar.component(.day, from: day.date))"
            default:
                label = day.shortDate
            }

            return BarChartDataPoint(
                label: label,
                steps: day.steps,
                goalMet: day.isGoalMet,
                isHighlighted: isToday,
                date: day.date
            )
        }
    }

    /// Create weekly aggregated bar chart data (for Year view)
    /// Groups daily data by ISO week and calculates weekly averages
    /// - Parameters:
    ///   - data: Array of daily step data
    ///   - goal: Daily step goal for determining goal met status
    /// - Returns: Array of BarChartDataPoint with weekly averages, sorted oldest first
    static func weeklyAggregated(from data: [DayStepData], goal: Int) -> [BarChartDataPoint] {
        let calendar = Calendar.current

        // Group days by ISO week and year
        var weekDict: [String: (days: [DayStepData], weekStart: Date)] = [:]

        for day in data {
            let weekOfYear = calendar.component(.weekOfYear, from: day.date)
            let year = calendar.component(.yearForWeekOfYear, from: day.date)
            let key = "\(year)-W\(weekOfYear)"

            // Calculate the start of this week for sorting
            if weekDict[key] == nil {
                var components = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: day.date)
                components.weekday = calendar.firstWeekday
                let weekStart = calendar.date(from: components) ?? day.date
                weekDict[key] = (days: [], weekStart: weekStart)
            }

            weekDict[key]?.days.append(day)
        }

        // Convert to BarChartDataPoints
        let currentWeek = calendar.component(.weekOfYear, from: Date())
        let currentYear = calendar.component(.yearForWeekOfYear, from: Date())

        let result = weekDict.map { key, value -> BarChartDataPoint in
            let totalSteps = value.days.reduce(0) { $0 + $1.steps }
            let avgSteps = value.days.isEmpty ? 0 : totalSteps / value.days.count
            let goalMetDays = value.days.filter { $0.isGoalMet }.count
            let goalMet = goalMetDays >= 4 // Majority of week (4+ days)

            // Extract week number for label
            let weekNum = calendar.component(.weekOfYear, from: value.weekStart)
            let year = calendar.component(.yearForWeekOfYear, from: value.weekStart)
            let isCurrentWeek = weekNum == currentWeek && year == currentYear

            return BarChartDataPoint(
                label: "W\(weekNum)",
                steps: avgSteps,
                goalMet: goalMet,
                isHighlighted: isCurrentWeek,
                date: value.weekStart
            )
        }
        .sorted { $0.date < $1.date } // Oldest first

        return result
    }

    /// Create monthly aggregated bar chart data (for All Time view)
    /// Groups daily data by month and calculates monthly averages
    /// - Parameters:
    ///   - data: Array of daily step data
    ///   - goal: Daily step goal for determining goal met status
    /// - Returns: Array of BarChartDataPoint with monthly averages, sorted oldest first
    static func monthlyAggregated(from data: [DayStepData], goal: Int) -> [BarChartDataPoint] {
        let calendar = Calendar.current

        // Group days by month and year
        var monthDict: [DateComponents: [DayStepData]] = [:]

        for day in data {
            let components = calendar.dateComponents([.year, .month], from: day.date)
            if monthDict[components] == nil {
                monthDict[components] = []
            }
            monthDict[components]?.append(day)
        }

        // Convert to BarChartDataPoints
        let currentMonth = calendar.component(.month, from: Date())
        let currentYear = calendar.component(.year, from: Date())

        let formatter = DateFormatter()
        formatter.dateFormat = "MMM"

        let result = monthDict.compactMap { components, days -> BarChartDataPoint? in
            guard let monthDate = calendar.date(from: components) else { return nil }

            let totalSteps = days.reduce(0) { $0 + $1.steps }
            let avgSteps = days.isEmpty ? 0 : totalSteps / days.count
            let goalMetDays = days.filter { $0.isGoalMet }.count
            // For monthly: goal met if majority of tracked days met goal
            let goalMet = days.count > 0 && (Double(goalMetDays) / Double(days.count)) >= 0.5

            let isCurrentMonth = components.month == currentMonth && components.year == currentYear

            return BarChartDataPoint(
                label: formatter.string(from: monthDate),
                steps: avgSteps,
                goalMet: goalMet,
                isHighlighted: isCurrentMonth,
                date: monthDate
            )
        }
        .sorted { $0.date < $1.date } // Oldest first

        return result
    }
}
