//
//  StreakChainView.swift
//  Just Walk
//
//  Horizontal scrollable streak chain visualization showing the last 45 days
//  as connected circles with gap interaction for protecting missed days.
//

import SwiftUI

struct StreakChainView: View {
    let days: [DayStepData]  // Last 45 days, most recent first
    let dailyGoal: Int
    let streakService: StreakService
    var onProtectRequest: (DayStepData) -> Void

    // Circle sizing
    private let circleSize: CGFloat = 36
    private let connectorWidth: CGFloat = 2
    private let connectorLength: CGFloat = 8

    // Protectable window: only last 14 days can be shielded
    private let protectableWindowDays = 14

    // Animation state for pulsing glow on protectable circles
    @State private var protectablePulse = false
    @State private var todayPulse = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if days.isEmpty {
                emptyStateView
            } else {
                ScrollViewReader { proxy in
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 0) {  // Manual spacing via connectors
                            ForEach(Array(days.reversed().enumerated()), id: \.element.id) { index, day in
                                HStack(spacing: 0) {
                                    // Connector line (before circle, except for first)
                                    if index > 0 {
                                        connectorLine
                                    }

                                    // Day circle
                                    dayCircle(day: day)
                                        .id(day.id)
                                }
                            }
                        }
                        .padding(.leading, 16)  // 16pt leading content padding
                        .padding(.trailing, 16)
                        .padding(.vertical, 12)
                    }
                    .onAppear {
                        // Auto-scroll to today (rightmost)
                        if let todayData = days.first {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                withAnimation {
                                    proxy.scrollTo(todayData.id, anchor: .trailing)
                                }
                            }
                        }
                        // Start pulsing animations
                        protectablePulse = true
                        todayPulse = true
                    }
                    .accessibilityElement(children: .contain)
                    .accessibilityLabel("Streak history for the last \(days.count) days")
                    .accessibilityValue(streakChainAccessibilityValue)
                }

                // Hint for protectable days
                if hasProtectableDays {
                    let count = days.filter { canProtect(day: $0) }.count
                    Text("\(count) day\(count == 1 ? "" : "s") to protect · Tap to use a shield")
                        .font(.system(size: 13, weight: .regular))
                        .foregroundStyle(Color(hex: "FF9500"))
                        .padding(.horizontal, 16)
                }
            }
        }
    }

    // MARK: - Empty State

    private var emptyStateView: some View {
        VStack(spacing: 12) {
            HStack(spacing: 4) {
                ForEach(0..<3, id: \.self) { _ in
                    Circle()
                        .stroke(Color.gray.opacity(0.2), lineWidth: 1.5)
                        .frame(width: 20, height: 20)
                    Rectangle()
                        .fill(Color.gray.opacity(0.2))
                        .frame(width: 8, height: 2)
                }

                VStack(spacing: 4) {
                    Circle()
                        .stroke(Color(hex: "00C7BE").opacity(0.5), lineWidth: 2)
                        .frame(width: circleSize, height: circleSize)
                    Text("Today")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(Color(.secondaryLabel))
                }
            }
            .padding(.vertical, 8)

            Text("Hit your goal today to start your streak")
                .font(.system(size: 15, weight: .regular))
                .foregroundStyle(Color(.secondaryLabel))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("No streak history yet. Hit your goal today to start your streak.")
    }

    // MARK: - Computed Properties

    private var hasProtectableDays: Bool {
        days.contains { canProtect(day: $0) }
    }

    private var streakChainAccessibilityValue: String {
        let protectableDays = days.filter { canProtect(day: $0) }.count
        let currentStreak = streakService.currentStreak
        if protectableDays > 0 {
            return "\(currentStreak) day streak. \(protectableDays) missed days can be protected."
        } else {
            return "\(currentStreak) day streak."
        }
    }

    // MARK: - Connector Line

    private var connectorLine: some View {
        Rectangle()
            .fill(Color(hex: "00C7BE"))
            .frame(width: connectorLength, height: connectorWidth)
    }

    // MARK: - Day Circle

    @ViewBuilder
    private func dayCircle(day: DayStepData) -> some View {
        let calendar = Calendar.current
        let isToday = calendar.isDateInToday(day.date)
        let goalMet = day.isGoalMet
        let isShielded = streakService.isDateShielded(day.date)
        let isProtectable = canProtect(day: day)

        VStack(spacing: 4) {
            ZStack {
                // State 1: Completed day (goal met) - filled teal
                if goalMet && !isShielded {
                    Circle()
                        .fill(Color(hex: "00C7BE"))
                        .frame(width: circleSize, height: circleSize)
                }

                // State 2: Protected day (shield used) - teal fill + shield badge
                if isShielded {
                    Circle()
                        .fill(Color(hex: "00C7BE"))
                        .frame(width: circleSize, height: circleSize)

                    // Shield badge - bottom right corner (14pt badge, 10pt icon)
                    ZStack {
                        Circle()
                            .fill(Color(hex: "00A3A0"))  // Darker teal for contrast
                            .frame(width: 14, height: 14)
                            .shadow(color: .black.opacity(0.15), radius: 1, x: 0, y: 1)
                        Image(systemName: "shield.fill")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(.white)
                    }
                    .offset(x: 12, y: 12)
                }

                // State 3: Today in progress - half-filled (bottom half teal, top half track)
                if isToday && !goalMet && !isShielded {
                    ZStack {
                        // Track (full circle, light gray)
                        Circle()
                            .fill(Color(hex: "D1D1D6").opacity(0.3))
                            .frame(width: circleSize, height: circleSize)

                        // Bottom half fill (teal)
                        Circle()
                            .fill(Color(hex: "00C7BE"))
                            .frame(width: circleSize, height: circleSize)
                            .mask(
                                Rectangle()
                                    .frame(width: circleSize, height: circleSize / 2)
                                    .offset(y: circleSize / 4)
                            )
                    }
                    .shadow(
                        color: Color(hex: "00C7BE").opacity(todayPulse ? 0.3 : 0.1),
                        radius: todayPulse ? 8 : 4
                    )
                    .animation(
                        .easeInOut(duration: 1.5).repeatForever(autoreverses: true),
                        value: todayPulse
                    )
                }

                // State 4: Missed protectable (within 14 days) - ORANGE border with pulse
                if !goalMet && !isShielded && !isToday && isProtectable {
                    Circle()
                        .stroke(Color(hex: "FF9500"), lineWidth: 2)
                        .frame(width: circleSize, height: circleSize)
                        .shadow(
                            color: Color(hex: "FF9500").opacity(protectablePulse ? 0.4 : 0.1),
                            radius: protectablePulse ? 6 : 3
                        )
                        .animation(
                            .easeInOut(duration: 1.2).repeatForever(autoreverses: true),
                            value: protectablePulse
                        )
                }

                // State 5: Missed too old (can't protect) - gray border
                if !goalMet && !isShielded && !isToday && !isProtectable {
                    Circle()
                        .stroke(Color(hex: "D1D1D6"), lineWidth: 1.5)
                        .frame(width: circleSize, height: circleSize)
                }
            }
            .onTapGesture {
                if isProtectable {
                    onProtectRequest(day)
                    HapticService.shared.playSelection()
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(dayAccessibilityLabel(for: day, isProtectable: isProtectable, goalMet: goalMet, isShielded: isShielded))
            .accessibilityHint(isProtectable ? "Double tap to protect this day with a shield" : "")
            .accessibilityAddTraits(isProtectable ? .isButton : [])

            // Day label (3-letter abbreviation)
            Text(dayAbbreviation(for: day.date))
                .font(.system(size: 13, weight: isToday ? .semibold : .regular))
                .foregroundStyle(isToday ? .primary : Color(hex: "8E8E93"))
        }
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

    private func dayAbbreviation(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "d"  // Day number: 14, 15, 16
        return formatter.string(from: date)
    }

    private func dayAccessibilityLabel(for day: DayStepData, isProtectable: Bool, goalMet: Bool, isShielded: Bool) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMMM d"
        let dateStr = formatter.string(from: day.date)

        if goalMet {
            return "\(dateStr). Goal met."
        } else if isShielded {
            return "\(dateStr). Protected with shield."
        } else if isProtectable {
            let stepsShort = max(0, dailyGoal - day.steps)
            return "\(dateStr). Missed. \(stepsShort.formatted()) steps short."
        } else {
            return "\(dateStr). Missed."
        }
    }
}

// MARK: - Preview

#Preview {
    let calendar = Calendar.current
    let today = Date()

    let sampleData: [DayStepData] = (0..<45).map { dayOffset in
        let date = calendar.date(byAdding: .day, value: -dayOffset, to: today)!
        let steps = [12500, 8000, 10500, 6000, 11000, 9500, 7500, 0, 4000, 15000].randomElement()!
        return DayStepData(date: date, steps: steps, distance: Double(steps) * 0.762, historicalGoal: 10000)
    }

    return VStack {
        Text("Streak Chain Preview")
            .font(.headline)

        StreakChainView(
            days: sampleData,
            dailyGoal: 10000,
            streakService: StreakService.shared,
            onProtectRequest: { day in
                print("Protect requested for: \(day.date)")
            }
        )
    }
    .padding()
}
