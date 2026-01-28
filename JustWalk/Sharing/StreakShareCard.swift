//
//  StreakShareCard.swift
//  JustWalk
//
//  Share card for streak milestones
//

import SwiftUI

struct StreakShareCard: View {
    let currentStreak: Int
    let milestoneText: String?

    static let cardSize = CGSize(width: 1080, height: 1920)

    var body: some View {
        ZStack {
            // Background
            LinearGradient(
                colors: [
                    Color(red: 0x0D/255, green: 0x0D/255, blue: 0x1A/255),
                    Color(red: 0x12/255, green: 0x12/255, blue: 0x20/255),
                    Color(red: 0x16/255, green: 0x14/255, blue: 0x28/255)
                ],
                startPoint: .top,
                endPoint: .bottom
            )

            VStack(spacing: 40) {
                Spacer()

                // Flame icon
                ZStack {
                    Circle()
                        .fill(Color(red: 0xFF/255, green: 0x73/255, blue: 0x1A/255).opacity(0.2))
                        .frame(width: 200, height: 200)

                    Image(systemName: "flame.fill")
                        .font(.system(size: 96))
                        .foregroundStyle(Color(red: 0xFF/255, green: 0x73/255, blue: 0x1A/255))
                }

                // Streak count
                Text("\(currentStreak)")
                    .font(.system(size: 120, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)

                Text("day streak")
                    .font(.system(size: 36, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.6))

                // Milestone badge
                if let milestone = milestoneText {
                    Text(milestone)
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundStyle(Color(red: 0xFF/255, green: 0x73/255, blue: 0x1A/255))
                        .padding(.horizontal, 32)
                        .padding(.vertical, 16)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color(red: 0xFF/255, green: 0x73/255, blue: 0x1A/255).opacity(0.15))
                        )
                }

                Spacer()
            }

            ShareCardBranding()
        }
    }
}
