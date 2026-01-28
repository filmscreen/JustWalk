//
//  DashboardViewModel.swift
//  Just Walk
//
//  Created by Randy Chia on 1/8/26.
//

import Foundation
import SwiftUI
import Combine
import CoreData

/// ViewModel for the main dashboard view
@MainActor
final class DashboardViewModel: ObservableObject {

    // MARK: - Published Properties

    // Data
    @Published var todaySteps: Int = 0
    @Published var todayDistance: Double = 0
    @Published var todayCalories: Double? = nil  // From HealthKit, nil if unavailable
    @Published var dailyGoal: Int = 10000
    @Published var isLoading = true
    @Published var error: Error?
    @Published var currentCoachingTip: CoachingTip?
    @Published var lastIncrementCelebrated: Int = 0

    @Published var weeklySteps: [DayStepData] = []
    @Published var yearlySteps: [DayStepData] = []
    @Published var contextualTips: [CoachingTip] = []
    @Published var totalMiles: Double = 0

    // Pull-to-refresh state
    @Published var isRefreshing = false
    @Published var refreshError: String?

    // Initial load tracking (for animation suppression)
    @Published var hasCompletedInitialLoad: Bool = false
    private var lastRefreshTime: Date?
    private let minimumRefreshInterval: TimeInterval = 2.0

    // Insight system
    @Published var currentInsight: (id: String, message: String)?
    private let insightEvaluator = InsightEvaluator()
    private var isRefreshingInsight = false
    @AppStorage("lastGoalReachedDate") private var lastGoalReachedDate: Double = 0

    // MARK: - Services

    private let stepRepository = StepRepository.shared
    private let stepTrackingService = StepTrackingService.shared
    private let hapticService = HapticService.shared
    private let healthKitService = HealthKitService.shared

    private var cancellables = Set<AnyCancellable>()
    private var lastGoalReached = false

    // MARK: - Computed Properties

    var goalProgress: Double {
        min(1.0, Double(todaySteps) / Double(dailyGoal))
    }

    var stepsRemaining: Int {
        max(0, dailyGoal - todaySteps)
    }

    var incrementsAchieved: Int {
        todaySteps / 500
    }

    var totalIncrements: Int {
        dailyGoal / 500
    }

    var stepsToNextIncrement: Int {
        let nextIncrement = (incrementsAchieved + 1) * 500
        return max(0, nextIncrement - todaySteps)
    }

    var goalReached: Bool {
        todaySteps >= dailyGoal
    }

    var formattedDistance: String {
        let miles = todayDistance * 0.000621371
        return String(format: "%.2f mi", miles)
    }

    var progressPercentage: String {
        String(format: "%.0f%%", goalProgress * 100)
    }

    var distanceComparison: String {
        DistanceContextManager.shared.getComparison(for: totalMiles)
    }

    // MARK: - History Stats (Merged from HistoryViewModel)

    var averageSteps: Int {
        let data = weeklySteps.filter { $0.steps > 0 }
        guard !data.isEmpty else { return 0 }
        return data.reduce(0) { $0 + $1.steps } / data.count
    }

    var totalStepsHistory: Int {
        weeklySteps.reduce(0) { $0 + $1.steps }
    }

    var bestDay: DayStepData? {
        weeklySteps.max(by: { $0.steps < $1.steps })
    }

    var daysAtGoal: Int {
        weeklySteps.filter { $0.isGoalMet }.count
    }

    var currentStreak: Int {
        var streak = 0
        let sortedData = weeklySteps.sorted { $0.date > $1.date }

        for day in sortedData {
            if day.isGoalMet {
                streak += 1
            } else {
                // Don't break streak just because today isn't finished
                if Calendar.current.isDateInToday(day.date) {
                    continue
                }
                break
            }
        }
        return streak
    }

    // MARK: - Initialization

    init() {
        setupObservers()
        loadGoalFromSettings()
    }

    // MARK: - Setup

