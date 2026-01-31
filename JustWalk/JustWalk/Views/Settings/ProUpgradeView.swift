//
//  ProUpgradeView.swift
//  JustWalk
//
//  Respectful Pro upgrade screen — clear value, honest pricing, no pressure
//

import SwiftUI
import StoreKit

struct ProUpgradeView: View {
    let onComplete: () -> Void
    let showsCloseButton: Bool

    init(onComplete: @escaping () -> Void, showsCloseButton: Bool = true) {
        self.onComplete = onComplete
        self.showsCloseButton = showsCloseButton
    }

    @StateObject private var subscriptionManager = SubscriptionManager.shared
    @State private var selectedPlan: String = SubscriptionManager.proAnnualID
    @State private var isPurchasing = false
    @State private var isRestoring = false
    @State private var showSuccess = false
    @State private var successCheckScale: CGFloat = 0

    // Alerts
    @State private var showErrorAlert = false
    @State private var errorMessage = ""
    @State private var showNoRestoreAlert = false

    // Entrance animation state
    @State private var showHero = false
    @State private var showPricing = false
    @State private var showCTA = false
    @State private var showFooter = false

    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // MARK: - Discount Calculation

    private var discountPercent: Int {
        guard let monthly = subscriptionManager.proMonthlyProduct,
              let annual = subscriptionManager.proAnnualProduct else { return 0 }
        let monthlyAnnualized = monthly.price * 12
        guard monthlyAnnualized > 0 else { return 0 }
        let savings = monthlyAnnualized - annual.price
        let percent = savings / monthlyAnnualized * 100
        return Int(NSDecimalNumber(decimal: percent).doubleValue.rounded())
    }

    private func annualMonthlyEquivalent(for annual: Product) -> String {
        let monthly = annual.price / 12
        return "\(monthly.formatted(annual.priceFormatStyle))/month"
    }

    // MARK: - Price Labels (with fallbacks when StoreKit products unavailable)

    private var monthlyPriceLabel: String {
        if let monthly = subscriptionManager.proMonthlyProduct {
            return "\(monthly.displayPrice)/month"
        }
        return "$4.99/month"
    }

    private var annualPriceLabel: String {
        if let annual = subscriptionManager.proAnnualProduct {
            return "\(annual.displayPrice)/year"
        }
        return "$29.99/year"
    }

