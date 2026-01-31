//
//  OneStepAtATimeView.swift
//  JustWalk
//
//  Screen 2: Streak explanation with animated dot visualization
//

import SwiftUI

struct OneStepAtATimeView: View {
    let onContinue: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var appeared = false
    @State private var filledDots: Int = 0
    @State private var showLine1 = false
    @State private var showLine2 = false
    @State private var showLine3 = false
    @State private var showBody = false
    @State private var showButton = false

    var body: some View {
        VStack(spacing: JW.Spacing.xxl) {
            Spacer()

            // Streak dot visualization
            HStack(spacing: JW.Spacing.md) {
                ForEach(0..<7, id: \.self) { index in
                    Circle()
                        .fill(index < filledDots ? JW.Color.accent : JW.Color.backgroundTertiary)
                        .frame(width: 32, height: 32)
                        .overlay(
                            Image(systemName: "checkmark")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(.white)
                                .opacity(index < filledDots ? 1 : 0)
                        )
                        .scaleEffect(index < filledDots ? 1 : 0.8)
                        .animation(
                            reduceMotion
                                ? .easeOut(duration: 0.15)
                                : JustWalkAnimation.emphasis.delay(Double(index) * 0.12),
                            value: filledDots
                        )
                }
            }
            .opacity(appeared ? 1 : 0)

            // Staggered text lines
            VStack(spacing: JW.Spacing.lg) {
                Text("Set a daily goal.")
                    .font(JW.Font.title2)
                    .foregroundStyle(JW.Color.textPrimary)
                    .opacity(showLine1 ? 1 : 0)
                    .offset(y: showLine1 ? 0 : 15)

                Text("Hit it.")
                    .font(JW.Font.title2)
                    .foregroundStyle(JW.Color.accent)
                    .opacity(showLine2 ? 1 : 0)
                    .offset(y: showLine2 ? 0 : 15)

                Text("Repeat.")
                    .font(JW.Font.title2)
                    .foregroundStyle(JW.Color.accent)
                    .opacity(showLine3 ? 1 : 0)
                    .offset(y: showLine3 ? 0 : 15)

                Text("Build a streak and watch your consistency grow.\nThat's where the real results come from.")
                    .font(JW.Font.body)
                    .foregroundStyle(JW.Color.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, JW.Spacing.xl)
                    .padding(.top, JW.Spacing.sm)
                    .opacity(showBody ? 1 : 0)
                    .offset(y: showBody ? 0 : 15)
            }

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
                    .foregroundStyle(.black)
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

        withAnimation(.easeOut(duration: 0.3)) { appeared = true }

        // Fill dots sequentially
        let dotBaseDelay: Double = quick ? 0.1 : 0.4
        for i in 1...7 {
            let delay = dotBaseDelay + (quick ? 0 : Double(i) * 0.12)
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                filledDots = i
            }
        }

        // Text lines appear after dots
        let textBase: Double = quick ? 0.2 : 1.4
        withAnimation(.easeOut(duration: 0.4).delay(textBase)) { showLine1 = true }
        withAnimation(.easeOut(duration: 0.4).delay(textBase + (quick ? 0 : 0.3))) { showLine2 = true }
        withAnimation(.easeOut(duration: 0.4).delay(textBase + (quick ? 0 : 0.6))) { showLine3 = true }
        withAnimation(.easeOut(duration: 0.5).delay(textBase + (quick ? 0 : 1.0))) { showBody = true }
        withAnimation(.easeOut(duration: 0.5).delay(textBase + (quick ? 0 : 1.3))) { showButton = true }
    }
}

#Preview {
    ZStack {
        JW.Color.backgroundPrimary.ignoresSafeArea()
        OneStepAtATimeView(onContinue: {})
    }
}
