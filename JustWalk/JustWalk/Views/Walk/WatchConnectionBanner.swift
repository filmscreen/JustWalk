//
//  WatchConnectionBanner.swift
//  JustWalk
//
//  Shows Apple Watch connection status on the Walks screen
//

import SwiftUI

struct WatchConnectionBanner: View {
    @ObservedObject private var connectivity = PhoneConnectivityManager.shared

    private var state: ConnectionState {
        if !connectivity.canCommunicateWithWatch {
            return .notPaired
        } else if connectivity.isWatchReachable {
            return .connected
        } else {
            return .notReachable
        }
    }

    var body: some View {
        switch state {
        case .connected:
            banner(
                icon: "applewatch",
                dot: JW.Color.accent,
                text: "Apple Watch Connected"
            )
        case .notReachable:
            banner(
                icon: "applewatch",
                dot: JW.Color.streak,
                text: "Watch Not Reachable"
            )
        case .notPaired:
            EmptyView()
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

    private enum ConnectionState {
        case connected
        case notReachable
        case notPaired
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
