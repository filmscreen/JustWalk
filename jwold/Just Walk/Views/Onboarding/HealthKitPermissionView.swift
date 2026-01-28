//
//  HealthKitPermissionView.swift
//  Just Walk
//
//  Pre-permission screen shown before triggering the system HealthKit prompt.
//

import SwiftUI

struct HealthKitPermissionView: View {
    var onAllow: () -> Void
    @State private var showWhySheet = false

    var body: some View {
        VStack(spacing: JWDesign.Spacing.xl) {
            Spacer()

            // Illustration
            ZStack {
                Circle()
                    .fill(Color.teal.opacity(0.15))
                    .frame(width: 140, height: 140)

                Image(systemName: "figure.walk.circle.fill")
                    .font(.system(size: 80))
                    .foregroundStyle(.teal)
            }

            // Headline
            Text("Let's Count Your Steps")
                .font(.title.bold())
                .multilineTextAlignment(.center)

            // Subtext
            Text("Just Walk needs access to your step data to track your progress and streaks.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, JWDesign.Spacing.lg)

            Spacer()

            // Primary button
            Button(action: onAllow) {
                Text("Allow Step Tracking")
                    .font(JWDesign.Typography.headlineBold)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, JWDesign.Spacing.md)
                    .background(Color.teal)
                    .clipShape(RoundedRectangle(cornerRadius: JWDesign.Radius.button))
            }
            .padding(.horizontal, JWDesign.Spacing.horizontalInset)

            // Secondary link
            Button("Why do you need this?") {
                showWhySheet = true
            }
            .font(.footnote)
            .foregroundStyle(.secondary)
            .padding(.bottom, JWDesign.Spacing.xl)
        }
        .background(JWDesign.Colors.background)
        .sheet(isPresented: $showWhySheet) {
            WhyWeNeedAccessSheet()
        }
    }
}

// MARK: - Preview

#Preview {
    HealthKitPermissionView(onAllow: {})
}
