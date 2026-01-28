//
//  MilestoneToastView.swift
//  JustWalk
//
//  Compact banner view for Tier 3 milestone celebrations
//

import SwiftUI

struct MilestoneToastView: View {
    let event: MilestoneEvent
    var onDismiss: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: event.sfSymbol)
                .font(.title3)
                .foregroundStyle(JW.Color.accent)

            VStack(alignment: .leading, spacing: 2) {
                Text(event.headline)
                    .font(JW.Font.subheadline.weight(.semibold))
                    .foregroundStyle(JW.Color.textPrimary)

                Text(event.subtitle)
                    .font(JW.Font.caption)
                    .foregroundStyle(JW.Color.textSecondary)
            }

            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: JW.Radius.lg)
                .fill(JW.Color.backgroundCard)
        )
        .overlay(
            RoundedRectangle(cornerRadius: JW.Radius.lg)
                .stroke(Color.white.opacity(0.06), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.3), radius: 12, y: 4)
        .padding(.horizontal, 16)
        .onTapGesture {
            onDismiss()
        }
    }
}

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()

        VStack {
            MilestoneToastView(
                event: MilestoneEvent(
                    id: "streak_restart_3",
                    tier: .tier3,
                    category: .streak,
                    headline: "Back at it.",
                    subtitle: "3-day streak after a break.",
                    sfSymbol: "arrow.counterclockwise.circle.fill"
                ),
                onDismiss: {}
            )
            Spacer()
        }
    }
}
