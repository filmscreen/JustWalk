//
//  IntervalEditorViewModel.swift
//  Just Walk
//
//  ViewModel for the Custom Interval Editor.
//  Manages state, validation, and preset operations for Pro users.
//

import Foundation
import Combine

@MainActor
final class IntervalEditorViewModel: ObservableObject {

    // MARK: - Published State

    /// Easy phase duration in seconds (60-300, 30-sec increments)
    @Published var easyDurationSeconds: TimeInterval = 180

    /// Brisk phase duration in seconds (60-300, 30-sec increments)
    @Published var briskDurationSeconds: TimeInterval = 180

    /// Number of interval cycles (2-10)
    @Published var numberOfIntervals: Int = 5

    /// Include 2-minute warmup (legacy - defaults to false in simplified flow)
    @Published var includeWarmup: Bool = false

    /// Include 2-minute cooldown (legacy - defaults to false in simplified flow)
    @Published var includeCooldown: Bool = false

    /// Current validation error (if any)
    @Published var validationError: ValidationError? = nil

    // MARK: - Dependencies

    private let preferencesManager = PowerWalkPreferencesManager.shared

    // MARK: - Constants

    static let warmupDuration: TimeInterval = 120
    static let cooldownDuration: TimeInterval = 120
    static let minTotalDuration: TimeInterval = 360   // 6 minutes
    static let maxTotalDuration: TimeInterval = 3600  // 60 minutes
    static let minPhaseDuration: TimeInterval = 60    // 1 minute
    static let maxPhaseDuration: TimeInterval = 300   // 5 minutes
    static let durationIncrement: TimeInterval = 30   // 30 seconds
    static let minIntervals = 2
    static let maxIntervals = 10
    static let maxCustomPresets = 5

    // MARK: - Validation

    enum ValidationError: LocalizedError {
        case durationTooShort
        case durationTooLong
        case maxCustomPresetsReached
        case duplicateName
        case emptyName

        var errorDescription: String? {
            switch self {
            case .durationTooShort:
                return "Minimum workout duration is 6 minutes"
            case .durationTooLong:
                return "Maximum workout duration is 60 minutes"
            case .maxCustomPresetsReached:
                return "You can save up to 5 custom presets"
            case .duplicateName:
                return "A preset with this name already exists"
            case .emptyName:
                return "Please enter a preset name"
            }
        }
    }

    // MARK: - Computed Properties

    /// All custom presets from the preferences manager
    var customPresets: [PowerWalkPreset] {
        preferencesManager.customPresets
    }

    /// Whether user can save more custom presets
    var canSaveMorePresets: Bool {
        customPresets.count < Self.maxCustomPresets
    }

    /// Duration of one complete cycle (easy + brisk)
    var cycleDuration: TimeInterval {
        easyDurationSeconds + briskDurationSeconds
    }

    /// Total workout duration including warmup/cooldown
    var totalWorkoutDuration: TimeInterval {
        let warmup = includeWarmup ? Self.warmupDuration : 0
        let cooldown = includeCooldown ? Self.cooldownDuration : 0
        let intervals = Double(numberOfIntervals) * cycleDuration
        return warmup + intervals + cooldown
    }

    /// Total workout duration in minutes
    var totalWorkoutMinutes: Int {
        Int(totalWorkoutDuration / 60)
    }

    /// Human-readable total duration (e.g., "32 min")
    var formattedTotalDuration: String {
        "\(totalWorkoutMinutes) min"
    }

    /// Whether the current configuration is valid
    var isValidConfiguration: Bool {
        totalWorkoutDuration >= Self.minTotalDuration &&
        totalWorkoutDuration <= Self.maxTotalDuration
    }

    /// Estimated steps for the workout
    /// Based on ~90 steps/min easy, ~130 steps/min brisk
    var estimatedSteps: Int {
        let warmupSteps = includeWarmup ? Int(Self.warmupDuration / 60) * 90 : 0
        let cooldownSteps = includeCooldown ? Int(Self.cooldownDuration / 60) * 90 : 0
        let easySteps = Int(easyDurationSeconds / 60) * 90 * numberOfIntervals
        let briskSteps = Int(briskDurationSeconds / 60) * 130 * numberOfIntervals
        return warmupSteps + easySteps + briskSteps + cooldownSteps
    }

    /// Formatted estimated steps (e.g., "~4,200 steps")
    var formattedEstimatedSteps: String {
        "~\(estimatedSteps.formatted()) steps"
    }

    /// Easy duration formatted as M:SS (e.g., "3:00")
    var easyDurationFormatted: String {
        formatDurationMinSec(easyDurationSeconds)
    }

    /// Brisk duration formatted as M:SS (e.g., "3:00")
    var briskDurationFormatted: String {
        formatDurationMinSec(briskDurationSeconds)
    }

