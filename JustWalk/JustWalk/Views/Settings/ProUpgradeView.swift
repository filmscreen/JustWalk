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
    @State private var showFeatures = false
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
                // MARK: Content
                VStack(spacing: 0) {
                    // Hero section
                    VStack(spacing: JW.Spacing.sm) {
                        Text("Just Walk Pro")
                            .font(JW.Font.largeTitle)
                            .foregroundStyle(JW.Color.textPrimary)
                            .multilineTextAlignment(.center)

                        Text("See the full picture.")
                            .font(JW.Font.title3)
                            .foregroundStyle(JW.Color.textSecondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.horizontal, JW.Spacing.xl)
                    .padding(.top, JW.Spacing.xl + 32) // Extra space for Skip button above
                    .opacity(showHero ? 1 : 0)
                    .offset(y: showHero ? 0 : 20)

                    // 95% hero message (prominent card)
                    HStack(spacing: JW.Spacing.sm) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(JW.Color.accent)

                        Text("Walking (~20%) and what you eat (~75%) make up 95% of your well-being.")
                            .font(JW.Font.subheadline)
                            .foregroundStyle(JW.Color.textPrimary)
                            .multilineTextAlignment(.leading)
                    }
                    .padding(JW.Spacing.lg)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: JW.Radius.lg)
                            .fill(JW.Color.accent.opacity(0.12))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: JW.Radius.lg)
                            .stroke(JW.Color.accent.opacity(0.3), lineWidth: 1)
                    )
                    .padding(.horizontal, JW.Spacing.lg)
                    .padding(.top, JW.Spacing.lg)
                    .opacity(showHero ? 1 : 0)

                    // 3 Feature cards
                    VStack(spacing: JW.Spacing.sm) {
                        // INTAKE
                        ProFeatureCard(
                            label: "INTAKE",
                            icon: "fork.knife",
                            labelColor: JW.Color.accent,
                            title: "AI Food Logging",
                            subtitle: "Track calories and macros in seconds."
                        )

                        // OUTPUT
                        ProFeatureCard(
                            label: "OUTPUT",
                            icon: "figure.walk",
                            labelColor: JW.Color.accent,
                            title: "Unlimited Guided Walks",
                            subtitle: "Intervals, Fat Burn, Post-Meal"
                        )

                        // PROTECTION
                        ProFeatureCard(
                            label: "PROTECTION",
                            icon: "shield.fill",
                            labelColor: JW.Color.accent,
                            title: "4 Shields Every Month",
                            subtitle: "Life happens. Stay protected."
                        )
                    }
                    .padding(.horizontal, JW.Spacing.lg)
                    .padding(.top, JW.Spacing.lg)
                    .opacity(showFeatures ? 1 : 0)
                    .offset(y: showFeatures ? 0 : 15)

                    Spacer(minLength: JW.Spacing.md)
                }

                // MARK: Fixed footer (pricing + CTA)
                stickyFooter
            }
            .background(JW.Color.backgroundPrimary)
            .opacity(showSuccess ? 0 : 1)

            // Success overlay
            if showSuccess {
                successOverlay
            }

            // Skip / Close button
            VStack {
                HStack {
                    // Skip For Now (left side, during onboarding) - liquid glass style
                    if showsCloseButton {
                        Button {
                            onComplete()
                            dismiss()
                        } label: {
                            Text("Skip For Now")
                                .font(JW.Font.subheadline)
                                .foregroundStyle(JW.Color.textSecondary)
                                .padding(.horizontal, JW.Spacing.md)
                                .padding(.vertical, JW.Spacing.sm)
                                .background(
                                    RoundedRectangle(cornerRadius: JW.Radius.md)
                                        .fill(Color.white.opacity(0.08))
                                )
                        }
                        .buttonStyle(.plain)
                        .padding(.top, JW.Spacing.md)
                        .padding(.leading, JW.Spacing.lg)
                    }

                    Spacer()
                }
                Spacer()
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
            HStack(spacing: JW.Spacing.sm) {
                // Monthly
                CompactPlanOption(
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

                // Annual (pre-selected)
                CompactPlanOption(
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
            .padding(.horizontal, JW.Spacing.lg)
            .padding(.top, JW.Spacing.sm)
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

            // Trial info
            Text("7-day free trial · Cancel anytime")
                .font(JW.Font.caption)
                .foregroundStyle(JW.Color.textSecondary)
                .opacity(showCTA ? 1 : 0)

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
        .padding(.top, JW.Spacing.xs)
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
        withAnimation(.easeOut(duration: 0.5).delay(quick ? 0 : 0.5)) { showFeatures = true }
        withAnimation(.easeOut(duration: 0.5).delay(quick ? 0 : 0.7)) { showPricing = true }
        withAnimation(.easeOut(duration: 0.5).delay(quick ? 0 : 0.9)) { showCTA = true }
        withAnimation(.easeOut(duration: 0.4).delay(quick ? 0 : 1.1)) { showFooter = true }
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

// MARK: - Pro Feature Card (compact)

private struct ProFeatureCard: View {
    let label: String
    let icon: String
    let labelColor: Color
    let title: String
    let subtitle: String

    var body: some View {
        HStack(spacing: JW.Spacing.md) {
            // Icon
            Image(systemName: icon)
                .font(.system(size: 20, weight: .medium))
                .foregroundStyle(labelColor)
                .frame(width: 36, height: 36)
                .background(
                    Circle()
                        .fill(labelColor.opacity(0.15))
                )

            // Text content
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundStyle(labelColor)
                    .tracking(1)

                Text(title)
                    .font(JW.Font.subheadline.weight(.semibold))
                    .foregroundStyle(JW.Color.textPrimary)

                Text(subtitle)
                    .font(JW.Font.caption)
                    .foregroundStyle(JW.Color.textSecondary)
            }

            Spacer()
        }
        .padding(JW.Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: JW.Radius.md)
                .fill(JW.Color.backgroundCard)
        )
        .overlay(
            RoundedRectangle(cornerRadius: JW.Radius.md)
                .stroke(Color.white.opacity(0.06), lineWidth: 1)
        )
    }
}

// MARK: - Compact Plan Option

private struct CompactPlanOption: View {
    let label: String
    let price: String
    let subtitle: String?
    let isSelected: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            VStack(spacing: JW.Spacing.xs) {
                Text(label)
                    .font(JW.Font.caption.weight(.medium))
                    .foregroundStyle(isSelected ? JW.Color.textPrimary : JW.Color.textSecondary)

                Text(price)
                    .font(JW.Font.headline)
                    .foregroundStyle(isSelected ? JW.Color.textPrimary : JW.Color.textSecondary)

                if let subtitle {
                    Text(subtitle)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(JW.Color.accent)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, JW.Spacing.md)
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

#Preview {
    ProUpgradeView(onComplete: {})
}
