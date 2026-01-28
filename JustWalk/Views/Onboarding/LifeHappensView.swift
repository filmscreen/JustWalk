//
//  LifeHappensView.swift
//  JustWalk
//
//  Screen 3: Shield explanation — "Life happens. Shields protect your streak."
//

import SwiftUI

struct LifeHappensView: View {
    let onContinue: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var showShield = false
    @State private var glowActive = false
    @State private var showHeadline = false
    @State private var showBody = false
    @State private var showGift = false
    @State private var showButton = false

    var body: some View {
        VStack(spacing: JW.Spacing.xxl) {
            Spacer()

            // Shield illustration with pulsing glow
            ZStack {
                // Glow ring
                Circle()
                    .fill(JW.Color.accent.opacity(glowActive ? 0.15 : 0))
                    .frame(width: 130, height: 130)
                    .animation(
                        reduceMotion ? nil : .easeInOut(duration: 1.5).repeatForever(autoreverses: true),
                        value: glowActive
                    )

                Image(systemName: "shield.fill")
                    .font(.system(size: 56, weight: .medium))
                    .foregroundStyle(JW.Color.accent)
            }
            .opacity(showShield ? 1 : 0)
            .scaleEffect(showShield ? 1 : 0.5)

            // Copy
            VStack(spacing: JW.Spacing.lg) {
                Text("Life Happens.")
                    .font(JW.Font.title1)
                    .foregroundStyle(JW.Color.textPrimary)
                    .multilineTextAlignment(.center)
                    .opacity(showHeadline ? 1 : 0)
                    .offset(y: showHeadline ? 0 : 20)

                VStack(spacing: JW.Spacing.sm) {
                    Text("Sick Day? Bad Weather?")
                        .font(JW.Font.body)
                        .foregroundStyle(JW.Color.textSecondary)
                        .multilineTextAlignment(.center)

                    Text("Shields protect your streak when\nyou need a break — no guilt.")
                        .font(JW.Font.body)
                        .foregroundStyle(JW.Color.textSecondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, JW.Spacing.xl)
                .opacity(showBody ? 1 : 0)
                .offset(y: showBody ? 0 : 15)
            }

            // Gift: Shield explanation
            VStack(spacing: JW.Spacing.md) {
                HStack(spacing: JW.Spacing.xs) {
                    Image(systemName: "shield.fill")
                        .foregroundStyle(JW.Color.accent)
                    Image(systemName: "shield.fill")
                        .foregroundStyle(JW.Color.accent)
                }
                .font(.system(size: 24))

                Text("Your first gift: 2 shields.")
                    .font(JW.Font.headline)
                    .foregroundStyle(JW.Color.textPrimary)

                Text("These are your safety net — if you miss a day, a shield keeps your streak alive. Pro members get more, but these 2 are on us.")
                    .font(JW.Font.subheadline)
                    .foregroundStyle(JW.Color.textSecondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.vertical, JW.Spacing.lg)
            .padding(.horizontal, JW.Spacing.xl)
            .background(
                RoundedRectangle(cornerRadius: JW.Radius.lg)
                    .fill(JW.Color.accent.opacity(0.1))
                    .overlay(
                        RoundedRectangle(cornerRadius: JW.Radius.lg)
                            .stroke(JW.Color.accent.opacity(0.3), lineWidth: 1)
                    )
            )
            .shadow(color: JW.Color.accent.opacity(showGift ? 0.3 : 0), radius: 12)
            .opacity(showGift ? 1 : 0)
            .scaleEffect(showGift ? 1 : 0.8)

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
            : .spring(response: 0.5, dampingFraction: 0.6)

        withAnimation(spring.delay(quick ? 0 : 0.2)) { showShield = true }
        if !quick { withAnimation(.easeInOut(duration: 1.5).delay(0.5)) { glowActive = true } }
        withAnimation(.easeOut(duration: 0.5).delay(quick ? 0 : 0.5)) { showHeadline = true }
        withAnimation(.easeOut(duration: 0.5).delay(quick ? 0 : 0.7)) { showBody = true }
        withAnimation(spring.delay(quick ? 0 : 1.0)) {
            showGift = true
            if !quick { JustWalkHaptics.success() }
        }
        withAnimation(.easeOut(duration: 0.5).delay(quick ? 0 : 1.3)) { showButton = true }
    }
}

#Preview {
    ZStack {
        JW.Color.backgroundPrimary.ignoresSafeArea()
        LifeHappensView(onContinue: {})
    }
}
