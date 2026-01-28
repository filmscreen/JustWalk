//
//  HealthPermissionOnboardingView.swift
//  Just Walk
//
//  Created by Randy Chia on 1/22/26.
//

import SwiftUI
import HealthKit

struct HealthPermissionOnboardingView: View {
    @EnvironmentObject private var coordinator: OnboardingCoordinator
    @State private var isRequesting = false

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            // Icon with white circle background
            ZStack {
                Circle()
                    .fill(.white)
                    .frame(width: 100, height: 100)

                Image(systemName: "heart.fill")
                    .font(.system(size: 50))
                    .foregroundStyle(.red)
            }

            Text("Count Your Steps")
                .font(.title2.bold())
                .foregroundStyle(.white)

            Text("Just Walk uses Apple Health to track your daily steps and walking distance.")
                .font(.body)
                .foregroundStyle(.white.opacity(0.85))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            // Privacy note
            HStack(spacing: 8) {
                Image(systemName: "lock.fill")
                    .font(.system(size: 14))
                Text("Your data stays on your device. We never upload or share it.")
                    .font(.footnote)
            }
            .foregroundStyle(.white.opacity(0.7))
            .multilineTextAlignment(.center)
            .padding(.horizontal, 40)

            Spacer()

            Button(action: {
                Task {
                    await requestHealthPermission()
                }
            }) {
                HStack(spacing: 8) {
                    if isRequesting {
                        ProgressView()
                            .tint(.blue)
                    }
                    Text("Connect Apple Health")
                        .font(.headline.weight(.semibold))
                }
                .foregroundStyle(.blue)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(.white)
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .shadow(color: .black.opacity(0.1), radius: 8, y: 4)
            }
            .disabled(isRequesting)
            .padding(.horizontal, 32)
            .padding(.bottom, 48)
        }
    }

    private func requestHealthPermission() async {
        guard HKHealthStore.isHealthDataAvailable() else {
            coordinator.next()
            return
        }

        isRequesting = true
        do {
            try await HealthKitService.shared.requestAuthorization()
        } catch {
            // Proceed regardless of error
        }
        isRequesting = false
        coordinator.next()
    }
}

#Preview {
    ZStack {
        LinearGradient(
            colors: [.blue, .cyan],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()

        HealthPermissionOnboardingView()
            .environmentObject(OnboardingCoordinator())
    }
}
