//
//  ProgressTabView.swift
//  Just Walk
//
//  Main Progress tab view with period selector, summary stats,
//  trends chart, milestones, and activity history.
//

import SwiftUI

struct ProgressTabView: View {
    @StateObject private var dataViewModel = DataViewModel()
    @ObservedObject private var historyManager = WorkoutHistoryManager.shared
    @ObservedObject private var streakService = StreakService.shared
    @ObservedObject private var stepRepository = StepRepository.shared
    @EnvironmentObject var storeManager: StoreManager
    @Environment(\.modelContext) private var modelContext

    // Period selection
    @State private var selectedPeriod: ProgressPeriod = .week

    // Sheets
    @State private var showPaywall = false
    @State private var selectedWorkout: WorkoutHistoryItem?
    @State private var showStreakDetails = false
    @State private var showWalkerCardShare = false
    @State private var selectedChallenge: Challenge?
    @State private var showChallengesList = false

    var body: some View {
        ScrollViewReader { proxy in
            VStack(spacing: 0) {
                // Header matching Dashboard style
                HStack {
                    Text("Progress")
                        .font(JWDesign.Typography.displaySmall)
                        .foregroundStyle(.primary)
                    Spacer()
                }
                .padding(.horizontal, JWDesign.Spacing.horizontalInset)
                .padding(.top, JWDesign.Spacing.md)
                .padding(.bottom, JWDesign.Spacing.sm)

                ScrollView {
                    VStack(spacing: JWDesign.Spacing.lg) {
                        // 0. Walker Rank Hero Card
                        RankHeroCard(
                            onShare: { showWalkerCardShare = true }
                        )
                        .padding(.horizontal, JWDesign.Spacing.horizontalInset)

                        // 1. Challenges Section (right below Walker Card)
                        ChallengesSectionView(
                            onSeeAll: {
                                showChallengesList = true
                            },
                            onSelectChallenge: { challenge in
                                selectedChallenge = challenge
                            }
                        )
                        .padding(.horizontal, JWDesign.Spacing.horizontalInset)

                        // 2. Period Selector
                        ProgressPeriodSelector(
                            selectedPeriod: $selectedPeriod,
                            isPro: storeManager.isPro,
                            onProRequired: { showPaywall = true }
                        )
                        .padding(.horizontal, JWDesign.Spacing.horizontalInset)

                        // 3. Summary Stats Card with streak banner
                        ProgressSummaryCard(
                            totalSteps: summaryStats.totalSteps,
                            totalDistance: summaryStats.totalDistance,
                            averageDailySteps: summaryStats.averageDaily,
                            daysGoalMet: summaryStats.daysGoalMet,
                            totalDays: summaryStats.totalDays,
                            currentStreak: streakService.currentStreak,
                            longestStreak: streakService.longestStreak,
                            onStreakTap: { showStreakDetails = true }
                        )
                        .padding(.horizontal, JWDesign.Spacing.horizontalInset)

                        // 4. Step Trends Chart
                        ProgressTrendsChart(
                            data: periodData,
                            dailyGoal: dataViewModel.dailyGoal,
                            period: selectedPeriod
                        )
                        .padding(.horizontal, JWDesign.Spacing.horizontalInset)

                        // 5. Recent Walks
                        ActivityHistorySection(
                            historyManager: historyManager,
                            isPro: storeManager.isPro,
                            onSelectWorkout: { workout in
                                selectedWorkout = workout
                            },
                            onUpgrade: { showPaywall = true }
                        )
                        .padding(.horizontal, JWDesign.Spacing.horizontalInset)
                    }
                    .padding(.vertical, JWDesign.Spacing.lg)
                    .padding(.bottom, JWDesign.Spacing.tabBarSafeArea)
                    .id("top")
                }
                .suppressAnimations(!dataViewModel.hasCompletedInitialLoad)
            }
            .onReceive(NotificationCenter.default.publisher(for: .scrollToTop)) { notification in
                if let tab = notification.object as? AppTab, tab == .levelUp {
                    withAnimation {
                        proxy.scrollTo("top", anchor: .top)
                    }
                }
            }
        }
        .background(JWDesign.Colors.background)
        .toolbar(.hidden, for: .navigationBar)
        .task {
            await loadData()
        }
        .refreshable {
            await loadData()
        }
        .sheet(isPresented: $showPaywall) {
            ProPaywallView()
        }
        .sheet(item: $selectedWorkout) { workout in
            WorkoutDetailView(workoutItem: workout)
        }
        .sheet(isPresented: $showStreakDetails) {
            StreakDetailSheet()
        }
        .sheet(isPresented: $showWalkerCardShare) {
            WalkerCardShareSheet()
        }
        .sheet(item: $selectedChallenge) { challenge in
            ChallengeDetailSheet(
                challenge: challenge,
                onDismiss: { selectedChallenge = nil }
            )
        }
        .navigationDestination(isPresented: $showChallengesList) {
            ChallengesView()
        }
    }

    // MARK: - Data Loading

    private func loadData() async {
        historyManager.setModelContext(modelContext)
        await dataViewModel.loadData()
        await historyManager.fetchWorkouts()
    }

    // MARK: - Computed Data

    private var periodData: [DayStepData] {
        switch selectedPeriod {
        case .week:
            return Array(dataViewModel.twoWeeksData.prefix(7))
        case .month:
            return dataViewModel.monthData
        case .year:
            return dataViewModel.yearData
        case .allTime:
            return dataViewModel.fullHistoryLog
        }
    }

    private var summaryStats: (totalSteps: Int, totalDistance: Double, averageDaily: Int, daysGoalMet: Int, totalDays: Int) {
        let data = periodData
        let totalSteps = data.reduce(0) { $0 + $1.steps }
        let totalDistance = data.reduce(0.0) { $0 + ($1.distance ?? 0) }
        let validDays = data.filter { $0.steps > 0 }
        let averageDaily = validDays.isEmpty ? 0 : totalSteps / validDays.count
        let daysGoalMet = data.filter { $0.isGoalMet }.count
        let totalDays = data.count

        return (totalSteps, totalDistance, averageDaily, daysGoalMet, totalDays)
    }

}

// MARK: - Preview

#Preview {
    NavigationStack {
        ProgressTabView()
            .environmentObject(StoreManager.shared)
    }
}
