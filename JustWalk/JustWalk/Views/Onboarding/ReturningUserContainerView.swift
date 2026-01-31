//
//  ReturningUserContainerView.swift
//  JustWalk
//
//  Container managing the returning user re-onboarding flow with horizontal slide transitions.
//  This replaces the simple WelcomeBackView with a multi-step flow matching the onboarding design.
//

import SwiftUI
import os.log

private let returningLogger = Logger(subsystem: "onworldtech.JustWalk", category: "ReturningUser")

struct ReturningUserContainerView: View {
    @Environment(AppState.self) private var appState
    let onComplete: () -> Void

    enum ReturningUserStep: Int, CaseIterable {
        case welcome        // Welcome back + data restored summary
        case health         // HealthKit + Motion permissions
        case notifications  // Notification re-authorization
        case goalConfirm    // Confirm or update step goal
        case proUpgrade     // Pro upgrade prompt (skip if already Pro)
    }

    @State private var currentStep: ReturningUserStep = .welcome

    private var isPro: Bool {
        SubscriptionManager.shared.isPro
    }

    var body: some View {
        ZStack {
            // Background
            JW.Color.backgroundPrimary
                .ignoresSafeArea()

            // Screens - horizontal slide transitions
            Group {
                switch currentStep {
                case .welcome:
                    ReturningWelcomeView(onContinue: { advanceToNextStep() })
                        .transition(.onboardingSlide)

                case .health:
                    ReturningHealthView(onContinue: { advanceToNextStep() })
                        .transition(.onboardingSlide)

                case .notifications:
                    ReturningNotificationsView(onContinue: { advanceToNextStep() })
                        .transition(.onboardingSlide)

                case .goalConfirm:
                    ReturningGoalConfirmView(onContinue: { advanceToNextStep() })
                        .transition(.onboardingSlide)

                case .proUpgrade:
                    NavigationStack {
                        ProUpgradeView(onComplete: { completeReturningFlow() }, showsCloseButton: false)
                            .navigationTitle("")
                            .toolbar {
                                ToolbarItem(placement: .navigationBarLeading) {
                                    Button("Skip For Now") {
                                        completeReturningFlow()
                                    }
                                    .foregroundStyle(JW.Color.textSecondary)
                                }
                            }
                    }
                    .transition(.onboardingSlide)
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    private func advanceToNextStep() {
        guard let currentIndex = ReturningUserStep.allCases.firstIndex(of: currentStep),
              currentIndex < ReturningUserStep.allCases.count - 1 else {
            completeReturningFlow()
            return
        }

        let nextStep = ReturningUserStep.allCases[currentIndex + 1]

        // Skip proUpgrade if user is already Pro
        if nextStep == .proUpgrade && isPro {
            returningLogger.info("User is already Pro, skipping proUpgrade step")
            completeReturningFlow()
            return
        }

        let animation: Animation = switch nextStep {
        case .welcome:
            .easeOut(duration: 0.5)
        case .health:
            JustWalkAnimation.standardSpring
        case .notifications:
            JustWalkAnimation.standardSpring
        case .goalConfirm:
            JustWalkAnimation.presentation
        case .proUpgrade:
            JustWalkAnimation.presentation
        }

        withAnimation(animation) {
            currentStep = nextStep
        }
    }

    private func completeReturningFlow() {
        returningLogger.info("Completing returning user flow")

        // Sync HealthKit history with restored goal
        Task {
            let goal = PersistenceManager.shared.loadProfile().dailyStepGoal
            _ = await HealthKitManager.shared.syncHealthKitHistory(
                days: HealthKitManager.historySyncDays,
                dailyGoal: goal
            )
        }

        onComplete()
    }
}

#Preview {
    ReturningUserContainerView(onComplete: {})
        .environment(AppState())
}
