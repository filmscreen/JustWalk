//
//  WatchOnboardingView.swift
//  Just Walk Watch App
//
//  3-screen onboarding flow for first-time Watch users.
//  Handles HealthKit permission requests and first-launch detection.
//

import SwiftUI

struct WatchOnboardingView: View {
    @State private var currentPage = 0
    @Binding var hasCompletedOnboarding: Bool

    var body: some View {
        TabView(selection: $currentPage) {
            WatchOnboardingWelcomeView(onContinue: { currentPage = 1 })
                .tag(0)

            WatchOnboardingHealthView(onContinue: { currentPage = 2 })
                .tag(1)

            WatchOnboardingReadyView(onComplete: {
                hasCompletedOnboarding = true
            })
                .tag(2)
        }
        .tabViewStyle(.page(indexDisplayMode: .automatic))
        .indexViewStyle(.page(backgroundDisplayMode: .automatic))
    }
}

// MARK: - Color Extension

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

// MARK: - Preview

#Preview {
    WatchOnboardingView(hasCompletedOnboarding: .constant(false))
}