    /// Human-readable walk structure description
    var workoutDescription: String {
        var parts: [String] = []

        if includeWarmup {
            parts.append("2 min warmup")
        }

        parts.append("\(numberOfIntervals)× (\(easyDurationFormatted) easy + \(briskDurationFormatted) brisk)")

        if includeCooldown {
            parts.append("2 min cooldown")
        }

        return parts.joined(separator: " → ")
    }

    // MARK: - Duration Options

    /// Available duration options: 1:00, 1:30, 2:00, 2:30, 3:00, 3:30, 4:00, 4:30, 5:00
    var durationOptions: [TimeInterval] {
        stride(from: Self.minPhaseDuration, through: Self.maxPhaseDuration, by: Self.durationIncrement)
            .map { TimeInterval($0) }
    }

    /// Available interval count options: 2-10
    var intervalCountOptions: [Int] {
        Array(Self.minIntervals...Self.maxIntervals)
    }

    // MARK: - Actions

    /// Set the easy phase duration
    func setEasyDuration(_ seconds: TimeInterval) {
        easyDurationSeconds = clampDuration(seconds)
        validateConfiguration()
        HapticService.shared.playSelection()
    }

    /// Set the brisk phase duration
    func setBriskDuration(_ seconds: TimeInterval) {
        briskDurationSeconds = clampDuration(seconds)
        validateConfiguration()
        HapticService.shared.playSelection()
    }

    /// Set the number of intervals
    func setIntervalCount(_ count: Int) {
        numberOfIntervals = max(Self.minIntervals, min(Self.maxIntervals, count))
        validateConfiguration()
        HapticService.shared.playSelection()
    }

    /// Toggle warmup inclusion
    func setIncludeWarmup(_ include: Bool) {
        includeWarmup = include
        validateConfiguration()
    }

    /// Toggle cooldown inclusion
    func setIncludeCooldown(_ include: Bool) {
        includeCooldown = include
        validateConfiguration()
    }

    /// Load values from an existing preset
    func loadPreset(_ preset: PowerWalkPreset) {
        easyDurationSeconds = preset.easyDuration
        briskDurationSeconds = preset.briskDuration
        validateConfiguration()
        HapticService.shared.playSelection()
    }

    /// Validate the current configuration
    func validateConfiguration() {
        if totalWorkoutDuration < Self.minTotalDuration {
            validationError = .durationTooShort
        } else if totalWorkoutDuration > Self.maxTotalDuration {
            validationError = .durationTooLong
        } else {
            validationError = nil
        }
    }

    /// Check if a preset name is unique
    func isPresetNameUnique(_ name: String) -> Bool {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let allNames = (PowerWalkPreset.allPresets + customPresets)
            .map { $0.name.lowercased() }
        return !allNames.contains(trimmedName)
    }

    /// Save the current configuration as a custom preset
    /// - Parameter name: The name for the new preset
    /// - Returns: true if save was successful, false if validation failed
    func saveAsPreset(name: String) -> Bool {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)

        // Validate name
        guard !trimmedName.isEmpty else {
            validationError = .emptyName
            HapticService.shared.playError()
            return false
        }

        // Check for duplicates
        guard isPresetNameUnique(trimmedName) else {
            validationError = .duplicateName
            HapticService.shared.playError()
            return false
        }

        // Check preset limit
        guard canSaveMorePresets else {
            validationError = .maxCustomPresetsReached
            HapticService.shared.playError()
            return false
        }

        // Create and save the preset
        let newPreset = PowerWalkPreset.customWithSeconds(
            name: trimmedName,
            easySeconds: easyDurationSeconds,
            briskSeconds: briskDurationSeconds
        )

        preferencesManager.addCustomPreset(newPreset)
        preferencesManager.selectPreset(newPreset)

        HapticService.shared.playSuccess()
        return true
    }

    /// Delete a custom preset
    func deleteCustomPreset(_ preset: PowerWalkPreset) {
        preferencesManager.removeCustomPreset(preset)
        HapticService.shared.playWarning()
    }

    /// Build an IWTConfiguration from the current settings
    func buildConfiguration() -> IWTConfiguration {
        IWTConfiguration(
            briskDuration: briskDurationSeconds,
            slowDuration: easyDurationSeconds,
            warmupDuration: includeWarmup ? Self.warmupDuration : 0,
            cooldownDuration: includeCooldown ? Self.cooldownDuration : 0,
            totalIntervals: numberOfIntervals,
            enableWarmup: includeWarmup,
            enableCooldown: includeCooldown
        )
    }

    // MARK: - Helpers

    private func clampDuration(_ seconds: TimeInterval) -> TimeInterval {
        max(Self.minPhaseDuration, min(Self.maxPhaseDuration, seconds))
    }

    private func formatDurationMinSec(_ seconds: TimeInterval) -> String {
        let mins = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%d:%02d", mins, secs)
    }
}
