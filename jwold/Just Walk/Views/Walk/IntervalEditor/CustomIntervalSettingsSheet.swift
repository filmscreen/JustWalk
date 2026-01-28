//
//  CustomIntervalSettingsSheet.swift
//  Just Walk
//
//  Simplified custom interval settings for Pro users.
//  Choose interval style and cycle count, then save as default.
//

import SwiftUI

/// Simplified custom interval settings sheet
struct CustomIntervalSettingsSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var storeManager: StoreManager
    @ObservedObject private var prefsManager = PowerWalkPreferencesManager.shared

    @State private var selectedStyle: IntervalStyle = .standard
    @State private var cycleCount: Int = 5
    @State private var showSavedConfirmation = false

    var body: some View {
        NavigationStack {
            ZStack {
                JWDesign.Colors.background
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: JWDesign.Spacing.lg) {
                        // Interval Style Section
                        intervalStyleSection

                        // Number of Cycles Section
                        cycleCountSection

                        // Preview Section
                        previewSection

                        // Save as Default Button
                        saveButton
                    }
                    .padding(.horizontal, JWDesign.Spacing.md)
                    .padding(.top, JWDesign.Spacing.md)
                    .padding(.bottom, JWDesign.Spacing.xl)
                }
            }
            .navigationTitle("Custom Intervals")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        // Apply changes to preferences
                        prefsManager.setIntervalStyle(selectedStyle)
                        prefsManager.setCycleCount(cycleCount)
                        dismiss()
                    }
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Color(hex: "00C7BE"))
                }
            }
            .onAppear {
                // Load current preferences
                selectedStyle = prefsManager.intervalStyle
                cycleCount = prefsManager.cycleCount
            }
        }
    }

    // MARK: - Interval Style Section

    private var intervalStyleSection: some View {
        VStack(alignment: .leading, spacing: JWDesign.Spacing.sm) {
            Text("INTERVAL STYLE")
                .font(JWDesign.Typography.caption)
                .foregroundStyle(Color(.secondaryLabel))
                .tracking(1)

            HStack(spacing: JWDesign.Spacing.sm) {
                ForEach(IntervalStyle.allCases) { style in
                    styleCard(style)
                }
            }
        }
    }

    private func styleCard(_ style: IntervalStyle) -> some View {
        let isSelected = selectedStyle == style

        return Button {
            HapticService.shared.playSelection()
            withAnimation(.spring(response: 0.2, dampingFraction: 0.7)) {
                selectedStyle = style
            }
        } label: {
            VStack(spacing: 8) {
                // Style name
                Text(style.displayName)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(isSelected ? Color(hex: "00C7BE") : .primary)

                // Easy duration
                Text(style.easyFormatted)
                    .font(.system(size: 13, weight: .medium, design: .monospaced))
                    .foregroundStyle(JWDesign.Colors.success)

                // Brisk duration
                Text(style.briskFormatted)
                    .font(.system(size: 13, weight: .medium, design: .monospaced))
                    .foregroundStyle(JWDesign.Colors.brandSecondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(JWDesign.Colors.secondaryBackground)
            .clipShape(RoundedRectangle(cornerRadius: JWDesign.Radius.medium))
            .overlay(
                RoundedRectangle(cornerRadius: JWDesign.Radius.medium)
                    .stroke(isSelected ? Color(hex: "00C7BE") : .clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Cycle Count Section

    private var cycleCountSection: some View {
        VStack(alignment: .leading, spacing: JWDesign.Spacing.sm) {
            Text("NUMBER OF INTERVALS")
                .font(JWDesign.Typography.caption)
                .foregroundStyle(Color(.secondaryLabel))
                .tracking(1)

            HStack(spacing: JWDesign.Spacing.lg) {
                // Decrement button
                Button {
                    if cycleCount > PowerWalkPreferencesManager.minCycles {
                        HapticService.shared.playSelection()
                        cycleCount -= 1
                    }
                } label: {
                    Image(systemName: "minus.circle.fill")
                        .font(.system(size: 36))
                        .foregroundStyle(
                            cycleCount > PowerWalkPreferencesManager.minCycles
                            ? Color(hex: "00C7BE")
                            : Color(.tertiaryLabel)
                        )
                }
                .disabled(cycleCount <= PowerWalkPreferencesManager.minCycles)

                // Count display
                VStack(spacing: 2) {
                    Text("\(cycleCount)")
                        .font(.system(size: 40, weight: .bold, design: .rounded))
                        .foregroundStyle(.primary)
                        .contentTransition(.numericText())

                    Text("intervals")
                        .font(JWDesign.Typography.caption)
                        .foregroundStyle(Color(.secondaryLabel))

                    Text("Easy + Brisk")
                        .font(.system(size: 10))
                        .foregroundStyle(Color(.tertiaryLabel))
                }
                .frame(minWidth: 80)

                // Increment button
                Button {
                    if cycleCount < PowerWalkPreferencesManager.maxCycles {
                        HapticService.shared.playSelection()
                        cycleCount += 1
                    }
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 36))
                        .foregroundStyle(
                            cycleCount < PowerWalkPreferencesManager.maxCycles
                            ? Color(hex: "00C7BE")
                            : Color(.tertiaryLabel)
                        )
                }
                .disabled(cycleCount >= PowerWalkPreferencesManager.maxCycles)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, JWDesign.Spacing.md)
            .background(JWDesign.Colors.secondaryBackground)
            .clipShape(RoundedRectangle(cornerRadius: JWDesign.Radius.medium))
            .animation(JWDesign.Animation.spring, value: cycleCount)
        }
    }

    // MARK: - Preview Section

    private var previewSection: some View {
        VStack(alignment: .leading, spacing: JWDesign.Spacing.sm) {
            Text("PREVIEW")
                .font(JWDesign.Typography.caption)
                .foregroundStyle(Color(.secondaryLabel))
                .tracking(1)

            HStack {
                Image(systemName: "info.circle.fill")
                    .foregroundStyle(Color(hex: "00C7BE"))

                Text(previewText)
                    .font(JWDesign.Typography.body)
                    .foregroundStyle(.primary)

                Spacer()
            }
            .padding(JWDesign.Spacing.md)
            .background(JWDesign.Colors.secondaryBackground)
            .clipShape(RoundedRectangle(cornerRadius: JWDesign.Radius.medium))
        }
    }

    private var previewText: String {
        let totalDuration = selectedStyle.totalDuration(cycles: cycleCount)
        let totalMinutes = Int(totalDuration / 60)
        let steps = selectedStyle.estimatedSteps(cycles: cycleCount)
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        let formattedSteps = formatter.string(from: NSNumber(value: steps)) ?? "\(steps)"
        return "\(totalMinutes) min · \(cycleCount) intervals · ~\(formattedSteps) steps"
    }

    // MARK: - Save Button

    private var saveButton: some View {
        Button {
            HapticService.shared.playSuccess()
            prefsManager.setIntervalStyle(selectedStyle)
            prefsManager.setCycleCount(cycleCount)
            prefsManager.saveCustomDefaults()
            showSavedConfirmation = true

            // Auto-dismiss confirmation after a moment
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                showSavedConfirmation = false
            }
        } label: {
            HStack {
                if showSavedConfirmation {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.white)
                    Text("Saved!")
                        .font(JWDesign.Typography.headlineBold)
                        .foregroundStyle(.white)
                } else {
                    Text("Save as Default")
                        .font(JWDesign.Typography.headline)
                        .foregroundStyle(.white)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, JWDesign.Spacing.md)
            .background(showSavedConfirmation ? JWDesign.Colors.success : Color(hex: "00C7BE"))
            .clipShape(RoundedRectangle(cornerRadius: JWDesign.Radius.medium))
        }
        .animation(.easeInOut(duration: 0.2), value: showSavedConfirmation)
    }
}

// MARK: - Preview

#Preview("Custom Interval Settings") {
    CustomIntervalSettingsSheet()
        .environmentObject(StoreManager.shared)
}
