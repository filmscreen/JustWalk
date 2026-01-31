//
//  HealthAccessRequiredView.swift
//  JustWalk
//
//  Full-screen view shown when HealthKit permission is denied.
//

import SwiftUI

struct HealthAccessRequiredView: View {
    var body: some View {
        ZStack {
            JW.Color.backgroundPrimary
                .ignoresSafeArea()

            VStack(spacing: JW.Spacing.xxl) {
                Spacer()

                // Icon
                ZStack {
                    Circle()
                        .fill(JW.Color.danger.opacity(0.15))
                        .frame(width: 100, height: 100)

                    Image(systemName: "heart.slash")
                        .font(.system(size: 44, weight: .medium))
                        .foregroundStyle(JW.Color.danger)
                }

                // Title + description
                VStack(spacing: JW.Spacing.md) {
                    Text("Health Access Required")
                        .font(JW.Font.title1)
                        .foregroundStyle(JW.Color.textPrimary)
                        .multilineTextAlignment(.center)

                    Text("JustWalk needs access to Health data to see your walking progress.")
                        .font(JW.Font.body)
                        .foregroundStyle(JW.Color.textSecondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, JW.Spacing.xl)

                Spacer()

                // CTA + note
                VStack(spacing: JW.Spacing.lg) {
                    Button(action: openSettings) {
                        Text("Open Settings")
                            .font(JW.Font.headline)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(JW.Color.accent)
                            .foregroundStyle(.black)
                            .clipShape(RoundedRectangle(cornerRadius: JW.Radius.lg))
                    }
                    .buttonPressEffect()
                    .padding(.horizontal, JW.Spacing.xl)

                    Text("Go to Health > Data Access > JustWalk and enable all permissions.")
                        .font(JW.Font.caption)
                        .foregroundStyle(JW.Color.textTertiary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, JW.Spacing.xxl)
                }
                .padding(.bottom, 40)
            }
        }
    }

    private func openSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }
}

#Preview {
    HealthAccessRequiredView()
}
