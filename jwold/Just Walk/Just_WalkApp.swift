//
//  Just_WalkApp.swift
//  Just Walk
//
//  Created by Randy Chia on 1/8/26.
//

import SwiftUI
import SwiftData
import BackgroundTasks
import WidgetKit
import UserNotifications
import CoreHaptics
import StoreKit

/// Handles notification presentation and triggers intense haptics for phase transitions
class NotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationDelegate()
    private var hapticEngine: CHHapticEngine?

    override init() {
        super.init()
        prepareHaptics()
    }

    private func prepareHaptics() {
        guard CHHapticEngine.capabilitiesForHardware().supportsHaptics else { return }
        do {
            hapticEngine = try CHHapticEngine()
            try hapticEngine?.start()
        } catch {
            print("Notification haptic engine failed: \(error)")
        }
    }

    /// Called when notification is received while app is in foreground
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        // Check if this is an IWT phase notification
        if notification.request.identifier.contains("iwt.phase") {
            // Play INTENSE haptic pattern
            playIntensePhaseChangeHaptic()
        }

        // Show banner, play sound, and update badge
        completionHandler([.banner, .sound, .badge])
    }

    /// Called when user taps on a notification
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                didReceive response: UNNotificationResponse,
                                withCompletionHandler completionHandler: @escaping () -> Void) {
        let identifier = response.notification.request.identifier

        // Handle weekly snapshot notification tap
        if identifier == "weekly.snapshot" {
            Task { @MainActor in
                await WeeklySnapshotManager.shared.showSnapshotFromNotification()
            }
            completionHandler()
            return
        }

        // Handle IWT notification actions
        if identifier.contains("iwt.phase") {
            switch response.actionIdentifier {
            case "PAUSE_SESSION":
                Task { @MainActor in
                    IWTService.shared.pauseSession()
                }
            case "OPEN_APP", UNNotificationDefaultActionIdentifier:
                // App will open naturally, trigger haptic for awareness
                playIntensePhaseChangeHaptic()
            default:
                break
            }
        }

        completionHandler()
    }

    /// Play an EXTREMELY intense haptic pattern for phase changes
    /// This is much stronger than the regular phase change haptic
    private func playIntensePhaseChangeHaptic() {
        guard CHHapticEngine.capabilitiesForHardware().supportsHaptics,
              let engine = hapticEngine else {
            // Fallback to UIImpactFeedbackGenerator for simpler devices
            playFallbackHaptic()
            return
        }

        // Ensure engine is started
        try? engine.start()

        var events: [CHHapticEvent] = []

        // ===== INTENSE MULTI-BURST PATTERN =====
        // Pattern: 3 strong bursts + sustained rumble + 3 more bursts + final explosion

        // INITIAL TRIPLE BURST (attention grabbing)
        for i in 0..<3 {
            events.append(CHHapticEvent(
                eventType: .hapticTransient,
                parameters: [
                    CHHapticEventParameter(parameterID: .hapticIntensity, value: 1.0),
                    CHHapticEventParameter(parameterID: .hapticSharpness, value: 1.0)
                ],
                relativeTime: Double(i) * 0.08
            ))
        }

        // SUSTAINED RUMBLE (awareness)
        events.append(CHHapticEvent(
            eventType: .hapticContinuous,
            parameters: [
                CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.9),
                CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.5)
            ],
            relativeTime: 0.3,
            duration: 0.25
        ))

        // SECONDARY TRIPLE BURST (reinforcement)
        for i in 0..<3 {
            events.append(CHHapticEvent(
                eventType: .hapticTransient,
                parameters: [
                    CHHapticEventParameter(parameterID: .hapticIntensity, value: 1.0),
                    CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.8)
                ],
                relativeTime: 0.6 + Double(i) * 0.1
            ))
        }

        // DEEP RUMBLE (building tension)
        events.append(CHHapticEvent(
            eventType: .hapticContinuous,
            parameters: [
                CHHapticEventParameter(parameterID: .hapticIntensity, value: 1.0),
                CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.2)
            ],
            relativeTime: 0.95,
            duration: 0.3
        ))

        // FINAL EXPLOSION (4 rapid sharp bursts)
        for i in 0..<4 {
            events.append(CHHapticEvent(
                eventType: .hapticTransient,
                parameters: [
                    CHHapticEventParameter(parameterID: .hapticIntensity, value: 1.0),
                    CHHapticEventParameter(parameterID: .hapticSharpness, value: 1.0)
                ],
                relativeTime: 1.3 + Double(i) * 0.06
            ))
        }

        do {
            let pattern = try CHHapticPattern(events: events, parameters: [])
            let player = try engine.makePlayer(with: pattern)
            try player.start(atTime: 0)
        } catch {
            print("Failed to play intense haptic: \(error)")
            playFallbackHaptic()
        }
    }

    /// Fallback haptic using UIKit generators (simpler but still effective)
    private func playFallbackHaptic() {
        // Play multiple impact feedbacks in sequence
        let heavyGenerator = UIImpactFeedbackGenerator(style: .heavy)
        let rigidGenerator = UIImpactFeedbackGenerator(style: .rigid)
        let notificationGenerator = UINotificationFeedbackGenerator()

        heavyGenerator.prepare()
        rigidGenerator.prepare()
        notificationGenerator.prepare()

        // Rapid sequence of strong impacts
        Task { @MainActor in
            for _ in 0..<3 {
                heavyGenerator.impactOccurred(intensity: 1.0)
                try? await Task.sleep(nanoseconds: 80_000_000) // 80ms
            }

            try? await Task.sleep(nanoseconds: 100_000_000) // 100ms pause

            notificationGenerator.notificationOccurred(.warning)

            try? await Task.sleep(nanoseconds: 150_000_000) // 150ms pause

            for _ in 0..<3 {
                rigidGenerator.impactOccurred(intensity: 1.0)
                try? await Task.sleep(nanoseconds: 60_000_000) // 60ms
            }

            notificationGenerator.notificationOccurred(.success)
        }
    }
}

