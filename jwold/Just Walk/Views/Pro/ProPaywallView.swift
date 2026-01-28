//
//  ProPaywallView.swift
//  Just Walk
//
//  Unified Pro subscription paywall.
//  Single paywall for all Pro features: Interval Walking, Streak Shields, Route Tracking, Advanced Insights.
//

import SwiftUI
import StoreKit

// MARK: - Paywall Copy (Easy A/B Testing)

private enum PaywallCopy {
    static let headline = "Walk Smarter. See Results."
    static let subhead = "Get the tools to build a lasting walking habit"
    static let trialCallout = "Start with a 7-day free trial"

    // Annual Plan
    static let annualPrice = "$39.99"
    static let annualPeriod = "/year"
    static let annualBreakdown = "Just $3.33/month • 7-day free trial"

    // Lifetime Plan
    static let lifetimePrice = "$119.99"
    static let lifetimeSubtitle = "Pay once, own forever"

    // Monthly Plan
    static let monthlyPrice = "$7.99"
    static let monthlyPeriod = "/month"
    static let monthlySubtitle = "Cancel anytime"
    static let monthlySavingsHint = "Annual saves 58%"

    static let ctaTrial = "Start Free Trial"
    static let ctaLifetime = "Buy Lifetime"
    static let ctaSubscribe = "Subscribe"

    static let legalText = "Subscriptions auto-renew unless cancelled at least 24 hours before the end of the current period. Manage subscriptions in Settings."

    static let termsURL = URL(string: "https://example.com/terms")!
    static let privacyURL = URL(string: "https://example.com/privacy")!
}

// MARK: - Feature Data

private struct ProFeature: Identifiable {
    let id = UUID()
    let icon: String
    let title: String
    let description: String
}

private let proFeatures: [ProFeature] = [
    ProFeature(
        icon: "figure.walk.motion",
        title: "Interval Walking",
        description: "Guided pace intervals — proven to boost fitness 20% faster than regular walks"
    ),
    ProFeature(
        icon: "shield.fill",
        title: "Streak Shields",
        description: "Missed a day? Protect your streak with 3 shields per month"
    ),
    ProFeature(
        icon: "point.bottomleft.forward.to.point.topright.scurvepath",
        title: "Route Tracking",
        description: "Map your walks, save favorite routes, see where you've been"
    ),
    ProFeature(
        icon: "chart.line.uptrend.xyaxis",
        title: "Advanced Insights",
        description: "Weekly progress reports, personal records, and goal recommendations"
    )
]

// MARK: - Plan Type

private enum PlanType: CaseIterable {
    case annual, lifetime, monthly
}

// MARK: - ProPaywallView

