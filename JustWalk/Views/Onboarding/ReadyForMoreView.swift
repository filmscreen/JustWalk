//
//  ReadyForMoreView.swift
//  JustWalk
//
//  Screen 4: "Ready for More?" — plants a seed about Walks / Guided Walks
//

import SwiftUI

struct ReadyForMoreView: View {
    let onContinue: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var showIcon = false
    @State private var showHeadline = false
    @State private var showBody = false
    @State private var showReassurance = false
    @State private var showButton = false

    var body: some View {
        VStack(spacing: JW.Spacing.xxl) {
            Spacer()

            // Illustration — walking figure
            ZStack {
                Circle()
                    .fill(Color.green.opacity(0.15))
                    .frame(width: 120, height: 120)

                Image(systemName: "figure.walk")
                    .font(.system(size: 48))
                    .foregroundColor(.green)
            }
            .opacity(showIcon ? 1 : 0)
            .scaleEffect(showIcon ? 1 : 0.8)

            // Copy
            VStack(spacing: JW.Spacing.lg) {
                Text("Ready for More?")
                    .font(JW.Font.title1)
                    .foregroundStyle(JW.Color.textPrimary)
                    .multilineTextAlignment(.center)
                    .opacity(showHeadline ? 1 : 0)
                    .offset(y: showHeadline ? 0 : 20)

                // Feature hints
                VStack(spacing: JW.Spacing.sm) {
                    Text("When you want to take your walks\nto the next level, Walks is there.")
                        .font(JW.Font.body)
                        .foregroundStyle(JW.Color.textSecondary)
                        .multilineTextAlignment(.center)

                    // Feature tags
                    HStack(spacing: JW.Spacing.md) {
                        FeatureHintTag(icon: "bolt.fill", text: "Intervals")
                        FeatureHintTag(icon: "heart.fill", text: "Fat Burn")
                        FeatureHintTag(icon: "fork.knife", text: "Post-Meal")
                    }
                    .padding(.top, JW.Spacing.sm)
                }
                .opacity(showBody ? 1 : 0)
                .offset(y: showBody ? 0 : 15)

                // Reassurance beat — slightly longer delay
                Text("But first, let's start simple.")
                    .font(JW.Font.headline)
                    .foregroundStyle(JW.Color.textPrimary)
                    .multilineTextAlignment(.center)
                    .opacity(showReassurance ? 1 : 0)
                    .offset(y: showReassurance ? 0 : 15)
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

        withAnimation(spring.delay(quick ? 0 : 0.2)) { showIcon = true }
        withAnimation(.easeOut(duration: 0.5).delay(quick ? 0 : 0.5)) { showHeadline = true }
        withAnimation(.easeOut(duration: 0.5).delay(quick ? 0 : 0.7)) { showBody = true }
        withAnimation(.easeOut(duration: 0.5).delay(quick ? 0 : 1.1)) { showReassurance = true }
        withAnimation(.easeOut(duration: 0.5).delay(quick ? 0 : 1.4)) { showButton = true }
    }
}

// MARK: - Feature Hint Tag

private struct FeatureHintTag: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 12))
            Text(text)
                .font(JW.Font.caption)
        }
        .foregroundStyle(JW.Color.textSecondary)
        .padding(.horizontal, JW.Spacing.sm)
        .padding(.vertical, JW.Spacing.xs)
        .background(
            Capsule()
                .fill(Color.white.opacity(0.06))
        )
    }
}

#Preview {
    ZStack {
        JW.Color.backgroundPrimary.ignoresSafeArea()
        ReadyForMoreView(onContinue: {})
    }
}