    private func setupObservers() {
        // Observe StepRepository for authoritative monotonic ratchet values
        // (uses max(pedometer, healthKit) - never decreases during day)
        stepRepository.$todaySteps
            .receive(on: DispatchQueue.main)
            .sink { [weak self] steps in
                guard let self = self else { return }
                self.todaySteps = steps
                self.checkIncrementMilestone()
            }
            .store(in: &cancellables)

        stepRepository.$todayDistance
            .receive(on: DispatchQueue.main)
            .assign(to: &$todayDistance)

        stepRepository.$stepGoal
            .receive(on: DispatchQueue.main)
            .sink { [weak self] goal in
                guard let self = self, goal > 0 else { return }
                self.dailyGoal = goal
            }
            .store(in: &cancellables)

        stepTrackingService.$error
            .receive(on: DispatchQueue.main)
            .assign(to: &$error)

        // Debug: Track changes to currentInsight
        $currentInsight
            .scan((old: nil as (id: String, message: String)?, new: nil as (id: String, message: String)?)) { ($0.new, $1) }
            .sink { [weak self] change in
                guard self != nil else { return }
                let oldId = change.old?.id ?? "nil"
                let newId = change.new?.id ?? "nil"
                if oldId != newId {
                    print("💡 currentInsight changed: \(oldId) → \(newId)")
                    if change.new == nil && change.old != nil {
                        print("   ⚠️ INSIGHT WAS CLEARED!")
                        Thread.callStackSymbols.prefix(10).forEach { print("      \($0)") }
                    }
                }
            }
            .store(in: &cancellables)

        // Listen for CloudKit sync updates (DailyStats synced from other devices)
        NotificationCenter.default.publisher(for: .NSPersistentStoreRemoteChange)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                Task { @MainActor in
                    await self?.loadData()
                }
            }
            .store(in: &cancellables)

