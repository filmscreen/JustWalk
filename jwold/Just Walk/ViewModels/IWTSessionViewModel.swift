//
//  IWTSessionViewModel.swift
//  Just Walk
//
//  Created by Randy Chia on 1/8/26.
//

import Foundation
import SwiftUI
import Combine

/// ViewModel for IWT walking session
@MainActor
final class IWTSessionViewModel: ObservableObject {

    // MARK: - Published Properties

    @Published var isSessionActive = false
    @Published var isPaused = false
    @Published var currentPhase: IWTPhase = .warmup
    @Published var phaseTimeRemaining: TimeInterval = 0
    @Published var totalElapsedTime: TimeInterval = 0
    @Published var currentInterval: Int = 0
    @Published var completedBriskIntervals: Int = 0
    @Published var completedSlowIntervals: Int = 0

    // Step tracking during session
    @Published var sessionSteps: Int = 0
    @Published var sessionDistance: Double = 0
    @Published var currentHeartRate: Double = 0
    @Published var activeCalories: Double = 0
    @Published var currentPace: String = "--:--"
    @Published var paceCategory: PaceCategory = .unknown

    // Goal progress tracking (for post-walk summary)
    @Published private(set) var stepsAtSessionStart: Int = 0
    @Published private(set) var dailyGoal: Int = 10000

    // UI State
    @Published var showCompletionSheet = false
    @Published var sessionSummary: IWTSessionSummary?
    @Published var selectedConfiguration: IWTConfiguration = .standard

    // Phase counter and instruction rotation
    @Published var currentInstructionIndex: Int = 0
    @Published var isWarningCountdown: Bool = false
    @Published var warningSecondsRemaining: Int = 10

    private var instructionRotationTask: Task<Void, Never>?
    private var warningTask: Task<Void, Never>?

    var sessionMode: WalkMode {
        iwtService.sessionMode
    }

    // MARK: - Services

    private let iwtService = IWTService.shared
    private let stepTrackingService = StepTrackingService.shared

    private var cancellables = Set<AnyCancellable>()

    // MARK: - Computed Properties

    var phaseProgress: Double {
        iwtService.phaseProgress
    }

    var sessionProgress: Double {
        iwtService.sessionProgress
    }

    var formattedPhaseTime: String {
        let minutes = Int(phaseTimeRemaining) / 60
        let seconds = Int(phaseTimeRemaining) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    var formattedTotalTime: String {
        let hours = Int(totalElapsedTime) / 3600
        let minutes = (Int(totalElapsedTime) % 3600) / 60
        let seconds = Int(totalElapsedTime) % 60

        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%02d:%02d", minutes, seconds)
        }
    }

    var formattedDistance: String {
        let miles = sessionDistance * 0.000621371
        return String(format: "%.2f mi", miles)
    }

    var intervalDisplay: String {
        if sessionMode == .classic {
            return "Classic Walk"
        }

        if currentInterval == 0 {
            return "Warming up"
        } else {
            return "Interval \(currentInterval) of \(selectedConfiguration.totalIntervals)"
        }
    }

    // Phase counter for Power Walk
    var totalPhases: Int {
        return iwtService.configuration.totalIntervals * 2
    }

    var currentPhaseNumber: Int {
        let interval = iwtService.currentInterval
        if currentPhase == .slow {
            // Easy phase comes first in each interval cycle
            return (interval - 1) * 2 + 1
        } else if currentPhase == .brisk {
            // Brisk phase comes second
            return (interval - 1) * 2 + 2
        }
        return 0
    }

    var phaseCounterDisplay: String {
        guard currentPhaseNumber > 0 else { return "" }
        return "Phase \(currentPhaseNumber) of \(totalPhases)"
    }

    var currentInstruction: String {
        let instructions = currentPhase.instructions
        guard !instructions.isEmpty else { return "" }
        return instructions[currentInstructionIndex % instructions.count]
    }

    // MARK: - Initialization

    init() {
        setupBindings()
        loadConfiguration()

        // CRITICAL: Sync initial state from IWTService immediately
        // This prevents timer reset when view is recreated (e.g., returning from background)
        syncStateFromService()
    }

    /// Sync current state from IWTService
    /// Called on init and can be called when view appears to ensure state consistency
    func syncStateFromService() {
        isSessionActive = iwtService.isSessionActive
        isPaused = iwtService.isPaused
        currentPhase = iwtService.currentPhase
        currentInterval = iwtService.currentInterval
        completedBriskIntervals = iwtService.completedBriskIntervals
        completedSlowIntervals = iwtService.completedSlowIntervals
        totalElapsedTime = iwtService.totalElapsedTime

        // CRITICAL: Sync phaseTimeRemaining from absolute phaseEndTime
        // This ensures accurate time display after returning from background
        if let endTime = iwtService.phaseEndTime {
            phaseTimeRemaining = max(0, endTime.timeIntervalSinceNow)
        } else {
            phaseTimeRemaining = iwtService.phaseTimeRemaining
        }
    }
    
