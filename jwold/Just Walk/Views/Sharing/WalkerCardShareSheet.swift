//
//  WalkerCardShareSheet.swift
//  Just Walk
//
//  Full share sheet for the Walker Rank card.
//  Features background customization with Pro-gated options.
//

import SwiftUI

struct WalkerCardShareSheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var rankManager = RankManager.shared
    @ObservedObject private var subscriptionManager = SubscriptionManager.shared

    @AppStorage("walkerDisplayName") private var displayName: String = ""
    @State private var selectedBackground: CardBackground = .solidDark
    @State private var customColor: Color = .blue
    @State private var showPaywall = false
    @State private var showColorPicker = false

    private var rank: WalkerRank {
        rankManager.profile.currentRank
    }

    private var cardData: WalkerCardData {
        WalkerCardData(
            rank: rank,
            displayName: displayName,
            daysAsWalker: rankManager.profile.daysAsWalker,
            totalMiles: rankManager.profile.totalMiles,
            background: selectedBackground,
            customColor: selectedBackground == .customColor ? customColor : nil
        )
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: JWDesign.Spacing.lg) {
                    // Live preview (360x360 = 1080/3)
                    cardPreview

                    // Background selector
                    BackgroundSelector(
                        selectedBackground: $selectedBackground,
                        customColor: $customColor,
                        rankColor: rank.color,
                        isPro: subscriptionManager.isPro
                    ) {
                        showPaywall = true
                    }
                    .padding(.horizontal, JWDesign.Spacing.horizontalInset)

                    // Custom color picker (shown when customColor is selected and user is Pro)
                    if selectedBackground == .customColor && subscriptionManager.isPro {
                        colorPickerSection
                    }

                    // Name field
                    nameFieldSection

                    // Share button
                    shareButton

                    Spacer().frame(height: JWDesign.Spacing.lg)
                }
                .padding(.top, JWDesign.Spacing.md)
            }
            .background(JWDesign.Colors.background)
            .navigationTitle("Share Your Rank")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
        .sheet(isPresented: $showPaywall) {
            ProPaywallView { showPaywall = false }
        }
    }

    // MARK: - Card Preview

    private var cardPreview: some View {
        WalkerCardView(data: cardData)
            .frame(width: 1080, height: 1080)
            .scaleEffect(1/3)
            .frame(width: 360, height: 360)
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .shadow(color: .black.opacity(0.2), radius: 20, y: 10)
            .padding(.horizontal, JWDesign.Spacing.horizontalInset)
    }

    // MARK: - Color Picker Section

    private var colorPickerSection: some View {
        VStack(alignment: .leading, spacing: JWDesign.Spacing.sm) {
            Text("Custom Color")
                .font(JWDesign.Typography.caption)
                .foregroundStyle(.secondary)

            ColorPicker("Select Color", selection: $customColor, supportsOpacity: false)
                .labelsHidden()
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, JWDesign.Spacing.horizontalInset)
    }

    // MARK: - Name Field Section

    private var nameFieldSection: some View {
        VStack(alignment: .leading, spacing: JWDesign.Spacing.sm) {
            Text("Your Name")
                .font(JWDesign.Typography.caption)
                .foregroundStyle(.secondary)

            TextField("Enter your name", text: $displayName)
                .jwTextFieldStyle()
        }
        .padding(.horizontal, JWDesign.Spacing.horizontalInset)
    }

    // MARK: - Share Button

    private var shareButton: some View {
        Button {
            share()
        } label: {
            HStack(spacing: JWDesign.Spacing.sm) {
                Image(systemName: "square.and.arrow.up")
                    .font(.system(size: 18, weight: .semibold))
                Text("Share")
                    .font(JWDesign.Typography.headlineBold)
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, JWDesign.Spacing.md)
            .background(rank.color)
            .clipShape(RoundedRectangle(cornerRadius: JWDesign.Radius.medium))
        }
        .padding(.horizontal, JWDesign.Spacing.horizontalInset)
    }

    // MARK: - Share Action

    private func share() {
        HapticService.shared.playSuccess()

        let cardType = ShareCardType.walkerCard(cardData)
        ShareService.shared.shareCard(cardType)
    }
}

// MARK: - Preview

#Preview("Walker Card Share Sheet") {
    WalkerCardShareSheet()
}

#Preview("Walker Card Share Sheet - Just Walker") {
    WalkerCardShareSheet()
        .onAppear {
            #if DEBUG
            RankManager.shared.debugSetRank(.justWalker)
            #endif
        }
}
