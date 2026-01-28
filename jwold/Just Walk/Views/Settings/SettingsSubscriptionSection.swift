//
//  SettingsSubscriptionSection.swift
//  Just Walk
//
//  Subscription status section for Settings screen.
//  Shows current Pro status or upgrade CTA.
//

import SwiftUI
import StoreKit

struct SettingsSubscriptionSection: View {
    @EnvironmentObject var storeManager: StoreManager
    @Binding var showPaywall: Bool

    var body: some View {
        Section {
            if storeManager.isPro {
                // Pro member status
                proMemberRow
            } else {
                // Upgrade CTA
                upgradeRow
            }
        } header: {
            Label("Subscription", systemImage: "crown.fill")
        } footer: {
            if storeManager.isPro {
                Text("Thank you for supporting Just Walk.")
            } else {
                Text("Unlock premium features to maximize your walking journey.")
            }
        }
    }

    // MARK: - Pro Member Row

    private var proMemberRow: some View {
        VStack(alignment: .leading, spacing: JWDesign.Spacing.sm) {
            HStack(spacing: JWDesign.Spacing.md) {
                // Pro badge with checkmark
                ZStack {
                    Circle()
                        .fill(JWDesign.Colors.success)
                        .frame(width: 44, height: 44)

                    Image(systemName: "checkmark")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(.white)
                }

                VStack(alignment: .leading, spacing: JWDesign.Spacing.xxs) {
                    Text("Pro Member")
                        .font(.headline)

                    // Show renewal/expiry info
                    if let expirationDate = storeManager.subscriptionExpirationDate {
                        if storeManager.willRenew {
                            Text("Renews \(expirationDate.formatted(date: .abbreviated, time: .omitted))")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        } else {
                            Text("Expires \(expirationDate.formatted(date: .abbreviated, time: .omitted))")
                                .font(.caption)
                                .foregroundStyle(.orange)
                        }
                    } else if storeManager.isProLifetime {
                        Text("Lifetime")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()
            }

            // Manage Subscription button
            Button {
                openSubscriptionManagement()
            } label: {
                HStack {
                    Text("Manage Subscription")
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, JWDesign.Spacing.xs)
    }

    // MARK: - Upgrade Row

    private var upgradeRow: some View {
        Button {
            showPaywall = true
        } label: {
            HStack(spacing: JWDesign.Spacing.md) {
                // Upgrade icon
                ZStack {
                    Circle()
                        .fill(JWDesign.Colors.brandPrimary.opacity(0.15))
                        .frame(width: 44, height: 44)

                    Image(systemName: "sparkles")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(JWDesign.Colors.brandPrimary)
                }

                VStack(alignment: .leading, spacing: JWDesign.Spacing.xxs) {
                    Text("Upgrade to Pro")
                        .font(.headline)
                        .foregroundStyle(.primary)

                    Text("7-day free trial")
                        .font(.caption)
                        .foregroundStyle(JWDesign.Colors.success)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .padding(.vertical, JWDesign.Spacing.xs)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Actions

    private func openSubscriptionManagement() {
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
            Task {
                do {
                    try await AppStore.showManageSubscriptions(in: windowScene)
                } catch {
                    // Fallback to Settings
                    if let url = URL(string: "itms-apps://apps.apple.com/account/subscriptions") {
                        await UIApplication.shared.open(url)
                    }
                }
            }
        }
    }
}

#Preview("Not Pro") {
    List {
        SettingsSubscriptionSection(showPaywall: .constant(false))
    }
    .environmentObject(StoreManager.shared)
}
