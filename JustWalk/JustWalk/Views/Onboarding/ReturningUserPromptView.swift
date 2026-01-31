//
//  ReturningUserPromptView.swift
//  JustWalk
//
//  Fallback screen when iCloud Key-Value Store check is inconclusive.
//  Asks user if they've used JustWalk before to determine sync behavior.
//

import SwiftUI

struct ReturningUserPromptView: View {
    let onYesReturning: () -> Void
    let onNoNewUser: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // Animation states
    @State private var showIcon = false
    @State private var glowActive = false
    @State private var showHeadline = false
    @State private var showBody = false
    @State private var showYesButton = false
    @State private var showNoButton = false

    var body: some View {
        VStack(spacing: JW.Spacing.xxl) {
            Spacer()

            // Question mark icon with pulsing glow
            ZStack {
                Circle()
                    .fill(JW.Color.accent.opacity(glowActive ? 0.15 : 0))
                    .frame(width: 130, height: 130)
                    .animation(
                        reduceMotion ? nil : .easeInOut(duration: 1.5).repeatForever(autoreverses: true),
                        value: glowActive
                    )

                Image(systemName: "person.crop.circle.badge.questionmark")
                    .font(.system(size: 56, weight: .medium))
                    .foregroundStyle(JW.Color.accent)
            }
            .opacity(showIcon ? 1 : 0)
            .scaleEffect(showIcon ? 1 : 0.5)

            // Copy
            VStack(spacing: JW.Spacing.lg) {
                Text("Welcome!")
                    .font(JW.Font.title1)
                    .foregroundStyle(JW.Color.textPrimary)
                    .multilineTextAlignment(.center)
                    .opacity(showHeadline ? 1 : 0)
                    .offset(y: showHeadline ? 0 : 20)

                VStack(spacing: JW.Spacing.sm) {
                    Text("Have you used JustWalk before?")
                        .font(JW.Font.body)
                        .foregroundStyle(JW.Color.textPrimary)

                    Text("If you've used JustWalk on another device,\nwe can restore your streak and shields.")
                        .font(JW.Font.subheadline)
                        .foregroundStyle(JW.Color.textSecondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, JW.Spacing.xl)
                .opacity(showBody ? 1 : 0)
                .offset(y: showBody ? 0 : 15)
            }

            Spacer()

            // Buttons
            VStack(spacing: JW.Spacing.lg) {
                // Yes - restore data
                Button {
                    JustWalkHaptics.buttonTap()
                    onYesReturning()
                } label: {
                    HStack(spacing: JW.Spacing.sm) {
                        Image(systemName: "icloud.and.arrow.down")
                        Text("Yes, restore my data")
                    }
                    .font(JW.Font.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(JW.Color.accent)
                    .foregroundStyle(.black)
                    .clipShape(RoundedRectangle(cornerRadius: JW.Radius.lg))
                }
                .buttonPressEffect()
                .padding(.horizontal, JW.Spacing.xl)
                .opacity(showYesButton ? 1 : 0)
                .offset(y: showYesButton ? 0 : 20)

                // No - new user
                Button {
                    JustWalkHaptics.buttonTap()
                    onNoNewUser()
                } label: {
                    Text("No, I'm new here")
                        .font(JW.Font.subheadline)
                        .foregroundStyle(JW.Color.textSecondary)
                }
                .opacity(showNoButton ? 1 : 0)
            }
            .padding(.bottom, 40)
        }
        .onAppear { runEntrance() }
    }

    // MARK: - Entrance Animation

    private func runEntrance() {
        let quick = reduceMotion

        let spring = quick
            ? Animation.easeOut(duration: 0.2)
            : .spring(response: 0.5, dampingFraction: 0.6)

        withAnimation(spring.delay(quick ? 0 : 0.2)) { showIcon = true }
        if !quick { withAnimation(.easeInOut(duration: 1.5).delay(0.5)) { glowActive = true } }
        withAnimation(.easeOut(duration: 0.5).delay(quick ? 0 : 0.4)) { showHeadline = true }
        withAnimation(.easeOut(duration: 0.5).delay(quick ? 0 : 0.6)) { showBody = true }
        withAnimation(spring.delay(quick ? 0 : 0.9)) { showYesButton = true }
        withAnimation(.easeOut(duration: 0.4).delay(quick ? 0 : 1.1)) { showNoButton = true }

        // Subtle haptic on appear
        DispatchQueue.main.asyncAfter(deadline: .now() + (quick ? 0.1 : 0.3)) {
            JustWalkHaptics.selectionChanged()
        }
    }
}

#Preview {
    ZStack {
        JW.Color.backgroundPrimary.ignoresSafeArea()
        ReturningUserPromptView(
            onYesReturning: {},
            onNoNewUser: {}
        )
    }
}
