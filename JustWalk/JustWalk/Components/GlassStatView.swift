//
//  GlassStatView.swift
//  JustWalk
//
//  Reusable Liquid Glass stat display component
//

import SwiftUI

struct GlassStatView: View {
    let value: String
    let label: String
    let icon: String?

    var body: some View {
        VStack(spacing: 8) {
            if let icon = icon {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundStyle(JW.Color.accent)
            }

            Text(value)
                .font(JW.Font.title2.bold().monospacedDigit())

            Text(label)
                .font(JW.Font.caption)
                .foregroundStyle(JW.Color.textSecondary)
        }
        .padding()
        .jwGlassEffect()
    }
}
