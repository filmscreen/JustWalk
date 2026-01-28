//
//  StepsContributionCard.swift
//  Just Walk
//
//  Primary stat display with contribution framing.
//  Shows "+X steps toward your goal" as the hero element.
//

import SwiftUI

struct StepsContributionCard: View {
    let stepsAdded: Int

    @State private var displayedSteps: Int = 0
    @State private var hasAnimated: Bool = false

    var body: some View {
        VStack(spacing: JWDesign.Spacing.sm) {
            // Hero number with count-up animation
            Text("+\(displayedSteps.formatted())")
                .font(.system(size: 56, weight: .bold, design: .rounded))
                .foregroundStyle(JWDesign.Gradients.brand)
                .contentTransition(.numericText())
                .monospacedDigit()

            Text("steps toward your goal")
                .font(JWDesign.Typography.subheadline)
                .foregroundStyle(.secondary)
        }
        .onAppear {
            guard !hasAnimated else { return }
            hasAnimated = true
            animateCountUp()
        }
    }

    private func animateCountUp() {
        // Quick count-up animation over 0.8 seconds
        let duration: Double = 0.8
        let steps = 20
        let increment = stepsAdded / steps
        let interval = duration / Double(steps)

        for i in 0..<steps {
            DispatchQueue.main.asyncAfter(deadline: .now() + interval * Double(i)) {
                withAnimation(.easeOut(duration: 0.05)) {
                    if i == steps - 1 {
                        displayedSteps = stepsAdded
                    } else {
                        displayedSteps = increment * (i + 1)
                    }
                }
            }
        }
    }
}

#Preview {
    StepsContributionCard(stepsAdded: 4847)
        .padding()
}
