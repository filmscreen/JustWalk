//
//  GoalConfirmationView.swift
//  Just Walk
//
//  Confirmation view after goal selection showing Start Walking
//  and optional Route Generation buttons.
//

import SwiftUI

struct GoalConfirmationView: View {
    let goal: WalkGoal
    let isPro: Bool
    let canGenerateRoute: Bool
    let isGeneratingRoute: Bool
    var onStartWalk: () -> Void = {}
    var onGenerateRoute: () -> Void = {}
    var onChangeGoal: () -> Void = {}
    var onShowPaywall: () -> Void = {}

    private let tealAccent = Color(hex: "00C7BE")

    var body: some View {
        VStack(spacing: 24) {
            // Goal display with checkmark
            goalDisplay

            // Primary: Start Walking button
            startWalkingButton

            // Divider with "or get a route"
            routeDivider

            // Secondary: Generate Route button
            generateRouteButton

            // Free tier note (if not pro)
            if !isPro {
                freeTierNote
            }

            // Change goal link
            changeGoalButton
        }
    }

    // MARK: - Goal Display

    private var goalDisplay: some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 24))
                .foregroundStyle(tealAccent)

            Text(goalDisplayText)
                .font(.system(size: 20, weight: .semibold))
        }
        .padding(.vertical, 16)
        .padding(.horizontal, 20)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemGray6))
        )
    }

    private var goalDisplayText: String {
        switch goal.type {
        case .time:
            return "\(Int(goal.target)) minute walk"
        case .distance:
            if goal.target == floor(goal.target) {
                return "\(Int(goal.target)) mile walk"
            }
            return String(format: "%.1f mile walk", goal.target)
        case .steps:
            return "\(Int(goal.target).formatted()) step walk"
        case .none:
            return "Open walk"
        }
    }

    // MARK: - Start Walking Button

    private var startWalkingButton: some View {
        Button {
            onStartWalk()
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "figure.walk")
                    .font(.system(size: 18, weight: .semibold))
                Text("Start Walking")
                    .font(.system(size: 17, weight: .semibold))
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(tealAccent)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Route Divider

    private var routeDivider: some View {
        HStack(spacing: 12) {
            Rectangle()
                .fill(Color(.separator))
                .frame(height: 1)

            Text("or get a route")
                .font(.system(size: 13))
                .foregroundStyle(.secondary)

            Rectangle()
                .fill(Color(.separator))
                .frame(height: 1)
        }
    }

    // MARK: - Generate Route Button

    private var generateRouteButton: some View {
        Button {
            if !isPro && !canGenerateRoute {
                onShowPaywall()
            } else {
                onGenerateRoute()
            }
        } label: {
            VStack(spacing: 6) {
                HStack(spacing: 10) {
                    if isGeneratingRoute {
                        ProgressView()
                            .tint(tealAccent)
                    } else {
                        Image(systemName: "mappin.and.ellipse")
                            .font(.system(size: 16, weight: .semibold))
                    }
                    Text(isGeneratingRoute ? "Generating..." : "Generate a Route")
                        .font(.system(size: 16, weight: .semibold))
                }
                .foregroundStyle(tealAccent)

                Text(routeSubtitle)
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(tealAccent, lineWidth: 1.5)
            )
        }
        .buttonStyle(.plain)
        .disabled(isGeneratingRoute)
    }

    private var routeSubtitle: String {
        let estimatedDistance = WalkGoalPresets.estimatedDistance(for: goal)
        switch goal.type {
        case .time:
            return "We'll create a ~\(Int(goal.target)) min loop"
        case .distance:
            if goal.target == floor(goal.target) {
                return "We'll create a ~\(Int(goal.target)) mi loop"
            }
            return String(format: "We'll create a ~%.1f mi loop", goal.target)
        case .steps:
            return String(format: "We'll create a ~%.1f mi loop", estimatedDistance)
        case .none:
            return "We'll create a walking loop for you"
        }
    }

    // MARK: - Free Tier Note

    private var freeTierNote: some View {
        HStack(spacing: 6) {
            Image(systemName: "star.fill")
                .font(.system(size: 12))
                .foregroundStyle(.yellow)

            Text(canGenerateRoute ? "1 free route per day" : "Free route used today")
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Change Goal Button

    private var changeGoalButton: some View {
        Button {
            HapticService.shared.playSelection()
            onChangeGoal()
        } label: {
            Text("Change goal")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(tealAccent)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Preview

#Preview("Can Generate Route") {
    GoalConfirmationView(
        goal: .time(minutes: 30.0),
        isPro: false,
        canGenerateRoute: true,
        isGeneratingRoute: false
    )
    .padding()
}

#Preview("Route Used") {
    GoalConfirmationView(
        goal: .distance(miles: 2.0),
        isPro: false,
        canGenerateRoute: false,
        isGeneratingRoute: false
    )
    .padding()
}

#Preview("Pro User") {
    GoalConfirmationView(
        goal: .steps(count: 5000.0),
        isPro: true,
        canGenerateRoute: true,
        isGeneratingRoute: false
    )
    .padding()
}

#Preview("Generating") {
    GoalConfirmationView(
        goal: .time(minutes: 45.0),
        isPro: true,
        canGenerateRoute: true,
        isGeneratingRoute: true
    )
    .padding()
}
