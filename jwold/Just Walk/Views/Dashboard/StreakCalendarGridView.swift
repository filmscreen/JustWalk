//
//  StreakCalendarGridView.swift
//  Just Walk
//
//  Calendar grid showing last 30 days for streak visualization.
//  Supports shield application on missed days within the 7-day window.
//

import SwiftUI
import Combine

// MARK: - Calendar Day State

enum CalendarDayState {
    case goalMet           // Teal filled circle
    case missed            // Gray circle (can't protect - too old)
    case missedProtectable // Gray circle with orange border (can protect)
    case protected         // Teal circle + shield badge
    case todayInProgress   // Outlined circle, pulsing
    case todayComplete     // Teal filled, highlighted
    case future            // Dimmed/invisible
    case empty             // Placeholder for grid alignment
}

// MARK: - Calendar Day Model

struct CalendarDay: Identifiable {
    let id = UUID()
    let date: Date?
    let dayNumber: Int?
    let dayData: DayStepData?
    let isEmpty: Bool

    init(date: Date, dayNumber: Int, dayData: DayStepData?) {
        self.date = date
        self.dayNumber = dayNumber
        self.dayData = dayData
        self.isEmpty = false
    }

    init(empty: Bool = true) {
        self.date = nil
        self.dayNumber = nil
        self.dayData = nil
        self.isEmpty = true
    }
}

// MARK: - Streak Calendar Grid View

struct StreakCalendarGridView: View {
    let days: [DayStepData]  // Historical data (most recent first)
    let dailyGoal: Int
    let streakService: StreakService
    var onProtectRequest: (DayStepData) -> Void
    var onInfoTapped: () -> Void = {}

    // Grid configuration
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 4), count: 7)
    private let protectableWindowDays = 7  // Only last 7 days can be shielded

    // Animation state
    @State private var todayPulse = false
    @State private var protectablePulse = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            Text("Last 30 Days")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(.primary)

            // Day of week headers (locale-aware)
            HStack(spacing: 4) {
                ForEach(weekdaySymbols, id: \.self) { symbol in
                    Text(symbol)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Color(.secondaryLabel))
                        .frame(maxWidth: .infinity)
                }
            }

            // Calendar grid
            LazyVGrid(columns: columns, spacing: 8) {
                ForEach(calendarDays) { day in
                    StreakCalendarDayCell(
                        day: day,
                        state: dayState(for: day),
                        todayPulse: $todayPulse,
                        protectablePulse: $protectablePulse,
                        onTap: {
                            if let dayData = day.dayData, canProtect(day: dayData) {
                                onProtectRequest(dayData)
                                HapticService.shared.playSelection()
                            }
                        }
                    )
                }
            }

            // Hint for protectable days
            if hasProtectableDays {
                let count = protectableDaysCount
                HStack(spacing: 6) {
                    Image(systemName: "hand.tap.fill")
                        .font(.system(size: 13))
                    Text("Tap \(count == 1 ? "the highlighted day" : "\(count) highlighted days") to protect")
                }
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Color(hex: "FF9500"))
                .padding(.top, 4)
            }

            // Calendar legend
            CalendarLegend(onInfoTapped: onInfoTapped)
                .padding(.top, 8)
        }
        .padding(16)
        .background(JWDesign.Colors.secondaryBackground)
        .clipShape(RoundedRectangle(cornerRadius: JWDesign.Radius.card))
        .onAppear {
            todayPulse = true
            protectablePulse = true
        }
    }

    // MARK: - Weekday Symbols (Locale-Aware)

    private var weekdaySymbols: [String] {
        let calendar = Calendar.current
        let symbols = calendar.veryShortWeekdaySymbols  // S, M, T, W, T, F, S
        let firstWeekday = calendar.firstWeekday  // 1 = Sunday, 2 = Monday
        let startIndex = firstWeekday - 1
        return Array(symbols[startIndex...]) + Array(symbols[..<startIndex])
    }

    // MARK: - Calendar Days (Rolling 30 days)

    private var calendarDays: [CalendarDay] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        // Get 35 days to fill grid (5 rows × 7 columns)
        var result: [CalendarDay] = []

        // Find the start date (30 days ago)
        guard let startDate = calendar.date(byAdding: .day, value: -34, to: today) else {
            return []
        }

        // Find what weekday the start date is
        let startWeekday = calendar.component(.weekday, from: startDate)
        let firstWeekday = calendar.firstWeekday

        // Calculate how many empty cells to add at the beginning
        var emptyCellsAtStart = startWeekday - firstWeekday
        if emptyCellsAtStart < 0 { emptyCellsAtStart += 7 }

        // Add empty cells at the beginning to align with weekdays
        for _ in 0..<emptyCellsAtStart {
            result.append(CalendarDay(empty: true))
        }

        // Add the 35 days
        for dayOffset in 0..<35 {
            guard let date = calendar.date(byAdding: .day, value: dayOffset, to: startDate) else { continue }

            let dayNumber = calendar.component(.day, from: date)
            let dayData = days.first { calendar.isDate($0.date, inSameDayAs: date) }

            result.append(CalendarDay(date: date, dayNumber: dayNumber, dayData: dayData))
        }

        return result
    }

    // MARK: - Day State

    private func dayState(for day: CalendarDay) -> CalendarDayState {
        guard !day.isEmpty, let date = day.date else { return .empty }

        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let dayStart = calendar.startOfDay(for: date)
        let isToday = calendar.isDateInToday(date)
        let isFuture = dayStart > today

        // CRITICAL: Future days are ALWAYS dimmed, regardless of data
        if isFuture { return .future }

        guard let dayData = day.dayData else {
            // No data for this day
            if isToday { return .todayInProgress }
            return .missed
        }

        let goalMet = dayData.isGoalMet
        let isShielded = streakService.isDateShielded(date)

        if isShielded { return .protected }

        if isToday {
            return goalMet ? .todayComplete : .todayInProgress
        }

        if goalMet { return .goalMet }

        // Missed day - check if protectable
        if canProtect(day: dayData) {
            return .missedProtectable
        }

        return .missed
    }

    // MARK: - Helpers

    private func canProtect(day: DayStepData) -> Bool {
        let calendar = Calendar.current
        let isToday = calendar.isDateInToday(day.date)
        let isFuture = day.date > Date()
        let goalMet = day.isGoalMet
        let isShielded = streakService.isDateShielded(day.date)

        guard !isToday && !isFuture && !goalMet && !isShielded else { return false }

        let daysSinceToday = calendar.dateComponents([.day], from: day.date, to: Date()).day ?? 0
        return daysSinceToday <= protectableWindowDays
    }

    private var hasProtectableDays: Bool {
        days.contains { canProtect(day: $0) }
    }

    private var protectableDaysCount: Int {
        days.filter { canProtect(day: $0) }.count
    }
}

