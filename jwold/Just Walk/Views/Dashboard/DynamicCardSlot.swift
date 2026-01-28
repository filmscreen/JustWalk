//
//  DynamicCardSlot.swift
//  Just Walk
//
//  Dynamic card container for the Today screen.
//  Shows one card at a time with dismiss animations.
//  Now integrated with DynamicCardType priority system.
//

import SwiftUI

// MARK: - Card Content Model

struct CardContent {
    let icon: String
    let iconColor: Color
    let title: String
    let subtitle: String
    let ctaText: String?
    let isDismissible: Bool

    static func from(_ card: DynamicCardType) -> CardContent {
        switch card {
        case .streakAtRisk(let streak, let stepsRemaining, let hoursLeft):
            return CardContent(
                icon: "exclamationmark.triangle.fill",
                iconColor: .orange,
                title: "⚠️ \(hoursLeft) hours left",
                subtitle: "\(stepsRemaining.formatted()) steps to keep your \(streak)-day streak",
                ctaText: "Start Walking →",
                isDismissible: true
            )

        case .dailyMilestone(let milestone):
            return CardContent(
                icon: "star.fill",
                iconColor: .yellow,
                title: "🎉 \(milestone.displayName) steps!",
                subtitle: "First time hitting \(milestone.displayName). That's a big deal.",
                ctaText: "Share",
                isDismissible: true
            )

        case .streakMilestone(let days):
            return CardContent(
                icon: "flame.fill",
                iconColor: .orange,
                title: "🔥 \(days)-day streak!",
                subtitle: streakMilestoneSubtitle(days),
                ctaText: "Share",
                isDismissible: true
            )

        case .proTrial:
            return CardContent(
                icon: "bolt.fill",
                iconColor: Color(hex: "00C7BE"),
                title: "Try Power Walk free",
                subtitle: "Guided intervals • More steps in less time",
                ctaText: "Start Free Trial →",
                isDismissible: true
            )

        case .weeklySummary(let snapshot):
            let changeText = weeklySummarySubtitle(snapshot)
            return CardContent(
                icon: "chart.bar.fill",
                iconColor: .blue,
                title: "Last week: \(snapshot.totalSteps.formatted()) steps",
                subtitle: changeText,
                ctaText: "See details →",
                isDismissible: true
            )

        case .goalAdjustment(_, let suggestedGoal, let consecutiveDays):
            return CardContent(
                icon: "arrow.up.circle.fill",
                iconColor: .green,
                title: "You've hit your goal \(consecutiveDays) days straight",
                subtitle: "Ready to raise it to \(suggestedGoal.formatted())?",
                ctaText: "Yes →",
                isDismissible: true  // "Not yet" = dismiss
            )

        case .comebackPrompt(let daysSince):
            return CardContent(
                icon: "hand.wave.fill",
                iconColor: .blue,
                title: "Welcome back 👋",
                subtitle: "Your last walk was \(daysSince) days ago. Start fresh?",
                ctaText: "Start Walking →",
                isDismissible: true
            )

        case .weatherSuggestion(let temp, let condition, let percentToGoal):
            return CardContent(
                icon: "sun.max.fill",
                iconColor: .orange,
                title: "Great walking weather today \(condition) \(temp)°F",
                subtitle: "A 30-min walk gets you to \(percentToGoal)%",
                ctaText: "Start Walking →",
                isDismissible: true
            )

        case .watchAppSetup:
            return CardContent(
                icon: "applewatch",
                iconColor: Color(hex: "00C7BE"),
                title: "Just Walk is on Apple Watch",
                subtitle: "Start walks from your wrist",
                ctaText: "Set Up →",
                isDismissible: true
            )
        }
    }
}

// MARK: - Subtitle Helpers

private func streakMilestoneSubtitle(_ days: Int) -> String {
    switch days {
    case 7: return "You've walked every day for a week."
    case 14: return "Two weeks of daily walking. Impressive!"
    case 30: return "A full month of hitting your goal!"
    case 60: return "60 days strong. You're unstoppable!"
    case 100: return "100 days! You're in the top 1%."
    case 365: return "A whole year of daily walking. Legend."
    default: return "Keep the streak alive!"
    }
}

