//
//  SummaryProgressRing.swift
//  Just Walk Watch App
//
//  Post-workout summary ring with checkmark overlay for goal hit state.
//

import SwiftUI

struct SummaryProgressRing: View {
    let totalSteps: Int
    let goal: Int
    let goalHitThisWorkout: Bool

    // MARK: - Computed Properties

    private var progress: Double {
        guard goal > 0 else { return 0 }
        return min(Double(totalSteps) / Double(goal), 1.0)
    }

    private var goalReached: Bool { totalSteps >= goal }

    private var stepsToGo: Int { max(0, goal - totalSteps) }

    private var bonusSteps: Int { max(0, totalSteps - goal) }

    // MARK: - Styling

    private let strokeWidth: CGFloat = 10.0

    /// Brand gradient: teal -> cyan -> blue (in-progress)
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

    /// Celebration gradient: gold -> orange (goal reached)
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
                    .trim(from: 0.0, to: CGFloat(progress))
                    .stroke(
                        goalReached ? celebrationGradient : brandGradient,
                        style: StrokeStyle(lineWidth: strokeWidth, lineCap: .round)
                    )
                    .frame(width: ringDiameter, height: ringDiameter)
                    .rotationEffect(.degrees(-90))

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
            // Goal hit state
            VStack(spacing: 2) {
                Image(systemName: "checkmark")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(.yellow)

                Text("GOAL")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.yellow)

                Text("HIT!")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.yellow)
            }
        } else {
            // In-progress state - show steps to go
            VStack(spacing: 2) {
                Text("\(stepsToGo.formatted())")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .monospacedDigit()
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)

                Text("to go")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
            }
        }
    }
}

// MARK: - Preview

#Preview("Goal Hit") {
    SummaryProgressRing(
        totalSteps: 10500,
        goal: 10000,
        goalHitThisWorkout: true
    )
    .frame(width: 110, height: 110)
}

#Preview("Goal Not Hit") {
    SummaryProgressRing(
        totalSteps: 7200,
        goal: 10000,
        goalHitThisWorkout: false
    )
    .frame(width: 110, height: 110)
}

#Preview("Early Progress") {
    SummaryProgressRing(
        totalSteps: 3500,
        goal: 10000,
        goalHitThisWorkout: false
    )
    .frame(width: 110, height: 110)
}
