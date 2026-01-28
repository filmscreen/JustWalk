//
//  MoreThanPedometerView.swift
//  JustWalk
//
//  Screen 1: "More Than a Pedometer" — introduces the app's philosophy
//

import SwiftUI

struct MoreThanPedometerView: View {
    let onContinue: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var showIllustration = false
    @State private var showHeadline = false
    @State private var showSubhead = false
    @State private var showButton = false

    var body: some View {
        VStack(spacing: JW.Spacing.xxl) {
            Spacer()

            // Illustration
            ZStack {
                // Decorative circle
                Circle()
                    .stroke(JW.Color.accent.opacity(0.2), lineWidth: 2)
                    .frame(width: 140, height: 140)

                // Accent arc
                Circle()
                    .trim(from: 0, to: showIllustration ? 0.3 : 0)
                    .stroke(JW.Color.accent, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                    .frame(width: 140, height: 140)
                    .rotationEffect(.degrees(-90))

                Image(systemName: "figure.walk")
                    .font(.system(size: 56, weight: .medium))
                    .foregroundStyle(JW.Color.accent)
            }
            .opacity(showIllustration ? 1 : 0)
            .scaleEffect(showIllustration ? 1 : 0.8)

            // Copy
            VStack(spacing: JW.Spacing.md) {
                Text("More Than a Pedometer.")
                    .font(JW.Font.title1)
                    .foregroundStyle(JW.Color.textPrimary)
                    .multilineTextAlignment(.center)
                    .opacity(showHeadline ? 1 : 0)
                    .offset(y: showHeadline ? 0 : 20)

                Text("Pedometers count steps.\nJust Walk builds the habit.")
                    .font(JW.Font.body)
                    .foregroundStyle(JW.Color.textSecondary)
                    .multilineTextAlignment(.center)
                    .opacity(showSubhead ? 1 : 0)
                    .offset(y: showSubhead ? 0 : 20)
            }
            .padding(.horizontal, JW.Spacing.xl)

            Spacer()

            // Continue button
            Button(action: {
                JustWalkHaptics.buttonTap()
                onContinue()
            }) {
                Text("Continue")
                    .font(JW.Font.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(JW.Color.accent)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: JW.Radius.lg))
            }
            .buttonPressEffect()
            .padding(.horizontal, JW.Spacing.xl)
            .padding(.bottom, 40)
            .opacity(showButton ? 1 : 0)
            .offset(y: showButton ? 0 : 20)
        }
        .onAppear { runEntrance() }
    }

    // MARK: - Entrance Animation

    private func runEntrance() {
        let quick = reduceMotion

        let spring = quick
            ? Animation.easeOut(duration: 0.2)
            : .spring(response: 0.5, dampingFraction: 0.7)

        withAnimation(spring.delay(quick ? 0 : 0.2)) { showIllustration = true }
        withAnimation(.easeOut(duration: 0.5).delay(quick ? 0 : 0.6)) { showHeadline = true }
        withAnimation(.easeOut(duration: 0.5).delay(quick ? 0 : 0.8)) { showSubhead = true }
        withAnimation(.easeOut(duration: 0.5).delay(quick ? 0 : 1.1)) { showButton = true }
    }
}

#Preview {
    ZStack {
        JW.Color.backgroundPrimary.ignoresSafeArea()
        MoreThanPedometerView(onContinue: {})
    }
}
