//
//  OnboardingContainerView.swift
//  JustWalk
//
//  Container view managing the 9-screen onboarding flow with horizontal slide transitions
//

import SwiftUI
import os.log

private let onboardingLogger = Logger(subsystem: "onworldtech.JustWalk", category: "Onboarding")

struct OnboardingContainerView: View {
    @Binding var isComplete: Bool
    enum OnboardingStep: Int, CaseIterable {
        case welcome           // Screen 1: More Than a Pedometer
        case consistency       // Screen 2: Set a daily goal. Hit it. Repeat.
        case shields           // Screen 3: Life Happens
        case walksPreview      // Screen 4: Ready for More?
        case permissions       // Screen 5: Health permissions
        case notifications     // Screen 6: Notification setup
        case goalSelection     // Screen 7: Your Daily Goal
        case proUpgrade        // Screen 8: Pro Upgrade
        case healthKitSync     // Screen 9: Import HealthKit history (final step)
    }

    @State private var currentStep: OnboardingStep = .welcome

    var body: some View {
        ZStack {
            // Background
            JW.Color.backgroundPrimary
                .ignoresSafeArea()

            // Screens — horizontal slide transitions
            Group {
                switch currentStep {
                case .welcome:
                    MoreThanPedometerView(onContinue: { advanceToNextStep() })
                        .transition(.onboardingSlide)

                case .consistency:
                    OneStepAtATimeView(onContinue: { advanceToNextStep() })
                        .transition(.onboardingSlide)

                case .shields:
                    LifeHappensView(onContinue: { advanceToNextStep() })
                        .transition(.onboardingSlide)

                case .walksPreview:
                    ReadyForMoreView(onContinue: { advanceToNextStep() })
                        .transition(.onboardingSlide)

                case .permissions:
                    PermissionsView(onContinue: { advanceToNextStep() })
                        .transition(.onboardingSlide)

                case .notifications:
                    NotificationSetupView(onContinue: { advanceToNextStep() })
                        .transition(.onboardingSlide)

                case .goalSelection:
                    GoalSettingView(onComplete: { advanceToNextStep() })
                        .transition(.onboardingSlide)

                case .proUpgrade:
                    NavigationStack {
                        ProUpgradeView(onComplete: { advanceToNextStep() }, showsCloseButton: false)
                            .navigationTitle("")
                            .toolbar {
                                ToolbarItem(placement: .navigationBarLeading) {
                                    Button("Skip For Now") {
                                        advanceToNextStep()
                                    }
                                    .foregroundStyle(JW.Color.textSecondary)
                                }
                            }
                    }
                    .transition(.onboardingSlide)

                case .healthKitSync:
                    HealthKitSyncView(onComplete: { completeOnboarding() })
                        .transition(.onboardingSlide)
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    private func advanceToNextStep() {
        guard let currentIndex = OnboardingStep.allCases.firstIndex(of: currentStep),
              currentIndex < OnboardingStep.allCases.count - 1 else {
            completeOnboarding()
            return
        }

        let nextStep = OnboardingStep.allCases[currentIndex + 1]

        let animation: Animation = switch nextStep {
        case .welcome:
            .easeOut(duration: 0.5)
        case .consistency:
            JustWalkAnimation.presentation
        case .shields:
            JustWalkAnimation.presentation
        case .walksPreview:
            JustWalkAnimation.presentation
        case .permissions:
            JustWalkAnimation.standardSpring
        case .notifications:
            JustWalkAnimation.standardSpring
        case .goalSelection:
            JustWalkAnimation.presentation
        case .proUpgrade:
            JustWalkAnimation.presentation
        case .healthKitSync:
            JustWalkAnimation.standardSpring
        }

        let resolvedStep = nextStep

        withAnimation(animation) {
            currentStep = resolvedStep
        }
    }

    private func completeOnboarding() {
        onboardingLogger.info("🎓 completeOnboarding() called")

        var profile = PersistenceManager.shared.loadProfile()
        profile.hasCompletedOnboarding = true
        PersistenceManager.shared.saveProfile(profile)

        // Set fast-sync flag in iCloud Key-Value Store for reinstall detection
        CloudKeyValueStore.setHasCompletedOnboarding()

        // Initialize shields immediately so new users see their 2 free shields right away
        onboardingLogger.info("🛡️ About to call ShieldManager.shared.load()...")
        ShieldManager.shared.load()
        onboardingLogger.info("🛡️ After ShieldManager.load(): availableShields=\(ShieldManager.shared.shieldData.availableShields)")
        StreakManager.shared.load()

        // Trigger immediate step fetch and widget update now that permissions are granted
        Task {
            let goal = profile.dailyStepGoal
            let authorized = await HealthKitManager.shared.isCurrentlyAuthorized()
            if authorized {
                _ = await HealthKitManager.shared.backfillDailyLogsIfNeeded(days: HealthKitManager.historySyncDays, dailyGoal: goal)
            }
            let steps = await HealthKitManager.shared.fetchTodaySteps()
            let streak = StreakManager.shared.streakData.currentStreak
            let shields = ShieldManager.shared.availableShields
            let weekSteps = buildWeekSteps()
            JustWalkWidgetData.updateWidgetData(
                todaySteps: steps,
                stepGoal: goal,
                currentStreak: streak,
                weekSteps: weekSteps,
                shieldCount: shields
            )
        }

        isComplete = true
    }

    private func buildWeekSteps() -> [Int] {
        let calendar = Calendar.current
        let persistence = PersistenceManager.shared
        return (-6...0).map { offset in
            guard let date = calendar.date(byAdding: .day, value: offset, to: Date()) else { return 0 }
            return persistence.loadDailyLog(for: date)?.steps ?? 0
        }
    }
}

#Preview {
    OnboardingContainerView(isComplete: .constant(false))
}
