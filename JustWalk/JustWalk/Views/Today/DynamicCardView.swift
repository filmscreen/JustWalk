//
//  DynamicCardView.swift
//  JustWalk
//
//  Dynamic card system — contextual cards with action callbacks (no dismiss)
//

import SwiftUI

// MARK: - Card Action

enum CardAction: Equatable {
    case navigateToIntervals
    case navigateToWalksTab
    case startPostMealWalk
    case startIntervalWalk
    case startFatBurnWalk
    case openWatchSetup
}

// MARK: - Pressable Button Style

struct PressableButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .animation(.spring(response: 0.2, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

// MARK: - Dynamic Card View

struct DynamicCardView: View {
    let cardType: DynamicCardType
    var onAction: ((CardAction) -> Void)? = nil

    var body: some View {
        Group {
            switch cardType {
            // P0 — Smart Walk Cards
            case .smartWalkPattern(let preferredMode):
                SmartWalkPatternCard(preferredMode: preferredMode, onAction: onAction)

            case .smartWalkPostMeal:
                SmartWalkPostMealCard(onAction: onAction)

            case .smartWalkEveningRescue(let stepsRemaining):
                SmartWalkEveningRescueCard(stepsRemaining: stepsRemaining, onAction: onAction)

            case .smartWalkCloseToGoal(let stepsRemaining):
                SmartWalkCloseToGoalCard(stepsRemaining: stepsRemaining, onAction: onAction)

            case .smartWalkMorning:
                SmartWalkMorningCard(onAction: onAction)

            case .smartWalkGoalMet:
                SmartWalkGoalMetCard(onAction: onAction)

            case .smartWalkDefault:
                SmartWalkDefaultCard(onAction: onAction)

            // P1 — Urgent Cards
            case .streakAtRisk(let stepsRemaining):
                StreakAtRiskCard(stepsRemaining: stepsRemaining, onAction: onAction)

            case .shieldDeployed(let remaining, let nextRefill):
                ShieldDeployedCard(remainingShields: remaining, nextRefill: nextRefill)

            case .welcomeBack:
                WelcomeBackCard(onAction: onAction)

            case .almostThere(let stepsRemaining):
                AlmostThereCard(stepsRemaining: stepsRemaining) {
                    onAction?(.navigateToWalksTab)
                }

            case .milestoneCelebration(let event):
                MilestoneCelebrationCard(event: event)

            case .tryIntervals:
                TryIntervalsCard {
                    onAction?(.navigateToWalksTab)
                }

            case .trySyncWithWatch:
                TrySyncWithWatchCard {
                    onAction?(.openWatchSetup)
                }

            case .newWeekNewGoal:
                NewWeekNewGoalCard {
                    onAction?(.navigateToWalksTab)
                }

            case .weekendWarrior:
                WeekendWarriorCard {
                    onAction?(.navigateToWalksTab)
                }

            case .eveningNudge(let stepsRemaining):
                EveningNudgeCard(stepsRemaining: stepsRemaining) {
                    onAction?(.navigateToWalksTab)
                }

            case .insight(let card):
                InsightCardView(card: card)

            case .tip(let tip):
                TipCard(tip: tip)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: JW.Radius.xl)
                .fill(JW.Color.backgroundCard)
        )
        .overlay(
            RoundedRectangle(cornerRadius: JW.Radius.xl)
                .stroke(Color.white.opacity(0.06), lineWidth: 1)
        )
    }
}

// MARK: - Weather-Enhanced Secondary Text

/// Appends weather phrase to secondary text when conditions are pleasant
private func weatherEnhancedText(_ baseText: String) -> String {
    guard let weatherPhrase = WeatherManager.shared.weatherPhrase() else {
        return baseText
    }
    return "\(baseText) \(weatherPhrase)"
}

// MARK: - Smart Walk Pattern Card

private struct SmartWalkPatternCard: View {
    let preferredMode: WalkMode
    var onAction: ((CardAction) -> Void)?

    private var modeLabel: String {
        switch preferredMode {
        case .interval: return "Interval walk"
        case .fatBurn: return "Fat burn walk"
        case .postMeal: return "Post-meal walk"
        case .free: return "Walk"
        }
    }

    private var actionForMode: CardAction {
        switch preferredMode {
        case .interval: return .startIntervalWalk
        case .fatBurn: return .startFatBurnWalk
        case .postMeal: return .startPostMealWalk
        case .free: return .navigateToWalksTab
        }
    }

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(weatherEnhancedText("You usually walk around now."))
                    .font(JW.Font.headline)
                    .foregroundStyle(JW.Color.textPrimary)

                Text("\(modeLabel)?")
                    .font(JW.Font.subheadline)
                    .foregroundStyle(JW.Color.textSecondary)
            }

            Spacer()

            Button {
                onAction?(actionForMode)
            } label: {
                Text("Let's Go →")
                    .font(JW.Font.subheadline.weight(.semibold))
                    .foregroundStyle(JW.Color.accent)
            }
            .buttonStyle(.plain)
        }
    }
}

