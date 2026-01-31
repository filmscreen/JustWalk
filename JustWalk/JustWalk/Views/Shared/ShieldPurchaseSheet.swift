//
//  ShieldPurchaseSheet.swift
//  JustWalk
//
//  One-off shield purchase flow for Pro and Free users
//

import SwiftUI
import StoreKit

struct ShieldPurchaseSheet: View {
    @Environment(\.dismiss) private var dismiss

    @StateObject private var subscriptionManager = SubscriptionManager.shared
    private var shieldManager = ShieldManager.shared

    @State private var isPurchasing = false
    @State private var purchaseError: String?

    let isPro: Bool
    var onShieldPurchased: (() -> Void)? = nil
    var onRequestProUpgrade: (() -> Void)? = nil

    init(isPro: Bool, onShieldPurchased: (() -> Void)? = nil, onRequestProUpgrade: (() -> Void)? = nil) {
        self.isPro = isPro
        self.onShieldPurchased = onShieldPurchased
        self.onRequestProUpgrade = onRequestProUpgrade
    }

    var body: some View {
        VStack(spacing: JW.Spacing.lg) {
            // Drag indicator
            Capsule()
                .fill(Color.secondary.opacity(0.5))
                .frame(width: 36, height: 5)
                .padding(.top, 8)

            header

            if isPro {
                proOptions
            } else {
                freeOptions
            }

            if let error = purchaseError {
                Text(error)
                    .font(JW.Font.caption)
                    .foregroundStyle(.red)
            }

            Button("Not now") {
                dismiss()
            }
            .font(JW.Font.subheadline)
            .foregroundStyle(JW.Color.textTertiary)
            .padding(.bottom, JW.Spacing.md)
        }
        .padding(.horizontal, JW.Spacing.xl)
        .presentationDetents([.medium])
        .presentationDragIndicator(.hidden)
        .task {
            await subscriptionManager.loadProducts()
        }
    }

    private var header: some View {
        VStack(spacing: JW.Spacing.md) {
            ZStack {
                Circle()
                    .fill(JW.Color.accentBlue.opacity(0.2))
                    .frame(width: 72, height: 72)
                Image(systemName: "shield.fill")
                    .font(.system(size: 32, weight: .semibold))
                    .foregroundStyle(JW.Color.accentBlue)
            }

            Text(isPro ? "Need another shield?" : "Protect your streak")
                .font(JW.Font.title2)
                .foregroundStyle(JW.Color.textPrimary)

            Text(isPro ? proSubheadline : freeSubheadline)
                .font(JW.Font.subheadline)
                .foregroundStyle(JW.Color.textSecondary)
                .multilineTextAlignment(.center)
        }
    }

    private var proSubheadline: String {
        if let date = shieldManager.nextRefillDate {
            let formatter = DateFormatter()
            formatter.dateFormat = "MMMM d"
            return "Your monthly shields refill \(formatter.string(from: date)).\nOr grab one now."
        }
        return "Your monthly shields have been used.\nGrab one now."
    }

    private var freeSubheadline: String {
        "Shields save your streak on days you can't walk."
    }

    private var proOptions: some View {
        Button {
            Task { await purchaseShield() }
        } label: {
            HStack {
                Image(systemName: "shield.fill")
                Text("Buy Shield")
                    .font(JW.Font.headline)
                Spacer()
                Text(subscriptionManager.shieldDisplayPrice)
                    .font(JW.Font.headline)
            }
            .foregroundStyle(.white)
            .padding()
            .background(JW.Color.accentBlue)
            .clipShape(RoundedRectangle(cornerRadius: JW.Radius.lg))
        }
        .disabled(isPurchasing || subscriptionManager.shieldProduct == nil)
        .opacity(isPurchasing ? 0.6 : 1)
    }

    private var freeOptions: some View {
        VStack(spacing: JW.Spacing.md) {
            Button {
                dismiss()
                onRequestProUpgrade?()
            } label: {
                VStack(alignment: .leading, spacing: JW.Spacing.xs) {
                    HStack {
                        Image(systemName: "star.fill")
                            .foregroundStyle(.yellow)
                        Text("Get Pro")
                            .font(JW.Font.headline)
                        Spacer()
                        Text(subscriptionManager.proAnnualProduct?.displayPrice ?? "$39.99/year")
                            .font(JW.Font.headline)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        featureRow("4 shields every month")
                        featureRow("All guided walks")
                        featureRow("Full walk history")
                    }
                    .font(JW.Font.subheadline)
                    .foregroundStyle(.white.opacity(0.9))

                    HStack {
                        Spacer()
                        Text("Best Value")
                            .font(JW.Font.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.white.opacity(0.2))
                            .clipShape(Capsule())
                    }
                }
                .foregroundStyle(.white)
                .padding()
                .background(
                    LinearGradient(
                        colors: [JW.Color.accentBlue, JW.Color.accentPurple],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .clipShape(RoundedRectangle(cornerRadius: JW.Radius.lg))
            }

            Button {
                Task { await purchaseShield() }
            } label: {
                HStack {
                    Image(systemName: "shield.fill")
                        .foregroundStyle(JW.Color.accentBlue)
                    Text("Buy 1 Shield")
                        .font(JW.Font.headline)
                    Spacer()
                    Text(subscriptionManager.shieldDisplayPrice)
                        .font(JW.Font.headline)
                }
                .foregroundStyle(JW.Color.textPrimary)
                .padding()
                .background(JW.Color.backgroundCard)
                .clipShape(RoundedRectangle(cornerRadius: JW.Radius.lg))
            }
            .disabled(isPurchasing || subscriptionManager.shieldProduct == nil)
            .opacity(isPurchasing ? 0.6 : 1)
        }
    }

    private func featureRow(_ text: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: "checkmark")
                .font(.caption)
            Text(text)
        }
    }

    private func purchaseShield() async {
        isPurchasing = true
        purchaseError = nil

        do {
            let success = try await subscriptionManager.purchaseShield()
            if success {
                onShieldPurchased?()
                dismiss()
            }
        } catch {
            purchaseError = "Purchase failed. Please try again."
        }

        isPurchasing = false
    }
}
