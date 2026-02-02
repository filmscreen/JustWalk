//
//  WalksHomeView.swift
//  JustWalk
//
//  Hub for all walk types: Intervals, Fat Burn Zone, Post-Meal Walk
//  Redesigned: Compact cards, segmented toggle, quiet paywall
//

import SwiftUI

// MARK: - Walk Type Navigation

enum WalkTypeDestination: Hashable {
    case intervals
    case fatBurn
    case postMeal
}

// MARK: - Segmented Tab

enum WalksTab: String, CaseIterable {
    case start = "Start a Walk"
    case history = "Your Walks"
}

struct WalksHomeView: View {
    @Environment(AppState.self) private var appState

    @StateObject private var subscriptionManager = SubscriptionManager.shared
    @StateObject private var usageManager = WalkUsageManager.shared
    @State private var recentWalks: [TrackedWalk] = []
    private var persistence: PersistenceManager { PersistenceManager.shared }

    // Segmented control state
    @State private var selectedTab: WalksTab = .start

    // Education sheet infrastructure
    @AppStorage("hasSeenIntervalsEducation") private var hasSeenIntervalsEducation = false
    @AppStorage("hasSeenFatBurnEducation") private var hasSeenFatBurnEducation = false
    @AppStorage("hasSeenPostMealEducation") private var hasSeenPostMealEducation = false

    @State private var showIntervalsEducation = false
    @State private var showFatBurnEducation = false
    @State private var showPostMealEducation = false

    // Navigation
    @State private var navigateToPostMeal = false
    @State private var navigateToIntervals = false
    @State private var navigateToFatBurn = false

    // Paywall
    @State private var showPaywallSheet = false
    @State private var paywallMode: WalkMode? = nil

    // History filter
    @State private var selectedHistoryFilter: HistoryFilter = .week
    @State private var showHistoryUpgradeSheet = false
    @State private var selectedHistoryWalk: TrackedWalk?

    // Tooltip
    @State private var showWalksTooltip = false
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false

    // Computed properties for usage status
    private var intervalsRemaining: Int {
        usageManager.remainingFree(for: .interval) ?? 1
    }

    private var fatBurnRemaining: Int {
        usageManager.remainingFree(for: .fatBurn) ?? 1
    }

    private var intervalsExhausted: Bool {
        !subscriptionManager.isPro && intervalsRemaining == 0
    }

    private var fatBurnExhausted: Bool {
        !subscriptionManager.isPro && fatBurnRemaining == 0
    }

    private var isPro: Bool { subscriptionManager.isPro }

    private var filteredWalks: [TrackedWalk] {
        let allWalks = recentWalks

        // Safety: if not Pro and filter requires Pro, fall back to week
        let activeFilter = (!isPro && selectedHistoryFilter.requiresPro) ? .week : selectedHistoryFilter

        guard let cutoff = activeFilter.cutoffDate else {
            return allWalks.sorted { $0.startTime > $1.startTime }
        }

        return allWalks
            .filter { $0.startTime >= cutoff }
            .sorted { $0.startTime > $1.startTime }
    }

    // MARK: - Summary Stats (for WalksSummaryCard)

    private var summaryPeriodText: String {
        let activeFilter = (!isPro && selectedHistoryFilter.requiresPro) ? .week : selectedHistoryFilter
        switch activeFilter {
        case .week: return "This Week"
        case .month: return "This Month"
        case .year: return "This Year"
        case .allTime: return "All Time"
        }
    }

    private var summaryTotalSteps: Int {
        filteredWalks.reduce(0) { $0 + $1.steps }
    }

    private var summaryTotalMinutes: Int {
        filteredWalks.reduce(0) { $0 + $1.durationMinutes }
    }

    private var emptyStatePeriodText: String {
        let activeFilter = (!isPro && selectedHistoryFilter.requiresPro) ? .week : selectedHistoryFilter
        switch activeFilter {
        case .week: return "this week"
        case .month: return "this month"
        case .year: return "this year"
        case .allTime: return "yet"
        }
    }

