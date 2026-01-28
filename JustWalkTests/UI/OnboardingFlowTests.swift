//
//  OnboardingFlowTests.swift
//  JustWalkTests
//
//  Tests for onboarding state logic and profile persistence
//

import Testing
import Foundation
@testable import JustWalk

extension SharedStateTests {
@Suite(.serialized)
struct OnboardingFlowTests {

    private let persistence = PersistenceManager.shared

    init() {
        persistence.clearAllData()
    }

    // MARK: - Fresh Install Shows Onboarding

    @Test func freshInstall_profileHasNotCompletedOnboarding() {
        persistence.clearAllData()
        let profile = persistence.loadProfile()
        #expect(profile.hasCompletedOnboarding == false)

        persistence.clearAllData()
    }

    // MARK: - Goal Selection Persists

    @Test func goalSelection_persistsToUserProfile() {
        var profile = UserProfile.default
        profile.dailyStepGoal = 7500
        persistence.saveProfile(profile)

        let loaded = persistence.loadProfile()
        #expect(loaded.dailyStepGoal == 7500)

        persistence.clearAllData()
    }

    // MARK: - Completing Onboarding Sets Flag

    @Test func completingOnboarding_setsHasCompletedOnboarding() {
        var profile = UserProfile.default
        #expect(profile.hasCompletedOnboarding == false)

        profile.hasCompletedOnboarding = true
        persistence.saveProfile(profile)

        let loaded = persistence.loadProfile()
        #expect(loaded.hasCompletedOnboarding == true)

        persistence.clearAllData()
    }

    // MARK: - All Step Goal Options Valid

    @Test func stepGoalOptions_allValidValues() {
        let validGoals = [3000, 5000, 7500, 10000]
        for goal in validGoals {
            var profile = UserProfile.default
            profile.dailyStepGoal = goal
            persistence.saveProfile(profile)

            let loaded = persistence.loadProfile()
            #expect(loaded.dailyStepGoal == goal)
        }

        persistence.clearAllData()
    }
}
} // extension SharedStateTests
