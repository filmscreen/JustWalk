//
//  WeekChartView.swift
//  JustWalk
//
//  7-day week strip showing daily goal completion with checkmark indicators
//

import SwiftUI
import StoreKit

// MARK: - Day Status

enum DayStatus: Equatable {
    case complete
    case missedNoData
    case shieldUsed
    case inProgress(Double) // 0.0 to 1.0
    case future
}

// MARK: - Day Data Model

struct DayData: Identifiable {
    let day: String         // "Mon", "Tue", etc.
    let dateLabel: String   // "1/25"
    let steps: Int
    let goal: Int
    let goalMet: Bool
    let shieldUsed: Bool
    let isToday: Bool
    let isWithinWeek: Bool
    let date: Date
    let isPastDay: Bool

    // Use date as stable ID to prevent view recreation on re-render
    var id: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }

    var stepProgress: Double {
        min(Double(steps) / Double(max(goal, 1)), 1.0)
    }

    /// Single-letter day label for compact display ("M", "T", "W", etc.)
    var shortLabel: String {
        let firstChar = day.prefix(1)
        // Disambiguate T (Tue/Thu) and S (Sat/Sun) using second character
        return String(firstChar)
    }

    var status: DayStatus {
        if !isWithinWeek { return .future }

        // For today: show goal complete (green) if met, otherwise show progress ring
        // Shield for today is just insurance while user is still walking
        if isToday {
            if goalMet { return .complete }
            return .inProgress(stepProgress)
        }

        // For past days: shield takes visual priority (user requested blue for all shielded days)
        if shieldUsed { return .shieldUsed }
        if goalMet { return .complete }
        if steps > 0 { return .inProgress(stepProgress) }
        return .missedNoData
    }

    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMM d"
        return formatter.string(from: date)
    }

    var distanceFormatted: String {
        let useMetric = PersistenceManager.shared.cachedUseMetric
        if useMetric {
            let km = Double(steps) * 0.0008
            return String(format: "%.1f km", km)
        } else {
            let mi = Double(steps) * 0.000497
            return String(format: "%.1f mi", mi)
        }
    }
}

// MARK: - Week Chart View

struct WeekChartView: View {
    var liveTodaySteps: Int

    init(liveTodaySteps: Int = 0) {
        self.liveTodaySteps = liveTodaySteps
    }

    private var persistence = PersistenceManager.shared
    @AppStorage("dailyStepGoal") private var dailyGoal = 5000
    @State private var selectedDay: DayData?
    @State private var appeared = false
    @State private var pressedDayID: String?

    private var weekData: [DayData] {
        // Access version counter so @Observable triggers re-render on log changes
        _ = persistence.dailyLogVersion

        let calendar = Calendar.current
        var data: [DayData] = []

        for offset in -6...0 {
            guard let date = calendar.date(byAdding: .day, value: offset, to: Date()) else { continue }
            let log = persistence.loadDailyLog(for: date)
            let weekdayIndex = calendar.component(.weekday, from: date) - 1
            let dayName = calendar.shortWeekdaySymbols[weekdayIndex]
            let month = calendar.component(.month, from: date)
            let dayNum = calendar.component(.day, from: date)
            let dateLabel = "\(month)/\(dayNum)"

            let isToday = offset == 0
            // For today, prefer live HealthKit steps over persisted log
            let steps = isToday ? liveTodaySteps : (log?.steps ?? 0)
            // For today, use current goal. For past days, use the stored historical goal.
            // If historical goal is missing (legacy data), fall back to current goal.
            let goal = isToday ? dailyGoal : (log?.goalTarget ?? dailyGoal)
            let goalMet = isToday ? (liveTodaySteps >= dailyGoal) : (log?.goalMet ?? false)
            let isPastDay = offset < 0

            data.append(DayData(
                day: dayName,
                dateLabel: dateLabel,
                steps: steps,
                goal: goal,
                goalMet: goalMet,
                shieldUsed: log?.shieldUsed ?? false,
                isToday: isToday,
                isWithinWeek: true,
                date: date,
                isPastDay: isPastDay
            ))
        }

        return data
    }

    private var totalWeekSteps: Int {
        weekData.reduce(0) { $0 + $1.steps }
    }

    private var locationInsight: WeeklyInsight {
        LocationInsightsService.shared.generateWeeklyInsight(weekSteps: totalWeekSteps)
    }