    private var annualSubtitleLabel: String {
        if let annual = subscriptionManager.proAnnualProduct {
            return "\(annualMonthlyEquivalent(for: annual)) · Save \(discountPercent)%"
        }
        return "$2.50/month · Save 50%"
    }

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                // MARK: Scrollable content (title + benefit cards)
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 0) {
                        // Hero section
                        VStack(spacing: JW.Spacing.md) {
                            Text("Just Walk Pro")
                                .font(JW.Font.largeTitle)
                                .foregroundStyle(JW.Color.textPrimary)
                                .multilineTextAlignment(.center)

                            Text("More walks. More protection. Full history.")
                                .font(JW.Font.subheadline)
                                .foregroundStyle(JW.Color.textSecondary)
                                .multilineTextAlignment(.center)
                        }
                        .padding(.horizontal, JW.Spacing.xl)
                        .padding(.top, JW.Spacing.xl)
                        .padding(.bottom, 24)
                        .opacity(showHero ? 1 : 0)
                        .offset(y: showHero ? 0 : 20)

                        // Feature cards
                        VStack(spacing: 16) {
                            FeatureComparisonCard(
                                icon: "bolt.fill",
                                iconColor: JW.Color.accent,
                                title: "Unlimited Guided Walks",
                                description: "Intervals, Fat Burn, Post-Meal — as many as you want."
                            )
                            .staggeredAppearance(index: 0)

                            FeatureComparisonCard(
                                icon: "shield.fill",
                                iconColor: JW.Color.streak,
                                title: "4 Shields Every Month",
                                description: "Life happens. Shields protect your streak when you can't walk."
                            )
                            .staggeredAppearance(index: 1)

                            FeatureComparisonCard(
                                icon: "chart.bar.fill",
                                iconColor: JW.Color.accentPurple,
                                title: "Complete Walk History",
                                description: "See every walk, every streak, from day one."
                            )
                            .staggeredAppearance(index: 2)
                        }
                        .padding(.horizontal, JW.Spacing.lg)
                    }
                    .padding(.bottom, JW.Spacing.lg)
                }

                // MARK: Fixed footer (pricing + CTA — always visible)
                stickyFooter
            }
            .background(JW.Color.backgroundPrimary)
            .opacity(showSuccess ? 0 : 1)

            // Success overlay
            if showSuccess {
                successOverlay
            }

            if showsCloseButton {
                VStack {
                    HStack {
                        Spacer()
                        Button {
                            onComplete()
                            dismiss()
                        } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(JW.Color.textSecondary)
                                .frame(width: 32, height: 32)
                                .background(JW.Color.backgroundCard.opacity(0.95))
                                .clipShape(Circle())
                                .shadow(color: Color.black.opacity(0.25), radius: 6, x: 0, y: 3)
                        }
                        .accessibilityLabel("Close")
                    }
                    .padding(.top, JW.Spacing.lg)
                    .padding(.trailing, JW.Spacing.lg)
                    Spacer()
                }
            }
        }
        .onAppear { runEntrance() }
        .task {
            await subscriptionManager.loadProducts()
        }
        .alert("Purchase Failed", isPresented: $showErrorAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage)
        }
        .alert("No Purchase Found", isPresented: $showNoRestoreAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("We couldn't find a previous purchase. If you subscribed on another device, make sure you're signed in with the same Apple ID.")
        }
    }

    // MARK: - Sticky Footer

    private var stickyFooter: some View {
        VStack(spacing: JW.Spacing.sm) {
            // Separator
            Divider()
                .overlay(JW.Color.backgroundTertiary)

            // Plan picker
            VStack(spacing: JW.Spacing.sm) {
                // Monthly row
                PlanPickerRow(
                    label: "Monthly",
                    price: monthlyPriceLabel,
                    subtitle: nil,
                    isSelected: selectedPlan == SubscriptionManager.proMonthlyID
                ) {
                    withAnimation(JustWalkAnimation.micro) {
                        selectedPlan = SubscriptionManager.proMonthlyID
                    }
                    JustWalkHaptics.selectionChanged()
                }

                // Annual row (pre-selected)
                PlanPickerRow(
                    label: "Annual",
                    price: annualPriceLabel,
                    subtitle: annualSubtitleLabel,
                    isSelected: selectedPlan == SubscriptionManager.proAnnualID
                ) {
                    withAnimation(JustWalkAnimation.micro) {
                        selectedPlan = SubscriptionManager.proAnnualID
                    }
                    JustWalkHaptics.selectionChanged()
                }
            }
            .padding(.top, 24)
            .padding(.horizontal, JW.Spacing.lg)
            .opacity(showPricing ? 1 : 0)
            .offset(y: showPricing ? 0 : 10)

            // Trial info
            Text("7-day free trial · Cancel anytime")
                .font(JW.Font.caption)
                .foregroundStyle(JW.Color.textSecondary)
                .opacity(showPricing ? 1 : 0)

            // CTA Button
            Button {
                Task { await purchase() }
            } label: {
                HStack(spacing: JW.Spacing.sm) {
                    if isPurchasing {
                        ProgressView()
                            .tint(.black)
                    } else {
                        Text("Start Free Trial")
                            .font(JW.Font.headline)
                    }
                }
                .foregroundStyle(.black)
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(JW.Color.accent)
                .clipShape(RoundedRectangle(cornerRadius: JW.Radius.lg))
            }
            .disabled(isPurchasing)
            .buttonPressEffect()
            .padding(.horizontal, JW.Spacing.lg)
            .opacity(showCTA ? 1 : 0)
            .offset(y: showCTA ? 0 : 10)

            // Restore + Terms
            VStack(spacing: JW.Spacing.xs) {
                Button {
                    Task { await restore() }
                } label: {
                    if isRestoring {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Text("Restore Purchase")
                    }
                }
                .font(JW.Font.caption)
                .foregroundStyle(JW.Color.accentBlue)
                .disabled(isRestoring)

                Text("Terms of Service · Privacy Policy")
                    .font(JW.Font.caption2)
                    .foregroundStyle(JW.Color.textTertiary)
            }
            .opacity(showFooter ? 1 : 0)
            .padding(.bottom, JW.Spacing.sm)
        }
        .padding(.top, JW.Spacing.sm)
        .background(JW.Color.backgroundPrimary)
    }

    // MARK: - Success Overlay

    private var successOverlay: some View {
        ZStack {
            JW.Color.backgroundPrimary.ignoresSafeArea()

            VStack(spacing: JW.Spacing.lg) {
                ZStack {
                    Circle()
                        .fill(JW.Color.accent.opacity(0.2))
                        .frame(width: 120, height: 120)

                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 64))
                        .foregroundStyle(JW.Color.accent)
                        .scaleEffect(successCheckScale)
                }

                Text("Welcome to Pro")
                    .font(JW.Font.title1)
                    .foregroundStyle(JW.Color.textPrimary)

                Text("Your habit just got stronger.")
                    .font(JW.Font.subheadline)
                    .foregroundStyle(JW.Color.textSecondary)
            }
        }
        .onAppear {
            JustWalkHaptics.success()
            withAnimation(JustWalkAnimation.celebration) {
                successCheckScale = 1.0
            }

            // Auto-dismiss after 2 seconds
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                dismiss()
                onComplete()
            }
        }
    }

    // MARK: - Entrance Animation

    private func runEntrance() {
        let quick = reduceMotion

        withAnimation(.easeOut(duration: 0.5).delay(quick ? 0 : 0.2)) { showHero = true }
        // Feature cards handle themselves via .staggeredAppearance()
        withAnimation(.easeOut(duration: 0.5).delay(quick ? 0 : 0.8)) { showPricing = true }
        withAnimation(.easeOut(duration: 0.5).delay(quick ? 0 : 1.1)) { showCTA = true }
        withAnimation(.easeOut(duration: 0.4).delay(quick ? 0 : 1.3)) { showFooter = true }
    }

    // MARK: - Actions

    private func purchase() async {
        guard let product = subscriptionManager.products.first(where: { $0.id == selectedPlan }) else {
            errorMessage = "Product not available. Please try again later."
            showErrorAlert = true
            return
        }

        isPurchasing = true
        defer { isPurchasing = false }

        do {
            if let _ = try await subscriptionManager.purchase(product) {
                withAnimation(JustWalkAnimation.standard) {
                    showSuccess = true
                }
            }
            // nil result means user cancelled — no error shown
        } catch StoreKitError.networkError {
            errorMessage = "Network error. Please check your connection and try again."
            showErrorAlert = true
        } catch {
            errorMessage = "Something went wrong. Please try again."
            showErrorAlert = true
        }
    }

    private func restore() async {
        isRestoring = true
        defer { isRestoring = false }

        let restored = await subscriptionManager.restorePurchases()

        if restored {
            withAnimation(JustWalkAnimation.standard) {
                showSuccess = true
            }
        } else {
            showNoRestoreAlert = true
        }
    }
}

