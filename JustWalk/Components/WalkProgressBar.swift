//
//  WalkProgressBar.swift
//  JustWalk
//
//  Shared progress bar with optional percentage label
//

import SwiftUI

struct WalkProgressBar: View {
    let progress: Double // 0.0 - 1.0
    var tint: Color = JW.Color.accent
    var showLabel: Bool = true

    var body: some View {
        VStack(spacing: 6) {
            ProgressView(value: min(1.0, progress))
                .tint(tint)
                .scaleEffect(y: 2)
                .padding(.horizontal, JW.Spacing.xxxl)

            if showLabel {
                Text("\(Int(progress * 100))% complete")
                    .font(JW.Font.caption)
                    .foregroundStyle(JW.Color.textSecondary)
            }
        }
    }
}

#Preview {
    WalkProgressBar(progress: 0.65)
        .padding()
        .background(Color.black)
}
