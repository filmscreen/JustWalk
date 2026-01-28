//
//  OnboardingValidationTests.swift
//  JustWalkTests
//
//  Validates onboarding flow order, recommendation logic, and screen contracts
//

import Testing
import Foundation
@testable import JustWalk

// MARK: - Onboarding Step Order Tests

@Suite("Onboarding Flow Order")
struct OnboardingStepOrderTests {

    typealias Step = OnboardingContainerView.OnboardingStep

    @Test("Enum has exactly 9 steps")
    func stepCount() {
        #expect(Step.allCases.count == 9)
    }

    @Test("Steps are in correct order")
    func stepOrder() {
        let expected: [Step] = [
            .welcome,
            .consistency,
            .shields,
            .walksPreview,
            .permissions,
            .notifications,
            .goalSelection,
            .proUpgrade,
            .ready
        ]
        #expect(Step.allCases == expected)
    }

    @Test("Permissions comes before Goal Selection")
    func permissionsBeforeGoal() {
        #expect(Step.permissions.rawValue < Step.goalSelection.rawValue)
    }

    @Test("Welcome comes before Permissions")
    func welcomeBeforePermissions() {
        #expect(Step.welcome.rawValue < Step.permissions.rawValue)
    }

    @Test("Raw values are sequential from 0")
    func rawValuesSequential() {
        for (index, step) in Step.allCases.enumerated() {
            #expect(step.rawValue == index, "Step \(step) should have rawValue \(index), got \(step.rawValue)")
        }
    }
}

// MARK: - Goal Recommendation Logic Tests

@Suite("Goal Recommendation Logic")
struct GoalRecommendationTests {

    // Mirrors the formula from GoalSettingView.recommendedGoal
    private func calculateRecommendedGoal(average: Int?) -> Int {
        guard let average = average else { return 7000 }
        let percentageTarget = Double(average) * 1.25
        let minimumTarget = Double(average + 2000)
        let target = max(percentageTarget, minimumTarget)
        let rounded = (Int(target) + 250) / 500 * 500
        return min(max(rounded, 5000), 10000)
    }

    // Mirrors the formula from GoalSettingView.easyGoal
    private func calculateEasyGoal(average: Int?) -> Int {
        guard let average = average else { return 5000 }
        let target = average + 1000
        let rounded = (target + 250) / 500 * 500
        return min(max(rounded, 5000), 10000)
    }

    // Mirrors the formula from GoalSettingView.extraMinutes
    private func calculateExtraMinutes(average: Int, recommended: Int) -> Int {
        let extraSteps = recommended - average
        return max(extraSteps / 100, 15)
    }

    // MARK: - Recommended Goal

    @Test("Recommended goal for low average (3,000)")
    func recommended_lowAverage() {
        // max(3000*1.25=3750, 5000) = 5000 → capped/floored at 5000
        #expect(calculateRecommendedGoal(average: 3000) == 5000)
    }

    @Test("Recommended goal for medium-low average (4,000)")
    func recommended_mediumLowAverage() {
        // max(4000*1.25=5000, 6000) = 6000
        #expect(calculateRecommendedGoal(average: 4000) == 6000)
    }

    @Test("Recommended goal for medium average (4,500)")
    func recommended_mediumAverage() {
        // max(4500*1.25=5625, 6500) = 6500
        #expect(calculateRecommendedGoal(average: 4500) == 6500)
    }

    @Test("Recommended goal for average of 5,000")
    func recommended_5kAverage() {
        // max(5000*1.25=6250, 7000) = 7000
        #expect(calculateRecommendedGoal(average: 5000) == 7000)
    }

    @Test("Recommended goal for high average (6,000)")
    func recommended_highAverage() {
        // max(6000*1.25=7500, 8000) = 8000
        #expect(calculateRecommendedGoal(average: 6000) == 8000)
    }

    @Test("Recommended goal for 7,000 average")
    func recommended_7kAverage() {
        // max(7000*1.25=8750, 9000) = 9000
        #expect(calculateRecommendedGoal(average: 7000) == 9000)
    }

    @Test("Recommended goal for very high average (8,000)")
    func recommended_veryHighAverage() {
        // max(8000*1.25=10000, 10000) = 10000
        #expect(calculateRecommendedGoal(average: 8000) == 10000)
    }

    @Test("Recommended goal capped at 10,000 for 12,000 average")
    func recommended_cappedAt10k() {
        // max(12000*1.25=15000, 14000) = 15000 → capped to 10000
        #expect(calculateRecommendedGoal(average: 12000) == 10000)
    }