    var body: some View {
        ZStack {
            JW.Color.backgroundPrimary
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Header
                headerView
                    .padding(.horizontal, JW.Spacing.lg)
                    .padding(.top, JW.Spacing.md)

                // Segmented control
                segmentedControl
                    .padding(.horizontal, JW.Spacing.lg)
                    .padding(.vertical, JW.Spacing.md)

                // Content based on selected tab
                contentView
            }
        }
        .navigationDestination(isPresented: $navigateToIntervals) {
            WalkTabView()
        }
        .navigationDestination(isPresented: $navigateToFatBurn) {
            FatBurnContainerView()
        }
        .navigationDestination(isPresented: $navigateToPostMeal) {
            PostMealSetupView {
                // Reset navigation state when flow completes
                navigateToPostMeal = false
            }
        }
        .sheet(isPresented: $showIntervalsEducation) {
            IntervalsEducationSheet {
                hasSeenIntervalsEducation = true
                showIntervalsEducation = false
                navigateToIntervals = true
            }
        }
        .sheet(isPresented: $showFatBurnEducation) {
            FatBurnEducationSheet {
                hasSeenFatBurnEducation = true
                showFatBurnEducation = false
                navigateToFatBurn = true
            }
        }
        .sheet(isPresented: $showPostMealEducation) {
            PostMealEducationSheet {
                hasSeenPostMealEducation = true
                showPostMealEducation = false
                navigateToPostMeal = true
            }
        }
        .sheet(isPresented: $showPaywallSheet) {
            PaywallSheet(mode: paywallMode) { showPaywallSheet = false }
        }
        .navigationBarHidden(true)
        .onAppear {
            usageManager.refreshWeek()
            loadRecentWalks()
            consumePendingCardAction()

            // Show walks tooltip (first time only, after onboarding)
            if hasCompletedOnboarding && TooltipKey.shouldShow(.walks) {
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    withAnimation(JustWalkAnimation.standard) {
                        showWalksTooltip = true
                    }
                }
            }
        }
        .onChange(of: appState.pendingCardAction) { _, _ in
            consumePendingCardAction()
        }
    }

    // MARK: - Header

    private var headerView: some View {
        VStack(alignment: .leading, spacing: JW.Spacing.xs) {
            HStack {
                Text("Walks")
                    .font(JW.Font.largeTitle)
                    .foregroundStyle(JW.Color.textPrimary)

                Spacer()

                WatchConnectionBanner()
            }

            Text("Walk with intention.")
                .font(JW.Font.subheadline)
                .foregroundStyle(JW.Color.textSecondary)
        }
        .tooltip(
            isPresented: $showWalksTooltip,
            content: "Guided walks make your steps more effective. Try your first one free.",
            arrowDirection: .down,
            offset: CGSize(width: 0, height: -8),
            onDismiss: { TooltipKey.markAsSeen(.walks) }
        )
    }

    // MARK: - Segmented Control

    private var segmentedControl: some View {
        HStack(spacing: 0) {
            ForEach(WalksTab.allCases, id: \.self) { tab in
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedTab = tab
                    }
                } label: {
                    Text(tab.rawValue)
                        .font(JW.Font.subheadline.weight(selectedTab == tab ? .semibold : .medium))
                        .foregroundStyle(selectedTab == tab ? Color.black : JW.Color.textSecondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, JW.Spacing.sm)
                        .contentShape(Rectangle())
                        .background(
                            Capsule()
                                .fill(selectedTab == tab ? JW.Color.accent : Color.clear)
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .background(
            Capsule()
                .fill(Color.white.opacity(0.06))
        )
    }

    // MARK: - Content View

    @ViewBuilder
    private var contentView: some View {
        switch selectedTab {
        case .start:
            startAWalkView
        case .history:
            yourWalksView
        }
    }

    // MARK: - Start a Walk View

    private var startAWalkView: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 12) {
                // Intervals card
                WalkTypeCard(
                    walkType: .intervals,
                    isPro: isPro,
                    freeWalksRemaining: intervalsRemaining,
                    onTap: handleIntervalsTap
                )
                .staggeredAppearance(index: 0)

                // Fat Burn Zone card
                WalkTypeCard(
                    walkType: .fatBurn,
                    isPro: isPro,
                    freeWalksRemaining: fatBurnRemaining,
                    onTap: handleFatBurnTap
                )
                .staggeredAppearance(index: 1)

                // Post-Meal Walk card
                WalkTypeCard(
                    walkType: .postMeal,
                    isPro: true, // Always free
                    freeWalksRemaining: 999,
                    onTap: handlePostMealTap
                )
                .staggeredAppearance(index: 2)
            }
            .padding(.horizontal, JW.Spacing.lg)
            .padding(.top, JW.Spacing.md)
            .padding(.bottom, 24)
        }
    }

    // MARK: - Status Computations

    private var intervalStatus: WalkTypeRowStatus {
        if subscriptionManager.isPro {
            return .start
        }
        if intervalsExhausted {
            return .availableMonday
        }
        return .freeLeft(intervalsRemaining)
    }

    private var fatBurnStatus: WalkTypeRowStatus {
        if subscriptionManager.isPro {
            return .start
        }
        if fatBurnExhausted {
            return .availableMonday
        }
        return .freeLeft(fatBurnRemaining)
    }

    // MARK: - Your Walks View

    private var yourWalksView: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 0) {
                // Filter pills
                historyFilterBar
                    .padding(.horizontal, JW.Spacing.lg)
                    .padding(.bottom, JW.Spacing.md)

                // Summary card at top
                WalksSummaryCard(
                    period: summaryPeriodText,
                    walkCount: filteredWalks.count,
                    totalSteps: summaryTotalSteps,
                    totalMinutes: summaryTotalMinutes
                )
                .padding(.horizontal, JW.Spacing.lg)
                .padding(.bottom, JW.Spacing.md)

                if filteredWalks.isEmpty {
                    emptyHistoryView
                } else {
                    historyListView
                }
            }
        }
        .sheet(isPresented: $showHistoryUpgradeSheet) {
            ProUpgradeView(onComplete: { showHistoryUpgradeSheet = false })
        }
        .sheet(item: $selectedHistoryWalk) { walk in
            NavigationStack {
                PostWalkSummaryView(
                    walk: walk,
                    showDeleteOption: true,
                    onDelete: {
                        loadRecentWalks()
                    }
                )
            }
        }
    }

    // MARK: - History Filter Bar

    private var historyFilterBar: some View {
        HStack(spacing: JW.Spacing.sm) {
            ForEach(HistoryFilter.allCases) { filter in
                Button {
                    handleHistoryFilterTap(filter)
                } label: {
                    HStack(spacing: 4) {
                        if filter.requiresPro && !isPro {
                            Image(systemName: "lock.fill")
                                .font(.system(size: 10))
                        }
                        Text(filter.rawValue)
                    }
                    .font(JW.Font.caption.weight(selectedHistoryFilter == filter ? .semibold : .regular))
                    .foregroundStyle(selectedHistoryFilter == filter ? Color.black : JW.Color.textSecondary)
                    .padding(.horizontal, JW.Spacing.md)
                    .padding(.vertical, JW.Spacing.sm)
                    .background(
                        Capsule()
                            .fill(selectedHistoryFilter == filter ? JW.Color.accent : Color.white.opacity(0.06))
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func handleHistoryFilterTap(_ filter: HistoryFilter) {
        if filter.requiresPro && !isPro {
            showHistoryUpgradeSheet = true
            return
        }
        selectedHistoryFilter = filter
    }

    private var emptyHistoryView: some View {
        VStack(spacing: JW.Spacing.md) {
            Spacer()
                .frame(height: 60)

            Image(systemName: "figure.walk")
                .font(.system(size: 48))
                .foregroundStyle(JW.Color.textSecondary.opacity(0.5))

            Text("No walks \(emptyStatePeriodText)")
                .font(JW.Font.headline)
                .foregroundStyle(JW.Color.textPrimary)

            Text("Start a guided walk to see it here")
                .font(JW.Font.subheadline)
                .foregroundStyle(JW.Color.textSecondary)

            Spacer()
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, JW.Spacing.lg)
        .padding(.vertical, 60)
    }

    private var historyListView: some View {
        VStack(spacing: 0) {
            // Show walks grouped by relative time
            let groupedWalks = groupWalksByFilter(filteredWalks)

            ForEach(groupedWalks, id: \.0) { section, walks in
                Section {
                    ForEach(Array(walks.enumerated()), id: \.element.id) { index, walk in
                        Button {
                            selectedHistoryWalk = walk
                        } label: {
                            CompactWalkRow(walk: walk)
                        }
                        .buttonStyle(.plain)

                        if index < walks.count - 1 {
                            Divider()
                                .overlay(Color.white.opacity(0.06))
                                .padding(.leading, 64)
                        }
                    }
                } header: {
                    Text(section.uppercased())
                        .font(JW.Font.caption)
                        .foregroundStyle(JW.Color.textTertiary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, JW.Spacing.lg)
                        .padding(.vertical, JW.Spacing.sm)
                        .background(JW.Color.backgroundPrimary)
                }
            }

            // Soft upgrade prompt for free users at 30-day limit
            if !subscriptionManager.isPro && hasReachedHistoryLimit {
                softUpgradePrompt
            }

            Spacer()
                .frame(height: JW.Spacing.xxxl)
        }
    }

    private var hasReachedHistoryLimit: Bool {
        let thirtyDaysAgo = Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date()
        let oldestWalk = recentWalks.min { $0.startTime < $1.startTime }
        guard let oldest = oldestWalk else { return false }
        return oldest.startTime < thirtyDaysAgo
    }

    private var softUpgradePrompt: some View {
        VStack(spacing: JW.Spacing.md) {
            Divider()
                .overlay(Color.white.opacity(0.06))

            VStack(spacing: JW.Spacing.sm) {
                Text("See your full walk history with Pro")
                    .font(JW.Font.subheadline)
                    .foregroundStyle(JW.Color.textSecondary)
                    .multilineTextAlignment(.center)

                Button {
                    showPaywallSheet = true
                    paywallMode = nil // General upgrade
                } label: {
                    Text("Upgrade to Pro")
                        .font(JW.Font.subheadline.weight(.semibold))
                        .foregroundStyle(JW.Color.accent)
                }
            }
            .padding(.vertical, JW.Spacing.lg)
            .padding(.horizontal, JW.Spacing.lg)
        }
    }

    // MARK: - Grouping Helpers

    private func groupWalksByTime(_ walks: [TrackedWalk]) -> [(String, [TrackedWalk])] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today) ?? today
        let thirtyDaysAgo = calendar.date(byAdding: .day, value: -30, to: today) ?? today

        // Filter for free users (30 days), Pro users get all
        let filteredWalks = subscriptionManager.isPro
            ? walks
            : walks.filter { $0.startTime >= thirtyDaysAgo }

        let grouped = Dictionary(grouping: filteredWalks) { walk -> String in
            let walkDay = calendar.startOfDay(for: walk.startTime)
            if walkDay == today {
                return "Today"
            } else if walkDay == yesterday {
                return "Yesterday"
            } else {
                return Self.groupByDayFormatter.string(from: walk.startTime)
            }
        }

        // Sort sections: Today, Yesterday, then by date descending
        let sortedKeys = grouped.keys.sorted { key1, key2 in
            if key1 == "Today" { return true }
            if key2 == "Today" { return false }
            if key1 == "Yesterday" { return true }
            if key2 == "Yesterday" { return false }
            // For date strings, we need to compare the actual dates
            let date1 = grouped[key1]?.first?.startTime ?? Date.distantPast
            let date2 = grouped[key2]?.first?.startTime ?? Date.distantPast
            return date1 > date2
        }

        return sortedKeys.map { key in
            (key, grouped[key]!.sorted { $0.startTime > $1.startTime })
        }
    }

    private func groupWalksByFilter(_ walks: [TrackedWalk]) -> [(String, [TrackedWalk])] {
        guard !walks.isEmpty else { return [] }

        let activeFilter = (!isPro && selectedHistoryFilter.requiresPro) ? .week : selectedHistoryFilter

        switch activeFilter {
        case .week:
            return groupByDay(walks)
        case .month:
            return groupByWeek(walks)
        case .year, .allTime:
            return groupByMonth(walks)
        }
    }

    private static let dayOfWeekFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "EEEE"
        return f
    }()

    private static let groupByDayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "EEEE, MMM d"
        return f
    }()

    private static let monthYearFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MMMM yyyy"
        return f
    }()

    private func groupByDay(_ walks: [TrackedWalk]) -> [(String, [TrackedWalk])] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: walks) { walk in
            calendar.startOfDay(for: walk.startTime)
        }

        return grouped
            .sorted { $0.key > $1.key }
            .map { (dayDate, walks) in
                let label: String
                if calendar.isDateInToday(dayDate) {
                    label = "Today"
                } else if calendar.isDateInYesterday(dayDate) {
                    label = "Yesterday"
                } else {
                    label = Self.dayOfWeekFormatter.string(from: dayDate)
                }
                return (label, walks.sorted { $0.startTime > $1.startTime })
            }
    }

    private func groupByWeek(_ walks: [TrackedWalk]) -> [(String, [TrackedWalk])] {
        let calendar = Calendar.current
        let now = Date()
        let startOfThisWeek = calendar.dateInterval(of: .weekOfYear, for: now)?.start ?? now

        let grouped = Dictionary(grouping: walks) { walk in
            calendar.dateInterval(of: .weekOfYear, for: walk.startTime)?.start ?? walk.startTime
        }

        return grouped
            .sorted { $0.key > $1.key }
            .map { (weekStart, walks) in
                let label: String
                if weekStart >= startOfThisWeek {
                    label = "This Week"
                } else if let lastWeekStart = calendar.date(byAdding: .weekOfYear, value: -1, to: startOfThisWeek),
                          weekStart >= lastWeekStart {
                    label = "Last Week"
                } else {
                    let weeksAgo = calendar.dateComponents([.weekOfYear], from: weekStart, to: startOfThisWeek).weekOfYear ?? 0
                    label = "\(weeksAgo) Weeks Ago"
                }
                return (label, walks.sorted { $0.startTime > $1.startTime })
            }
    }

    private func groupByMonth(_ walks: [TrackedWalk]) -> [(String, [TrackedWalk])] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: walks) { walk in
            let comps = calendar.dateComponents([.year, .month], from: walk.startTime)
            return calendar.date(from: comps) ?? walk.startTime
        }

        return grouped
            .sorted { $0.key > $1.key }
            .map { (monthDate, walks) in
                let label = Self.monthYearFormatter.string(from: monthDate)
                return (label, walks.sorted { $0.startTime > $1.startTime })
            }
    }

    // MARK: - Actions

    private func handleIntervalsTap() {
        JustWalkHaptics.buttonTap()

        if intervalsExhausted && !subscriptionManager.isPro {
            paywallMode = .interval
            showPaywallSheet = true
            return
        }

        if !hasSeenIntervalsEducation {
            showIntervalsEducation = true
        } else {
            navigateToIntervals = true
        }
    }

    private func handleFatBurnTap() {
        JustWalkHaptics.buttonTap()

        if fatBurnExhausted && !subscriptionManager.isPro {
            paywallMode = .fatBurn
            showPaywallSheet = true
            return
        }

        if !hasSeenFatBurnEducation {
            showFatBurnEducation = true
        } else {
            navigateToFatBurn = true
        }
    }

    private func handlePostMealTap() {
        JustWalkHaptics.buttonTap()

        if !hasSeenPostMealEducation {
            showPostMealEducation = true
        } else {
            navigateToPostMeal = true
        }
    }

    private func loadRecentWalks() {
        recentWalks = persistence.loadAllTrackedWalks()
            .filter(\.isDisplayable)
            .sorted { $0.startTime > $1.startTime }
    }

    private func consumePendingCardAction() {
        guard let action = appState.pendingCardAction else { return }
        appState.pendingCardAction = nil

        switch action {
        case .navigateToWalksTab:
            selectedTab = .start
        case .navigateToIntervals, .startIntervalWalk:
            selectedTab = .start
            navigateToIntervals = true
        case .startPostMealWalk:
            selectedTab = .start
            navigateToPostMeal = true
        case .startFatBurnWalk:
            selectedTab = .start
            navigateToFatBurn = true
        case .openWatchSetup:
            // Open the Apple Watch app on paired device
            if let url = URL(string: "itms-watchs://") {
                UIApplication.shared.open(url)
            }
        case .navigateToFuelTab, .useShieldForDate, .letStreakBreak, .dismissFuelUpsell:
            // These actions are handled in TodayView, not here
            break
        }
    }
}

