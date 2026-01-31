//
//  IntervalActiveView.swift
//  JustWalk
//
//  Full-screen immersive interval walking experience
//

import SwiftUI

struct IntervalActiveView: View {
    @StateObject private var walkSession = WalkSessionManager.shared
    @StateObject private var watchConnectivity = PhoneConnectivityManager.shared
    @State private var showEndConfirmation = false
    @State private var phaseAnimationTrigger: UUID?
    @State private var previousPhaseType: IntervalPhase.PhaseType?
    @State private var isPhaseWarning = false
    @State private var justCompletedCycleIndex: Int? = nil

    // MARK: - Body

    var body: some View {
        ZStack {
            // Animated phase-colored background
            phaseBackgroundGradient
                .ignoresSafeArea()
                .animation(.easeInOut(duration: 0.8), value: currentPhase?.type)

            VStack(spacing: 0) {
                // Top: minimized stats bar
                WalkStatsBar(
                    elapsedSeconds: walkSession.elapsedSeconds,
                    steps: walkSession.currentSteps,
                    distanceMeters: walkSession.currentDistance
                )
                    .padding(.top, JW.Spacing.sm)

                Spacer()

                // Center: large phase display
                VStack(spacing: 24) {
                    // Phase icon (large)
                    Image(systemName: phaseIcon)
                        .font(.system(size: 48, weight: .medium))
                        .foregroundStyle(phaseAccentColor)
                        .contentTransition(.symbolEffect(.replace))

                    // Phase label
                    Text(phaseLabel)
                        .font(.system(size: 56, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .scaleEffect(phaseAnimationTrigger == currentPhase?.id ? 1.0 : 0.7)
                        .animation(.spring(response: 0.4, dampingFraction: 0.6), value: phaseAnimationTrigger)

                    // Countdown timer (large)
                    Text(countdownText)
                        .font(.system(size: 72, weight: .bold, design: .rounded).monospacedDigit())
                        .foregroundStyle(.white)
                        .contentTransition(.numericText())
                        .animation(.default, value: secondsRemaining)
                        .glowEffect(color: phaseAccentColor, radius: 20, isActive: isPhaseWarning)

                    // Cycle progress dots
                    if walkSession.totalCycles > 0 {
                        cycleDotsView
                    }

                    // Next phase preview
                    nextPhasePreview
                }

                Spacer()

                // Bottom: controls + overall progress
                VStack(spacing: 16) {
                    WalkProgressBar(progress: overallProgress)
                    controlButtons
                }
                .padding(.bottom, 40)
            }
        }
        .alert("End this walk?", isPresented: $showEndConfirmation) {
            Button("End", role: .destructive) {
                Task { await walkSession.endWalk() }
            }
            Button("Keep Going", role: .cancel) {}
        }
        // Phase change handler
        .onChange(of: currentPhase?.id) { oldValue, newValue in
            guard let phase = currentPhase, oldValue != newValue else { return }
            // Reset pre-warning glow
            withAnimation { isPhaseWarning = false }

            let isFastPhase = phase.type == .fast

            // iPhone haptic feedback - strong vibration pattern for phase change
            JustWalkHaptics.intervalPhaseChange()

            // Watch haptics (works even when phone screen is off)
            watchConnectivity.triggerPhaseChangeHapticOnWatch()

            // Notification with text instruction (always fires for clear guidance)
            NotificationManager.shared.sendIntervalPhaseChangeNotification(isFastPhase: isFastPhase)

            withAnimation {
                phaseAnimationTrigger = phase.id
            }
            previousPhaseType = phase.type
        }
        // Countdown warnings
        .onChange(of: secondsRemaining) { oldValue, newValue in
            guard newValue < oldValue else { return }
            // 10-second warning - sync to Watch
            if newValue == 10 {
                JustWalkHaptics.intervalCountdownWarning()
                watchConnectivity.triggerCountdownWarningOnWatch()
            }
            // 3-second visual glow warning
            if newValue <= 3, newValue > 0 {
                if !isPhaseWarning {
                    withAnimation { isPhaseWarning = true }
                }
            }
        }
        // Halfway announcement
        .onChange(of: overallProgress) { oldValue, newValue in
            if oldValue < 0.5, newValue >= 0.5 {
            }
        }
        .onAppear {
            if let phase = currentPhase {
                previousPhaseType = phase.type
                withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
                    phaseAnimationTrigger = phase.id
                }
            }
        }
    }

    // MARK: - Phase Background Gradient

    private var phaseBackgroundGradient: some View {
        let tint = phaseTintColor
        return LinearGradient(
            colors: [
                tint.opacity(0.3),
                JW.Color.backgroundPrimary,
                tint.opacity(0.15)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    private var phaseTintColor: Color {
        guard let phase = currentPhase else { return .clear }
        switch phase.type {
        case .warmup:   return JW.Color.phaseWarmup
        case .fast:     return JW.Color.phaseFast
        case .slow:     return JW.Color.phaseSlow
        case .cooldown: return JW.Color.phaseCooldown
        }
    }

    // MARK: - Cycle Dots

    private var cycleDotsView: some View {
        HStack(spacing: 8) {
            ForEach(0..<walkSession.totalCycles, id: \.self) { i in
                Circle()
                    .fill(dotColor(for: i))
                    .frame(width: 12, height: 12)
                    .scaleEffect(justCompletedCycleIndex == i ? 1.3 : 1.0)
                    .animation(.spring(response: 0.3, dampingFraction: 0.5), value: justCompletedCycleIndex)
                    .animation(.easeInOut(duration: 0.3), value: walkSession.completedCycles)
            }
        }
        .onChange(of: walkSession.completedCycles) { _, newValue in
            guard newValue > 0 else { return }
            justCompletedCycleIndex = newValue - 1
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                justCompletedCycleIndex = nil
            }
        }
    }

    private func dotColor(for index: Int) -> Color {
        if index < walkSession.completedCycles {
            return JW.Color.accent
        } else if index == walkSession.currentCycleIndex {
            return phaseAccentColor.opacity(0.7)
        } else {
            return JW.Color.backgroundTertiary
        }
    }

    // MARK: - Next Phase Preview

    @ViewBuilder
    private var nextPhasePreview: some View {
        if let next = nextPhase {
            HStack(spacing: 8) {
                Text("Up Next:")
                    .foregroundStyle(JW.Color.textSecondary)

                Image(systemName: iconName(for: next.type))
                    .foregroundStyle(phaseColor(for: next.type))

                Text(next.displayName)
                    .font(JW.Font.headline)
                    .foregroundStyle(phaseColor(for: next.type))
            }
            .font(JW.Font.subheadline)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .jwGlassEffect()
        }
    }

    // MARK: - Control Buttons

    private var controlButtons: some View {
        HStack(spacing: 20) {
            // Pause / Resume
            Button(action: {
                if walkSession.isPaused {
                    walkSession.resumeWalk()
                } else {
                    walkSession.pauseWalk()
                }
            }) {
                Image(systemName: walkSession.isPaused ? "play.fill" : "pause.fill")
                    .font(JW.Font.title2)
                    .frame(width: 60, height: 60)
            }
            .jwGlassEffect()
            .buttonPressEffect()

            // End walk
            Button(action: {
                showEndConfirmation = true
            }) {
                Text("End")
                    .font(JW.Font.headline)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 28)
                    .padding(.vertical, 16)
            }
            .jwGlassEffect(tintColor: JW.Color.danger)
            .buttonPressEffect()
        }
        .padding(.horizontal)
        .jwGlassEffect()
    }

    // MARK: - Computed Properties

    private var currentPhase: IntervalPhase? {
        walkSession.getCurrentIntervalPhase()
    }

    private var nextPhase: IntervalPhase? {
        walkSession.getNextIntervalPhase()
    }

    private var secondsRemaining: Int {
        walkSession.getSecondsRemainingInPhase()
    }

    private var phaseLabel: String {
        guard let phase = currentPhase else { return "" }
        switch phase.type {
        case .warmup:   return "WARM UP"
        case .fast:     return "FAST"
        case .slow:     return "SLOW"
        case .cooldown: return "COOL DOWN"
        }
    }

    private var phaseIcon: String {
        guard let phase = currentPhase else { return "figure.walk" }
        return iconName(for: phase.type)
    }

    private var countdownText: String {
        formatDuration(secondsRemaining)
    }

    private var phaseAccentColor: Color {
        guard let phase = currentPhase else { return JW.Color.accent }
        return phaseColor(for: phase.type)
    }

    private var overallProgress: Double {
        let totalDuration: Int
        if let program = walkSession.currentIntervalProgram {
            totalDuration = program.duration * 60
        } else if let custom = walkSession.currentCustomInterval {
            totalDuration = custom.totalMinutes * 60
        } else {
            return 0
        }
        guard totalDuration > 0 else { return 0 }
        return Double(walkSession.elapsedSeconds) / Double(totalDuration)
    }

    // MARK: - Helpers

    private func phaseColor(for type: IntervalPhase.PhaseType) -> Color {
        switch type {
        case .warmup:   return JW.Color.phaseWarmup
        case .fast:     return JW.Color.phaseFast
        case .slow:     return JW.Color.phaseSlow
        case .cooldown: return JW.Color.phaseCooldown
        }
    }

    private func iconName(for type: IntervalPhase.PhaseType) -> String {
        switch type {
        case .warmup:   return "flame"
        case .fast:     return "hare.fill"
        case .slow:     return "tortoise.fill"
        case .cooldown: return "snowflake"
        }
    }

    private func formatDuration(_ seconds: Int) -> String {
        let mins = seconds / 60
        let secs = seconds % 60
        return String(format: "%d:%02d", mins, secs)
    }

}

#Preview {
    IntervalActiveView()
}
