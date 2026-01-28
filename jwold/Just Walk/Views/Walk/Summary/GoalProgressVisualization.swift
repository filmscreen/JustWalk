//
//  GoalProgressVisualization.swift
//  Just Walk
//
//  Animated before/after progress bar showing goal progress.
//  Visualizes the impact of the walk on daily step goal.
//

import SwiftUI

struct GoalProgressVisualization: View {
    let stepsBefore: Int
    let stepsAfter: Int
    let goal: Int

    @State private var animatedProgress: Double = 0
    @State private var showPulse: Bool = false

    private var progressBefore: Double {
        min(1.0, Double(stepsBefore) / Double(goal))
    }

    private var progressAfter: Double {
        min(1.0, Double(stepsAfter) / Double(goal))
    }

    private var didReachGoal: Bool {
        stepsAfter >= goal && stepsBefore < goal
    }

    var body: some View {
        VStack(spacing: JWDesign.Spacing.sm) {
            // Progress bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    // Background track
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.gray.opacity(0.2))

                    // Before state (faded indicator)
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.gray.opacity(0.4))
                        .frame(width: geo.size.width * progressBefore)

                    // After state (animated fill)
                    RoundedRectangle(cornerRadius: 6)
                        .fill(JWDesign.Gradients.brand)
                        .frame(width: geo.size.width * animatedProgress)
                        .scaleEffect(showPulse ? 1.02 : 1.0, anchor: .leading)
                }
            }
            .frame(height: 12)

            // Labels
            HStack {
                Text(stepsBefore.formatted())
                    .font(JWDesign.Typography.caption)
                    .foregroundStyle(.secondary)

                Spacer()

                HStack(spacing: 4) {
                    Text(stepsAfter.formatted())
                        .fontWeight(.semibold)
                    Text("/")
                        .foregroundStyle(.secondary)
                    Text(goal.formatted())
                        .foregroundStyle(.secondary)
                }
                .font(JWDesign.Typography.caption)
            }
        }
        .onAppear {
            // Start with before state
            animatedProgress = progressBefore

            // Animate to after state
            withAnimation(.easeOut(duration: 1.2).delay(0.3)) {
                animatedProgress = progressAfter
            }

            // Pulse if goal reached
            if didReachGoal {
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    withAnimation(.easeInOut(duration: 0.3).repeatCount(2, autoreverses: true)) {
                        showPulse = true
                    }
                }
            }
        }
    }
}

#Preview("Progress") {
    VStack(spacing: 40) {
        GoalProgressVisualization(
            stepsBefore: 4200,
            stepsAfter: 9047,
            goal: 10000
        )

        GoalProgressVisualization(
            stepsBefore: 8500,
            stepsAfter: 11200,
            goal: 10000
        )
    }
    .padding()
}
