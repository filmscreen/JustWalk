import Foundation
import SwiftUI
import Combine
import Charts
import CoreData

// MARK: - Time Period Enum

enum HistoryTimePeriod: String, CaseIterable {
    case twoWeeks = "14 Days"
    case month = "Month"
    case year = "Year"
}

// MARK: - Aggregated Data Models

struct MonthStepData: Identifiable {
    let id = UUID()
    let date: Date // First day of month
    let steps: Int
    let avgDaily: Int
    let daysTracked: Int

    var monthLabel: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM"
        return formatter.string(from: date)
    }

    var monthYearLabel: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM yyyy"
        return formatter.string(from: date)
    }
}

struct YearStepData: Identifiable {
    let id = UUID()
    let year: Int
    let steps: Int
    let avgDaily: Int
    let daysTracked: Int

    var yearLabel: String {
        "\(year)"
    }
}

@MainActor
class DataViewModel: ObservableObject {

    // MARK: - Published Properties
    @Published var historyLog: [DayStepData] = []
    @Published var fullHistoryLog: [DayStepData] = [] // Unfiltered for Pro calculations
    @Published var monthlyData: [MonthStepData] = []
    @Published var yearlyData: [YearStepData] = []
    @Published var isLoading = false
    @Published var showUpgradePrompt = false
    @Published var selectedPeriod: HistoryTimePeriod = .twoWeeks

    // Initial load tracking (for animation suppression)
    @Published var hasCompletedInitialLoad: Bool = false

    // MARK: - Services
    private let stepRepository = StepRepository.shared
    private let stepTrackingService = StepTrackingService.shared
    private let freeTierManager = FreeTierManager.shared

    // MARK: - Cancellables
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Re-entry Guard
    private var isCurrentlyLoading = false
    private var lastRemoteChangeTime: Date = .distantPast

    // MARK: - Free Tier Properties

    /// Number of days hidden due to free tier
    var hiddenDaysCount: Int {
        guard !freeTierManager.isPro else { return 0 }
        return max(0, fullHistoryLog.count - historyLog.count)
    }

    /// Whether user is on free tier with limited history
    var isHistoryLimited: Bool {
        !freeTierManager.isPro && hiddenDaysCount > 0
    }

    /// Whether user can access extended history (months/years views)
    var canAccessExtendedHistory: Bool {
        freeTierManager.isPro
    }

    // MARK: - 14-Day Computed Stats (for 2 Weeks tab)

    /// Last 14 days of data
    var twoWeeksData: [DayStepData] {
        Array(historyLog.prefix(14))
    }

    /// Average steps per day over past 14 days
    var twoWeeksAverageSteps: Int {
        let validDays = twoWeeksData.filter { $0.steps > 0 }
        guard !validDays.isEmpty else { return 0 }
        return validDays.reduce(0) { $0 + $1.steps } / validDays.count
    }

    /// Total steps over past 14 days
    var twoWeeksTotalSteps: Int {
        twoWeeksData.reduce(0) { $0 + $1.steps }
    }

    /// Days at goal in past 14 days
    var twoWeeksDaysAtGoal: Int {
        twoWeeksData.filter { $0.isGoalMet }.count
    }

    /// Total distance over past 14 days (in meters)
    var twoWeeksTotalDistance: Double {
        twoWeeksData.reduce(0) { $0 + ($1.distance ?? 0) }
    }

    // MARK: - 30-Day Computed Stats (for Month tab)

    /// Last 30 days of data
    var monthData: [DayStepData] {
        Array(historyLog.prefix(30))
    }

    /// Average steps per day over past 30 days
    var monthAverageSteps: Int {
        let validDays = monthData.filter { $0.steps > 0 }
        guard !validDays.isEmpty else { return 0 }
        return validDays.reduce(0) { $0 + $1.steps } / validDays.count
    }

    /// Total steps over past 30 days
    var monthTotalSteps: Int {
        monthData.reduce(0) { $0 + $1.steps }
    }

    /// Days at goal in past 30 days
    var monthDaysAtGoal: Int {
        monthData.filter { $0.isGoalMet }.count
    }

    /// Total distance over past 30 days (in meters)
    var monthTotalDistance: Double {
        monthData.reduce(0) { $0 + ($1.distance ?? 0) }
    }

