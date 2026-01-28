//
//  WalkActionButtons.swift
//  Just Walk
//
//  Action buttons for the during-walk screen.
//  End (secondary) and Pause/Resume (primary) buttons.
//

import SwiftUI

struct WalkActionButtons: View {
    let isPaused: Bool
    let onEnd: () -> Void
    let onPauseResume: () -> Void

    // Button styling constants
    private let buttonHeight: CGFloat = 50
    private let buttonCornerRadius: CGFloat = 12
    private let buttonSpacing: CGFloat = 12

    var body: some View {
        HStack(spacing: buttonSpacing) {
            // End button (secondary, left)
            endButton

            // Pause/Resume button (primary, right)
            pauseResumeButton
        }
    }

    // MARK: - End Button

    private var endButton: some View {
        Button(action: {
            HapticService.shared.playIncrementMilestone()
            onEnd()
        }) {
            HStack(spacing: 8) {
                Image(systemName: "stop.fill")
                    .font(.system(size: 16, weight: .semibold))
                Text("End")
                    .font(.system(size: 17, weight: .semibold))
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(height: buttonHeight)
            .background(Color(hex: "FF3B30"))  // iOS red
            .clipShape(RoundedRectangle(cornerRadius: buttonCornerRadius))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Pause/Resume Button

    private var pauseResumeButton: some View {
        Button(action: {
            HapticService.shared.playSelection()
            onPauseResume()
        }) {
            HStack(spacing: 8) {
                Image(systemName: isPaused ? "play.fill" : "pause.fill")
                    .font(.system(size: 16, weight: .semibold))
                Text(isPaused ? "Resume" : "Pause")
                    .font(.system(size: 17, weight: .semibold))
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(height: buttonHeight)
            .background(isPaused ? Color(hex: "00C7BE") : Color(hex: "3A3A3C"))  // Teal or dark gray
            .clipShape(RoundedRectangle(cornerRadius: buttonCornerRadius))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Paused Indicator

struct PausedIndicator: View {
    @State private var isAnimating = false

    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(.white)
                .frame(width: 8, height: 8)
                .opacity(isAnimating ? 0.4 : 1.0)
                .animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true), value: isAnimating)

            Text("PAUSED")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(.white)
                .tracking(1.5)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(.white.opacity(0.2))
        .clipShape(Capsule())
        .onAppear {
            isAnimating = true
        }
    }
}

// MARK: - Preview

#Preview("Active") {
    ZStack {
        LinearGradient(
            colors: [Color(hex: "00C7BE"), Color(hex: "34C759")],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()

        VStack {
            Spacer()
            WalkActionButtons(
                isPaused: false,
                onEnd: {},
                onPauseResume: {}
            )
            .padding(.horizontal, 24)
            .padding(.bottom, 40)
        }
    }
}

#Preview("Paused") {
    ZStack {
        LinearGradient(
            colors: [Color(hex: "00C7BE"), Color(hex: "34C759")],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()

        VStack {
            PausedIndicator()
            Spacer()
            WalkActionButtons(
                isPaused: true,
                onEnd: {},
                onPauseResume: {}
            )
            .padding(.horizontal, 24)
            .padding(.bottom, 40)
        }
    }
}
