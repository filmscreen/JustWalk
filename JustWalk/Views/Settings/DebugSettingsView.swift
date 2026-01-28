//
//  DebugSettingsView.swift
//  JustWalk
//
//  Debug settings for simulation, test personas, and testing
//

import SwiftUI

struct DebugSettingsView: View {
    private var healthKitManager: HealthKitManager { HealthKitManager.shared }
    private var subscriptionManager: SubscriptionManager { SubscriptionManager.shared }

    @AppStorage("debug_overridePro") private var overridePro = false
    @AppStorage("debug_simulateWalk") private var simulateWalk = false

    #if DEBUG
    private var testDataProvider: TestDataProvider { TestDataProvider.shared }
    private var streakManager: StreakManager { StreakManager.shared }
    private var shieldManager: ShieldManager { ShieldManager.shared }
    private var cloudKitSync: CloudKitSyncManager { CloudKitSyncManager.shared }

    @State private var selectedPersona: TestPersona = TestDataProvider.shared.activePersona
    #endif

    var body: some View {
        List {
            #if DEBUG
            // MARK: - Test Personas
            Section {
                ForEach(TestPersona.allCases) { persona in
                    Button {
                        selectedPersona = persona
                        testDataProvider.applyPersona(persona)
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: persona.icon)
                                .font(.title3)
                                .foregroundStyle(selectedPersona == persona ? .blue : .secondary)
                                .frame(width: 28)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(persona.displayName)
                                    .font(.body)
                                    .foregroundStyle(.primary)
                                Text(persona.description)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()

                            if selectedPersona == persona {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(.blue)
                                    .fontWeight(.semibold)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }

                if testDataProvider.isTestDataActive {
                    Button("Reset to Real Data", role: .destructive) {
                        selectedPersona = .realData
                        testDataProvider.revertToRealData()
                    }
                }
            } header: {
                Text("Test Personas")
            } footer: {
                if testDataProvider.isTestDataActive {
                    Label("Test data is active — app state is synthetic", systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                        .font(.caption)
                }
            }

            // MARK: - Current State
            Section("Current State") {
                LabeledContent("Steps", value: "\(healthKitManager.todaySteps)")
                LabeledContent("Streak", value: "\(streakManager.streakData.currentStreak) days")
                LabeledContent("Longest Streak", value: "\(streakManager.streakData.longestStreak) days")
                LabeledContent("Shields", value: "\(shieldManager.shieldData.availableShields)/\(ShieldData.maxBanked(isPro: subscriptionManager.isPro))")
                LabeledContent("Pro", value: subscriptionManager.isPro ? "Yes" : "No")
            }

            // MARK: - CloudKit Sync
            Section("CloudKit Sync") {
                LabeledContent("Status", value: cloudKitSync.syncStatus.displayText)

                if let lastSync = cloudKitSync.lastSyncDate {
                    LabeledContent("Last Sync", value: lastSync.formatted(.dateTime.month().day().hour().minute()))
                }

                Button("Force Sync Now") {
                    cloudKitSync.forceSync()
                }

                Button("Push to Cloud") {
                    cloudKitSync.pushAllToCloud()
                }

                Button("Pull from Cloud") {
                    cloudKitSync.pullFromCloud()
                }

                Button("Delete Cloud Data", role: .destructive) {
                    cloudKitSync.deleteCloudData()
                }
            }
            #endif

            // MARK: - Watch Connectivity
            #if DEBUG
            Section("Watch Connectivity") {
                NavigationLink("Connectivity Test") {
                    WatchConnectivityTestView()
                }
            }
            #endif

            // MARK: - Pro Override (works in production/TestFlight)
            Section {
                Toggle(isOn: Binding(
                    get: { subscriptionManager.isTesterModeEnabled },
                    set: { newValue in
                        if newValue {
                            subscriptionManager.enableTesterMode()
                        } else {
                            subscriptionManager.disableTesterMode()
                        }
                    }
                )) {
                    HStack(spacing: 12) {
                        Image(systemName: "crown.fill")
                            .foregroundStyle(.yellow)
                        Text("Tester Mode")
                    }
                }
                .tint(.green)
            } header: {
                Text("Pro Override")
            } footer: {
                Text("Works in TestFlight and production. Unlocks all Pro features for testing.")
            }

            // MARK: - Simulation
            Section("Simulation") {
                Toggle("Simulate Walk Mode", isOn: $simulateWalk)
                    .onChange(of: simulateWalk) { _, newValue in
                        healthKitManager.simulateWalkEnabled = newValue
                    }

                #if DEBUG
                Toggle("Override Pro Status (Debug)", isOn: $overridePro)
                    .onChange(of: overridePro) { _, newValue in
                        subscriptionManager.isPro = newValue
                    }
                #endif
            }

            // MARK: - Data
            Section("Data") {
                Button("Reset Onboarding", role: .destructive) {
                    var profile = PersistenceManager.shared.loadProfile()
                    profile.hasCompletedOnboarding = false
                    PersistenceManager.shared.saveProfile(profile)
                }

                Button("Reset All Data", role: .destructive) {
                    // Clear UserDefaults
                    if let bundleID = Bundle.main.bundleIdentifier {
                        UserDefaults.standard.removePersistentDomain(forName: bundleID)
                    }
                }
            }

            // MARK: - Test Actions
            #if DEBUG
            Section("Test Actions") {
                Button("Trigger Shield Deploy") {
                    _ = ShieldManager.shared.autoDeployIfAvailable(forDate: Date())
                }

                Button("Break Streak (30+ days)") {
                    // Simulate breaking a long streak
                    var streakData = StreakManager.shared.streakData
                    streakData.currentStreak = 45
                    StreakManager.shared.streakData = streakData
                    _ = StreakManager.shared.breakStreak()
                }

                Button("Reset All Shield Usage", role: .destructive) {
                    let persistence = PersistenceManager.shared
                    let allLogs = persistence.loadAllDailyLogs()
                    for log in allLogs where log.shieldUsed {
                        var modified = log
                        modified.shieldUsed = false
                        persistence.saveDailyLog(modified)
                    }
                    // Reset shield counters
                    var shieldData = shieldManager.shieldData
                    shieldData.shieldsUsedThisMonth = 0
                    persistence.saveShieldData(shieldData)
                    shieldManager.shieldData = shieldData
                }
            }
            #endif
        }
        .navigationTitle("Debug")
    }
}
