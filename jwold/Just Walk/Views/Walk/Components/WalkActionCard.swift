//
//  WalkActionCard.swift
//  Just Walk
//
//  Unified action card for Walk tab with Start button.
//  Used for Just Walk and Power Walk options.
//

import SwiftUI

// MARK: - Walk Card Type

enum WalkCardType {
    case justWalk
    case powerWalk

    var icon: String {
        switch self {
        case .justWalk: return "figure.walk"
        case .powerWalk: return "bolt.fill"
        }
    }

    var iconColor: Color {
        switch self {
        case .justWalk: return Color(hex: "34C759")
        case .powerWalk: return Color(hex: "00C7BE")
        }
    }

    var title: String {
        switch self {
        case .justWalk: return "Just Walk"
        case .powerWalk: return "Power Walk"
        }
    }

    var subtitle: String {
        switch self {
        case .justWalk: return "Go at your pace"
        case .powerWalk: return "Guided intervals"
        }
    }
}

// MARK: - Walk Action Card

struct WalkActionCard: View {
    let type: WalkCardType
    let timeEstimate: String?
    var savingsText: String? = nil
    let goalReachedText: String
    let isGoalReached: Bool
    let isLocked: Bool
    var onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // Icon circle
                iconCircle

                // Content
                cardContent

                Spacer()

                // Start button
                startButton
            }
            .padding(16)
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 20))
        }
        .buttonStyle(WalkActionCardButtonStyle())
    }

    // MARK: - Icon

    private var iconCircle: some View {
        ZStack {
            Circle()
                .fill(type.iconColor.opacity(0.15))
                .frame(width: 44, height: 44)
            Image(systemName: type.icon)
                .font(.system(size: 20))
                .foregroundStyle(type.iconColor)
        }
    }

    // MARK: - Content

    private var cardContent: some View {
        VStack(alignment: .leading, spacing: 4) {
            // Title + PRO badge
            HStack(spacing: 8) {
                Text(type.title)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.primary)

                if type == .powerWalk {
                    Text("PRO")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(Color(hex: "00C7BE"))
                        .clipShape(Capsule())
                }
            }

            // Subtitle
            Text(type.subtitle)
                .font(.system(size: 15))
                .foregroundStyle(.secondary)

            // Time estimate or goal-reached text
            if let time = timeEstimate {
                HStack(spacing: 8) {
                    Text(time)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Color(hex: "00C7BE"))
                    if let savings = savingsText {
                        Text("• \(savings)")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(Color(hex: "34C759"))
                    }
                }
            } else if isGoalReached {
                Text(goalReachedText)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Color(hex: "00C7BE"))
            }
        }
    }

    // MARK: - Start Button

    private var startButton: some View {
        Group {
            if isLocked {
                // Locked: gray outline + lock
                HStack(spacing: 4) {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 12))
                    Text("Start")
                        .font(.system(size: 15, weight: .semibold))
                }
                .foregroundStyle(.secondary)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Capsule().strokeBorder(Color(.separator), lineWidth: 1))
            } else {
                // Active: teal filled
                Text("Start")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color(hex: "00C7BE"))
                    .clipShape(Capsule())
            }
        }
    }
}

// MARK: - Button Style

private struct WalkActionCardButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.spring(response: 0.15, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

// MARK: - Preview

#Preview("Just Walk - Active") {
    VStack(spacing: 16) {
        WalkActionCard(
            type: .justWalk,
            timeEstimate: "~1 hr 40 min to goal",
            goalReachedText: "Ready when you are",
            isGoalReached: false,
            isLocked: false,
            onTap: {}
        )

        WalkActionCard(
            type: .powerWalk,
            timeEstimate: "~1 hr 24 min to goal",
            savingsText: "Save 16 min",
            goalReachedText: "Earn bonus steps faster",
            isGoalReached: false,
            isLocked: false,
            onTap: {}
        )

        WalkActionCard(
            type: .powerWalk,
            timeEstimate: "~1 hr 24 min to goal",
            savingsText: "Save 16 min",
            goalReachedText: "Earn bonus steps faster",
            isGoalReached: false,
            isLocked: true,
            onTap: {}
        )
    }
    .padding()
    .background(Color(.systemGroupedBackground))
}
