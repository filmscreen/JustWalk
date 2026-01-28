//
//  RouteNotAvailablePlaceholder.swift
//  JustWalk
//
//  Placeholder shown when no route coordinates are available.
//

import SwiftUI

struct RouteNotAvailablePlaceholder: View {
    var body: some View {
        VStack(spacing: JW.Spacing.md) {
            Image(systemName: "location.slash")
                .font(.system(size: 32, weight: .medium))
                .foregroundStyle(JW.Color.textTertiary)

            Text("Route Not Available")
                .font(JW.Font.subheadline.weight(.medium))
                .foregroundStyle(JW.Color.textSecondary)

            Text("Enable location access in Settings to see your walk route.")
                .font(JW.Font.caption)
                .foregroundStyle(JW.Color.textTertiary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 200)
        .background(
            RoundedRectangle(cornerRadius: JW.Radius.lg)
                .fill(JW.Color.backgroundCard)
        )
    }
}

#Preview {
    RouteNotAvailablePlaceholder()
        .padding()
        .background(JW.Color.backgroundPrimary)
}