// MARK: - Walk Type Row Status

enum WalkTypeRowStatus: Equatable {
    case freeLeft(Int)
    case availableMonday
    case start

    var text: String {
        switch self {
        case .freeLeft(let count):
            return "\(count) free left"
        case .availableMonday:
            return "Available Mon"
        case .start:
            return "Start"
        }
    }

    var color: Color {
        switch self {
        case .freeLeft:
            return JW.Color.accent.opacity(0.9)
        case .availableMonday:
            return JW.Color.textTertiary
        case .start:
            return JW.Color.textSecondary
        }
    }
}

// MARK: - Walk Type Feature Card

enum FeatureCardWalkType {
    case intervals
    case fatBurn
    case postMeal

    var title: String {
        switch self {
        case .intervals: return "Intervals"
        case .fatBurn: return "Fat Burn Zone"
        case .postMeal: return "Post-Meal Walk"
        }
    }

    var description: String {
        switch self {
        case .intervals:
            return "Japanese Walking Method — Alternate fast and slow to boost metabolism."
        case .fatBurn:
            return "Walk in your fat-burning heart rate zone with real-time guidance. No time limit."
        case .postMeal:
            return "A 10-minute walk after eating helps regulate blood sugar."
        }
    }

    var showsAppleWatchIcon: Bool {
        switch self {
        case .intervals: return false
        case .fatBurn: return true
        case .postMeal: return false
        }
    }

