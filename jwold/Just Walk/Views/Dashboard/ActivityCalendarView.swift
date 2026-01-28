//
//  ActivityCalendarView.swift
//  Just Walk
//
//  Calendar grid view showing date numbers with tappable day summaries.
//  Uses circular cells with color-coded status indicators.
//

import SwiftUI

struct ActivityCalendarView: View {
    @ObservedObject var dataViewModel: DataViewModel
    @ObservedObject var streakService: StreakService
    @ObservedObject var freeTierManager: FreeTierManager

    let days: [DayStepData]
    let onShieldRequest: (Date) -> Void

    // State for day summary sheet (replaces shield-only sheet)
    @State private var selectedDayForSummary: DayStepData?

    // 7 columns for Mon-Sun
    private let columns = Array(repeating: GridItem(.flexible(), spacing: JWDesign.Spacing.xs), count: 7)

    // Weekday labels (Monday first)
    private let weekdayLabels = ["M", "T", "W", "T", "F", "S", "S"]

    var body: some View {
        VStack(alignment: .leading, spacing: JWDesign.Spacing.lg) {
            // Weekday header row
            weekdayHeaderRow

            // Calendar grid
            LazyVGrid(columns: columns, spacing: JWDesign.Spacing.xs) {
                // Leading padding for first week alignment
                ForEach(0..<leadingPaddingCount, id: \.self) { _ in
                    Color.clear
                        .frame(minWidth: 40, minHeight: 40)
                        .aspectRatio(1, contentMode: .fit)
                }

                // Day cells
                ForEach(calendarDays) { day in
                    CalendarDayCell(
                        day: day,
                        isShielded: streakService.isDateShielded(day.date),
                        canShield: canShieldDay(day),
                        isFutureDay: isFutureDay(day.date),
                        isToday: isToday(day.date),
                        onTap: {
                            handleDayTap(day)
                        }
                    )
                }
            }
        }
        .sheet(item: $selectedDayForSummary) { day in
            DaySummarySheet(
                day: day,
                isShielded: streakService.isDateShielded(day.date),
                canShield: canShieldDay(day),
                shieldsRemaining: streakService.getStreakData()?.shieldsRemaining ?? 0,
                isToday: Calendar.current.isDateInToday(day.date),
                onShieldTap: {
                    onShieldRequest(day.date)
                    selectedDayForSummary = nil
                }
            )
            .presentationDetents([.height(320)])
        }
    }

    // MARK: - Weekday Header

    private var weekdayHeaderRow: some View {
        HStack(spacing: JWDesign.Spacing.xs) {
            ForEach(weekdayLabels, id: \.self) { label in
                Text(label)
                    .font(JWDesign.Typography.captionBold)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
            }
        }
        .padding(.bottom, JWDesign.Spacing.xs)
    }

    // MARK: - Calendar Data

    /// Days sorted oldest first for proper grid layout
    private var calendarDays: [DayStepData] {
        days.sorted { $0.date < $1.date }
    }

    /// Calculate leading padding to align first day to correct weekday column
    private var leadingPaddingCount: Int {
        guard let firstDay = calendarDays.first else { return 0 }
        let weekday = Calendar.current.component(.weekday, from: firstDay.date)
        // Convert Sunday=1 system to Monday-based (Mon=0, Tue=1, ..., Sun=6)
        return (weekday + 5) % 7
    }

    // MARK: - Date Helpers

    private func isFutureDay(_ date: Date) -> Bool {
        date > Date()
    }

    private func isToday(_ date: Date) -> Bool {
        Calendar.current.isDateInToday(date)
    }

    // MARK: - Shield Logic

    private func canShieldDay(_ day: DayStepData) -> Bool {
        let goalMet = day.isGoalMet
        let isShielded = streakService.isDateShielded(day.date)
        let isFuture = isFutureDay(day.date)
        // Show button on all missed days - tap handler shows purchase sheet if 0 shields
        return !goalMet && !isShielded && !isFuture
    }

    private func handleDayTap(_ day: DayStepData) {
        // Allow tapping any past day (not future)
        guard !isFutureDay(day.date) else { return }
        HapticService.shared.playSelection()
        selectedDayForSummary = day
    }
}

// MARK: - Calendar Day Cell (Circle Design with Date Numbers)

