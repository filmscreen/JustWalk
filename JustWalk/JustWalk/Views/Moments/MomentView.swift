//
//  MomentView.swift
//  JustWalk
//
//  Typography-driven emotional moments
//  Simple. Quiet. Earned.
//

import SwiftUI

struct MomentView: View {
    let moment: EmotionalMoment
    let onContinue: () -> Void

    @State private var showContent = false
    @State private var showButton = false
    @State private var allowDismiss = false  // Prevent accidental taps on appear

    private var accentOpacity: Double {
        // Day 365 gets strongest accent, others subtle
        if case .milestone(let days) = moment, days >= 365 {
            return 0.20
        }
        if case .milestone(let days) = moment, days >= 100 {
            return 0.15
        }
        return 0.10
    }

    var body: some View {
        ZStack {
            // Background - app's dark background with subtle radial gradient
            ZStack {
                JW.Color.backgroundPrimary
                    .ignoresSafeArea()

                // Subtle radial gradient - lighter center, darker edges
                RadialGradient(
                    colors: [
                        JW.Color.accent.opacity(accentOpacity),
                        Color.clear
                    ],
                    center: .center,
                    startRadius: 0,
                    endRadius: 300
                )
                .ignoresSafeArea()
            }

            // Tap anywhere to continue (with delay to prevent accidental taps)
            Color.clear
                .contentShape(Rectangle())
                .onTapGesture {
                    guard allowDismiss else { return }
                    dismiss()
                }

            // Content
            VStack(spacing: 0) {
                Spacer()

                contentView
                    .opacity(showContent ? 1 : 0)
                    .scaleEffect(showContent ? 1 : 0.95)

                Spacer()

                // Continue button - understated, brand green
                Button {
                    guard allowDismiss else { return }
                    dismiss()
                } label: {
                    Text("Continue")
                        .font(JW.Font.body)
                        .foregroundStyle(JW.Color.accent)
                }
                .opacity(showButton ? 1 : 0)
                .disabled(!allowDismiss)
                .padding(.bottom, 60)
            }
            .frame(maxWidth: 280)
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.3)) {
                showContent = true
            }
            withAnimation(.easeOut(duration: 0.3).delay(0.2)) {
                showButton = true
            }
            JustWalkHaptics.success()

            // Allow dismissal after a short delay to prevent accidental taps
            // from propagating gestures during view transition
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                allowDismiss = true
            }
        }
    }

    @ViewBuilder
    private var contentView: some View {
        let content = moment.content

        VStack(spacing: 8) {
            // Primary text
            if moment.isLargeNumber {
                // Special treatment for "100" - large number
                Text(content.primaryText)
                    .font(.system(size: 72, weight: .bold, design: .default))
                    .foregroundStyle(JW.Color.textPrimary)
                    .multilineTextAlignment(.center)
            } else {
                Text(content.primaryText)
                    .font(JW.Font.largeTitle.bold())
                    .foregroundStyle(JW.Color.textPrimary)
                    .multilineTextAlignment(.center)
            }

            // Secondary text
            if let secondary = content.secondaryText {
                Text(secondary)
                    .font(JW.Font.title3)
                    .foregroundStyle(JW.Color.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.top, moment.isLargeNumber ? 0 : 4)
            }

            // Tertiary text (for comebackWithRecord and 365)
            if let tertiary = content.tertiaryText {
                Text(tertiary)
                    .font(JW.Font.body)
                    .foregroundStyle(JW.Color.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.top, 12)
            }
        }
    }

    private func dismiss() {
        withAnimation(.easeIn(duration: 0.2)) {
            showContent = false
            showButton = false
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            onContinue()
        }
    }
}

// MARK: - Helpers

private extension EmotionalMoment {
    var isLargeNumber: Bool {
        if case .milestone(let days) = self, days == 100 {
            return true
        }
        return false
    }
}

// MARK: - Previews

#Preview("First Walk") {
    MomentView(moment: .firstWalk) { }
}

#Preview("Clutch Save") {
    MomentView(moment: .clutchSave) { }
}

#Preview("Under The Wire") {
    MomentView(moment: .underTheWire) { }
}

#Preview("Comeback") {
    MomentView(moment: .comeback) { }
}

#Preview("Comeback With Record") {
    MomentView(moment: .comebackWithRecord(days: 47)) { }
}

#Preview("7 Day Milestone") {
    MomentView(moment: .milestone(days: 7)) { }
}

#Preview("30 Day Milestone") {
    MomentView(moment: .milestone(days: 30)) { }
}

#Preview("100 Day Milestone") {
    MomentView(moment: .milestone(days: 100)) { }
}

#Preview("365 Day Milestone") {
    MomentView(moment: .milestone(days: 365)) { }
}

#Preview("Walk Complete") {
    MomentView(moment: .walkComplete(minutes: 18, steps: 1847, goalHit: false, streakDay: nil)) { }
}

#Preview("Walk Complete - Goal Hit") {
    MomentView(moment: .walkComplete(minutes: 18, steps: 1847, goalHit: true, streakDay: nil)) { }
}

#Preview("Walk Complete - Streak Day") {
    MomentView(moment: .walkComplete(minutes: 18, steps: 1847, goalHit: false, streakDay: 24)) { }
}
