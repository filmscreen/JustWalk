//
//  ScrollableStepBarChart.swift
//  Just Walk
//
//  Scrollable bar chart for step trends. Adapts aggregation based on period:
//  - Week: Daily bars (7), no scrolling
//  - Month: Daily bars (30), scrollable
//  - Year: Weekly averages (52), scrollable
//  - All Time: Monthly averages, scrollable
//

import SwiftUI

// MARK: - Scrollable Bar Chart

struct ScrollableStepBarChart: View {
    let data: [BarChartDataPoint]
    let dailyGoal: Int
    let period: ProgressPeriod

    // Layout constants matching MiniWeekChart style
    private let barWidth: CGFloat = 28
    private let barSpacing: CGFloat = 8
    private let maxBarHeight: CGFloat = 120
    private let minBarHeight: CGFloat = 4

    // Whether this period should scroll
    private var isScrollable: Bool {
        data.count > 7
    }

    var body: some View {
        Group {
            if data.isEmpty {
                Text("No data")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                GeometryReader { geometry in
                    if isScrollable {
                        scrollableContent
                    } else {
                        nonScrollableContent(availableWidth: geometry.size.width)
                    }
                }
            }
        }
        .frame(height: maxBarHeight + 50) // Bar height + labels
    }

    // MARK: - Scrollable Content

    private var scrollableContent: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .bottom, spacing: barSpacing) {
                    ForEach(data) { point in
                        BarView(
                            point: point,
                            barWidth: barWidth,
                            barHeight: barHeight(for: point.steps),
                            dailyGoal: dailyGoal
                        )
                        .id(point.id)
                    }
                }
                .padding(.horizontal, 4)
            }
            .onAppear {
                // Scroll to most recent (last item) on appear - no animation to avoid jitter
                if let last = data.last {
                    proxy.scrollTo(last.id, anchor: .trailing)
                }
            }
        }
    }

    // MARK: - Non-Scrollable Content (Week view - 7 bars fit)

    private func nonScrollableContent(availableWidth: CGFloat) -> some View {
        HStack(alignment: .bottom, spacing: barSpacing) {
            ForEach(data) { point in
                BarView(
                    point: point,
                    barWidth: barWidth,
                    barHeight: barHeight(for: point.steps),
                    dailyGoal: dailyGoal
                )
                .frame(maxWidth: .infinity)
            }
        }
    }

    // MARK: - Bar Height Calculation

    private func barHeight(for steps: Int) -> CGFloat {
        guard steps > 0 else { return minBarHeight }
        guard dailyGoal > 0 else { return minBarHeight }
        let ratio = CGFloat(steps) / CGFloat(dailyGoal)
        return min(maxBarHeight, max(minBarHeight, ratio * maxBarHeight))
    }
}

// MARK: - Individual Bar View

private struct BarView: View {
    let point: BarChartDataPoint
    let barWidth: CGFloat
    let barHeight: CGFloat
    let dailyGoal: Int

    // Animation suppression (for initial load)
    @Environment(\.suppressAnimations) private var suppressAnimations

    var body: some View {
        VStack(spacing: 4) {
            // Step count label (hide if 0 steps)
            if point.steps > 0 {
                Text(formatStepCount(point.steps))
                    .font(.system(size: 11, weight: .medium).monospacedDigit())
                    .foregroundStyle(point.isHighlighted ? Color(hex: "00C7BE") : Color(hex: "8E8E93"))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            } else {
                Text(" ")
                    .font(.system(size: 11, weight: .medium))
            }

            // Bar with optional highlight border
            ZStack {
                RoundedRectangle(cornerRadius: 4)
                    .fill(barColor)
                    .frame(width: barWidth, height: barHeight)

                // Today/current period highlight border
                if point.isHighlighted {
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(Color(hex: "00C7BE"), lineWidth: 2)
                        .frame(width: barWidth, height: barHeight)
                }
            }
            .shadow(
                color: point.isHighlighted ? Color(hex: "00C7BE").opacity(0.3) : .clear,
                radius: point.isHighlighted ? 8 : 0
            )
            .animation(suppressAnimations ? nil : .easeInOut(duration: 0.3), value: point.steps)

            // Date label
            Text(point.label)
                .font(.system(size: 11, weight: point.isHighlighted ? .bold : .regular))
                .foregroundStyle(point.isHighlighted ? Color(hex: "00C7BE") : Color(hex: "8E8E93"))
                .lineLimit(1)
        }
    }

    // MARK: - Bar Color

    private var barColor: Color {
        if point.steps == 0 {
            return Color(hex: "E5E5EA")  // Empty state
        } else if point.goalMet {
            return Color(hex: "00C7BE")  // Goal met: teal
        } else {
            return Color(hex: "D1D1D6")  // Goal missed: light gray
        }
    }

    // MARK: - Step Formatting

    private func formatStepCount(_ steps: Int) -> String {
        if steps >= 1000 {
            let thousands = Double(steps) / 1000.0
            if thousands >= 10 {
                return String(format: "%.0fk", thousands)  // "12k"
            } else {
                return String(format: "%.1fk", thousands)  // "8.5k"
            }
        }
        return "\(steps)"
    }
}

// MARK: - Preview

#Preview("Week Data") {
    let calendar = Calendar.current
    let today = Date()

    let sampleData: [BarChartDataPoint] = (0..<7).reversed().map { dayOffset in
        let date = calendar.date(byAdding: .day, value: -dayOffset, to: today)!
        let steps = [12500, 8000, 10500, 6000, 11000, 9500, 7200][6 - dayOffset]
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE"
        return BarChartDataPoint(
            label: formatter.string(from: date),
            steps: steps,
            goalMet: steps >= 10000,
            isHighlighted: dayOffset == 0,
            date: date
        )
    }

    return ScrollableStepBarChart(
        data: sampleData,
        dailyGoal: 10000,
        period: .week
    )
    .padding()
    .background(JWDesign.Colors.secondaryBackground)
}

#Preview("Month Data - Scrollable") {
    let calendar = Calendar.current
    let today = Date()

    let sampleData: [BarChartDataPoint] = (0..<30).reversed().map { dayOffset in
        let date = calendar.date(byAdding: .day, value: -dayOffset, to: today)!
        let steps = Int.random(in: 4000...16000)
        return BarChartDataPoint(
            label: "\(calendar.component(.day, from: date))",
            steps: steps,
            goalMet: steps >= 10000,
            isHighlighted: dayOffset == 0,
            date: date
        )
    }

    return ScrollableStepBarChart(
        data: sampleData,
        dailyGoal: 10000,
        period: .month
    )
    .padding()
    .background(JWDesign.Colors.secondaryBackground)
}

#Preview("Year Data - Weekly") {
    let calendar = Calendar.current
    let today = Date()

    let sampleData: [BarChartDataPoint] = (0..<52).reversed().map { weekOffset in
        let date = calendar.date(byAdding: .weekOfYear, value: -weekOffset, to: today)!
        let avgSteps = Int.random(in: 6000...12000)
        let weekNum = calendar.component(.weekOfYear, from: date)
        return BarChartDataPoint(
            label: "W\(weekNum)",
            steps: avgSteps,
            goalMet: avgSteps >= 10000,
            isHighlighted: weekOffset == 0,
            date: date
        )
    }

    return ScrollableStepBarChart(
        data: sampleData,
        dailyGoal: 10000,
        period: .year
    )
    .padding()
    .background(JWDesign.Colors.secondaryBackground)
}
