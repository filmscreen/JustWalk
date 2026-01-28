//
//  EducationSheetTemplate.swift
//  JustWalk
//
//  Reusable full-screen education sheet with icon, title, message, and action button
//

import SwiftUI

struct EducationSheetTemplate: View {
    let icon: String
    let iconColor: Color
    let title: String
    let message: String
    var buttonTitle: String = "Got It"
    let onContinue: () -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: JW.Spacing.xxl) {
            Spacer()

            ZStack {
                Circle()
                    .fill(iconColor.opacity(0.15))
                    .frame(width: 100, height: 100)

                Image(systemName: icon)
                    .font(.system(size: 44, weight: .medium))
                    .foregroundStyle(iconColor)
            }

            VStack(spacing: JW.Spacing.md) {
                Text(title)
                    .font(JW.Font.title1)
                    .foregroundStyle(JW.Color.textPrimary)
                    .multilineTextAlignment(.center)

                Text(message)
                    .font(JW.Font.body)
                    .foregroundStyle(JW.Color.textSecondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, JW.Spacing.xl)

            Spacer()

            Button(action: {
                JustWalkHaptics.buttonTap()
                onContinue()
            }) {
                Text(buttonTitle)
                    .font(JW.Font.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(JW.Color.accent)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: JW.Radius.lg))
            }
            .buttonPressEffect()
            .padding(.horizontal, JW.Spacing.xl)
            .padding(.bottom, 40)
        }
        .background(JW.Color.backgroundPrimary)
        .presentationDetents([.large])
    }
}

#Preview {
    EducationSheetTemplate(
        icon: "bolt.fill",
        iconColor: .blue,
        title: "Sample Education",
        message: "This is a sample education sheet to demonstrate the template.",
        onContinue: {}
    )
}