    // MARK: - 365-Day Computed Stats (for Year tab)

    /// Last 365 days of data
    var yearData: [DayStepData] {
        Array(fullHistoryLog.prefix(365))
    }

    /// Average steps per day over past 365 days
    var yearAverageSteps: Int {
        let validDays = yearData.filter { $0.steps > 0 }
        guard !validDays.isEmpty else { return 0 }
        return validDays.reduce(0) { $0 + $1.steps } / validDays.count
    }

    /// Total steps over past 365 days
    var yearTotalSteps: Int {
        yearData.reduce(0) { $0 + $1.steps }
    }

    /// Days at goal in past 365 days
    var yearDaysAtGoal: Int {
        yearData.filter { $0.isGoalMet }.count
    }

    /// Total distance over past 365 days (in meters)
    var yearTotalDistance: Double {
        yearData.reduce(0) { $0 + ($1.distance ?? 0) }
    }

    // MARK: - All Time Computed Stats (Pro only)

    /// All time data (all available historical data)
    var allTimeData: [DayStepData] {
        fullHistoryLog
    }

    /// Average steps per day all time
    var allTimeAverageSteps: Int {
        let validDays = allTimeData.filter { $0.steps > 0 }
        guard !validDays.isEmpty else { return 0 }
        return validDays.reduce(0) { $0 + $1.steps } / validDays.count
    }

    /// Total steps all time
    var allTimeTotalSteps: Int {
        allTimeData.reduce(0) { $0 + $1.steps }
    }

    /// Days at goal all time
    var allTimeDaysAtGoal: Int {
        allTimeData.filter { $0.isGoalMet }.count
    }

    /// Total distance all time (in meters)
    var allTimeTotalDistance: Double {
        allTimeData.reduce(0) { $0 + ($1.distance ?? 0) }
    }

    /// Monthly totals for the year chart (always 12 months, including months with 0 data)
    var last12MonthsForChart: [MonthStepData] {
        let calendar = Calendar.current

        // Build dict of actual data
        var monthDict: [DateComponents: (steps: Int, count: Int)] = [:]
        for day in yearData {
            let components = calendar.dateComponents([.year, .month], from: day.date)
            if let existing = monthDict[components] {
                monthDict[components] = (existing.steps + day.steps, existing.count + 1)
            } else {
                monthDict[components] = (day.steps, 1)
            }
        }

        // Generate all 12 months (including current month going back 11 months)
        var result: [MonthStepData] = []
        for monthOffset in (0..<12).reversed() {
            guard let monthDate = calendar.date(byAdding: .month, value: -monthOffset, to: Date()),
                  let startOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: monthDate)) else { continue }

            let components = calendar.dateComponents([.year, .month], from: startOfMonth)

