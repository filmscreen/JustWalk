//
//  ProFeatureHighlightCard.swift
//  Just Walk
//
//  Created by Claude on 1/22/26.
//

import SwiftUI

struct ProFeatureHighlightCard: View {
    let icon: String
    let iconColor: Color
    let title: String
    let description: String

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            // Icon circle
            ZStack {
                Circle()
                    .fill(iconColor)
                    .frame(width: 40, height: 40)

                Image(systemName: icon)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.white)
            }

            // Title + Description
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.white)

                Text(description)
                    .font(.system(size: 14))
                    .foregroundStyle(.white.opacity(0.8))
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .padding(16)
        .background(Color.white.opacity(0.15))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

#Preview {
    ZStack {
        LinearGradient(
            colors: [.blue, .cyan],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()

        VStack(spacing: 12) {
            ProFeatureHighlightCard(
                icon: "shield.fill",
                iconColor: Color(hex: "FF9500"),
                title: "Streak Shields",
                description: "Protect your streak on rest days or when life gets busy"
            )

            ProFeatureHighlightCard(
                icon: "target",
                iconColor: Color(hex: "00C7BE"),
                title: "Goal Walks",
                description: "Set distance or step targets and get guided to completion"
            )

            ProFeatureHighlightCard(
                icon: "bolt.fill",
                iconColor: Color(hex: "FF6B35"),
                title: "Interval Mode",
                description: "Alternate fast and slow paces to boost your cardio"
            )

            ProFeatureHighlightCard(
                icon: "chart.xyaxis.line",
                iconColor: Color(hex: "AF52DE"),
                title: "Advanced Insights",
                description: "Deeper analytics on your walking patterns and trends"
            )
        }
        .padding(.horizontal, 24)
    }
}