    private var daysCompleted: Int {
        weekData.filter { $0.goalMet || $0.shieldUsed }.count
    }

    private var weekSummary: String {
        let qualifier: String = switch daysCompleted {
        case 7: "perfect!"
        case 5...6: "strong!"
        case 3...4: "solid!"
        case 1...2: "keep going."
        default: "let's get started."
        }
        return "\(daysCompleted) of 7 days this week — \(qualifier)"
    }

    var body: some View {
        VStack(spacing: 12) {
            // Day indicators
            HStack(spacing: 0) {
                ForEach(Array(weekData.enumerated()), id: \.element.id) { index, day in
                    DayIndicator(day: day)
                        .scaleEffect(appeared ? 1 : 0.8)
                        .scaleEffect(pressedDayID == day.id ? 0.88 : 1.0)
                        .opacity(appeared ? 1 : 0)
                        .animation(
                            .spring(response: 0.3, dampingFraction: 0.7)
                            .delay(Double(index) * 0.05),
                            value: appeared
                        )
                        .animation(
                            .spring(response: 0.15, dampingFraction: 0.6),
                            value: pressedDayID
                        )
                        .onTapGesture {
                            pressedDayID = day.id
                            JustWalkHaptics.buttonTap()
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                pressedDayID = nil
                                selectedDay = day
                            }
                        }
                }
            }

            // Weekly summary + location insights
            VStack(spacing: JW.Spacing.sm) {
                Text(weekSummary)
                    .font(JW.Font.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(JW.Color.textPrimary)

                VStack(spacing: 2) {
                    Text(locationInsight.dataLine)
                        .font(JW.Font.caption)
                        .foregroundStyle(JW.Color.textSecondary)
                    Text(locationInsight.contextLine)
                        .font(JW.Font.caption)
                        .foregroundStyle(JW.Color.textTertiary)
                }
            }
            .multilineTextAlignment(.center)
        }
        .onAppear {
            withAnimation {
                appeared = true
            }
        }
        .onDisappear {
            appeared = false
        }
        .sheet(item: $selectedDay) { day in
            DayDetailSheet(data: day)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.hidden)
                .presentationBackground(Color(.systemBackground))
        }
    }
}

// MARK: - Day Indicator

struct DayIndicator: View {
    let day: DayData

    @State private var animatedProgress: Double?
    @State private var goalJustCompleted = false

    private let circleSize: CGFloat = 32
    private let ringSize: CGFloat = 36

    private var displayProgress: Double {
        animatedProgress ?? day.stepProgress
    }

    var body: some View {
        VStack(spacing: 6) {
            // Day label
            Text(day.shortLabel)
                .font(JW.Font.caption2)
                .foregroundStyle(day.isToday ? JW.Color.textPrimary : JW.Color.textSecondary)
                .fontWeight(day.isToday ? .semibold : .regular)

            // Status indicator
            ZStack {
                switch day.status {
                case .complete:
                    // Solid green circle with white checkmark
                    Circle()
                        .fill(JW.Color.success)
                        .frame(width: circleSize, height: circleSize)
                        .shadow(
                            color: day.isToday ? JW.Color.success.opacity(0.4) : .clear,
                            radius: day.isToday ? 6 : 0
                        )
                    Image(systemName: "checkmark")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.white)

                case .missedNoData:
                    // Dashed gray circle (no data)
                    Circle()
                        .stroke(
                            JW.Color.backgroundTertiary.opacity(0.6),
                            style: StrokeStyle(lineWidth: 2, dash: [4, 4])
                        )
                        .frame(width: circleSize, height: circleSize)

                case .shieldUsed:
                    // Blue circle with white checkmark (like complete, but blue)
                    Circle()
                        .fill(JW.Color.accentBlue)
                        .frame(width: circleSize, height: circleSize)
                    Image(systemName: "checkmark")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.white)

                case .inProgress(_):
                    // Mini progress ring
                    ZStack {
                        Circle()
                            .stroke(JW.Color.backgroundTertiary, lineWidth: 3)
                            .frame(width: ringSize, height: ringSize)
                        Circle()
                            .trim(from: 0, to: displayProgress)
                            .stroke(
                                progressRingColor,
                                style: StrokeStyle(lineWidth: 3, lineCap: .round)
                            )
                            .frame(width: ringSize, height: ringSize)
                            .rotationEffect(.degrees(-90))
                    }

                case .future:
                    Circle()
                        .fill(JW.Color.backgroundTertiary.opacity(0.2))
                        .frame(width: circleSize, height: circleSize)
                }
            }
            .frame(width: ringSize, height: ringSize)

