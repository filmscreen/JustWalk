//
//  DashboardView.swift
//  Just Walk
//
//  Created by Randy Chia on 1/8/26.
//

import SwiftUI
import Charts
import CoreMotion

/// Main dashboard showing daily progress toward 10,000 step goal
struct DashboardView: View {

    @StateObject private var viewModel = DashboardViewModel()
    @StateObject private var weeklySnapshotManager = WeeklySnapshotManager.shared
    @ObservedObject private var streakService = StreakService.shared
    @ObservedObject private var healthKitService = HealthKitService.shared
    @ObservedObject private var rankManager = RankManager.shared
    @ObservedObject private var challengeManager = ChallengeManager.shared
    @EnvironmentObject var storeManager: StoreManager
    @State private var showIWTSession = false
    @State private var showStreakDetail = false
    @State private var isErrorBannerDismissed = false
    @State private var isMotionBannerDismissed = false
    @AppStorage("dismissedHealthPermissionBanner") private var dismissedHealthPermissionBanner = false
    
    // Celebration State
    @AppStorage("lastCelebrationDate") private var lastCelebrationDate: Double = 0
    @State private var showConfetti = false
    @AppStorage("currentCelebrationPhrase") private var currentCelebrationPhrase: String = "Goal Reached!"
    @State private var confettiHideWorkItem: DispatchWorkItem?

    // Gifted Shields Alert State
    @State private var giftedShieldsCount: Int = 0
    @State private var showGiftedShieldsAlert = false

    // Milestone Share State
    @State private var showMilestoneShareSheet = false

    // Paywall State
    @State private var showProPaywall = false

    // Challenge Detail State
    @State private var selectedChallengeForDashboard: Challenge?

    // Debug overlay state (triple-tap progress ring to show)
    #if DEBUG
    @State private var showDebugOverlay = false
    @State private var debugTapCount = 0
    @State private var debugTapTimer: Timer?
    #endif

    // This Week mini-chart data
    @StateObject private var activityDataViewModel = DataViewModel()

    // StartWalkCard Manager (promotional card for free users)
    @StateObject private var startWalkCardManager = StartWalkCardManager.shared

    // Dynamic Card Priority Manager
    @StateObject private var dynamicCardManager = DynamicCardPriorityManager.shared

    // Permission Banner Manager (post-onboarding permission prompts)
    @StateObject private var permissionBannerManager = PermissionBannerManager.shared

    // Legacy Dynamic Card Slot state (for backward compatibility)
    @State private var currentDynamicCard: DynamicCard?
    @AppStorage("dismissedDynamicCardId") private var dismissedDynamicCardId: String = ""

    // Notification Permission State
    @ObservedObject private var notificationManager = NotificationPermissionManager.shared
    @State private var showNotificationPrompt = false
    @AppStorage("notificationBannerDismissed") private var notificationBannerDismissed = false

    // Rank Celebration State
    @State private var showRankUpCelebration = false
    @State private var celebratingRank: WalkerRank?
    @State private var showRankExplainer = false
    @AppStorage("hasDismissedRankTeaser") private var hasDismissedRankTeaser = false

    // Scene phase for foreground detection
    @Environment(\.scenePhase) private var scenePhase