// MARK: - Plan Picker Row

private struct PlanPickerRow: View {
    let label: String
    let price: String
    let subtitle: String?
    let isSelected: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: JW.Spacing.md) {
                // Radio button
                ZStack {
                    Circle()
                        .stroke(isSelected ? JW.Color.accent : JW.Color.textTertiary, lineWidth: 2)
                        .frame(width: 22, height: 22)

                    if isSelected {
                        Circle()
                            .fill(JW.Color.accent)
                            .frame(width: 12, height: 12)
                    }
                }

                // Plan label
                Text(label)
                    .font(JW.Font.headline)
                    .foregroundStyle(JW.Color.textPrimary)

                Spacer()

                // Price info
                VStack(alignment: .trailing, spacing: 2) {
                    Text(price)
                        .font(JW.Font.headline)
                        .foregroundStyle(JW.Color.textPrimary)

                    if let subtitle {
                        Text(subtitle)
                            .font(JW.Font.caption)
                            .foregroundStyle(JW.Color.accent)
                    }
                }
            }
            .padding(JW.Spacing.lg)
            .background(
                RoundedRectangle(cornerRadius: JW.Radius.lg)
                    .fill(JW.Color.backgroundCard)
            )
            .overlay(
                RoundedRectangle(cornerRadius: JW.Radius.lg)
                    .stroke(isSelected ? JW.Color.accent : Color.white.opacity(0.06), lineWidth: isSelected ? 2 : 1)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Feature Comparison Card

private struct FeatureComparisonCard: View {
    let icon: String
    let iconColor: Color
    let title: String
    let description: String

    var body: some View {
        HStack(alignment: .top, spacing: JW.Spacing.lg) {
            // Icon
            ZStack {
                Circle()
                    .fill(iconColor.opacity(0.15))
                    .frame(width: 44, height: 44)

                Image(systemName: icon)
                    .font(.title3)
                    .foregroundStyle(iconColor)
            }

            // Text
            VStack(alignment: .leading, spacing: JW.Spacing.xs) {
                Text(title)
                    .font(JW.Font.headline.bold())
                    .foregroundStyle(JW.Color.textPrimary)
                    .lineLimit(1)

                Text(description)
                    .font(JW.Font.subheadline)
                    .foregroundStyle(JW.Color.textSecondary)
                    .lineLimit(2)
            }

            Spacer()
        }
        .padding(JW.Spacing.lg)
        .background(
            RoundedRectangle(cornerRadius: JW.Radius.lg)
                .fill(JW.Color.backgroundCard)
        )
        .overlay(
            RoundedRectangle(cornerRadius: JW.Radius.lg)
                .stroke(Color.white.opacity(0.06), lineWidth: 1)
        )
    }
}

#Preview {
    ProUpgradeView(onComplete: {})
}