            // Shield icon below circle (if shield was used)
            if day.shieldUsed {
                Image(systemName: "shield.fill")
                    .font(.system(size: 10))
                    .foregroundStyle(JW.Color.accentBlue)
                    .frame(height: 14)
            } else if day.isToday {
                Text("today")
                    .font(.system(size: 9, design: .rounded))
                    .foregroundStyle(JW.Color.textTertiary)
                    .frame(height: 14)
            } else {
                Spacer()
                    .frame(height: 14)
            }
        }
        .frame(maxWidth: .infinity)
        .contentShape(Rectangle())
        .onAppear {
            // Only animate on first appearance (when animatedProgress is nil)
            if animatedProgress == nil, case .inProgress(let progress) = day.status {
                // Start from 0 and animate to target
                animatedProgress = 0
                withAnimation(JustWalkAnimation.ringFill) {
                    animatedProgress = progress
                }
            }
        }
        .onChange(of: day.steps) { _, _ in
            if case .inProgress(let progress) = day.status {
                withAnimation(JustWalkAnimation.standard) {
                    animatedProgress = progress
                }
            }
        }
    }

    private var progressRingColor: Color {
        if day.isToday {
            return JW.Color.accent
        }
        return JW.Color.accent.opacity(0.7)
    }
}

// MARK: - Day Detail State

private enum DayDetailState {
    case goalMet
    case goalMissed
    case shieldUsed
    case restDay
    case streakBroken
    case lightDayShielded

    var primaryText: String {
        switch self {
        case .goalMet, .goalMissed: return ""
        case .restDay: return "Rest day"
        case .shieldUsed: return "Shield used"
        case .streakBroken: return "Missed"
        case .lightDayShielded: return "Light day"
        }
    }

    var secondaryText: String? {
        switch self {
        case .restDay: return "That's okay — you showed up the next day."
        case .shieldUsed: return "A shield protected your streak. Life happens."
        case .streakBroken: return "Every streak starts somewhere. Ready to begin again?"
        case .lightDayShielded: return "A shield kept your streak alive."
        default: return nil
        }
    }
}

// MARK: - Day Detail Sheet

struct DayDetailSheet: View {
    let data: DayData

    @Environment(\.dismiss) private var dismiss
    @State private var walks: [TrackedWalk] = []
    @State private var dayState: DayDetailState = .goalMet
    @State private var showShieldConfirmation = false
    @State private var shieldApplied = false
    @State private var showPaywall = false
    @State private var showPurchaseSheet = false

    private var shieldManager: ShieldManager { ShieldManager.shared }
    private var subscriptionManager: SubscriptionManager { SubscriptionManager.shared }

    /// Whether this day is eligible for repair (within 7 days including today, not already met/shielded)
    private var dayIsRepairable: Bool {
        guard !data.goalMet && !data.shieldUsed else { return false }
        return shieldManager.canRepairDate(data.date)
    }

    /// Whether this day can be repaired with a shield (has shields available)
    private var canRepairWithShield: Bool {
        dayIsRepairable && shieldManager.availableShields > 0
    }

    /// Whether to show purchase prompt (day is repairable but no shields)
    private var shouldShowPurchasePrompt: Bool {
        dayIsRepairable && shieldManager.availableShields == 0
    }

    // MARK: - Walk Helpers

    private func walkModeIcon(_ mode: WalkMode) -> String {
        switch mode {
        case .free: return "figure.walk"
        case .interval: return "waveform.path"
        case .fatBurn: return "heart.fill"
        case .postMeal: return "fork.knife"
        }
    }

    private func walkModeColor(_ mode: WalkMode) -> Color {
        switch mode {
        case .free: return JW.Color.accent
        case .interval: return JW.Color.accentBlue
        case .fatBurn: return JW.Color.streak
        case .postMeal: return JW.Color.accentPurple
        }
    }

