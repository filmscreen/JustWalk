//
//  UnifiedShieldPurchaseSheet.swift
//  Just Walk
//
//  Unified purchase sheet for shields.
//  Pro subscription is PRIMARY (top), $3.99 single shield is SECONDARY (bottom).
//

import SwiftUI
import StoreKit

// MARK: - Copy Constants

private enum ShieldPurchaseCopy {
    static let title = "Protect This Day"
    static let subtitle = "Use a shield to save your streak"
    static let goPro = "Get Pro — $39.99/year"
    static let proShieldsText = "3 shields every month"
    static let proExtrasText = "+ all Pro features"
    static let trialInfo = "7-day free trial"
    static let trialCTA = "Start Free Trial"
    static let singleShieldPrice = "$3.99"
    static let singleShieldHeadline = "Just This Once — $3.99"
    static let buySingleCTA = "Buy 1 Shield"
    static let footerText = "Pro members get 3 shields/month included"
}

// MARK: - Unified Shield Purchase Sheet

struct UnifiedShieldPurchaseSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var storeManager: StoreManager
    @StateObject private var subscriptionManager = SubscriptionManager.shared

    @State private var isPurchasing = false
    @State private var purchaseError: String?

    var onPurchaseComplete: () -> Void
    var onShowPaywall: () -> Void
    var onDismiss: () -> Void

    // Design constants
    private let accentColor = Color(hex: "00C7BE")
    private let grayButtonColor = Color(.systemGray5)

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: JWDesign.Spacing.lg) {
                    // Subtitle
                    Text(ShieldPurchaseCopy.subtitle)
                        .font(JWDesign.Typography.subheadline)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .center)

                    // Pro subscription card (PRIMARY)
                    proSubscriptionCard

                    // Single shield purchase (SECONDARY)
                    singleShieldCard

                    // Error message
                    if let error = purchaseError {
                        Text(error)
                            .font(JWDesign.Typography.caption)
                            .foregroundStyle(.red)
                            .multilineTextAlignment(.center)
                    }

                    // Footer text
                    footerView
                }
                .padding(.horizontal, JWDesign.Spacing.horizontalInset)
                .padding(.vertical, JWDesign.Spacing.lg)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle(ShieldPurchaseCopy.title)
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    // MARK: - Pro Subscription Card

    private var proSubscriptionCard: some View {
        VStack(alignment: .leading, spacing: JWDesign.Spacing.md) {
            // Headline
            Text(ShieldPurchaseCopy.goPro)
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(.primary)

            // Benefits
            VStack(alignment: .leading, spacing: 4) {
                Text(ShieldPurchaseCopy.proShieldsText)
                    .font(JWDesign.Typography.body)
                    .foregroundStyle(.primary)

                Text(ShieldPurchaseCopy.proExtrasText)
                    .font(JWDesign.Typography.body)
                    .foregroundStyle(.secondary)

                Text(ShieldPurchaseCopy.trialInfo)
                    .font(JWDesign.Typography.body)
                    .foregroundStyle(.secondary)
            }

            // CTA Button
            Button(action: showProPaywall) {
                Text(ShieldPurchaseCopy.trialCTA)
                    .font(JWDesign.Typography.headlineBold)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, JWDesign.Spacing.md)
                    .background(accentColor)
                    .clipShape(RoundedRectangle(cornerRadius: JWDesign.Radius.button))
            }
        }
        .padding(JWDesign.Spacing.lg)
        .background(JWDesign.Colors.secondaryBackground)
        .clipShape(RoundedRectangle(cornerRadius: JWDesign.Radius.card))
        .overlay(
            RoundedRectangle(cornerRadius: JWDesign.Radius.card)
                .stroke(accentColor, lineWidth: 2)
        )
    }

    // MARK: - Single Shield Card

    private var singleShieldCard: some View {
        VStack(alignment: .leading, spacing: JWDesign.Spacing.md) {
            // Headline
            Text(ShieldPurchaseCopy.singleShieldHeadline)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(.primary)

            // CTA Button
            Button(action: purchaseSingleShield) {
                HStack {
                    if isPurchasing {
                        ProgressView()
                            .tint(.primary)
                    } else {
                        Text(ShieldPurchaseCopy.buySingleCTA)
                            .font(JWDesign.Typography.headlineBold)
                    }
                }
                .foregroundStyle(.primary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, JWDesign.Spacing.md)
                .background(grayButtonColor)
                .clipShape(RoundedRectangle(cornerRadius: JWDesign.Radius.button))
            }
            .disabled(isPurchasing)
        }
        .padding(JWDesign.Spacing.lg)
        .background(JWDesign.Colors.secondaryBackground)
        .clipShape(RoundedRectangle(cornerRadius: JWDesign.Radius.card))
    }

    // MARK: - Footer View

    private var footerView: some View {
        Text(ShieldPurchaseCopy.footerText)
            .font(JWDesign.Typography.caption)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.top, JWDesign.Spacing.sm)
    }

    // MARK: - Purchase Actions

    private func showProPaywall() {
        // Dismiss this sheet and show the main paywall
        dismiss()
        onShowPaywall()
    }

    private func purchaseSingleShield() {
        isPurchasing = true
        purchaseError = nil

        Task {
            do {
                // Use the single shield product ID
                let shieldsGranted = try await subscriptionManager.purchaseShields(
                    productId: SubscriptionManager.shieldSingleProductId
                )

                await MainActor.run {
                    isPurchasing = false
                    if shieldsGranted > 0 {
                        HapticService.shared.playSuccess()
                        onPurchaseComplete()
                        dismiss()
                    }
                }
            } catch {
                await MainActor.run {
                    isPurchasing = false
                    if case SubscriptionManager.ShieldPurchaseError.cancelled = error {
                        // User cancelled, no error message needed
                    } else {
                        purchaseError = error.localizedDescription
                    }
                }
            }
        }
    }
}

// MARK: - Preview

#Preview("Unified Shield Purchase") {
    UnifiedShieldPurchaseSheet(
        onPurchaseComplete: {},
        onShowPaywall: {},
        onDismiss: {}
    )
    .environmentObject(StoreManager.shared)
}