@main
struct Just_WalkApp: App {
    @Environment(\.scenePhase) private var scenePhase

    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            WalkingSession.self,
            DailyStats.self,
            UserSettings.self,
            StreakData.self
        ])

        // CloudKit-enabled configuration for automatic iCloud sync
        // Container ID must match the one created in Xcode's iCloud capability
        // Syncs StreakData (shields, streaks) and DailyStats (step history) to iCloud
        let modelConfiguration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false,
            cloudKitDatabase: .private("iCloud.onworldtech.Just-Walk")
        )

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    // Set to false for production so new users see onboarding
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @AppStorage("appTheme") private var appTheme: AppTheme = .system

    // StoreKit 2: Streak Repair transaction listener task
    @State private var streakRepairListenerTask: Task<Void, Never>?

    init() {
        // Register Background Task (Must be done in init/didFinishLaunching)
        BackgroundTaskManager.shared.registerBackgroundTask()

        // Set up notification delegate for intense haptic feedback on phase transitions
        UNUserNotificationCenter.current().delegate = NotificationDelegate.shared

        // Register notification categories for IWT actions
        IWTService.registerNotificationCategories()

    }

    var body: some Scene {
        WindowGroup {
            Group {
                if hasCompletedOnboarding {
                    // iOS 26 Liquid Glass Navigation (with legacy fallback)
                    AdaptiveNavigationContainer()
                } else {
                    // Coordinator-based onboarding flow (9 screens)
                    OnboardingContainerView {
                        Task {
                            // THE HOOK: Hydrate historical data immediately after onboarding
                            await StepRepository.shared.hydrateHistoricalData()
                            await configureServices(permissionsGranted: true)
                        }
                    }
                }
            }
            .task {
                // Only configure non-permission services initially
                // Permission-requiring services wait until onboarding completes
                await configureServices(permissionsGranted: hasCompletedOnboarding)
            }
            .onAppear {
                // Inject model context into persistence service, streak service, resurrection manager, and step repository
                Task { @MainActor in
                    let context = sharedModelContainer.mainContext
                    SessionPersistenceService.shared.setModelContext(context)
                    StreakService.shared.setModelContext(context)
                    StreakResurrectionManager.shared.setModelContext(context)
                    StepRepository.shared.setModelContext(context)  // For high-water mark ratchet
                }
                // Start StoreKit 2 listener for Streak Repair purchases
                streakRepairListenerTask = listenForStreakRepairTransactions()
            }
            .preferredColorScheme(appTheme.colorScheme)
            // Handle goal reached during background delivery (fixes Pillar 4 vulnerability)
            .onReceive(NotificationCenter.default.publisher(for: .dailyStepGoalReached)) { _ in
                guard hasCompletedOnboarding else { return }
                let stepRepo = StepRepository.shared
                StreakService.shared.checkDailyGoalFromSteps(
                    currentSteps: stepRepo.todaySteps,
                    stepGoal: stepRepo.stepGoal,
                    context: sharedModelContainer.mainContext
                )
                // Smart Coach: Send "High Five" notification for goal reached
                NotificationIntelligenceManager.shared.triggerGoalReachedNotification()
            }
        }
        .modelContainer(sharedModelContainer)
        .environmentObject(StoreManager.shared)
        .onChange(of: scenePhase) {
            if scenePhase == .background {
                if hasCompletedOnboarding {
                    // Force widget refresh on app close - user expects to see latest steps
                    StepRepository.shared.handleAppBackground()
                    BackgroundTaskManager.shared.scheduleAppRefresh()
                    // Smart Coach: Evaluate and schedule appropriate evening notifications
                    NotificationIntelligenceManager.shared.scheduleSmartEveningUpdate()
                }
            } else if scenePhase == .active {
                 // Force a data refresh from HealthKit & CoreMotion when app comes to foreground
                 // But ONLY if onboarding is complete to avoid premature permission prompts
                 if hasCompletedOnboarding {
                     // Re-check HealthKit authorization state (user may have enabled in Settings)
                     // This triggers reactive UI updates via @Published authorizationState
                     HealthKitService.shared.checkAuthorizationState()

                     // Re-check notification authorization (user may have enabled in iOS Settings)
                     Task {
                         await NotificationPermissionManager.shared.checkAuthorizationStatus()
                     }

                     // Validate streak on app open (checks if streak should be reset)
                     StreakService.shared.validateStreakOnAppOpen(context: sharedModelContainer.mainContext)

                     // Streak Resurrection: Reconcile historical data (throttled to 6 hours)
                     Task {
                         await StreakResurrectionManager.shared.triggerReconciliation()
                     }

                     // Check if we need to reset for a new day
                     // If true, it triggers an async reset + reload, so we skip manual reload
                     if !StepTrackingService.shared.checkForNewDay() {
                         // Offload HealthKit fetch to prevent blocking Main Thread during app resume
                         Task {
                            // NEW: Use StepRepository as the primary refresh mechanism
                            await StepRepository.shared.handleAppForeground()

                            // Legacy: StepTrackingService still handles session tracking
                            StepTrackingService.shared.refreshHealthKitData()
                            StepTrackingService.shared.loadTodaySteps()

                            // Widget update now handled by StepRepository automatically
                            // But force an extra update for immediate feedback
                            try? await Task.sleep(nanoseconds: 500_000_000) // Wait 0.5s for data to settle
                            StepRepository.shared.forceWidgetRefresh()

                            // Check if regular walking reached today's goal (streak update)
                            // Use StepRepository values for consistency
                            let stepRepo = StepRepository.shared
                            StreakService.shared.checkDailyGoalFromSteps(
                                currentSteps: stepRepo.todaySteps,
                                stepGoal: stepRepo.stepGoal,
                                context: sharedModelContainer.mainContext
                            )

                            // Update challenge progress when app becomes active
                            ChallengeManager.shared.updateDailyProgress()

                            // Schedule streak-at-risk notification if applicable
                            let streakService = StreakService.shared
                            if streakService.currentStreak > 0 && stepRepo.todaySteps < stepRepo.stepGoal {
                                NotificationManager.shared.scheduleStreakAtRiskNotification(
                                    currentStreak: streakService.currentStreak,
                                    stepsRemaining: stepRepo.stepGoal - stepRepo.todaySteps,
                                    stepGoal: stepRepo.stepGoal
                                )
                            }
                         }
                     }

                     // Clear app badge if no IWT session is active
                     // This cleans up any stale badges from phase notifications
                     if !IWTService.shared.isSessionActive {
                         Task {
                             await NotificationManager.shared.clearAppBadge()
                         }
                     }
                 }
            }
        }
    }


    // MARK: - Streak Repair Transaction Listener

    /// Listen for Streak Repair purchases and atomically repair the streak.
    /// Only finishes the transaction AFTER confirmed repair (crash-proof).
    private func listenForStreakRepairTransactions() -> Task<Void, Never> {
        Task.detached { @MainActor [sharedModelContainer] in
            for await result in Transaction.updates {
                guard let transaction = try? result.payloadValue else { continue }

                // Only handle streak repair purchases
                guard transaction.productID == StoreManager.streakRepairProductId else {
                    // Let StoreManager handle other products
                    continue
                }

                print("🛡️ StreakRepair: Processing transaction \(transaction.id)")

                // ATOMIC REPAIR: Only finish if repair succeeds
                let context = sharedModelContainer.mainContext

                if let repairedDate = StreakService.shared.attemptStreakRepair(context: context) {
                    // SUCCESS: Repair confirmed - NOW we can finish the transaction
                    await transaction.finish()
                    print("🛡️ StreakRepair: Transaction \(transaction.id) finished - repaired \(repairedDate.formatted(date: .abbreviated, time: .omitted))")
                } else {
                    // FAILURE: Do NOT finish - transaction will retry on next launch
                    print("⚠️ StreakRepair: Repair failed - transaction NOT finished (will retry)")
                }
            }
        }
    }

    // MARK: - App Initialization

    @MainActor
    private func configureServices(permissionsGranted: Bool) async {
        // Allow a brief moment for the UI to mount and launch screen to dismiss
        try? await Task.sleep(nanoseconds: 100_000_000) // 0.1s

        // 1. RevenueCat / Subscription Manager - No permissions needed
        // Configure RevenueCat SDK - UUID sync happens in AuthViewModel when session is detected
        // TODO: Set skipRevenueCatForTesting to false when you have a real appl_ API key
        let skipRevenueCatForTesting = true
        if skipRevenueCatForTesting {
            print("⚠️ Skipping RevenueCat configuration (test mode)")
        }
        // NOTE: When ready for production, set skipRevenueCatForTesting = false and uncomment:
        // SubscriptionManager.shared.configure()

        // ONLY initialize permission-requiring services if user has completed onboarding
        guard permissionsGranted else {
            print("⏳ Services: Waiting for onboarding completion before requesting permissions")
            return
        }

        // 2. HealthKit & Step Tracking (Heavy - involves permission checks & background delivery)
        // NEW: Initialize StepRepository as the Single Source of Truth
        await StepRepository.shared.initialize()

        // Legacy: StepTrackingService still needed for session tracking (IWT)
        _ = StepTrackingService.shared

        // 3. Initialize ChallengeManager (depends on StepRepository)
        ChallengeManager.shared.refreshAvailableChallenges()
        ChallengeManager.shared.updateDailyProgress()

        // 4. Schedule recurring notifications
        NotificationManager.shared.scheduleWeeklySnapshotNotification()

        // 5. Streak Resurrection: Reconcile local DailyStats with HealthKit (12-month range)
        // This runs silently, throttled to 6 hours, and ensures streak integrity
        StreakResurrectionManager.shared.setModelContext(sharedModelContainer.mainContext)
        await StreakResurrectionManager.shared.triggerReconciliation()

        // 6. Legacy backfill (60 days) - kept for compatibility, may overlap with resurrection
        if StreakService.shared.needsBackfill() {
            await StreakService.shared.backfillFromHealthKit()
        }

        // 7. Check for gifted shields from support (Supabase)
        await GiftedShieldsService.shared.checkAndClaimGifts()

        print("✅ Services Configured (StepRepository + StreakResurrection initialized)")
    }
}

enum AppTheme: String, CaseIterable, Identifiable {
    case system = "System"
    case light = "Light"
    case dark = "Dark"
    
    var id: String { rawValue }
    
    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
}
