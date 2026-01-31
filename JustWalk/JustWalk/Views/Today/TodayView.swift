//
//  TodayView.swift
//  JustWalk
//
//  Main Today screen: step ring, streak, week strip, shields pill, dynamic card
//

import SwiftUI
import WidgetKit

struct TodayView: View {
    @Environment(AppState.self) private var appState

    @StateObject private var healthKitManager = HealthKitManager.shared
    private var streakManager = StreakManager.shared
    private var shieldManager = ShieldManager.shared
    @StateObject private var dynamicCardEngine = DynamicCardEngine.shared
    private var persistence = PersistenceManager.shared

    @AppStorage("dailyStepGoal") private var dailyGoal = 5000
    private var todaySteps: Int { healthKitManager.todaySteps }
    @State private var showStreakDetail = false
    @State private var showShieldDetail = false
    @State private var showProPaywall = false
    @State private var showMilestonePrompt = false
    @State private var milestoneStreakDays: Int = 0
    @State private var renderedCard: DynamicCardType = .tip(DailyTip.allTips[0])
    @AppStorage("hasSeenStreakMilestoneProPrompt") private var hasSeenMilestonePrompt = false
    #if DEBUG
    @State private var showDebugOverlay = false
    #endif

    private var headline: String {
        let steps = todaySteps
        let goal = max(dailyGoal, 1)
        let streak = streakManager.streakData.currentStreak
        let longest = streakManager.streakData.longestStreak
        let hour = Calendar.current.component(.hour, from: Date())

        // P1: Milestone hit today
        let milestones: [Int: String] = [
            7: "One Week.",
            14: "Two Weeks.",
            21: "Three Weeks.",
            30: "One Month.",
            60: "Two Months.",
            90: "Three Months.",
            180: "Six Months.",
            365: "One Year."
        ]
        if let milestone = milestones[streak] {
            return milestone
        }

        // P2: New streak record
        if streak >= longest && streak > 1 {
            return "New Record."
        }

        // P3: Big step day (150%+ of goal)
        if steps >= goal && steps >= Int(Double(goal) * 1.5) {
            return "What a Day."
        }

        // P4: Goal complete - with clutch save and pattern variants
        if steps >= goal {
            let minute = Calendar.current.component(.minute, from: Date())
            // After 11:30pm
            if hour == 23 && minute >= 30 {
                return "Under the wire."
            }
            // After 10:30pm
            if hour >= 23 || (hour == 22 && minute >= 30) {
                return "Clutch."
            }
            // Hardest day conquered
            if let hardestDay = PatternManager.shared.snapshot().cachedHardestDay {
                let todayWeekday = Calendar.current.component(.weekday, from: Date()) - 1
                if todayWeekday == hardestDay {
                    return PatternCopy.hardestDayConqueredHeadline(hardestDay)
                }
            }
            return "Nailed It."
        }

        // P5: On track based on time of day
        let expectedRatio: Double = switch hour {
        case 0..<12: 0.3
        case 12..<18: 0.6
        case 18..<21: 0.8
        default: 0.95
        }
        let actualRatio = Double(steps) / Double(goal)
        if actualRatio >= expectedRatio * 0.9 && steps > 0 {
            return "Looking Good."
        }

        // P6: Streak at risk (evening + far from goal)
        if hour >= 19 && streak >= 3 && steps < goal {
            return "Still Time."
        }

        // P7: Pattern-aware encouragement (hardest day, near typical time, best day)
        let patterns = PatternManager.shared.snapshot()
        let todayWeekday = Calendar.current.component(.weekday, from: Date()) - 1

        // On hardest day (goal not met)
        if let hardestDay = patterns.cachedHardestDay, todayWeekday == hardestDay {
            return PatternCopy.hardestDayEncouragement(hardestDay)
        }

        // Near typical walk time
        if let typicalHour = patterns.cachedTypicalHour, abs(hour - typicalHour) <= 1 {
            return PatternCopy.nearTypicalTime
        }

        // On best day
        if let bestDay = patterns.cachedBestDay, todayWeekday == bestDay {
            return PatternCopy.bestDay
        }

        // P8: Behind but recoverable
        if steps > 0 && steps < goal {
            return "Keep Moving."
        }

        // P9: Morning
        if hour < 12 {
            return "Let's Go."
        }

        // P10: Default
        return "Your Day."
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                // Headline
                Text(headline)
                    .font(.title.bold())
                    .foregroundStyle(JW.Color.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .id(headline)
                    .transition(.asymmetric(
                        insertion: .move(edge: .bottom).combined(with: .opacity),
                        removal: .opacity
                    ))
                    .animation(.spring(response: 0.4, dampingFraction: 0.8), value: headline)
                    .padding(.horizontal)
                    .padding(.top, JW.Spacing.sm)
                    .staggeredAppearance(index: 0, delay: 0.05)
                    .padding(.bottom, JW.Spacing.xxl)         // 32pt → ring

                // Hero Ring
                StepRingView(
                    steps: todaySteps,
                    goal: dailyGoal
                )
                .bounceIn(delay: 0.1)
                #if DEBUG
                .onTapGesture(count: 3) {
                    showDebugOverlay = true
                }
                #endif
                .padding(.bottom, JW.Spacing.xxl)           // 32pt → pills row

                // Streak & Shields Pills (centered)
                HStack(spacing: JW.Spacing.md) {
                    StreakPill(
                        streak: streakManager.streakData.currentStreak,
                        longestStreak: streakManager.streakData.longestStreak,
                        onTap: { showStreakDetail = true }
                    )

                    ShieldsPill(
                        count: shieldManager.availableShields,
                        isWarning: shieldManager.availableShields == 0
                            && streakManager.streakData.currentStreak >= 7
                    ) {
                        showShieldDetail = true
                    }
                }
                .staggeredAppearance(index: 1, delay: 0.05)
                .padding(.bottom, JW.Spacing.xl)             // 24pt → week chart

                // Week Chart
                WeekChartView(liveTodaySteps: todaySteps)
                    .padding(.vertical, JW.Spacing.lg)
                    .padding(.horizontal, JW.Spacing.sm)
                    .jwCard()
                    .padding(.horizontal)
                    .staggeredAppearance(index: 2, delay: 0.05)
                    .padding(.bottom, JW.Spacing.lg)

                // Dynamic Card (always visible — never empty)
                DynamicCardView(cardType: renderedCard, onAction: { action in
                    handleCardAction(action)
                })
                .id(renderedCard.cardKey)
                .transition(.asymmetric(
                    insertion: .move(edge: .bottom).combined(with: .opacity),
                    removal: .move(edge: .trailing).combined(with: .opacity)
                ))
                .padding(.horizontal)
                .staggeredAppearance(index: 3, delay: 0.05)

                Spacer(minLength: 60)
            }
        }
        .background(JW.Color.backgroundPrimary)
        .toolbar(.hidden, for: .navigationBar)
        .onAppear {
            // Track last app open time for notification suppression
            UserDefaults.standard.set(Date(), forKey: "lastAppOpenTime")

            Task {
                // Fetch weather in background (for Smart Walk Card enhancement)
                await WeatherManager.shared.fetchWeatherIfNeeded()

                let steps = await healthKitManager.fetchTodaySteps(force: true)
                withAnimation(JustWalkAnimation.standard) {
                    dynamicCardEngine.refresh(dailyGoal: dailyGoal, currentSteps: steps)
                    renderedCard = dynamicCardEngine.currentCard
                }
                pushWidgetData()
                checkStreakPaywallTrigger()
            }
        }
        .refreshable {
            JustWalkHaptics.selectionChanged()
            let steps = await healthKitManager.fetchTodaySteps(force: true)
            withAnimation(JustWalkAnimation.standard) {
                dynamicCardEngine.refresh(dailyGoal: dailyGoal, currentSteps: steps)
                renderedCard = dynamicCardEngine.currentCard
            }
            pushWidgetData()
        }
        .onChange(of: persistence.dailyLogVersion) { _, _ in
            Task {
                let steps = await healthKitManager.fetchTodaySteps(force: true)
                withAnimation(JustWalkAnimation.standard) {
                    dynamicCardEngine.refresh(dailyGoal: dailyGoal, currentSteps: steps)
                    renderedCard = dynamicCardEngine.currentCard
                }
                pushWidgetData()
            }
        }
        .onReceive(dynamicCardEngine.$currentCard) { newCard in
            renderedCard = newCard
        }
        .sheet(isPresented: $showStreakDetail) {
            StreakDetailSheet()
        }
        .sheet(isPresented: $showShieldDetail) {
            ShieldDetailSheet()
        }
        .sheet(isPresented: $showProPaywall) {
            ProUpgradeView(onComplete: { showProPaywall = false })
        }
        .sheet(isPresented: $showMilestonePrompt) {
            StreakMilestonePrompt(
                streakDays: milestoneStreakDays,
                onUpgrade: {
                    showMilestonePrompt = false
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                        showProPaywall = true
                    }
                },
                onDismiss: {
                    showMilestonePrompt = false
                }
            )
        }
        .onChange(of: streakManager.lastReachedMilestone) { _, milestone in
            guard let milestone, milestone == 7 else { return }
            guard !hasSeenMilestonePrompt else { return }
            guard !SubscriptionManager.shared.isPro else { return }

            hasSeenMilestonePrompt = true
            milestoneStreakDays = milestone
            streakManager.clearLastReachedMilestone()

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                showMilestonePrompt = true
            }
        }
        #if DEBUG
        .overlay {
            if showDebugOverlay {
                DebugOverlayView(isPresented: $showDebugOverlay)
            }
        }
        #endif
    }

    private func handleCardAction(_ action: CardAction) {
        // Mark card as acted upon and re-evaluate
        dynamicCardEngine.markAsActedUpon(dynamicCardEngine.currentCard)
        withAnimation(JustWalkAnimation.standard) {
            dynamicCardEngine.refresh(dailyGoal: dailyGoal, currentSteps: todaySteps)
        }

        // Route action to WalksHomeView via AppState
        appState.pendingCardAction = action
        appState.selectedTab = .walks
    }

    private func checkStreakPaywallTrigger() {
        let subscriptionManager = SubscriptionManager.shared
        guard !subscriptionManager.isPro else { return }
        guard shieldManager.availableShields == 0 else { return }
        guard streakManager.streakData.currentStreak >= 3 else { return }
        guard todaySteps < dailyGoal else { return }

        // Check if already shown today
        let lastShownKey = "lastStreakPaywallDate"
        let todayString: String = {
            let f = DateFormatter()
            f.dateFormat = "yyyy-MM-dd"
            return f.string(from: Date())
        }()
        guard UserDefaults.standard.string(forKey: lastShownKey) != todayString else { return }

        showProPaywall = true
        UserDefaults.standard.set(todayString, forKey: lastShownKey)
    }

    private func pushWidgetData() {
        let goal = dailyGoal
        let streak = streakManager.streakData.currentStreak
        let calendar = Calendar.current
        let persistence = PersistenceManager.shared
        let weekSteps = (-6...0).map { offset -> Int in
            guard let date = calendar.date(byAdding: .day, value: offset, to: Date()) else { return 0 }
            return persistence.loadDailyLog(for: date)?.steps ?? 0
        }
        // Compute walk time inline for widget data
        let log = persistence.loadDailyLog(for: Date())
        let walkTime: Int = {
            guard let ids = log?.trackedWalkIDs else { return 0 }
            return ids.compactMap { persistence.loadTrackedWalk(by: $0) }
                .filter(\.isDisplayable)
                .reduce(0) { $0 + $1.durationMinutes }
        }()
        JustWalkWidgetData.updateWidgetData(
            todaySteps: todaySteps,
            stepGoal: goal,
            currentStreak: streak,
            weekSteps: weekSteps,
            shieldCount: shieldManager.availableShields,
            walkTimeMinutes: walkTime
        )
    }
}

