//
//  PowerWalkWorkout.swift
//  Just Walk
//
//  Complete Power Walk workout definition.
//  Simplified: No warmup/cooldown, uses IntervalStyle for timing.
//

import Foundation

/// Complete Power Walk workout definition
struct PowerWalkWorkout: Codable, Equatable, Sendable {
    let preset: PowerWalkPreset
    let targetBriskIntervals: Int       // Number of brisk phases (also equals easy phases)

    // MARK: - Computed Properties

    /// Total number of cycles (each cycle = 1 easy + 1 brisk)
    var totalCycles: Int { targetBriskIntervals }

    /// Total number of phases (easy + brisk pairs)
    var totalPhases: Int {
        targetBriskIntervals * 2  // easy + brisk for each interval
    }

    /// Total workout duration in seconds
    var totalDuration: TimeInterval {
        TimeInterval(targetBriskIntervals) * preset.cycleDuration
    }

    /// Total duration in minutes (rounded)
    var totalMinutes: Int {
        Int(totalDuration / 60)
    }

    /// Human-readable duration (e.g., "30 min")
    var formattedDuration: String {
        "\(totalMinutes) min"
    }

    /// Formatted duration with hours if needed (e.g., "1h 15m")
    var formattedDurationLong: String {
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60

        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes) min"
        }
    }

    /// Estimated steps based on average pace for each phase
    var estimatedSteps: Int {
        let easySteps = Int(preset.easyDuration / 60) * PowerWalkPhase.easy.stepsPerMinute * targetBriskIntervals
        let briskSteps = Int(preset.briskDuration / 60) * PowerWalkPhase.brisk.stepsPerMinute * targetBriskIntervals
        return easySteps + briskSteps
    }

    /// Formatted estimated steps (e.g., "~2,500")
    var formattedEstimatedSteps: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return "~\(formatter.string(from: NSNumber(value: estimatedSteps)) ?? "\(estimatedSteps)")"
    }

    /// Estimated distance in meters
    var estimatedDistanceMeters: Double {
        // Average stride length: ~0.75m for easy, ~0.85m for brisk
        let easyDistance = Double(Int(preset.easyDuration / 60) * PowerWalkPhase.easy.stepsPerMinute * targetBriskIntervals) * 0.75
        let briskDistance = Double(Int(preset.briskDuration / 60) * PowerWalkPhase.brisk.stepsPerMinute * targetBriskIntervals) * 0.85
        return easyDistance + briskDistance
    }

    /// Estimated distance in miles
    var estimatedDistanceMiles: Double {
        estimatedDistanceMeters * 0.000621371
    }

    /// Formatted estimated distance (e.g., "~1.5 mi")
    var formattedEstimatedDistance: String {
        String(format: "~%.1f mi", estimatedDistanceMiles)
    }

    /// Description of the workout structure
    var structureDescription: String {
        "\(targetBriskIntervals)× (\(preset.easyMinutes) min easy + \(preset.briskMinutes) min brisk)"
    }
}

// MARK: - Convenience Initializers

extension PowerWalkWorkout {
    /// Quick workout: 3 cycles = 18 min with standard (3:00/3:00)
    static func quick(preset: PowerWalkPreset = .default) -> PowerWalkWorkout {
        PowerWalkWorkout(
            preset: preset,
            targetBriskIntervals: 3
        )
    }

    /// Standard workout: 5 cycles = 30 min with standard (3:00/3:00)
    static func standard(preset: PowerWalkPreset = .default) -> PowerWalkWorkout {
        PowerWalkWorkout(
            preset: preset,
            targetBriskIntervals: 5
        )
    }

    /// Extended workout: 7 cycles = 42 min with standard (3:00/3:00)
    /// Note: With final easy phase as natural wind-down, approaches 45 min feel
    static func extended(preset: PowerWalkPreset = .default) -> PowerWalkWorkout {
        PowerWalkWorkout(
            preset: preset,
            targetBriskIntervals: 7
        )
    }

    /// Create a workout with a specific number of intervals
    static func custom(
        preset: PowerWalkPreset = .default,
        intervals: Int
    ) -> PowerWalkWorkout {
        PowerWalkWorkout(
            preset: preset,
            targetBriskIntervals: max(1, min(15, intervals))
        )
    }

    /// Create a workout from an IntervalStyle and cycle count
    static func from(style: IntervalStyle, cycles: Int) -> PowerWalkWorkout {
        // Convert IntervalStyle to PowerWalkPreset
        let preset = PowerWalkPreset(
            id: "style_\(style.rawValue)",
            name: style.displayName,
            description: style.detailedDescription,
            easyDuration: style.easyDuration,
            briskDuration: style.briskDuration,
            icon: style.icon
        )
        return PowerWalkWorkout(preset: preset, targetBriskIntervals: cycles)
    }
}

// MARK: - Duration Options

/// Pre-calculated duration options for quick selection UI
struct PowerWalkDurationOption: Identifiable, Equatable {
    let id: String
    let displayName: String        // "Quick", "Standard", "Extended"
    let durationLabel: String      // "18 min", "30 min", "42 min"
    let subtitle: String           // "3 cycles · ~2,000 steps"
    let briskIntervals: Int
    let estimatedSteps: Int
    let workout: PowerWalkWorkout

