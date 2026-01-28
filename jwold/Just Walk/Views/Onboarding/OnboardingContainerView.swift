//
//  OnboardingContainerView.swift
//  Just Walk
//
//  Created by Randy Chia on 1/22/26.
//

import SwiftUI

struct OnboardingContainerView: View {
    @StateObject private var coordinator = OnboardingCoordinator()
    let onComplete: () -> Void

    var body: some View {
        ZStack {
            // Existing blue gradient
            LinearGradient(
                colors: [.blue, .cyan],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                // Progress dots (hidden on welcome/complete)
                if shouldShowProgress {
                    OnboardingProgressView(
                        currentIndex: coordinator.currentProgressIndex,
                        totalCount: coordinator.totalScreenCount
                    )
                    .padding(.top, 20)
                }

                // Screen content
                screenContent
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing),
                        removal: .move(edge: .leading)
                    ))
                    .id(coordinator.currentScreen)  // Forces view identity change for animation
            }
            .animation(.easeInOut(duration: 0.3), value: coordinator.currentScreen)
        }
        .onAppear { coordinator.onComplete = onComplete }
        .environmentObject(coordinator)
    }

    private var shouldShowProgress: Bool {
        coordinator.currentScreen != .welcome && coordinator.currentScreen != .complete
    }

    @ViewBuilder
    private var screenContent: some View {
        switch coordinator.currentScreen {
        case .welcome: WelcomeOnboardingView()
        case .dailyGoal: DailyGoalOnboardingView()
        case .streakCommitment: StreakCommitmentOnboardingView()
        case .proPaywall: ProPaywallOnboardingView()
        case .watchConnection: WatchConnectionOnboardingView()
        case .healthPermission: HealthPermissionOnboardingView()
        case .locationPermission: LocationPermissionOnboardingView()
        case .notificationPermission: NotificationPermissionOnboardingView()
        case .complete: OnboardingCompleteView()
        }
    }
}

#Preview {
    OnboardingContainerView {
        print("Onboarding completed")
    }
}
