//
//  SyncDiagnosticsView.swift
//  Just Walk
//
//  Comprehensive diagnostics for monitoring data consistency across
//  iPhone, Widget, Watch, and HealthKit.
//

import SwiftUI
import HealthKit
import Combine

struct SyncDiagnosticsView: View {
    @StateObject private var stepRepo = StepRepository.shared
    @ObservedObject private var cloudKit = CloudKitSyncHandler.shared

    // Auto-refresh timer
    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    // State
    @State private var widgetSteps: Int = 0
    @State private var widgetDistance: Double = 0
    @State private var widgetGoal: Int = 0
    @State private var widgetForDate: Date?
    @State private var widgetLastUpdate: Date?

    // App Group
    private var appGroupDefaults: UserDefaults? {
        UserDefaults(suiteName: "group.com.onworldtech.JustWalk")
    }

    // Sync status
    private var isWidgetInSync: Bool {
        guard let forDate = widgetForDate,
              Calendar.current.isDateInToday(forDate) else {
            return false
        }
        return widgetSteps == stepRepo.todaySteps
    }

    private var widgetSyncDelta: Int {
        stepRepo.todaySteps - widgetSteps
    }

    var body: some View {
        List {
            // MARK: - Consistency Summary
            consistencySummarySection

            // MARK: - iPhone App
            iPhoneAppSection

            // MARK: - iPhone Widget
            iPhoneWidgetSection

            // MARK: - HealthKit
            healthKitSection

            // MARK: - CloudKit
            cloudKitSection

            // MARK: - Apple Watch
            appleWatchSection

            // MARK: - Actions
            actionsSection
        }
        .navigationTitle("Sync Diagnostics")
        .onAppear {
            refreshWidgetData()
        }
        .onReceive(timer) { _ in
            refreshWidgetData()
        }
    }

    // MARK: - Consistency Summary Section

