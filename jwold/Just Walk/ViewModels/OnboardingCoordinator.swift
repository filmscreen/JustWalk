//
//  OnboardingCoordinator.swift
//  Just Walk
//
//  Created by Randy Chia on 1/22/26.
//

import SwiftUI
import Combine
import WatchConnectivity

final class OnboardingCoordinator: ObservableObject {

    enum Screen: Int, CaseIterable {
        case welcome = 0
        case dailyGoal = 1
        case streakCommitment = 2
        case proPaywall = 3
        case watchConnection = 4
        case healthPermission = 5
        case locationPermission = 6
        case notificationPermission = 7
        case complete = 8
    }

    @Published var currentScreen: Screen = .welcome

    // User selections
    @Published var selectedDailyGoal: Int = 4000
    @Published var selectedStreakCommitment: Int? = nil  // 7, 30, or nil

    var onComplete: (() -> Void)?

    var isWatchPaired: Bool {
        guard WCSession.isSupported() else { return false }
        return WCSession.default.isPaired
    }

    var totalScreenCount: Int {
        isWatchPaired ? Screen.allCases.count : Screen.allCases.count - 1
    }

    var currentProgressIndex: Int {
        var index = currentScreen.rawValue
        if !isWatchPaired && currentScreen.rawValue > Screen.watchConnection.rawValue {
            index -= 1
        }
        return index
    }

    func next() {
        guard let nextRaw = Screen(rawValue: currentScreen.rawValue + 1) else {
            return
        }

        var nextScreen = nextRaw

        // Skip watchConnection if no watch paired
        if nextScreen == .watchConnection && !isWatchPaired {
            nextScreen = .healthPermission
        }

        withAnimation(.easeInOut(duration: 0.3)) {
            currentScreen = nextScreen
        }
    }

    func skip() {
        next()
    }

    func complete() {
        // Save selections
        UserDefaults.standard.set(selectedDailyGoal, forKey: "dailyStepGoal")
        if let streak = selectedStreakCommitment {
            UserDefaults.standard.set(streak, forKey: "initialStreakGoal")
        }
        StepRepository.shared.stepGoal = selectedDailyGoal

        UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")
        UserDefaults.standard.set(Date(), forKey: "onboardingCompletedDate")
        onComplete?()
    }
}
