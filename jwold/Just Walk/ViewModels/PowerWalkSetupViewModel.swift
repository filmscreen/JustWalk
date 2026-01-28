//
//  PowerWalkSetupViewModel.swift
//  Just Walk
//
//  View model for Power Walk Setup screen.
//  Generates duration options based on steps remaining to goal.
//

import Foundation
import Combine

// MARK: - Duration Option Model

struct SetupDurationOption: Identifiable, Equatable {
    let id = UUID()
    let minutes: Int
    let estimatedSteps: Int
    let isRecommended: Bool
    let label: String
    let hint: String?
}

// MARK: - View Model

@MainActor
final class PowerWalkSetupViewModel: ObservableObject {

    // MARK: - Published State

    @Published private(set) var durationOptions: [SetupDurationOption] = []
    @Published var selectedMinutes: Int = 30
    @Published var enableAudioCues: Bool = true
    @Published var enableHaptics: Bool = true

    @Published private(set) var stepsRemaining: Int = 0
    @Published private(set) var goalReached: Bool = false

    // MARK: - Constants

    /// Steps per minute for Power Walk (interval average)
    private let stepsPerMinute = 120

    /// Minimum duration offered
    private let minDuration = 10

    /// Maximum duration offered
    private let maxDuration = 45

    // MARK: - UserDefaults Keys

    private enum Keys {
        static let enableAudioCues = "powerWalk.enableAudioCues"
        static let enableHaptics = "powerWalk.enableHaptics"
    }

    // MARK: - Dependencies

    private let stepRepo = StepRepository.shared
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Initialization

    init() {
        loadSettings()
        setupBindings()
        refresh()
    }

    // MARK: - Bindings

    private func setupBindings() {
        stepRepo.$todaySteps
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.refresh()
            }
            .store(in: &cancellables)
    }

    // MARK: - Refresh

    func refresh() {
        stepsRemaining = stepRepo.stepsRemaining
        goalReached = stepRepo.goalReached
        durationOptions = generateDurationOptions()

        // Auto-select recommended option
        if let recommended = durationOptions.first(where: { $0.isRecommended }) {
            selectedMinutes = recommended.minutes
        } else if let first = durationOptions.first {
            selectedMinutes = first.minutes
        }
    }

    // MARK: - Duration Option Generation

    private func generateDurationOptions() -> [SetupDurationOption] {
        // Edge case: Very few steps needed (<1,000)
        if stepsRemaining > 0 && stepsRemaining < 1000 {
            return [
                SetupDurationOption(
                    minutes: 10,
                    estimatedSteps: 10 * stepsPerMinute,
                    isRecommended: true,
                    label: "Quick boost",
                    hint: "A little extra never hurts!"
                )
            ]
        }

        // Edge case: Goal already reached
        if goalReached {
            return [
                SetupDurationOption(
                    minutes: 15,
                    estimatedSteps: 15 * stepsPerMinute,
                    isRecommended: false,
                    label: "Short session",
                    hint: nil
                ),
                SetupDurationOption(
                    minutes: 25,
                    estimatedSteps: 25 * stepsPerMinute,
                    isRecommended: true,
                    label: "Standard",
                    hint: "Great for staying active"
                ),
                SetupDurationOption(
                    minutes: 35,
                    estimatedSteps: 35 * stepsPerMinute,
                    isRecommended: false,
                    label: "Extended",
                    hint: nil
                )
            ]
        }

        // Calculate recommended duration
        let exactMinutes = Int(ceil(Double(stepsRemaining) / Double(stepsPerMinute)))
        let recommendedMinutes = roundToFive(max(minDuration, min(maxDuration, exactMinutes)))

        // Generate options based on steps remaining
        return generateOptionsForSteps(stepsRemaining, recommended: recommendedMinutes)
    }

    private func generateOptionsForSteps(_ steps: Int, recommended: Int) -> [SetupDurationOption] {
        var options: [SetupDurationOption] = []

        switch steps {
        case 1000..<2000:
            // 10, 15, 20 min
            options = [
                makeOption(minutes: 10, recommended: recommended),
                makeOption(minutes: 15, recommended: recommended),
                makeOption(minutes: 20, recommended: recommended)
            ]

        case 2000..<4000:
            // 15, 25, 35 min
            options = [
                makeOption(minutes: 15, recommended: recommended),
                makeOption(minutes: 25, recommended: recommended),
                makeOption(minutes: 35, recommended: recommended)
            ]

        case 4000..<6000:
            // 20, 30, 40 min
            options = [
                makeOption(minutes: 20, recommended: recommended),
                makeOption(minutes: 30, recommended: recommended),
                makeOption(minutes: 40, recommended: recommended)
            ]

        default:
            // > 6000: 25, 35, 45 min
            options = [
                makeOption(minutes: 25, recommended: recommended),
                makeOption(minutes: 35, recommended: recommended),
                makeOption(minutes: 45, recommended: recommended)
            ]
        }

        return options
    }

    private func makeOption(minutes: Int, recommended: Int) -> SetupDurationOption {
        let isRecommended = minutes == recommended
        let stepsForDuration = minutes * stepsPerMinute

        // Determine hint
        var hint: String? = nil
        if isRecommended {
            if stepsForDuration >= stepsRemaining {
                hint = "Gets you to your goal"
            } else {
                hint = "Go beyond your goal"
            }
        }

        return SetupDurationOption(
            minutes: minutes,
            estimatedSteps: stepsForDuration,
            isRecommended: isRecommended,
            label: labelForDuration(minutes),
            hint: hint
        )
    }

    private func labelForDuration(_ minutes: Int) -> String {
        switch minutes {
        case ...10: return "Quick boost"
        case 11...20: return "Short session"
        case 21...30: return "Standard"
        default: return "Extended"
        }
    }

    private func roundToFive(_ value: Int) -> Int {
        return ((value + 2) / 5) * 5
    }

    // MARK: - Computed Properties

    var selectedOption: SetupDurationOption? {
        durationOptions.first { $0.minutes == selectedMinutes }
    }

    var selectedEstimatedSteps: Int {
        selectedMinutes * stepsPerMinute
    }

    var headerSubtitle: String {
        if goalReached {
            return "Keep the momentum going with a bonus Power Walk."
        }
        if stepsRemaining < 1000 {
            return "A quick boost to finish strong."
        }
        return "Alternate easy and brisk every 3 min"
    }

    var structurePreviewText: String {
        "You'll alternate between easy and brisk paces. We'll tell you when to switch."
    }

    // MARK: - Walk Configuration

    func getWalkConfiguration() -> WalkConfiguration {
        WalkConfiguration(
            duration: TimeInterval(selectedMinutes * 60),
            walkType: .fatBurn
        )
    }

    // MARK: - Settings Persistence

    func saveSettings() {
        UserDefaults.standard.set(enableAudioCues, forKey: Keys.enableAudioCues)
        UserDefaults.standard.set(enableHaptics, forKey: Keys.enableHaptics)
    }

    private func loadSettings() {
        enableAudioCues = UserDefaults.standard.object(forKey: Keys.enableAudioCues) as? Bool ?? true
        enableHaptics = UserDefaults.standard.object(forKey: Keys.enableHaptics) as? Bool ?? true
    }
}