struct ProPaywallView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @ObservedObject private var storeManager = StoreManager.shared

    @State private var selectedPlan: PlanType = .annual
    @State private var isLoading = false
    @State private var errorMessage: String?

    /// Callback invoked on successful purchase
    var onPurchaseComplete: (() -> Void)?

    // TODO: Set to false to use real StoreKit in production
    private let useMockPurchase = true

    // MARK: - Design Constants

    private let accentColor = Color(hex: "00C7BE")
    private let screenPadding: CGFloat = 20
    private let sectionSpacing: CGFloat = 24

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: sectionSpacing) {
                    headerSection
                    featuresSection
                    trialCallout
                    planSelectionSection
                    ctaButton
                    footerSection
                }
                .padding(.horizontal, screenPadding)
                .padding(.vertical, 16)
            }
            .background(Color(.systemGroupedBackground))
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 28))
                            .symbolRenderingMode(.hierarchical)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    // MARK: - Header Section

    private var headerSection: some View {
        VStack(spacing: 16) {
            // Crown icon with teal gradient
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [accentColor, accentColor.opacity(0.7)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 70, height: 70)

                Image(systemName: "crown.fill")
                    .font(.system(size: 32))
                    .foregroundStyle(.white)
            }
            .shadow(color: accentColor.opacity(0.4), radius: 10, y: 5)

            VStack(spacing: 8) {
                Text(PaywallCopy.headline)
                    .font(.system(size: 24, weight: .bold))
                    .multilineTextAlignment(.center)

                Text(PaywallCopy.subhead)
                    .font(.system(size: 15, weight: .regular))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(.top, 8)
    }

    // MARK: - Features Section

    private var featuresSection: some View {
        VStack(spacing: 16) {
            ForEach(proFeatures) { feature in
                featureRow(feature)
            }
        }
    }

    private func featureRow(_ feature: ProFeature) -> some View {
        HStack(alignment: .top, spacing: 16) {
            // Icon in teal circle
            ZStack {
                Circle()
                    .fill(accentColor.opacity(0.08))
                    .frame(width: 40, height: 40)

                Image(systemName: feature.icon)
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(accentColor)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(feature.title)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.primary)

                Text(feature.description)
                    .font(.system(size: 15, weight: .regular))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer()
        }
    }

    // MARK: - Trial Callout

    private var trialCallout: some View {
        HStack(spacing: 8) {
            Image(systemName: "gift.fill")
                .font(.system(size: 15))
            Text(PaywallCopy.trialCallout)
                .font(.system(size: 15, weight: .medium))
        }
        .foregroundStyle(accentColor)
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(accentColor.opacity(0.1))
        .clipShape(Capsule())
    }

    // MARK: - Plan Selection Section

    private var planSelectionSection: some View {
        VStack(spacing: 12) {
            annualPlanCard
            lifetimePlanCard
            monthlyPlanOption
        }
    }

    // MARK: - Annual Plan Card (Primary/Dominant)

    private var annualPlanCard: some View {
        let isSelected = selectedPlan == .annual

        return Button {
            withAnimation(.spring(response: 0.2, dampingFraction: 0.7)) {
                selectedPlan = .annual
            }
        } label: {
            HStack(spacing: 12) {
                // Radio indicator
                radioIndicator(isSelected: isSelected)

                // Plan details
                VStack(alignment: .leading, spacing: 4) {
                    Text(PaywallCopy.annualPrice + PaywallCopy.annualPeriod)
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(.primary)

                    Text(PaywallCopy.annualBreakdown)
                        .font(.system(size: 13, weight: .regular))
                        .foregroundStyle(.secondary)
                }

                Spacer()

                // BEST VALUE badge
                Text("BEST VALUE")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(accentColor)
                    .clipShape(Capsule())
            }
            .padding(16)
            .background(isSelected ? accentColor.opacity(0.08) : cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(accentColor, lineWidth: 2)
            )
            .scaleEffect(isSelected ? 1.02 : 1.0)
        }
        .buttonStyle(.plain)
        .disabled(isLoading)
    }

    // MARK: - Lifetime Plan Card (Secondary)

    private var lifetimePlanCard: some View {
        let isSelected = selectedPlan == .lifetime

        return Button {
            withAnimation(.spring(response: 0.2, dampingFraction: 0.7)) {
                selectedPlan = .lifetime
            }
        } label: {
            HStack(spacing: 12) {
                // Radio indicator
                radioIndicator(isSelected: isSelected)

                // Plan details
                VStack(alignment: .leading, spacing: 4) {
                    Text(PaywallCopy.lifetimePrice)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(.primary)

                    Text(PaywallCopy.lifetimeSubtitle)
                        .font(.system(size: 13, weight: .regular))
                        .foregroundStyle(.secondary)
                }

                Spacer()
            }
            .padding(16)
            .background(cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(isSelected ? accentColor : Color(.separator).opacity(0.3), lineWidth: isSelected ? 2 : 1)
            )
        }
        .buttonStyle(.plain)
        .disabled(isLoading)
    }

    // MARK: - Monthly Plan Option (Tertiary - Text Only)

    private var monthlyPlanOption: some View {
        let isSelected = selectedPlan == .monthly

        return Button {
            withAnimation(.spring(response: 0.2, dampingFraction: 0.7)) {
                selectedPlan = .monthly
            }
        } label: {
            VStack(spacing: 4) {
                HStack(spacing: 12) {
                    // Radio indicator
                    radioIndicator(isSelected: isSelected)

                    // Price
                    Text(PaywallCopy.monthlyPrice + PaywallCopy.monthlyPeriod)
                        .font(.system(size: 15, weight: .regular))
                        .foregroundStyle(isSelected ? accentColor : .secondary)

                    Spacer()
                }

                HStack {
                    Spacer()
                        .frame(width: 34) // Align with text above (22 radio + 12 spacing)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(PaywallCopy.monthlySubtitle)
                            .font(.system(size: 13, weight: .regular))
                            .foregroundStyle(.tertiary)

                        Text(PaywallCopy.monthlySavingsHint)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(Color.orange)
                    }

                    Spacer()
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .buttonStyle(.plain)
        .disabled(isLoading)
    }

    // MARK: - Radio Indicator

    private func radioIndicator(isSelected: Bool) -> some View {
        ZStack {
            Circle()
                .stroke(isSelected ? accentColor : Color(.tertiaryLabel), lineWidth: 2)
                .frame(width: 22, height: 22)

            if isSelected {
                Circle()
                    .fill(accentColor)
                    .frame(width: 12, height: 12)
            }
        }
    }

    // MARK: - Card Background

    private var cardBackground: Color {
        colorScheme == .dark ? Color(hex: "1C1C1E") : .white
    }

    // MARK: - CTA Button

    private var ctaButtonText: String {
        switch selectedPlan {
        case .annual:
            return PaywallCopy.ctaTrial
        case .lifetime:
            return PaywallCopy.ctaLifetime
        case .monthly:
            return PaywallCopy.ctaSubscribe
        }
    }

    private var ctaButton: some View {
        Button {
            Task {
                await purchase()
            }
        } label: {
            HStack(spacing: 8) {
                if isLoading {
                    ProgressView()
                        .tint(.white)
                } else {
                    Text(ctaButtonText)
                        .font(.system(size: 17, weight: .semibold))
                }
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(accentColor)
            .clipShape(Capsule())
        }
        .shadow(color: accentColor.opacity(0.3), radius: 8, y: 4)
        .disabled(isLoading)
    }

    // MARK: - Footer Section

    private var footerSection: some View {
        VStack(spacing: 12) {
            // Restore Purchases
            Button {
                Task {
                    await restore()
                }
            } label: {
                if isLoading {
                    ProgressView()
                        .scaleEffect(0.8)
                } else {
                    Text("Restore Purchases")
                        .font(.system(size: 15, weight: .regular))
                        .foregroundStyle(.secondary)
                }
            }
            .disabled(isLoading)

            // Error message
            if let error = errorMessage {
                Text(error)
                    .font(.system(size: 13, weight: .regular))
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
            }

            // Legal text
            Text(PaywallCopy.legalText)
                .font(.system(size: 11, weight: .regular))
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)

            // Terms and Privacy links
            HStack(spacing: 24) {
                Link("Terms of Service", destination: PaywallCopy.termsURL)
                    .font(.system(size: 11, weight: .regular))
                    .foregroundStyle(.secondary)

                Link("Privacy Policy", destination: PaywallCopy.privacyURL)
                    .font(.system(size: 11, weight: .regular))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.top, 8)
    }

    // MARK: - Purchase Action

    private func purchase() async {
        errorMessage = nil
        isLoading = true

        defer { isLoading = false }

        // Mock purchase for development
        if useMockPurchase {
            try? await Task.sleep(nanoseconds: 500_000_000) // 0.5s delay
            onPurchaseComplete?()
            dismiss()
            return
        }

        // Real StoreKit purchase
        let product: Product?
        switch selectedPlan {
        case .annual:
            product = storeManager.proAnnualProduct
        case .lifetime:
            product = storeManager.proLifetimeProduct
        case .monthly:
            product = storeManager.proMonthlyProduct
        }

        guard let product = product else {
            errorMessage = "Product not available. Please try again."
            return
        }

        await storeManager.purchase(product)

        if storeManager.isPro {
            onPurchaseComplete?()
            dismiss()
        } else if let error = storeManager.purchaseError {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Restore Action

    private func restore() async {
        errorMessage = nil
        isLoading = true

        defer { isLoading = false }

        // Mock restore for development
        if useMockPurchase {
            try? await Task.sleep(nanoseconds: 500_000_000)
            onPurchaseComplete?()
            dismiss()
            return
        }

        // Real restore
        await storeManager.restorePurchases()

        if storeManager.isPro {
            onPurchaseComplete?()
            dismiss()
        } else {
            errorMessage = "No previous purchases found."
        }
    }
}

// MARK: - Preview

#Preview("Default") {
    ProPaywallView()
}

#Preview("Dark Mode") {
    ProPaywallView()
        .preferredColorScheme(.dark)
}