// MARK: - Smart Walk Post-Meal Card

private struct SmartWalkPostMealCard: View {
    var onAction: ((CardAction) -> Void)?

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(weatherEnhancedText("Good time for a post-meal walk."))
                    .font(JW.Font.headline)
                    .foregroundStyle(JW.Color.textPrimary)

                Text("10 minutes helps regulate blood sugar.")
                    .font(JW.Font.subheadline)
                    .foregroundStyle(JW.Color.textSecondary)
            }

            Spacer()

            Button {
                onAction?(.startPostMealWalk)
            } label: {
                Text("Start →")
                    .font(JW.Font.subheadline.weight(.semibold))
                    .foregroundStyle(JW.Color.accent)
            }
            .buttonStyle(.plain)
        }
    }
}

// MARK: - Smart Walk Evening Rescue Card

private struct SmartWalkEveningRescueCard: View {
    let stepsRemaining: Int
    var onAction: ((CardAction) -> Void)?

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(weatherEnhancedText("A 20-minute walk closes out your day."))
                    .font(JW.Font.headline)
                    .foregroundStyle(JW.Color.textPrimary)

                Text("You're \(stepsRemaining.formatted()) steps away.")
                    .font(JW.Font.subheadline)
                    .foregroundStyle(JW.Color.textSecondary)
            }

            Spacer()

            Button {
                onAction?(.navigateToWalksTab)
            } label: {
                Text("Let's Go →")
                    .font(JW.Font.subheadline.weight(.semibold))
                    .foregroundStyle(JW.Color.accent)
            }
            .buttonStyle(.plain)
        }
    }
}

// MARK: - Smart Walk Close to Goal Card

private struct SmartWalkCloseToGoalCard: View {
    let stepsRemaining: Int
    var onAction: ((CardAction) -> Void)?

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(weatherEnhancedText("You're almost there."))
                    .font(JW.Font.headline)
                    .foregroundStyle(JW.Color.textPrimary)

                Text("A 10-minute walk wraps it up.")
                    .font(JW.Font.subheadline)
                    .foregroundStyle(JW.Color.textSecondary)
            }

            Spacer()

            Button {
                onAction?(.navigateToWalksTab)
            } label: {
                Text("Finish Strong →")
                    .font(JW.Font.subheadline.weight(.semibold))
                    .foregroundStyle(JW.Color.accent)
            }
            .buttonStyle(.plain)
        }
    }
}

// MARK: - Smart Walk Morning Card

private struct SmartWalkMorningCard: View {
    var onAction: ((CardAction) -> Void)?

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(weatherEnhancedText("Start your day with a walk?"))
                    .font(JW.Font.headline)
                    .foregroundStyle(JW.Color.textPrimary)

                Text("15 minutes to clear your head.")
                    .font(JW.Font.subheadline)
                    .foregroundStyle(JW.Color.textSecondary)
            }

            Spacer()

            Button {
                onAction?(.navigateToWalksTab)
            } label: {
                Text("Let's Go →")
                    .font(JW.Font.subheadline.weight(.semibold))
                    .foregroundStyle(JW.Color.accent)
            }
            .buttonStyle(.plain)
        }
    }
}

// MARK: - Smart Walk Goal Met Card