    @Test("Recommended goal floored at 5,000 for 2,000 average")
    func recommended_flooredAt5k() {
        // max(2000*1.25=2500, 4000) = 4000 → floored to 5000
        #expect(calculateRecommendedGoal(average: 2000) == 5000)
    }

    @Test("Recommended goal defaults to 7,000 when no data")
    func recommended_noData() {
        #expect(calculateRecommendedGoal(average: nil) == 7000)
    }

    // MARK: - Easy Goal

    @Test("Easy goal for low average (3,000)")
    func easy_lowAverage() {
        // 3000+1000=4000 → floored to 5000
        #expect(calculateEasyGoal(average: 3000) == 5000)
    }

    @Test("Easy goal for medium average (4,500)")
    func easy_mediumAverage() {
        // 4500+1000=5500
        #expect(calculateEasyGoal(average: 4500) == 5500)
    }

    @Test("Easy goal for high average (8,000)")
    func easy_highAverage() {
        // 8000+1000=9000
        #expect(calculateEasyGoal(average: 8000) == 9000)
    }

    @Test("Easy goal capped at 10,000 for very high average")
    func easy_cappedAt10k() {
        // 10000+1000=11000 → capped at 10000
        #expect(calculateEasyGoal(average: 10000) == 10000)
    }

    @Test("Easy goal defaults to 5,000 when no data")
    func easy_noData() {
        #expect(calculateEasyGoal(average: nil) == 5000)
    }

    // MARK: - Sequential Order (Easy ≤ Recommended ≤ Ambitious)

    @Test("Goals are sequential for low average (3,000)",
          arguments: [3000])
    func goalsSequential_low(average: Int) {
        let easy = calculateEasyGoal(average: average)
        let recommended = calculateRecommendedGoal(average: average)
        let ambitious = 10000
        #expect(easy <= recommended, "Easy (\(easy)) should be ≤ Recommended (\(recommended))")
        #expect(recommended <= ambitious, "Recommended (\(recommended)) should be ≤ Ambitious (\(ambitious))")
    }

    @Test("Goals are sequential across representative averages",
          arguments: [2000, 3000, 4000, 4500, 5000, 6000, 7000, 8000, 9000, 9500, 10000, 12000, 15000])
    func goalsSequential(average: Int) {
        let easy = calculateEasyGoal(average: average)
        let recommended = calculateRecommendedGoal(average: average)
        let ambitious = 10000
        #expect(easy <= recommended, "avg=\(average): Easy (\(easy)) should be ≤ Recommended (\(recommended))")
        #expect(recommended <= ambitious, "avg=\(average): Recommended (\(recommended)) should be ≤ Ambitious (\(ambitious))")
    }

    @Test("Goals are sequential for generic state (no data)")
    func goalsSequential_noData() {
        let easy = calculateEasyGoal(average: nil)        // 5000
        let recommended = calculateRecommendedGoal(average: nil)  // 7000
        let ambitious = 10000
        #expect(easy < recommended)
        #expect(recommended < ambitious)
    }

    // MARK: - Extra Minutes

    @Test("Extra minutes for medium stretch (4,500 avg, 6,500 recommended)")
    func extraMinutes_mediumStretch() {
        // 6500-4500=2000 extra, 2000/100=20 min
        #expect(calculateExtraMinutes(average: 4500, recommended: 6500) == 20)
    }

    @Test("Extra minutes floors to 15 for small differences")
    func extraMinutes_minimumFloor() {
        // 5000-4500=500, 500/100=5 → floored to 15
        #expect(calculateExtraMinutes(average: 4500, recommended: 5000) == 15)
    }

    @Test("Extra minutes for large stretch (3,000 avg, 5,000 recommended)")
    func extraMinutes_largeStretch() {
        // 5000-3000=2000, 2000/100=20
        #expect(calculateExtraMinutes(average: 3000, recommended: 5000) == 20)
    }

    // MARK: - Full Verification Table (from spec)

    @Test("Verification table matches spec",
          arguments: [
            (3000, 5000, 5000),
            (4000, 5000, 6000),
            (4500, 5500, 6500),
            (5000, 6000, 7000),
            (6000, 7000, 8000),
            (7000, 8000, 9000),
            (8000, 9000, 10000),
          ] as [(Int, Int, Int)])
    func verificationTable(average: Int, expectedEasy: Int, expectedRecommended: Int) {
        #expect(calculateEasyGoal(average: average) == expectedEasy,
                "avg=\(average): Easy should be \(expectedEasy)")
        #expect(calculateRecommendedGoal(average: average) == expectedRecommended,
                "avg=\(average): Recommended should be \(expectedRecommended)")
    }
}

// MARK: - Goal Setting UI State Tests
// GoalOption type was removed during onboarding redesign; these tests
// are intentionally omitted until a replacement API is introduced.
