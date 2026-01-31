//
//  WatchConnectionBanner.swift
//  JustWalk
//
//  Shows Apple Watch connection status on the Walks screen
//

import SwiftUI

struct WatchConnectionBanner: View {
    @ObservedObject private var connectivity = PhoneConnectivityManager.shared

    var body: some View {
        // Only show banner when watch is paired and app is installed
        if connectivity.isWatchConnectedStable {
            banner(
                icon: "applewatch",
                dot: JW.Color.accent,
                text: "Apple Watch Connected"
            )
        }
    }

    private func banner(icon: String, dot: Color, text: String) -> some View {
        HStack(spacing: JW.Spacing.sm) {
            ZStack(alignment: .bottomTrailing) {
                Image(systemName: icon)
                    .font(.system(size: 14))
                    .foregroundStyle(JW.Color.textSecondary)

                Circle()
                    .fill(dot)
                    .frame(width: 7, height: 7)
                    .offset(x: 2, y: 2)
            }

            Text(text)
                .font(JW.Font.caption)
                .foregroundStyle(JW.Color.textSecondary)
        }
        .padding(.horizontal, JW.Spacing.md)
        .padding(.vertical, JW.Spacing.sm)
        .background(
            Capsule()
                .fill(JW.Color.backgroundCard)
        )
        .overlay(
            Capsule()
                .stroke(Color.white.opacity(0.06), lineWidth: 1)
        )
    }

}

#Preview {
    ZStack {
        JW.Color.backgroundPrimary.ignoresSafeArea()
        VStack(spacing: 16) {
            WatchConnectionBanner()
        }
    }
}
