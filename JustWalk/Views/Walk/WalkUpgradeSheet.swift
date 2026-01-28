//
//  WalkUpgradeSheet.swift
//  JustWalk
//
//  Soft upgrade prompt when free user exhausts weekly sessions for any gated walk type
//

import SwiftUI

struct WalkUpgradeSheet: View {
    let walkTypeName: String
    let icon: String
    let iconColor: Color
    let weeklyLimit: Int
    let upgradeMessage: String
    let onUpgrade: () -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: JW.Spacing.xl) {
            Image(systemName: icon)
                .font(.system(size: 48))
                .foregroundStyle(iconColor)

            VStack(spacing: JW.Spacing.sm) {
                Text(walkTypeName)
                    .font(JW.Font.title2)
                    .foregroundStyle(JW.Color.textPrimary)

                Text(upgradeMessage)
                    .font(JW.Font.subheadline)
                    .foregroundStyle(JW.Color.textSecondary)
                    .multilineTextAlignment(.center)
            }

            Spacer()

            VStack(spacing: JW.Spacing.md) {
                Button(action: {
                    dismiss()
                    onUpgrade()
                }) {
                    Text("Upgrade to Pro")
                        .font(JW.Font.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(JW.Color.accent)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: JW.Radius.lg))
                }
                .buttonPressEffect()

                Button("Maybe Later") {
                    dismiss()
                }
                .font(JW.Font.subheadline)
                .foregroundStyle(JW.Color.textSecondary)
            }
        }
        .padding(JW.Spacing.xl)
        .background(JW.Color.backgroundPrimary)
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
    }

    // MARK: - Convenience Factories

    static func interval(onUpgrade: @escaping () -> Void) -> WalkUpgradeSheet {
        WalkUpgradeSheet(
            walkTypeName: "Free Interval Used",
            icon: "bolt.circle.fill",
            iconColor: JW.Color.accent,
            weeklyLimit: IntervalUsageData.freeWeeklyLimit,
            upgradeMessage: "You've used your free Interval walk this week. Go Pro for unlimited walks.",
            onUpgrade: onUpgrade
        )
    }

    static func fatBurn(onUpgrade: @escaping () -> Void) -> WalkUpgradeSheet {
        WalkUpgradeSheet(
            walkTypeName: "Free Fat Burn Used",
            icon: "heart.circle.fill",
            iconColor: JW.Color.streak,
            weeklyLimit: FatBurnUsageData.freeWeeklyLimit,
            upgradeMessage: "You've used your free Fat Burn walk this week. Go Pro for unlimited walks.",
            onUpgrade: onUpgrade
        )
    }
}

#Preview("Interval") {
    WalkUpgradeSheet.interval(onUpgrade: {})
}

#Preview("Fat Burn") {
    WalkUpgradeSheet.fatBurn(onUpgrade: {})
}
