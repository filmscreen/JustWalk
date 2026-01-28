//
//  StreakDetailSheet.swift
//  JustWalk
//
//  Half-sheet showing current streak, month-navigable calendar, and shield info
//

import SwiftUI

struct StreakDetailSheet: View {
    @Environment(\.dismiss) private var dismiss

    private var streakManager = StreakManager.shared
    private var shieldManager = ShieldManager.shared
    private var persistence = PersistenceManager.shared
    private var subscriptionManager = SubscriptionManager.shared

    @State private var showPaywall = false

    private var streakData: StreakData {
        streakManager.streakData
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Fixed header section (flame, streak count)
                heroSection
                    .padding(.horizontal)
                    .padding(.top, JW.Spacing.sm)

                Divider()
                    .overlay(JW.Color.backgroundTertiary)
                    .padding(.horizontal)
                    .padding(.vertical, JW.Spacing.sm)

                // Static month-based calendar (no nested scroll)
                MonthNavigableCalendar(showPaywall: $showPaywall)
                    .padding(.horizontal)

                // Fixed footer (legend + shield section)
                VStack(spacing: JW.Spacing.md) {
                    legendRow
                    shieldSection
                }
                .padding(.horizontal)
                .padding(.bottom, JW.Spacing.md)
            }
            .navigationTitle("Your Streak")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .sheet(isPresented: $showPaywall) {
            ProUpgradeView(onComplete: { showPaywall = false })
        }
    }

    // MARK: - Hero Section

    private var heroSection: some View {
        VStack(spacing: JW.Spacing.sm) {
            ZStack {
                Circle()
                    .fill(JW.Color.streak.opacity(0.2))
                    .frame(width: 72, height: 72)

                Image(systemName: "flame.fill")
                    .font(.system(size: 32))
                    .foregroundStyle(JW.Color.streak)
            }

            Text("\(streakData.currentStreak)")
                .font(.system(size: 36, weight: .bold, design: .rounded))
                .contentTransition(.numericText(value: Double(streakData.currentStreak)))

            Text(streakData.currentStreak == 1 ? "day" : "days")
                .font(JW.Font.subheadline)
                .foregroundStyle(JW.Color.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, JW.Spacing.sm)
    }

    // MARK: - Legend

    private var legendRow: some View {
        HStack(spacing: JW.Spacing.lg) {
            legendItem(color: JW.Color.accent, icon: "checkmark", label: "Goal Met")
            legendItem(color: JW.Color.accentBlue, icon: "shield.fill", label: "Shield Used")
            legendItem(color: JW.Color.backgroundTertiary, icon: nil, label: "Missed")
        }
        .font(JW.Font.caption)
    }

    private func legendItem(color: Color, icon: String?, label: String) -> some View {
        HStack(spacing: 4) {
            ZStack {
                Circle()
                    .fill(color)
                    .frame(width: 14, height: 14)

                if let icon {
                    Image(systemName: icon)
                        .font(.system(size: 7, weight: .bold))
                        .foregroundStyle(.white)
                }
            }

            Text(label)
                .foregroundStyle(JW.Color.textSecondary)
        }
    }

    // MARK: - Shield Section

    private var shieldSection: some View {
        VStack(spacing: JW.Spacing.md) {
            HStack(spacing: JW.Spacing.sm) {
                Image(systemName: "shield.fill")
                    .foregroundStyle(JW.Color.accentBlue)

                Text("\(shieldManager.availableShields) shield\(shieldManager.availableShields == 1 ? "" : "s") available")
                    .font(JW.Font.headline)
                    .foregroundStyle(JW.Color.textPrimary)
            }


        }
    }

}

// MARK: - Month-Navigable Streak Calendar (Static, No Nested Scroll)

struct MonthNavigableCalendar: View {
    @Bindable private var subscriptionManager = SubscriptionManager.shared
    private var persistence = PersistenceManager.shared
    private var streakManager = StreakManager.shared
    @AppStorage("dailyStepGoal") private var dailyGoal = 5000

    @Binding var showPaywall: Bool

    init(showPaywall: Binding<Bool>) {
        self._showPaywall = showPaywall
    }

    @State private var displayedMonth: Date = Date()
    @State private var selectedDay: DayData?
    @State private var earliestAllowedMonth: Date?

    private let calendar = Calendar.current

    private var isPro: Bool {
        subscriptionManager.isPro
    }

    private var isCurrentMonth: Bool {
        calendar.isDate(displayedMonth, equalTo: Date(), toGranularity: .month)
    }

    private var canGoBack: Bool {
        guard isPro else { return false }
        guard let earliest = earliestAllowedMonth else { return true }
        return displayedMonth > earliest
    }