private struct SmartWalkGoalMetCard: View {
    var onAction: ((CardAction) -> Void)?

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text("You hit your goal.")
                        .font(JW.Font.headline)
                        .foregroundStyle(JW.Color.textPrimary)

                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(JW.Color.success)
                }

                Text("Bonus walk? Every step counts.")
                    .font(JW.Font.subheadline)
                    .foregroundStyle(JW.Color.textSecondary)
            }

            Spacer()

            Button {
                onAction?(.navigateToWalksTab)
            } label: {
                Text("Why Not →")
                    .font(JW.Font.subheadline.weight(.semibold))
                    .foregroundStyle(JW.Color.accent)
            }
            .buttonStyle(.plain)
        }
    }
}

// MARK: - Smart Walk Default Card

private struct SmartWalkDefaultCard: View {
    var onAction: ((CardAction) -> Void)?

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(weatherEnhancedText("Ready for a walk?"))
                    .font(JW.Font.headline)
                    .foregroundStyle(JW.Color.textPrimary)

                Text("Pick one and let's go.")
                    .font(JW.Font.subheadline)
                    .foregroundStyle(JW.Color.textSecondary)
            }

            Spacer()

            Button {
                onAction?(.navigateToWalksTab)
            } label: {
                Text("See Walks →")
                    .font(JW.Font.subheadline.weight(.semibold))
                    .foregroundStyle(JW.Color.accent)
            }
            .buttonStyle(.plain)
        }
    }
}

// MARK: - Streak At Risk Card

private struct StreakAtRiskCard: View {
    let stepsRemaining: Int
    var onAction: ((CardAction) -> Void)?

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Label("Streak at Risk", systemImage: "exclamationmark.triangle.fill")
                    .font(JW.Font.headline)
                    .foregroundStyle(JW.Color.streak)

                Text("\(stepsRemaining.formatted()) steps to keep your streak alive.")
                    .font(JW.Font.subheadline)
                    .foregroundStyle(JW.Color.textSecondary)
            }

            Spacer()

            Button {
                onAction?(.navigateToWalksTab)
            } label: {
                Text("See Walks →")
                    .font(JW.Font.subheadline.weight(.bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Capsule().fill(JW.Color.streak))
            }
            .buttonStyle(.plain)
        }
    }
}

// MARK: - Shield Deployed Card

private struct ShieldDeployedCard: View {
    let remainingShields: Int
    let nextRefill: String

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Label("Shield Deployed", systemImage: "shield.fill")
                    .font(JW.Font.headline)
                    .foregroundStyle(JW.Color.accentBlue)

                Text("Your streak is safe. Shield used.")
                    .font(JW.Font.subheadline)
                    .foregroundStyle(JW.Color.textSecondary)

                Label("\(remainingShields) shield\(remainingShields == 1 ? "" : "s") remaining \u{00B7} Refills \(nextRefill)", systemImage: "calendar")
                    .font(JW.Font.caption)
                    .foregroundStyle(JW.Color.textTertiary)
            }

            Spacer()

            ZStack {
                Circle()
                    .fill(JW.Color.accentBlue.opacity(0.2))
                    .frame(width: 50, height: 50)

                Image(systemName: "shield.fill")
                    .font(.title2)
                    .foregroundStyle(JW.Color.accentBlue)
            }
        }
    }
}

// MARK: - Welcome Back Card

private struct WelcomeBackCard: View {
    var onAction: ((CardAction) -> Void)?

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "arrow.uturn.backward.circle.fill")
                    .font(.title2)
                    .foregroundStyle(JW.Color.accent)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Welcome Back")
                        .font(JW.Font.headline)

                    Text("Every streak starts with one step.")
                        .font(JW.Font.subheadline)
                        .foregroundStyle(JW.Color.textSecondary)
                }

                Spacer()
            }

            Button {
                onAction?(.navigateToWalksTab)
            } label: {
                Text("Start Walking")
                    .font(JW.Font.subheadline.weight(.bold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Capsule().fill(JW.Color.accent))
            }
            .buttonStyle(PressableButtonStyle())
        }
    }
}

// MARK: - Almost There Card

