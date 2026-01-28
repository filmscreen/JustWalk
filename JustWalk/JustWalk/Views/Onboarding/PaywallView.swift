//
//  PaywallView.swift
//  JustWalk
//
//  Two-screen Pro paywall: benefits showcase → plan selection
//

import SwiftUI
import StoreKit

struct PaywallView: View {
    let onComplete: () -> Void

    @StateObject private var subscriptionManager = SubscriptionManager.shared
    @State private var screen: PaywallScreen = .benefits
    @State private var selectedPlan: String? = SubscriptionManager.proAnnualID

    private enum PaywallScreen {
        case benefits, plans
    }

    // MARK: - Discount Calculation

    private var discountPercent: Int {
        guard let monthly = subscriptionManager.proMonthlyProduct,
              let yearly = subscriptionManager.proAnnualProduct else { return 0 }
        let monthlyAnnualized = monthly.price * 12
        guard monthlyAnnualized > 0 else { return 0 }
        let savings = monthlyAnnualized - yearly.price
        let percent = savings / monthlyAnnualized * 100
        return Int(NSDecimalNumber(decimal: percent).doubleValue.rounded())
    }

    private var discountCTALabel: String {
        let pct = discountPercent
        return pct > 0 ? "GET \(pct)% OFF" : "Get Pro"
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            JW.Color.backgroundPrimary.ignoresSafeArea()

            if screen == .benefits {
                benefitsScreen
                    .transition(.move(edge: .leading))
            }

            if screen == .plans {
                plansScreen
                    .transition(.move(edge: .trailing))
            }
        }
        .task {
            await subscriptionManager.loadProducts()
        }
    }

    // MARK: - Screen 1: Benefits

    private var benefitsScreen: some View {
        VStack(spacing: JW.Spacing.xl) {
            Spacer()

            // Hero icon with glow
            ZStack {
                Circle()
                    .fill(JW.Color.accent.opacity(0.2))
                    .frame(width: 120, height: 120)
                    .blur(radius: 20)

                Image(systemName: "shield.checkered")
                    .font(.system(size: 56))
                    .foregroundStyle(JW.Color.accent)
            }

            // Headline + subtitle
            VStack(spacing: 6) {
                Text("Protect Your Streak")
                    .font(JW.Font.title1)
                    .foregroundStyle(JW.Color.textPrimary)

                Text("Unlimited walks. More shields. Full history.")
                    .font(JW.Font.subheadline)
                    .foregroundStyle(JW.Color.textSecondary)
            }

            // Benefit rows
            VStack(alignment: .leading, spacing: JW.Spacing.lg) {
                ProBenefitRow(icon: "bolt.fill", title: "Unlimited Guided Walks", color: JW.Color.accent)
                ProBenefitRow(icon: "shield.fill", title: "More Protection", color: JW.Color.streak)
                ProBenefitRow(icon: "chart.bar.fill", title: "Full History", color: JW.Color.accentPurple)
            }
            .padding(.horizontal, JW.Spacing.xl)

            Spacer()

            // CTA
            Button {
                withAnimation(.easeInOut(duration: 0.35)) {
                    screen = .plans
                }
            } label: {
                Text(discountCTALabel)
                    .font(JW.Font.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(JW.Color.accent)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: JW.Radius.lg))
            }
            .buttonPressEffect()
            .padding(.horizontal, JW.Spacing.xl)

            // Skip
            Button("Skip Offer") {
                onComplete()
            }
            .font(JW.Font.subheadline)
            .foregroundStyle(JW.Color.textSecondary)
            .padding(.bottom, JW.Spacing.xxxl)
        }
    }

    // MARK: - Screen 2: Plans

    private var plansScreen: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: JW.Spacing.xl) {
                // Back button
                HStack {
                    Button {
                        withAnimation(.easeInOut(duration: 0.35)) {
                            screen = .benefits
                        }
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(JW.Font.title3)
                            .foregroundStyle(JW.Color.textPrimary)
                    }
                    Spacer()
                }
                .padding(.horizontal, JW.Spacing.xl)
                .padding(.top, JW.Spacing.lg)

                // Headline
                Text("Choose Your Plan")
                    .font(JW.Font.title1)
                    .foregroundStyle(JW.Color.textPrimary)

                // Plan cards
                VStack(spacing: JW.Spacing.md) {
                    if let yearly = subscriptionManager.proAnnualProduct {
                        PlanCard(
                            product: yearly,
                            isSelected: selectedPlan == yearly.id,
                            badge: discountPercent > 0 ? "SAVE \(discountPercent)%" : nil,
                            subtitle: monthlyEquivalent(for: yearly),
                            periodLabel: "per year",
                            onSelect: { selectedPlan = yearly.id }
                        )
                    }

                    if let monthly = subscriptionManager.proMonthlyProduct {
                        PlanCard(
                            product: monthly,
                            isSelected: selectedPlan == monthly.id,
                            badge: nil,
                            subtitle: nil,
                            periodLabel: "per month",
                            onSelect: { selectedPlan = monthly.id }
                        )
                    }
                }
                .padding(.horizontal, JW.Spacing.xl)

                // CTA
                Button {
                    Task {
                        if let planID = selectedPlan,
                           let product = subscriptionManager.products.first(where: { $0.id == planID }) {
                            try? await subscriptionManager.purchase(product)
                        }
                        onComplete()
                    }
                } label: {
                    Text(selectedPlan == SubscriptionManager.proAnnualID ? discountCTALabel : "Subscribe")
                        .font(JW.Font.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(JW.Color.accent)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: JW.Radius.lg))
                }
                .buttonPressEffect()
                .padding(.horizontal, JW.Spacing.xl)

                // Legal disclosure
                Text("Payment is charged to your Apple ID account at confirmation of purchase. Subscription automatically renews unless canceled at least 24 hours before the end of the current period. Manage subscriptions in Settings > Apple ID > Subscriptions.")
                    .font(JW.Font.caption2)
                    .foregroundStyle(JW.Color.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, JW.Spacing.xl)

                // Links
                HStack(spacing: 4) {
                    Link("Terms of Service", destination: URL(string: "https://onworldtech.com/justwalk/terms")!)
                    Text("·")
                        .foregroundStyle(.secondary)
                    Link("Privacy Policy", destination: URL(string: "https://onworldtech.com/justwalk/privacy")!)
                }
                .font(.caption)
                .foregroundStyle(.secondary)

                // Restore
                Button("Restore Purchases") {
                    Task {
                        await subscriptionManager.restorePurchases()
                    }
                }
                .font(JW.Font.caption)
                .foregroundStyle(JW.Color.textSecondary)

                // Dismiss
                Button("Maybe Later") {
                    onComplete()
                }
                .font(JW.Font.subheadline)
                .foregroundStyle(JW.Color.textSecondary)
                .padding(.bottom, JW.Spacing.xxxl)
            }
        }
    }

    // MARK: - Helpers

    private func monthlyEquivalent(for yearly: Product) -> String {
        let monthly = yearly.price / 12
        return "(Just \(monthly.formatted(yearly.priceFormatStyle))/mo)"
    }
}