// MARK: - Streak Pill

struct StreakPill: View {
    let streak: Int
    let longestStreak: Int
    let onTap: () -> Void

    @State private var isFlameAnimating = false

    private var flameColor: Color {
        switch streak {
        case 0:
            return .gray
        case 1...6:
            return JW.Color.streak
        case 7...29:
            return JW.Color.streak
        case 30...99:
            return JW.Color.danger
        case 100...:
            return JW.Color.accentPurple
        default:
            return JW.Color.streak
        }
    }

    /// Show "X best" when current streak is below the longest streak
    private var showBest: Bool {
        longestStreak > 0 && streak < longestStreak
    }

    var body: some View {
        Button(action: {
            JustWalkHaptics.buttonTap()
            onTap()
        }) {
            HStack(spacing: JW.Spacing.sm) {
                Image(systemName: streak > 0 ? "flame.fill" : "flame")
                    .foregroundStyle(flameColor)
                    .symbolEffect(.pulse, options: .repeating, value: streak > 0 && isFlameAnimating)

                if streak > 0 {
                    HStack(spacing: 4) {
                        Text("\(streak) day\(streak == 1 ? "" : "s")")
                            .font(JW.Font.subheadline)
                            .foregroundStyle(JW.Color.textSecondary)
                            .contentTransition(.numericText(value: Double(streak)))

                        if showBest {
                            Text("·")
                                .font(JW.Font.subheadline)
                                .foregroundStyle(JW.Color.textTertiary)

                            Text("\(longestStreak) best")
                                .font(JW.Font.subheadline)
                                .foregroundStyle(JW.Color.textTertiary)
                        }
                    }
                } else {
                    Text("Start streak")
                        .font(JW.Font.subheadline)
                        .foregroundStyle(JW.Color.textTertiary)
                }
            }
            .padding(.horizontal, JW.Spacing.md)
            .padding(.vertical, JW.Spacing.sm)
            .background(
                Capsule()
                    .fill(JW.Color.backgroundCard)
            )
            .overlay(
                Capsule()
                    .stroke(Color.white.opacity(0.06), lineWidth: 1)
            )
        }
        .buttonStyle(ScalePressButtonStyle())
        .onAppear {
            isFlameAnimating = true
        }
    }
}

