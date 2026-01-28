//
//  EndedEarlyCard.swift
//  Just Walk
//
//  Non-judgmental display for partial Power Walk completion.
//  Shows factual intervals and encouraging message.
//

import SwiftUI
import Combine

struct EndedEarlyCard: View {
    let completedIntervals: Int
    let totalIntervals: Int
    let encouragementMessage: String

    var body: some View {
        VStack(spacing: JWDesign.Spacing.md) {
            // Intervals display - factual, not judgmental
            HStack(spacing: JWDesign.Spacing.sm) {
                Image(systemName: "bolt.fill")
                    .font(.body)
                    .foregroundStyle(Color(hex: "00C7BE"))

                Text("\(completedIntervals) of \(totalIntervals)")
                    .font(JWDesign.Typography.headline)

                Text("intervals completed")
                    .font(JWDesign.Typography.subheadline)
                    .foregroundStyle(.secondary)
            }

            Divider()

            // Encouraging message
            Text(encouragementMessage)
                .font(JWDesign.Typography.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(JWDesign.Spacing.lg)
        .background(JWDesign.Colors.secondaryBackground)
        .clipShape(RoundedRectangle(cornerRadius: JWDesign.Radius.large))
    }
}

#Preview {
    EndedEarlyCard(
        completedIntervals: 4,
        totalIntervals: 8,
        encouragementMessage: "Every step counts. You still made progress."
    )
    .padding()
}
