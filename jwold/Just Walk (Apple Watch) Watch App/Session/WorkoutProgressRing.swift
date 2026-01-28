//
//  WorkoutProgressRing.swift
//  Just Walk Watch App
//
//  Circular progress ring for during-workout display.
//  Shows steps inside, fills as user progresses toward goal.
//

import SwiftUI

// MARK: - Display Mode

enum ProgressRingDisplayMode {
    case steps        // Default: show session steps + "steps" label
    case goalProgress // Show steps + steps-to-go
}

struct WorkoutProgressRing: View {
    let steps: Int
    let totalSteps: Int // Today's total steps (for goal calculation)
    let goal: Int
    let isLuminanceReduced: Bool

    /// Display mode for center content (default .steps for backward compatibility)
    var displayMode: ProgressRingDisplayMode = .steps

    // MARK: - Computed Properties

    private var progress: Double {
        guard goal > 0 else { return 0 }
        return Double(totalSteps) / Double(goal)
    }

    private var goalReached: Bool { totalSteps >= goal }

    private var bonusSteps: Int {
        max(0, totalSteps - goal)
    }

    private var stepsToGo: Int {
        max(0, goal - totalSteps)
    }

    // MARK: - Styling

    private let strokeWidth: CGFloat = 8.0

    /// Brand gradient: teal → cyan → blue
    private var brandGradient: AngularGradient {
        AngularGradient(
            colors: [
                Color(hex: "00C7BE"), // Teal
                .cyan,
                .blue,
                Color(hex: "00C7BE")  // Back to teal
            ],
            center: .center,
            startAngle: .degrees(-90),
            endAngle: .degrees(270)
        )
    }

    /// Celebration gradient: gold → orange
    private var celebrationGradient: AngularGradient {
        AngularGradient(
            colors: [
                Color(red: 1.0, green: 0.85, blue: 0.2),  // Gold
                Color(red: 1.0, green: 0.6, blue: 0.1),   // Orange
                Color(red: 1.0, green: 0.85, blue: 0.2)   // Gold
            ],
            center: .center,
            startAngle: .degrees(-90),
            endAngle: .degrees(270)
        )
    }

    // MARK: - Body

    var body: some View {
        GeometryReader { geometry in
            let size = min(geometry.size.width, geometry.size.height)
            let ringDiameter = size - strokeWidth

            ZStack {
                // MARK: - Background Track
                Circle()
                    .stroke(
                        Color.white.opacity(0.15),
                        style: StrokeStyle(lineWidth: strokeWidth, lineCap: .round)
                    )
                    .frame(width: ringDiameter, height: ringDiameter)

                // MARK: - Progress Ring
                Circle()
                    .trim(from: 0.0, to: CGFloat(min(progress, 1.0)))
                    .stroke(
                        goalReached ? celebrationGradient : brandGradient,
                        style: StrokeStyle(lineWidth: strokeWidth, lineCap: .round)
                    )
                    .frame(width: ringDiameter, height: ringDiameter)
                    .rotationEffect(.degrees(-90))
                    .animation(.easeInOut(duration: 0.3), value: progress)

                // MARK: - Overfill Ring (Bonus Steps)
                if progress > 1.0 {
                    Circle()
                        .trim(from: 0.0, to: CGFloat(min(progress - 1.0, 1.0)))
                        .stroke(
                            celebrationGradient,
                            style: StrokeStyle(lineWidth: strokeWidth, lineCap: .round)
                        )
                        .frame(width: ringDiameter, height: ringDiameter)
                        .rotationEffect(.degrees(-90))
                        .opacity(0.6)
                        .animation(.easeInOut(duration: 0.3), value: progress)
                }

                // MARK: - Center Content
                centerContent
                    .frame(width: ringDiameter - strokeWidth * 2 - 8)
            }
            .frame(width: size, height: size)
        }
    }

    // MARK: - Center Content

    @ViewBuilder
    private var centerContent: some View {
        if goalReached {
            celebrationContent
        } else {
            switch displayMode {
            case .steps:
                stepsContent
            case .goalProgress:
                goalProgressContent
            }
        }
    }

    /// Celebration content shown when goal is reached
    private var celebrationContent: some View {
        VStack(spacing: 0) {
            Text("Goal hit!")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.yellow)

            Text("+\(bonusSteps.formatted())")
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundStyle(.yellow)
                .contentTransition(.numericText())
                .monospacedDigit()

            Text("bonus")
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.yellow.opacity(0.8))
        }
    }

    /// Steps mode: show session steps with "steps" label
    private var stepsContent: some View {
        VStack(spacing: 0) {
            Text("\(steps.formatted())")
                .font(.system(size: isLuminanceReduced ? 32 : 38, weight: .bold, design: .rounded))
                .foregroundStyle(isLuminanceReduced ? .white.opacity(0.6) : .white)
                .contentTransition(.numericText())
                .monospacedDigit()
                .minimumScaleFactor(0.6)
                .lineLimit(1)

            Text("steps")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(isLuminanceReduced ? .white.opacity(0.4) : .secondary)
        }
    }

    /// Goal progress mode: show steps with "X to go" label
    private var goalProgressContent: some View {
        VStack(spacing: 1) {
            Text(steps.formatted())
                .font(.system(size: isLuminanceReduced ? 28 : 32, weight: .bold, design: .rounded))
                .foregroundStyle(isLuminanceReduced ? .white.opacity(0.6) : .white)
                .monospacedDigit()
                .minimumScaleFactor(0.6)
                .lineLimit(1)

            Text("\(stepsToGo.formatted()) to go")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Preview

#Preview("Normal Progress") {
    WorkoutProgressRing(
        steps: 2847,
        totalSteps: 5900,
        goal: 10000,
        isLuminanceReduced: false
    )
    .frame(width: 140, height: 140)
}

#Preview("Goal Reached") {
    WorkoutProgressRing(
        steps: 3500,
        totalSteps: 10347,
        goal: 10000,
        isLuminanceReduced: false
    )
    .frame(width: 140, height: 140)
}

#Preview("Always-On") {
    WorkoutProgressRing(
        steps: 2847,
        totalSteps: 5900,
        goal: 10000,
        isLuminanceReduced: true
    )
    .frame(width: 140, height: 140)
}
