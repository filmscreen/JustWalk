//
//  NotificationPermissionOnboardingView.swift
//  Just Walk
//
//  Created by Randy Chia on 1/22/26.
//

import SwiftUI

struct NotificationPermissionOnboardingView: View {
    @EnvironmentObject private var coordinator: OnboardingCoordinator
    @State private var isRequesting = false

    private let benefits = [
        "Streak at risk reminders",
        "Goal celebration",
        "Weekly progress"
    ]

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            Image(systemName: "bell.badge.fill")
                .font(.system(size: 70))
                .foregroundStyle(.white)

            Text("Stay on Track")
                .font(.title2.bold())
                .foregroundStyle(.white)

            Text("Get reminders to keep your streak alive and celebrate your wins.")
                .font(.body)
                .foregroundStyle(.white.opacity(0.85))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            // Bullet list card
            VStack(alignment: .leading, spacing: 12) {
                ForEach(benefits, id: \.self) { benefit in
                    HStack(spacing: 12) {
                        Text("•")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(.white)
                        Text(benefit)
                            .font(.subheadline)
                            .foregroundStyle(.white)
                    }
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.white.opacity(0.15))
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .padding(.horizontal, 24)

            Spacer()

            VStack(spacing: 16) {
                Button(action: {
                    Task {
                        await requestNotifications()
                    }
                }) {
                    HStack(spacing: 8) {
                        if isRequesting {
                            ProgressView()
                                .tint(.blue)
                        }
                        Text("Enable Notifications")
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

                Button(action: { coordinator.next() }) {
                    Text("Not now")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.8))
                }
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 48)
        }
    }

    private func requestNotifications() async {
        isRequesting = true
        _ = await NotificationPermissionManager.shared.requestPermission()
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

        NotificationPermissionOnboardingView()
            .environmentObject(OnboardingCoordinator())
    }
}
