//
//  WalkBottomSheet.swift
//  Just Walk
//
//  Bottom sheet container for Walk tab with action cards.
//  Anchored to bottom with rounded top corners and shadow.
//

import SwiftUI

struct WalkBottomSheet: View {
    @ObservedObject var viewModel: WalkLandingViewModel
    @ObservedObject private var subscriptionManager = SubscriptionManager.shared

    var onJustWalkTap: () -> Void
    var onGoalWalkTap: () -> Void = {}
    var onIntervalTap: () -> Void = {}
    var onPostMealTap: () -> Void = {}
    var onSavedRoutes: () -> Void = {}

    private var isPro: Bool { subscriptionManager.isPro }
    private var savedRoutesCount: Int { SavedRouteManager.shared.savedRoutes.count }

    var body: some View {
        VStack(spacing: 16) {
            // Step header (left-aligned) - directly observes StepRepository
            WalkTabHeader()
                .frame(maxWidth: .infinity, alignment: .leading)

            // 1. Just Walk (teal, primary)
            justWalkButton

            // 2. Walk with a Goal (outlined)
            goalWalkButton

            // 3. Interval Mode (outlined + PRO badge)
            intervalButton

            // 4. Post-Meal Walk (outlined, green, always free)
            postMealButton

            // 5. Saved Routes (text link)
            savedRoutesLink

            // Last walk (only if meaningful)
            LastWalkSummary()
                .padding(.top, 4)
        }
        .padding(.horizontal, 20)
        .padding(.top, 24)
        .padding(.bottom, 100)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.15), radius: 20, y: -8)
        )
    }

    // MARK: - Just Walk Button (Teal, Primary)

    private var justWalkButton: some View {
        Button {
            onJustWalkTap()
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "figure.walk")
                    .font(.system(size: 24, weight: .semibold))

                VStack(alignment: .leading, spacing: 2) {
                    Text("Just Walk")
                        .font(.system(size: 17, weight: .semibold))
                    Text("Start walking, no goal")
                        .font(.system(size: 14))
                        .opacity(0.9)
                }

                Spacer()
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 16)
            .frame(maxWidth: .infinity)
            .background(Color(hex: "00C7BE"))
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
        .buttonStyle(.plain)
        .hapticOnTap(.buttonTap)
    }

    // MARK: - Goal Walk Button (Outlined)

    private var goalWalkButton: some View {
        Button {
            onGoalWalkTap()
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "target")
                    .font(.system(size: 24, weight: .semibold))

                VStack(alignment: .leading, spacing: 2) {
                    Text("Walk with a Goal")
                        .font(.system(size: 17, weight: .semibold))
                    Text("Set a time, distance, or steps")
                        .font(.system(size: 14))
                }

                Spacer()
            }
            .foregroundStyle(Color(hex: "00C7BE"))
            .padding(.horizontal, 16)
            .padding(.vertical, 16)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(Color(hex: "00C7BE"), lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
        .hapticOnTap(.buttonTap)
    }

    // MARK: - Interval Mode Button (Outlined + PRO badge)

    private var intervalButton: some View {
        Button {
            onIntervalTap()
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "bolt.fill")
                    .font(.system(size: 24, weight: .semibold))

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 8) {
                        Text("Interval Mode")
                            .font(.system(size: 17, weight: .semibold))

                        if !isPro {
                            Text("PRO")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color(hex: "FF9500"))
                                .clipShape(Capsule())
                        }
                    }
                    Text("Burn 20% more with pacing cues")
                        .font(.system(size: 14))
                }

                Spacer()
            }
            .foregroundStyle(isPro ? Color(hex: "FF9500") : .secondary)
            .padding(.horizontal, 16)
            .padding(.vertical, 16)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(isPro ? Color(hex: "FF9500") : Color.secondary.opacity(0.3), lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
        .hapticOnTap(.buttonTap)
    }

    // MARK: - Post-Meal Walk Button (Outlined, Green)

    private var postMealButton: some View {
        Button {
            onPostMealTap()
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "fork.knife")
                    .font(.system(size: 24, weight: .semibold))

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 8) {
                        Text("Post-Meal Walk")
                            .font(.system(size: 17, weight: .semibold))

                        Text("FREE")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color(hex: "34C759"))
                            .clipShape(Capsule())
                    }
                    Text("10 min walk to aid digestion")
                        .font(.system(size: 14))
                }

                Spacer()
            }
            .foregroundStyle(Color(hex: "34C759"))
            .padding(.horizontal, 16)
            .padding(.vertical, 16)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(Color(hex: "34C759"), lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
        .hapticOnTap(.buttonTap)
    }

    // MARK: - Saved Routes Link

    private var savedRoutesLink: some View {
        Button {
            HapticService.shared.playSelection()
            onSavedRoutes()
        } label: {
            HStack(spacing: 4) {
                Text(savedRoutesCount > 0 ? "Saved Routes (\(savedRoutesCount))" : "Saved Routes")
                    .font(.system(size: 15, weight: .medium))
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
            }
            .foregroundStyle(.secondary)
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(.top, 4)
    }
}

// MARK: - Preview

#Preview("Steps to Go") {
    ZStack {
        Color(.secondarySystemBackground)
            .ignoresSafeArea()
        VStack {
            Spacer()
            WalkBottomSheet(
                viewModel: WalkLandingViewModel(),
                onJustWalkTap: {}
            )
        }
    }
}
