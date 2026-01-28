//
//  PowerWalkEfficiencyCard.swift
//  Just Walk
//
//  Shows time saved for Power Walk sessions.
//  The key payoff stat: "You saved ~12 min vs. a regular walk"
//

import SwiftUI
import Combine

struct PowerWalkEfficiencyCard: View {
    let minutesSaved: Int

    var body: some View {
        HStack(spacing: JWDesign.Spacing.md) {
            Image(systemName: "bolt.fill")
                .font(.title2)
                .foregroundStyle(.yellow)

            VStack(alignment: .leading, spacing: 2) {
                Text("You saved ~\(minutesSaved) min")
                    .font(JWDesign.Typography.headlineBold)

                Text("vs. a regular walk")
                    .font(JWDesign.Typography.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding(JWDesign.Spacing.lg)
        .background(JWDesign.Colors.secondaryBackground)
        .clipShape(RoundedRectangle(cornerRadius: JWDesign.Radius.large))
    }
}

#Preview {
    PowerWalkEfficiencyCard(minutesSaved: 12)
        .padding()
}