    var body: some View {
        let weeks = buildMonthWeeks(for: displayedMonth)
        let weekdayHeaders = reorderedWeekdaySymbols()

        VStack(spacing: JW.Spacing.sm) {
            // Month navigation header
            monthNavigationHeader

            // Free user upgrade prompt
            if !isPro {
                upgradePromptSection
            }

            // Weekday header
            weekdayHeader(symbols: weekdayHeaders)

            // Static calendar grid (no ScrollView)
            VStack(spacing: JW.Spacing.xs) {
                ForEach(weeks) { week in
                    HStack(spacing: JW.Spacing.xs) {
                        ForEach(week.days) { day in
                            StreakCalendarDayCell(day: day)
                                .frame(maxWidth: .infinity)
                                .contentShape(Circle())
                                .onTapGesture {
                                    if day.isInRange {
                                        JustWalkHaptics.buttonTap()
                                        selectedDay = makeDayData(from: day)
                                    }
                                }
                        }
                    }
                }
            }
            .padding(.horizontal, JW.Spacing.sm)
            .padding(.bottom, JW.Spacing.sm)
        }
        .background(
            RoundedRectangle(cornerRadius: JW.Radius.lg)
                .fill(JW.Color.backgroundCard)
        )
        .sheet(item: $selectedDay) { day in
            DayDetailSheet(data: day)
                .presentationDetents([.medium])
                .presentationDragIndicator(.hidden)
                .presentationBackground(Color(.systemBackground))
        }
        .task {
            if isPro {
                await loadEarliestMonth()
            }
        }
    }

    // MARK: - Month Navigation Header

    private var monthNavigationHeader: some View {
        HStack {
            Button {
                previousMonth()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(canGoBack ? JW.Color.accent : JW.Color.textTertiary)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .disabled(!canGoBack)

            Spacer()

            Text(monthYearString(displayedMonth))
                .font(JW.Font.headline)
                .foregroundStyle(JW.Color.textPrimary)

            Spacer()

            Button {
                nextMonth()
            } label: {
                Image(systemName: "chevron.right")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(isCurrentMonth ? JW.Color.textTertiary : JW.Color.accent)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .disabled(isCurrentMonth)
        }
        .padding(.horizontal, JW.Spacing.sm)
    }

    // MARK: - Weekday Header

    private func weekdayHeader(symbols: [String]) -> some View {
        HStack(spacing: JW.Spacing.xs) {
            ForEach(symbols, id: \.self) { symbol in
                Text(symbol)
                    .font(JW.Font.caption2)
                    .foregroundStyle(JW.Color.textTertiary)
                    .frame(maxWidth: .infinity)
            }
        }
        .padding(.horizontal, JW.Spacing.md)
    }

    // MARK: - Upgrade Prompt

    private var upgradePromptSection: some View {
        HStack(spacing: JW.Spacing.sm) {
            Image(systemName: "crown.fill")
                .font(.system(size: 14))
                .foregroundStyle(JW.Color.streak)

            Text("View past months with Pro")
                .font(JW.Font.subheadline)
                .foregroundStyle(JW.Color.textSecondary)

            Spacer(minLength: JW.Spacing.sm)

            Button("Upgrade") {
                showPaywall = true
            }
            .font(JW.Font.subheadline.weight(.semibold))
            .foregroundStyle(JW.Color.accent)
            .padding(.horizontal, JW.Spacing.md)
            .padding(.vertical, JW.Spacing.xs)
            .background(
                Capsule()
                    .fill(JW.Color.accent.opacity(0.15))
            )
        }
        .padding(.horizontal, JW.Spacing.md)
        .padding(.vertical, JW.Spacing.sm)
        .background(JW.Color.backgroundTertiary.opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: JW.Radius.md))
        .padding(.horizontal, JW.Spacing.sm)
    }

    // MARK: - Navigation Actions

    private func previousMonth() {
        guard canGoBack else { return }
        JustWalkHaptics.buttonTap()
        withAnimation(.easeInOut(duration: 0.2)) {
            if let newMonth = calendar.date(byAdding: .month, value: -1, to: displayedMonth) {
                displayedMonth = newMonth
            }
        }
    }

    private func nextMonth() {
        guard !isCurrentMonth else { return }
        JustWalkHaptics.buttonTap()
        withAnimation(.easeInOut(duration: 0.2)) {
            if let newMonth = calendar.date(byAdding: .month, value: 1, to: displayedMonth) {
                displayedMonth = newMonth
            }
        }
    }

    // MARK: - Calendar Building

    private func buildMonthWeeks(for month: Date) -> [StreakCalendarWeek] {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"

        let today = calendar.startOfDay(for: Date())

        // Get the range of days in this month
        guard let monthInterval = calendar.dateInterval(of: .month, for: month) else { return [] }
        let monthStart = monthInterval.start
        let monthEnd = calendar.date(byAdding: .day, value: -1, to: monthInterval.end) ?? monthInterval.end

        // Find the start of the week containing the first day of the month
        guard let weekStart = calendar.date(
            from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: monthStart)
        ) else { return [] }

        // Find the end of the week containing the last day of the month
        let lastDayWeekdayIndex = (calendar.component(.weekday, from: monthEnd) - calendar.firstWeekday + 7) % 7
        let daysToWeekEnd = 6 - lastDayWeekdayIndex
        guard let weekEnd = calendar.date(byAdding: .day, value: daysToWeekEnd, to: monthEnd) else { return [] }

        var weeks: [StreakCalendarWeek] = []
        var currentWeekDays: [StreakCalendarDay] = []
        var current = weekStart

        while current <= weekEnd {
            let isInMonth = calendar.isDate(current, equalTo: month, toGranularity: .month)
            let isInRange = isInMonth && current <= today
            let isToday = calendar.isDateInToday(current)
            let isFuture = current > today

            var goalMet = false
            var shieldUsed = false
            var steps = 0

            if isInRange {
                if let log = persistence.loadDailyLog(for: current) {
                    goalMet = log.goalMet
                    shieldUsed = log.shieldUsed
                    steps = log.steps
                }
            }

            let day = StreakCalendarDay(
                id: formatter.string(from: current),
                date: current,
                isInRange: isInRange,
                isToday: isToday,
                isFuture: isFuture || !isInMonth,
                goalMet: goalMet,
                shieldUsed: shieldUsed,
                steps: steps,
                goal: dailyGoal
            )

            currentWeekDays.append(day)

            if currentWeekDays.count == 7 {
                weeks.append(StreakCalendarWeek(
                    id: "week_\(weeks.count)_\(formatter.string(from: current))",
                    days: currentWeekDays,
                    showMonthHeader: false,
                    monthHeader: nil
                ))
                currentWeekDays = []
            }

            guard let next = calendar.date(byAdding: .day, value: 1, to: current) else { break }
            current = next
        }

        return weeks
    }

