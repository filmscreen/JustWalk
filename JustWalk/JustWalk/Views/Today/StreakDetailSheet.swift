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
            ScrollView {
                VStack(spacing: JW.Spacing.sm) {
                    // Compact hero section (no card background)
                    heroSection

                    // Static month-based calendar (no nested scroll)
                    MonthNavigableCalendar(showPaywall: $showPaywall)
                        .layoutPriority(1)

                    // Fixed footer (legend + shield section)
                    VStack(spacing: JW.Spacing.md) {
                        legendRow
                        shieldSection
                    }
                    .padding(.horizontal, JW.Spacing.sm)
                    .padding(.vertical, JW.Spacing.sm)
                }
                .padding(.horizontal, JW.Spacing.sm)
                .padding(.top, JW.Spacing.xs)
                .padding(.bottom, JW.Spacing.sm)
                .frame(maxWidth: .infinity)
            }
            .scrollBounceBehavior(.basedOnSize)
            .scrollIndicators(.hidden)
            .background(JW.Color.backgroundPrimary)
            .navigationTitle("Your Streak")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .toolbarBackground(JW.Color.backgroundPrimary, for: .navigationBar)
        }
        .presentationDetents([.large, .medium], selection: .constant(.large))
        .presentationDragIndicator(.visible)
        .presentationBackground(JW.Color.backgroundPrimary)
        .sheet(isPresented: $showPaywall) {
            ProUpgradeView(onComplete: { showPaywall = false })
        }
    }

    @AppStorage("dailyStepGoal") private var dailyGoal = 5000

    // MARK: - Hero Section

    private var heroSection: some View {
        VStack(spacing: JW.Spacing.sm) {
            // Flame icon - large centered circle
            ZStack {
                Circle()
                    .fill(JW.Color.streak)
                    .frame(width: 88, height: 88)

                Text("🔥")
                    .font(.system(size: 40))
            }

            // Streak count
            Text("\(streakData.currentStreak)")
                .font(.system(size: 48, weight: .bold, design: .rounded))
                .contentTransition(.numericText(value: Double(streakData.currentStreak)))

            // "day" label
            Text(streakData.currentStreak == 1 ? "day" : "days")
                .font(JW.Font.title3)
                .foregroundStyle(JW.Color.textSecondary)

            // Goal display
            Text("Goal: \(dailyGoal.formatted()) steps")
                .font(JW.Font.subheadline)
                .foregroundStyle(JW.Color.textTertiary)

            // Trophy: Best streak display
            if streakData.longestStreak > 0 {
                HStack(spacing: 4) {
                    Text("🏆")
                        .font(.system(size: 14))

                    if streakData.currentStreak == streakData.longestStreak && streakData.currentStreak > 1 {
                        Text("Best: \(streakData.longestStreak) days — now!")
                            .font(JW.Font.subheadline)
                            .foregroundStyle(JW.Color.textSecondary)
                    } else {
                        Text("Best: \(streakData.longestStreak) day\(streakData.longestStreak == 1 ? "" : "s")")
                            .font(JW.Font.subheadline)
                            .foregroundStyle(JW.Color.textSecondary)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, JW.Spacing.md)
    }

    // MARK: - Legend

    private var legendRow: some View {
        HStack(spacing: JW.Spacing.md) {
            legendItem(color: JW.Color.accent, icon: "checkmark", label: "Goal")
            legendItem(color: JW.Color.accentBlue, icon: "checkmark", label: "Shield")
            legendItemRing(label: "Partial")
        }
        .font(JW.Font.caption)
    }

    private func legendItemRing(label: String) -> some View {
        HStack(spacing: 4) {
            ZStack {
                Circle()
                    .stroke(JW.Color.backgroundTertiary, lineWidth: 2)
                    .frame(width: 16, height: 16)
                Circle()
                    .trim(from: 0, to: 0.5)
                    .stroke(JW.Color.accent.opacity(0.7), style: StrokeStyle(lineWidth: 2, lineCap: .round))
                    .frame(width: 16, height: 16)
                    .rotationEffect(.degrees(-90))
            }
            Text(label)
                .foregroundStyle(JW.Color.textSecondary)
        }
    }

    private func legendItem(color: Color, icon: String?, label: String) -> some View {
        HStack(spacing: 4) {
            ZStack {
                Circle()
                    .fill(color)
                    .frame(width: 16, height: 16)

                if let icon {
                    Image(systemName: icon)
                        .font(.system(size: 8, weight: .bold))
                        .foregroundStyle(.white)
                }
            }

            Text(label)
                .foregroundStyle(JW.Color.textSecondary)
        }
    }

    // MARK: - Shield Section

    private var shieldSection: some View {
        HStack(spacing: JW.Spacing.xs) {
            Image(systemName: "shield.fill")
                .font(.system(size: 16))
                .foregroundStyle(JW.Color.accentBlue)

            Text("\(shieldManager.availableShields) shield\(shieldManager.availableShields == 1 ? "" : "s") available")
                .font(JW.Font.subheadline)
                .foregroundStyle(JW.Color.textPrimary)
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
        if !isPro {
            // Free users can navigate to months within the past 30 days
            let thirtyDaysAgo = calendar.date(byAdding: .day, value: -30, to: Date()) ?? Date()
            let limitMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: thirtyDaysAgo))

            if let previousMonth = calendar.date(byAdding: .month, value: -1, to: displayedMonth),
               let limit = limitMonth {
                // Allow if previous month is >= the month containing the 30-days-ago date
                return previousMonth >= limit
            }
            return false
        }

        // Pro users can go back to earliest data
        guard let earliest = earliestAllowedMonth else { return true }
        return displayedMonth > earliest
    }

    var body: some View {
        let weeks = buildMonthWeeks(for: displayedMonth)
        let weekdayHeaders = reorderedWeekdaySymbols()

        VStack(spacing: JW.Spacing.xs) {
            // Month navigation header
            monthNavigationHeader

            // Free user upgrade prompt
            if !isPro {
                upgradePromptSection
            }

            // Weekday header
            weekdayHeader(symbols: weekdayHeaders)

            // Static calendar grid (no ScrollView)
            VStack(spacing: JW.Spacing.sm) {
                ForEach(weeks) { week in
                    HStack(spacing: 2) {
                        ForEach(week.days) { day in
                            StreakCalendarDayCell(day: day)
                                .frame(maxWidth: .infinity)
                                .contentShape(Circle())
                                .onTapGesture {
                                    if day.isInRange && !day.isLocked {
                                        JustWalkHaptics.buttonTap()
                                        selectedDay = makeDayData(from: day)
                                    }
                                }
                        }
                    }
                }
            }
            .padding(.horizontal, 2)
            .padding(.bottom, JW.Spacing.xs)
        }
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: JW.Radius.lg)
                .fill(JW.Color.backgroundCard)
        )
        .sheet(item: $selectedDay) { day in
            DayDetailSheet(data: day)
                .presentationDetents([.medium, .large])
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
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(canGoBack ? JW.Color.accent : JW.Color.textTertiary)
                    .frame(width: 36, height: 36)
                    .contentShape(Rectangle())
            }
            .disabled(!canGoBack)

            Spacer()

            Text(monthYearString(displayedMonth))
                .font(JW.Font.subheadline.weight(.semibold))
                .foregroundStyle(JW.Color.textPrimary)

            Spacer()

            Button {
                nextMonth()
            } label: {
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(isCurrentMonth ? JW.Color.textTertiary : JW.Color.accent)
                    .frame(width: 36, height: 36)
                    .contentShape(Rectangle())
            }
            .disabled(isCurrentMonth)
        }
        .padding(.horizontal, 2)
    }

    // MARK: - Weekday Header

    private func weekdayHeader(symbols: [String]) -> some View {
        HStack(spacing: 2) {
            ForEach(symbols, id: \.self) { symbol in
                Text(symbol)
                    .font(JW.Font.caption2)
                    .foregroundStyle(JW.Color.textTertiary)
                    .frame(maxWidth: .infinity)
            }
        }
        .padding(.horizontal, 2)
    }

    // MARK: - Upgrade Prompt

    private var upgradePromptSection: some View {
        HStack(spacing: JW.Spacing.xs) {
            Image(systemName: "crown.fill")
                .font(.system(size: 12))
                .foregroundStyle(JW.Color.streak)

            Text("View full history with Pro")
                .font(JW.Font.caption)
                .foregroundStyle(JW.Color.textSecondary)

            Spacer(minLength: JW.Spacing.xs)

            Button("Upgrade") {
                showPaywall = true
            }
            .font(JW.Font.caption.weight(.semibold))
            .foregroundStyle(JW.Color.accent)
            .padding(.horizontal, JW.Spacing.xs)
            .padding(.vertical, 4)
            .background(
                Capsule()
                    .fill(JW.Color.accent.opacity(0.15))
            )
        }
        .padding(.horizontal, JW.Spacing.xs)
        .padding(.vertical, JW.Spacing.xs)
        .background(JW.Color.backgroundTertiary.opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: JW.Radius.sm))
        .padding(.horizontal, 2)
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
        let thirtyDaysAgo = calendar.date(byAdding: .day, value: -30, to: today) ?? today

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

            // For free users, days older than 30 days are locked
            let isLocked = !isPro && isInRange && current < thirtyDaysAgo

            var goalMet = false
            var shieldUsed = false
            var steps = 0
            // For today, use current goal. For past days, use stored historical goal.
            var goal = dailyGoal

            if isInRange && !isLocked {
                if let log = persistence.loadDailyLog(for: current) {
                    goalMet = log.goalMet
                    shieldUsed = log.shieldUsed
                    steps = log.steps
                    // Use the stored historical goal if available
                    if !isToday, let storedGoal = log.goalTarget {
                        goal = storedGoal
                    }
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
                goal: goal,
                isLocked: isLocked
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
            date: day.date,
            isPastDay: calendar.startOfDay(for: day.date) < calendar.startOfDay(for: Date())
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
    let isLocked: Bool  // True for days beyond 30-day limit for free users
}

// MARK: - Calendar Day Cell

private struct StreakCalendarDayCell: View {
    let day: StreakCalendarDay

    private let circleSize: CGFloat = 40
    private let ringSize: CGFloat = 40

    private var stepProgress: Double {
        guard day.goal > 0 else { return 0 }
        return min(Double(day.steps) / Double(day.goal), 1.0)
    }

    private var hasPartialProgress: Bool {
        !day.goalMet && !day.shieldUsed && day.steps > 0
    }

    var body: some View {
        if day.isLocked {
            // Locked day (beyond 30 days for free users): faded circle with lock
            VStack(spacing: 1) {
                ZStack {
                    Circle()
                        .fill(JW.Color.backgroundTertiary.opacity(0.4))
                        .frame(width: circleSize, height: circleSize)
                    Image(systemName: "lock.fill")
                        .font(.system(size: 9))
                        .foregroundStyle(JW.Color.textTertiary.opacity(0.6))
                }
                Color.clear.frame(height: 6)
            }
        } else if day.isInRange {
            VStack(spacing: 1) {
                ZStack {
                    // Shield takes visual priority - always show blue for shielded days
                    if day.shieldUsed {
                        // Shield used: solid blue circle with checkmark
                        Circle()
                            .fill(JW.Color.accentBlue)
                            .frame(width: circleSize, height: circleSize)
                        Image(systemName: "checkmark")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(.white)
                    } else if day.goalMet {
                        // Goal met: solid green circle with checkmark
                        Circle()
                            .fill(JW.Color.accent)
                            .frame(width: circleSize, height: circleSize)
                        Image(systemName: "checkmark")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(.white)
                    } else if hasPartialProgress {
                        // Partial progress: ring showing percentage
                        Circle()
                            .stroke(JW.Color.backgroundTertiary, lineWidth: 2.5)
                            .frame(width: ringSize, height: ringSize)
                        Circle()
                            .trim(from: 0, to: stepProgress)
                            .stroke(
                                JW.Color.accent.opacity(0.7),
                                style: StrokeStyle(lineWidth: 2.5, lineCap: .round)
                            )
                            .frame(width: ringSize, height: ringSize)
                            .rotationEffect(.degrees(-90))
                    } else {
                        // Missed with no steps: gray circle
                        Circle()
                            .fill(JW.Color.backgroundTertiary)
                            .frame(width: circleSize, height: circleSize)
                    }
                }
                .overlay {
                    if day.isToday {
                        Circle()
                            .stroke(JW.Color.accent, lineWidth: 2)
                            .frame(width: 44, height: 44)
                    }
                }

                // Shield indicator below (for shielded days)
                if day.shieldUsed {
                    Image(systemName: "shield.fill")
                        .font(.system(size: 6))
                        .foregroundStyle(JW.Color.accentBlue)
                } else {
                    Color.clear.frame(height: 6)
                }
            }
        } else {
            // Placeholder for out-of-range or future days
            VStack(spacing: 1) {
                Circle()
                    .fill(Color.clear)
                    .frame(width: circleSize, height: circleSize)
                Color.clear.frame(height: 6)
            }
        }
    }
}

#Preview {
    StreakDetailSheet()
}
