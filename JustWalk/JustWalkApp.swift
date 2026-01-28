//
//  JustWalkApp.swift
//  JustWalk
//
//  Created by Randy Chia on 1/23/26.
//

import SwiftUI
import HealthKit
import WidgetKit

@main
struct JustWalkApp: App {
    @State private var appState: AppState
    @State private var onboardingComplete: Bool
    @Environment(\.scenePhase) private var scenePhase

    init() {
        let state = PersistenceManager.shared.loadAppState()
        _appState = State(initialValue: state)
        _onboardingComplete = State(initialValue: state.profile.hasCompletedOnboarding)
    }

    var body: some Scene {
        WindowGroup {
            Group {
                if onboardingComplete {
                    ContentView()
                        .environment(appState)
                } else {
                    OnboardingContainerView(isComplete: $onboardingComplete)
                }
            }
            .onAppear {
                StreakManager.shared.load()
                ShieldManager.shared.load()
                MilestoneManager.shared.load()
                ShieldManager.shared.checkAndDeployForMissedDays()
                CloudKitSyncManager.shared.setup()
                NotificationManager.shared.registerCategories()
                LocationInsightsService.shared.detectLocationOnce()
                pushWidgetData()
                Task {
                    #if !targetEnvironment(simulator)
                    guard HKHealthStore.isHealthDataAvailable() else {
                        appState.healthKitDenied = true
                        return
                    }
                    #endif
                    // Initialize HealthKit for returning users — starts step observation
                    let authorized = await HealthKitManager.shared.initializeIfAuthorized()
                    appState.healthKitDenied = !authorized
                }
            }
            .onChange(of: scenePhase) { _, newPhase in
                if newPhase == .active {
                    CloudKitSyncManager.shared.pullFromCloud()
                    reloadAppState()
                    WalkSessionManager.shared.cleanupOrphanedState()
                    ShieldManager.shared.checkAndDeployForMissedDays()
                    DynamicCardEngine.shared.checkDailyReset()
                    Task {
                        // Re-initialize HealthKit — handles case where user granted permission in Settings
                        let authorized = await HealthKitManager.shared.initializeIfAuthorized()
                        appState.healthKitDenied = !authorized
                    }
                } else if newPhase == .background {
                    CloudKitSyncManager.shared.pushAllToCloud()
                    WalkSessionManager.shared.saveStateIfNeeded()
                    MilestoneManager.shared.save()
                    scheduleStreakReminderIfNeeded()
                }
            }
            .onChange(of: onboardingComplete) { _, completed in
                if completed {
                    var profile = PersistenceManager.shared.loadProfile()
                    profile.hasCompletedOnboarding = true
                    PersistenceManager.shared.saveProfile(profile)
                    // Re-check HealthKit authorization immediately after onboarding
                    Task {
                        let authorized = await HealthKitManager.shared.initializeIfAuthorized()
                        await MainActor.run {
                            appState.healthKitDenied = !authorized
                        }
                    }
                }
            }
            .preferredColorScheme(.dark)
        }
    }

    private func reloadAppState() {
        let persistence = PersistenceManager.shared
        persistence.invalidateCaches()
        appState.profile = persistence.loadProfile()
        appState.streakData = persistence.loadStreakData()
        appState.shieldData = persistence.loadShieldData()
        appState.todayLog = persistence.loadDailyLog(for: Date())

        // Keep singleton managers in sync with persisted data
        StreakManager.shared.load()
        ShieldManager.shared.load()
    }

    private func pushWidgetData() {
        Task {
            let steps = await HealthKitManager.shared.fetchTodaySteps()
            let persistence = PersistenceManager.shared
            let goal = persistence.loadProfile().dailyStepGoal
            let streak = StreakManager.shared.streakData.currentStreak
            let weekSteps = buildWeekSteps()
            let shields = ShieldManager.shared.availableShields
            JustWalkWidgetData.updateWidgetData(
                todaySteps: steps,
                stepGoal: goal,
                currentStreak: streak,
                weekSteps: weekSteps,
                shieldCount: shields
            )
        }
    }

    private func buildWeekSteps() -> [Int] {
        let calendar = Calendar.current
        let persistence = PersistenceManager.shared
        return (-6...0).map { offset in
            guard let date = calendar.date(byAdding: .day, value: offset, to: Date()) else { return 0 }
            return persistence.loadDailyLog(for: date)?.steps ?? 0
        }
    }

    private func scheduleStreakReminderIfNeeded() {
        let streakManager = StreakManager.shared
        if streakManager.isAtRisk {
            NotificationManager.shared.scheduleStreakAtRiskReminder(streak: streakManager.streakData.currentStreak)
        }
    }
}