    private func loadEarliestMonth() async {
        let allLogs = persistence.loadAllDailyLogs()
        let streakData = streakManager.streakData

        var earliestDate: Date?

        if let streakStart = streakData.streakStartDate {
            earliestDate = streakStart
        }

        if let earliestLog = allLogs.last?.date {
            if let currentEarliest = earliestDate {
                earliestDate = min(currentEarliest, earliestLog)
            } else {
                earliestDate = earliestLog
            }
        }

        if let hkDate = await HealthKitManager.shared.fetchEarliestStepDate() {
            let hkStart = calendar.startOfDay(for: hkDate)
            if let currentEarliest = earliestDate {
                earliestDate = min(currentEarliest, hkStart)
            } else {
                earliestDate = hkStart
            }
        }

        if let date = earliestDate {
            earliestAllowedMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: date))
        }
    }

    private func monthYearString(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: date)
    }

    private func reorderedWeekdaySymbols() -> [String] {
        let symbols = calendar.veryShortWeekdaySymbols
        let first = calendar.firstWeekday
        return (0..<7).map { symbols[($0 + first - 1) % 7] }
    }

    private func makeDayData(from day: StreakCalendarDay) -> DayData {
        let weekdayIndex = calendar.component(.weekday, from: day.date) - 1
        let dayName = calendar.shortWeekdaySymbols[weekdayIndex]
        let month = calendar.component(.month, from: day.date)
        let dayNum = calendar.component(.day, from: day.date)

        return DayData(
            day: dayName,
            dateLabel: "\(month)/\(dayNum)",
            steps: day.steps,
            goal: day.goal,
            goalMet: day.goalMet,
            shieldUsed: day.shieldUsed,
            isToday: day.isToday,
            isWithinWeek: day.isInRange,
            date: day.date
        )
    }
}

// MARK: - Calendar Week Model

private struct StreakCalendarWeek: Identifiable {
    let id: String
    let days: [StreakCalendarDay]
    let showMonthHeader: Bool
    let monthHeader: String?
}

// MARK: - Calendar Day Model

private struct StreakCalendarDay: Identifiable {
    let id: String
    let date: Date
    let isInRange: Bool
    let isToday: Bool
    let isFuture: Bool
    let goalMet: Bool
    let shieldUsed: Bool
    let steps: Int
    let goal: Int
}

// MARK: - Calendar Day Cell

private struct StreakCalendarDayCell: View {
    let day: StreakCalendarDay

    var body: some View {
        if day.isInRange {
            ZStack {
                Circle()
                    .fill(cellColor)
                    .frame(width: 32, height: 32)

                if day.goalMet {
                    Image(systemName: "checkmark")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.white)
                } else if day.shieldUsed {
                    Image(systemName: "shield.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(.white)
                }
            }
            .overlay {
                if day.isToday {
                    Circle()
                        .stroke(JW.Color.accent, lineWidth: 2)
                        .frame(width: 34, height: 34)
                }
            }
        } else {
            // Placeholder for out-of-range or future days
            Circle()
                .fill(Color.clear)
                .frame(width: 32, height: 32)
        }
    }

    private var cellColor: Color {
        if day.goalMet {
            return JW.Color.accent
        } else if day.shieldUsed {
            return JW.Color.accentBlue
        } else {
            return JW.Color.backgroundTertiary
        }
    }
}

#Preview {
    StreakDetailSheet()
}