private struct CalendarDayCell: View {
    let day: DayStepData
    let isShielded: Bool
    let canShield: Bool
    let isFutureDay: Bool
    let isToday: Bool
    let onTap: () -> Void

    private var dayNumber: String {
        let calendar = Calendar.current
        return "\(calendar.component(.day, from: day.date))"
    }

    var body: some View {
        Button(action: onTap) {
            ZStack {
                // Background circle
                Circle()
                    .fill(cellColor)

                // Today ring (thick teal stroke)
                if isToday && !isFutureDay {
                    Circle()
                        .strokeBorder(JWDesign.Colors.brandSecondary, lineWidth: 3)
                }

                // Future day dashed border
                if isFutureDay {
                    Circle()
                        .strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [4]))
                        .foregroundStyle(Color.secondary.opacity(0.3))
                }

                // Date number (always shown)
                Text(dayNumber)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(textColor)

            }
            .frame(minWidth: 40, minHeight: 40)
            .aspectRatio(1, contentMode: .fit)
        }
        .buttonStyle(CalendarCellButtonStyle())
        .disabled(isFutureDay)
    }

    // MARK: - Cell Color

    private var cellColor: Color {
        if isFutureDay {
            return .clear
        } else if isToday {
            return Color.primary.opacity(0.1)  // Grey background for today
        } else if day.isGoalMet {
            return JWDesign.Colors.brandSecondary  // Teal for success
        } else if isShielded {
            return Color.orange.opacity(0.5)  // Muted orange for shielded
        } else {
            // Gray for missed days
            return Color.primary.opacity(0.1)
        }
    }

    // MARK: - Text Color

    private var textColor: Color {
        if isFutureDay {
            return Color.gray.opacity(0.4)
        } else if isToday {
            return JWDesign.Colors.brandSecondary  // Teal text for today
        } else if day.isGoalMet {
            return .white
        } else if isShielded {
            return .primary  // Dark text on muted orange
        } else {
            return .secondary
        }
    }
}

// MARK: - Custom Button Style (Press Animation)

private struct CalendarCellButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.92 : 1.0)
            .animation(JWDesign.Animation.quick, value: configuration.isPressed)
    }
}

// MARK: - Day Summary Sheet

private struct DaySummarySheet: View {
    let day: DayStepData
    let isShielded: Bool
    let canShield: Bool
    let shieldsRemaining: Int
    let isToday: Bool
    let onShieldTap: () -> Void

    @Environment(\.dismiss) private var dismiss

    private var goalValue: Int {
        day.historicalGoal ?? 10000
    }

    var body: some View {
        VStack(spacing: JWDesign.Spacing.md) {
            // Drag indicator
            Capsule()
                .fill(Color.secondary.opacity(0.4))
                .frame(width: 36, height: 5)
                .padding(.top, 6)

            // Date header
            Text(day.date.formatted(date: .complete, time: .omitted))
                .font(JWDesign.Typography.headlineBold)
                .foregroundStyle(.primary)

            // Stats section - Steps and Distance only
            HStack(spacing: 0) {
                // Steps column
                statColumn(
                    icon: "figure.walk",
                    iconColor: JWDesign.Colors.brandSecondary,
                    value: day.steps.formatted(),
                    label: "steps"
                )

                Divider()
                    .frame(height: 50)
                    .background(Color.secondary.opacity(0.3))

                // Distance column
                statColumn(
                    icon: "ruler",
                    iconColor: .blue,
                    value: formatDistance(day.distance ?? 0),
                    label: "distance"
                )
            }
            .padding(JWDesign.Spacing.md)
            .background(JWDesign.Colors.secondaryBackground)
            .clipShape(RoundedRectangle(cornerRadius: JWDesign.Radius.card))
            .padding(.horizontal, JWDesign.Spacing.md)

            // Goal status section - visual treatment based on state
            goalStatusSection
                .padding(.horizontal, JWDesign.Spacing.md)

            Spacer()

            // Use Shield button (only if can shield)
            if !isToday && canShield {
                Button {
                    HapticService.shared.playSuccess()
                    onShieldTap()
                } label: {
                    HStack(spacing: JWDesign.Spacing.sm) {
                        Image(systemName: "shield.fill")
                            .font(.system(size: 20))
                        Text("Use Shield")
                            .font(JWDesign.Typography.headlineBold)
                        Spacer()
                        Text("\(shieldsRemaining) remaining")
                            .font(JWDesign.Typography.caption)
                            .foregroundStyle(.white.opacity(0.8))
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, JWDesign.Spacing.lg)
                    .padding(.vertical, JWDesign.Spacing.lg)
                    .frame(maxWidth: .infinity)
                    .background(Color.orange)
                    .clipShape(RoundedRectangle(cornerRadius: JWDesign.Radius.card))
                }
                .padding(.horizontal, JWDesign.Spacing.md)
            }

            Spacer().frame(height: JWDesign.Spacing.md)
        }
        .background(JWDesign.Colors.background)
    }

