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
                VStack(spacing: JW.Spacing.lg) {
                    // Hero section with more breathing room
                    heroSection
                        .padding(.top, JW.Spacing.md)

                    // Info rows in card
                    infoRows

                    // How shields work section in card
                    howShieldsWorkSection
                        .padding(.horizontal, JW.Spacing.md)
                        .padding(.vertical, JW.Spacing.md)
                        .background(
                            RoundedRectangle(cornerRadius: JW.Radius.lg)
                                .fill(JW.Color.backgroundCard)
                        )

                    purchaseSection
                }
                .padding(.horizontal, JW.Spacing.lg)
                .padding(.top, JW.Spacing.md)
                .padding(.bottom, JW.Spacing.xl)
            }
            .background(JW.Color.backgroundPrimary)
            .navigationTitle("Shields")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .toolbarBackground(JW.Color.backgroundPrimary, for: .navigationBar)
        }
        .presentationDetents([.large, .medium], selection: .constant(.large))
        .presentationDragIndicator(.visible)
        .presentationBackground(JW.Color.backgroundPrimary)
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
        VStack(spacing: JW.Spacing.sm) {
            // Shield icon - large centered circle
            ZStack {
                Circle()
                    .fill(JW.Color.accentBlue.opacity(0.3))
                    .frame(width: 88, height: 88)

                Text("🛡️")
                    .font(.system(size: 40))
            }

            // Count display
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text("\(shieldData.availableShields)")
                    .font(.system(size: 48, weight: .bold, design: .rounded))
                    .contentTransition(.numericText(value: Double(shieldData.availableShields)))

                Text("of \(maxBank)")
                    .font(JW.Font.title3)
                    .foregroundStyle(JW.Color.textSecondary)
            }

            // "shields available" label
            Text("shields available")
                .font(JW.Font.subheadline)
                .foregroundStyle(JW.Color.textSecondary)

            // Bank visualization
            HStack(spacing: 8) {
                ForEach(0..<maxBank, id: \.self) { index in
                    Image(systemName: index < shieldData.availableShields ? "shield.fill" : "shield")
                        .font(.system(size: 20))
                        .foregroundStyle(index < shieldData.availableShields ? JW.Color.accentBlue : JW.Color.backgroundTertiary)
                }
            }
            .padding(.top, JW.Spacing.xs)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, JW.Spacing.md)
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
                .foregroundStyle(JW.Color.textTertiary)
                .textCase(.uppercase)

            VStack(alignment: .leading, spacing: 6) {
                BulletPoint(text: "Protect your streak when you miss a day")
                BulletPoint(text: "No guilt, no pressure")
                if isPro {
                    BulletPoint(text: "Pro: 4 shields/month, bank up to 8")
                } else {
                    BulletPoint(text: "Free: 2 shields to start (no refills)")
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
                .font(JW.Font.body)
                .foregroundStyle(JW.Color.textSecondary)
            Spacer()
            Text(value)
                .font(JW.Font.body.weight(.medium))
                .foregroundStyle(JW.Color.textPrimary)
        }
        .padding(.horizontal, JW.Spacing.lg)
        .padding(.vertical, JW.Spacing.md)
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
                .font(JW.Font.subheadline)
                .foregroundStyle(JW.Color.textSecondary)
        }
    }
}

#Preview {
    ShieldDetailSheet()
}
