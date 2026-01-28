//
//  StreakBadgeView.swift
//  JustWalk
//
//  Streak indicator badge with flame icon
//

import SwiftUI

struct StreakBadgeView: View {
    let streak: Int
    var longestStreak: Int = 0
    var onTap: (() -> Void)? = nil

    @State private var isAnimating = false

    private var flameColor: Color {
        switch streak {
        case 0:
            return .gray
        case 1...6:
            return JW.Color.streak
        case 7...29:
            return JW.Color.streak
        case 30...99:
            return JW.Color.danger
        case 100...:
            return JW.Color.accentPurple
        default:
            return JW.Color.streak
        }
    }

    private var subtitle: String? {
        if streak == 0 {
            return "Hit your goal today"
        } else if longestStreak > 0 && streak >= longestStreak {
            return "Your longest streak"
        } else if longestStreak > streak {
            return "Best: \(longestStreak)"
        }
        return nil
    }

    var body: some View {
        Button {
            onTap?()
        } label: {
            VStack(spacing: 2) {
                HStack(spacing: 6) {
                    Image(systemName: streak > 0 ? "flame.fill" : "flame")
                        .foregroundStyle(flameColor)
                        .symbolEffect(.pulse, options: .repeating, value: streak > 0 && isAnimating)

                    if streak > 0 {
                        Text("\(streak) days")
                            .font(JW.Font.headline)
                            .foregroundStyle(JW.Color.textPrimary)
                            .contentTransition(.numericText(value: Double(streak)))
                    } else {
                        Text("Start your streak")
                            .font(JW.Font.headline)
                            .foregroundStyle(JW.Color.textSecondary)
                    }
                }

                if let subtitle {
                    Text(subtitle)
                        .font(JW.Font.caption)
                        .foregroundStyle(JW.Color.textTertiary)
                }
            }
        }
        .buttonStyle(.plain)
        .onAppear {
            isAnimating = true
        }
    }
}

// MARK: - Large Streak Badge

struct LargeStreakBadgeView: View {
    let streak: Int
    let longestStreak: Int

    var body: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(JW.Color.streak.opacity(0.2))
                    .frame(width: 80, height: 80)

                Image(systemName: "flame.fill")
                    .font(.system(size: 36))
                    .foregroundStyle(JW.Color.streak)
            }

            VStack(spacing: 4) {
                Text("\(streak)")
                    .font(JW.Font.largeTitle)
                    .contentTransition(.numericText(value: Double(streak)))

                Text("day streak")
                    .font(JW.Font.subheadline)
                    .foregroundStyle(JW.Color.textSecondary)
            }

            if longestStreak > streak {
                Text("Best: \(longestStreak) days")
                    .font(JW.Font.caption)
                    .foregroundStyle(JW.Color.textSecondary)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: JW.Radius.xl)
                .fill(JW.Color.backgroundCard)
        )
        .overlay(RoundedRectangle(cornerRadius: JW.Radius.xl).stroke(Color.white.opacity(0.06), lineWidth: 1))
    }
}

// MARK: - Streak Milestone Badge

struct StreakMilestoneBadge: View {
    let milestone: Int
    let isUnlocked: Bool

    private var milestoneIcon: String {
        switch milestone {
        case 7: return "7.circle.fill"
        case 30: return "30.circle.fill"
        case 50: return "50.circle.fill"
        case 100: return "100.circle.fill"
        case 365: return "star.circle.fill"
        default: return "\(milestone).circle.fill"
        }
    }

    private var milestoneColor: Color {
        switch milestone {
        case 7: return JW.Color.success
        case 30: return JW.Color.accentBlue
        case 50: return JW.Color.accentPurple
        case 100: return JW.Color.streak
        case 365: return JW.Color.accent
        default: return .gray
        }
    }

    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(isUnlocked ? milestoneColor.opacity(0.2) : JW.Color.backgroundTertiary)
                    .frame(width: 60, height: 60)

                if isUnlocked {
                    Image(systemName: "flame.fill")
                        .font(.title)
                        .foregroundStyle(milestoneColor)
                } else {
                    Image(systemName: "lock.fill")
                        .font(.title2)
                        .foregroundStyle(.gray)
                }
            }

            Text("\(milestone)")
                .font(JW.Font.caption.bold())
                .foregroundStyle(isUnlocked ? JW.Color.textPrimary : JW.Color.textSecondary)

            Text("days")
                .font(JW.Font.caption2)
                .foregroundStyle(JW.Color.textSecondary)
        }
        .opacity(isUnlocked ? 1.0 : 0.5)
    }
}

// MARK: - Shield Badge View

struct ShieldBadgeView: View {
    let count: Int
    var onTap: (() -> Void)? = nil

    var body: some View {
        Button {
            onTap?()
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "shield.fill")
                    .foregroundStyle(JW.Color.accentBlue)

                Text("\(count)")
                    .font(JW.Font.headline)
                    .contentTransition(.numericText(value: Double(count)))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(JW.Color.backgroundCard)
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Walk Time Badge View

struct WalkTimeBadgeView: View {
    let minutes: Int
    var onTap: (() -> Void)? = nil

    var body: some View {
        Button {
            onTap?()
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "figure.walk")
                    .foregroundStyle(JW.Color.accent)

                Text(minutes > 0 ? "\(minutes)m" : "0m")
                    .font(JW.Font.headline)
                    .contentTransition(.numericText(value: Double(minutes)))

                Text("Walks")
                    .font(JW.Font.caption2)
                    .foregroundStyle(JW.Color.textSecondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(JW.Color.backgroundCard)
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    VStack(spacing: 30) {
        VStack(spacing: 20) {
            StreakBadgeView(streak: 0)
            StreakBadgeView(streak: 5, longestStreak: 42)
            StreakBadgeView(streak: 42, longestStreak: 42)
            StreakBadgeView(streak: 150, longestStreak: 150)
        }

        LargeStreakBadgeView(streak: 42, longestStreak: 87)

        HStack(spacing: 16) {
            StreakMilestoneBadge(milestone: 7, isUnlocked: true)
            StreakMilestoneBadge(milestone: 30, isUnlocked: true)
            StreakMilestoneBadge(milestone: 50, isUnlocked: false)
            StreakMilestoneBadge(milestone: 100, isUnlocked: false)
        }
    }
    .padding()
}