private struct AlmostThereCard: View {
    let stepsRemaining: Int
    var onAction: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "flag.checkered.circle.fill")
                    .font(.title2)
                    .foregroundStyle(JW.Color.success)

                VStack(alignment: .leading, spacing: 4) {
                    Text("You're close.")
                        .font(JW.Font.headline)

                    Text("Just \(stepsRemaining.formatted()) steps to go.")
                        .font(JW.Font.subheadline)
                        .foregroundStyle(JW.Color.textSecondary)
                }

                Spacer()
            }

            Button(action: onAction) {
                Text("See Walks →")
                    .font(JW.Font.subheadline.weight(.bold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Capsule().fill(JW.Color.success))
            }
            .buttonStyle(PressableButtonStyle())
        }
    }
}

// MARK: - Milestone Celebration Card

private struct MilestoneCelebrationCard: View {
    let event: MilestoneEvent
    @State private var hasAppeared = false

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: event.sfSymbol)
                .font(.system(size: 50))
                .foregroundStyle(JW.Color.accent)
                .scaleEffect(hasAppeared ? 1.0 : 0.5)
                .opacity(hasAppeared ? 1.0 : 0.0)

            VStack(spacing: 4) {
                Text(event.headline)
                    .font(JW.Font.headline)

                Text(event.subtitle)
                    .font(JW.Font.subheadline)
                    .foregroundStyle(JW.Color.textSecondary)
            }
        }
        .frame(maxWidth: .infinity)
        .onAppear {
            withAnimation(JustWalkAnimation.celebration) {
                hasAppeared = true
            }
            JustWalkHaptics.milestone()
        }
    }
}

// MARK: - Try Intervals Card

private struct TryIntervalsCard: View {
    var onAction: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "bolt.circle.fill")
                    .font(.title2)
                    .foregroundStyle(JW.Color.accent)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Try Intervals")
                        .font(JW.Font.headline)

                    Text("Alternate fast & slow for 20% better results.")
                        .font(JW.Font.subheadline)
                        .foregroundStyle(JW.Color.textSecondary)
                }

                Spacer()
            }

            Button(action: onAction) {
                Text("See Walks →")
                    .font(JW.Font.subheadline.weight(.bold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Capsule().fill(JW.Color.accent))
            }
            .buttonStyle(PressableButtonStyle())
        }
    }
}

// MARK: - Try Sync With Watch Card

private struct TrySyncWithWatchCard: View {
    var onAction: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "applewatch.and.arrow.forward")
                    .font(.title2)
                    .foregroundStyle(JW.Color.accentBlue)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Pair Your Watch")
                        .font(JW.Font.headline)

                    Text("Get heart rate, calories & more during walks.")
                        .font(JW.Font.subheadline)
                        .foregroundStyle(JW.Color.textSecondary)
                }

                Spacer()
            }

            Button(action: onAction) {
                Text("Set Up Watch")
                    .font(JW.Font.subheadline.weight(.bold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Capsule().fill(JW.Color.accentBlue))
            }
            .buttonStyle(PressableButtonStyle())
        }
    }
}

// MARK: - New Week New Goal Card

private struct NewWeekNewGoalCard: View {
    var onAction: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "calendar.badge.plus")
                    .font(.title2)
                    .foregroundStyle(JW.Color.accent)

                VStack(alignment: .leading, spacing: 4) {
                    Text("New Week, New Goal")
                        .font(JW.Font.headline)

                    Text("Start the week strong with a walk.")
                        .font(JW.Font.subheadline)
                        .foregroundStyle(JW.Color.textSecondary)
                }

                Spacer()
            }

            Button(action: onAction) {
                Text("Let's Go")
                    .font(JW.Font.subheadline.weight(.bold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Capsule().fill(JW.Color.accent))
            }
            .buttonStyle(PressableButtonStyle())
        }
    }
}

// MARK: - Weekend Warrior Card

private struct WeekendWarriorCard: View {
    var onAction: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "sun.max.circle.fill")
                    .font(.title2)
                    .foregroundStyle(.orange)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Weekend Warrior")
                        .font(JW.Font.headline)

                    Text("Make the most of your day off.")
                        .font(JW.Font.subheadline)
                        .foregroundStyle(JW.Color.textSecondary)
                }

                Spacer()
            }

            Button(action: onAction) {
                Text("Start Walk")
                    .font(JW.Font.subheadline.weight(.bold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Capsule().fill(.orange))
            }
            .buttonStyle(PressableButtonStyle())
        }
    }
}

