//
//  ShieldEducationSheet.swift
//  Just Walk
//
//  Shield education view - shows either first-time education or refresher info.
//  First-time: Shown once when user first has shields.
//  Refresher: Available via info button for quick reference.
//

import SwiftUI

struct ShieldEducationSheet: View {
    let isFirstTime: Bool
    let shieldCount: Int
    var onDismiss: () -> Void

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Hero section
                    heroSection

                    // Description
                    descriptionSection

                    // How they work rules
                    rulesSection

                    // Shield count (refresher only)
                    if !isFirstTime {
                        shieldCountSection
                    }

                    // Action button
                    actionButton
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 32)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle(isFirstTime ? "" : "How Shields Work")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if !isFirstTime {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            onDismiss()
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 24))
                                .foregroundStyle(Color(.tertiaryLabel))
                        }
                    }
                }
            }
        }
    }

    // MARK: - Hero Section

    private var heroSection: some View {
        VStack(spacing: 16) {
            // Shield icon with pulse
            Image(systemName: "shield.fill")
                .font(.system(size: 56))
                .foregroundStyle(Color(hex: "00C7BE"))
                .symbolEffect(.pulse, options: .repeating)

            if isFirstTime {
                Text("You Have Streak Shields!")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.center)
            }
        }
    }

    // MARK: - Description Section

    private var descriptionSection: some View {
        VStack(spacing: 16) {
            Text(isFirstTime
                ? "Life happens. Shields let you protect missed days and keep your streak alive."
                : "Shields protect missed days and keep your streak alive.")
                .font(.system(size: 17))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            // Visual diagram
            shieldDiagram
        }
    }

    // MARK: - Shield Diagram

    private var shieldDiagram: some View {
        HStack(spacing: 0) {
            // Before
            VStack(spacing: 4) {
                Circle()
                    .fill(Color(hex: "00C7BE"))
                    .frame(width: 24, height: 24)
                Text("Before")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }

            // Connector line
            Rectangle()
                .fill(Color(.separator))
                .frame(width: 24, height: 2)

            // Shield (gap)
            VStack(spacing: 4) {
                ZStack {
                    Circle()
                        .fill(Color(hex: "00C7BE"))
                        .frame(width: 24, height: 24)
                    Image(systemName: "shield.fill")
                        .font(.system(size: 10))
                        .foregroundStyle(.white)
                }
                Text("Gap")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }

            // Connector line
            Rectangle()
                .fill(Color(.separator))
                .frame(width: 24, height: 2)

            // After
            VStack(spacing: 4) {
                Circle()
                    .fill(Color(hex: "00C7BE"))
                    .frame(width: 24, height: 24)
                Text("After")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 16)
        .padding(.horizontal, 24)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Rules Section

    private var rulesSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("HOW THEY WORK")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.secondary)
                .tracking(0.5)

            VStack(alignment: .leading, spacing: 12) {
                ruleRow(icon: "clock.fill", text: "Apply within 7 days of a miss")
                ruleRow(icon: "link", text: "Day must connect to your streak")
                ruleRow(icon: "plus.circle.fill", iconColor: Color(hex: "FF9500"), text: "Tap the orange + on any protectable day")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func ruleRow(icon: String, iconColor: Color = Color(hex: "00C7BE"), text: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundStyle(iconColor)
                .frame(width: 24)

            Text(text)
                .font(.system(size: 15))
                .foregroundStyle(.primary)
        }
    }

    // MARK: - Shield Count Section

    private var shieldCountSection: some View {
        HStack(spacing: 8) {
            Image(systemName: "shield.fill")
                .font(.system(size: 16))
                .foregroundStyle(Color(hex: "00C7BE"))

            Text("You have: \(shieldCount) shield\(shieldCount == 1 ? "" : "s")")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(.primary)
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
        .background(Color(hex: "00C7BE").opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    // MARK: - Action Button

    private var actionButton: some View {
        Button {
            HapticService.shared.playSelection()
            onDismiss()
        } label: {
            Text(isFirstTime ? "Got it" : "Done")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(Color(hex: "00C7BE"))
                .clipShape(RoundedRectangle(cornerRadius: 14))
        }
    }
}

// MARK: - Previews

#Preview("First Time") {
    ShieldEducationSheet(
        isFirstTime: true,
        shieldCount: 3,
        onDismiss: {}
    )
}

#Preview("Refresher") {
    ShieldEducationSheet(
        isFirstTime: false,
        shieldCount: 2,
        onDismiss: {}
    )
}