    private func loadConfiguration() {
        let defaults = UserDefaults.standard
        let briskMinutes = defaults.integer(forKey: "iwtBriskMinutes")
        let slowMinutes = defaults.integer(forKey: "iwtSlowMinutes")
        
        // Use defaults if not set (3 mins each)
        let briskDuration = TimeInterval((briskMinutes > 0 ? briskMinutes : 3) * 60)
        let slowDuration = TimeInterval((slowMinutes > 0 ? slowMinutes : 3) * 60)
        
        let enableWarmup = defaults.object(forKey: "iwtEnableWarmup") as? Bool ?? true
        let enableCooldown = defaults.object(forKey: "iwtEnableCooldown") as? Bool ?? true
        
        selectedConfiguration = IWTConfiguration(
            briskDuration: briskDuration,
            slowDuration: slowDuration,
            warmupDuration: 120,
            cooldownDuration: 120,
            totalIntervals: 5,
            enableWarmup: enableWarmup,
            enableCooldown: enableCooldown
        )
    }

    // MARK: - Setup

    private func setupBindings() {
        // Bind IWT service state
        iwtService.$isSessionActive
            .receive(on: DispatchQueue.main)
            .assign(to: &$isSessionActive)

        iwtService.$isPaused
            .receive(on: DispatchQueue.main)
            .assign(to: &$isPaused)

        iwtService.$currentPhase
            .receive(on: DispatchQueue.main)
            .assign(to: &$currentPhase)

        iwtService.$phaseTimeRemaining
            .receive(on: DispatchQueue.main)
            .sink { [weak self] remaining in
                self?.phaseTimeRemaining = remaining
                // Trigger 10-second warning countdown
                if remaining <= 10 && remaining > 9 && !(self?.isWarningCountdown ?? false) {
                    self?.startWarningCountdown()
                }
            }
            .store(in: &cancellables)

        iwtService.$totalElapsedTime
            .receive(on: DispatchQueue.main)
            .assign(to: &$totalElapsedTime)

        iwtService.$currentInterval
            .receive(on: DispatchQueue.main)
            .assign(to: &$currentInterval)

        iwtService.$completedBriskIntervals
            .receive(on: DispatchQueue.main)
            .assign(to: &$completedBriskIntervals)

        iwtService.$completedSlowIntervals
            .receive(on: DispatchQueue.main)
            .assign(to: &$completedSlowIntervals)

        // Bind step tracking service state (for session steps/distance)
        stepTrackingService.$sessionSteps
            .receive(on: DispatchQueue.main)
            .assign(to: &$sessionSteps)

        stepTrackingService.$sessionDistance
            .receive(on: DispatchQueue.main)
            .assign(to: &$sessionDistance)

        stepTrackingService.$currentHeartRate
            .receive(on: DispatchQueue.main)
            .assign(to: &$currentHeartRate)

        stepTrackingService.$activeCalories
            .receive(on: DispatchQueue.main)
            .assign(to: &$activeCalories)

        // Setup callbacks
        iwtService.onPhaseChange = { [weak self] phase in
            Task { @MainActor in
                self?.handlePhaseChange(phase)
            }
        }

        iwtService.onSessionComplete = { [weak self] in
            Task { @MainActor in
                self?.handleSessionComplete()
            }
        }
        
        // Listen for remote stop (from Watch)
        NotificationCenter.default.publisher(for: .remoteSessionStopped)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] notification in
                let info = notification.userInfo
                let steps = info?["finalSteps"] as? Int
                let district = info?["finalDistance"] as? Double
                let cals = info?["finalCalories"] as? Double
                
