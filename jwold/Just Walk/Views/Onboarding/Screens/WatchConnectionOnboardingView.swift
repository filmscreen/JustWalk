//
//  WatchConnectionOnboardingView.swift
//  Just Walk
//
//  Created by Randy Chia on 1/22/26.
//

import SwiftUI
import WatchConnectivity

struct WatchConnectionOnboardingView: View {
    @EnvironmentObject private var coordinator: OnboardingCoordinator
    @State private var showingToast = false

    private let features = [
        "Steps sync automatically",
        "Start walks from Watch",
        "Track routes on the go"
    ]

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            Image(systemName: "applewatch")
                .font(.system(size: 70))
                .foregroundStyle(.white)

            Text("Connect Apple Watch")
                .font(.title2.bold())
                .foregroundStyle(.white)

            Text("See your progress and start walks directly from your wrist.")
                .font(.body)
                .foregroundStyle(.white.opacity(0.85))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            // Feature list card
            VStack(alignment: .leading, spacing: 12) {
                ForEach(features, id: \.self) { feature in
                    HStack(spacing: 12) {
                        Image(systemName: "checkmark")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(Color(hex: "34C759"))
                        Text(feature)
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
                Button(action: connectNow) {
                    Text("Connect Now")
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(.blue)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                        .shadow(color: .black.opacity(0.1), radius: 8, y: 4)
                }

                Button(action: { coordinator.next() }) {
                    Text("Set up later")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.8))
                }
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 48)
        }
        .overlay(alignment: .top) {
            if showingToast {
                toastView
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .padding(.top, 60)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: showingToast)
    }

    private var toastView: some View {
        HStack(spacing: 12) {
            Image(systemName: "applewatch")
                .font(.system(size: 20))
            Text("Open Just Walk on your Apple Watch")
                .font(.subheadline.weight(.medium))
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(Color.black.opacity(0.8))
        .clipShape(Capsule())
    }

    private func connectNow() {
        // Activate WCSession if needed
        if WCSession.isSupported() {
            let session = WCSession.default
            if session.activationState != .activated {
                session.activate()
            }
        }

        // Show toast
        showingToast = true

        // After 2 second delay, advance to next screen
        Task {
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            coordinator.next()
        }
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

        WatchConnectionOnboardingView()
            .environmentObject(OnboardingCoordinator())
    }
}
