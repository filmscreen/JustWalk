//
//  WalkInsightCard.swift
//  JustWalk
//
//  Generic insight card with icon, title, and message body
//

import SwiftUI

struct WalkInsightCard: View {
    let icon: String
    let iconColor: Color
    let title: String
    let message: String

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .foregroundStyle(iconColor)

                Text(title)
                    .font(JW.Font.headline)
            }

            Text(message)
                .font(JW.Font.subheadline)
                .foregroundStyle(JW.Color.textSecondary)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(JW.Color.backgroundCard)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.white.opacity(0.06), lineWidth: 1)
        )
    }
}

#Preview {
    WalkInsightCard(
        icon: "lightbulb.fill",
        iconColor: .yellow,
        title: "Did You Know?",
        message: "Walking after meals can help regulate blood sugar levels."
    )
    .padding()
    .background(Color.black)
}
