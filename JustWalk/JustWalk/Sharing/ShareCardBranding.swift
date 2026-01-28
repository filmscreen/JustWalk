//
//  ShareCardBranding.swift
//  JustWalk
//
//  Branding overlay for all share cards
//

import SwiftUI

struct ShareCardBranding: View {
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "figure.walk")
                .font(.system(size: 14, weight: .semibold))

            Text("Just Walk")
                .font(.system(size: 14, weight: .semibold, design: .rounded))
        }
        .foregroundStyle(.white.opacity(0.5))
        .padding(12)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
    }
}
