//
//  PowerWalkRecommendation.swift
//  Just Walk
//
//  Goal-based workout recommendation logic.
//  Calculates how many intervals are needed to reach step goals.
//

import Foundation

/// Calculated workout recommendation based on steps remaining to daily goal
struct PowerWalkRecommendation: Equatable {
    let workout: PowerWalkWorkout
    let stepsRemaining: Int
    let estimatedSteps: Int
    let willReachGoal: Bool
    let percentOfGoal: Double
    let estimatedMinutes: Int

    // MARK: - Computed Properties

    /// How many steps over/under the goal this workout would achieve
    var stepsOverUnder: Int {
        estimatedSteps - stepsRemaining
    }

    /// Formatted steps remaining (e.g., "3,500")
    var formattedStepsRemaining: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return formatter.string(from: NSNumber(value: stepsRemaining)) ?? "\(stepsRemaining)"
    }

    /// Formatted estimated steps (e.g., "~3,600")
    var formattedEstimatedSteps: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return "~\(formatter.string(from: NSNumber(value: estimatedSteps)) ?? "\(estimatedSteps)")"
    }

    /// Confidence level in the recommendation
    var confidenceLevel: ConfidenceLevel {
        if willReachGoal && percentOfGoal >= 0.95 {
            return .high
        } else if percentOfGoal >= 0.8 {
            return .medium
        } else {
            return .low
        }
    }

    enum ConfidenceLevel {
        case high
        case medium
        case low

        var description: String {
            switch self {
            case .high: return "You'll likely reach your goal"
            case .medium: return "You'll make good progress"
            case .low: return "Every step counts"
            }
        }
    }

    // MARK: - Factory Methods

    /// Calculate recommended workout based on steps remaining to daily goal
    /// - Parameters:
    ///   - stepsRemaining: Steps needed to reach daily goal
    ///   - preset: The interval preset to use
    /// - Returns: A recommendation with the optimal workout
    static func calculate(
        stepsRemaining: Int,
        preset: PowerWalkPreset = .default
    ) -> PowerWalkRecommendation {
        // Average steps per minute across easy/brisk phases
        // Easy: 90 spm, Brisk: 130 spm
        // With equal time ratio: (90 + 130) / 2 = 110 spm average
        let easyRatio = preset.easyDuration / preset.cycleDuration
        let briskRatio = preset.briskDuration / preset.cycleDuration
        let avgStepsPerMinute = Double(PowerWalkPhase.easy.stepsPerMinute) * easyRatio +
                                Double(PowerWalkPhase.brisk.stepsPerMinute) * briskRatio

        // Calculate minutes needed to reach goal (used for reference)
        _ = Double(stepsRemaining) / avgStepsPerMinute

        // Determine number of brisk intervals needed
        _ = preset.cycleDuration / 60
        let warmupCooldownMinutes = 4.0  // 2 + 2

        // Calculate cycles needed (accounting for warmup/cooldown contribution)
        let warmupCooldownSteps = Int(warmupCooldownMinutes) * PowerWalkPhase.easy.stepsPerMinute
        let stepsFromIntervals = max(0, stepsRemaining - warmupCooldownSteps)
        let stepsPerCycle = Int(preset.easyDuration / 60) * PowerWalkPhase.easy.stepsPerMinute +
                           Int(preset.briskDuration / 60) * PowerWalkPhase.brisk.stepsPerMinute

        let cyclesNeeded: Double
        if stepsPerCycle > 0 {
            cyclesNeeded = Double(stepsFromIntervals) / Double(stepsPerCycle)
        } else {
            cyclesNeeded = 3.0  // Fallback to minimum
        }

        // Clamp to reasonable range: 3-10 intervals
        let targetIntervals = max(3, min(10, Int(ceil(cyclesNeeded))))

        let workout = PowerWalkWorkout(
            preset: preset,
            targetBriskIntervals: targetIntervals
        )

        return PowerWalkRecommendation(
            workout: workout,
            stepsRemaining: stepsRemaining,
            estimatedSteps: workout.estimatedSteps,
            willReachGoal: workout.estimatedSteps >= stepsRemaining,
            percentOfGoal: stepsRemaining > 0
                ? min(1.0, Double(workout.estimatedSteps) / Double(stepsRemaining))
                : 1.0,
            estimatedMinutes: workout.totalMinutes
        )
    }

    /// Calculate workout recommendation for a specific duration
    /// - Parameters:
    ///   - targetMinutes: Desired workout duration in minutes
    ///   - preset: The interval preset to use
    /// - Returns: A workout that fits within the target duration
    static func forDuration(
        targetMinutes: Int,
        preset: PowerWalkPreset = .default
    ) -> PowerWalkWorkout {
        let warmupCooldownMinutes = 4  // 2 + 2
        let availableMinutes = max(0, targetMinutes - warmupCooldownMinutes)
        let cycleMinutes = Int(preset.cycleDuration / 60)

        let targetIntervals: Int
        if cycleMinutes > 0 {
            targetIntervals = max(1, availableMinutes / cycleMinutes)
        } else {
            targetIntervals = 3
        }

        return PowerWalkWorkout(
            preset: preset,
            targetBriskIntervals: min(15, targetIntervals)
        )
    }

    /// Calculate multiple recommendations for comparison
    /// - Parameters:
    ///   - stepsRemaining: Steps needed to reach daily goal
    ///   - preset: The interval preset to use
    /// - Returns: Array of recommendations with different interval counts
    static func calculateOptions(
        stepsRemaining: Int,
        preset: PowerWalkPreset = .default
    ) -> [PowerWalkRecommendation] {
        let optimalRecommendation = calculate(stepsRemaining: stepsRemaining, preset: preset)
        let optimalIntervals = optimalRecommendation.workout.targetBriskIntervals

        var options: [PowerWalkRecommendation] = []

        // Add a shorter option (if possible)
        if optimalIntervals > 3 {
            let shorterWorkout = PowerWalkWorkout(
                preset: preset,
                targetBriskIntervals: max(3, optimalIntervals - 2)
            )
            options.append(PowerWalkRecommendation(
                workout: shorterWorkout,
                stepsRemaining: stepsRemaining,
                estimatedSteps: shorterWorkout.estimatedSteps,
                willReachGoal: shorterWorkout.estimatedSteps >= stepsRemaining,
                percentOfGoal: stepsRemaining > 0
                    ? min(1.0, Double(shorterWorkout.estimatedSteps) / Double(stepsRemaining))
                    : 1.0,
                estimatedMinutes: shorterWorkout.totalMinutes
            ))
        }

        // Add the optimal option
        options.append(optimalRecommendation)

        // Add a longer option (if reasonable)
        if optimalIntervals < 10 {
            let longerWorkout = PowerWalkWorkout(
                preset: preset,
                targetBriskIntervals: min(10, optimalIntervals + 2)
            )
            options.append(PowerWalkRecommendation(
                workout: longerWorkout,
                stepsRemaining: stepsRemaining,
                estimatedSteps: longerWorkout.estimatedSteps,
                willReachGoal: longerWorkout.estimatedSteps >= stepsRemaining,
                percentOfGoal: stepsRemaining > 0
                    ? min(1.0, Double(longerWorkout.estimatedSteps) / Double(stepsRemaining))
                    : 1.0,
                estimatedMinutes: longerWorkout.totalMinutes
            ))
        }

        return options.sorted { $0.workout.targetBriskIntervals < $1.workout.targetBriskIntervals }
    }
}

