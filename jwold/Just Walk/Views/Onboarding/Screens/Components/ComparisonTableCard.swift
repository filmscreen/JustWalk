//
//  ComparisonTableCard.swift
//  Just Walk
//
//  Created by Claude on 1/22/26.
//

import SwiftUI

struct ComparisonTableCard: View {
    private let freeFeatures = [
        "Step tracking",
        "Daily streaks",
        "Progress ring",
        "Week chart",
        "Rank system",
        "1 route/day",
        "3 saved routes"
    ]

    private let proFeatures = [
        "Everything in Free",
        "Streak Shields",
        "Goal walks",
        "Interval mode",
        "Unlimited routes",
        "Unlimited saves",
        "Advanced insights"
    ]

    var body: some View {
        VStack(spacing: 0) {
            // Header row
            HStack {
                Text("FREE")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.7))
                    .frame(maxWidth: .infinity)

                Text("PRO ✨")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
            }
            .padding(.vertical, 12)
            .background(Color.white.opacity(0.1))

            // Feature rows
            ForEach(0..<max(freeFeatures.count, proFeatures.count), id: \.self) { index in
                HStack(alignment: .center) {
                    // FREE column
                    if index < freeFeatures.count {
                        HStack(spacing: 8) {
                            Image(systemName: "checkmark")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(Color(hex: "34C759"))

                            Text(freeFeatures[index])
                                .font(.system(size: 14))
                                .foregroundStyle(.white.opacity(0.9))
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    } else {
                        Spacer()
                            .frame(maxWidth: .infinity)
                    }

                    // PRO column
                    if index < proFeatures.count {
                        HStack(spacing: 8) {
                            Image(systemName: "checkmark")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(Color(hex: "34C759"))

                            Text(proFeatures[index])
                                .font(.system(size: 14))
                                .foregroundStyle(.white)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    } else {
                        Spacer()
                            .frame(maxWidth: .infinity)
                    }
                }
                .padding(.vertical, 10)
                .padding(.horizontal, 16)

                // Divider (except last row)
                if index < max(freeFeatures.count, proFeatures.count) - 1 {
                    Divider()
                        .background(Color.white.opacity(0.1))
                        .padding(.horizontal, 16)
                }
            }
        }
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

        ComparisonTableCard()
            .padding(.horizontal, 24)
    }
}