    var iconName: String {
        switch self {
        case .intervals: return "bolt.fill"
        case .fatBurn: return "heart.fill"
        case .postMeal: return "fork.knife"
        }
    }

    var iconColor: Color {
        switch self {
        case .intervals: return JW.Color.accent
        case .fatBurn: return JW.Color.streak
        case .postMeal: return JW.Color.streak
        }
    }

    var iconBackgroundColor: Color {
        switch self {
        case .intervals: return JW.Color.accent.opacity(0.2)
        case .fatBurn: return JW.Color.streak.opacity(0.2)
        case .postMeal: return JW.Color.streak.opacity(0.2)
        }
    }
}

struct WalkTypeCard: View {
    let walkType: FeatureCardWalkType
    let isPro: Bool
    let freeWalksRemaining: Int
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 8) {
                // Header: Icon + Title + Free Badge + Right Badge + Chevron
                HStack(alignment: .center, spacing: 10) {
                    // Icon
                    ZStack {
                        Circle()
                            .fill(walkType.iconBackgroundColor)
                            .frame(width: 36, height: 36)

                        Image(systemName: walkType.iconName)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(walkType.iconColor)
                    }

                    // Title
                    Text(walkType.title)
                        .font(.headline)
                        .foregroundStyle(JW.Color.textPrimary)

                    // Free user badge (inline after title)
                    if !isPro && walkType != .postMeal {
                        if freeWalksRemaining > 0 {
                            Text("\(freeWalksRemaining) free/wk")
                                .font(JW.Font.caption.weight(.medium))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 2)
                                .background(JW.Color.accent.opacity(0.2))
                                .foregroundStyle(JW.Color.accent)
                                .clipShape(RoundedRectangle(cornerRadius: 4))
                        } else {
                            Text("Resets Mon")
                                .font(JW.Font.caption)
                                .foregroundStyle(JW.Color.textSecondary)
                        }
                    }

                    Spacer()

                    // Apple Watch icon (no text)
                    if walkType.showsAppleWatchIcon {
                        Image(systemName: "applewatch")
                            .font(.system(size: 14))
                            .foregroundStyle(JW.Color.textSecondary)
                    }

                    // Chevron
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(JW.Color.textSecondary)
                }

                // Description
                Text(walkType.description)
                    .font(JW.Font.subheadline)
                    .foregroundStyle(JW.Color.textSecondary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                    .multilineTextAlignment(.leading)
            }
            .padding(16)
            .background(JW.Color.backgroundCard)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(Color.white.opacity(0.08), lineWidth: 1)
            )
        }
        .buttonStyle(CardPressButtonStyle())
    }
}

