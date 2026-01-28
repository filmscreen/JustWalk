//
//  WalkTypeSelectionView.swift
//  Just Walk
//
//  Screen 2: Walk type selection.
//  Shows available walk types with estimated steps based on selected duration.
//

import SwiftUI

struct WalkTypeSelectionView: View {
    let durationMinutes: Int

    @StateObject private var subscriptionManager = SubscriptionManager.shared
    @State private var selectedWalkType: WalkType? = nil
    @State private var navigateToConfirmation = false
    @State private var showPaywall = false
    @State private var pendingWalkType: WalkType? = nil
    @State private var showComingSoonToast = false
    @State private var comingSoonMessage = ""

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Header
                Text("Choose your walk")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(.primary)
                    .padding(.top, 8)

                // Walk type cards
                ForEach(WalkType.allCases) { walkType in
                    walkTypeCard(walkType)
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 40)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("\(durationMinutes) min")
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(isPresented: $navigateToConfirmation) {
            if let walkType = selectedWalkType {
                WalkConfirmationView(
                    walkType: walkType,
                    durationMinutes: durationMinutes
                )
            }
        }
        .sheet(isPresented: $showPaywall) {
            ProPaywallView {
                showPaywall = false
                if let pending = pendingWalkType {
                    selectedWalkType = pending
                    pendingWalkType = nil
                    navigateToConfirmation = true
                }
            }
        }
        .overlay(alignment: .bottom) {
            if showComingSoonToast {
                Text(comingSoonMessage)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(Capsule().fill(Color(hex: "8E8E93")))
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .padding(.bottom, 40)
            }
        }
    }

    // MARK: - Walk Type Card

    private func walkTypeCard(_ walkType: WalkType) -> some View {
        Button {
            handleWalkTypeTap(walkType)
        } label: {
            HStack(spacing: 12) {
                // Icon
                ZStack {
                    Circle()
                        .fill(walkType.themeColor.opacity(0.15))
                        .frame(width: 44, height: 44)
                    Image(systemName: walkType.icon)
                        .font(.system(size: 20))
                        .foregroundStyle(walkType.themeColor)
                }

                // Content
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text(walkType.name)
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(.primary)

                        // Badge
                        Text(walkType.badgeText)
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(walkType.badgeColor)
                            .clipShape(Capsule())
                    }

                    Text(walkType.benefit)
                        .font(.system(size: 15, weight: .regular))
                        .foregroundStyle(.secondary)

                    Text(walkType.formattedSteps(for: durationMinutes))
                        .font(.system(size: 13, weight: .regular))
                        .foregroundStyle(Color(.tertiaryLabel))
                }

                Spacer()

                // Chevron
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color(.tertiaryLabel))
            }
            .padding(16)
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .opacity(walkType.isAvailable ? 1.0 : 0.6)
        }
        .buttonStyle(ScaleButtonStyle())
    }

    // MARK: - Actions

    private func handleWalkTypeTap(_ walkType: WalkType) {
        HapticService.shared.playSelection()

        // Check if coming soon
        guard walkType.isAvailable else {
            comingSoonMessage = "\(walkType.name) coming soon!"
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                showComingSoonToast = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                withAnimation(.easeOut(duration: 0.2)) {
                    showComingSoonToast = false
                }
            }
            return
        }

        // Check Pro requirement
        if walkType.isPro && !subscriptionManager.isPro {
            pendingWalkType = walkType
            showPaywall = true
            return
        }

        // Navigate to confirmation
        selectedWalkType = walkType
        navigateToConfirmation = true
    }
}

// MARK: - Scale Button Style

struct ScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.spring(response: 0.2, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        WalkTypeSelectionView(durationMinutes: 30)
    }
}
