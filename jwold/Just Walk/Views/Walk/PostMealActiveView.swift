//
//  PostMealActiveView.swift
//  Just Walk
//
//  Active walk screen for the 10-minute Post-Meal Walk.
//  Shows a countdown timer as the hero element, stats bar,
//  progress bar, and control buttons.
//

import SwiftUI

struct PostMealActiveView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var workoutManager = PhoneWorkoutManager.shared

    /// Total walk duration in seconds (10 minutes)
    let totalDurationSeconds: Int = 600

    // Timer state
    @State private var secondsRemaining: Int = 600
    @State private var timerActive = true
    @State private var timer: Timer?
    @State private var walkStartTime: Date?

    // UI state
    @State private var showingEndConfirmation = false
    @State private var showingSummary = false
    @State private var completedWorkout: PhoneWorkoutSummary?
    @State private var startError: String?
    @State private var showingStartError = false
    @State private var halfwayChimePlayed = false

    // Post-meal green
    private let accentColor = Color(hex: "34C759")

    var body: some View {
        ZStack {
            // Dark, calm background
            LinearGradient(
                colors: [Color(hex: "1A2E1A"), Color(hex: "0F1F0F")],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            // Main content
            VStack(spacing: 0) {
                // Header
                headerSection
                    .padding(.horizontal, 24)
                    .padding(.top, 16)

                // Paused indicator
                if workoutManager.state == .paused {
                    PausedIndicator()
                        .padding(.top, 12)
                }

                Spacer()

                // Hero countdown timer
                countdownSection

                Spacer()

                // Progress bar
                progressBar
                    .padding(.horizontal, 24)

                // Encouragement text
                Text(encouragementText)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(.white.opacity(0.7))
                    .padding(.top, JWDesign.Spacing.lg)

                Spacer()

                // Stats row
                statsRow
                    .padding(.horizontal, 24)

                // Controls
                controlButtons
                    .padding(.horizontal, 24)
                    .padding(.top, JWDesign.Spacing.xl)
                    .padding(.bottom, 40)
            }

            // End early confirmation overlay
            if showingEndConfirmation {
                postMealEndConfirmation
                    .transition(.opacity)
                    .animation(.easeOut(duration: 0.2), value: showingEndConfirmation)
            }
        }
        .task { await startSession() }
        .alert("Error", isPresented: $showingStartError) {
            Button("OK") { dismiss() }
        } message: {
            Text(startError ?? "Failed to start walk")
        }
        .sheet(isPresented: $showingSummary) {
            if let summary = completedWorkout, let workout = summary.workout {
                WorkoutSummaryView(workout: workout, walkMode: .postMeal)
            }
        }
        .onChange(of: showingSummary) { _, isShowing in
            if !isShowing { dismiss() }
        }
        .onDisappear {
            timer?.invalidate()
            timer = nil
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Post-Meal Walk")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.white)

                GPSStatusPill(isRecording: workoutManager.isRecordingRoute)
            }

            Spacer()
        }
    }

    // MARK: - Countdown Timer (Hero)

    private var countdownSection: some View {
        VStack(spacing: 8) {
            Text(formattedCountdown)
                .font(.system(size: 72, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .monospacedDigit()
                .contentTransition(.numericText())
                .animation(.easeInOut(duration: 0.15), value: secondsRemaining)

            Text("remaining")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(.white.opacity(0.5))
        }
    }

    // MARK: - Progress Bar

    private var progressBar: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                // Track
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.white.opacity(0.15))

                // Fill
                RoundedRectangle(cornerRadius: 4)
                    .fill(accentColor)
                    .frame(width: geometry.size.width * progress)
                    .animation(.easeInOut(duration: 0.3), value: progress)
            }
        }
        .frame(height: 6)
    }

    // MARK: - Stats Row

    private var statsRow: some View {
        WalkStatsCard(
            duration: workoutManager.elapsedTime,
            distance: currentDistance,
            steps: workoutManager.sessionSteps,
            configuration: .init(showDuration: true, showDistance: true, showSteps: true)
        )
    }

    // MARK: - Control Buttons

    private var controlButtons: some View {
        HStack(spacing: 12) {
            // End button
            Button {
                if shouldShowEndConfirmation {
                    showingEndConfirmation = true
                } else {
                    Task { await endWalk() }
                }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "stop.fill")
                        .font(.system(size: 16, weight: .semibold))
                    Text("End")
                        .font(.system(size: 17, weight: .semibold))
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(Color(hex: "FF3B30"))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .buttonStyle(.plain)

            // Pause/Resume button
            Button {
                togglePause()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: workoutManager.state == .paused ? "play.fill" : "pause.fill")
                        .font(.system(size: 16, weight: .semibold))
                    Text(workoutManager.state == .paused ? "Resume" : "Pause")
                        .font(.system(size: 17, weight: .semibold))
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(workoutManager.state == .paused ? accentColor : Color(hex: "3A3A3C"))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - End Early Confirmation

    private var postMealEndConfirmation: some View {
        ZStack {
            Color.black.opacity(0.4)
                .ignoresSafeArea()
                .onTapGesture {
                    withAnimation(.easeOut(duration: 0.2)) {
                        showingEndConfirmation = false
                    }
                }

            VStack(spacing: 24) {
                Text("End this walk?")
                    .font(.system(size: 22, weight: .bold))

                Text("Your progress still counts.")
                    .font(.system(size: 15))
                    .foregroundStyle(.secondary)

                VStack(spacing: 12) {
                    // Keep Going (primary)
                    Button {
                        HapticService.shared.playSelection()
                        withAnimation(.easeOut(duration: 0.2)) {
                            showingEndConfirmation = false
                        }
                    } label: {
                        Text("Keep Going")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(accentColor)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }

                    // End Walk (secondary)
                    Button {
                        HapticService.shared.playIncrementMilestone()
                        showingEndConfirmation = false
                        Task { await endWalk() }
                    } label: {
                        Text("End Walk")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(Color(hex: "FF3B30"))
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color(hex: "FF3B30"), lineWidth: 2)
                            )
                    }
                }
            }
            .padding(24)
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .shadow(color: .black.opacity(0.2), radius: 20, y: 10)
            .padding(.horizontal, 32)
        }
    }

    // MARK: - Computed Properties

    private var formattedCountdown: String {
        let minutes = secondsRemaining / 60
        let seconds = secondsRemaining % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    private var progress: Double {
        let elapsed = totalDurationSeconds - secondsRemaining
        guard totalDurationSeconds > 0 else { return 0 }
        return min(1.0, Double(elapsed) / Double(totalDurationSeconds))
    }

    private var currentDistance: Double {
        max(workoutManager.sessionDistance, workoutManager.gpsDistance)
    }

    private var encouragementText: String {
        if workoutManager.state == .paused {
            return "Paused — tap Resume to continue"
        }
        if secondsRemaining <= 0 {
            return "Walk complete!"
        }
        if secondsRemaining <= 60 {
            return "Almost there!"
        }
        if secondsRemaining <= 300 {
            return "Halfway there. Keep it up."
        }
        return "Just keep walking."
    }

    private var shouldShowEndConfirmation: Bool {
        // Show confirmation if they've been walking more than 1 minute
        workoutManager.elapsedTime >= 60
    }

    // MARK: - Actions

    private func startSession() async {
        // Cancel any stale state
        if workoutManager.state != .idle {
            workoutManager.cancelWorkout()
        }

        do {
            try await workoutManager.startWorkout()
            walkStartTime = Date()
            startTimer()
        } catch {
            startError = error.localizedDescription
            showingStartError = true
        }
    }

    private func startTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            Task { @MainActor in
                guard timerActive else { return }

                if secondsRemaining > 0 {
                    secondsRemaining -= 1

                    // Halfway chime at 5:00
                    if secondsRemaining == 300 && !halfwayChimePlayed {
                        halfwayChimePlayed = true
                        HapticService.shared.playSelection()
                    }
                }

                // Auto-complete at 0:00
                if secondsRemaining <= 0 {
                    timer?.invalidate()
                    timer = nil
                    HapticService.shared.playSuccess()
                    await endWalk()
                }
            }
        }
    }

    private func togglePause() {
        HapticService.shared.playSelection()
        if workoutManager.state == .paused {
            workoutManager.resumeWorkout()
            timerActive = true
        } else {
            workoutManager.pauseWorkout()
            timerActive = false
        }
    }

    private func endWalk() async {
        timer?.invalidate()
        timer = nil

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

#Preview {
    PostMealActiveView()
}