// MARK: - Card Press Button Style

struct CardPressButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? 0.7 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

// MARK: - Legacy Compact Walk Type Row (kept for reference)

struct WalkTypeRow: View {
    let icon: String
    let iconColor: Color
    let title: String
    let subtitle: String
    let status: WalkTypeRowStatus
    let isAvailable: Bool
    let onTap: () -> Void

    var body: some View {
        Button {
            onTap()
        } label: {
            HStack(spacing: JW.Spacing.md) {
                // Icon
                ZStack {
                    Circle()
                        .fill(iconColor.opacity(0.15))
                        .frame(width: 40, height: 40)

                    Image(systemName: icon)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(iconColor)
                }

                // Title and subtitle
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(JW.Font.subheadline.weight(.semibold))
                        .foregroundStyle(JW.Color.textPrimary)

                    Text(subtitle)
                        .font(JW.Font.caption)
                        .foregroundStyle(JW.Color.textSecondary)
                }

                Spacer()

                // Status badge
                HStack(spacing: 4) {
                    Text(status.text)
                        .font(JW.Font.caption.weight(.medium))
                        .foregroundStyle(status.color)

                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(JW.Color.textTertiary)
                }
            }
            .padding(.vertical, JW.Spacing.md)
            .contentShape(Rectangle())
            .opacity(isAvailable ? 1.0 : 0.5)
        }
        .buttonStyle(ScalePressButtonStyle(scale: 0.98))
    }
}

