//
//  HeroProgressRing.swift
//  Just Walk
//
//  Hero progress ring for the Today screen.
//  Takes 35-40% of screen height, shows steps remaining prominently.
//

import SwiftUI

struct HeroProgressRing: View {
    let stepsRemaining: Int
    let totalSteps: Int
    let goal: Int
    let distance: Double
    let calories: Int?
    let goalReached: Bool
    var onTap: () -> Void = {}

    // Animation state
    @State private var animatedProgress: Double = 0
    @State private var previousGoalReached: Bool = false

    // Animation suppression (for initial load)
    @Environment(\.suppressAnimations) private var suppressAnimations

    // Dynamic Type support - 48pt for larger ring
    @ScaledMetric(relativeTo: .largeTitle) private var primaryFontSize: CGFloat = 48
    private var cappedPrimaryFontSize: CGFloat {
        min(primaryFontSize, 58)
    }

    // MARK: - Computed Properties

    private var progress: Double {
        guard goal > 0 else { return 0 }
        return Double(totalSteps) / Double(goal)
    }

    private var bonusSteps: Int {
        max(0, totalSteps - goal)
    }

    // Ring size for hero layout (220pt)
    private var ringSize: CGFloat { 220 }
    private var strokeWidth: CGFloat { 18 }

    // MARK: - Body

