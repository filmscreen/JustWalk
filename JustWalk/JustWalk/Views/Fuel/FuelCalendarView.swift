//
//  FuelCalendarView.swift
//  JustWalk
//
//  Calendar view for the Fuel tab showing days with food logged
//

import SwiftUI

struct FuelCalendarView: View {
    @Binding var selectedDate: Date
    let hasLogsForDate: (Date) -> Bool

    @State private var displayedMonth: Date = Date()
    @State private var isExpanded = false

    private let calendar = Calendar.current
    private let weekdaySymbols = ["M", "T", "W", "T", "F", "S", "S"]

    // MARK: - Computed Properties

    private var monthYearString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: displayedMonth)
    }

    /// Returns Monday through Sunday for the week containing selectedDate
    private var weekDates: [Date] {
        // Get the weekday of the selected date (1 = Sunday, 2 = Monday, ..., 7 = Saturday)
        let weekday = calendar.component(.weekday, from: selectedDate)

        // Calculate days back to Monday (our week start)
        // Sunday (1) -> go back 6 days
        // Monday (2) -> go back 0 days
        // Tuesday (3) -> go back 1 day, etc.
        let daysFromMonday = weekday == 1 ? 6 : weekday - 2

        guard let monday = calendar.date(byAdding: .day, value: -daysFromMonday, to: selectedDate) else {
            return []
        }

        // Generate all 7 days of the week
        return (0..<7).compactMap { dayOffset in
            calendar.date(byAdding: .day, value: dayOffset, to: monday)
        }
    }

    private var daysInMonth: [Date?] {
        guard let monthInterval = calendar.dateInterval(of: .month, for: displayedMonth) else {
            return []
        }

        // Get the first day of the month
        let firstDayOfMonth = monthInterval.start

        // Find what weekday the month starts on (adjusting for Monday start)
        var weekday = calendar.component(.weekday, from: firstDayOfMonth)
        // Convert Sunday=1 to Monday=0 based index
        weekday = (weekday + 5) % 7

        // Get number of days in the month
        guard let range = calendar.range(of: .day, in: .month, for: displayedMonth) else {
            return []
        }
        let numberOfDays = range.count

        // Build the array with nil padding for empty cells
        var days: [Date?] = Array(repeating: nil, count: weekday)

        for day in 1...numberOfDays {
            if let date = calendar.date(bySetting: .day, value: day, of: firstDayOfMonth) {
                days.append(date)
            }
        }

        // Pad remaining cells to complete the grid (always 6 rows)
        let totalCells = 42
        while days.count < totalCells {
            days.append(nil)
        }

        return days
    }

    // MARK: - Body

    var body: some View {
        Group {
            if isExpanded {
                expandedCalendarView
            } else {
                weekStripView
            }
        }
        .animation(.easeInOut(duration: 0.2), value: isExpanded)
        .padding(.horizontal, JW.Spacing.md)
        .padding(.vertical, JW.Spacing.sm)
        .jwCard()
    }

    // MARK: - Subviews

    /// Collapsed week strip view showing 7 days
    private var weekStripView: some View {
        VStack(spacing: JW.Spacing.sm) {
            // Weekday labels row
            HStack(spacing: 0) {
                ForEach(weekdaySymbols.indices, id: \.self) { index in
                    Text(weekdaySymbols[index])
                        .font(JW.Font.caption)
                        .foregroundStyle(JW.Color.textTertiary)
                        .frame(maxWidth: .infinity)
                }

                // Spacer for chevron alignment
                Color.clear
                    .frame(width: 44)
            }

            // Day cells row with chevron
            HStack(spacing: 0) {
                ForEach(weekDates, id: \.self) { date in
                    DayCell(
                        date: date,
                        isSelected: calendar.isDate(date, inSameDayAs: selectedDate),
                        isToday: calendar.isDateInToday(date),
                        hasLogs: hasLogsForDate(date)
                    ) {
                        selectedDate = date
                        JustWalkHaptics.selectionChanged()
                    }
                }

                // Expand chevron - tap to expand calendar
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isExpanded = true
                        displayedMonth = selectedDate
                        JustWalkHaptics.selectionChanged()
                    }
                } label: {
                    Image(systemName: "chevron.down")
                        .font(JW.Font.caption)
                        .foregroundStyle(JW.Color.textTertiary)
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .contentShape(Rectangle())
        // Block all horizontal drag gestures to prevent week navigation from edge swipes
        .highPriorityGesture(
            DragGesture(minimumDistance: 10, coordinateSpace: .local)
                .onChanged { _ in }
                .onEnded { _ in }
        )
    }

    /// Expanded full calendar view
    private var expandedCalendarView: some View {
        VStack(spacing: JW.Spacing.md) {
            // Month navigation header with collapse chevron
            expandedMonthHeader

            // Weekday labels
            weekdayHeader

            // Calendar grid
            calendarGrid
        }
    }

    private var expandedMonthHeader: some View {
        HStack {
            Button {
                navigateMonth(by: -1)
            } label: {
                Image(systemName: "chevron.left")
                    .font(JW.Font.headline)
                    .foregroundStyle(JW.Color.textSecondary)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(ScalePressButtonStyle())

            Spacer()

            // Tappable header to collapse
            HStack(spacing: JW.Spacing.xs) {
                Text(monthYearString)
                    .font(JW.Font.headline)
                    .foregroundStyle(JW.Color.textPrimary)

                Image(systemName: "chevron.up")
                    .font(JW.Font.caption)
                    .foregroundStyle(JW.Color.textTertiary)
            }
            .contentShape(Rectangle())
            .onTapGesture {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isExpanded = false
                    JustWalkHaptics.selectionChanged()
                }
            }

            Spacer()

            Button {
                navigateMonth(by: 1)
            } label: {
                Image(systemName: "chevron.right")
                    .font(JW.Font.headline)
                    .foregroundStyle(JW.Color.textSecondary)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(ScalePressButtonStyle())
        }
    }

    private var monthHeader: some View {
        HStack {
            Button {
                navigateMonth(by: -1)
            } label: {
                Image(systemName: "chevron.left")
                    .font(JW.Font.headline)
                    .foregroundStyle(JW.Color.textSecondary)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(ScalePressButtonStyle())

            Spacer()

            Text(monthYearString)
                .font(JW.Font.headline)
                .foregroundStyle(JW.Color.textPrimary)

            Spacer()

            Button {
                navigateMonth(by: 1)
            } label: {
                Image(systemName: "chevron.right")
                    .font(JW.Font.headline)
                    .foregroundStyle(JW.Color.textSecondary)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(ScalePressButtonStyle())
        }
    }

    private var weekdayHeader: some View {
        HStack(spacing: 0) {
            ForEach(weekdaySymbols.indices, id: \.self) { index in
                Text(weekdaySymbols[index])
                    .font(JW.Font.caption)
                    .foregroundStyle(JW.Color.textTertiary)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    private var calendarGrid: some View {
        let columns = Array(repeating: GridItem(.flexible(), spacing: 0), count: 7)

        return LazyVGrid(columns: columns, spacing: JW.Spacing.xs) {
            ForEach(Array(daysInMonth.enumerated()), id: \.offset) { _, date in
                if let date = date {
                    DayCell(
                        date: date,
                        isSelected: calendar.isDate(date, inSameDayAs: selectedDate),
                        isToday: calendar.isDateInToday(date),
                        hasLogs: hasLogsForDate(date)
                    ) {
                        selectedDate = date
                        JustWalkHaptics.selectionChanged()
                    }
                } else {
                    Color.clear
                        .frame(height: 32)
                }
            }
        }
    }

    // MARK: - Methods

    private func navigateMonth(by value: Int) {
        withAnimation(.easeInOut(duration: 0.2)) {
            if let newMonth = calendar.date(byAdding: .month, value: value, to: displayedMonth) {
                displayedMonth = newMonth
                JustWalkHaptics.selectionChanged()
            }
        }
    }
}

// MARK: - Day Cell

private struct DayCell: View {
    let date: Date
    let isSelected: Bool
    let isToday: Bool
    let hasLogs: Bool
    let onTap: () -> Void

    private let calendar = Calendar.current

    private var dayNumber: String {
        String(calendar.component(.day, from: date))
    }

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 2) {
                ZStack {
                    // Selection/Today background
                    if isSelected {
                        Circle()
                            .fill(JW.Color.accent)
                            .frame(width: 28, height: 28)
                    } else if isToday {
                        Circle()
                            .stroke(JW.Color.accent, lineWidth: 1.5)
                            .frame(width: 28, height: 28)
                    }

                    Text(dayNumber)
                        .font(JW.Font.caption)
                        .fontWeight(isToday || isSelected ? .semibold : .regular)
                        .foregroundStyle(dayTextColor)
                }

                // Logged indicator dot
                Circle()
                    .fill(hasLogs ? JW.Color.accent : Color.clear)
                    .frame(width: 3, height: 3)
            }
            .frame(height: 32)
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var dayTextColor: Color {
        if isSelected {
            return JW.Color.backgroundPrimary
        } else if isToday {
            return JW.Color.accent
        } else {
            return JW.Color.textPrimary
        }
    }
}

// MARK: - Preview

#Preview("With Mock Data") {
    struct PreviewWrapper: View {
        @State private var selectedDate = Date()

        // Mock data: random days have logs
        private func mockHasLogs(for date: Date) -> Bool {
            let day = Calendar.current.component(.day, from: date)
            return [3, 5, 7, 12, 15, 18, 20, 22, 25, 28].contains(day)
        }

        var body: some View {
            VStack {
                FuelCalendarView(
                    selectedDate: $selectedDate,
                    hasLogsForDate: mockHasLogs
                )
                .padding()

                Spacer()

                Text("Selected: \(selectedDate.formatted(date: .abbreviated, time: .omitted))")
                    .foregroundStyle(JW.Color.textSecondary)
                    .padding()
            }
            .background(JW.Color.backgroundPrimary)
        }
    }

    return PreviewWrapper()
}

#Preview("Empty Calendar") {
    struct PreviewWrapper: View {
        @State private var selectedDate = Date()

        var body: some View {
            VStack {
                FuelCalendarView(
                    selectedDate: $selectedDate,
                    hasLogsForDate: { _ in false }
                )
                .padding()

                Spacer()
            }
            .background(JW.Color.backgroundPrimary)
        }
    }

    return PreviewWrapper()
}
