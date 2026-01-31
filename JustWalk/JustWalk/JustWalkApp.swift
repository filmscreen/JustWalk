//
//  JustWalkApp.swift
//  JustWalk
//
//  Created by Randy Chia on 1/23/26.
//

import SwiftUI
import HealthKit
import WidgetKit
import os.log

private let appLogger = Logger(subsystem: "onworldtech.JustWalk", category: "AppLaunch")

/// App launch state for handling reinstall scenarios
enum AppLaunchState {
    case loading           // Checking for iCloud Key-Value Store
    case askIfReturning    // KVS inconclusive, ask user if they've used app before
    case waitingForSync    // User confirmed returning, waiting for CloudKit
    case newUser           // No prior data, show full onboarding
    case returningUser     // CloudKit data found, may need HealthKit re-auth
    case syncFailed        // CloudKit sync failed, offer retry or proceed as new
    case ready             // Fully initialized, show main app
}

@main
struct JustWalkApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var appState: AppState
    @State private var launchState: AppLaunchState = .loading
    @State private var onboardingComplete: Bool
    @State private var syncRetryCount: Int = 0
    @Environment(\.scenePhase) private var scenePhase

    init() {
        let state = PersistenceManager.shared.loadAppState()
        _appState = State(initialValue: state)
        _onboardingComplete = State(initialValue: state.profile.hasCompletedOnboarding)
    }

    var body: some Scene {
        WindowGroup {
            Group {
                switch launchState {
                case .loading:
                    LaunchLoadingView()
                        .onAppear {
                            checkLaunchState()
                        }
                case .askIfReturning:
                    ReturningUserPromptView(
                        onYesReturning: {
                            launchState = .waitingForSync
                            startCloudKitSync()
                        },
                        onNoNewUser: {
                            launchState = .newUser
                        }
                    )
                case .waitingForSync:
                    LaunchLoadingView()
                case .newUser:
                    OnboardingContainerView(isComplete: $onboardingComplete)
                        .onChange(of: onboardingComplete) { _, completed in
                            if completed {
                                // Initialize app managers before transitioning to ready
                                initializeApp()
                                launchState = .ready
                            }
                        }
                case .returningUser:
                    ReturningUserContainerView(onComplete: {
                        launchState = .ready
                    })
                    .environment(appState)
                case .syncFailed:
                    CloudKitSyncFailedView(
                        retryCount: syncRetryCount,
                        onRetry: {
                            syncRetryCount += 1
                            launchState = .waitingForSync
                            startCloudKitSync()
                        },
                        onProceedAsNew: {
                            launchState = .newUser
                        }
                    )
                case .ready:
                    ContentView()
                        .environment(appState)
                }
            }
            .onAppear {
                // Main initialization happens in checkLaunchState() based on user type
                // This onAppear only handles HealthKit for already-ready users
                if launchState == .ready {
                    Task {
                        #if !targetEnvironment(simulator)
                        guard HKHealthStore.isHealthDataAvailable() else {
                            appState.healthKitDenied = true
                            return
                        }
                        #endif
                        let authorized = await HealthKitManager.shared.initializeIfAuthorized()
                        if authorized {
                            let profile = PersistenceManager.shared.loadProfile()
                            if profile.hasCompletedOnboarding {
                                _ = await HealthKitManager.shared.backfillDailyLogsIfNeeded(days: HealthKitManager.historySyncDays, dailyGoal: profile.dailyStepGoal)
                                await MainActor.run {
                                    reloadAppState()
                                }
                            }
                        }
                        appState.healthKitDenied = !authorized
                    }
                }
            }
            .onChange(of: scenePhase) { _, newPhase in
                // Only handle scene phase changes when app is fully ready
                guard launchState == .ready else { return }

                if newPhase == .active {
                    CloudKitSyncManager.shared.pullFromCloud()
                    reloadAppState()
                    WalkSessionManager.shared.cleanupOrphanedState()
                    Task { await ShieldManager.shared.checkAndDeployForMissedDays() }
                    StepDataManager.shared.fetchToday()
                    DynamicCardEngine.shared.checkDailyReset()
                    PatternManager.shared.refreshIfNeeded()
                    WalkNotificationManager.shared.scheduleNotificationIfNeeded()
                    Task {
                        // Re-initialize HealthKit — handles case where user granted permission in Settings
                        let authorized = await HealthKitManager.shared.initializeIfAuthorized()
                        if authorized {
                            // Only backfill if onboarding is complete — during onboarding,
                            // HealthKitSyncView handles the initial sync with the user's chosen goal
                            let profile = PersistenceManager.shared.loadProfile()
                            if profile.hasCompletedOnboarding {
                                _ = await HealthKitManager.shared.backfillDailyLogsIfNeeded(days: HealthKitManager.historySyncDays, dailyGoal: profile.dailyStepGoal)
                                await MainActor.run {
                                    reloadAppState()
                                }
                            }
                        }
                        appState.healthKitDenied = !authorized
                    }
                } else if newPhase == .background {
                    CloudKitSyncManager.shared.pushAllToCloud()
                    WalkSessionManager.shared.saveStateIfNeeded()
                    MilestoneManager.shared.save()
                    scheduleStreakReminderIfNeeded()

                    // Schedule background tasks for widget refresh while app is backgrounded
                    BackgroundTaskManager.shared.scheduleAllBackgroundTasks()
                }
            }
            .preferredColorScheme(.dark)
        }
    }

    // MARK: - Launch State Check

    /// Determines if this is a new user or returning user (reinstall with CloudKit data).
    /// Uses fast iCloud Key-Value Store check first to avoid delays for new users.
    private func checkLaunchState() {
        appLogger.info("🚀 checkLaunchState() called")
        let persistence = PersistenceManager.shared
        let localProfile = persistence.loadProfile()

        appLogger.info("   Local profile hasCompletedOnboarding: \(localProfile.hasCompletedOnboarding)")

        // If local data shows onboarding complete, user is ready
        if localProfile.hasCompletedOnboarding {
            appLogger.info("   ✅ Local onboarding complete - going to ready state")
            initializeApp()
            launchState = .ready
            return
        }

        // Check iCloud Key-Value Store first (fast, ~0.5s)
        // This tells us if user has EVER completed onboarding on any device
        let kvsResult = CloudKeyValueStore.hasEverCompletedOnboarding()
        appLogger.info("   KVS hasEverCompletedOnboarding: \(String(describing: kvsResult))")

        if let hasCompletedBefore = kvsResult {
            if hasCompletedBefore {
                // User has used app before - wait for CloudKit to restore data
                appLogger.info("   📥 KVS says returning user - starting CloudKit sync")
                launchState = .waitingForSync
                startCloudKitSync()
            } else {
                // KVS explicitly says false - user completed onboarding as new user
                // (the flag is only set to true, never false, so this means they're new)
                appLogger.info("   🆕 KVS says new user (false) - going to onboarding")
                launchState = .newUser
            }
        } else {
            // KVS returned nil - couldn't determine. This happens when:
            // 1. Brand new user (key never set)
            // 2. Existing user who used app before KVS code was added
            // 3. iCloud not signed in or KVS not synced yet
            // Do a quick CloudKit check (2-3s) to see if data exists
            appLogger.info("   ❓ KVS returned nil - doing quick CloudKit check")
            quickCloudKitCheck()
        }
    }

    /// Quick CloudKit check when KVS is inconclusive.
    /// Shows loading screen for 2-3 seconds max, then routes appropriately.
    private func quickCloudKitCheck() {
        appLogger.info("🔍 quickCloudKitCheck() starting...")
        Task {
            let hasData = await CloudKitSyncManager.shared.quickCheckForExistingData()
            appLogger.info("🔍 quickCloudKitCheck() result: \(hasData)")

            await MainActor.run {
                if hasData {
                    // Found CloudKit data - this is a returning user
                    appLogger.info("   📥 Found CloudKit data - starting sync")
                    launchState = .waitingForSync
                    startCloudKitSync()
                } else {
                    // No data found - proceed as new user
                    appLogger.info("   🆕 No CloudKit data found - going to onboarding")
                    launchState = .newUser
                }
            }
        }
    }

    /// Starts CloudKit sync for returning users (called after KVS confirms prior use)
    private func startCloudKitSync() {
        Task {
            let cloudKit = CloudKitSyncManager.shared
            let persistence = PersistenceManager.shared

            appLogger.info("📥 startCloudKitSync: Setting up CloudKit and pulling data...")

            // Setup CloudKit - WAIT for zone creation to complete
            let setupSuccess = await cloudKit.setup()

            guard setupSuccess else {
                appLogger.error("❌ startCloudKitSync: CloudKit setup failed!")
                await MainActor.run {
                    launchState = .syncFailed
                }
                return
            }

            appLogger.info("✅ startCloudKitSync: CloudKit setup succeeded, pulling data...")

            // Now pull data from cloud
            cloudKit.pullFromCloud()

            // Wait for sync with polling (max 5 seconds, check every 0.5s)
            let maxWaitNanos: UInt64 = 5_000_000_000
            let pollInterval: UInt64 = 500_000_000
            var waited: UInt64 = 0

            while waited < maxWaitNanos {
                try? await Task.sleep(nanoseconds: pollInterval)
                waited += pollInterval

                // Check if sync completed (success or error)
                if cloudKit.syncStatus != .syncing && cloudKit.syncStatus != .idle {
                    break
                }

                // Also check if profile was restored during sync
                let checkProfile = persistence.loadProfile()
                if checkProfile.hasCompletedOnboarding {
                    break
                }
            }

            await MainActor.run {
                // Re-check profile after potential CloudKit sync
                let updatedProfile = persistence.loadProfile()

                if updatedProfile.hasCompletedOnboarding {
                    // CloudKit restored user data - this is a returning user
                    appLogger.info("✅ startCloudKitSync: Data restored successfully!")
                    reloadAppState()
                    initializeApp()

                    // Check if HealthKit needs re-authorization
                    Task {
                        let authorized = await HealthKitManager.shared.initializeIfAuthorized()
                        await MainActor.run {
                            if authorized {
                                // HealthKit still authorized, go straight to app
                                launchState = .ready
                            } else {
                                // HealthKit needs re-auth, show welcome back flow
                                launchState = .returningUser
                            }
                        }
                    }
                } else {
                    // No data restored - check if it was a sync error, timeout, or truly no data
                    appLogger.warning("⚠️ startCloudKitSync: No data restored, sync status: \(String(describing: cloudKit.syncStatus))")
                    switch cloudKit.syncStatus {
                    case .error, .syncing, .idle:
                        // Sync failed or timed out - offer retry option
                        launchState = .syncFailed
                    case .success:
                        // Sync succeeded but no prior data found
                        // This is unexpected (KVS said they used app before)
                        // Could be CloudKit data was deleted - show sync failed to let them retry
                        launchState = .syncFailed
                    }
                }
            }
        }
    }

    /// Called after onboarding completes (new users)
    private func finalizeOnboarding() {
        var profile = PersistenceManager.shared.loadProfile()
        profile.hasCompletedOnboarding = true
        PersistenceManager.shared.saveProfile(profile)

        // Set fast-sync flag in iCloud Key-Value Store for reinstall detection
        CloudKeyValueStore.setHasCompletedOnboarding()

        Task {
            let authorized = await HealthKitManager.shared.initializeIfAuthorized()
            if authorized {
                let goal = PersistenceManager.shared.loadProfile().dailyStepGoal
                _ = await HealthKitManager.shared.syncHealthKitHistory(days: HealthKitManager.historySyncDays, dailyGoal: goal)
            }
            await MainActor.run {
                appState.healthKitDenied = !authorized
                reloadAppState()
            }
        }
    }

    /// Initialize app managers and services
    private func initializeApp() {
        appLogger.info("⚙️ initializeApp() called")

        PersistenceManager.shared.migrateDailyLogGoalTargetsIfNeeded()
        PersistenceManager.shared.repairCorruptedGoalTargets()
        PatternManager.shared.refreshIfNeeded()
        WalkNotificationManager.shared.scheduleNotificationIfNeeded()
        StreakManager.shared.load()
        ShieldManager.shared.load()
        MilestoneManager.shared.load()
        Task { await ShieldManager.shared.checkAndDeployForMissedDays() }
        StepDataManager.shared.fetchToday()
        NotificationManager.shared.registerCategories()
        LocationInsightsService.shared.detectLocationOnce()
        PhoneConnectivityManager.shared.syncStreakInfoToWatch()
        pushWidgetData()

        // Setup CloudKit sync - creates zone (WAITS for completion), then pushes data
        // CRITICAL: Must be called for ALL users (new and returning) so data syncs to cloud
        appLogger.info("📡 Starting async CloudKit setup and initial push...")
        Task {
            // Wait for setup (zone creation) to complete
            let setupSuccess = await CloudKitSyncManager.shared.setup()

            if setupSuccess {
                appLogger.info("📤 CloudKit setup succeeded, pushing initial data...")
                // Zone is confirmed to exist, now safe to push
                CloudKitSyncManager.shared.pushAllToCloud()
            } else {
                appLogger.error("❌ CloudKit setup failed - data will not sync!")
            }
        }

        // Sync appState with loaded manager data so UI updates immediately
        appState.shieldData = ShieldManager.shared.shieldData
        appState.streakData = StreakManager.shared.streakData
        appState.profile = PersistenceManager.shared.loadProfile()
        appState.todayLog = PersistenceManager.shared.loadDailyLog(for: Date())

        // Listen for CloudKit sync completion
        NotificationCenter.default.addObserver(
            forName: .didCompleteCloudSync,
            object: nil,
            queue: .main
        ) { _ in
            reloadAppState()
            pushWidgetData()
        }

        // Listen for data deletion to reset app
        NotificationCenter.default.addObserver(
            forName: .didDeleteAllData,
            object: nil,
            queue: .main
        ) { _ in
            // Reset app state and return to onboarding
            reloadAppState()
            launchState = .newUser
            onboardingComplete = false
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

        // Update appState with manager values (they may have been modified during load)
        appState.streakData = StreakManager.shared.streakData
        appState.shieldData = ShieldManager.shared.shieldData
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