    // MARK: - Goal Status Section

    @ViewBuilder
    private var goalStatusSection: some View {
        HStack(spacing: JWDesign.Spacing.md) {
            // Icon based on state
            if day.isGoalMet {
                // Goal achieved - green checkmark
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 20))
                    .foregroundStyle(JWDesign.Colors.success)
            } else if isShielded {
                // Day shielded - orange shield
                Image(systemName: "shield.fill")
                    .font(.system(size: 20))
                    .foregroundStyle(.orange)
            } else if canShield {
                // Missed goal, can shield - warning style
                Image(systemName: "exclamationmark.circle.fill")
                    .font(.system(size: 20))
                    .foregroundStyle(.orange)
            } else {
                // Missed goal, can't shield (today or no shields)
                Image(systemName: "circle")
                    .font(.system(size: 20))
                    .foregroundStyle(.secondary)
            }

            // Text based on state
            VStack(alignment: .leading, spacing: 2) {
                if day.isGoalMet {
                    Text("Goal: \(goalValue.formatted())")
                        .font(JWDesign.Typography.subheadlineBold)
                        .foregroundStyle(JWDesign.Colors.success)
                    Text("Achieved!")
                        .font(JWDesign.Typography.caption)
                        .foregroundStyle(JWDesign.Colors.success)
                } else if isShielded {
                    Text("Day Shielded")
                        .font(JWDesign.Typography.subheadlineBold)
                        .foregroundStyle(.orange)
                    Text("Streak protected")
                        .font(JWDesign.Typography.caption)
                        .foregroundStyle(.orange.opacity(0.8))
                } else if canShield {
                    Text("Missed: \(goalValue.formatted()) steps")
                        .font(JWDesign.Typography.subheadlineBold)
                        .foregroundStyle(.primary)
                    Text("Use a shield to protect your streak")
                        .font(JWDesign.Typography.caption)
                        .foregroundStyle(.orange)
                } else {
                    Text("Goal: \(goalValue.formatted())")
                        .font(JWDesign.Typography.subheadline)
                        .foregroundStyle(.secondary)
                    if isToday {
                        Text("In progress")
                            .font(JWDesign.Typography.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Spacer()
        }
        .padding(JWDesign.Spacing.md)
    }

    // MARK: - Stat Column Helper

    private func statColumn(icon: String, iconColor: Color, value: String, label: String) -> some View {
        VStack(spacing: JWDesign.Spacing.xs) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundStyle(iconColor)

            Text(value)
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundStyle(.primary)

            Text(label)
                .font(JWDesign.Typography.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Distance Formatter

    private func formatDistance(_ distance: Double) -> String {
        let miles = distance * 0.000621371
        return String(format: "%.2f mi", miles)
    }
}

// MARK: - Preview

#Preview("Activity Calendar - Redesign") {
    let mockDays = (0..<35).map { offset -> DayStepData in
        let date = Calendar.current.date(byAdding: .day, value: -offset + 5, to: Date())!
        let steps = offset > 5 ? (Bool.random() ? Int.random(in: 8000...15000) : Int.random(in: 1000...5000)) : 0
        return DayStepData(date: date, steps: steps, distance: Double(steps) * 0.75, historicalGoal: 10000)
    }

    return ScrollView {
        ActivityCalendarView(
            dataViewModel: DataViewModel(),
            streakService: StreakService.shared,
            freeTierManager: FreeTierManager.shared,
            days: mockDays,
            onShieldRequest: { _ in }
        )
        .padding()
    }
    .background(JWDesign.Colors.background)
}
