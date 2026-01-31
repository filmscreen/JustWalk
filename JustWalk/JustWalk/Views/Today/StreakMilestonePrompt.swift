//
//  StreakMilestonePrompt.swift
//  JustWalk
//
//  One-time celebration prompt when user hits their first 7-day streak.
//  Highlights Pro shield benefits with a soft upgrade CTA.
//

import SwiftUI

struct StreakMilestonePrompt: View {
    let streakDays: Int
    let onUpgrade: () -> Void
    let onDismiss: () -> Void

    @State private var checkScale: CGFloat = 0
    @State private var contentOpacity: Double = 0

    var body: some View {
        VStack(spacing: JW.Spacing.xxl) {
            Spacer()

            // Celebration icon
            ZStack {
                Circle()
                    .fill(JW.Color.accent.opacity(0.15))
                    .frame(width: 100, height: 100)

                Image(systemName: "flame.fill")
                    .font(.system(size: 44, weight: .medium))
                    .foregroundStyle(JW.Color.accent)
                    .scaleEffect(checkScale)
            }

            // Headline
            VStack(spacing: JW.Spacing.md) {
                Text("You're on a Roll!")
                    .font(JW.Font.title1)
                    .foregroundStyle(JW.Color.textPrimary)

                Text("\(streakDays)-day streak. You've built real momentum.")
                    .font(JW.Font.body)
                    .foregroundStyle(JW.Color.textSecondary)
                    .multilineTextAlignment(.center)
            }
            .opacity(contentOpacity)

            // Shield benefit callout
            VStack(spacing: JW.Spacing.lg) {
                HStack(alignment: .top, spacing: JW.Spacing.md) {
                    ZStack {
                        Circle()
                            .fill(JW.Color.streak.opacity(0.15))
                            .frame(width: 44, height: 44)

                        Image(systemName: "shield.fill")
                            .font(.title3)
                            .foregroundStyle(JW.Color.streak)
                    }

                    VStack(alignment: .leading, spacing: JW.Spacing.xs) {
                        Text("Protect What You've Built")
                            .font(JW.Font.headline)
                            .foregroundStyle(JW.Color.textPrimary)

                        Text("Pro gives you 4 shields per month (bank up to 8) so a busy day doesn't erase your progress.")
                            .font(JW.Font.subheadline)
                            .foregroundStyle(JW.Color.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            .padding(JW.Spacing.lg)
            .background(
                RoundedRectangle(cornerRadius: JW.Radius.lg)
                    .fill(JW.Color.backgroundCard)
            )
            .overlay(
                RoundedRectangle(cornerRadius: JW.Radius.lg)
                    .stroke(Color.white.opacity(0.06), lineWidth: 1)
            )
            .padding(.horizontal, JW.Spacing.xl)
            .opacity(contentOpacity)

            Spacer()

            // CTAs
            VStack(spacing: JW.Spacing.md) {
                Button(action: {
                    JustWalkHaptics.buttonTap()
                    onUpgrade()
                }) {
                    Text("Try Pro Free")
                        .font(JW.Font.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(JW.Color.accent)
                        .foregroundStyle(.black)
                        .clipShape(RoundedRectangle(cornerRadius: JW.Radius.lg))
                }
                .buttonPressEffect()

                Button(action: {
                    onDismiss()
                }) {
                    Text("Keep Going Free")
                        .font(JW.Font.subheadline)
                        .foregroundStyle(JW.Color.textSecondary)
                }
            }
            .padding(.horizontal, JW.Spacing.xl)
            .padding(.bottom, 40)
            .opacity(contentOpacity)
        }
        .background(JW.Color.backgroundPrimary)
        .onAppear {
            JustWalkHaptics.streakMilestone()
            withAnimation(JustWalkAnimation.celebration) {
                checkScale = 1.0
            }
            withAnimation(.easeOut(duration: 0.5).delay(0.3)) {
                contentOpacity = 1.0
            }
        }
        .presentationDetents([.large])
    }
}

#Preview {
    StreakMilestonePrompt(
        streakDays: 7,
        onUpgrade: {},
        onDismiss: {}
    )
}