private func weeklySummarySubtitle(_ snapshot: WeeklySummaryData) -> String {
    if let change = snapshot.percentChange {
        if snapshot.isUp {
            return "\(change)% more than the week before 📈"
        } else {
            return "\(abs(change))% less than the week before"
        }
    }
    return "Your best week yet!"
}

// MARK: - Dynamic Card Slot (Type-Based)

struct DynamicCardSlotTyped: View {
    let cardType: DynamicCardType?
    var onDismiss: () -> Void
    var onPrimaryAction: () -> Void

    var body: some View {
        if let cardType = cardType {
            DynamicCardContainer(
                card: cardType,
                onDismiss: onDismiss,
                onPrimaryAction: onPrimaryAction
            )
            .transition(.asymmetric(
                insertion: .opacity.combined(with: .move(edge: .top)),
                removal: .opacity.combined(with: .move(edge: .trailing))
            ))
        }
    }
}

// MARK: - Dynamic Card Container

struct DynamicCardContainer: View {
    let card: DynamicCardType
    var onDismiss: () -> Void
    var onPrimaryAction: () -> Void

    @Environment(\.colorScheme) private var colorScheme

    private var cardContent: CardContent {
        CardContent.from(card)
    }

    var body: some View {
        Button {
            onPrimaryAction()
        } label: {
            HStack(spacing: 12) {
                // Icon
                iconView

                // Content
                VStack(alignment: .leading, spacing: 4) {
                    Text(cardContent.title)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(.primary)

                    Text(cardContent.subtitle)
                        .font(.system(size: 15))
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }

                Spacer()

                // Trailing content (CTA and/or dismiss)
                trailingContent
            }
            .padding(16)
            .background(JWDesign.Colors.secondaryBackground)
            .clipShape(RoundedRectangle(cornerRadius: JWDesign.Radius.card))
            .shadow(color: .black.opacity(0.04), radius: 4, y: 2)
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityHint(cardContent.isDismissible ? "Double tap to open, swipe to dismiss" : "Double tap to open")
        .accessibilityAddTraits(.isButton)
    }

    // MARK: - Icon View

    private var iconView: some View {
        ZStack {
            Circle()
                .fill(cardContent.iconColor.opacity(colorScheme == .dark ? 0.15 : 0.10))
                .frame(width: 36, height: 36)
            Image(systemName: cardContent.icon)
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(cardContent.iconColor)
        }
    }

    // MARK: - Trailing Content

    @ViewBuilder
    private var trailingContent: some View {
        // Dismiss button (if dismissible)
        if cardContent.isDismissible {
            Button {
                withAnimation(.easeOut(duration: 0.2)) {
                    onDismiss()
                }
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color(.tertiaryLabel))
                    .frame(width: 28, height: 28)
                    .background(Color(.tertiarySystemFill))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
        }
    }
}

// MARK: - Legacy Support (for backward compatibility)

struct DynamicCard: Identifiable, Equatable {
    let id: String
    let icon: String
    let iconColor: Color
    let title: String
    let subtitle: String
    let isDismissible: Bool
    var actionHandler: (() -> Void)?

    static func == (lhs: DynamicCard, rhs: DynamicCard) -> Bool {
        lhs.id == rhs.id
    }
}

struct DynamicCardSlot: View {
    let currentCard: DynamicCard?
    var onDismiss: () -> Void
    var onTap: () -> Void