    var body: some View {
        ZStack {
            // Background Ring
            Circle()
                .stroke(Color.gray.opacity(0.12), lineWidth: strokeWidth)

            // Progress Ring (First Lap - up to 100%)
            Circle()
                .trim(from: 0, to: min(animatedProgress, 1.0))
                .stroke(
                    ringGradient,
                    style: StrokeStyle(lineWidth: strokeWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))

            // Overlap Ring (Second Lap+ - beyond 100%)
            if animatedProgress > 1.0 {
                Circle()
                    .trim(from: 0, to: animatedProgress - 1.0)
                    .stroke(
                        ringGradient,
                        style: StrokeStyle(lineWidth: strokeWidth, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
            }

            // Center Content
            centerContent
        }
        .frame(width: ringSize, height: ringSize)
        .onAppear {
            if suppressAnimations {
                animatedProgress = progress
            } else {
                withAnimation(.easeOut(duration: 1.0)) {
                    animatedProgress = progress
                }
            }
        }
        .onChange(of: progress) { _, newValue in
            if suppressAnimations {
                animatedProgress = newValue
            } else {
                withAnimation(.easeInOut(duration: 0.5)) {
                    animatedProgress = newValue
                }
            }
        }
        .onChange(of: goalReached) { wasReached, isReached in
            if !wasReached && isReached {
                HapticService.shared.playGoalReached()
            }
            previousGoalReached = isReached
        }
        .onTapGesture {
            onTap()
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Daily step progress")
        .accessibilityValue(accessibilityDescription)
        .accessibilityHint(goalReached ? "Tap to celebrate" : "Shows your progress toward today's step goal")
    }

    // MARK: - Ring Gradient

    private var ringGradient: AngularGradient {
        AngularGradient(
            colors: [
                Color(hex: "00C7BE"),  // Teal
                .cyan,
                .blue,
                Color(hex: "00C7BE")   // Back to teal for seamless loop
            ],
            center: .center,
            startAngle: .degrees(-90),
            endAngle: .degrees(270)
        )
    }

    // MARK: - Center Content

    @ViewBuilder
    private var centerContent: some View {
        if goalReached && bonusSteps > 0 {
            // Over goal state - show bonus
            overGoalContent
        } else if goalReached {
            // Just hit goal - celebration
            goalReachedContent
        } else {
            // In progress - show steps remaining
            inProgressContent
        }
    }

    // MARK: - In Progress State

    private var inProgressContent: some View {
        VStack(spacing: 2) {
            // Steps accumulated (large, teal)
            Text(totalSteps.formatted())
                .font(.system(size: cappedPrimaryFontSize, weight: .bold, design: .rounded).monospacedDigit())
                .foregroundStyle(Color(hex: "00C7BE"))
                .contentTransition(.numericText())

            // Steps remaining (17pt, secondary)
            Text("\(stepsRemaining.formatted()) to go")
                .font(.system(size: 17, weight: .regular).monospacedDigit())
                .foregroundStyle(.secondary)

            // Distance (15pt, tertiary)
            tertiaryStats
        }
    }

    // MARK: - Goal Reached State

    private var goalReachedContent: some View {
        VStack(spacing: 6) {
            // Trophy icon
            Image(systemName: "trophy.fill")
                .font(.system(size: 36))
                .foregroundStyle(.yellow)
                .symbolEffect(.pulse, options: .repeating)

            // "Goal Reached!"
            Text("Goal Reached!")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(Color(hex: "00C7BE"))

            // Total steps
            Text("\(totalSteps.formatted()) steps")
                .font(.system(size: 15, weight: .regular).monospacedDigit())
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Over Goal State

    private var overGoalContent: some View {
        VStack(spacing: 4) {
            // Trophy icon
            Image(systemName: "trophy.fill")
                .font(.system(size: 24))
                .foregroundStyle(.yellow)
                .symbolEffect(.pulse, options: .repeating)

            // Total steps (large, teal - the hero)
            Text(totalSteps.formatted())
                .font(.system(size: cappedPrimaryFontSize, weight: .bold, design: .rounded).monospacedDigit())
                .foregroundStyle(.mint)
                .contentTransition(.numericText())

            // Bonus steps (smaller, green)
            Text("+\(bonusSteps.formatted()) bonus")
                .font(.system(size: 15, weight: .regular).monospacedDigit())
                .foregroundStyle(Color(hex: "34C759"))
        }
    }

    // MARK: - Tertiary Stats

    @ViewBuilder
    private var tertiaryStats: some View {
        HStack(spacing: 6) {
            // Distance (convert meters to miles)
            Text(String(format: "%.1f mi", distance * 0.000621371))

            if let cal = calories, cal > 0 {
                Text("·")
                Text("\(cal) cal")
            }
        }
        .font(.system(size: 15, weight: .regular))
        .foregroundStyle(Color(.tertiaryLabel))
        .padding(.top, 4)
    }

    // MARK: - Accessibility

    private var accessibilityDescription: String {
        if goalReached && bonusSteps > 0 {
            return "Goal reached with \(bonusSteps.formatted()) bonus steps. \(totalSteps.formatted()) total steps today."
        } else if goalReached {
            return "Goal reached! \(totalSteps.formatted()) steps today."
        } else {
            let percent = Int(progress * 100)
            return "\(stepsRemaining.formatted()) steps remaining to reach your goal. \(percent) percent complete."
        }
    }
}

// MARK: - Preview

#Preview("In Progress") {
    VStack {
        HeroProgressRing(
            stepsRemaining: 4800,
            totalSteps: 5200,
            goal: 10000,
            distance: 2.1,
            calories: 180,
            goalReached: false
        )
    }
    .padding()
    .background(Color(.systemGroupedBackground))
}

#Preview("Goal Reached") {
    VStack {
        HeroProgressRing(
            stepsRemaining: 0,
            totalSteps: 10000,
            goal: 10000,
            distance: 4.2,
            calories: 350,
            goalReached: true
        )
    }
    .padding()
    .background(Color(.systemGroupedBackground))
}

#Preview("Over Goal") {
    VStack {
        HeroProgressRing(
            stepsRemaining: 0,
            totalSteps: 12500,
            goal: 10000,
            distance: 5.3,
            calories: 450,
            goalReached: true
        )
    }
    .padding()
    .background(Color(.systemGroupedBackground))
}

#Preview("Early Progress") {
    VStack {
        HeroProgressRing(
            stepsRemaining: 8500,
            totalSteps: 1500,
            goal: 10000,
            distance: 0.6,
            calories: 52,
            goalReached: false
        )
    }
    .padding()
    .background(Color(.systemGroupedBackground))
}
