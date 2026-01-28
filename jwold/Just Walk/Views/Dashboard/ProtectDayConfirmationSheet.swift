//
//  ProtectDayConfirmationSheet.swift
//  Just Walk
//
//  Confirmation sheet for protecting a missed day with a streak shield.
//  Handles all user states: has shields, Pro out of shields, free no shields.
//

import SwiftUI

struct ProtectDayConfirmationSheet: View {
    @Environment(\.dismiss) private var dismiss

    let day: DayStepData
    let dailyGoal: Int
    @ObservedObject var shieldInventory: ShieldInventoryManager
    @EnvironmentObject var storeManager: StoreManager

    var onUseShield: () -> Void
    var onShowPaywall: () -> Void
    var onDismiss: () -> Void

    // Sheet state for unified purchase
    @State private var showPurchaseSheet = false

    // MARK: - Computed Properties

    private var stepsShort: Int {
        max(0, dailyGoal - day.steps)
    }

    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMMM d"  // "Monday, January 15"
        return formatter.string(from: day.date)
    }

    private var hasShields: Bool {
        shieldInventory.hasShields
    }

    private var isProWithNoShields: Bool {
        storeManager.isPro && !hasShields
    }

    // MARK: - Body

    var body: some View {
        VStack(spacing: JWDesign.Spacing.lg) {
            // Handle indicator
            RoundedRectangle(cornerRadius: 2.5)
                .fill(Color.secondary.opacity(0.3))
                .frame(width: 36, height: 5)
                .padding(.top, JWDesign.Spacing.sm)

            // Header
            headerSection

            // Chain preview
            chainPreview

            // State-specific content
            stateContent

            Spacer()

            // Buttons
            buttonSection
        }
        .background(JWDesign.Colors.background)
        .sheet(isPresented: $showPurchaseSheet) {
            UnifiedShieldPurchaseSheet(
                onPurchaseComplete: {
                    showPurchaseSheet = false
                },
                onShowPaywall: {
                    showPurchaseSheet = false
                    onShowPaywall()
                },
                onDismiss: {
                    showPurchaseSheet = false
                }
            )
            .presentationDetents([.medium, .large])
        }
    }

    // MARK: - Header Section

    private var headerSection: some View {
        VStack(spacing: JWDesign.Spacing.sm) {
            Image(systemName: "shield.fill")
                .font(.system(size: 40))
                .foregroundStyle(Color(hex: "FF9500"))

            Text("Protect \(formattedDate)?")
                .font(.title3.bold())
                .multilineTextAlignment(.center)

            Text("You were \(stepsShort.formatted()) steps short")
                .font(JWDesign.Typography.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(.top, JWDesign.Spacing.md)
    }

    // MARK: - Chain Preview Visual

    private var chainPreview: some View {
        HStack(spacing: 0) {
            // Previous day (teal filled)
            Circle()
                .fill(Color(hex: "00C7BE"))
                .frame(width: 28, height: 28)

            // Connector with shield (larger for emphasis)
            HStack(spacing: 4) {
                Rectangle()
                    .fill(Color(hex: "00C7BE"))
                    .frame(width: 20, height: 3)

                Image(systemName: "shield.fill")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(Color(hex: "FF9500"))

                Rectangle()
                    .fill(Color(hex: "00C7BE"))
                    .frame(width: 20, height: 3)
            }

            // Next day (teal filled)
            Circle()
                .fill(Color(hex: "00C7BE"))
                .frame(width: 28, height: 28)
        }
        .padding(.vertical, JWDesign.Spacing.sm)
    }

    // MARK: - State-Specific Content

    @ViewBuilder
    private var stateContent: some View {
        if hasShields {
            // User has shields available
            Text(shieldInventory.shieldCountText)
                .font(JWDesign.Typography.subheadline)
                .foregroundStyle(.secondary)
        } else if isProWithNoShields {
            // Pro user, but used all monthly shields
            VStack(spacing: JWDesign.Spacing.xs) {
                Text(shieldInventory.usedAllMonthlyText)
                    .font(JWDesign.Typography.subheadline)
                    .foregroundStyle(.secondary)

                if let refreshText = shieldInventory.refreshDateText {
                    Text(refreshText)
                        .font(JWDesign.Typography.caption)
                        .foregroundStyle(.tertiary)
                }
            }
        } else {
            // Free user, no shields
            EmptyView()
        }
    }

    // MARK: - Button Section

    @ViewBuilder
    private var buttonSection: some View {
        VStack(spacing: JWDesign.Spacing.md) {
            if hasShields {
                // Has shields: Show "Use 1 Shield" button
                useShieldButton
            } else if isProWithNoShields {
                // Pro but no shields: Show divider + $3.99 option
                proNoShieldsButtons
            } else {
                // Free, no shields: Show "Get Shields" → opens unified purchase sheet
                getShieldsButton
            }

            // Always show "Not Now"
            notNowButton
        }
        .padding(.horizontal, JWDesign.Spacing.horizontalInset)
        .padding(.bottom, JWDesign.Spacing.xl)
    }

    private var useShieldButton: some View {
        Button(action: {
            onUseShield()
            dismiss()
        }) {
            HStack {
                Image(systemName: "shield.fill")
                Text("Use 1 Shield")
            }
            .font(JWDesign.Typography.headlineBold)
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, JWDesign.Spacing.md)
            .background(Color(hex: "00C7BE"))
            .clipShape(RoundedRectangle(cornerRadius: JWDesign.Radius.button))
        }
    }

    private var proNoShieldsButtons: some View {
        VStack(spacing: JWDesign.Spacing.md) {
            // Divider with "need more?"
            HStack {
                Rectangle()
                    .fill(Color(.separator))
                    .frame(height: 1)
                Text("need more?")
                    .font(JWDesign.Typography.caption)
                    .foregroundStyle(.tertiary)
                Rectangle()
                    .fill(Color(.separator))
                    .frame(height: 1)
            }

            // $3.99 one-off option
            Button(action: {
                showPurchaseSheet = true
            }) {
                HStack(spacing: JWDesign.Spacing.sm) {
                    Image(systemName: "shield.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(Color(hex: "FF9500"))

                    VStack(alignment: .leading, spacing: 2) {
                        Text("1 Shield — $3.99")
                            .font(JWDesign.Typography.bodyBold)
                            .foregroundStyle(.primary)
                        Text("One-time purchase")
                            .font(JWDesign.Typography.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()
                }
                .padding(JWDesign.Spacing.md)
                .background(JWDesign.Colors.secondaryBackground)
                .clipShape(RoundedRectangle(cornerRadius: JWDesign.Radius.medium))
            }
        }
    }

    private var getShieldsButton: some View {
        Button(action: {
            showPurchaseSheet = true
        }) {
            HStack {
                Image(systemName: "shield.fill")
                Text("Get Shields")
            }
            .font(JWDesign.Typography.headlineBold)
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, JWDesign.Spacing.md)
            .background(Color(hex: "FF9500"))
            .clipShape(RoundedRectangle(cornerRadius: JWDesign.Radius.button))
        }
    }

    private var notNowButton: some View {
        Button(action: {
            onDismiss()
            dismiss()
        }) {
            Text("Not Now")
                .font(JWDesign.Typography.subheadline)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, JWDesign.Spacing.sm)
        }
    }
}

// MARK: - Preview

#Preview("Has Shields") {
    let sampleDay = DayStepData(
        date: Calendar.current.date(byAdding: .day, value: -2, to: Date())!,
        steps: 8500,
        distance: 6.5,
        historicalGoal: 10000
    )

    ProtectDayConfirmationSheet(
        day: sampleDay,
        dailyGoal: 10000,
        shieldInventory: ShieldInventoryManager.shared,
        onUseShield: {},
        onShowPaywall: {},
        onDismiss: {}
    )
    .environmentObject(StoreManager.shared)
}

#Preview("No Shields - Free User") {
    let sampleDay = DayStepData(
        date: Calendar.current.date(byAdding: .day, value: -3, to: Date())!,
        steps: 4200,
        distance: 3.2,
        historicalGoal: 10000
    )

    ProtectDayConfirmationSheet(
        day: sampleDay,
        dailyGoal: 10000,
        shieldInventory: ShieldInventoryManager.shared,
        onUseShield: {},
        onShowPaywall: {},
        onDismiss: {}
    )
    .environmentObject(StoreManager.shared)
}
