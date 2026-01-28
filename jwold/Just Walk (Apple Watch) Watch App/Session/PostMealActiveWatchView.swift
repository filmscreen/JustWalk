//
//  PostMealActiveWatchView.swift
//  Just Walk Watch App
//
//  Active walk screen for the 10-minute Post-Meal Walk.
//  Shows a large countdown timer as the hero element, progress bar,
//  and pause/end controls. Auto-completes at 0:00 with haptic.
//  Supports Always-On Display.
//

import SwiftUI
import WatchKit

struct PostMealActiveWatchView: View {
    @ObservedObject private var sessionManager = WatchSessionManager.shared
    @Environment(\.isLuminanceReduced) private var isLuminanceReduced

    @State private var showEndConfirmation = false

    var body: some View {
        TimelineView(.periodic(from: Date(), by: isLuminanceReduced ? 10 : 0.5)) { _ in
            if isLuminanceReduced {
                alwaysOnView
            } else if sessionManager.isPaused {
                pausedView
            } else {
                activeView
            }
        }
    }

    // MARK: - Active View

    private var activeView: some View {
        VStack(spacing: 8) {
            Spacer()

            // Time remaining (HUGE)
            Text(formattedTimeRemaining)
                .font(.system(size: 48, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .monospacedDigit()
                .contentTransition(.numericText())

            Text("remaining")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.secondary)

            // Progress bar
            progressBar
                .padding(.horizontal, 12)
                .padding(.top, 4)

            // Steps count (small)
            HStack(spacing: 4) {
                Image(systemName: "shoeprints.fill")
                    .font(.system(size: 11))
                    .foregroundStyle(.orange)
                Text("\(sessionManager.sessionSteps)")
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .monospacedDigit()
            }
            .foregroundStyle(.white)
            .padding(.top, 4)

            Spacer()

            // Controls
            controlButtons
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .confirmationDialog("End walk?", isPresented: $showEndConfirmation) {
            Button("End Walk", role: .destructive) {
                sessionManager.stopSession()
            }
            Button("Keep Walking", role: .cancel) {}
        }
    }

    // MARK: - Paused View

    private var pausedView: some View {
        VStack(spacing: 12) {
            Spacer()

            Image(systemName: "pause.circle.fill")
                .font(.system(size: 40))
                .foregroundStyle(.orange)

            Text("Paused")
                .font(.system(size: 20, weight: .bold, design: .rounded))

            Text(formattedTimeRemaining)
                .font(.system(size: 28, weight: .semibold, design: .rounded))
                .foregroundStyle(.secondary)
                .monospacedDigit()

            Spacer()

            HStack(spacing: 12) {
                // Resume
                Button {
                    WKInterfaceDevice.current().play(.click)
                    sessionManager.resumeSession()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "play.fill")
                            .font(.system(size: 14, weight: .semibold))
                        Text("Resume")
                            .font(.system(size: 14, weight: .semibold))
                    }
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.orange)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                .buttonStyle(.plain)

                // End
                Button {
                    WKInterfaceDevice.current().play(.click)
                    sessionManager.stopSession()
                } label: {
                    Text("End")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 56)
                        .padding(.vertical, 12)
                        .background(Color.red.opacity(0.8))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    // MARK: - Always-On View

    private var alwaysOnView: some View {
        VStack(spacing: 8) {
            Spacer()

            Text(formattedTimeRemaining)
                .font(.system(size: 48, weight: .bold, design: .rounded))
                .foregroundStyle(.white.opacity(0.6))
                .monospacedDigit()

            Text("remaining")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.white.opacity(0.4))

            Spacer()
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
                    .fill(Color.orange)
                    .frame(width: geometry.size.width * sessionManager.timerProgress)
            }
        }
        .frame(height: 6)
    }

    // MARK: - Control Buttons

    private var controlButtons: some View {
        HStack(spacing: 8) {
            // Pause
            Button {
                WKInterfaceDevice.current().play(.click)
                sessionManager.pauseSession()
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "pause.fill")
                        .font(.system(size: 14, weight: .semibold))
                    Text("Pause")
                        .font(.system(size: 14, weight: .semibold))
                }
                .foregroundStyle(.black)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(Color.yellow)
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            .buttonStyle(.plain)

            // End
            Button {
                WKInterfaceDevice.current().play(.click)
                handleEndTap()
            } label: {
                Text("End")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 56)
                    .padding(.vertical, 12)
                    .background(Color.red.opacity(0.8))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Helpers

    private var formattedTimeRemaining: String {
        let total = Int(sessionManager.timeRemaining)
        let minutes = total / 60
        let seconds = total % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    private func handleEndTap() {
        // Show confirmation if walked more than 1 minute
        if sessionManager.sessionStartTime.map({ Date().timeIntervalSince($0) >= 60 }) ?? false {
            showEndConfirmation = true
        } else {
            sessionManager.stopSession()
        }
    }
}

// MARK: - Preview

#Preview {
    PostMealActiveWatchView()
}