            if let data = monthDict[components] {
                result.append(MonthStepData(
                    date: startOfMonth,
                    steps: data.steps,
                    avgDaily: data.count > 0 ? data.steps / data.count : 0,
                    daysTracked: data.count
                ))
            } else {
                // No data for this month - add with 0 steps
                result.append(MonthStepData(
                    date: startOfMonth,
                    steps: 0,
                    avgDaily: 0,
                    daysTracked: 0
                ))
            }
        }

        return result
    }

    // MARK: - Year Tab Month Filter

    @Published var selectedYearMonthFilter: Date? = nil

    /// Available months for the filter dropdown (always 12 months, most recent first)
    var availableMonthsForFilter: [Date] {
        let calendar = Calendar.current
        var months: [Date] = []

        // Generate all 12 months (current month first, going back 11 months)
        for monthOffset in 0..<12 {
            guard let monthDate = calendar.date(byAdding: .month, value: -monthOffset, to: Date()),
                  let startOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: monthDate)) else { continue }
            months.append(startOfMonth)
        }

        return months // Already sorted most recent first
    }

    /// Filtered year data based on selected month
    var filteredYearData: [DayStepData] {
        guard let selectedMonth = selectedYearMonthFilter else {
            return yearData
        }

        let calendar = Calendar.current
        let selectedComponents = calendar.dateComponents([.year, .month], from: selectedMonth)

        return yearData.filter { day in
            let dayComponents = calendar.dateComponents([.year, .month], from: day.date)
            return dayComponents.year == selectedComponents.year && dayComponents.month == selectedComponents.month
        }
    }

    /// Format month for filter display
    func formatMonthForFilter(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: date)
    }

    // MARK: - General Computed Stats

    var averageSteps: Int {
        let validDays = historyLog.filter { $0.steps > 0 }
        guard !validDays.isEmpty else { return 0 }
        return validDays.reduce(0) { $0 + $1.steps } / validDays.count
    }

    var totalStepsHistory: Int {
        historyLog.reduce(0) { $0 + $1.steps }
    }

    var totalStepsAllTime: Int {
        fullHistoryLog.reduce(0) { $0 + $1.steps }
    }

    var daysAtGoal: Int {
        historyLog.filter { $0.isGoalMet }.count
    }

    /// Daily goal for chart reference line
    var dailyGoal: Int {
        let goal = UserDefaults.standard.integer(forKey: "dailyStepGoal")
        return goal > 0 ? goal : 10000
    }

    // MARK: - Initialization
    init() {
        setupObservers()
        Task {
            await loadData()
        }
    }

    private func setupObservers() {
        // Listen for CloudKit sync updates (DailyStats synced from other devices)
        // Debounce to prevent infinite loop from rapid local cache writes
        NotificationCenter.default.publisher(for: .NSPersistentStoreRemoteChange)
            .receive(on: DispatchQueue.main)
            .debounce(for: .seconds(2), scheduler: DispatchQueue.main)
            .sink { [weak self] _ in
                guard let self = self, !self.isCurrentlyLoading else { return }
                // Additional debounce: skip if we just processed a change
                let now = Date()
                guard now.timeIntervalSince(self.lastRemoteChangeTime) > 2 else { return }
                self.lastRemoteChangeTime = now
                Task { @MainActor in
                    await self.loadData()
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

        // Listen for step goal changes (retroactive recalculation completed)
        NotificationCenter.default.publisher(for: .stepGoalDidChange)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                Task { @MainActor in
                    print("📊 DataViewModel: Goal changed, reloading data")
                    await self?.loadData()
                }
            }
            .store(in: &cancellables)

        // Listen for test data scenario changes (DEBUG only)
        #if DEBUG
        NotificationCenter.default.publisher(for: .testDataScenarioChanged)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                Task { @MainActor in
                    print("📊 DataViewModel: Test scenario changed, reloading data")
                    await self?.loadData()
                }
            }
            .store(in: &cancellables)
        #endif
    }

    // MARK: - Data Loading

    func loadData() async {
        // Prevent re-entry from NSPersistentStoreRemoteChange notifications
        // triggered by local cache writes during this load
        guard !isCurrentlyLoading else { return }
        isCurrentlyLoading = true
        defer { isCurrentlyLoading = false }

        isLoading = true

        // Determine how many days to fetch based on tier
        // Always fetch at least 90 days for the activity chart on home screen
        let daysToFetch = max(90, freeTierManager.historyDaysAllowed)

        // Use test data when test mode is enabled (DEBUG only)
        #if DEBUG
        if TestDataProvider.shared.isTestDataEnabled {
            let savedGoal = UserDefaults.standard.integer(forKey: "dailyStepGoal")
            let dailyGoal = savedGoal > 0 ? savedGoal : 10_000
            let testData = TestDataProvider.shared.generateStepHistory(days: daysToFetch, dailyGoal: dailyGoal)
            self.fullHistoryLog = testData
            self.historyLog = freeTierManager.isPro ? testData : freeTierManager.filterHistoryData(testData, dateKeyPath: \.date)
            aggregateMonthlyData()
            aggregateYearlyData()
            isLoading = false
            print("📊 DataViewModel: Using test data (\(testData.count) days)")
            return
        }
        #endif

        // Fetch from SwiftData DailyStats (Book of Record)
        // This includes today's live data and CloudKit-synced data from other devices
        let data = await stepRepository.fetchHistoricalStepData(forPastDays: daysToFetch)

        // Note: Today's override is already handled in fetchHistoricalStepData()
        // It uses live StepRepository.todaySteps to match the ring immediately

        let sortedData = data.sorted { $0.date > $1.date }

        // GUARD: Don't wipe existing data if fetch returned empty or all zeros
        // This prevents race conditions from destroying the UI state
        if sortedData.isEmpty {
            print("⚠️ DataViewModel: Fetch returned empty - preserving existing data")
            isLoading = false
            return
        }

        // Check if ALL days have 0 steps (suspicious - likely a fetch failure)
        let totalSteps = sortedData.reduce(0) { $0 + $1.steps }
        let hasExistingData = !fullHistoryLog.isEmpty && fullHistoryLog.contains { $0.steps > 0 }

        if totalSteps == 0 && hasExistingData {
            print("⚠️ DataViewModel: Fetch returned all zeros but we have existing data - preserving")
            isLoading = false
            return
        }

        // Store full history
        self.fullHistoryLog = sortedData

        // Apply free tier limitation for display (30 days for free users)
        if freeTierManager.isPro {
            self.historyLog = sortedData
        } else {
            self.historyLog = freeTierManager.filterHistoryData(sortedData, dateKeyPath: \.date)
        }

        // Aggregate data for charts
        aggregateMonthlyData()
        aggregateYearlyData()

        isLoading = false

        // Mark initial load as complete after brief delay (allows animations to settle)
        if !hasCompletedInitialLoad {
            try? await Task.sleep(nanoseconds: 100_000_000) // 0.1s buffer
            hasCompletedInitialLoad = true
        }
    }

    // MARK: - Data Aggregation

    private func aggregateMonthlyData() {
        let calendar = Calendar.current
        var monthDict: [DateComponents: (steps: Int, count: Int)] = [:]

        for day in fullHistoryLog {
            let components = calendar.dateComponents([.year, .month], from: day.date)
            if let existing = monthDict[components] {
                monthDict[components] = (existing.steps + day.steps, existing.count + 1)
            } else {
                monthDict[components] = (day.steps, 1)
            }
        }

        monthlyData = monthDict.compactMap { components, data in
            guard let date = calendar.date(from: components) else { return nil }
            return MonthStepData(
                date: date,
                steps: data.steps,
                avgDaily: data.count > 0 ? data.steps / data.count : 0,
                daysTracked: data.count
            )
        }
        .sorted { $0.date > $1.date }
    }

    private func aggregateYearlyData() {
        let calendar = Calendar.current
        var yearDict: [Int: (steps: Int, count: Int)] = [:]

        for day in fullHistoryLog {
            let year = calendar.component(.year, from: day.date)
            if let existing = yearDict[year] {
                yearDict[year] = (existing.steps + day.steps, existing.count + 1)
            } else {
                yearDict[year] = (day.steps, 1)
            }
        }

        yearlyData = yearDict.map { year, data in
            YearStepData(
                year: year,
                steps: data.steps,
                avgDaily: data.count > 0 ? data.steps / data.count : 0,
                daysTracked: data.count
            )
        }
        .sorted { $0.year > $1.year }
    }

    // MARK: - Chart Data (Last N items for display)

    var recentDaysForChart: [DayStepData] {
        Array(historyLog.prefix(14).reversed()) // Last 14 days, oldest first for chart
    }

    var recentMonthsForChart: [MonthStepData] {
        Array(monthlyData.prefix(12).reversed()) // Last 12 months, oldest first
    }

    var recentYearsForChart: [YearStepData] {
        Array(yearlyData.prefix(5).reversed()) // Last 5 years, oldest first
    }

    // MARK: - Formatting

    func formatDistance(_ distance: Double) -> String {
        let miles = distance * 0.000621371
        return String(format: "%.2f mi", miles)
    }

    func formatSteps(_ steps: Int) -> String {
        steps.formatted()
    }

    func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, yyyy"
        return formatter.string(from: date)
    }

    func formatShortDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter.string(from: date)
    }

    func formatLargeNumber(_ number: Int) -> String {
        if number >= 1000000 {
            return String(format: "%.1fM", Double(number) / 1000000)
        } else if number >= 1000 {
            return String(format: "%.1fK", Double(number) / 1000)
        }
        return number.formatted()
    }

    func formatCompact(_ number: Int) -> String {
        if number >= 1000 {
            return String(format: "%.1fk", Double(number) / 1000)
        }
        return number.formatted()
    }

    /// Format number compactly without decimals (e.g., "111k")
    func formatCompactRounded(_ number: Int) -> String {
        if number >= 1000 {
            let thousands = (number + 500) / 1000 // Round to nearest thousand
            return "\(thousands)k"
        }
        return number.formatted()
    }
}