// MARK: - Calendar Day Cell

private struct StreakCalendarDayCell: View {
    let day: CalendarDay
    let state: CalendarDayState
    @Binding var todayPulse: Bool
    @Binding var protectablePulse: Bool
    var onTap: () -> Void

    private let circleSize: CGFloat = 36

    var body: some View {
        ZStack {
            switch state {
            case .empty:
                Color.clear
                    .frame(width: circleSize, height: circleSize)

            case .future:
                // Dimmed circle
                Circle()
                    .fill(Color.gray.opacity(0.1))
                    .frame(width: circleSize, height: circleSize)
                    .overlay {
                        if let dayNumber = day.dayNumber {
                            Text("\(dayNumber)")
                                .font(.system(size: 14, weight: .regular))
                                .foregroundStyle(Color(.quaternaryLabel))
                        }
                    }

            case .goalMet:
                // Teal filled
                Circle()
                    .fill(Color(hex: "00C7BE"))
                    .frame(width: circleSize, height: circleSize)
                    .overlay {
                        if let dayNumber = day.dayNumber {
                            Text("\(dayNumber)")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(.white)
                        }
                    }

            case .missed:
                // Gray circle
                Circle()
                    .fill(Color(hex: "E5E5EA"))
                    .frame(width: circleSize, height: circleSize)
                    .overlay {
                        if let dayNumber = day.dayNumber {
                            Text("\(dayNumber)")
                                .font(.system(size: 14, weight: .regular))
                                .foregroundStyle(Color(.secondaryLabel))
                        }
                    }

            case .missedProtectable:
                // Orange fill (light) with border + "+" badge to indicate tappable
                ZStack {
                    Circle()
                        .fill(Color(hex: "FF9500").opacity(0.15))
                        .frame(width: circleSize, height: circleSize)
                        .overlay {
                            Circle()
                                .stroke(Color(hex: "FF9500"), lineWidth: 2.5)
                        }

                    if let dayNumber = day.dayNumber {
                        Text("\(dayNumber)")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(Color(hex: "FF9500"))
                    }

                    // "+" badge to indicate action available
                    ZStack {
                        Circle()
                            .fill(Color(hex: "FF9500"))
                            .frame(width: 14, height: 14)
                        Image(systemName: "plus")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundStyle(.white)
                    }
                    .offset(x: 11, y: 11)
                }
                .shadow(
                    color: Color(hex: "FF9500").opacity(protectablePulse ? 0.5 : 0.15),
                    radius: protectablePulse ? 8 : 4
                )
                .animation(
                    .easeInOut(duration: 1.0).repeatForever(autoreverses: true),
                    value: protectablePulse
                )
                .onTapGesture { onTap() }

            case .protected:
                // Teal with shield badge
                ZStack {
                    Circle()
                        .fill(Color(hex: "00C7BE"))
                        .frame(width: circleSize, height: circleSize)

                    if let dayNumber = day.dayNumber {
                        Text("\(dayNumber)")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.white)
                    }

                    // Shield badge - white background with teal icon
                    ZStack {
                        Circle()
                            .fill(.white)
                            .frame(width: 16, height: 16)
                            .shadow(color: .black.opacity(0.15), radius: 2, x: 0, y: 1)
                        Image(systemName: "shield.fill")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(Color(hex: "00C7BE"))
                    }
                    .offset(x: 11, y: 11)
                }

            case .todayInProgress:
                // Outlined with pulse (3pt stroke for today emphasis)
                Circle()
                    .stroke(Color(hex: "00C7BE"), lineWidth: 3)
                    .frame(width: circleSize, height: circleSize)
                    .background(Circle().fill(Color(hex: "00C7BE").opacity(0.1)))
                    .overlay {
                        if let dayNumber = day.dayNumber {
                            Text("\(dayNumber)")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(Color(hex: "00C7BE"))
                        }
                    }
                    .shadow(
                        color: Color(hex: "00C7BE").opacity(todayPulse ? 0.3 : 0.1),
                        radius: todayPulse ? 8 : 4
                    )
                    .animation(
                        .easeInOut(duration: 1.5).repeatForever(autoreverses: true),
                        value: todayPulse
                    )

            case .todayComplete:
                // Teal filled with teal ring to indicate "today"
                ZStack {
                    // Outer teal ring to distinguish today (3pt)
                    Circle()
                        .stroke(Color(hex: "00C7BE"), lineWidth: 3)
                        .frame(width: circleSize + 6, height: circleSize + 6)

                    // Inner filled circle
                    Circle()
                        .fill(Color(hex: "00C7BE"))
                        .frame(width: circleSize, height: circleSize)

                    if let dayNumber = day.dayNumber {
                        Text("\(dayNumber)")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(.white)
                    }
                }
            }
        }
        .frame(height: circleSize + 4)  // Consistent row height
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityHint(state == .missedProtectable ? "Double tap to protect this day" : "")
        .accessibilityAddTraits(state == .missedProtectable ? .isButton : [])
    }

    private var accessibilityLabel: String {
        guard let date = day.date else { return "" }

        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM d"
        let dateStr = formatter.string(from: date)

        switch state {
        case .empty: return ""
        case .future: return "\(dateStr). Future."
        case .goalMet: return "\(dateStr). Goal met."
        case .missed: return "\(dateStr). Missed."
        case .missedProtectable: return "\(dateStr). Missed. Can be protected."
        case .protected: return "\(dateStr). Protected with shield."
        case .todayInProgress: return "Today, \(dateStr). Goal in progress."
        case .todayComplete: return "Today, \(dateStr). Goal complete."
        }
    }
}

// MARK: - Preview

#Preview {
    let calendar = Calendar.current
    let today = Date()

    let sampleData: [DayStepData] = (0..<35).map { dayOffset in
        let date = calendar.date(byAdding: .day, value: -dayOffset, to: today)!
        let steps: Int
        if dayOffset == 0 {
            steps = 6500  // Today in progress
        } else if dayOffset == 2 || dayOffset == 5 {
            steps = 3000  // Missed (protectable)
        } else if dayOffset == 15 {
            steps = 2000  // Missed (too old)
        } else {
            steps = 11000  // Goal met
        }
        return DayStepData(date: date, steps: steps, distance: Double(steps) * 0.762, historicalGoal: 10000)
    }

    return ScrollView {
        StreakCalendarGridView(
            days: sampleData,
            dailyGoal: 10000,
            streakService: StreakService.shared,
            onProtectRequest: { day in
                print("Protect requested for: \(day.date)")
            }
        )
        .padding()
    }
    .background(Color(.systemGroupedBackground))
}