                self?.endSession(finalSteps: steps, finalDistance: district, finalCalories: cals)
            }
            .store(in: &cancellables)
            
        // Listen for remote pause
        NotificationCenter.default.publisher(for: .remoteSessionPaused)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                guard let self = self else { return }
                if !self.isPaused { // Prevent loop
                    self.iwtService.pauseSession() 
                }
            }
            .store(in: &cancellables)

        // Listen for remote resume
        NotificationCenter.default.publisher(for: .remoteSessionResumed)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                guard let self = self else { return }
                if self.isPaused { // Prevent loop
                    self.iwtService.resumeSession()
                }
            }
            .store(in: &cancellables)
    }

    // MARK: - Session Control

    func startSession(mode: WalkMode = .interval) {
        // Capture steps before walk for goal progress visualization
        // Use async Task to get real-time CMPedometer steps (no HealthKit delay)
        Task {
            if let pedometerSteps = await stepTrackingService.queryTodayStepsFromPedometer() {
                stepsAtSessionStart = pedometerSteps
            } else {
                // Fall back to HealthKit if CMPedometer unavailable
                stepsAtSessionStart = StepRepository.shared.todaySteps
            }
        }
        dailyGoal = StepRepository.shared.stepGoal

        // Play Symphony haptic for session start
        HapticService.shared.playSymphony()

        // Start IWT timer
        iwtService.startSession(mode: mode, with: iwtService.configuration)

        // Start step tracking with pace/cadence updates
        stepTrackingService.startSession { [weak self] update in
            Task { @MainActor in
                self?.handlePedometerUpdate(update)
            }
        }
    }

    func pauseSession() {
        iwtService.pauseSession()
        // stepTrackingService.sendSessionPauseToWatch() // Handled by IWTService now
    }

    func resumeSession() {
        iwtService.resumeSession()
        // stepTrackingService.sendSessionResumeToWatch() // Handled by IWTService now
    }

    func endSession(finalSteps: Int? = nil, finalDistance: Double? = nil, finalCalories: Double? = nil, hkWorkoutId: UUID? = nil) {
        // Prevent double-calling if session is already ended
        guard iwtService.isSessionActive else { return }

        let stepsToSave = finalSteps ?? stepTrackingService.sessionSteps
        let distanceToSave = finalDistance ?? stepTrackingService.sessionDistance
        let calsToSave = finalCalories ?? stepTrackingService.activeCalories

        // Generate summary (which also stops IWT timer and sets active=false)
        if let summary = iwtService.endSession(
            steps: stepsToSave,
            distance: distanceToSave,
            averageHeartRate: stepTrackingService.sessionAverageHeartRate,
            activeCalories: calsToSave
        ) {
            self.sessionSummary = summary
            self.showCompletionSheet = true

            // Persist session with HealthKit workout ID for later fetching
            Task {
                do {
                    try await SessionPersistenceService.shared.saveIWTSession(
                        summary,
                        steps: stepsToSave,
                        distance: distanceToSave,
                        isIWTSession: sessionMode == .interval,
                        hkWorkoutId: hkWorkoutId
                    )
                } catch {
                    print("Failed to save session: \(error)")
                }
            }
        }
        
        // Stop sensor tracking
        Task {
            _ = await stepTrackingService.stopSession()

            // AGGRESSIVE WIDGET UPDATE: Force widget refresh after session ends
            // This ensures widgets show the new step count immediately
            stepTrackingService.forceWidgetUpdate()
        }
    }

    func skipPhase() {
        iwtService.skipToNextPhase()
    }

    // MARK: - Configuration
    
    // Configuration is now loaded from Settings via loadConfiguration()

    // MARK: - Event Handlers

    private func handlePhaseChange(_ phase: IWTPhase) {
        // Reset instruction index when phase changes
        currentInstructionIndex = 0
        isWarningCountdown = false
        warningTask?.cancel()

        // Update pace guidance based on phase
        updatePaceGuidance(for: phase)

        // Start instruction rotation for the new phase
        startInstructionRotation()
    }

    // MARK: - Instruction Rotation

    private func startInstructionRotation() {
        instructionRotationTask?.cancel()
        instructionRotationTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 8_000_000_000) // 8 seconds
                guard !Task.isCancelled else { return }
                await MainActor.run {
                    self?.currentInstructionIndex += 1
                }
            }
        }
    }

    // MARK: - Warning Countdown

    private func startWarningCountdown() {
        warningTask?.cancel()
        isWarningCountdown = true
        warningSecondsRemaining = 10

        // Single haptic tap for warning
        HapticService.shared.playSelection()

        warningTask = Task { [weak self] in
            for i in stride(from: 9, through: 1, by: -1) {
                try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
                guard !Task.isCancelled else { return }
                await MainActor.run {
                    self?.warningSecondsRemaining = i
                }
            }
            await MainActor.run {
                self?.isWarningCountdown = false
            }
        }
    }

    private func handleSessionComplete() {
        let steps = stepTrackingService.sessionSteps
        let distance = stepTrackingService.sessionDistance
        let avgHR = stepTrackingService.sessionAverageHeartRate
        let activeCalories = stepTrackingService.activeCalories

        sessionSummary = iwtService.endSession(
            steps: steps,
            distance: distance,
            averageHeartRate: avgHR,
            activeCalories: activeCalories
        )

        // Stop both step tracking AND GPS workout to get hkWorkoutId
        Task {
            _ = await stepTrackingService.stopSession()

            // Stop GPS workout and capture HealthKit workout ID
            let gpsSummary = try? await PhoneWorkoutManager.shared.stopWorkout()
            let hkWorkoutId = gpsSummary?.hkWorkoutId

            // Save session with hkWorkoutId
            if let summary = sessionSummary {
                do {
                    try await SessionPersistenceService.shared.saveIWTSession(
                        summary,
                        steps: sessionSteps,
                        distance: sessionDistance,
                        isIWTSession: sessionMode == .interval,
                        hkWorkoutId: hkWorkoutId
                    )
                } catch {
                    print("Failed to save IWT session: \(error)")
                }
            }
        }

        showCompletionSheet = true
    }

    private func handlePedometerUpdate(_ update: PedometerUpdate) {
        currentPace = stepTrackingService.formattedPace()
        paceCategory = stepTrackingService.currentPaceCategory()
    }

    private func updatePaceGuidance(for phase: IWTPhase) {
        // Could provide haptic feedback or visual cues based on
        // whether user's current pace matches the expected pace for the phase
    }

    // MARK: - Summary Helpers

    func dismissCompletion() {
        showCompletionSheet = false
        sessionSummary = nil
    }
}