        // Listen for workout saves (local session completed)
        NotificationCenter.default.publisher(for: .workoutSaved)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                Task { @MainActor in
                    await self?.loadData()
                }
            }
            .store(in: &cancellables)

        // Listen for debug history updates
        NotificationCenter.default.publisher(for: .debugHistoryUpdated)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                Task { [weak self] in
                    // Slight delay to ensure simulation writes
                    try? await Task.sleep(nanoseconds: 500_000_000) // 0.5s
                    await self?.loadData()
                }
            }
            .store(in: &cancellables)

        // Listen for step goal changes (retroactive recalculation completed)
        NotificationCenter.default.publisher(for: .stepGoalDidChange)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                Task { @MainActor in
                    await self?.loadData()
                }
            }
            .store(in: &cancellables)

        #if DEBUG
        // Listen for test scenario changes
        NotificationCenter.default.publisher(for: .testDataScenarioChanged)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                Task { @MainActor in
                    await self?.loadData()
                }
            }
            .store(in: &cancellables)
        #endif
    }

    private func loadGoalFromSettings() {
        let savedGoal = UserDefaults.standard.integer(forKey: "dailyStepGoal")
        if savedGoal > 0 {
            dailyGoal = savedGoal
        }
    }

    // MARK: - Data Loading

    func loadData() async {
        print("📱 loadData() called")
        isLoading = true
        error = nil

        #if DEBUG
        // Check if using test data
        if TestDataProvider.shared.isTestDataEnabled {
            self.todaySteps = TestDataProvider.shared.todaySteps
            self.todayDistance = TestDataProvider.shared.todayDistance
            self.weeklySteps = TestDataProvider.shared.generateStepHistory(days: 7, dailyGoal: dailyGoal)
            self.yearlySteps = TestDataProvider.shared.generateStepHistory(days: 365, dailyGoal: dailyGoal)
            let totalMeters = yearlySteps.reduce(0.0) { $0 + ($1.distance ?? 0) }
            self.totalMiles = totalMeters * 0.000621371
            updateCoachingTips()
            refreshInsight()
            isLoading = false
            return
        }
        #endif

        // Use StepRepository as the source of truth (monotonic ratchet)
        self.todaySteps = stepRepository.todaySteps
        self.todayDistance = stepRepository.todayDistance
        self.dailyGoal = stepRepository.stepGoal > 0 ? stepRepository.stepGoal : dailyGoal

        // Fetch active calories from HealthKit (nil if unavailable)
        self.todayCalories = await healthKitService.fetchTodayActiveCalories()

        // Load history for chart
        await fetchWeeklyData()

        // Load total miles for distance comparison
        await fetchTotalMiles()

        // Retry logic: If history seems empty (0 steps total), wait and try once more.
        // This handles HealthKit "cold start" latency where it might return 0s initially.
        let totalHistory = weeklySteps.reduce(0) { $0 + $1.steps }
        if totalHistory == 0 {
            try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second delay
            await fetchWeeklyData()
        }

        // Start live updates
        stepTrackingService.startTodayUpdates()

        // Update coaching tip
        updateCoachingTips()

        // Refresh insight card
        refreshInsight()

        isLoading = false

        // Mark initial load as complete after brief delay (allows animations to settle)
        if !hasCompletedInitialLoad {
            try? await Task.sleep(nanoseconds: 100_000_000) // 0.1s buffer
            hasCompletedInitialLoad = true
        }
    }

    func refreshTodayData() async {
        // Debounce: Prevent rapid refreshes (minimum 2 seconds apart)
        if let lastRefresh = lastRefreshTime,
           Date().timeIntervalSince(lastRefresh) < minimumRefreshInterval {
            print("📱 Refresh skipped - too soon since last refresh (\(String(format: "%.1f", Date().timeIntervalSince(lastRefresh)))s ago)")
            return
        }

        // Prevent concurrent refreshes
        guard !isRefreshing else {
            print("📱 Refresh skipped - already in progress")
            return
        }

        isRefreshing = true
        lastRefreshTime = Date()

        let oldSteps = self.todaySteps
        print("📱 refreshTodayData() called - Before: \(oldSteps) steps")

        #if DEBUG
        // If using test data, just reload from TestDataProvider
        if TestDataProvider.shared.isTestDataEnabled {
            await loadData()
            isRefreshing = false
            HapticService.shared.playSuccess()
            return
        }
        #endif

        // Force StepRepository to re-query all data sources
        await stepRepository.forceRefresh()

        // Update local state from repository
        self.todaySteps = stepRepository.todaySteps
        self.todayDistance = stepRepository.todayDistance

        // Refresh calories from HealthKit
        self.todayCalories = await healthKitService.fetchTodayActiveCalories()

        print("📱 refreshTodayData() complete - After: \(todaySteps) steps (change: \(todaySteps - oldSteps))")

        updateCoachingTips()
        await fetchWeeklyData() // Refresh weekly data as well
        checkIncrementMilestone()
        refreshInsight(force: true) // Force re-evaluate insight based on new data

        // Clear any previous error
        self.refreshError = nil

        // Success haptic on complete
        HapticService.shared.playSuccess()

        isRefreshing = false
    }
    
    private func fetchWeeklyData() async {
        // Fetch from SwiftData DailyStats (Book of Record)
        // This includes CloudKit-synced data from other devices
        weeklySteps = await stepRepository.fetchHistoricalStepData(forPastDays: 7)
    }

    private func fetchTotalMiles() async {
        // Fetch from SwiftData DailyStats (Book of Record)
        let yearlyData = await stepRepository.fetchHistoricalStepData(forPastDays: 365)
        let totalMeters = yearlyData.reduce(0.0) { $0 + ($1.distance ?? 0) }
        let miles = totalMeters * 0.000621371
        self.totalMiles = miles
        self.yearlySteps = yearlyData
    }

    func stopUpdates() {
        stepTrackingService.stopTodayUpdates()
    }

    // MARK: - Insight System

    func refreshInsight(force: Bool = false) {
        print("🔄 refreshInsight called (force: \(force), currentInsight: \(currentInsight?.id ?? "nil"))")

        // Don't refresh if we already have an insight showing (unless forced)
        if currentInsight != nil && !force {
            print("   ⏭️ Skipping - already have insight: \(currentInsight!.id)")
            return
        }

        // Prevent concurrent refreshes
        guard !isRefreshingInsight else {
            print("   ⏭️ Skipping - refresh already in progress")
            return
        }
        isRefreshingInsight = true
        defer {
            isRefreshingInsight = false
            print("🔄 refreshInsight completed")
        }

        let state = buildUserState()
        print("   📊 UserState: steps=\(state.stepsToday), goal=\(state.stepGoal), hour=\(state.hourOfDay), goalMet=\(state.goalMetToday), streak=\(state.currentStreak)")

        let result = insightEvaluator.getBestInsight(for: state)
        currentInsight = result
        print("   🎯 Result: \(result?.id ?? "nil")")
    }

    private func buildUserState() -> UserState {
        let calendar = Calendar.current
        let now = Date()
        let hour = calendar.component(.hour, from: now)
        let minute = calendar.component(.minute, from: now)
        let dayOfWeek = calendar.component(.weekday, from: now)
        let isWeekend = dayOfWeek == 1 || dayOfWeek == 7

        // Calculate minutes until midnight
        let endOfDay = calendar.startOfDay(for: now).addingTimeInterval(24 * 60 * 60)
        let minutesUntilMidnight = Int(endOfDay.timeIntervalSince(now) / 60)

        // Get streak info
        let streakService = StreakService.shared
        let streakData = streakService.getStreakData()
        let currentStreak = streakService.currentStreak
        let shieldsRemaining = streakData?.shieldsRemaining ?? 0

        // Get yesterday's data
        let yesterday = calendar.date(byAdding: .day, value: -1, to: now)!
        let yesterdayData = weeklySteps.first { calendar.isDate($0.date, inSameDayAs: yesterday) }
        let stepsYesterdayTotal = yesterdayData?.steps ?? 0
        let goalMetYesterday = yesterdayData?.isGoalMet ?? false

        // Calculate steps at same time yesterday (approximate based on ratio)
        let hourRatio = Double(hour * 60 + minute) / (24.0 * 60.0)
        let stepsYesterdaySameTime = Int(Double(stepsYesterdayTotal) * hourRatio)

        // Calculate 7-day average
        let recentDays = weeklySteps.filter { $0.steps > 0 }
        let averageDailySteps = recentDays.isEmpty ? 0 : recentDays.reduce(0) { $0 + $1.steps } / recentDays.count

        // Days active this week
        let daysActiveThisWeek = weeklySteps.filter { $0.steps >= dailyGoal }.count

        // Check if goal was just hit (within last 5 minutes)
        let justHitGoal = goalReached && (Date().timeIntervalSince1970 - lastGoalReachedDate) < 300

        // Track when goal was reached
        if goalReached && lastGoalReachedDate < calendar.startOfDay(for: now).timeIntervalSince1970 {
            lastGoalReachedDate = Date().timeIntervalSince1970
        }

        // Check pro status
        let isPro = StoreManager.shared.ownsLifetime

        return UserState(
            stepsToday: todaySteps,
            stepGoal: dailyGoal,
            stepsRemaining: stepsRemaining,
            percentComplete: goalProgress * 100,
            distanceToday: todayDistance * 0.000621371, // meters to miles
            caloriesToday: Int(Double(todaySteps) * 0.04), // rough estimate
            currentStreak: currentStreak,
            longestStreak: streakData?.longestStreak ?? 0,
            hasStreakShield: shieldsRemaining > 0,
            shieldsRemaining: shieldsRemaining,
            stepsYesterdaySameTime: stepsYesterdaySameTime,
            stepsYesterdayTotal: stepsYesterdayTotal,
            averageDailySteps: averageDailySteps,
            daysActiveThisWeek: daysActiveThisWeek,
            hourOfDay: hour,
            minutesUntilMidnight: minutesUntilMidnight,
            dayOfWeek: dayOfWeek,
            isWeekend: isWeekend,
            lastInsightShownId: nil,
            lastInsightShownDate: nil,
            isPro: isPro,
            goalMetToday: goalReached,
            goalMetYesterday: goalMetYesterday,
            justHitGoal: justHitGoal
        )
    }

    // MARK: - Coaching

    private func updateCoachingTips() {
        currentCoachingTip = CoachingService.shared.generateTip(
            currentSteps: todaySteps,
            dailyGoal: dailyGoal
        )
        
        contextualTips = CoachingService.shared.generateContextualTips(
            steps: todaySteps,
            goal: dailyGoal
        )
    }

    private func checkIncrementMilestone() {
        let currentIncrement = incrementsAchieved

        if currentIncrement > lastIncrementCelebrated {
            lastIncrementCelebrated = currentIncrement
            currentCoachingTip = CoachingTipTemplates.incrementMilestone(increment: currentIncrement)

            // Play haptic feedback for increment milestone
            hapticService.playIncrementMilestone()
        }

        // Check if goal was just reached
        if goalReached && !lastGoalReached {
            lastGoalReached = true
            hapticService.playGoalReached()
        } else if !goalReached {
            lastGoalReached = false
        }

        // Play near-goal haptic when within 500 steps
        if stepsRemaining > 0 && stepsRemaining <= 500 && stepsRemaining % 100 == 0 {
            hapticService.playNearGoal()
        }
    }

    func getRandomTip() {
        let allTips = CoachingTipTemplates.motivationTips +
                      CoachingTipTemplates.healthTips +
                      CoachingTipTemplates.iwtTips

        currentCoachingTip = allTips.randomElement()
    }

    // MARK: - Goal Management

    func updateDailyGoal(_ newGoal: Int) {
        // Ensure goal is in 500-step increments
        dailyGoal = (newGoal / 500) * 500
        dailyGoal = max(500, min(50000, dailyGoal))
        UserDefaults.standard.set(dailyGoal, forKey: "dailyStepGoal")
    }
}

extension Notification.Name {
    static let debugHistoryUpdated = Notification.Name("debugHistoryUpdated")
}
