//
//  CustomRefreshView.swift
//  Just Walk
//
//  Custom branded pull-to-refresh indicator with walking figure animation.
//

import SwiftUI

struct CustomRefreshView: View {
    let isRefreshing: Bool
    let progress: CGFloat // 0-1 based on pull distance

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "figure.walk")
                .font(.system(size: 28, weight: .medium))
                .foregroundStyle(JWDesign.Colors.brandSecondary)
                .symbolEffect(.bounce, options: .repeating, value: isRefreshing)
                .rotationEffect(.degrees(isRefreshing ? 0 : Double(-10 + progress * 20)))
                .scaleEffect(0.8 + progress * 0.4)
                .opacity(progress > 0.1 ? 1.0 : progress * 10)

            if isRefreshing {
                Text("Syncing...")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(height: 60)
    }
}

// MARK: - PreferenceKey for Scroll Offset

struct RefreshOffsetKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

#Preview("Pulling") {
    CustomRefreshView(isRefreshing: false, progress: 0.7)
}

#Preview("Refreshing") {
    CustomRefreshView(isRefreshing: true, progress: 1.0)
}
