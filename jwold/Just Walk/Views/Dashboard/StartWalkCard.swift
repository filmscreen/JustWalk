//
//  StartWalkCard.swift
//  Just Walk
//
//  Promotional card for Walk Mode targeting free users on the Today screen.
//  Features contextual variants and dismissible behavior.
//

import SwiftUI

struct StartWalkCard: View {
    let variant: StartWalkCardVariant
    var onTap: () -> Void
    var onDismiss: () -> Void

    var body: some View {
        ZStack(alignment: .topTrailing) {
            // Main card content (tappable)
            Button(action: onTap) {
                HStack(spacing: 12) {  // 12pt icon-to-text
                    // Icon container: 36pt circle with walking figure
                    ZStack {
                        Circle()
                            .fill(Color(hex: "00C7BE").opacity(0.08))
                            .frame(width: 36, height: 36)
                        Image(systemName: "figure.walk")
                            .font(.system(size: 20))
                            .foregroundStyle(Color(hex: "00C7BE"))
                    }

                    // Title + Subtitle stack
                    VStack(alignment: .leading, spacing: 4) {
                        // Title row with PRO badge
                        HStack(spacing: 6) {
                            Text(variant.headline)
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundStyle(.primary)

                            // PRO badge pill
                            Text("PRO")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(Color(hex: "00C7BE"))
                                )
                        }

                        // Subtitle
                        Text(variant.description)
                            .font(.system(size: 15, weight: .regular))
                            .foregroundStyle(Color(.secondaryLabel))
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Spacer()

                    // CTA: "Try it" + chevron
                    HStack(spacing: 4) {
                        Text(variant.ctaText)
                            .font(.system(size: 15, weight: .regular))
                        Image(systemName: "chevron.right")
                            .font(.system(size: 14, weight: .regular))
                    }
                    .foregroundStyle(Color(hex: "00C7BE"))
                }
                .padding(16)
                .padding(.trailing, 8)  // Extra 8pt for X button
                .background(JWDesign.Colors.secondaryBackground)
                .clipShape(RoundedRectangle(cornerRadius: JWDesign.Radius.card))
                .shadow(color: Color.black.opacity(0.04), radius: 4, x: 0, y: 2)
            }
            .buttonStyle(.plain)
            .hapticOnTap(.buttonTap)

            // X dismiss button (top-right, 44pt tap target)
            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .regular))
                    .foregroundStyle(Color(hex: "AEAEB2"))
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .offset(x: -12 + 22, y: 12 - 22)  // Position visual 12pt from edges
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(variant.headline). \(variant.description)")
        .accessibilityHint("Double tap to try Walk mode, or use actions to dismiss")
        .accessibilityAction(named: "Dismiss") { onDismiss() }
    }
}

#Preview {
    VStack(spacing: 16) {
        StartWalkCard(variant: .default, onTap: {}, onDismiss: {})
        StartWalkCard(variant: .goalHit, onTap: {}, onDismiss: {})
        StartWalkCard(variant: .weekend, onTap: {}, onDismiss: {})
    }
    .padding()
}
