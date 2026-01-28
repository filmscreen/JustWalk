//
//  WalkLandingViewModel.swift
//  Just Walk
//
//  View model for Walk Landing screen.
//  Calculates time estimates based on steps remaining to goal.
//

import Foundation
import Combine

// MARK: - Progress State

enum WalkProgressState {
    case notStarted      // 0 steps
    case inProgress      // 1-99%
    case goalAchieved    // 100-149%
    case wayOver         // 150%+
}

@MainActor
final class WalkLandingViewModel: ObservableObject {

    // MARK: - Published State

    @Published private(set) var stepsRemaining: Int = 0
    @Published private(set) var todaySteps: Int = 0
    @Published private(set) var stepGoal: Int = 10_000
    @Published private(set) var progressPercent: Int = 0
    @Published private(set) var justWalkMinutes: Int = 0
    @Published private(set) var powerWalkMinutes: Int = 0
    @Published private(set) var savedMinutes: Int = 0
    @Published private(set) var goalReached: Bool = false
    @Published private(set) var isAlmostThere: Bool = false

    // MARK: - Constants

    /// Steps per minute for Just Walk (casual pace, ~2.5 mph)
    private let justWalkStepsPerMinute: Double = 100.0

    /// Steps per minute for Power Walk (interval average, ~3.2 mph)
    private let powerWalkStepsPerMinute: Double = 120.0

    /// Minimum time estimate to show (avoid showing "1 min to goal")
    private let minimumMinutes: Int = 5

    /// Steps threshold for "almost there" state
    private let almostThereThreshold: Int = 1_000

    // MARK: - Dependencies

    private let stepRepo = StepRepository.shared

    // MARK: - Initialization

    init() {
        refresh()  // Get initial values from StepRepository
    }

    // MARK: - Refresh

    func refresh() {
        todaySteps = stepRepo.todaySteps
        stepGoal = stepRepo.stepGoal
        stepsRemaining = stepRepo.stepsRemaining
        goalReached = stepRepo.goalReached
        progressPercent = Int(stepRepo.goalProgress * 100)
        isAlmostThere = stepsRemaining > 0 && stepsRemaining <= almostThereThreshold

        if goalReached {
            // Goal reached - no time estimates needed
            justWalkMinutes = 0
            powerWalkMinutes = 0
            savedMinutes = 0
        } else {
            // Calculate time estimates
            let rawJustWalkMinutes = Int(ceil(Double(stepsRemaining) / justWalkStepsPerMinute))
            let rawPowerWalkMinutes = Int(ceil(Double(stepsRemaining) / powerWalkStepsPerMinute))

            // Apply minimum threshold
            justWalkMinutes = max(minimumMinutes, rawJustWalkMinutes)
            powerWalkMinutes = max(minimumMinutes, rawPowerWalkMinutes)

            // Calculate savings (only show if meaningful)
            let rawSavedMinutes = justWalkMinutes - powerWalkMinutes
            savedMinutes = rawSavedMinutes >= 2 ? rawSavedMinutes : 0
        }
    }

    // MARK: - Computed Properties

    /// Header text - changes based on progress state
    var headerText: String {
        switch progressState {
        case .notStarted, .inProgress:
            return "\(formattedStepsRemaining) steps to go"
        case .goalAchieved:
            return "Congrats on hitting your goal!"
        case .wayOver:
            return "\(formattedBonusSteps) bonus steps!"
        }
    }

    /// Subtitle text - contextual encouragement based on progress state
    var subtitleText: String {
        switch progressState {
        case .notStarted:
            return "Let's get started"
        case .inProgress:
            return progressPercent < 50 ? "You're making progress!" : "Almost there!"
        case .goalAchieved:
            return "Keep going for bonus steps"
        case .wayOver:
            return "You're on fire today"
        }
    }

    /// Combined header with contextual suffix for single-line display
    var combinedHeaderText: String {
        if goalReached {
            return "Goal hit! · Keep the momentum going"
        }
        let contextSuffix: String
        if stepsRemaining < 4000 {
            contextSuffix = "Almost there!"
        } else if stepsRemaining < 8000 {
            contextSuffix = "You're on your way"
        } else {
            contextSuffix = "Let's get started"
        }
        return "\(formattedStepsRemaining) steps to go · \(contextSuffix)"
    }

    /// Formatted steps remaining with commas
    var formattedStepsRemaining: String {
        formatNumber(stepsRemaining)
    }

    /// Formatted today steps with commas
    var formattedTodaySteps: String {
        formatNumber(todaySteps)
    }

    /// Current progress state based on steps vs goal
    var progressState: WalkProgressState {
        if todaySteps == 0 { return .notStarted }
        if progressPercent < 100 { return .inProgress }
        if progressPercent < 150 { return .goalAchieved }
        return .wayOver
    }

    /// Bonus steps (steps over goal)
    var bonusSteps: Int {
        max(0, todaySteps - stepGoal)
    }

    /// Formatted bonus steps with commas
    var formattedBonusSteps: String {
        formatNumber(bonusSteps)
    }

    /// Time estimate text for Just Walk card (nil when goal reached to hide)
    var justWalkTimeText: String? {
        if goalReached {
            return nil  // Hide time estimate when goal is hit
        }
        return "~\(formatTimeEstimate(justWalkMinutes)) to goal"
    }

    /// Time estimate text for Power Walk card (nil when goal reached to hide)
    var powerWalkTimeText: String? {
        if goalReached {
            return nil  // Hide time estimate when goal is hit
        }
        return "~\(formatTimeEstimate(powerWalkMinutes)) to goal"
    }

    /// Goal status text shown when goal is already hit
    var goalHitText: String {
        "You've hit today's goal!"
    }

    /// Just Walk card subtext when goal reached
    var justWalkGoalReachedText: String {
        "Ready when you are"
    }

    /// Power Walk card subtext when goal reached
    var powerWalkGoalReachedText: String {
        "Earn bonus steps faster"
    }

    /// Savings text for Power Walk card (nil if not meaningful)
    var powerWalkSavingsText: String? {
        guard !goalReached && savedMinutes >= 2 else { return nil }
        return "Save \(formatTimeEstimate(savedMinutes))"
    }

    // MARK: - Helpers

    private func formatNumber(_ number: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return formatter.string(from: NSNumber(value: number)) ?? "\(number)"
    }

    /// Format time estimate - converts to hours when >= 60 min
    private func formatTimeEstimate(_ minutes: Int) -> String {
        if minutes >= 60 {
            let hours = minutes / 60
            let mins = minutes % 60
            if mins == 0 {
                return "\(hours) hr"
            }
            return "\(hours) hr \(mins) min"
        }
        return "\(minutes) min"
    }
}
