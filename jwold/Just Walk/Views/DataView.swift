//
//  DataView.swift
//  Just Walk
//
//  Step metrics view with 2 Weeks/Month/Year toggle.
//  Free users: 2 Weeks tab only. Pro users: Full 12-month history.
//

import SwiftUI
import Charts

struct DataView: View {
    @StateObject private var viewModel = DataViewModel()
    @ObservedObject private var freeTierManager = FreeTierManager.shared
    @State private var showPaywall = false
    @Environment(\.colorScheme) private var colorScheme

    /// Whether the selected period requires Pro access
    private var requiresProAccess: Bool {
        (viewModel.selectedPeriod == .month || viewModel.selectedPeriod == .year) && !freeTierManager.isPro
    }

    var body: some View {
        ScrollView {
            VStack(spacing: JWDesign.Spacing.cardPadding) {
                // Time Period Picker (always shown)
                periodPicker

                if requiresProAccess {
                    // Show paywall for Month/Year tabs when not Pro
                    proLockedContent
                } else {
                    // Show full content for 2 Weeks or Pro users
                    summaryStatsSection
                    chartSection
                    detailListSection
                }
            }
            .padding(.vertical, JWDesign.Spacing.cardPadding)
        }
        .background(JWDesign.Colors.background)
        .navigationTitle("Step Metrics")
        .navigationBarTitleDisplayMode(.inline)
        .refreshable {
            await viewModel.loadData()
        }
        .sheet(isPresented: $showPaywall) {
            ProPaywallView()
        }
    }

    // MARK: - Pro Locked Content

