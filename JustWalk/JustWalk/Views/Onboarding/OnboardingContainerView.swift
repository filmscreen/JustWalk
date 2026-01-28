//
//  OnboardingContainerView.swift
//  JustWalk
//
//  Container view managing the 9-screen onboarding flow with horizontal slide transitions
//

import SwiftUI

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
        case ready             // Screen 9: You're ready
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
                    ProUpgradeView(onComplete: { advanceToNextStep() })
                        .transition(.onboardingSlide)

                case .ready:
                    YoureReadyView(onComplete: { completeOnboarding() })
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
        case .ready:
            JustWalkAnimation.emphasis
        }

        withAnimation(animation) {
            currentStep = nextStep
        }
    }

    private func completeOnboarding() {
        var profile = PersistenceManager.shared.loadProfile()
        profile.hasCompletedOnboarding = true
        PersistenceManager.shared.saveProfile(profile)

        // Trigger immediate step fetch and widget update now that permissions are granted
        Task {
            let steps = await HealthKitManager.shared.fetchTodaySteps()
            let goal = profile.dailyStepGoal
            let streak = StreakManager.shared.streakData.currentStreak
            let shields = ShieldManager.shared.availableShields
            JustWalkWidgetData.updateWidgetData(
                todaySteps: steps,
                stepGoal: goal,
                currentStreak: streak,
                weekSteps: [],
                shieldCount: shields
            )
        }

        isComplete = true
    }
}

#Preview {
    OnboardingContainerView(isComplete: .constant(false))
}
