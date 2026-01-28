//
//  PowerWalkPreferencesManager.swift
//  Just Walk
//
//  Persists Power Walk user preferences.
//  Manages selected interval style, cycle count, and custom presets.
//

import Foundation
import Combine

/// Persists Power Walk user preferences
@MainActor
final class PowerWalkPreferencesManager: ObservableObject {
    static let shared = PowerWalkPreferencesManager()

    private let defaults = UserDefaults.standard

    // MARK: - Keys

    private enum Keys {
        static let selectedPresetId = "powerWalk_selectedPresetId"
        static let lastWorkoutIntervals = "powerWalk_lastWorkoutIntervals"
        static let customPresets = "powerWalk_customPresets"
        static let defaultPresetId = "powerWalk_defaultPresetId"
        static let defaultDurationMinutes = "powerWalk_defaultDurationMinutes"
        static let lastUsedDurationOption = "powerWalk_lastUsedDurationOption"
        static let hasCompletedOnboarding = "powerWalk_hasCompletedOnboarding"

        // New simplified interval settings
        static let intervalStyle = "powerWalk_intervalStyle"
        static let cycleCount = "powerWalk_cycleCount"
        static let selectedDurationId = "powerWalk_selectedDurationId"
    }

    // MARK: - Constants

    /// Available default duration options (in minutes)
    static let defaultDurationOptions: [Int] = [18, 30, 42]

    /// Minimum and maximum cycle counts
    static let minCycles = 3
    static let maxCycles = 10

    // MARK: - Published Properties

    @Published private(set) var selectedPreset: PowerWalkPreset = .default
    @Published private(set) var lastWorkoutIntervals: Int = 5
    @Published private(set) var customPresets: [PowerWalkPreset] = []
    @Published private(set) var defaultDurationMinutes: Int = 30
    @Published private(set) var lastUsedDurationOption: String = "standard"
    @Published private(set) var hasCompletedOnboarding: Bool = false

    // New simplified settings
    @Published var intervalStyle: IntervalStyle = .standard
    @Published var cycleCount: Int = 5
    @Published private(set) var selectedDurationId: String = "standard"

    // MARK: - Initialization

    private init() {
        loadPreferences()
    }

    // MARK: - Computed Properties

    /// All available presets (built-in + custom)
    var allPresets: [PowerWalkPreset] {
        PowerWalkPreset.allPresets + customPresets
    }

    /// The user's default preset (may differ from selected)
    var defaultPreset: PowerWalkPreset {
        let id = defaults.string(forKey: Keys.defaultPresetId) ?? PowerWalkPreset.default.id
        return allPresets.first { $0.id == id } ?? .default
    }

    /// Build workout from current preferences (simplified)
    var currentWorkout: PowerWalkWorkout {
        PowerWalkWorkout.from(style: intervalStyle, cycles: cycleCount)
    }

    /// Quick access to duration options for the selected interval style
    var durationOptions: [PowerWalkDurationOption] {
        PowerWalkDurationOption.options(for: intervalStyle)
    }

    /// Get the current configuration for IWTService
    var currentConfiguration: IWTConfiguration {
        intervalStyle.configuration(cycles: cycleCount)
    }

    /// Preview text showing current walk structure
    var structurePreview: String {
        let totalDuration = intervalStyle.totalDuration(cycles: cycleCount)
        let totalMinutes = Int(totalDuration / 60)
        let steps = intervalStyle.estimatedSteps(cycles: cycleCount)
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        let formattedSteps = formatter.string(from: NSNumber(value: steps)) ?? "\(steps)"
        return "\(totalMinutes) min · \(cycleCount) intervals · ~\(formattedSteps) steps"
    }

    // MARK: - Interval Style & Cycle Count (Simplified)

    /// Set the interval style
    func setIntervalStyle(_ style: IntervalStyle) {
        intervalStyle = style
        defaults.set(style.rawValue, forKey: Keys.intervalStyle)
    }

    /// Set the number of cycles
    func setCycleCount(_ count: Int) {
        cycleCount = max(Self.minCycles, min(Self.maxCycles, count))
        defaults.set(cycleCount, forKey: Keys.cycleCount)
    }

    /// Set the selected duration option (quick/standard/extended)
    func setSelectedDurationId(_ id: String) {
        selectedDurationId = id
        defaults.set(id, forKey: Keys.selectedDurationId)

        // Also update cycle count based on selection
        switch id {
        case "quick":
            setCycleCount(3)
        case "standard":
            setCycleCount(5)
        case "extended":
            setCycleCount(7)
        default:
            break
        }
    }

    /// Save current interval settings as user's default
    func saveCustomDefaults() {
        defaults.set(intervalStyle.rawValue, forKey: Keys.intervalStyle)
        defaults.set(cycleCount, forKey: Keys.cycleCount)
    }

    // MARK: - Preset Selection (Legacy support)

    /// Select a preset for the next workout
    func selectPreset(_ preset: PowerWalkPreset) {
        selectedPreset = preset
        defaults.set(preset.id, forKey: Keys.selectedPresetId)
    }

    /// Set the user's default preset
    func setDefaultPreset(_ preset: PowerWalkPreset) {
        defaults.set(preset.id, forKey: Keys.defaultPresetId)
    }

    /// Set the default workout duration (in minutes)
    func setDefaultDurationMinutes(_ minutes: Int) {
        guard Self.defaultDurationOptions.contains(minutes) else { return }
        defaultDurationMinutes = minutes
        defaults.set(minutes, forKey: Keys.defaultDurationMinutes)
    }

    // MARK: - Workout Settings

    /// Set the number of brisk intervals
    func setWorkoutIntervals(_ count: Int) {
        lastWorkoutIntervals = max(1, min(15, count))
        defaults.set(lastWorkoutIntervals, forKey: Keys.lastWorkoutIntervals)
    }

