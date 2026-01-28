//
//  MilestoneFullscreenView.swift
//  JustWalk
//
//  Fullscreen overlay for Tier 1 milestone celebrations
//

import SwiftUI

struct MilestoneFullscreenView: View {
    let event: MilestoneEvent
    var onDismiss: () -> Void

    @State private var showConfetti = false
    @State private var hasAppeared = false

    var body: some View {
        ZStack {
            // Dark background
            Color.black
                .ignoresSafeArea()

            VStack(spacing: 24) {
                Spacer()

                // SF Symbol icon
                Image(systemName: event.sfSymbol)
                    .font(.system(size: 80))
                    .foregroundStyle(JW.Color.accent)
                    .scaleEffect(hasAppeared ? 1.0 : 0.3)
                    .opacity(hasAppeared ? 1.0 : 0.0)

                // Headline
                Text(event.headline)
                    .font(JW.Font.largeTitle.bold())
                    .foregroundStyle(JW.Color.textPrimary)
                    .multilineTextAlignment(.center)
                    .opacity(hasAppeared ? 1.0 : 0.0)

                // Subtitle
                Text(event.subtitle)
                    .font(JW.Font.body)
                    .foregroundStyle(JW.Color.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
                    .opacity(hasAppeared ? 1.0 : 0.0)

                Spacer()

                // Continue button
                Button {
                    onDismiss()
                } label: {
                    Text("Continue")
                        .font(JW.Font.headline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Capsule().fill(JW.Color.accent))
                }
                .padding(.horizontal, 32)
                .padding(.bottom, 48)
                .opacity(hasAppeared ? 1.0 : 0.0)
            }
        }
        .overlay {
            ConfettiView.streakMilestone(isActive: $showConfetti)
        }
        .onAppear {
            JustWalkHaptics.milestone()

            withAnimation(JustWalkAnimation.dramatic) {
                hasAppeared = true
            }

            // Trigger confetti slightly after entrance
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                showConfetti = true
            }
        }
    }
}

#Preview {
    MilestoneFullscreenView(
        event: MilestoneEvent(
            id: "streak_30",
            tier: .tier1,
            category: .streak,
            headline: "One Month.",
            subtitle: "30 days. That's not luck.",
            sfSymbol: "flame.circle.fill"
        ),
        onDismiss: {}
    )
}
