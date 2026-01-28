//
//  WatchOnboardingHealthView.swift
//  Just Walk Watch App
//
//  Health access permission screen.
//  Triggers HealthKit authorization when user taps Continue.
//

import SwiftUI
import WatchKit
import HealthKit

struct WatchOnboardingHealthView: View {
    let onContinue: () -> Void

    @State private var isRequesting = false
    @State private var didRequest = false

    var body: some View {
        VStack(spacing: 12) {
            Spacer()

            // Heart icon
            ZStack {
                Circle()
                    .fill(Color.red.opacity(0.2))
                    .frame(width: 50, height: 50)

                Image(systemName: "heart.fill")
                    .font(.system(size: 24))
                    .foregroundStyle(.red)
            }

            // Title
            Text("Allow Health Access")
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)

            // Subtitle
            Text("To track steps and\nsave your workouts")
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Spacer()

            // Button
            Button {
                WKInterfaceDevice.current().play(.click)
                requestPermissions()
            } label: {
                HStack(spacing: 6) {
                    if isRequesting {
                        ProgressView()
                            .tint(.black)
                    }
                    Text("Continue")
                }
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.black)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(Color(hex: "00C7BE"))
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            .buttonStyle(.plain)
            .disabled(isRequesting)
        }
        .padding(.horizontal, 12)
        .padding(.bottom, 8)
    }

    private func requestPermissions() {
        // If already requested, just continue
        guard !didRequest else {
            print("⌚️ Health: Already requested, continuing")
            onContinue()
            return
        }

        print("⌚️ Health: Requesting HealthKit authorization...")
        isRequesting = true

        Task {
            // Request HealthKit authorization
            await WatchHealthManager.shared.requestAuthorization()

            print("⌚️ Health: Authorization request completed, isAuthorized: \(WatchHealthManager.shared.isAuthorized)")

            await MainActor.run {
                isRequesting = false
                didRequest = true

                // Small delay then continue
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    onContinue()
                }
            }
        }
    }
}

// MARK: - Preview

#Preview {
    WatchOnboardingHealthView(onContinue: {})
}