// MARK: - Compact Walk Row (for history)

struct CompactWalkRow: View {
    let walk: TrackedWalk

    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.timeStyle = .short
        return f
    }()

    private var walkTypeLabel: String {
        switch walk.mode {
        case .interval:
            return walk.intervalProgram?.displayName ?? "Interval Walk"
        case .fatBurn:
            return "Fat Burn Zone"
        case .postMeal:
            return "Post-Meal Walk"
        case .free:
            return "Free Walk"
        }
    }

    private var walkIcon: String {
        switch walk.mode {
        case .interval: return "bolt.fill"
        case .fatBurn: return "heart.fill"
        case .postMeal: return "fork.knife"
        case .free: return "figure.walk"
        }
    }

    private var iconColor: Color {
        switch walk.mode {
        case .interval: return JW.Color.accent
        case .fatBurn: return JW.Color.streak
        case .postMeal: return JW.Color.streak
        case .free: return JW.Color.accentBlue
        }
    }

    private var iconBackgroundColor: Color {
        switch walk.mode {
        case .interval: return JW.Color.accent.opacity(0.2)
        case .fatBurn: return JW.Color.streak.opacity(0.2)
        case .postMeal: return JW.Color.streak.opacity(0.2)
        case .free: return JW.Color.accentBlue.opacity(0.2)
        }
    }

    private var formattedDuration: String {
        let mins = walk.durationMinutes
        if mins < 1 {
            return "<1 min"
        } else if mins < 60 {
            return "\(mins) min"
        } else {
            let h = mins / 60
            let m = mins % 60
            return m > 0 ? "\(h)h \(m)m" : "\(h)h"
        }
    }

    var body: some View {
        HStack(spacing: 12) {
            // Icon with colored background
            ZStack {
                Circle()
                    .fill(iconBackgroundColor)
                    .frame(width: 36, height: 36)

                Image(systemName: walkIcon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(iconColor)
            }

            // Walk info
            VStack(alignment: .leading, spacing: 2) {
                Text(walkTypeLabel)
                    .font(.body.weight(.medium))
                    .foregroundStyle(JW.Color.textPrimary)

                HStack(spacing: 0) {
                    Text(Self.timeFormatter.string(from: walk.startTime))
                    Text("  ·  ")
                        .foregroundStyle(JW.Color.textTertiary)
                    Text(formattedDuration)
                }
                .font(JW.Font.subheadline)
                .foregroundStyle(JW.Color.textSecondary)
            }

            Spacer()

            // Steps count (primary metric)
            Text("\(walk.steps.formatted()) steps")
                .font(JW.Font.subheadline)
                .foregroundStyle(JW.Color.textSecondary)

            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(JW.Color.textTertiary)
        }
        .padding(.vertical, 12)
        .padding(.horizontal, JW.Spacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
    }
}

// MARK: - Walks Summary Card

struct WalksSummaryCard: View {
    let period: String
    let walkCount: Int
    let totalSteps: Int
    let totalMinutes: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(period)
                .font(JW.Font.subheadline.weight(.medium))
                .foregroundStyle(JW.Color.textPrimary)

            HStack(spacing: 0) {
                Text("\(walkCount) walks")
                Text("  ·  ")
                    .foregroundStyle(JW.Color.textTertiary)
                Text("\(totalSteps.formatted()) steps")
                Text("  ·  ")
                    .foregroundStyle(JW.Color.textTertiary)
                Text("\(totalMinutes) min")
            }
            .font(JW.Font.subheadline)
            .foregroundStyle(JW.Color.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(JW.Color.backgroundCard)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
    }
}

// MARK: - Paywall Sheet

struct PaywallSheet: View {
    let mode: WalkMode?
    let onComplete: () -> Void

    private var title: String {
        switch mode {
        case .interval:
            return "You've used your free Interval walk this week"
        case .fatBurn:
            return "You've used your free Fat Burn walk this week"
        default:
            return "Go Pro for unlimited walks"
        }
    }

    private var message: String {
        switch mode {
        case .interval:
            return "Go Pro for unlimited Interval walks and access to all training programs."
        case .fatBurn:
            return "Go Pro for unlimited Fat Burn Zone walks and personalized heart rate guidance."
        default:
            return "Unlock unlimited walks, full history, and all premium features."
        }
    }

    var body: some View {
        NavigationStack {
            ProUpgradeView(onComplete: onComplete)
                .navigationTitle("")
        }
    }
}

// MARK: - Education Sheets

struct IntervalsEducationSheet: View {
    let onDismiss: () -> Void

    var body: some View {
        EducationSheetTemplate(
            icon: "bolt.fill",
            iconColor: JW.Color.accent,
            title: "How Intervals Work",
            message: "Alternate between fast and slow walking. This variation helps your body burn more calories.\n\nBased on Japanese research showing 20% better results vs walking at a steady pace.",
            onContinue: onDismiss
        )
    }
}

struct FatBurnEducationSheet: View {
    let onDismiss: () -> Void

    var body: some View {
        EducationSheetTemplate(
            icon: "heart.fill",
            iconColor: JW.Color.streak,
            title: "Fat Burn Zone",
            message: "Uses your Apple Watch heart rate to keep you in the optimal zone for fat loss. Walk at the right intensity — not too hard, not too easy.",
            onContinue: onDismiss
        )
    }
}

#Preview {
    NavigationStack {
        WalksHomeView()
    }
    .environment(AppState())
}
