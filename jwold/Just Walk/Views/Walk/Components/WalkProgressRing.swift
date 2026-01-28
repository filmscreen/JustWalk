//
//  WalkProgressRing.swift
//  Just Walk
//
//  Progress ring showing goal progress during a walk.
//  Content adapts based on the selected walk goal type.
//

import SwiftUI

// MARK: - Ring Display Mode

enum RingDisplayMode {
    case stepsAccumulated(steps: Int, secondaryText: String)
    case countdown(timeRemaining: TimeInterval)
    case distanceRemaining(meters: Double)
    case stepsRemaining(count: Int)
    case goalReached
}

// MARK: - Walk Progress Ring

struct WalkProgressRing: View {
    let displayMode: RingDisplayMode
    let progress: Double  // 0.0 to 1.0
    let goalHit: Bool

    // Ring configuration
    private let ringSize: CGFloat = 240
    private let ringWidth: CGFloat = 16

    // Animation state
    @State private var animatedProgress: Double = 0
    @State private var showCelebration: Bool = false

    var body: some View {
        ZStack {
            // Track ring (white, low opacity)
            Circle()
                .stroke(
                    Color.white.opacity(0.2),
                    style: StrokeStyle(lineWidth: ringWidth, lineCap: .round)
                )
                .frame(width: ringSize, height: ringSize)

            // Progress ring (white/light teal fill)
            Circle()
                .trim(from: 0, to: animatedProgress)
                .stroke(
                    goalHit ? Color.white : Color.white.opacity(0.9),
                    style: StrokeStyle(lineWidth: ringWidth, lineCap: .round)
                )
                .frame(width: ringSize, height: ringSize)
                .rotationEffect(.degrees(-90))
                .animation(.easeInOut(duration: 0.5), value: animatedProgress)

            // Goal hit glow effect
            if goalHit && showCelebration {
                Circle()
                    .stroke(Color.white.opacity(0.4), lineWidth: ringWidth + 8)
                    .frame(width: ringSize, height: ringSize)
                    .blur(radius: 8)
                    .opacity(showCelebration ? 1 : 0)
            }

            // Center content
            centerContent
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.8)) {
                animatedProgress = min(progress, 1.0)
            }
        }
        .onChange(of: progress) { _, newValue in
            withAnimation(.easeInOut(duration: 0.3)) {
                animatedProgress = min(newValue, 1.0)
            }
        }
        .onChange(of: goalHit) { wasHit, isNowHit in
            if !wasHit && isNowHit {
                // Goal just hit - trigger celebration
                triggerCelebration()
            }
        }
    }

    // MARK: - Center Content

    private var centerContent: some View {
        VStack(spacing: 4) {
            switch displayMode {
            case .stepsAccumulated(let steps, let secondaryText):
                heroNumber(steps.formatted())
                secondaryLabel(secondaryText)

            case .countdown(let remaining):
                heroNumber(formatCountdown(remaining))

            case .distanceRemaining(let meters):
                let miles = meters * 0.000621371
                heroNumber(String(format: "%.2f", miles))
                secondaryLabel("mi remaining")

            case .stepsRemaining(let count):
                heroNumber(count.formatted())
                secondaryLabel("steps remaining")

            case .goalReached:
                Text("Goal reached!")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(.white)
                    .scaleEffect(showCelebration ? 1.1 : 1.0)
                    .animation(.spring(response: 0.3, dampingFraction: 0.5), value: showCelebration)
                secondaryLabel("Keep going?")
            }
        }
    }

    private func heroNumber(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 48, weight: .bold, design: .rounded))
            .foregroundStyle(.white)
            .contentTransition(.numericText())
    }

    private func secondaryLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 15, weight: .regular))
            .foregroundStyle(.white.opacity(0.8))
    }

    private func formatCountdown(_ seconds: TimeInterval) -> String {
        let mins = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%d:%02d", mins, secs)
    }

    // MARK: - Celebration

    private func triggerCelebration() {
        // Haptic feedback
        HapticService.shared.playSuccess()

        // Visual celebration
        withAnimation(.easeOut(duration: 0.3)) {
            showCelebration = true
        }

        // Fade out celebration after a moment
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            withAnimation(.easeOut(duration: 0.5)) {
                showCelebration = false
            }
        }
    }
}

// MARK: - Preview

#Preview("Steps Accumulated") {
    ZStack {
        LinearGradient(
            colors: [Color(hex: "00C7BE"), Color(hex: "34C759")],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()

        WalkProgressRing(
            displayMode: .stepsAccumulated(steps: 3847, secondaryText: "toward daily goal"),
            progress: 0.65,
            goalHit: false
        )
    }
}

#Preview("Time Countdown") {
    ZStack {
        LinearGradient(
            colors: [Color(hex: "00C7BE"), Color(hex: "34C759")],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()

        WalkProgressRing(
            displayMode: .countdown(timeRemaining: 845),  // 14:05
            progress: 0.53,
            goalHit: false
        )
    }
}

#Preview("Distance Remaining") {
    ZStack {
        LinearGradient(
            colors: [Color(hex: "00C7BE"), Color(hex: "34C759")],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()

        WalkProgressRing(
            displayMode: .distanceRemaining(meters: 1287),  // ~0.8 mi
            progress: 0.60,
            goalHit: false
        )
    }
}

#Preview("Goal Reached") {
    ZStack {
        LinearGradient(
            colors: [Color(hex: "00C7BE"), Color(hex: "34C759")],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()

        WalkProgressRing(
            displayMode: .goalReached,
            progress: 1.0,
            goalHit: true
        )
    }
}
