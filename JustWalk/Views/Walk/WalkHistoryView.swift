//
//  WalkHistoryView.swift
//  JustWalk
//
//  Full walk history with filter tabs, grouping, and Pro gating
//

import SwiftUI

// MARK: - History Filter

enum HistoryFilter: String, CaseIterable, Identifiable {
    case week = "Week"
    case month = "Month"
    case year = "Year"
    case allTime = "All Time"

    var id: String { rawValue }

    var requiresPro: Bool {
        self == .year || self == .allTime
    }

    var cutoffDate: Date? {
        let calendar = Calendar.current
        let now = Date()
        switch self {
        case .week:
            return calendar.date(byAdding: .day, value: -7, to: now)
        case .month:
            return calendar.date(byAdding: .day, value: -30, to: now)
        case .year:
            return calendar.date(byAdding: .year, value: -1, to: now)
        case .allTime:
            return nil
        }
    }
}

// MARK: - WalkHistoryView

struct WalkHistoryView: View {
    @State private var selectedFilter: HistoryFilter = .month
    @State private var showUpgradeSheet = false

    private var subscriptionManager: SubscriptionManager { SubscriptionManager.shared }
    private var persistence: PersistenceManager { PersistenceManager.shared }

    private var isPro: Bool { subscriptionManager.isPro }

    private var useMetric: Bool {
        PersistenceManager.shared.cachedUseMetric
    }

    // MARK: - Filtering

    private var filteredWalks: [TrackedWalk] {
        let allWalks = persistence.loadAllTrackedWalks().filter(\.isDisplayable)

        // Safety: if not Pro and filter requires Pro, fall back to month
        let activeFilter = (!isPro && selectedFilter.requiresPro) ? .month : selectedFilter

        guard let cutoff = activeFilter.cutoffDate else {
            return allWalks.sorted { $0.startTime > $1.startTime }
        }

        return allWalks
            .filter { $0.startTime >= cutoff }
            .sorted { $0.startTime > $1.startTime }
    }

    // MARK: - Grouping

    private var groupedWalks: [(String, [TrackedWalk])] {
        let walks = filteredWalks
        guard !walks.isEmpty else { return [] }

        let activeFilter = (!isPro && selectedFilter.requiresPro) ? .month : selectedFilter

        switch activeFilter {
        case .week:
            return groupByDay(walks)
        case .month:
            return groupByWeek(walks)
        case .year, .allTime:
            return groupByMonth(walks)
        }
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            JW.Color.backgroundPrimary
                .ignoresSafeArea()

            VStack(spacing: 0) {
                filterBar
                    .padding(.horizontal, JW.Spacing.lg)
                    .padding(.vertical, JW.Spacing.md)

                if groupedWalks.isEmpty {
                    emptyState
                } else {
                    ScrollView(showsIndicators: false) {
                        LazyVStack(alignment: .leading, spacing: JW.Spacing.lg) {
                            ForEach(groupedWalks, id: \.0) { header, walks in
                                Section {
                                    ForEach(walks) { walk in
                                        WalkHistoryRowView(walk: walk, useMetric: useMetric)
                                    }
                                } header: {
                                    Text(header.uppercased())
                                        .font(JW.Font.caption)
                                        .foregroundStyle(JW.Color.textTertiary)
                                        .padding(.horizontal, JW.Spacing.xs)
                                }
                            }
                        }
                        .padding(.horizontal, JW.Spacing.lg)
                        .padding(.bottom, JW.Spacing.xxxl)
                    }
                }
            }
        }
        .navigationTitle("Your Walks")
        .navigationBarTitleDisplayMode(.large)
        .sheet(isPresented: $showUpgradeSheet) {
            ProUpgradeView(onComplete: { showUpgradeSheet = false })
        }
    }

    // MARK: - Filter Bar

    private var filterBar: some View {
        HStack(spacing: JW.Spacing.sm) {
            ForEach(HistoryFilter.allCases) { filter in
                Button {
                    handleFilterTap(filter)
                } label: {
                    HStack(spacing: 4) {
                        if filter.requiresPro && !isPro {
                            Image(systemName: "lock.fill")
                                .font(.system(size: 10))
                        }
                        Text(filter.rawValue)
                    }
                    .font(JW.Font.caption.weight(selectedFilter == filter ? .semibold : .regular))
                    .foregroundStyle(selectedFilter == filter ? Color.black : JW.Color.textSecondary)
                    .padding(.horizontal, JW.Spacing.md)
                    .padding(.vertical, JW.Spacing.sm)
                    .background(
                        Capsule()
                            .fill(selectedFilter == filter ? JW.Color.accent : Color.white.opacity(0.06))
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: JW.Spacing.md) {
            Spacer()

            Image(systemName: "figure.walk")
                .font(.system(size: 48))
                .foregroundStyle(JW.Color.textTertiary)

            Text("No walks yet")
                .font(JW.Font.headline)
                .foregroundStyle(JW.Color.textPrimary)

            Text("Your walk history will appear here")
                .font(JW.Font.subheadline)
                .foregroundStyle(JW.Color.textSecondary)

            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Actions

    private func handleFilterTap(_ filter: HistoryFilter) {
        if filter.requiresPro && !isPro {
            showUpgradeSheet = true
            return
        }
        selectedFilter = filter
    }

    // MARK: - Grouping Helpers

    private static let dayOfWeekFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "EEEE"
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
}