// MARK: - Pro Benefit Row

private struct ProBenefitRow: View {
    let icon: String
    let title: String
    let color: Color

    var body: some View {
        HStack(spacing: JW.Spacing.lg) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.15))
                    .frame(width: 44, height: 44)

                Image(systemName: icon)
                    .font(JW.Font.title3)
                    .foregroundStyle(color)
            }

            Text(title)
                .font(JW.Font.headline)
                .foregroundStyle(JW.Color.textPrimary)
        }
    }
}

// MARK: - Plan Card

private struct PlanCard: View {
    let product: Product
    let isSelected: Bool
    let badge: String?
    let subtitle: String?
    let periodLabel: String
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            VStack(alignment: .leading, spacing: JW.Spacing.xs) {
                if let badge {
                    Text(badge)
                        .font(JW.Font.caption.weight(.bold))
                        .foregroundStyle(JW.Color.accent)
                }

                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(product.displayPrice) \(periodLabel)")
                            .font(JW.Font.headline)
                            .foregroundStyle(JW.Color.textPrimary)

                        if let subtitle {
                            Text(subtitle)
                                .font(JW.Font.caption)
                                .foregroundStyle(JW.Color.textSecondary)
                        }
                    }

                    Spacer()

                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(isSelected ? JW.Color.accent : JW.Color.textSecondary)
                        .font(JW.Font.title2)
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: JW.Radius.md)
                    .fill(isSelected ? JW.Color.accent.opacity(0.1) : JW.Color.backgroundCard)
            )
            .overlay(
                RoundedRectangle(cornerRadius: JW.Radius.md)
                    .stroke(isSelected ? JW.Color.accent : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    PaywallView(onComplete: {})
}
