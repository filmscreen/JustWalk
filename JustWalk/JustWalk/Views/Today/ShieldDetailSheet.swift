//
//  ShieldDetailSheet.swift
//  JustWalk
//
//  Half-sheet showing shield bank details, refill info, and purchase option
//

import SwiftUI
import StoreKit

struct ShieldDetailSheet: View {
    @Environment(\.dismiss) private var dismiss

    private var shieldManager = ShieldManager.shared
    private var subscriptionManager = SubscriptionManager.shared

    @State private var showPurchaseSheet = false
    @State private var showProPaywall = false


    private var shieldData: ShieldData {
        shieldManager.shieldData
    }

    private var isPro: Bool {
        subscriptionManager.isPro
    }

    private var maxBank: Int {
        ShieldData.maxBanked(isPro: isPro)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: JW.Spacing.md) {
                    heroSection
                    infoRows
                    howShieldsWorkSection
                    purchaseSection

                }
                .padding()
            }
            .navigationTitle("Shields")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .presentationDetents([.large, .medium], selection: .constant(.large))
        .presentationDragIndicator(.visible)
        .sheet(isPresented: $showPurchaseSheet) {
            ShieldPurchaseSheet(
                isPro: isPro,
                onShieldPurchased: { },
                onRequestProUpgrade: { showProPaywall = true }
            )
        }
        .sheet(isPresented: $showProPaywall) {
            ProUpgradeView(onComplete: { showProPaywall = false })
        }

    }

    // MARK: - Hero Section

    private var heroSection: some View {
        VStack(spacing: JW.Spacing.md) {
            // Shield icon
            ZStack {
                Circle()
                    .fill(JW.Color.accentBlue.opacity(0.2))
                    .frame(width: 64, height: 64)

                Image(systemName: "shield.fill")
                    .font(.system(size: 28))
                    .foregroundStyle(JW.Color.accentBlue)
            }

            // Count
            VStack(spacing: 2) {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text("\(shieldData.availableShields)")
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                        .contentTransition(.numericText(value: Double(shieldData.availableShields)))

                    Text("of \(maxBank)")
                        .font(JW.Font.subheadline)
                        .foregroundStyle(JW.Color.textSecondary)
                }

                Text("shields available")
                    .font(JW.Font.caption)
                    .foregroundStyle(JW.Color.textTertiary)
            }

            // Bank visualization
            HStack(spacing: 6) {
                ForEach(0..<maxBank, id: \.self) { index in
                    Image(systemName: index < shieldData.availableShields ? "shield.fill" : "shield")
                        .font(.body)
                        .foregroundStyle(index < shieldData.availableShields ? JW.Color.accentBlue : JW.Color.backgroundTertiary)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, JW.Spacing.sm)
    }

    // MARK: - Info Rows

    private var infoRows: some View {
        VStack(spacing: 0) {
            InfoRow(label: "Monthly Refill", value: isPro ? "4 shields/month" : "None (Pro to get more)")
            Divider().padding(.horizontal)
            InfoRow(label: "Next Refill", value: shieldManager.nextRefillDateFormatted)
            Divider().padding(.horizontal)
            InfoRow(label: "Used This Month", value: "\(shieldData.shieldsUsedThisMonth)")
            Divider().padding(.horizontal)
            InfoRow(label: "Lifetime Used", value: "\(shieldData.totalShieldsUsed)")
        }
        .background(
            RoundedRectangle(cornerRadius: JW.Radius.lg)
                .fill(JW.Color.backgroundCard)
        )
    }

    // MARK: - How Shields Work

    private var howShieldsWorkSection: some View {
        VStack(alignment: .leading, spacing: JW.Spacing.sm) {
            Text("How Shields Work")
                .font(JW.Font.caption.bold())
                .foregroundStyle(JW.Color.textSecondary)
                .textCase(.uppercase)

            VStack(alignment: .leading, spacing: 8) {
                BulletPoint(text: "Use a shield to protect your streak when you miss a day")
                BulletPoint(text: "Keeps your streak alive — no guilt, no pressure")
                if isPro {
                    BulletPoint(text: "Pro members get 4 shields/month, bank up to 8")
                } else {
                    BulletPoint(text: "Free members get 2 shields to start (no refills)")
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var purchaseSection: some View {
        Group {
            if shieldData.availableShields == 0 {
                Button {
                    JustWalkHaptics.buttonTap()
                    showPurchaseSheet = true
                } label: {
                    HStack {
                        Image(systemName: "shield.fill")
                        Text(isPro ? "Buy Shield" : "Get More Shields")
                            .font(JW.Font.headline)
                        Spacer()
                        Text(subscriptionManager.shieldDisplayPrice)
                            .font(JW.Font.subheadline.weight(.semibold))
                    }
                    .foregroundStyle(.white)
                    .padding()
                    .background(JW.Color.accentBlue)
                    .clipShape(RoundedRectangle(cornerRadius: JW.Radius.lg))
                }
                .padding(.top, JW.Spacing.sm)
            }
        }
    }


}

// MARK: - Info Row

private struct InfoRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .font(JW.Font.subheadline)
                .foregroundStyle(JW.Color.textSecondary)
            Spacer()
            Text(value)
                .font(JW.Font.subheadline.weight(.medium))
                .foregroundStyle(JW.Color.textPrimary)
        }
        .padding(.horizontal)
        .padding(.vertical, 12)
    }
}

// MARK: - Bullet Point

private struct BulletPoint: View {
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Circle()
                .fill(JW.Color.accentBlue)
                .frame(width: 6, height: 6)
                .padding(.top, 6)

            Text(text)
                .font(JW.Font.caption)
                .foregroundStyle(JW.Color.textSecondary)
        }
    }
}

#Preview {
    ShieldDetailSheet()
}
