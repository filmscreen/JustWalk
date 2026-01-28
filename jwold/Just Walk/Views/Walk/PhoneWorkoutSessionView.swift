//
//  PhoneWorkoutSessionView.swift
//  Just Walk
//
//  Redesigned during-walk screen with STEPS as the hero.
//  Progress ring shows daily step goal progress, not time elapsed.
//

import SwiftUI
import HealthKit

struct PhoneWorkoutSessionView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var workoutManager = PhoneWorkoutManager.shared
    @ObservedObject private var stepRepository = StepRepository.shared
    @ObservedObject private var stepTrackingService = StepTrackingService.shared

    // Walk goal (passed in or defaults to .none for daily goal tracking)
    var walkGoal: WalkGoal = .none

    // Walk tracking state
    @State private var stepsAtWalkStart: Int = 0
    @State private var dailyGoalAtStart: Int = 10_000
    @State private var goalHitDuringWalk: Bool = false
    @State private var hasTriggeredGoalCelebration: Bool = false
    @State private var walkGoalHitDuringWalk: Bool = false
    @State private var hasTriggeredWalkGoalCelebration: Bool = false

    // UI state
    @State private var showingSummary = false
    @State private var completedWorkout: PhoneWorkoutSummary?
    @State private var showingCancelAlert = false
    @State private var showingEndConfirmation = false
    @State private var startError: String?
    @State private var activeError: WalkErrorType? = nil

    @State private var showingStartError = false

    var body: some View {
        baseView
    }

    private var baseView: some View {
        mainZStack
            .task { await startWorkout() }
            .alert("End Walk?", isPresented: $showingCancelAlert) {
                Button("Continue Walking", role: .cancel) { }
                Button("Discard", role: .destructive) { handleDiscard() }
            } message: {
                Text("Your walk will not be saved.")
            }
            .alert("Error", isPresented: $showingStartError) {
                Button("OK") { handleErrorDismiss() }
            } message: {
                Text(startError ?? "Failed to start walk")
            }
            .sheet(isPresented: $showingSummary) {
                sheetContent
            }
            .overlay { overlayContent }
            .onChange(of: showingSummary, handleSummaryDidChange)
            .onChange(of: currentDailySteps, handleStepsDidChange)
            .onChange(of: workoutManager.elapsedTime, handleTimeDidChange)
            .onChange(of: workoutManager.sessionDistance, handleDistanceDidChange)
            .onChange(of: workoutManager.hasGPSSignal, handleGPSDidChange)
            .onChange(of: startError, handleErrorDidChange)
            .onReceive(NotificationCenter.default.publisher(for: .endWalkFromLiveActivity)) { _ in
                Task { await stopWorkout() }
            }
    }

    private func handleDiscard() {
        workoutManager.cancelWorkout()
        dismiss()
    }

    private func handleErrorDismiss() {
        startError = nil
        dismiss()
    }

    @ViewBuilder
    private var sheetContent: some View {
        if let summary = completedWorkout, let workout = summary.workout {
            WorkoutSummaryView(workout: workout)
        }
    }

    @ViewBuilder
    private var overlayContent: some View {
        if showingEndConfirmation {
            EndWalkConfirmationView(
                steps: stepsThisWalk,
                durationSeconds: workoutManager.elapsedTime,
                distanceMeters: currentDistance,
                onKeepWalking: handleKeepWalking,
                onEndWalk: handleConfirmEndWalk
            )
            .transition(.opacity)
            .animation(.easeOut(duration: 0.2), value: showingEndConfirmation)
        }
    }

    private func handleSummaryDidChange(_ old: Bool, _ new: Bool) {
        if !new { dismiss() }
    }

    private func handleStepsDidChange(_ old: Int, _ new: Int) {
        checkGoalHit(currentSteps: new)
    }

    private func handleTimeDidChange(_ old: TimeInterval, _ new: TimeInterval) {
        checkWalkGoalProgress()
    }

    private func handleDistanceDidChange(_ old: Double, _ new: Double) {
        checkWalkGoalProgress()
    }

    private func handleGPSDidChange(_ old: Bool, _ new: Bool) {
        handleGPSSignalChange(new)
    }

    private func handleErrorDidChange(_ old: String?, _ new: String?) {
        showingStartError = new != nil
    }

    private var mainZStack: some View {
        ZStack {
            backgroundGradient.ignoresSafeArea()
            mainContentView
            errorBannerView
        }
    }

    private func handleKeepWalking() {
        withAnimation(.easeOut(duration: 0.2)) {
            showingEndConfirmation = false
        }
    }

    private func handleConfirmEndWalk() {
        showingEndConfirmation = false
        Task { await stopWorkout() }
    }

    private func handleGPSSignalChange(_ hasSignal: Bool) {
        withAnimation {
            if !hasSignal {
                activeError = .gpsSignalLost
            } else if activeError == .gpsSignalLost {
                activeError = nil
            }
        }
    }

    // MARK: - Background

    private var backgroundGradient: some View {
        LinearGradient(
            colors: [Color(hex: "00C7BE"), Color(hex: "34C759")],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    // MARK: - Main Content

    private var mainContentView: some View {
        VStack(spacing: 0) {
            headerSection
                .padding(.horizontal, 24)
                .padding(.top, 16)

            contextualMessageView
                .padding(.top, 12)

            if workoutManager.state == .paused {
                PausedIndicator()
                    .padding(.top, 12)
            }

            Spacer()
            progressRingSection
            Spacer()

            statsCardSection
                .padding(.horizontal, 24)

            Spacer()

            actionButtonsSection
                .padding(.horizontal, 24)
                .padding(.bottom, 40)
        }
    }

    // MARK: - Stats Card Section

    private var statsCardSection: some View {
        WalkStatsCard(
            duration: workoutManager.elapsedTime,
            distance: currentDistance,
            steps: stepsThisWalk,
            calories: currentCalories,
            configuration: statsConfiguration
        )
    }

    // MARK: - Action Buttons Section

    private var actionButtonsSection: some View {
        WalkActionButtons(
            isPaused: workoutManager.state == .paused,
            onEnd: handleEndTap,
            onPauseResume: handlePauseResumeTap
        )
    }

    private func handleEndTap() {
        if shouldShowEndConfirmation {
            showingEndConfirmation = true
        } else {
            Task { await stopWorkout() }
        }
    }

    private func handlePauseResumeTap() {
        if workoutManager.state == .paused {
            workoutManager.resumeWorkout()
        } else {
            workoutManager.pauseWorkout()
        }
    }

    // MARK: - Error Banner

    private var errorBannerView: some View {
        VStack {
            if let error = activeError {
                WalkErrorBanner(
                    errorType: error,
                    onDismiss: makeDismissHandler(for: error)
                )
                .padding(.horizontal, 24)
                .padding(.top, 80)
                .transition(.move(edge: .top).combined(with: .opacity))
            }
            Spacer()
        }
        .animation(.easeInOut(duration: 0.3), value: activeError)
    }

    // MARK: - Header Section

    private var headerSection: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Just Walk")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.white)

                GPSStatusPill(isRecording: workoutManager.isRecordingRoute)
            }

            Spacer()

            // Close/Cancel button
            Button {
                showingCancelAlert = true
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 28))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(.white.opacity(0.6))
            }
        }
    }

    // MARK: - Progress Ring Section

    private var progressRingSection: some View {
        WalkProgressRing(
            displayMode: ringDisplayMode,
            progress: walkGoalProgress,
            goalHit: isWalkGoalHit
        )
    }

    // MARK: - Computed Properties

    /// Steps taken during this walk session
    private var stepsThisWalk: Int {
        max(0, workoutManager.sessionSteps)
    }

    /// Current distance (best of session or GPS)
    private var currentDistance: Double {
        max(workoutManager.sessionDistance, workoutManager.gpsDistance)
    }

    /// Current calories (nil if zero)
    private var currentCalories: Int? {
        workoutManager.activeCalories > 0 ? Int(workoutManager.activeCalories) : nil
    }

    /// Current total daily steps (start + walk steps)
    private var currentDailySteps: Int {
        stepsAtWalkStart + stepsThisWalk
    }

    /// Steps remaining to hit daily goal
    private var stepsToGoal: Int {
        max(0, dailyGoalAtStart - currentDailySteps)
    }

    /// Ring progress (0.0 to 1.0) - for daily goal
    private var ringProgress: Double {
        guard dailyGoalAtStart > 0 else { return 0 }
        return min(1.0, Double(currentDailySteps) / Double(dailyGoalAtStart))
    }

    // MARK: - Contextual Message

    private var contextualMessage: String {
        if isWalkGoalHit {
            return "Goal reached! Keep going?"
        }
        switch walkGoal.type {
        case .none:
            return "Go at your own pace"
        case .time:
            return "\(Int(walkGoal.target)) minute walk"
        case .distance:
            let miles = walkGoal.target
            if miles == floor(miles) {
                return "\(Int(miles)) mile walk"
            }
            return String(format: "%.1f mile walk", miles)
        case .steps:
            return "\(Int(walkGoal.target).formatted()) step walk"
        }
    }

    private var contextualMessageView: some View {
        Text(contextualMessage)
            .font(.system(size: 15, weight: .medium))
            .foregroundStyle(.white.opacity(0.9))
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(.white.opacity(0.15))
            .clipShape(Capsule())
    }

    // MARK: - Ring Display Mode

    private var ringDisplayMode: RingDisplayMode {
        if isWalkGoalHit {
            return .goalReached
        }
        switch walkGoal.type {
        case .none:
            return .stepsAccumulated(steps: stepsThisWalk, secondaryText: "toward daily goal")
        case .time:
            let remaining = max(0, walkGoal.target * 60 - workoutManager.elapsedTime)
            return .countdown(timeRemaining: remaining)
        case .distance:
            let targetMeters = WalkGoalPresets.milesToMeters(walkGoal.target)
            return .distanceRemaining(meters: max(0, targetMeters - currentDistance))
        case .steps:
            return .stepsRemaining(count: max(0, Int(walkGoal.target) - stepsThisWalk))
        }
    }

    // MARK: - Stats Configuration

    private var statsConfiguration: WalkStatsConfiguration {
        switch walkGoal.type {
        case .none:     return .durationDistance
        case .time:     return .stepsDistance
        case .distance: return .stepsDuration
        case .steps:    return .durationDistance
        }
    }

    // MARK: - Walk Goal Computed Properties

    /// Progress toward walk goal (0.0 to 1.0)
    private var walkGoalProgress: Double {
        switch walkGoal.type {
        case .none:
            return ringProgress  // Fall back to daily step goal
        case .time:
            let targetSeconds = walkGoal.target * 60
            guard targetSeconds > 0 else { return 0 }
            return min(1.0, workoutManager.elapsedTime / targetSeconds)
        case .distance:
            let targetMeters = WalkGoalPresets.milesToMeters(walkGoal.target)
            guard targetMeters > 0 else { return 0 }
            return min(1.0, currentDistance / targetMeters)
        case .steps:
            guard walkGoal.target > 0 else { return 0 }
            return min(1.0, Double(stepsThisWalk) / walkGoal.target)
        }
    }

    /// Whether the current walk goal has been achieved
    private var isWalkGoalHit: Bool {
        switch walkGoal.type {
        case .none:
            return goalHitDuringWalk
        case .time, .distance, .steps:
            return walkGoalProgress >= 1.0
        }
    }

    // MARK: - Helpers

    private func makeDismissHandler(for error: WalkErrorType) -> (() -> Void)? {
        if error == .gpsSignalLost {
            return nil
        } else {
            return { activeError = nil }
        }
    }

    // MARK: - End Confirmation

    private var shouldShowEndConfirmation: Bool {
        let durationMet = workoutManager.elapsedTime >= 300  // 5 minutes
        let stepsMet = stepsThisWalk >= 500
        let distanceMet = currentDistance >= 402.336  // 0.25 mi
        return durationMet || stepsMet || distanceMet
    }

    // MARK: - Goal Tracking

    private func checkGoalHit(currentSteps: Int) {
        // Check if we just hit the daily goal during this walk
        if currentSteps >= dailyGoalAtStart && !hasTriggeredGoalCelebration {
            hasTriggeredGoalCelebration = true
            goalHitDuringWalk = true
        }

        // Check walk-specific goal (time and distance checked elsewhere via progress)
        if walkGoal.type == .steps {
            if stepsThisWalk >= Int(walkGoal.target) && !hasTriggeredWalkGoalCelebration {
                hasTriggeredWalkGoalCelebration = true
                walkGoalHitDuringWalk = true
                HapticService.shared.playSuccess()
            }
        }
    }

    private func checkWalkGoalProgress() {
        // Check time and distance goals based on progress
        guard !hasTriggeredWalkGoalCelebration else { return }

        switch walkGoal.type {
        case .none:
            break  // Daily goal checked via checkGoalHit
        case .time, .distance:
            if walkGoalProgress >= 1.0 {
                hasTriggeredWalkGoalCelebration = true
                walkGoalHitDuringWalk = true
                HapticService.shared.playSuccess()
            }
        case .steps:
            break  // Step goal checked via checkGoalHit
        }
    }

    // MARK: - Actions

    private func startWorkout() async {
        // Get real-time today's steps from CMPedometer (instant, no HealthKit delay)
        if let pedometerSteps = await stepTrackingService.queryTodayStepsFromPedometer() {
            stepsAtWalkStart = pedometerSteps
        } else {
            // Fall back to HealthKit if CMPedometer unavailable
            stepsAtWalkStart = stepRepository.todaySteps
        }

        dailyGoalAtStart = stepRepository.stepGoal
        goalHitDuringWalk = stepsAtWalkStart >= dailyGoalAtStart
        hasTriggeredGoalCelebration = stepsAtWalkStart >= dailyGoalAtStart

        // Cancel any stale workout state first (e.g., previous session didn't clean up properly)
        if workoutManager.state != .idle {
            workoutManager.cancelWorkout()
        }

        do {
            try await workoutManager.startWorkout()
        } catch {
            startError = error.localizedDescription
        }
    }

    private func stopWorkout() async {
        HapticService.shared.playIncrementMilestone()

        do {
            let summary = try await workoutManager.stopWorkout()
            completedWorkout = summary
            showingSummary = true
        } catch {
            print("Failed to stop workout: \(error)")
            dismiss()
        }
    }
}

// MARK: - Preview

#Preview("Active") {
    PhoneWorkoutSessionView()
}

#Preview("Goal Hit") {
    PhoneWorkoutSessionView()
}

// MARK: - Notification Name

extension Notification.Name {
    /// Posted when user taps "End Walk" on the Live Activity
    static let endWalkFromLiveActivity = Notification.Name("endWalkFromLiveActivity")
}
