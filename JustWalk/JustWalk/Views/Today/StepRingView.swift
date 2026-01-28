//
//  StepRingView.swift
//  JustWalk
//
//  Circular progress ring showing daily step progress
//

import SwiftUI

struct StepRingView: View {
    let steps: Int
    let goal: Int

    @State private var animatedProgress: Double = 0
    @State private var justCompletedGoal = false

    private var progress: Double {
        min(Double(steps) / Double(max(goal, 1)), 1.0)
    }

    var body: some View {
        ZStack {
            // Inner circle fill for depth
            Circle()
                .fill(JW.Color.backgroundCard.opacity(0.5))
                .frame(width: 200, height: 200)

            // Background ring
            Circle()
                .stroke(JW.Color.backgroundTertiary, lineWidth: 18)
                .frame(width: 220, height: 220)

            // Progress ring
            Circle()
                .trim(from: 0, to: animatedProgress)
                .stroke(
                    progress >= 1.0
                        ? AnyShapeStyle(JW.Color.accent)
                        : AnyShapeStyle(JW.Color.ringGradient),
                    style: StrokeStyle(lineWidth: 18, lineCap: .round)
                )
                .frame(width: 220, height: 220)
                .rotationEffect(.degrees(-90))

            // Brand green glow only at goal completion
            if progress >= 1.0 {
                Circle()
                    .fill(JW.Color.accent.opacity(0.12))
                    .frame(width: 250, height: 250)
                    .blur(radius: 25)
            }

            // Center content
            VStack(spacing: 4) {
                AnimatedCounter(
                    value: steps,
                    font: JW.Font.heroNumber,
                    color: JW.Color.textPrimary
                )

                Group {
                    if progress >= 1.0 {
                        Label("Goal Complete!", systemImage: "checkmark.circle.fill")
                            .font(JW.Font.caption.bold())
                            .foregroundStyle(JW.Color.accent)
                            .transition(.scale.combined(with: .opacity))
                    } else {
                        Text(steps == 0 ? "Let's get moving" : "\(max(goal - steps, 0).formatted()) to go")
                            .font(JW.Font.subheadline)
                            .foregroundStyle(JW.Color.textTertiary)
                            .contentTransition(.interpolate)
                    }
                }
                .animation(.spring(response: 0.4, dampingFraction: 0.8), value: progress >= 1.0)

            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(steps.formatted()) of \(goal.formatted()) steps, \(Int(progress * 100)) percent")
        .scaleEffect(justCompletedGoal ? 1.03 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.5), value: justCompletedGoal)
        .onAppear {
            withAnimation(JustWalkAnimation.ringFill) {
                animatedProgress = progress
            }
        }
        .onChange(of: steps) { oldValue, newValue in
            withAnimation(JustWalkAnimation.standard) {
                animatedProgress = progress
            }
            // Goal complete moment: pulse + haptic
            if oldValue < goal && newValue >= goal {
                JustWalkHaptics.goalComplete()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    justCompletedGoal = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                        justCompletedGoal = false
                    }
                }
            }
        }
    }
}

// MARK: - Compact Step Ring

struct CompactStepRingView: View {
    let steps: Int
    let goal: Int
    let size: CGFloat

    @State private var animatedProgress: Double = 0

    private var progress: Double {
        min(Double(steps) / Double(max(goal, 1)), 1.0)
    }

    var body: some View {
        ZStack {
            Circle()
                .stroke(JW.Color.backgroundTertiary, lineWidth: size * 0.08)
                .frame(width: size, height: size)

            Circle()
                .trim(from: 0, to: animatedProgress)
                .stroke(
                    progress >= 1.0 ? JW.Color.success : JW.Color.accent,
                    style: StrokeStyle(lineWidth: size * 0.08, lineCap: .round)
                )
                .frame(width: size, height: size)
                .rotationEffect(.degrees(-90))

            VStack(spacing: 0) {
                Text("\(steps)")
                    .font(.system(size: size * 0.2, weight: .bold, design: .rounded))
                    .minimumScaleFactor(0.5)
                    .foregroundStyle(JW.Color.textPrimary)

                Text("steps")
                    .font(.system(size: size * 0.1, design: .rounded))
                    .foregroundStyle(JW.Color.textSecondary)
            }
        }
        .onAppear {
            withAnimation(JustWalkAnimation.ringFill) {
                animatedProgress = progress
            }
        }
        .onChange(of: steps) { _, _ in
            withAnimation(JustWalkAnimation.standard) {
                animatedProgress = progress
            }
        }
    }
}

#Preview {
    VStack(spacing: 40) {
        StepRingView(steps: 7500, goal: 10000)
        StepRingView(steps: 10500, goal: 10000)
        CompactStepRingView(steps: 5000, goal: 10000, size: 80)
    }
    .background(JW.Color.backgroundPrimary)
}
