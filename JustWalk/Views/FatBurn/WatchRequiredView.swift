//
//  WatchRequiredView.swift
//  JustWalk
//
//  Shown when user taps Fat Burn Zone without an Apple Watch paired.
//  Provides graceful fallback to Intervals.
//

import SwiftUI

struct WatchRequiredView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            JW.Color.backgroundPrimary
                .ignoresSafeArea()

            VStack(spacing: JW.Spacing.xxl) {
                Spacer()

                // Icon
                ZStack {
                    Circle()
                        .fill(JW.Color.streak.opacity(0.15))
                        .frame(width: 100, height: 100)

                    Image(systemName: "applewatch")
                        .font(.system(size: 44, weight: .medium))
                        .foregroundStyle(JW.Color.streak)
                }

                // Title + description
                VStack(spacing: JW.Spacing.md) {
                    Text("Apple Watch Required")
                        .font(JW.Font.title1)
                        .foregroundStyle(JW.Color.textPrimary)
                        .multilineTextAlignment(.center)

                    Text("Fat Burn Zone uses real-time heart rate to guide your walk. Please pair an Apple Watch to use this feature.")
                        .font(JW.Font.body)
                        .foregroundStyle(JW.Color.textSecondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, JW.Spacing.xl)

                Spacer()

                // Alternative suggestion
                VStack(spacing: JW.Spacing.md) {
                    Text("Don't have one?")
                        .font(JW.Font.subheadline)
                        .foregroundStyle(JW.Color.textSecondary)

                    Button(action: {
                        JustWalkHaptics.buttonTap()
                        dismiss()
                    }) {
                        HStack(spacing: JW.Spacing.sm) {
                            Text("Try Intervals for a similar fat-burning effect")
                                .font(JW.Font.subheadline)
                                .foregroundStyle(JW.Color.accent)

                            Image(systemName: "arrow.right")
                                .font(JW.Font.caption)
                                .foregroundStyle(JW.Color.accent)
                        }
                    }
                }

                // Back button
                Button(action: {
                    JustWalkHaptics.buttonTap()
                    dismiss()
                }) {
                    Text("Go Back")
                        .font(JW.Font.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(JW.Color.backgroundCard)
                        .foregroundStyle(JW.Color.textPrimary)
                        .clipShape(RoundedRectangle(cornerRadius: JW.Radius.lg))
                }
                .buttonPressEffect()
                .padding(.horizontal, JW.Spacing.xl)
                .padding(.bottom, 40)
            }
        }
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button(action: { dismiss() }) {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                        Text("Back")
                    }
                    .foregroundStyle(JW.Color.textSecondary)
                }
            }
        }
    }
}

#Preview {
    NavigationStack {
        WatchRequiredView()
    }
}
