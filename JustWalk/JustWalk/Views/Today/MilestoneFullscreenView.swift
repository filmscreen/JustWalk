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

    @State private var hasAppeared = false

    private var accentOpacity: Double {
        // Stronger accent for bigger milestones
        switch event.headline {
        case let h where h.contains("Year"):
            return 0.20
        case let h where h.contains("Month"):
            return 0.15
        default:
            return 0.10
        }
    }

    var body: some View {
        ZStack {
            // Background - app's dark background with subtle radial gradient
            ZStack {
                JW.Color.backgroundPrimary
                    .ignoresSafeArea()

                // Subtle radial gradient - accent glow behind content
                RadialGradient(
                    colors: [
                        JW.Color.accent.opacity(accentOpacity),
                        Color.clear
                    ],
                    center: .center,
                    startRadius: 0,
                    endRadius: 300
                )
                .ignoresSafeArea()
            }

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

                // Continue button - understated, brand green text
                Button {
                    onDismiss()
                } label: {
                    Text("Continue")
                        .font(JW.Font.body)
                        .foregroundStyle(JW.Color.accent)
                }
                .padding(.bottom, 60)
                .opacity(hasAppeared ? 1.0 : 0.0)
            }
        }
        .onAppear {
            JustWalkHaptics.milestone()

            withAnimation(JustWalkAnimation.dramatic) {
                hasAppeared = true
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