// MARK: - Shields Pill

struct ShieldsPill: View {
    let count: Int
    var isWarning: Bool = false
    let onTap: () -> Void

    @State private var warningPulse = false

    var body: some View {
        Button(action: {
            JustWalkHaptics.buttonTap()
            onTap()
        }) {
            HStack(spacing: JW.Spacing.sm) {
                Image(systemName: "shield.fill")
                    .foregroundStyle(JW.Color.accentBlue)
                Text("\(count) shield\(count == 1 ? "" : "s")")
                    .font(JW.Font.subheadline)
                    .foregroundStyle(JW.Color.textSecondary)
                    .contentTransition(.numericText(value: Double(count)))
            }
            .padding(.horizontal, JW.Spacing.md)
            .padding(.vertical, JW.Spacing.sm)
            .background(
                Capsule()
                    .fill(JW.Color.backgroundCard)
            )
            .overlay(
                Capsule()
                    .stroke(
                        isWarning
                            ? JW.Color.streak.opacity(warningPulse ? 0.8 : 0.2)
                            : Color.white.opacity(0.06),
                        lineWidth: isWarning ? 1.5 : 1
                    )
            )
        }
        .buttonStyle(ScalePressButtonStyle())
        .onAppear {
            if isWarning {
                withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) {
                    warningPulse = true
                }
            }
        }
    }
}

#Preview {
    TodayView()
}