    /// Set the last used duration option (quick/standard/extended)
    func setLastUsedDurationOption(_ optionId: String) {
        lastUsedDurationOption = optionId
        defaults.set(optionId, forKey: Keys.lastUsedDurationOption)

        // Also update intervals based on option
        switch optionId {
        case "quick":
            setWorkoutIntervals(3)
        case "standard":
            setWorkoutIntervals(5)
        case "extended":
            setWorkoutIntervals(7)
        default:
            break
        }
    }

    /// Mark onboarding as completed
    func completeOnboarding() {
        hasCompletedOnboarding = true
        defaults.set(true, forKey: Keys.hasCompletedOnboarding)
    }

    // MARK: - Custom Presets

    /// Add a custom preset
    func addCustomPreset(_ preset: PowerWalkPreset) {
        customPresets.append(preset)
        saveCustomPresets()
    }

    /// Remove a custom preset
    func removeCustomPreset(_ preset: PowerWalkPreset) {
        customPresets.removeAll { $0.id == preset.id }
        saveCustomPresets()

        // If this was the selected preset, revert to default
        if selectedPreset.id == preset.id {
            selectPreset(.default)
        }
    }

    /// Update an existing custom preset
    func updateCustomPreset(_ preset: PowerWalkPreset) {
        if let index = customPresets.firstIndex(where: { $0.id == preset.id }) {
            customPresets[index] = preset
            saveCustomPresets()

            // Update selected if this was selected
            if selectedPreset.id == preset.id {
                selectedPreset = preset
            }
        }
    }

    /// Check if a preset is custom (user-created)
    func isCustomPreset(_ preset: PowerWalkPreset) -> Bool {
        customPresets.contains { $0.id == preset.id }
    }

    // MARK: - Reset

    /// Reset all preferences to defaults
    func resetToDefaults() {
        selectedPreset = .default
        lastWorkoutIntervals = 5
        defaultDurationMinutes = 30
        lastUsedDurationOption = "standard"
        intervalStyle = .standard
        cycleCount = 5
        selectedDurationId = "standard"

        defaults.removeObject(forKey: Keys.selectedPresetId)
        defaults.removeObject(forKey: Keys.lastWorkoutIntervals)
        defaults.removeObject(forKey: Keys.defaultPresetId)
        defaults.removeObject(forKey: Keys.defaultDurationMinutes)
        defaults.removeObject(forKey: Keys.lastUsedDurationOption)
        defaults.removeObject(forKey: Keys.intervalStyle)
        defaults.removeObject(forKey: Keys.cycleCount)
        defaults.removeObject(forKey: Keys.selectedDurationId)
        // Note: Don't reset custom presets or onboarding
    }

    // MARK: - Persistence

    private func loadPreferences() {
        // Load selected preset
        if let presetId = defaults.string(forKey: Keys.selectedPresetId) {
            // First check built-in presets
            if let preset = PowerWalkPreset.allPresets.first(where: { $0.id == presetId }) {
                selectedPreset = preset
            }
            // Then check custom presets (loaded below)
        }

        // Load workout settings
        let intervals = defaults.integer(forKey: Keys.lastWorkoutIntervals)
        lastWorkoutIntervals = intervals > 0 ? intervals : 5

        // Load duration option
        if let durationOption = defaults.string(forKey: Keys.lastUsedDurationOption) {
            lastUsedDurationOption = durationOption
        }

        // Load default duration
        let duration = defaults.integer(forKey: Keys.defaultDurationMinutes)
        defaultDurationMinutes = duration > 0 ? duration : 30

        // Load onboarding state
        hasCompletedOnboarding = defaults.bool(forKey: Keys.hasCompletedOnboarding)

        // Load new simplified settings
        if let styleRaw = defaults.string(forKey: Keys.intervalStyle),
           let style = IntervalStyle(rawValue: styleRaw) {
            intervalStyle = style
        }

        let savedCycles = defaults.integer(forKey: Keys.cycleCount)
        cycleCount = savedCycles > 0 ? savedCycles : 5

        if let durationId = defaults.string(forKey: Keys.selectedDurationId) {
            selectedDurationId = durationId
        }

        // Load custom presets
        loadCustomPresets()

        // Now check if selected preset was a custom one
        if let presetId = defaults.string(forKey: Keys.selectedPresetId),
           !PowerWalkPreset.allPresets.contains(where: { $0.id == presetId }),
           let customPreset = customPresets.first(where: { $0.id == presetId }) {
            selectedPreset = customPreset
        }
    }

    private func loadCustomPresets() {
        guard let data = defaults.data(forKey: Keys.customPresets),
              let presets = try? JSONDecoder().decode([PowerWalkPreset].self, from: data) else {
            return
        }
        customPresets = presets
    }

    private func saveCustomPresets() {
        guard let data = try? JSONEncoder().encode(customPresets) else { return }
        defaults.set(data, forKey: Keys.customPresets)
    }
}

// MARK: - Convenience Extension

extension PowerWalkPreferencesManager {
    /// Create a workout for a specific duration option
    func workout(for optionId: String) -> PowerWalkWorkout {
        switch optionId {
        case "quick":
            return PowerWalkWorkout.from(style: intervalStyle, cycles: 3)
        case "extended":
            return PowerWalkWorkout.from(style: intervalStyle, cycles: 7)
        default:
            return PowerWalkWorkout.from(style: intervalStyle, cycles: 5)
        }
    }

    /// Get the recommended workout based on steps remaining
    func recommendedWorkout(stepsRemaining: Int) -> PowerWalkRecommendation {
        PowerWalkRecommendation.calculate(
            stepsRemaining: stepsRemaining,
            preset: selectedPreset
        )
    }
}
