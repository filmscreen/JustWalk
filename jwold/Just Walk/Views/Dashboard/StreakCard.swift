//
//  StreakCard.swift
//  Just Walk
//
//  Streak card component for the Today screen.
//  Shows current streak status with 6 distinct visual states.
//

import SwiftUI

struct StreakCard: View {
    let state: StreakCardState
    let onTap: () -> Void
    var onShare: (() -> Void)?
    var onStreakLostSeen: (() -> Void)?

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Button(action: handleTap) {
            HStack(spacing: 12) {
                iconView
                textContent
                Spacer()
                trailingContent
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 16)
            .frame(height: 72)
            .background(JWDesign.Colors.secondaryBackground)
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityHint("Double tap to view streak details")
        .accessibilityAddTraits(.isButton)
    }

    // MARK: - Icon View

    @ViewBuilder
    private var iconView: some View {
        ZStack {
            Circle()
                .fill(iconBackgroundColor.opacity(0.10))
                .frame(width: 40, height: 40)

            Image(systemName: iconName)
                .font(.system(size: 20))
                .foregroundStyle(iconColor)
                .symbolEffect(.pulse, options: .repeating, isActive: shouldPulse)
        }
    }

    // MARK: - Text Content

    private var textContent: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(.primary)

            Text(subtitle)
                .font(.system(size: 14, weight: .regular))
                .foregroundStyle(subtitleColor)
        }
    }

    // MARK: - Trailing Content

    @ViewBuilder
    private var trailingContent: some View {
        // Chevron for all states - indicates navigation to details
        Image(systemName: "chevron.right")
            .font(.system(size: 14, weight: .regular))
            .foregroundStyle(Color(hex: "8E8E93"))
    }

    // MARK: - State-Based Properties

    private var iconName: String {
        switch state {
        case .loading:
            return "flame"
        case .noStreak:
            return "flame.fill"
        case .active:
            return "flame.fill"
        case .atRisk:
            return "flame.fill"
        case .protected:
            return "shield.fill"
        case .lost:
            return "heart.slash.fill"
        case .milestone:
            return "flame.fill"
        }
    }

    private var iconColor: Color {
        switch state {
        case .loading:
            return Color(.tertiaryLabel)
        case .noStreak:
            return Color.gray.opacity(0.4)
        case .active:
            return Color(hex: "FF9500") // Orange
        case .atRisk:
            return Color(hex: "FF9500") // Orange
        case .protected:
            return Color(hex: "00C7BE") // Teal
        case .lost:
            return Color(.secondaryLabel) // Gray
        case .milestone:
            return Color(hex: "FF9500") // Orange
        }
    }

    private var iconBackgroundColor: Color {
        iconColor
    }

    private var shouldPulse: Bool {
        switch state {
        case .active, .milestone:
            return true
        default:
            return false
        }
    }

    private var title: String {
        switch state {
        case .loading:
            return "Loading..."
        case .noStreak:
            return "Start a Streak"
        case .active(let days, _):
            return "\(days)-day streak"
        case .atRisk(let days, _):
            return "\(days)-day streak at risk"
        case .protected(let days):
            return "\(days)-day streak protected"
        case .lost:
            return "Streak ended"
        case .milestone(let days):
            return StreakMilestone.from(days: days)?.title ?? "\(days)-day streak!"
        }
    }

    private var subtitle: String {
        switch state {
        case .loading:
            return "Checking your streak"
        case .noStreak:
            return "Meet today's goal to begin"
        case .active(_, let isSecured):
            return isSecured ? "Streak secured!" : "Keep it going!"
        case .atRisk(_, let stepsRemaining):
            return "\(stepsRemaining.formatted()) steps to keep it"
        case .protected:
            return "Shield used today"
        case .lost:
            return "Start a new one today"
        case .milestone(let days):
            return StreakMilestone.from(days: days)?.subtitle ?? "Amazing achievement!"
        }
    }

    private var subtitleColor: Color {
        switch state {
        case .active(_, let isSecured):
            return isSecured ? Color(hex: "34C759") : Color(.secondaryLabel) // Green when secured
        case .atRisk:
            return Color(hex: "FF9500") // Orange warning
        case .protected:
            return Color(hex: "00C7BE") // Teal
        default:
            return Color(.secondaryLabel)
        }
    }

    // MARK: - Accessibility

    private var accessibilityLabel: String {
        switch state {
        case .loading:
            return "Loading streak information"
        case .noStreak:
            return "Start a Streak. Meet today's goal to begin."
        case .active(let days, let isSecured):
            let status = isSecured ? "Streak secured" : "Keep it going"
            return "\(days) day streak. \(status)."
        case .atRisk(let days, let stepsRemaining):
            return "\(days) day streak at risk. \(stepsRemaining.formatted()) steps to keep it."
        case .protected(let days):
            return "\(days) day streak protected. Shield used today."
        case .lost:
            return "Streak ended. Start a new one today."
        case .milestone(let days):
            return "\(days) day streak milestone! \(StreakMilestone.from(days: days)?.subtitle ?? "")"
        }
    }

    // MARK: - Actions

    private func handleTap() {
        // For "lost" state, mark as seen after first tap
        if case .lost = state {
            onStreakLostSeen?()
        }
        onTap()
    }
}

