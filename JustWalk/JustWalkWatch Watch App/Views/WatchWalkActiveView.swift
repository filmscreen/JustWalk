//
//  WatchWalkActiveView.swift
//  JustWalkWatch Watch App
//
//  Active walk screen with timer, stats, phase display, and controls
//

import SwiftUI

struct WatchWalkActiveView: View {
    @Bindable var session: WatchWalkSessionManager
    let onEnd: () -> Void

    @State private var showEndConfirmation = false
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.isLuminanceReduced) private var isLuminanceReduced

    // MARK: - Formatted Values

    private var formattedTime: String {
        let totalSeconds: Int
        if session.isIntervalMode && !session.intervalCompleted {
            totalSeconds = session.intervalTimeRemaining
        } else if session.isPostMealMode && !session.postMealCompleted {
            totalSeconds = session.postMealTimeRemaining
        } else {
            totalSeconds = session.elapsedSeconds
        }
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    private var timeAccessibilityLabel: String {
        let totalSeconds: Int
        if session.isIntervalMode && !session.intervalCompleted {
            totalSeconds = session.intervalTimeRemaining
            let minutes = totalSeconds / 60
            let seconds = totalSeconds % 60
            return "\(minutes) minutes \(seconds) seconds remaining"
        } else if session.isPostMealMode && !session.postMealCompleted {
            totalSeconds = session.postMealTimeRemaining
            let minutes = totalSeconds / 60
            let seconds = totalSeconds % 60
            return "\(minutes) minutes \(seconds) seconds remaining"
        } else {
            totalSeconds = session.elapsedSeconds
            let minutes = totalSeconds / 60
            let seconds = totalSeconds % 60
            return "\(minutes) minutes \(seconds) seconds elapsed"
        }
    }

    private var useMetric: Bool {
        WatchPersistenceManager.shared.loadUseMetricUnits()
    }

    private var formattedDistance: String {
        if useMetric {
            let km = session.currentDistance / 1000
            if km >= 1 {
                return String(format: "%.2f km", km)
            } else {
                return "\(Int(session.currentDistance)) m"
            }
        } else {
            let miles = session.currentDistance / 1609.344
            return String(format: "%.2f mi", miles)
        }
    }

    @State private var selectedPage = 0  // Default to timer page

    var body: some View {
        TabView(selection: $selectedPage) {
            // MARK: - Page 1: Timer & Stats
            mainTimerPage
                .containerBackground(Color.black.gradient, for: .tabView)
                .tag(0)

            // MARK: - Page 2: Controls
            controlsPage
                .containerBackground(Color.black.gradient, for: .tabView)
                .tag(1)
        }
        .tabViewStyle(PageTabViewStyle())
        .navigationBarBackButtonHidden(true)
        .confirmationDialog("End this walk?", isPresented: $showEndConfirmation) {
            Button("End Walk", role: .destructive, action: onEnd)
            Button("Cancel", role: .cancel) {}
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                session.ensureTimerRunning()
            }
        }
    }

    // MARK: - Main Timer Page

    private var mainTimerPage: some View {
        VStack(spacing: 8) {
            if session.isIntervalMode && session.intervalTransferData != nil {
                // INTERVAL MODE LAYOUT - Phase-focused design
                intervalPhaseView
            } else if session.isIntervalMode {
                // Simple interval mode (no phases)
                intervalHeader
            } else {
                // Standard/Post-Meal walk - elapsed time
                standardTimeDisplay
            }

            Spacer()

            // Inline stats at bottom of timer page
            if session.isIntervalMode {
                intervalInlineStats
            } else {
                standardInlineStats
            }
        }
        .padding(.horizontal)
        .padding(.top, 4)
        .opacity(isLuminanceReduced ? 0.6 : 1.0)
    }

    // MARK: - Standard Inline Stats (steps · distance + ♥ BPM · cal)

    private var standardInlineStats: some View {
        VStack(spacing: 4) {
            HStack(spacing: 6) {
                Text("\(session.currentSteps)")
                    .font(.headline)
                Text("steps")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text("·")
                    .foregroundStyle(.secondary)
                Text(formattedDistance)
                    .font(.headline)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("\(session.currentSteps) steps, \(formattedDistance)")

            HStack(spacing: 6) {
                Image(systemName: "heart.fill")
                    .font(.caption2)
                    .foregroundStyle(.red)
                Text(session.heartRate > 0 ? "\(session.heartRate)" : "—")
                    .font(.headline)
                if session.heartRate > 0 {
                    Text("BPM")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                Text("·")
                    .foregroundStyle(.secondary)
                Text("\(Int(session.activeCalories))")
                    .font(.headline)
                Text("cal")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(session.heartRate > 0 ? "\(session.heartRate) BPM, \(Int(session.activeCalories)) calories" : "Heart rate not available, \(Int(session.activeCalories)) calories")
        }
    }

    // MARK: - Interval Inline Stats (♥ BPM · cal)

    private var intervalInlineStats: some View {
        HStack(spacing: 6) {
            Image(systemName: "heart.fill")
                .font(.caption2)
                .foregroundStyle(.red)
            Text(session.heartRate > 0 ? "\(session.heartRate)" : "—")
                .font(.headline)
            if session.heartRate > 0 {
                Text("BPM")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            Text("·")
                .foregroundStyle(.secondary)
            Text("\(Int(session.activeCalories))")
                .font(.headline)
            Text("cal")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(session.heartRate > 0 ? "\(session.heartRate) BPM" : "heart rate not available"), \(Int(session.activeCalories)) calories")
    }

    // MARK: - Interval Phase View (Optimized Layout)

    /// Primary interval display with phase name and time grouped together
    private var intervalPhaseView: some View {
        VStack(spacing: 10) {
            // PRIMARY: Current phase block - name + time together
            if let phase = session.currentPhase {
                VStack(spacing: 4) {
                    Text(phaseDisplayName(phase.type).uppercased())
                        .font(.system(.title3, design: .rounded, weight: .bold))
                        .foregroundStyle(phaseColor(phase.type))

                    Text(formatSeconds(session.secondsRemainingInPhase))
                        .font(.system(size: 44, weight: .bold, design: .monospaced))
                        .monospacedDigit()
                        .foregroundStyle(phaseColor(phase.type))
                }

                // Phase progress bar
                ProgressView(value: phaseProgress)
                    .tint(phaseColor(phase.type))
                    .padding(.horizontal, 4)
            }

            // Next phase preview
            if let next = session.nextPhase {
                HStack(spacing: 4) {
                    Text("Next:")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(phaseDisplayName(next.type))
                        .font(.caption.bold())
                        .foregroundStyle(phaseColor(next.type))
                }
            }

            // SECONDARY: Total remaining (smaller, less prominent)
            if !session.intervalCompleted {
                HStack(spacing: 4) {
                    Text("Total:")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text(formattedTime)
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
            } else {
                Label("Complete!", systemImage: "checkmark.circle.fill")
                    .font(.caption.bold())
                    .foregroundStyle(.green)
            }
        }
    }

    private var phaseProgress: Double {
        guard let phase = session.currentPhase else { return 0 }
        let elapsed = session.elapsedSeconds - phase.startOffset
        return min(1.0, Double(elapsed) / Double(phase.durationSeconds))
    }

    // MARK: - Controls Page

    private var controlsPage: some View {
        VStack(spacing: 8) {
            // Timer/phase context at top — user never loses track of time
            controlsHeader

            if !isLuminanceReduced {
                Spacer()

                // Pause/Resume
                Button {
                    if session.isPaused {
                        session.resumeWalk()
                        WatchHaptics.walkResumed()
                    } else {
                        session.pauseWalk()
                        WatchHaptics.walkPaused()
                    }
                } label: {
                    Label(
                        session.isPaused ? "Resume" : "Pause",
                        systemImage: session.isPaused ? "play.fill" : "pause.fill"
                    )
                    .font(.footnote.bold())
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(session.isPaused ? Color.green.opacity(0.3) : Color.yellow.opacity(0.3))
                    .foregroundStyle(session.isPaused ? .green : .yellow)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                .buttonStyle(.plain)

                // End Walk
                Button(role: .destructive) {
                    showEndConfirmation = true
                } label: {
                    Label(session.isEnding ? "Ending…" : "End Walk",
                          systemImage: session.isEnding ? "hourglass" : "stop.fill")
                        .font(.footnote.bold())
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(Color.red.opacity(session.isEnding ? 0.15 : 0.3))
                        .foregroundStyle(session.isEnding ? Color.secondary : Color.red)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                .buttonStyle(.plain)
                .disabled(session.isEnding)
            }
        }
        .padding(.horizontal)
        .padding(.top, 8)
        .opacity(isLuminanceReduced ? 0.6 : 1.0)
    }

    // MARK: - Controls Header (timer/phase context)

    @ViewBuilder
    private var controlsHeader: some View {
        if session.isIntervalMode, let phase = session.currentPhase, !session.intervalCompleted {
            // Interval: Phase name + phase timer
            VStack(spacing: 4) {
                Text("\(phaseDisplayName(phase.type)) · \(formatSeconds(session.secondsRemainingInPhase))")
                    .font(.system(.footnote, design: .rounded, weight: .semibold))
                    .foregroundStyle(phaseColor(phase.type))

                HStack(spacing: 6) {
                    Text("\(session.currentSteps) steps")
                    Text("·")
                        .foregroundStyle(.secondary)
                    Text(formattedDistance)
                }
                .font(.caption2)
                .foregroundStyle(.secondary)
            }
        } else {
            // Standard / Post-Meal / Completed interval: timer + stats
            VStack(spacing: 4) {
                if session.isPostMealMode && session.postMealCompleted {
                    Text("00:00")
                        .font(.system(size: 24, weight: .bold, design: .monospaced))
                        .monospacedDigit()
                        .foregroundStyle(.green)
                } else {
                    Text(formattedTime)
                        .font(.system(size: 24, weight: .bold, design: .monospaced))
                        .monospacedDigit()
                }

                HStack(spacing: 6) {
                    Text("\(session.currentSteps) steps")
                    Text("·")
                        .foregroundStyle(.secondary)
                    Text(formattedDistance)
                }
                .font(.caption2)
                .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Interval Header

    @ViewBuilder
    private var intervalHeader: some View {
        if session.intervalCompleted {
            Label("Interval Complete!", systemImage: "checkmark.circle.fill")
                .font(.caption.bold())
                .foregroundStyle(.green)

            Text("00:00")
                .font(.system(size: 40, weight: .bold, design: .monospaced))
                .monospacedDigit()
                .foregroundStyle(.green)
                .accessibilityLabel("Interval complete, zero seconds remaining")
        } else {
            Text(formattedTime)
                .font(.system(size: 40, weight: .bold, design: .monospaced))
                .monospacedDigit()
                .foregroundStyle(session.isPaused ? .yellow : brandTeal)
                .accessibilityLabel(timeAccessibilityLabel)

            // Progress bar
            ProgressView(value: session.intervalProgress)
                .tint(brandTeal)
                .padding(.horizontal, 4)
                .accessibilityLabel("Interval progress")
                .accessibilityValue("\(Int(session.intervalProgress * 100))%")
        }
    }

    // MARK: - Standard Time Display

    @ViewBuilder
    private var standardTimeDisplay: some View {
        if session.isPostMealMode && session.postMealCompleted {
            // Post-meal timer finished
            Label("Complete!", systemImage: "checkmark.circle.fill")
                .font(.caption.bold())
                .foregroundStyle(.green)

            Text("00:00")
                .font(.system(size: 40, weight: .bold, design: .monospaced))
                .monospacedDigit()
                .foregroundStyle(.green)
                .accessibilityLabel("Post-meal walk complete")
        } else {
            Text(formattedTime)
                .font(.system(size: 40, weight: .bold, design: .monospaced))
                .monospacedDigit()
                .foregroundStyle(session.isPaused ? .yellow : .primary)
                .accessibilityLabel(timeAccessibilityLabel)

            // Progress bar for post-meal countdown
            if session.isPostMealMode {
                ProgressView(value: postMealProgress)
                    .tint(brandTeal)
                    .padding(.horizontal, 4)
            }
        }
    }

    private var postMealProgress: Double {
        guard session.isPostMealMode else { return 0 }
        let total = Double(WatchWalkSessionManager.postMealDurationSeconds)
        return min(1.0, Double(session.elapsedSeconds) / total)
    }

    // MARK: - Brand Colors

    private var brandTeal: Color {
        Color(red: 0x34/255, green: 0xD3/255, blue: 0x99/255)
    }

    private var phaseWarmup: Color {
        Color(red: 0xFF/255, green: 0x8C/255, blue: 0x00/255)  // Matches JW.Color.phaseWarmup
    }

    private var phaseSlow: Color {
        Color(red: 0x40/255, green: 0x85/255, blue: 0xFF/255)  // Matches JW.Color.phaseSlow
    }

    private var phaseCooldown: Color {
        Color(red: 0x8C/255, green: 0x45/255, blue: 0xFF/255)  // Matches JW.Color.phaseCooldown
    }

    // MARK: - Phase Helpers

    private func phaseColor(_ type: String) -> Color {
        switch type {
        case "warmup": return phaseWarmup
        case "fast": return brandTeal  // Matches JW.Color.phaseFast
        case "slow": return phaseSlow
        case "cooldown": return phaseCooldown
        default: return .primary
        }
    }

    private func phaseDisplayName(_ type: String) -> String {
        switch type {
        case "warmup": return "WARM UP"
        case "fast": return "FAST"
        case "slow": return "SLOW"
        case "cooldown": return "COOL DOWN"
        default: return type.uppercased()
        }
    }

    private func formatSeconds(_ seconds: Int) -> String {
        let mins = seconds / 60
        let secs = seconds % 60
        return String(format: "%d:%02d", mins, secs)
    }
}
