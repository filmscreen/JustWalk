//
//  ProPaywallOnboardingView.swift
//  Just Walk
//
//  Created by Randy Chia on 1/22/26.
//

import SwiftUI
import StoreKit

struct ProPaywallOnboardingView: View {
    @EnvironmentObject private var coordinator: OnboardingCoordinator
    @ObservedObject private var storeManager = StoreManager.shared
    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        ZStack(alignment: .bottom) {
            // Scrollable content
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    VStack(spacing: 8) {
                        Text("Get more from Just Walk")
                            .font(.title2.bold())
                            .foregroundStyle(.white)
                            .multilineTextAlignment(.center)

                        Text("Unlock powerful features to reach your goals faster")
                            .font(.body)
                            .foregroundStyle(.white.opacity(0.85))
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top, 16)

                    // Comparison table card
                    ComparisonTableCard()

                    // "Why Go Pro?" divider
                    HStack(spacing: 12) {
                        Rectangle()
                            .fill(Color.white.opacity(0.3))
                            .frame(height: 1)

                        Text("Why Go Pro?")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.white.opacity(0.9))

                        Rectangle()
                            .fill(Color.white.opacity(0.3))
                            .frame(height: 1)
                    }

                    // Feature highlight cards
                    VStack(spacing: 12) {
                        ProFeatureHighlightCard(
                            icon: "shield.fill",
                            iconColor: Color(hex: "FF9500"),
                            title: "Streak Shields",
                            description: "Protect your streak on rest days or when life gets busy"
                        )

                        ProFeatureHighlightCard(
                            icon: "target",
                            iconColor: Color(hex: "00C7BE"),
                            title: "Goal Walks",
                            description: "Set distance or step targets and get guided to completion"
                        )

                        ProFeatureHighlightCard(
                            icon: "bolt.fill",
                            iconColor: Color(hex: "FF6B35"),
                            title: "Interval Mode",
                            description: "Alternate fast and slow paces to boost your cardio"
                        )

                        ProFeatureHighlightCard(
                            icon: "chart.xyaxis.line",
                            iconColor: Color(hex: "AF52DE"),
                            title: "Advanced Insights",
                            description: "Deeper analytics on your walking patterns and trends"
                        )
                    }

                    // Error message if any
                    if let errorMessage = errorMessage {
                        Text(errorMessage)
                            .font(.footnote)
                            .foregroundStyle(.red)
                            .padding(.horizontal)
                    }

                    // Bottom spacer for sticky footer
                    Spacer(minLength: 180)
                }
                .padding(.horizontal, 24)
            }

            // Sticky footer
            stickyFooter
        }
    }

    // MARK: - Sticky Footer

    private var stickyFooter: some View {
        VStack(spacing: 12) {
            // Price info
            VStack(spacing: 4) {
                Text(priceText)
                    .font(.system(size: 15))
                    .foregroundStyle(.white)

                Text("That's only $3.33/month")
                    .font(.system(size: 13))
                    .foregroundStyle(.white.opacity(0.7))
            }

            // CTA Button
            Button(action: {
                Task {
                    await startFreeTrial()
                }
            }) {
                HStack {
                    if isLoading || storeManager.isPurchasing {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .blue))
                    } else {
                        Text("Try Pro Free for 7 Days")
                            .font(.headline.weight(.semibold))
                    }
                }
                .foregroundStyle(.blue)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(.white)
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .shadow(color: .black.opacity(0.1), radius: 8, y: 4)
            }
            .disabled(isLoading || storeManager.isPurchasing)
            .padding(.horizontal, 32)

            // Skip button
            Button(action: { coordinator.next() }) {
                Text("Maybe later")
                    .font(.system(size: 15))
                    .foregroundStyle(.white.opacity(0.8))
            }
        }
        .padding(.bottom, 48)
        .padding(.top, 20)
        .background(
            LinearGradient(
                colors: [.clear, Color.blue.opacity(0.98)],
                startPoint: .top,
                endPoint: .center
            )
        )
    }

    // MARK: - Computed Properties

    private var priceText: String {
        if let product = storeManager.proAnnualProduct {
            return "\(product.displayPrice)/year after 7-day free trial"
        }
        return "$39.99/year after 7-day free trial"
    }

    // MARK: - Actions

    private func startFreeTrial() async {
        guard let product = storeManager.proAnnualProduct else {
            errorMessage = "Product not available. Please try again later."
            return
        }

        isLoading = true
        errorMessage = nil

        await storeManager.purchase(product)

        isLoading = false

        if storeManager.isPro {
            coordinator.next()
        } else if let error = storeManager.purchaseError {
            errorMessage = error.localizedDescription
        }
    }
}

#Preview {
    ZStack {
        LinearGradient(
            colors: [.blue, .cyan],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()

        ProPaywallOnboardingView()
            .environmentObject(OnboardingCoordinator())
    }
}
