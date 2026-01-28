//
//  ProgressTrendsChart.swift
//  Just Walk
//
//  Scrollable bar chart showing step trends over the selected period.
//  Adapts aggregation level based on timeframe:
//  - Week: Daily bars (7)
//  - Month: Daily bars (30), scrollable
//  - Year: Weekly averages (52), scrollable
//  - All Time: Monthly averages, scrollable
//

import SwiftUI

struct ProgressTrendsChart: View {
    let data: [DayStepData]
    let dailyGoal: Int
    let period: ProgressPeriod

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            Text("Step Trends")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(.primary)

            // Bar chart
            ScrollableStepBarChart(
                data: chartData,
                dailyGoal: dailyGoal,
                period: period
            )
            .frame(height: 170) // Bar height (120) + labels (50)
        }
        .padding(16)
        .background(JWDesign.Colors.secondaryBackground)
        .clipShape(RoundedRectangle(cornerRadius: JWDesign.Radius.card))
    }

    // MARK: - Chart Data Based on Period

    private var chartData: [BarChartDataPoint] {
        switch period {
        case .week:
            // Daily bars for 7 days
            return BarChartDataPoint.dailyData(from: data, period: .week)

        case .month:
            // Daily bars for 30 days (scrollable)
            return BarChartDataPoint.dailyData(from: data, period: .month)

        case .year:
            // Weekly averages (52 weeks, scrollable)
            return BarChartDataPoint.weeklyAggregated(from: data, goal: dailyGoal)

        case .allTime:
            // Monthly averages (scrollable)
            return BarChartDataPoint.monthlyAggregated(from: data, goal: dailyGoal)
        }
    }
}

// MARK: - Preview

#Preview("Week Data") {
    let calendar = Calendar.current
    let today = Date()

    let sampleData: [DayStepData] = (0..<7).map { dayOffset in
        let date = calendar.date(byAdding: .day, value: -dayOffset, to: today)!
        let steps = Int.random(in: 5000...15000)
        return DayStepData(date: date, steps: steps, distance: Double(steps) * 0.762, historicalGoal: 10000)
    }

    return ScrollView {
        ProgressTrendsChart(
            data: sampleData,
            dailyGoal: 10000,
            period: .week
        )
        .padding()
    }
    .background(Color(.systemGroupedBackground))
}

#Preview("Month Data") {
    let calendar = Calendar.current
    let today = Date()

    let sampleData: [DayStepData] = (0..<30).map { dayOffset in
        let date = calendar.date(byAdding: .day, value: -dayOffset, to: today)!
        let steps = Int.random(in: 4000...16000)
        return DayStepData(date: date, steps: steps, distance: Double(steps) * 0.762, historicalGoal: 10000)
    }

    return ScrollView {
        ProgressTrendsChart(
            data: sampleData,
            dailyGoal: 10000,
            period: .month
        )
        .padding()
    }
    .background(Color(.systemGroupedBackground))
}

#Preview("Year Data") {
    let calendar = Calendar.current
    let today = Date()

    let sampleData: [DayStepData] = (0..<365).map { dayOffset in
        let date = calendar.date(byAdding: .day, value: -dayOffset, to: today)!
        let steps = Int.random(in: 3000...18000)
        return DayStepData(date: date, steps: steps, distance: Double(steps) * 0.762, historicalGoal: 10000)
    }

    return ScrollView {
        ProgressTrendsChart(
            data: sampleData,
            dailyGoal: 10000,
            period: .year
        )
        .padding()
    }
    .background(Color(.systemGroupedBackground))
}

#Preview("All Time Data") {
    let calendar = Calendar.current
    let today = Date()

    let sampleData: [DayStepData] = (0..<500).map { dayOffset in
        let date = calendar.date(byAdding: .day, value: -dayOffset, to: today)!
        let steps = Int.random(in: 2000...20000)
        return DayStepData(date: date, steps: steps, distance: Double(steps) * 0.762, historicalGoal: 10000)
    }

    return ScrollView {
        ProgressTrendsChart(
            data: sampleData,
            dailyGoal: 10000,
            period: .allTime
        )
        .padding()
    }
    .background(Color(.systemGroupedBackground))
}
