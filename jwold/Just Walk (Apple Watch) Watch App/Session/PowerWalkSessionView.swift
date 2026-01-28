//
//  PowerWalkSessionView.swift
//  Just Walk Watch App
//
//  During-workout screen for Power Walk (interval) mode.
//  Phase-colored backgrounds, countdown timer, progress dots.
//

import SwiftUI
import WatchKit

struct PowerWalkSessionView: View {
    @ObservedObject private var sessionManager = WatchSessionManager.shared
    @ObservedObject private var healthManager = WatchHealthManager.shared
    @Environment(\.isLuminanceReduced) private var isLuminanceReduced

    @State private var showEndConfirmation = false
    @State private var showTransitionCountdown = false
    @State private var countdownNumber: Int? = nil
    @State private var lastCountdownTrigger: Int = 0

    var body: some View {
        // TimelineView for efficient Always-On updates
        TimelineView(.periodic(from: Date(), by: isLuminanceReduced ? 10 : 1)) { _ in
            ZStack {
                // Phase-colored background
                phaseBackground
                    .ignoresSafeArea()

                if isLuminanceReduced {
                    alwaysOnView
                } else if sessionManager.isPaused {
                    PowerWalkPausedView()
                } else {
                    activeWorkoutView
                }

                // Transition countdown overlay (only when not always-on)
                if showTransitionCountdown && !isLuminanceReduced {
                    PhaseTransitionOverlay(
                        countdownNumber: countdownNumber,
                        nextPhase: sessionManager.nextPhase
                    )
                }
            }
        }
        .onReceive(sessionManager.$timeRemaining) { remaining in
            handleTimeUpdate(remaining)
        }
    }

    // MARK: - Phase Background