// MARK: - Evening Nudge Card

private struct EveningNudgeCard: View {
    let stepsRemaining: Int
    var onAction: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "moon.circle.fill")
                    .font(.title2)
                    .foregroundStyle(JW.Color.accentPurple)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Evening Check-in")
                        .font(JW.Font.headline)

                    Text("\(stepsRemaining.formatted()) steps left to hit your goal.")
                        .font(JW.Font.subheadline)
                        .foregroundStyle(JW.Color.textSecondary)
                }

                Spacer()
            }

            Button(action: onAction) {
                Text("Quick Walk")
                    .font(JW.Font.subheadline.weight(.bold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Capsule().fill(JW.Color.accentPurple))
            }
            .buttonStyle(PressableButtonStyle())
        }
    }
}

// MARK: - Insight Card (pattern-based personalization)

private struct InsightCardView: View {
    let card: InsightCard

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(card.primaryText)
                .font(JW.Font.headline)

            Text(card.secondaryText)
                .font(JW.Font.subheadline)
                .foregroundStyle(JW.Color.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Tip Card (reusable for all P3 tips)

private struct TipCard: View {
    let tip: DailyTip

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: tip.icon)
                .font(.title2)
                .foregroundStyle(JW.Color.accent)
                .frame(width: 44, height: 44)
                .background(JW.Color.accent.opacity(0.15))
                .clipShape(RoundedRectangle(cornerRadius: 12))

            VStack(alignment: .leading, spacing: 4) {
                Text(tip.title)
                    .font(JW.Font.headline)

                Text(tip.subtitle)
                    .font(JW.Font.subheadline)
                    .foregroundStyle(JW.Color.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer()
        }
    }
}

// MARK: - Previews

#Preview("All Card Types") {
    ScrollView {
        VStack(spacing: 16) {
            // P0 Smart Walk Cards
            DynamicCardView(cardType: .smartWalkPattern(preferredMode: .interval))
            DynamicCardView(cardType: .smartWalkPostMeal)
            DynamicCardView(cardType: .smartWalkEveningRescue(stepsRemaining: 2500))
            DynamicCardView(cardType: .smartWalkCloseToGoal(stepsRemaining: 800))
            DynamicCardView(cardType: .smartWalkMorning)
            DynamicCardView(cardType: .smartWalkGoalMet)
            DynamicCardView(cardType: .smartWalkDefault)

            // P1 Urgent Cards
            DynamicCardView(cardType: .streakAtRisk(stepsRemaining: 2300))
            DynamicCardView(cardType: .shieldDeployed(remainingShields: 2, nextRefill: "Feb 1"))
            DynamicCardView(cardType: .welcomeBack)

            // P2 Contextual Cards
            DynamicCardView(cardType: .almostThere(stepsRemaining: 800))
            DynamicCardView(cardType: .tryIntervals)
            DynamicCardView(cardType: .trySyncWithWatch)
            DynamicCardView(cardType: .newWeekNewGoal)
            DynamicCardView(cardType: .weekendWarrior)
            DynamicCardView(cardType: .eveningNudge(stepsRemaining: 1500))
            DynamicCardView(cardType: .milestoneCelebration(event: MilestoneEvent(
                id: "streak_14",
                tier: .tier2,
                category: .streak,
                headline: "Two Weeks Strong.",
                subtitle: "14 days — the habit is forming.",
                sfSymbol: "flame.fill"
            )))

            // P3 Tips (sample of 5)
            DynamicCardView(cardType: .tip(DailyTip.allTips[0]))  // Five Minutes Counts
            DynamicCardView(cardType: .tip(DailyTip.allTips[20])) // Mood Boost
            DynamicCardView(cardType: .tip(DailyTip.allTips[30])) // Walk It Off
            DynamicCardView(cardType: .tip(DailyTip.allTips[40])) // Consistency Wins
            DynamicCardView(cardType: .tip(DailyTip.allTips[49])) // Already a Walker
        }
        .padding()
    }
}