    static func options(for preset: PowerWalkPreset) -> [PowerWalkDurationOption] {
        let quick = PowerWalkWorkout.quick(preset: preset)
        let standard = PowerWalkWorkout.standard(preset: preset)
        let extended = PowerWalkWorkout.extended(preset: preset)

        return [
            PowerWalkDurationOption(
                id: "quick",
                displayName: "Quick",
                durationLabel: quick.formattedDuration,
                subtitle: "\(quick.totalCycles) cycles · \(quick.formattedEstimatedSteps) steps",
                briskIntervals: 3,
                estimatedSteps: quick.estimatedSteps,
                workout: quick
            ),
            PowerWalkDurationOption(
                id: "standard",
                displayName: "Standard",
                durationLabel: standard.formattedDuration,
                subtitle: "\(standard.totalCycles) cycles · \(standard.formattedEstimatedSteps) steps",
                briskIntervals: 5,
                estimatedSteps: standard.estimatedSteps,
                workout: standard
            ),
            PowerWalkDurationOption(
                id: "extended",
                displayName: "Extended",
                durationLabel: extended.formattedDuration,
                subtitle: "\(extended.totalCycles) cycles · \(extended.formattedEstimatedSteps) steps",
                briskIntervals: 7,
                estimatedSteps: extended.estimatedSteps,
                workout: extended
            )
        ]
    }

    /// Options using IntervalStyle instead of PowerWalkPreset
    static func options(for style: IntervalStyle) -> [PowerWalkDurationOption] {
        let quickCycles = 3
        let standardCycles = 5
        let extendedCycles = 7

        let quickSteps = style.estimatedSteps(cycles: quickCycles)
        let standardSteps = style.estimatedSteps(cycles: standardCycles)
        let extendedSteps = style.estimatedSteps(cycles: extendedCycles)

        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal

        return [
            PowerWalkDurationOption(
                id: "quick",
                displayName: "Quick",
                durationLabel: "\(Int(style.totalDuration(cycles: quickCycles) / 60)) min",
                subtitle: "\(quickCycles) cycles · ~\(formatter.string(from: NSNumber(value: quickSteps)) ?? "\(quickSteps)") steps",
                briskIntervals: quickCycles,
                estimatedSteps: quickSteps,
                workout: PowerWalkWorkout.from(style: style, cycles: quickCycles)
            ),
            PowerWalkDurationOption(
                id: "standard",
                displayName: "Standard",
                durationLabel: "\(Int(style.totalDuration(cycles: standardCycles) / 60)) min",
                subtitle: "\(standardCycles) cycles · ~\(formatter.string(from: NSNumber(value: standardSteps)) ?? "\(standardSteps)") steps",
                briskIntervals: standardCycles,
                estimatedSteps: standardSteps,
                workout: PowerWalkWorkout.from(style: style, cycles: standardCycles)
            ),
            PowerWalkDurationOption(
                id: "extended",
                displayName: "Extended",
                durationLabel: "\(Int(style.totalDuration(cycles: extendedCycles) / 60)) min",
                subtitle: "\(extendedCycles) cycles · ~\(formatter.string(from: NSNumber(value: extendedSteps)) ?? "\(extendedSteps)") steps",
                briskIntervals: extendedCycles,
                estimatedSteps: extendedSteps,
                workout: PowerWalkWorkout.from(style: style, cycles: extendedCycles)
            )
        ]
    }
}

// MARK: - Scheduled Phase

/// Individual phase in the workout schedule
struct ScheduledPhase: Identifiable, Equatable {
    let id: UUID
    let phase: PowerWalkPhase
    let duration: TimeInterval
    let intervalNumber: Int?   // nil for warmup/cooldown (legacy)

    /// Absolute end time (calculated at session start)
    var endTime: Date?

    init(
        id: UUID = UUID(),
        phase: PowerWalkPhase,
        duration: TimeInterval,
        intervalNumber: Int?,
        endTime: Date? = nil
    ) {
        self.id = id
        self.phase = phase
        self.duration = duration
        self.intervalNumber = intervalNumber
        self.endTime = endTime
    }

    /// Duration formatted as mm:ss
    var formattedDuration: String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    /// Display label for this phase
    var displayLabel: String {
        phase.rawValue
    }
}

// MARK: - Session Summary

/// Summary of completed Power Walk session
struct PowerWalkSessionSummary: Codable, Equatable {
    let startTime: Date
    let endTime: Date
    let totalDuration: TimeInterval
    let workout: PowerWalkWorkout
    let completedBriskIntervals: Int
    let completedEasyIntervals: Int
    let completedSuccessfully: Bool

    // Added during/after session
    var steps: Int
    var distance: Double
    var averageHeartRate: Double
    var activeCalories: Double

    init(
        startTime: Date,
        endTime: Date,
        totalDuration: TimeInterval,
        workout: PowerWalkWorkout,
        completedBriskIntervals: Int,
        completedEasyIntervals: Int,
        completedSuccessfully: Bool,
        steps: Int = 0,
        distance: Double = 0,
        averageHeartRate: Double = 0,
        activeCalories: Double = 0
    ) {
        self.startTime = startTime
        self.endTime = endTime
        self.totalDuration = totalDuration
        self.workout = workout
        self.completedBriskIntervals = completedBriskIntervals
        self.completedEasyIntervals = completedEasyIntervals
        self.completedSuccessfully = completedSuccessfully
        self.steps = steps
        self.distance = distance
        self.averageHeartRate = averageHeartRate
        self.activeCalories = activeCalories
    }

    /// Formatted duration (e.g., "23:47")
    var formattedDuration: String {
        let minutes = Int(totalDuration) / 60
        let seconds = Int(totalDuration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    /// Completion percentage (0.0 to 1.0)
    var completionPercentage: Double {
        guard workout.targetBriskIntervals > 0 else { return 0 }
        return Double(completedBriskIntervals) / Double(workout.targetBriskIntervals)
    }

    /// Formatted completion (e.g., "5 of 5")
    var formattedCompletion: String {
        "\(completedBriskIntervals) of \(workout.targetBriskIntervals)"
    }

    /// Distance formatted in miles
    var formattedDistance: String {
        let miles = distance * 0.000621371
        return String(format: "%.2f mi", miles)
    }
}
