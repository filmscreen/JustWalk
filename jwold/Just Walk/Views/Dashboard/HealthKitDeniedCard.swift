//
//  HealthKitDeniedCard.swift
//  Just Walk
//
//  Card shown when HealthKit permission is denied, replacing the progress ring.
//

import SwiftUI

struct HealthKitDeniedCard: View {
    var body: some View {
        VStack(spacing: JWDesign.Spacing.md) {
            // Warning icon
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 48))
                .foregroundStyle(.orange)

            // Headline
            Text("Step Tracking Disabled")
                .font(JWDesign.Typography.headlineBold)

            // Subtext
            Text("Just Walk needs access to Health data to count your steps.")
                .font(JWDesign.Typography.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, JWDesign.Spacing.md)

            // Primary button
            Button(action: openHealthSettings) {
                Text("Enable in Settings")
                    .font(JWDesign.Typography.headlineBold)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, JWDesign.Spacing.md)
                    .background(Color.teal)
                    .clipShape(RoundedRectangle(cornerRadius: JWDesign.Radius.button))
            }
            .padding(.horizontal, JWDesign.Spacing.lg)
            .padding(.top, JWDesign.Spacing.sm)
        }
        .padding(JWDesign.Spacing.lg)
        .frame(maxWidth: .infinity)
        .background(JWDesign.Colors.secondaryBackground)
        .clipShape(RoundedRectangle(cornerRadius: JWDesign.Radius.card))
    }

    private func openHealthSettings() {
        // Try to open Health app directly, fall back to Settings
        if let healthURL = URL(string: "x-apple-health://"),
           UIApplication.shared.canOpenURL(healthURL) {
            UIApplication.shared.open(healthURL)
        } else if let settingsURL = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(settingsURL)
        }
    }
}

// MARK: - Preview

#Preview {
    VStack {
        HealthKitDeniedCard()
            .padding()
    }
    .background(Color.gray.opacity(0.1))
}