    private var proLockedContent: some View {
        VStack(spacing: JWDesign.Spacing.xl) {
            Spacer()
                .frame(height: 40)

            // Lock icon with gradient background
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [
                                JWDesign.Colors.brandSecondary.opacity(0.2),
                                JWDesign.Colors.brandPrimary.opacity(0.2)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 100, height: 100)

                Image(systemName: "chart.bar.fill")
                    .font(.system(size: 44))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [JWDesign.Colors.brandSecondary, JWDesign.Colors.brandPrimary],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }

            VStack(spacing: JWDesign.Spacing.sm) {
                Text("Unlock 12-Month History")
                    .font(.title2)
                    .fontWeight(.bold)
                    .multilineTextAlignment(.center)

                Text("Get access to a full year of step metrics, trends, and insights with Just Walk Pro.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, JWDesign.Spacing.lg)
            }

            // Feature highlights
            VStack(alignment: .leading, spacing: JWDesign.Spacing.md) {
                proFeatureRow(icon: "calendar", text: "30-day and 365-day metrics")
                proFeatureRow(icon: "chart.xyaxis.line", text: "Monthly step totals chart")
                proFeatureRow(icon: "list.bullet", text: "Full daily log with filters")
            }
            .padding(.horizontal, JWDesign.Spacing.xl)

            // Unlock button
            Button {
                showPaywall = true
            } label: {
                HStack(spacing: JWDesign.Spacing.sm) {
                    Image(systemName: "crown.fill")
                        .font(.system(size: 14))
                    Text("Unlock with Pro")
                        .font(.headline)
                        .fontWeight(.bold)
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(
                    LinearGradient(
                        colors: [JWDesign.Colors.brandSecondary, JWDesign.Colors.brandPrimary],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .clipShape(Capsule())
                .shadow(color: JWDesign.Colors.brandPrimary.opacity(0.3), radius: 8, y: 4)
            }
            .padding(.horizontal, JWDesign.Spacing.xl)

            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    private func proFeatureRow(icon: String, text: String) -> some View {
        HStack(spacing: JWDesign.Spacing.md) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(JWDesign.Colors.brandPrimary)
                .frame(width: 24)

            Text(text)
                .font(.subheadline)
                .foregroundStyle(.primary)

            Spacer()
        }
    }

    // MARK: - Period Picker

    private var periodPicker: some View {
        Picker("Time Period", selection: $viewModel.selectedPeriod) {
            ForEach(HistoryTimePeriod.allCases, id: \.self) { period in
                Text(period.rawValue).tag(period)
            }
        }
        .pickerStyle(.segmented)
        .padding(.horizontal, JWDesign.Spacing.horizontalInset)
    }

    // MARK: - Summary Stats

    private var summaryStatsSection: some View {
        LazyVGrid(columns: [
            GridItem(.flexible()),
            GridItem(.flexible())
        ], spacing: JWDesign.Spacing.cardPadding) {
            switch viewModel.selectedPeriod {
            case .twoWeeks:
                StatSummaryCard(
                    title: "14-Day Avg",
                    value: viewModel.formatLargeNumber(viewModel.twoWeeksAverageSteps),
                    subtitle: "steps per day",
                    icon: "chart.bar.fill",
                    color: JWDesign.Colors.brandPrimary
                )

                StatSummaryCard(
                    title: "14-Day Total",
                    value: viewModel.formatLargeNumber(viewModel.twoWeeksTotalSteps),
                    subtitle: "steps",
                    icon: "sum",
                    color: JWDesign.Colors.recovery
                )

                StatSummaryCard(
                    title: "Days at Goal",
                    value: "\(viewModel.twoWeeksDaysAtGoal)",
                    subtitle: "of 14 days",
                    icon: "checkmark.circle.fill",
                    color: JWDesign.Colors.success
                )

                StatSummaryCard(
                    title: "Distance",
                    value: viewModel.formatDistance(viewModel.twoWeeksTotalDistance),
                    subtitle: "in 14 days",
                    icon: "figure.walk",
                    color: JWDesign.Colors.warning
                )

            case .month:
                StatSummaryCard(
                    title: "30-Day Avg",
                    value: viewModel.formatLargeNumber(viewModel.monthAverageSteps),
                    subtitle: "steps per day",
                    icon: "chart.bar.fill",
                    color: JWDesign.Colors.brandPrimary
                )

                StatSummaryCard(
                    title: "30-Day Total",
                    value: viewModel.formatLargeNumber(viewModel.monthTotalSteps),
                    subtitle: "steps",
                    icon: "sum",
                    color: JWDesign.Colors.recovery
                )

                StatSummaryCard(
                    title: "Days at Goal",
                    value: "\(viewModel.monthDaysAtGoal)",
                    subtitle: "of 30 days",
                    icon: "checkmark.circle.fill",
                    color: JWDesign.Colors.success
                )

                StatSummaryCard(
                    title: "Distance",
                    value: viewModel.formatDistance(viewModel.monthTotalDistance),
                    subtitle: "in 30 days",
                    icon: "figure.walk",
                    color: JWDesign.Colors.warning
                )

            case .year:
                StatSummaryCard(
                    title: "365-Day Avg",
                    value: viewModel.formatLargeNumber(viewModel.yearAverageSteps),
                    subtitle: "steps per day",
                    icon: "chart.bar.fill",
                    color: JWDesign.Colors.brandPrimary
                )

                StatSummaryCard(
                    title: "365-Day Total",
                    value: viewModel.formatLargeNumber(viewModel.yearTotalSteps),
                    subtitle: "steps",
                    icon: "sum",
                    color: JWDesign.Colors.recovery
                )

                StatSummaryCard(
                    title: "Days at Goal",
                    value: "\(viewModel.yearDaysAtGoal)",
                    subtitle: "of 365 days",
                    icon: "checkmark.circle.fill",
                    color: JWDesign.Colors.success
                )

                StatSummaryCard(
                    title: "Distance",
                    value: viewModel.formatDistance(viewModel.yearTotalDistance),
                    subtitle: "in 365 days",
                    icon: "figure.walk",
                    color: JWDesign.Colors.warning
                )
            }
        }
        .padding(.horizontal, JWDesign.Spacing.horizontalInset)
    }

    // MARK: - Chart Section

    private var chartSection: some View {
        VStack(alignment: .leading, spacing: JWDesign.Spacing.md) {
            Text(chartTitle)
                .font(JWDesign.Typography.headline)
                .padding(.horizontal, JWDesign.Spacing.horizontalInset)

            Group {
                switch viewModel.selectedPeriod {
                case .twoWeeks:
                    twoWeeksChart
                case .month:
                    monthChart
                case .year:
                    yearChart
                }
            }
            .frame(height: 180)
            .padding(.horizontal, JWDesign.Spacing.horizontalInset)
        }
        .padding(.vertical, JWDesign.Spacing.md)
        .background(JWDesign.Colors.secondaryBackground)
        .clipShape(RoundedRectangle(cornerRadius: JWDesign.Radius.card))
        .padding(.horizontal, JWDesign.Spacing.horizontalInset)
    }

    private var chartTitle: String {
        switch viewModel.selectedPeriod {
        case .twoWeeks: return "Last 14 Days"
        case .month: return "Last 30 Days"
        case .year: return "Last 12 Months"
        }
    }

    // MARK: - Two Weeks Chart (matches home screen Weekly Activity style)

    private var twoWeeksChart: some View {
        Chart {
            ForEach(viewModel.recentDaysForChart) { day in
                BarMark(
                    x: .value("Date", day.date, unit: .day),
                    y: .value("Steps", day.steps)
                )
                .foregroundStyle(twoWeeksBarColor(for: day))
                .clipShape(Capsule())
                .annotation(position: .top, spacing: 4) {
                    Text(viewModel.formatCompact(day.steps))
                        .font(JWDesign.Typography.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            // Goal reference line
            RuleMark(y: .value("Goal", viewModel.dailyGoal))
                .lineStyle(StrokeStyle(lineWidth: 1, dash: [5]))
                .foregroundStyle(JWDesign.Colors.warning.opacity(0.6))
        }
        .chartYAxis(.hidden)
        .chartXAxis {
            AxisMarks(preset: .aligned, position: .bottom, values: .stride(by: .day, count: 2)) { value in
                AxisValueLabel(format: .dateTime.day(), centered: true)
            }
        }
    }

    /// Bar color matching home screen: mint if goal reached, blue for today, faded blue for past days
    private func twoWeeksBarColor(for day: DayStepData) -> Color {
        if day.isGoalMet {
            return .mint
        } else if Calendar.current.isDateInToday(day.date) {
            return .blue
        } else {
            return .blue.opacity(0.4)
        }
    }

    // MARK: - Month Chart (Last 30 days)

    private var monthChart: some View {
        Chart {
            ForEach(viewModel.monthData) { day in
                BarMark(
                    x: .value("Date", day.date, unit: .day),
                    y: .value("Steps", day.steps)
                )
                .foregroundStyle(monthBarColor(for: day))
                .clipShape(Capsule())
            }

            // Goal reference line
            RuleMark(y: .value("Goal", viewModel.dailyGoal))
                .lineStyle(StrokeStyle(lineWidth: 1, dash: [5]))
                .foregroundStyle(JWDesign.Colors.warning.opacity(0.6))
        }
        .chartYAxis(.hidden)
        .chartXAxis {
            AxisMarks(preset: .aligned, position: .bottom, values: .stride(by: .day, count: 7)) { value in
                AxisValueLabel(format: .dateTime.day(), centered: true)
            }
        }
    }

    /// Bar color for month chart
    private func monthBarColor(for day: DayStepData) -> Color {
        if day.isGoalMet {
            return .mint
        } else if Calendar.current.isDateInToday(day.date) {
            return .cyan
        } else {
            return .cyan.opacity(0.4)
        }
    }

    // MARK: - Year Chart (Last 12 months with monthly totals)

    private var yearChart: some View {
        Chart {
            ForEach(viewModel.last12MonthsForChart) { month in
                BarMark(
                    x: .value("Month", month.monthLabel),
                    y: .value("Steps", month.steps)
                )
                .foregroundStyle(yearBarColor(for: month))
                .clipShape(Capsule())
                .annotation(position: .top, spacing: 4) {
                    Text(viewModel.formatCompactRounded(month.steps))
                        .font(JWDesign.Typography.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .chartYAxis(.hidden)
        .chartXAxis {
            AxisMarks(position: .bottom) { _ in
                AxisValueLabel()
            }
        }
    }

    /// Bar color for year chart: teal tones
    private func yearBarColor(for month: MonthStepData) -> Color {
        // Check if monthly average meets daily goal
        if month.avgDaily >= viewModel.dailyGoal {
            return .mint
        } else {
            return .teal.opacity(0.6)
        }
    }

    // MARK: - Detail List Section

    private var detailListSection: some View {
        VStack(alignment: .leading, spacing: JWDesign.Spacing.md) {
            HStack {
                Text(detailListTitle)
                    .font(JWDesign.Typography.headline)
                Spacer()
                Text(detailListSubtitle)
                    .font(JWDesign.Typography.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, JWDesign.Spacing.horizontalInset)

            // Month filter for Year tab
            if viewModel.selectedPeriod == .year {
                yearMonthFilterPicker
            }

            LazyVStack(spacing: JWDesign.Spacing.listRowSpacing) {
                switch viewModel.selectedPeriod {
                case .twoWeeks:
                    ForEach(viewModel.twoWeeksData) { day in
                        dayRow(day)
                    }
                case .month:
                    ForEach(viewModel.monthData) { day in
                        dayRow(day)
                    }
                case .year:
                    ForEach(viewModel.filteredYearData) { day in
                        dayRow(day)
                    }
                }
            }
            .padding(.horizontal, JWDesign.Spacing.horizontalInset)
        }
    }

    // MARK: - Year Month Filter Picker

    private var yearMonthFilterPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: JWDesign.Spacing.sm) {
                // "All" option
                Button {
                    viewModel.selectedYearMonthFilter = nil
                } label: {
                    Text("All")
                        .font(JWDesign.Typography.caption)
                        .fontWeight(viewModel.selectedYearMonthFilter == nil ? .semibold : .regular)
                        .foregroundStyle(viewModel.selectedYearMonthFilter == nil ? .white : .primary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            viewModel.selectedYearMonthFilter == nil
                                ? JWDesign.Colors.brandPrimary
                                : JWDesign.Colors.secondaryBackground
                        )
                        .clipShape(Capsule())
                }

                // Month options
                ForEach(viewModel.availableMonthsForFilter, id: \.self) { monthDate in
                    Button {
                        viewModel.selectedYearMonthFilter = monthDate
                    } label: {
                        Text(monthFilterLabel(monthDate))
                            .font(JWDesign.Typography.caption)
                            .fontWeight(isMonthSelected(monthDate) ? .semibold : .regular)
                            .foregroundStyle(isMonthSelected(monthDate) ? .white : .primary)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(
                                isMonthSelected(monthDate)
                                    ? JWDesign.Colors.brandPrimary
                                    : JWDesign.Colors.secondaryBackground
                            )
                            .clipShape(Capsule())
                    }
                }
            }
            .padding(.horizontal, JWDesign.Spacing.horizontalInset)
        }
    }

    private func monthFilterLabel(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM"
        return formatter.string(from: date)
    }

    private func isMonthSelected(_ date: Date) -> Bool {
        guard let selected = viewModel.selectedYearMonthFilter else { return false }
        let calendar = Calendar.current
        return calendar.isDate(date, equalTo: selected, toGranularity: .month)
    }

    private var detailListTitle: String {
        switch viewModel.selectedPeriod {
        case .twoWeeks: return "Daily Log"
        case .month: return "Daily Log"
        case .year: return "Daily Log"
        }
    }

    private var detailListSubtitle: String {
        switch viewModel.selectedPeriod {
        case .twoWeeks: return "\(viewModel.twoWeeksData.count) days"
        case .month: return "\(viewModel.monthData.count) days"
        case .year: return "\(viewModel.filteredYearData.count) days"
        }
    }

    // MARK: - Row Views

    private func dayRow(_ day: DayStepData) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: JWDesign.Spacing.xs) {
                Text(viewModel.formatDate(day.date))
                    .font(JWDesign.Typography.subheadline)
                    .foregroundStyle(.secondary)

                Text(viewModel.formatSteps(day.steps))
                    .font(JWDesign.Typography.headlineBold)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: JWDesign.Spacing.xs) {
                if day.steps >= viewModel.dailyGoal {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(JWDesign.Colors.success)
                }
                Text(viewModel.formatDistance(day.distance ?? 0))
                    .font(JWDesign.Typography.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(JWDesign.Spacing.cardPadding)
        .background(JWDesign.Colors.secondaryBackground)
        .clipShape(RoundedRectangle(cornerRadius: JWDesign.Radius.medium))
    }

}

#Preview {
    NavigationStack {
        DataView()
    }
}