    var body: some View {
        if let card = currentCard {
            DynamicCardView(
                card: card,
                onDismiss: onDismiss,
                onTap: onTap
            )
            .transition(.asymmetric(
                insertion: .opacity.combined(with: .move(edge: .top)),
                removal: .opacity.combined(with: .move(edge: .trailing))
            ))
        }
    }
}

struct DynamicCardView: View {
    let card: DynamicCard
    var onDismiss: () -> Void
    var onTap: () -> Void

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Button {
            onTap()
            card.actionHandler?()
        } label: {
            HStack(spacing: 12) {
                // Icon circle (36pt)
                ZStack {
                    Circle()
                        .fill(card.iconColor.opacity(colorScheme == .dark ? 0.15 : 0.10))
                        .frame(width: 36, height: 36)
                    Image(systemName: card.icon)
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(card.iconColor)
                }

                // Title + Subtitle
                VStack(alignment: .leading, spacing: 4) {
                    Text(card.title)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(.primary)

                    Text(card.subtitle)
                        .font(.system(size: 15, weight: .regular))
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }

                Spacer()

                // Dismiss button (if dismissible)
                if card.isDismissible {
                    Button {
                        withAnimation(.easeOut(duration: 0.2)) {
                            onDismiss()
                        }
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(Color(.tertiaryLabel))
                            .frame(width: 28, height: 28)
                            .background(Color(.tertiarySystemFill))
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(16)
            .background(JWDesign.Colors.secondaryBackground)
            .clipShape(RoundedRectangle(cornerRadius: JWDesign.Radius.card))
            .shadow(color: Color.black.opacity(0.04), radius: 4, x: 0, y: 2)
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityHint(card.isDismissible ? "Double tap to open, swipe to dismiss" : "Double tap to open")
        .accessibilityAddTraits(.isButton)
    }
}

// MARK: - Previews

#Preview("Streak At Risk") {
    VStack {
        DynamicCardSlotTyped(
            cardType: .streakAtRisk(streak: 7, stepsRemaining: 3200, hoursLeft: 2),
            onDismiss: { print("Dismissed") },
            onPrimaryAction: { print("Primary action") }
        )
    }
    .padding()
    .background(Color(.systemGroupedBackground))
}

#Preview("Daily Milestone") {
    VStack {
        DynamicCardSlotTyped(
            cardType: .dailyMilestone(milestone: .first10k),
            onDismiss: { print("Dismissed") },
            onPrimaryAction: { print("Primary action") }
        )
    }
    .padding()
    .background(Color(.systemGroupedBackground))
}

#Preview("Streak Milestone") {
    VStack {
        DynamicCardSlotTyped(
            cardType: .streakMilestone(days: 30),
            onDismiss: { print("Dismissed") },
            onPrimaryAction: { print("Primary action") }
        )
    }
    .padding()
    .background(Color(.systemGroupedBackground))
}

#Preview("Pro Trial") {
    VStack {
        DynamicCardSlotTyped(
            cardType: .proTrial,
            onDismiss: { print("Dismissed") },
            onPrimaryAction: { print("Primary action") }
        )
    }
    .padding()
    .background(Color(.systemGroupedBackground))
}

#Preview("Weekly Summary") {
    VStack {
        DynamicCardSlotTyped(
            cardType: .weeklySummary(snapshot: WeeklySummaryData(
                totalSteps: 52000,
                percentChange: 15,
                isUp: true,
                bestDayName: "Saturday",
                bestDaySteps: 12500
            )),
            onDismiss: { print("Dismissed") },
            onPrimaryAction: { print("Primary action") }
        )
    }
    .padding()
    .background(Color(.systemGroupedBackground))
}

#Preview("Goal Adjustment") {
    VStack {
        DynamicCardSlotTyped(
            cardType: .goalAdjustment(currentGoal: 10000, suggestedGoal: 12000, consecutiveDays: 7),
            onDismiss: { print("Dismissed") },
            onPrimaryAction: { print("Primary action") }
        )
    }
    .padding()
    .background(Color(.systemGroupedBackground))
}

#Preview("Comeback Prompt") {
    VStack {
        DynamicCardSlotTyped(
            cardType: .comebackPrompt(daysSinceLastWalk: 5),
            onDismiss: { print("Dismissed") },
            onPrimaryAction: { print("Primary action") }
        )
    }
    .padding()
    .background(Color(.systemGroupedBackground))
}

#Preview("Watch Setup") {
    VStack {
        DynamicCardSlotTyped(
            cardType: .watchAppSetup,
            onDismiss: { print("Dismissed") },
            onPrimaryAction: { print("Primary action") }
        )
    }
    .padding()
    .background(Color(.systemGroupedBackground))
}

#Preview("Empty Slot") {
    VStack {
        Text("Above")
        DynamicCardSlotTyped(
            cardType: nil,
            onDismiss: { },
            onPrimaryAction: { }
        )
        Text("Below")
    }
    .padding()
    .background(Color(.systemGroupedBackground))
}