    // Color scheme for dark mode adaptive styles
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        NavigationStack {
            ScrollViewReader { proxy in
                VStack(spacing: 0) {
                    // Header
                    Text("Just Walk")
                        .font(.system(size: 28, weight: .bold))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 16)
                        .padding(.top, 8)
                        .padding(.bottom, 8)  // 8pt to ring top

                    ScrollView {
                        VStack(spacing: 0) {  // Manual spacing control
                            // Error Banners & Permission Banners
                            VStack(spacing: 8) {
                                // Post-onboarding permission banner (highest priority)
                                if let bannerType = permissionBannerManager.currentBanner {
                                    PermissionBanner(
                                        type: bannerType,
                                        onEnable: { permissionBannerManager.handleAction(for: bannerType) },
                                        onDismiss: {
                                            withAnimation {
                                                permissionBannerManager.dismiss(bannerType)
                                            }
                                        }
                                    )
                                    .transition(.move(edge: .top).combined(with: .opacity))
                                }

                                if let error = viewModel.error, !isErrorBannerDismissed {
                                    ErrorBannerView(
                                        error: error,
                                        onDismiss: { isErrorBannerDismissed = true }
                                    )
                                    .transition(.move(edge: .top).combined(with: .opacity))
                                }

                                if !viewModel.isLoading && StepTrackingService.authorizationStatus == .denied && !isMotionBannerDismissed {
                                    PermissionErrorBanner(
                                        permissionType: .motion,
                                        onDismiss: { isMotionBannerDismissed = true }
                                    )
                                }

                                if !viewModel.isLoading && !HealthKitService.shared.isHealthKitAuthorized && !dismissedHealthPermissionBanner {
                                    PermissionErrorBanner(
                                        permissionType: .healthKit,
                                        onDismiss: { dismissedHealthPermissionBanner = true }
                                    )
                                }

                                // Notification Re-Prompt Banner (30+ days after dismissal)
                                if notificationManager.shouldShowRePromptBanner && !notificationBannerDismissed {
                                    NotificationRePromptBanner(
                                        onEnable: {
                                            showNotificationPrompt = true
                                        },
                                        onDismiss: {
                                            notificationBannerDismissed = true
                                        }
                                    )
                                    .transition(.move(edge: .top).combined(with: .opacity))
                                }
                            }

                            // HERO SECTION - Progress ring or denied state card
                            if healthKitService.authorizationState == .denied {
                                HealthKitDeniedCard()
                            } else {
                                HeroProgressRing(
                                    stepsRemaining: viewModel.stepsRemaining,
                                    totalSteps: viewModel.todaySteps,
                                    goal: viewModel.dailyGoal,
                                    distance: viewModel.todayDistance,
                                    calories: viewModel.todayCalories.map { Int($0) },
                                    goalReached: viewModel.goalReached,
                                    onTap: {
                                        if viewModel.goalReached {
                                            triggerCelebration()
                                        }
                                        #if DEBUG
                                        handleDebugTap()
                                        #endif
                                    }
                                )
                                .padding(.top, 12)  // Adequate clearance for ring stroke
                            }

                            // 16pt spacing from ring to first card
                            Spacer().frame(height: 16)

                            // Cards section with 12pt spacing
                            if healthKitService.authorizationState != .denied {
                                VStack(spacing: 12) {
                                    // Streak Card (always visible)
                                    streakCard

                                    // Rank Card (conditional based on visibility)
                                    switch rankManager.rankCardVisibility {
                                    case .hidden:
                                        EmptyView()
                                    case .teaser:
                                        if !hasDismissedRankTeaser {
                                            RankTeaserCard(
                                                onTap: { showRankExplainer = true },
                                                onDismiss: { hasDismissedRankTeaser = true }
                                            )
                                        }
                                    case .shown:
                                        RankIdentityCard(onTap: {
                                            NotificationCenter.default.post(name: .switchToProgressTab, object: nil)
                                        })
                                    }

                                    // Week Chart
                                    MiniWeekChart(
                                        weekData: thisWeekData,
                                        dailyGoal: viewModel.dailyGoal,
                                        onSeeMore: {
                                            NotificationCenter.default.post(name: .switchToProgressTab, object: nil)
                                        }
                                    )
                                    .onAppear {
                                        if activityDataViewModel.yearData.isEmpty {
                                            Task {
                                                await activityDataViewModel.loadData()
                                            }
                                        }
                                    }

                                    // Just Walk Button (below This Week card)
                                    StartWalkingButton {
                                        NotificationCenter.default.post(name: .switchToWalkTab, object: nil)
                                        // Small delay to let tab switch complete, then trigger walk
                                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                            NotificationCenter.default.post(name: .startWalkFromDashboard, object: nil)
                                        }
                                    }

                                    // Contextual Content Row
                                    DashboardContextualRow(
                                        lastWalk: WorkoutHistoryManager.shared.workouts.first(where: {
                                            Calendar.current.isDateInToday($0.startDate)
                                        }),
                                        hasWalkedToday: viewModel.todaySteps > 0
                                    )
                                }
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.bottom, 16)  // 16pt above tab bar (safe area added by system)
                        .id("top")
                    }
                    .suppressAnimations(!viewModel.hasCompletedInitialLoad)
                    .refreshable {
                        await viewModel.refreshTodayData()
                    }
                }
                .onReceive(NotificationCenter.default.publisher(for: .scrollToTop)) { notification in
                    if let tab = notification.object as? AppTab, tab == .home {
                        withAnimation {
                            proxy.scrollTo("top", anchor: .top)
                        }
                    }
                }
            }
            .background(JWDesign.Colors.background)
            .toolbar(.hidden, for: .navigationBar)
            .task {
                await viewModel.loadData()
                await weeklySnapshotManager.checkAndPrepareSnapshot()
                checkForCelebration()

                // Check notification permission and potentially show prompt
                await notificationManager.checkAuthorizationStatus()

                // Delay slightly so it doesn't interrupt first impression
                try? await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds

                if notificationManager.shouldShowPermissionPrompt() {
                    showNotificationPrompt = true
                }
            }
            .onAppear {
                checkForCelebration()

                // CRITICAL: Refresh data when view appears (tab switch, app foreground)
                // This fixes the bug where Recent Activity tile shows stale data until user toggles tabs
                Task {
                    await viewModel.refreshTodayData()
                }

                // Evaluate dynamic card slot
                evaluateDynamicCard()

                // Evaluate permission banners (post-onboarding prompts)
                permissionBannerManager.evaluate()
            }
            .onChange(of: viewModel.todaySteps) { _, _ in
                checkForCelebration()
            }
            .overlay {
                if showConfetti {
                    ConfettiView()
                        .allowsHitTesting(false)
                }
            }
            // Pull-to-refresh error toast
            .overlay(alignment: .bottom) {
                if let errorMessage = viewModel.refreshError {
                    Text(errorMessage)
                        .font(JWDesign.Typography.caption)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(Capsule().fill(Color.red.opacity(0.9)))
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                        .padding(.bottom, 100)
                        .onAppear {
                            // Auto-dismiss after 3 seconds
                            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                                withAnimation {
                                    viewModel.refreshError = nil
                                }
                            }
                        }
                }
            }
            #if DEBUG
            .overlay {
                if showDebugOverlay {
                    DebugHandshakeOverlay(isPresented: $showDebugOverlay)
                        .zIndex(101)
                }
            }
            #endif
            .fullScreenCover(isPresented: $weeklySnapshotManager.shouldShowSnapshot) {
                if let snapshot = weeklySnapshotManager.currentSnapshot {
                    WeeklySnapshotView(snapshot: snapshot) {
                        weeklySnapshotManager.markAsShown()
                    }
                }
            }
            // Notification Permission Prompt (smart trigger)
            .sheet(isPresented: $showNotificationPrompt) {
                NotificationPermissionView(
                    onEnable: {
                        Task {
                            let _ = await notificationManager.requestPermission()
                            showNotificationPrompt = false
                        }
                    },
                    onNotNow: {
                        notificationManager.markPromptDismissed()
                        showNotificationPrompt = false
                    }
                )
            }
            // Challenge Detail Sheet (from mini card on dashboard)
            .sheet(item: $selectedChallengeForDashboard) { challenge in
                ChallengeDetailSheet(
                    challenge: challenge,
                    onDismiss: { selectedChallengeForDashboard = nil }
                )
            }
            // Gifted Shields Alert (from user support)
            .alert("Shields Received!", isPresented: $showGiftedShieldsAlert) {
                Button("Awesome!") { }
            } message: {
                Text("You've received \(giftedShieldsCount) streak shield\(giftedShieldsCount == 1 ? "" : "s") as a gift from the Just Walk team!")
            }
            .onReceive(NotificationCenter.default.publisher(for: .shieldsGifted)) { notification in
                if let count = notification.userInfo?["count"] as? Int {
                    giftedShieldsCount = count
                    showGiftedShieldsAlert = true
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .rankPromoted)) { notification in
                if let newRank = notification.userInfo?["newRank"] as? WalkerRank {
                    // Check if we've already shown this celebration
                    let key = "hasSeenRankUpCelebration_\(newRank.rawValue)"
                    if !UserDefaults.standard.bool(forKey: key) {
                        celebratingRank = newRank
                        showRankUpCelebration = true
                    }
                }
            }
            .onChange(of: scenePhase) { _, newPhase in
                if newPhase == .active {
                    // App came to foreground - refresh all data to show latest steps
                    Task {
                        await viewModel.refreshTodayData()
                    }
                    // Re-evaluate dynamic card slot
                    evaluateDynamicCard()
                    // Re-evaluate StartWalkCard visibility (used by dynamic card)
                    startWalkCardManager.evaluateVisibility()
                    // Re-evaluate permission banners (user may have enabled in Settings)
                    permissionBannerManager.evaluate()
                }
            }
            // Smart trigger for StartWalkCard when goal is reached
            .onChange(of: viewModel.goalProgress) { _, newValue in
                if newValue >= 1.0 {
                    startWalkCardManager.onGoalHit()
                }
            }
        }
    }

    // MARK: - Celebration

    private func checkForCelebration() {
        // Ensure we actually have steps and met the goal
        guard viewModel.todaySteps > 0, 
              viewModel.dailyGoal > 0,
              viewModel.todaySteps >= viewModel.dailyGoal else { return }

        if viewModel.goalReached {
            // Only auto-celebrate once per day
            let lastDate = Date(timeIntervalSince1970: lastCelebrationDate)
            if !Calendar.current.isDateInToday(lastDate) {
                pickCelebrationPhrase()
                lastCelebrationDate = Date().timeIntervalSince1970
                triggerCelebration()
            }
        }
    }
    
    /// Manually trigger celebration (called when user taps progress ring)
    private func triggerCelebration() {
        // Cancel any pending hide timer
        confettiHideWorkItem?.cancel()
        
        // Reset and show confetti fresh
        showConfetti = false
        DispatchQueue.main.async {
            showConfetti = true
        }
        
        // Haptic Feedback
        HapticService.shared.playGoalReached()
        
        // Schedule hide after 4 seconds (cancellable)
        let workItem = DispatchWorkItem {
            withAnimation {
                showConfetti = false
            }
        }
        confettiHideWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 4, execute: workItem)
    }

    #if DEBUG
    /// Handle triple-tap on progress ring to show debug overlay
    private func handleDebugTap() {
        debugTapCount += 1
        debugTapTimer?.invalidate()
        debugTapTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: false) { _ in
            Task { @MainActor in
                debugTapCount = 0
            }
        }
        if debugTapCount >= 3 {
            withAnimation(.spring(response: 0.3)) {
                showDebugOverlay = true
            }
            debugTapCount = 0
        }
    }
    #endif

    /// Available celebration phrases
    private let celebrationPhrases = [
        "Crushed it! 🔥",
        "Champion!",
        "Unstoppable!",
        "Goal Reached!",
        "Amazing work!",
        "You did it! ⭐️",
        "Walking legend!"
    ]
    
    /// Pick a stable celebration phrase (called once when goal is reached)
    private func pickCelebrationPhrase() {
        currentCelebrationPhrase = celebrationPhrases.randomElement() ?? "Goal Reached!"
    }
    
    // MARK: - Streak Logic

    private func isToday(_ date: Date) -> Bool {
        Calendar.current.isDateInToday(date)
    }
    
    /// Returns bar color: mint if steps exceed goal, otherwise blue with today emphasized
    private func barColor(for data: DayStepData) -> Color {
        if data.steps >= viewModel.dailyGoal {
            return .mint
        } else if isToday(data.date) {
            return .blue
        } else {
            return .blue.opacity(0.4)
        }
    }
    
    private func formatCompact(_ number: Int) -> String {
        let doubleNum = Double(number)
        if doubleNum >= 1000 {
            return String(format: "%.1fk", doubleNum / 1000)
        }
        return number.formatted()
    }

    // MARK: - This Week Data

    /// Last 7 days of data for the compact chart
    private var thisWeekData: [DayStepData] {
        Array(activityDataViewModel.yearData.prefix(7))
    }

    private func formatLargeNumber(_ number: Int) -> String {
        if number >= 1000000 {
            return String(format: "%.1fM", Double(number) / 1000000)
        } else if number >= 1000 {
            return String(format: "%.1fK", Double(number) / 1000)
        }
        return number.formatted()
    }

    // MARK: - Cards from HistoryView


    // MARK: - Streak Card State

    private var streakCardState: StreakCardState {
        guard streakService.isLoaded else { return .loading }

        // 1. Check for milestone celebration (highest priority when applicable)
        if streakService.isAtMilestone {
            return .milestone(days: streakService.currentStreak)
        }

        // 2. Check if streak was just lost
        if streakService.streakWasLostToday {
            return .lost(previousStreak: streakService.previousStreakBeforeLoss)
        }

        // 3. No streak
        if streakService.currentStreak == 0 {
            return .noStreak
        }

        // 4. Today is shielded
        if streakService.isTodayShielded {
            return .protected(days: streakService.currentStreak)
        }

        // 5. Goal reached today - streak is secured
        if viewModel.goalReached {
            return .active(days: streakService.currentStreak, isSecured: true)
        }

        // 6. At risk (has streak but goal not met yet)
        return .atRisk(
            days: streakService.currentStreak,
            stepsRemaining: viewModel.stepsRemaining
        )
    }

    private var streakCard: some View {
        StreakCard(
            state: streakCardState,
            onTap: { showStreakDetail = true },
            onShare: streakCardState.isMilestone ? {
                // Mark milestone as seen and show share sheet
                if let days = streakCardState.streakDays {
                    streakService.markMilestoneSeen(days)
                }
                showMilestoneShareSheet = true
            } : nil,
            onStreakLostSeen: {
                streakService.markStreakLostSeen()
            }
        )
        .sheet(isPresented: $showStreakDetail) {
            StreakDetailSheet()
        }
        .sheet(isPresented: $showMilestoneShareSheet) {
            // TODO: Implement milestone share sheet
            Text("Share your \(streakCardState.streakDays ?? 0)-day streak!")
                .presentationDetents([.medium])
        }
        .fullScreenCover(isPresented: $showProPaywall) {
            ProPaywallView()
        }
        .fullScreenCover(isPresented: $showRankUpCelebration) {
            if let rank = celebratingRank {
                RankUpCelebrationView(rank: rank) {
                    let key = "hasSeenRankUpCelebration_\(rank.rawValue)"
                    UserDefaults.standard.set(true, forKey: key)
                    showRankUpCelebration = false
                }
            }
        }
        .sheet(isPresented: $showRankExplainer) {
            RankSystemExplainerSheet()
                .presentationDetents([.medium])
        }
    }

    // MARK: - Dynamic Card Slot

    /// Evaluate and set the current dynamic card based on priority
    private func evaluateDynamicCard() {
        // Convert weekly snapshot if available
        var weeklyData: WeeklySummaryData?
        if let snapshot = weeklySnapshotManager.currentSnapshot {
            weeklyData = WeeklySummaryData(
                totalSteps: snapshot.totalSteps,
                percentChange: snapshot.percentageChange,
                isUp: snapshot.isUp,
                bestDayName: snapshot.bestDayName,
                bestDaySteps: snapshot.bestDaySteps
            )
        }

        // Calculate consecutive goal days from streak service
        let consecutiveGoalDays = streakService.currentStreak

        // Get last active date from workout history
        let lastActiveDate = WorkoutHistoryManager.shared.lastWorkoutDate

        // Evaluate with priority manager
        dynamicCardManager.evaluate(
            todaySteps: viewModel.todaySteps,
            stepGoal: viewModel.dailyGoal,
            goalReached: viewModel.goalReached,
            consecutiveGoalDays: consecutiveGoalDays,
            weeklySnapshot: weeklyData,
            lastActiveDate: lastActiveDate,
            appLaunchCount: 10  // Constant - launch tracking removed
        )
    }

    /// Handle tap/action on dynamic card
    private func handleDynamicCardAction() {
        guard let card = dynamicCardManager.currentCard else { return }

        switch card {
        case .streakAtRisk:
            // Navigate to walk tab to start walking
            NotificationCenter.default.post(name: .switchToWalkTab, object: nil)

        case .dailyMilestone(let milestone):
            // Mark as seen and show share sheet
            dynamicCardManager.markMilestoneSeen(milestone)
            // TODO: Show share sheet for milestone

        case .streakMilestone(let days):
            // Mark as seen and show share sheet
            dynamicCardManager.markStreakMilestoneSeen(days)
            // TODO: Show share sheet for streak milestone

        case .proTrial:
            // Navigate to upgrade/paywall
            showProPaywall = true

        case .weeklySummary:
            // Show weekly snapshot detail
            weeklySnapshotManager.shouldShowSnapshot = true

        case .goalAdjustment(_, let suggestedGoal, _):
            // Update the goal
            UserDefaults.standard.set(suggestedGoal, forKey: "dailyStepGoal")
            viewModel.dailyGoal = suggestedGoal
            dynamicCardManager.dismissCurrentCard()

        case .comebackPrompt:
            // Navigate to walk tab
            NotificationCenter.default.post(name: .switchToWalkTab, object: nil)

        case .weatherSuggestion:
            // Navigate to walk tab
            NotificationCenter.default.post(name: .switchToWalkTab, object: nil)

        case .watchAppSetup:
            // Open Watch app settings or deep link
            if let url = URL(string: "itms-watchs://") {
                UIApplication.shared.open(url)
            }
        }
    }

    // MARK: - Coaching Tips Carousel


}

// MARK: - Components

struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(spacing: JWDesign.Spacing.sm) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(color)

            Text(value)
                .font(JWDesign.Typography.headline)

            Text(title)
                .font(JWDesign.Typography.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(JWDesign.Spacing.cardPadding)
        .background(JWDesign.Colors.secondaryBackground)
        .clipShape(RoundedRectangle(cornerRadius: JWDesign.Radius.card))
    }
}

struct StatSummaryCard: View {
    let title: String
    let value: String
    let subtitle: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: JWDesign.Spacing.sm) {
            HStack {
                Image(systemName: icon)
                    .foregroundStyle(color)
                Spacer()
            }

            Text(value)
                .font(JWDesign.Typography.headline)

            VStack(alignment: .leading, spacing: JWDesign.Spacing.xxs) {
                Text(title)
                    .font(JWDesign.Typography.caption)
                    .foregroundStyle(.secondary)
                Text(subtitle)
                    .font(JWDesign.Typography.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(JWDesign.Spacing.cardPadding)
        .background(JWDesign.Colors.secondaryBackground)
        .clipShape(RoundedRectangle(cornerRadius: JWDesign.Radius.medium))
    }
}

#Preview {
    DashboardView()
        .environmentObject(StoreManager.shared)
}