    private var consistencySummarySection: some View {
        Section {
            VStack(spacing: 12) {
                // Widget sync status
                HStack {
                    if isWidgetInSync {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                            .font(.title2)
                        VStack(alignment: .leading) {
                            Text("Widget In Sync")
                                .font(.headline)
                                .foregroundStyle(.green)
                            Text("App Group matches live data")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    } else {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                            .font(.title2)
                        VStack(alignment: .leading) {
                            Text("Widget Out of Sync")
                                .font(.headline)
                                .foregroundStyle(.orange)
                            if widgetForDate == nil || !Calendar.current.isDateInToday(widgetForDate!) {
                                Text("Widget has stale date")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            } else {
                                Text("Delta: \(widgetSyncDelta) steps")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    Spacer()
                }

                Divider()

                // CloudKit status
                HStack {
                    cloudKitStatusIcon
                    VStack(alignment: .leading) {
                        Text("iCloud: \(cloudKit.syncStatus.rawValue)")
                            .font(.subheadline)
                        if let error = cloudKit.errorMessage {
                            Text(error)
                                .font(.caption)
                                .foregroundStyle(.red)
                        }
                    }
                    Spacer()
                }
            }
            .padding(.vertical, 4)
        } header: {
            Label("Status", systemImage: "checkmark.shield.fill")
        }
    }

    @ViewBuilder
    private var cloudKitStatusIcon: some View {
        switch cloudKit.syncStatus {
        case .synced:
            Image(systemName: "icloud.fill")
                .foregroundStyle(.green)
        case .syncing:
            ProgressView()
                .controlSize(.small)
        case .noAccount:
            Image(systemName: "icloud.slash.fill")
                .foregroundStyle(.orange)
        case .error:
            Image(systemName: "exclamationmark.icloud.fill")
                .foregroundStyle(.red)
        case .idle:
            Image(systemName: "icloud.fill")
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - iPhone App Section

    private var iPhoneAppSection: some View {
        Section {
            LabeledContent("Today's Steps", value: "\(stepRepo.todaySteps)")
                .fontWeight(.semibold)

            LabeledContent("HealthKit Steps", value: "\(stepRepo.healthKitSteps)")
                .foregroundStyle(.secondary)

            LabeledContent("Distance", value: String(format: "%.0f m", stepRepo.todayDistance))

            LabeledContent("Step Goal", value: "\(stepRepo.stepGoal)")

            LabeledContent("Goal Progress", value: String(format: "%.0f%%", stepRepo.goalProgress * 100))

            LabeledContent("Last HK Refresh", value: stepRepo.lastHealthKitRefresh.formatted(date: .omitted, time: .standard))
                .font(.caption)
                .foregroundStyle(.secondary)
        } header: {
            Label("iPhone App", systemImage: "iphone")
        } footer: {
            Text("Live data from StepRepository (HealthKit source of truth)")
        }
    }

    // MARK: - iPhone Widget Section

    private var iPhoneWidgetSection: some View {
        Section {
            LabeledContent("Widget Steps", value: "\(widgetSteps)")
                .fontWeight(.semibold)

            LabeledContent("Widget Distance", value: String(format: "%.0f m", widgetDistance))

            LabeledContent("Widget Goal", value: "\(widgetGoal)")

            if let forDate = widgetForDate {
                LabeledContent("For Date") {
                    VStack(alignment: .trailing) {
                        Text(forDate.formatted(date: .abbreviated, time: .omitted))
                        if Calendar.current.isDateInToday(forDate) {
                            Text("(Today)")
                                .font(.caption2)
                                .foregroundStyle(.green)
                        } else {
                            Text("(Stale!)")
                                .font(.caption2)
                                .foregroundStyle(.red)
                        }
                    }
                }
            } else {
                LabeledContent("For Date", value: "Not set")
                    .foregroundStyle(.red)
            }

            if let lastUpdate = widgetLastUpdate {
                LabeledContent("Last Update", value: lastUpdate.formatted(date: .omitted, time: .standard))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            // Sync indicator
            HStack {
                Text("Sync Status")
                Spacer()
                if isWidgetInSync {
                    Label("In Sync", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                        .font(.caption)
                } else {
                    Label("Out of Sync (\(widgetSyncDelta))", systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                        .font(.caption)
                }
            }
        } header: {
            Label("iPhone Widget", systemImage: "square.grid.2x2")
        } footer: {
            Text("Data from App Group (what widgets see)")
        }
    }

    // MARK: - HealthKit Section

    private var healthKitSection: some View {
        Section {
            HStack {
                Text("Authorization")
                Spacer()
                if HealthKitService.shared.isHealthKitAuthorized {
                    Label("Authorized", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                        .font(.caption)
                } else {
                    Label("Not Authorized", systemImage: "xmark.circle.fill")
                        .foregroundStyle(.red)
                        .font(.caption)
                }
            }

            HStack {
                Text("Data Available")
                Spacer()
                if HKHealthStore.isHealthDataAvailable() {
                    Label("Yes", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                        .font(.caption)
                } else {
                    Label("No", systemImage: "xmark.circle.fill")
                        .foregroundStyle(.red)
                        .font(.caption)
                }
            }
        } header: {
            Label("HealthKit", systemImage: "heart.fill")
        } footer: {
            Text("Uses HKStatisticsQuery with .cumulativeSum for iPhone + Watch deduplication")
        }
    }

    // MARK: - CloudKit Section

    private var cloudKitSection: some View {
        Section {
            LabeledContent("Status", value: cloudKit.syncStatus.rawValue)

            if let lastSync = cloudKit.lastSyncDate {
                LabeledContent("Last Sync", value: lastSync.formatted(date: .abbreviated, time: .shortened))
            } else {
                LabeledContent("Last Sync", value: "Never")
                    .foregroundStyle(.secondary)
            }

            if let error = cloudKit.errorMessage {
                HStack {
                    Text("Error")
                    Spacer()
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.trailing)
                }
            }
        } header: {
            Label("CloudKit", systemImage: "icloud.fill")
        } footer: {
            Text("Syncs StreakData and DailyStats to iCloud")
        }
    }

    // MARK: - Apple Watch Section

    private var appleWatchSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "applewatch")
                        .foregroundStyle(.blue)
                    Text("Independent Architecture")
                        .font(.subheadline)
                        .fontWeight(.medium)
                }

                Text("Watch queries HealthKit independently")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text("Watch Complications use Watch's own App Group")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text("HealthKit iCloud syncs data across devices")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 4)
        } header: {
            Label("Apple Watch", systemImage: "applewatch")
        } footer: {
            Text("No direct iPhone-Watch communication for step data. Both devices trust HealthKit as the source of truth.")
        }
    }

    // MARK: - Actions Section

    private var actionsSection: some View {
        Section {
            Button {
                Task {
                    await stepRepo.forceRefresh()
                    refreshWidgetData()
                }
            } label: {
                Label("Force Refresh", systemImage: "arrow.clockwise")
            }

            Button {
                cloudKit.forceSync()
            } label: {
                Label("Force CloudKit Sync", systemImage: "icloud.and.arrow.up")
            }
        } header: {
            Label("Actions", systemImage: "bolt.fill")
        }
    }

    // MARK: - Helper Methods

    private func refreshWidgetData() {
        guard let defaults = appGroupDefaults else { return }

        widgetSteps = defaults.integer(forKey: "todaySteps")
        widgetDistance = defaults.double(forKey: "todayDistance")
        widgetGoal = defaults.integer(forKey: "dailyStepGoal")
        widgetForDate = defaults.object(forKey: "forDate") as? Date
        widgetLastUpdate = defaults.object(forKey: "lastUpdateDate") as? Date
    }
}

#Preview {
    NavigationStack {
        SyncDiagnosticsView()
    }
}