// MARK: - Time Saved Calculation

extension PowerWalkRecommendation {
    /// Calculate estimated time saved compared to a regular walk
    /// - Parameters:
    ///   - steps: Number of steps walked
    ///   - duration: Actual duration in seconds
    /// - Returns: Minutes saved (or negative if took longer)
    static func calculateTimeSaved(steps: Int, duration: TimeInterval) -> Int {
        // Regular walk: ~100 steps/min (casual pace)
        // Power Walk: ~110 steps/min (average of easy/brisk)
        let regularWalkMinutes = Double(steps) / 100.0
        let actualMinutes = duration / 60.0
        return max(0, Int(regularWalkMinutes - actualMinutes))
    }

    /// Estimate how long a regular walk would take for the same steps
    /// - Parameter steps: Number of steps to walk
    /// - Returns: Estimated duration in seconds
    static func estimateRegularWalkDuration(forSteps steps: Int) -> TimeInterval {
        // Regular walk averages 100 steps/min
        return (Double(steps) / 100.0) * 60.0
    }

    /// Estimate how long a Power Walk would take for the same steps
    /// - Parameter steps: Number of steps to walk
    /// - Returns: Estimated duration in seconds
    static func estimatePowerWalkDuration(forSteps steps: Int) -> TimeInterval {
        // Power Walk averages ~110 steps/min
        return (Double(steps) / 110.0) * 60.0
    }
}
