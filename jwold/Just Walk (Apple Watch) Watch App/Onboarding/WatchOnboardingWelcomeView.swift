//
//  WatchOnboardingWelcomeView.swift
//  Just Walk Watch App
//
//  Welcome screen introducing the app.
//  First screen of the onboarding flow.
//

import SwiftUI
import WatchKit

struct WatchOnboardingWelcomeView: View {
    let onContinue: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            Spacer()

            // App icon
            ZStack {
                Circle()
                    .fill(Color(hex: "00C7BE").opacity(0.2))
                    .frame(width: 60, height: 60)

                Image(systemName: "figure.walk")
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundStyle(Color(hex: "00C7BE"))
            }

            // Title
            Text("Just Walk")
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(.white)

            // Subtitle
            Text("Track your steps\nfrom your wrist")
                .font(.system(size: 14))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Spacer()

            // Button
            Button {
                WKInterfaceDevice.current().play(.click)
                onContinue()
            } label: {
                Text("Get Started")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color(hex: "00C7BE"))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 12)
        .padding(.bottom, 8)
    }
}

// MARK: - Preview

#Preview {
    WatchOnboardingWelcomeView(onContinue: {})
}
