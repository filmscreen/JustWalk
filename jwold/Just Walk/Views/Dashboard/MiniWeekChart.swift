//
//  MiniWeekChart.swift
//  Just Walk
//
//  Compact 7-day step activity chart for the Today screen.
//

import SwiftUI

struct MiniWeekChart: View {
    let weekData: [DayStepData]
    let dailyGoal: Int
    var onSeeMore: () -> Void

    // Animation suppression (for initial load)
    @Environment(\.suppressAnimations) private var suppressAnimations

    private let maxBarHeight: CGFloat = 82  // Balanced height
    private let barWidth: CGFloat = 28
    private let barSpacing: CGFloat = 12

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {  // 16pt header to bars
            // Header row - entire row tappable
            Button(action: onSeeMore) {
                HStack {
                    Text("This Week")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(.primary)
                    Spacer()
                    HStack(spacing: 4) {
                        Text("See more")
                            .font(.system(size: 15, weight: .regular))
                        Image(systemName: "chevron.right")
                            .font(.system(size: 14, weight: .regular))
                    }
                    .foregroundStyle(Color(hex: "00C7BE"))
                }
            }
            .buttonStyle(.plain)

            // Bar chart - 7 days
            HStack(alignment: .bottom, spacing: barSpacing) {
                ForEach(weekData.reversed()) { day in
                    VStack(spacing: 4) {
                        // Step count label (hide if 0 steps)
                        if day.steps > 0 {
                            Text(formatStepCount(day.steps))
                                .font(.system(size: 11, weight: .medium).monospacedDigit())
                                .foregroundStyle(isToday(day.date) ? Color(hex: "00C7BE") : Color(hex: "8E8E93"))
                        } else {
                            Text(" ")  // Placeholder for alignment
                                .font(.system(size: 11, weight: .medium))
                        }

                        // Bar - rounded rectangle with today highlight
                        ZStack {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(barColor(for: day))
                                .frame(width: barWidth, height: barHeight(for: day))

                            // Today's bar border highlight
                            if isToday(day.date) {
                                RoundedRectangle(cornerRadius: 4)
                                    .stroke(Color(hex: "00C7BE"), lineWidth: 2)
                                    .frame(width: barWidth, height: barHeight(for: day))
                            }
                        }
                        .shadow(
                            color: isToday(day.date) ? Color(hex: "00C7BE").opacity(0.3) : .clear,
                            radius: isToday(day.date) ? 8 : 0
                        )
                        .animation(suppressAnimations ? nil : .easeInOut(duration: 0.3), value: day.steps)

                        // Day label (3-letter: Wed, Thu, etc.)
                        Text(dayAbbreviation(for: day.date))
                            .font(.system(size: 13, weight: isToday(day.date) ? .bold : .regular))
                            .foregroundStyle(isToday(day.date) ? Color(hex: "00C7BE") : Color(hex: "8E8E93"))
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("This week's activity")
            .accessibilityValue(weekChartAccessibilityValue)
            .accessibilityHint("Double tap to see more details")
        }
        .padding(16)
        .background(JWDesign.Colors.secondaryBackground)
        .clipShape(RoundedRectangle(cornerRadius: JWDesign.Radius.card))
        .shadow(color: Color.black.opacity(0.04), radius: 4, x: 0, y: 2)
    }

    // MARK: - Accessibility

    private var weekChartAccessibilityValue: String {
        let daysGoalMet = weekData.filter { $0.isGoalMet }.count
        return "\(daysGoalMet) of 7 days goal met"
    }

    // MARK: - Helpers

    private func barHeight(for day: DayStepData) -> CGFloat {
        let emptyHeight: CGFloat = 4  // Empty state: flat bar
        guard day.steps > 0 else { return emptyHeight }

        // Height = (steps / goal) × maxHeight, capped at maxHeight
        let ratio = CGFloat(day.steps) / CGFloat(dailyGoal)
        return min(maxBarHeight, ratio * maxBarHeight)
    }

    private func barColor(for day: DayStepData) -> Color {
        if day.steps == 0 {
            return Color(hex: "E5E5EA")  // Empty state color
        } else if day.isGoalMet {
            return Color(hex: "00C7BE")  // Goal met: teal
        } else {
            return Color(hex: "D1D1D6")  // Goal missed: light gray
        }
    }

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

    private func dayAbbreviation(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE"  // 3-letter: Wed, Thu, Fri
        return formatter.string(from: date)
    }

    private func isToday(_ date: Date) -> Bool {
        Calendar.current.isDateInToday(date)
    }
}

#Preview {
    let calendar = Calendar.current
    let today = Date()
    let sampleData: [DayStepData] = (0..<7).map { dayOffset in
        let date = calendar.date(byAdding: .day, value: -dayOffset, to: today)!
        let steps = [12500, 8000, 10500, 6000, 11000, 9500, 0][dayOffset]
        return DayStepData(date: date, steps: steps, distance: Double(steps) * 0.762, historicalGoal: 10000)
    }

    return MiniWeekChart(
        weekData: sampleData,
        dailyGoal: 10000,
        onSeeMore: {}
    )
    .padding()
}
