//
//  StreakHeroCard.swift
//  Just Walk
//
//  Hero card displaying the current streak with flame emoji and best streak.
//

import SwiftUI

struct StreakHeroCard: View {
    let currentStreak: Int
    let longestStreak: Int
    var shieldsRemaining: Int = 0
    var onGetShields: (() -> Void)? = nil

    var body: some View {
        VStack(spacing: 0) {  // Manual spacing control
            // Top row: Streak count + Best
            HStack(alignment: .firstTextBaseline) {
                // Left: Flame emoji + streak count (baseline-aligned)
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text("🔥")
                        .font(.system(size: 28))
                        .alignmentGuide(.firstTextBaseline) { d in d[.bottom] - 4 }

                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text("\(currentStreak)")
                            .font(.system(size: 34, weight: .bold))
                            .foregroundStyle(.primary)
                        Text(currentStreak == 1 ? "day" : "days")
                            .font(.system(size: 17, weight: .regular))
                            .foregroundStyle(Color(hex: "8E8E93"))
                    }
                }

                Spacer()

                // Right: Best streak (baseline aligned with "days")
                VStack(alignment: .trailing, spacing: 4) {
                    Text("Best")
                        .font(.system(size: 13, weight: .regular))
                        .foregroundStyle(Color(hex: "AEAEB2"))
                    Text("\(longestStreak) days")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(Color(hex: "8E8E93"))
                }
                .alignmentGuide(.firstTextBaseline) { d in d[.bottom] }
            }

            // Subtitle: 8pt below streak row
            Text(subtitleText)
                .font(.system(size: 15, weight: .regular))
                .foregroundStyle(Color(hex: "8E8E93"))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, 8)

            // Divider: 16pt below subtitle, 0.5pt height, full width
            Rectangle()
                .fill(Color(hex: "E5E5EA"))
                .frame(height: 0.5)
                .padding(.top, 16)

            // Shields row: 16pt below divider
            shieldsRow
                .padding(.top, 16)
        }
        .padding(16)
        .frame(maxWidth: .infinity)
        .background(JWDesign.Colors.secondaryBackground)
        .clipShape(RoundedRectangle(cornerRadius: JWDesign.Radius.card))
        .shadow(color: Color.black.opacity(0.04), radius: 4, x: 0, y: 2)
    }

    // MARK: - Shields Row

    private var shieldsRow: some View {
        Button(action: { onGetShields?() }) {
            HStack(spacing: 8) {
                Image(systemName: "shield")
                    .font(.system(size: 20))
                    .foregroundStyle(Color(hex: "8E8E93"))
                Text("\(shieldsRemaining) \(shieldsRemaining == 1 ? "shield" : "shields")")
                    .font(.system(size: 15, weight: .regular))
                    .foregroundStyle(Color(hex: "8E8E93"))
                Spacer()
                HStack(spacing: 4) {
                    Text("Get shields")
                        .font(.system(size: 15, weight: .regular))
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .regular))
                }
                .foregroundStyle(Color(hex: "00C7BE"))
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: - Contextual Subtitle

    private var subtitleText: String {
        switch currentStreak {
        case 0:
            return "Start today!"
        case 1...6:
            return "Building momentum"
        default:
            // 7+ days
            if currentStreak >= longestStreak {
                return "New personal best! 🎉"
            } else {
                let daysUntilRecord = longestStreak - currentStreak + 1
                return "\(daysUntilRecord) days until you beat your record!"
            }
        }
    }
}

// MARK: - Previews

#Preview("Active Streak - With Shields") {
    StreakHeroCard(
        currentStreak: 12,
        longestStreak: 25,
        shieldsRemaining: 3,
        onGetShields: {}
    )
    .padding()
}

#Preview("No Shields") {
    StreakHeroCard(
        currentStreak: 7,
        longestStreak: 25,
        shieldsRemaining: 0,
        onGetShields: {}
    )
    .padding()
}

#Preview("One Shield") {
    StreakHeroCard(
        currentStreak: 3,
        longestStreak: 25,
        shieldsRemaining: 1,
        onGetShields: {}
    )
    .padding()
}

#Preview("New Personal Best") {
    StreakHeroCard(
        currentStreak: 30,
        longestStreak: 25,
        shieldsRemaining: 2,
        onGetShields: {}
    )
    .padding()
}