// MARK: - Previews

#Preview("No Streak") {
    VStack {
        StreakCard(
            state: .noStreak,
            onTap: { print("Tapped") }
        )
    }
    .padding()
    .background(Color(.systemGroupedBackground))
}

#Preview("Active - Secured") {
    VStack {
        StreakCard(
            state: .active(days: 7, isSecured: true),
            onTap: { print("Tapped") }
        )
    }
    .padding()
    .background(Color(.systemGroupedBackground))
}

#Preview("Active - In Progress") {
    VStack {
        StreakCard(
            state: .active(days: 3, isSecured: false),
            onTap: { print("Tapped") }
        )
    }
    .padding()
    .background(Color(.systemGroupedBackground))
}

#Preview("At Risk") {
    VStack {
        StreakCard(
            state: .atRisk(days: 5, stepsRemaining: 4200),
            onTap: { print("Tapped") }
        )
    }
    .padding()
    .background(Color(.systemGroupedBackground))
}

#Preview("Protected") {
    VStack {
        StreakCard(
            state: .protected(days: 12),
            onTap: { print("Tapped") }
        )
    }
    .padding()
    .background(Color(.systemGroupedBackground))
}

#Preview("Lost") {
    VStack {
        StreakCard(
            state: .lost(previousStreak: 14),
            onTap: { print("Tapped") },
            onStreakLostSeen: { print("Streak lost seen") }
        )
    }
    .padding()
    .background(Color(.systemGroupedBackground))
}

#Preview("Milestone - 7 days") {
    VStack {
        StreakCard(
            state: .milestone(days: 7),
            onTap: { print("Tapped") },
            onShare: { print("Share") }
        )
    }
    .padding()
    .background(Color(.systemGroupedBackground))
}

#Preview("Milestone - 30 days") {
    VStack {
        StreakCard(
            state: .milestone(days: 30),
            onTap: { print("Tapped") },
            onShare: { print("Share") }
        )
    }
    .padding()
    .background(Color(.systemGroupedBackground))
}

#Preview("Milestone - 100 days") {
    VStack {
        StreakCard(
            state: .milestone(days: 100),
            onTap: { print("Tapped") },
            onShare: { print("Share") }
        )
    }
    .padding()
    .background(Color(.systemGroupedBackground))
}

#Preview("Milestone - 365 days") {
    VStack {
        StreakCard(
            state: .milestone(days: 365),
            onTap: { print("Tapped") },
            onShare: { print("Share") }
        )
    }
    .padding()
    .background(Color(.systemGroupedBackground))
}