    private var phaseBackground: some View {
        let color = phaseBackgroundColor
        return Rectangle()
            .fill(
                LinearGradient(
                    colors: [color, color.opacity(0.7)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .opacity(isLuminanceReduced ? 0.3 : 1.0)
    }

    private var phaseBackgroundColor: Color {
        switch sessionManager.currentPhase {
        case .brisk:
            return Color.orange
        case .slow:
            return Color(hex: "00C7BE") // Teal
        case .warmup:
            return Color.orange.opacity(0.7)
        case .cooldown:
            return Color.purple.opacity(0.8)
        default:
            return Color.gray.opacity(0.5)
        }
    }

    // MARK: - Active Workout View

    private var activeWorkoutView: some View {
        VStack(spacing: 8) {
            Spacer()

            // Phase name (secondary)
            Text(phaseDisplayName)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(.white.opacity(0.8))

            // Countdown timer (primary - hero metric)
            countdownTimerDisplay

            // Progress dots
            if !isLuminanceReduced {
                PhaseProgressDots(
                    currentInterval: sessionManager.currentInterval,
                    totalIntervals: sessionManager.totalIntervals,
                    currentPhase: sessionManager.currentPhase
                )
            }

            // Stats row (HR, Cal, Time)
            statsRow

            Spacer()

            // Controls
            controlButtons
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .confirmationDialog("End workout early?", isPresented: $showEndConfirmation) {
            Button("End Workout", role: .destructive) {
                sessionManager.stopSession()
            }
            Button("Keep Going", role: .cancel) {}
        }
    }

    // MARK: - Phase Display Name

    private var phaseDisplayName: String {
        switch sessionManager.currentPhase {
        case .brisk: return "BRISK"
        case .slow: return "EASY"
        case .warmup: return "WARMUP"
        case .cooldown: return "COOLDOWN"
        default: return sessionManager.currentPhase.title.uppercased()
        }
    }

    // MARK: - Countdown Timer

    private var countdownTimerDisplay: some View {
        Group {
            if let endTime = sessionManager.phaseEndTime {
                Text(timerInterval: Date()...endTime, countsDown: true)
                    .font(.system(size: isLuminanceReduced ? 20 : 48, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .monospacedDigit()
            } else {
                Text(sessionManager.formattedTime)
                    .font(.system(size: isLuminanceReduced ? 20 : 48, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .monospacedDigit()
            }
        }
    }

    // MARK: - Stats Row

    private var statsRow: some View {
        HStack(spacing: 0) {
            // Heart Rate
            statItem(
                icon: "heart.fill",
                value: sessionManager.currentHeartRate > 0
                    ? "\(Int(sessionManager.currentHeartRate))"
                    : "--",
                color: .red
            )

            Divider()
                .frame(height: 20)
                .padding(.horizontal, 6)

            // Calories
            statItem(
                icon: "flame.fill",
                value: sessionManager.activeCalories > 0
                    ? "\(Int(sessionManager.activeCalories))"
                    : "--",
                color: .orange
            )

            Divider()
                .frame(height: 20)
                .padding(.horizontal, 6)

            // Duration
            if let startTime = sessionManager.sessionStartTime {
                HStack(spacing: 3) {
                    Image(systemName: "clock")
                        .font(.system(size: 11))
                        .foregroundStyle(.cyan)
                    Text(startTime, style: .timer)
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white)
                        .monospacedDigit()
                }
            }
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 8)
        .background(Color.white.opacity(0.15))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private func statItem(icon: String, value: String, color: Color) -> some View {
        HStack(spacing: 3) {
            Image(systemName: icon)
                .font(.system(size: 11))
                .foregroundStyle(color)
            Text(value)
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundStyle(.white)
                .monospacedDigit()
        }
    }

    // MARK: - Control Buttons

    private var controlButtons: some View {
        HStack(spacing: 24) {
            // Pause Button
            Button {
                WKInterfaceDevice.current().play(.click)
                sessionManager.pauseSession()
            } label: {
                Image(systemName: "pause.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 48, height: 48)
                    .background(Color.white.opacity(0.25))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)

            // End Button
            Button {
                WKInterfaceDevice.current().play(.click)
                showEndConfirmation = true
            } label: {
                Text("End")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 48, height: 48)
                    .background(Color.red.opacity(0.7))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
        }
        .opacity(isLuminanceReduced ? 0.4 : 1.0)
    }

    // MARK: - Time Update Handler

    private func handleTimeUpdate(_ remaining: TimeInterval) {
        // Skip if paused
        guard !sessionManager.isPaused else { return }

        // Phase halfway haptic (single tap at midpoint)
        let halfwayPoint = sessionManager.currentPhaseDuration / 2
        if halfwayPoint > 10 && remaining <= halfwayPoint && remaining > halfwayPoint - 1 {
            sessionManager.playPhaseHalfwayHaptic()
        }

        // Pre-warning at 10 seconds
        if remaining <= 10 && remaining > 9 {
            sessionManager.playPreWarningHaptic()
        }

        // Countdown overlay at 3 seconds
        let currentSecond = Int(ceil(remaining))

        if remaining <= 3 && remaining > 0 {
            // Show countdown overlay
            if !showTransitionCountdown {
                withAnimation(.easeInOut(duration: 0.2)) {
                    showTransitionCountdown = true
                }
            }

            // Update countdown number and play haptic on each new second
            if currentSecond != lastCountdownTrigger && currentSecond > 0 {
                countdownNumber = currentSecond
                lastCountdownTrigger = currentSecond
                WKInterfaceDevice.current().play(.click)
            }
        } else {
            // Hide countdown overlay when not in countdown range
            if showTransitionCountdown {
                withAnimation(.easeInOut(duration: 0.2)) {
                    showTransitionCountdown = false
                    countdownNumber = nil
                }
            }

            // Reset countdown trigger when out of countdown range
            if remaining > 3 {
                lastCountdownTrigger = 0
            }
        }
    }

    // MARK: - Always-On Display View

    /// Simplified view for Always-On Display (wrist down)
    /// Shows only phase + time to save battery
    /// Updates every 10 seconds
    private var alwaysOnView: some View {
        VStack(spacing: 12) {
            Spacer()

            // Phase name (dimmed)
            Text(phaseDisplayName)
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundStyle(.white.opacity(0.6))

            // Countdown timer (dimmed)
            if let endTime = sessionManager.phaseEndTime {
                Text(timerInterval: Date()...endTime, countsDown: true)
                    .font(.system(size: 20, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.4))
                    .monospacedDigit()
            }

            Spacer()
        }
    }
}

// MARK: - Preview

#Preview("Active") {
    PowerWalkSessionView()
}

#Preview("Always-On") {
    PowerWalkSessionView()
        .environment(\.isLuminanceReduced, true)
}
