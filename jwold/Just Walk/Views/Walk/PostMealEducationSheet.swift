//
//  PostMealEducationSheet.swift
//  Just Walk
//
//  First-time education sheet for Post-Meal Walk.
//  Explains the science behind post-meal walking.
//

import SwiftUI

struct PostMealEducationSheet: View {
    var onDismiss: () -> Void

    var body: some View {
        VStack(spacing: JWDesign.Spacing.xxl) {
            // Icon
            ZStack {
                Circle()
                    .fill(Color(hex: "34C759").opacity(0.15))
                    .frame(width: 80, height: 80)
                Image(systemName: "fork.knife")
                    .font(.system(size: 36))
                    .foregroundStyle(Color(hex: "34C759"))
            }
            .padding(.top, JWDesign.Spacing.xxl)

            // Title
            Text("How Post-Meal Walks Work")
                .font(.title3.bold())

            // Description
            VStack(spacing: JWDesign.Spacing.lg) {
                Text("A 10-minute walk after eating can reduce blood sugar spikes by up to 30%.")
                    .font(JWDesign.Typography.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)

                Text("Best within 30 minutes of a meal. No special pace needed — just walk.")
                    .font(JWDesign.Typography.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, JWDesign.Spacing.xxl)

            Spacer()

            // Got It button
            Button {
                HapticService.shared.playSelection()
                onDismiss()
            } label: {
                Text("Got It")
            }
            .buttonStyle(JWPrimaryButtonStyle(color: Color(hex: "34C759")))
            .padding(.horizontal, JWDesign.Spacing.xl)
            .padding(.bottom, JWDesign.Spacing.xxxl)
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
    }
}

// MARK: - Preview

#Preview {
    Text("Education Sheet")
        .sheet(isPresented: .constant(true)) {
            PostMealEducationSheet(onDismiss: {})
        }
}
