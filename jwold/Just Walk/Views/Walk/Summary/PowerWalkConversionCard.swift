//
//  PowerWalkConversionCard.swift
//  Just Walk
//
//  Subtle, dismissible conversion prompt shown after Just Walk sessions.
//  Non-blocking, appears at bottom of summary after trigger conditions met.
//

import SwiftUI
import Combine

struct PowerWalkConversionCard: View {
    let bodyText: String
    let ctaText: String
    let onTryPowerWalk: () -> Void
    let onDismiss: () -> Void

    @State private var isVisible: Bool = true

    var body: some View {
        if isVisible {
            VStack(spacing: JWDesign.Spacing.md) {
                // Header row with dismiss button
                HStack(alignment: .top) {
                    Image(systemName: "bolt.fill")
                        .font(.title3)
                        .foregroundStyle(.yellow)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(bodyText)
                            .font(JWDesign.Typography.subheadline)
                            .foregroundStyle(.primary)
                    }

                    Spacer()

                    Button {
                        withAnimation(JWDesign.Animation.quick) {
                            isVisible = false
                        }
                        onDismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .padding(8)
                    }
                    .buttonStyle(.plain)
                }

                // CTA Button
                Button {
                    HapticService.shared.playSelection()
                    onTryPowerWalk()
                } label: {
                    Text(ctaText)
                        .font(JWDesign.Typography.subheadlineBold)
                }
                .buttonStyle(JWGradientButtonStyle())
            }
            .padding(JWDesign.Spacing.lg)
            .background(JWDesign.Colors.secondaryBackground)
            .clipShape(RoundedRectangle(cornerRadius: JWDesign.Radius.large))
            .transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }
}

#Preview {
    PowerWalkConversionCard(
        bodyText: "Your walk took 47 min. Power Walk could do it in ~35.",
        ctaText: "Try Power Walk Free",
        onTryPowerWalk: {},
        onDismiss: {}
    )
    .padding()
}