    private func walkModeName(_ mode: WalkMode) -> String {
        switch mode {
        case .free: return "Free Walk"
        case .interval: return "Interval Walk"
        case .fatBurn: return "Fat Burn Zone"
        case .postMeal: return "Post-Meal Walk"
        }
    }

    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: date)
    }

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            // FIXED HEADER: Drag indicator + Date + Stats
            VStack(spacing: 16) {
                // Drag indicator
                Capsule()
                    .fill(Color.secondary.opacity(0.5))
                    .frame(width: 36, height: 5)
                    .padding(.top, 8)

                // Date header
                Text(data.formattedDate)
                    .font(.headline)
                    .foregroundStyle(JW.Color.textPrimary)

                // Content based on day state (steps/distance/goal - always visible)
                switch dayState {
                case .goalMet, .goalMissed:
                    stepsContent
                case .restDay, .streakBroken:
                    missedContent
                case .shieldUsed, .lightDayShielded:
                    shieldContent
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 16)

            Divider()

            // SCROLLABLE MIDDLE: Walk list (expands to fill available space)
            if walks.isEmpty {
                VStack {
                    Spacer()
                    if dayState == .goalMet || dayState == .goalMissed {
                        Text("No walks recorded")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                }
                .frame(maxWidth: .infinity)
            } else {
                ScrollView {
                    walksSection
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                }
                .frame(maxWidth: .infinity)
            }

            Spacer(minLength: 0)

            Divider()

            // FIXED FOOTER: Shield buttons + Done
            VStack(spacing: 12) {
                // Use Shield button (for missed days that can be repaired)
                if canRepairWithShield && !shieldApplied {
                    useShieldButton
                }

                // Purchase prompt (when day is repairable but no shields available)
                if shouldShowPurchasePrompt && !shieldApplied {
                    purchaseShieldButton
                }

                // Done button
                Button("Done") { dismiss() }
                    .font(.headline)
                    .foregroundStyle(JW.Color.accent)
            }
            .padding(.horizontal, 24)
            .padding(.top, 16)
            .padding(.bottom, 24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
        .onAppear {
            determineDayState()
            loadWalks()
        }
        .alert("Use Shield?", isPresented: $showShieldConfirmation) {
            Button("Use Shield", role: .destructive) {
                applyShield()
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Use 1 shield to protect your streak for this day. You have \(shieldManager.availableShields) shield\(shieldManager.availableShields == 1 ? "" : "s") remaining.")
        }
        .sheet(isPresented: $showPaywall) {
            ProUpgradeView(onComplete: { showPaywall = false })
        }
        .sheet(isPresented: $showPurchaseSheet) {
            ShieldPurchaseSheet(
                isPro: subscriptionManager.isPro,
                onShieldPurchased: { applyShield() },
                onRequestProUpgrade: { showPaywall = true }
            )
        }
    }

    // MARK: - Use Shield Button

    private var useShieldButton: some View {
        Button {
            JustWalkHaptics.buttonTap()
            showShieldConfirmation = true
        } label: {
            HStack(spacing: JW.Spacing.sm) {
                Image(systemName: "shield.fill")
                    .font(.system(size: 16))
                Text("Use Shield to Repair")
                    .font(JW.Font.headline)
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(JW.Color.accentBlue)
            .clipShape(RoundedRectangle(cornerRadius: JW.Radius.lg))
        }
        .padding(.bottom, JW.Spacing.sm)
    }

    private func applyShield() {
        if shieldManager.repairDate(data.date) {
            shieldApplied = true
            JustWalkHaptics.success()
            // Update the day state to reflect the shield was used
            dayState = .shieldUsed
        }
    }

    // MARK: - Upgrade for Shields Button

    private var purchaseShieldButton: some View {
        Button {
            JustWalkHaptics.buttonTap()
            showPurchaseSheet = true
        } label: {
            HStack(spacing: JW.Spacing.sm) {
                Image(systemName: "shield.fill")
                    .font(.system(size: 16))
                Text("Get Shield to Repair")
                    .font(JW.Font.headline)
                Spacer()
                Text(subscriptionManager.shieldDisplayPrice)
                    .font(JW.Font.subheadline.weight(.semibold))
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(JW.Color.accentBlue)
            .clipShape(RoundedRectangle(cornerRadius: JW.Radius.lg))
        }
        .padding(.bottom, JW.Spacing.sm)
    }

    // MARK: - Steps Content (Goal Met / Goal Missed)

    private var stepsContent: some View {
        VStack(spacing: JW.Spacing.xs) {
            Text("\(data.steps.formatted())")
                .font(.system(size: 48, weight: .bold, design: .rounded))
                .foregroundStyle(JW.Color.textPrimary)

            Text("steps")
                .font(JW.Font.subheadline)
                .foregroundStyle(JW.Color.textSecondary)

            // Combined stats line: distance · goal status
            HStack(spacing: 6) {
                Text(data.distanceFormatted)
                    .foregroundStyle(JW.Color.textSecondary)

                Text("·")
                    .foregroundStyle(JW.Color.textTertiary)

                if data.goalMet {
                    Image(systemName: "checkmark")
                        .font(.caption2.bold())
                        .foregroundStyle(JW.Color.success)
                    Text("Goal: \(data.goal.formatted())")
                        .foregroundStyle(JW.Color.textSecondary)
                } else {
                    Text("Goal: \(data.goal.formatted())")
                        .foregroundStyle(JW.Color.textTertiary)
                }
            }
            .font(JW.Font.caption)
            .padding(.top, JW.Spacing.xs)
        }
    }

    // MARK: - Missed Content (Rest Day / Streak Broken)

    private var missedContent: some View {
        VStack(spacing: JW.Spacing.sm) {
            Text(dayState.primaryText)
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundStyle(JW.Color.textPrimary)

            Text("No walks recorded")
                .font(JW.Font.subheadline)
                .foregroundStyle(JW.Color.textTertiary)

            if let secondary = dayState.secondaryText {
                Divider()
                    .overlay(JW.Color.backgroundTertiary)

                Text(secondary)
                    .font(JW.Font.subheadline)
                    .foregroundStyle(JW.Color.textSecondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    // MARK: - Shield Content

    private var shieldContent: some View {
        VStack(spacing: JW.Spacing.sm) {
            HStack(spacing: JW.Spacing.sm) {
                Image(systemName: "shield.fill")
                    .font(.system(size: 20))
                    .foregroundStyle(JW.Color.accentBlue)
                Text(dayState.primaryText)
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(JW.Color.textPrimary)
            }

            if data.steps > 0 {
                HStack(spacing: 6) {
                    Text("\(data.steps.formatted()) steps")
                    Text("·")
                        .foregroundStyle(JW.Color.textTertiary)
                    Text(data.distanceFormatted)
                }
                .font(JW.Font.subheadline)
                .foregroundStyle(JW.Color.textSecondary)

                Text("Goal: \(data.goal.formatted()) (missed)")
                    .font(JW.Font.caption)
                    .foregroundStyle(JW.Color.textTertiary)
            }

            if let secondary = dayState.secondaryText {
                Divider()
                    .overlay(JW.Color.backgroundTertiary)

                Text(secondary)
                    .font(JW.Font.subheadline)
                    .foregroundStyle(JW.Color.textSecondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    // MARK: - Walks Section

    private var walksSection: some View {
        VStack(alignment: .leading, spacing: JW.Spacing.md) {
            Text("Walks")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(JW.Color.textTertiary)
                .frame(maxWidth: .infinity, alignment: .leading)

            ForEach(walks) { walk in
                HStack(spacing: JW.Spacing.md) {
                    // Walk type icon
                    Image(systemName: walkModeIcon(walk.mode))
                        .font(.subheadline)
                        .foregroundStyle(walkModeColor(walk.mode))
                        .frame(width: 20)

                    // Walk info
                    VStack(alignment: .leading, spacing: 2) {
                        Text(walkModeName(walk.mode))
                            .font(JW.Font.subheadline)
                            .fontWeight(.medium)
                            .foregroundStyle(JW.Color.textPrimary)
                        Text("\(formatTime(walk.startTime)) · \(walk.durationMinutes) min")
                            .font(JW.Font.caption)
                            .foregroundStyle(JW.Color.textTertiary)
                    }

                    Spacer()

                    // Step count
                    Text("\(walk.steps.formatted()) steps")
                        .font(JW.Font.subheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(JW.Color.accent)
                }
            }
        }
    }

    // MARK: - State Determination

    private func determineDayState() {
        if data.goalMet {
            dayState = .goalMet
            return
        }

        if data.shieldUsed {
            if data.steps > 0 && Double(data.steps) < Double(data.goal) * 0.5 {
                dayState = .lightDayShielded
            } else {
                dayState = .shieldUsed
            }
            return
        }

        if data.steps == 0 {
            // Check if the user showed up the next day
            let calendar = Calendar.current
            if let nextDay = calendar.date(byAdding: .day, value: 1, to: data.date),
               let log = PersistenceManager.shared.loadDailyLog(for: nextDay),
               log.goalMet {
                dayState = .restDay
            } else {
                dayState = .streakBroken
            }
            return
        }

        dayState = .goalMissed
    }

    private func loadWalks() {
        // Query walks directly by date instead of relying on trackedWalkIDs in DailyLog
        walks = PersistenceManager.shared.loadTrackedWalks(forDay: data.date)
            .filter(\.isDisplayable)
            .sorted { $0.startTime < $1.startTime }
    }
}

// MARK: - Extended Week Chart (with step bars)

struct ExtendedWeekChartView: View {
    private var persistence = PersistenceManager.shared
    @AppStorage("dailyStepGoal") private var dailyGoal = 5000

    private var weekData: [ExtendedDayData] {
        _ = persistence.dailyLogVersion

        let calendar = Calendar.current
        var data: [ExtendedDayData] = []

        for offset in -6...0 {
            guard let date = calendar.date(byAdding: .day, value: offset, to: Date()) else { continue }
            let log = persistence.loadDailyLog(for: date)
            let weekdayIndex = calendar.component(.weekday, from: date) - 1
            let dayName = calendar.shortWeekdaySymbols[weekdayIndex]

            let isToday = offset == 0
            // For today, use current goal. For past days, use stored historical goal.
            let goal = isToday ? dailyGoal : (log?.goalTarget ?? dailyGoal)

            data.append(ExtendedDayData(
                day: dayName,
                steps: log?.steps ?? 0,
                goal: goal,
                goalMet: log?.goalMet ?? false,
                shieldUsed: log?.shieldUsed ?? false,
                isToday: isToday
            ))
        }

        return data
    }

    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            ForEach(weekData.indices, id: \.self) { index in
                ExtendedWeekDayColumn(data: weekData[index])
                    .staggeredAppearance(index: index)
            }
        }
    }
}

struct ExtendedDayData: Identifiable {
    let id = UUID()
    let day: String
    let steps: Int
    let goal: Int
    let goalMet: Bool
    let shieldUsed: Bool
    let isToday: Bool

    var progress: Double {
        min(Double(steps) / Double(max(goal, 1)), 1.0)
    }
}

struct ExtendedWeekDayColumn: View {
    let data: ExtendedDayData

    @State private var animatedHeight: CGFloat = 0

    private var barColor: Color {
        if data.shieldUsed { return JW.Color.accentBlue }
        if data.goalMet { return JW.Color.success }
        return JW.Color.accent
    }

    private let maxBarHeight: CGFloat = 60

    var body: some View {
        VStack(spacing: 6) {
            // Step bar
            ZStack(alignment: .bottom) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(JW.Color.backgroundTertiary)
                    .frame(width: 24, height: maxBarHeight)

                RoundedRectangle(cornerRadius: 4)
                    .fill(barColor)
                    .frame(width: 24, height: animatedHeight)
            }

            // Status indicator
            ZStack {
                if data.shieldUsed {
                    // Blue checkmark circle (like goal met, but blue)
                    Image(systemName: "checkmark.circle.fill")
                        .font(JW.Font.caption2)
                        .foregroundStyle(JW.Color.accentBlue)
                } else if data.goalMet {
                    Image(systemName: "checkmark.circle.fill")
                        .font(JW.Font.caption2)
                        .foregroundStyle(JW.Color.success)
                } else {
                    Circle()
                        .fill(JW.Color.backgroundTertiary)
                        .frame(width: 12, height: 12)
                }
            }
            .frame(height: 16)

            // Day label
            Text(data.day)
                .font(JW.Font.caption2)
                .foregroundStyle(data.isToday ? JW.Color.textPrimary : JW.Color.textSecondary)
                .fontWeight(data.isToday ? .semibold : .regular)
        }
        .frame(maxWidth: .infinity)
        .onAppear {
            withAnimation(JustWalkAnimation.ringFill) {
                animatedHeight = maxBarHeight * data.progress
            }
        }
    }
}

#Preview {
    VStack(spacing: 40) {
        WeekChartView()
            .frame(height: 80)
            .padding(.horizontal)

        ExtendedWeekChartView()
            .frame(height: 120)
            .padding(.horizontal)
    }
}
