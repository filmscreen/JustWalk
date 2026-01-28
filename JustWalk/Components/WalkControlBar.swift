//
//  WalkControlBar.swift
//  JustWalk
//
//  Shared pause/resume + end walk controls for free walk, fat burn, and post-meal
//

import SwiftUI

struct WalkControlBar: View {
    let isPaused: Bool
    let onTogglePause: () -> Void
    let onEnd: () -> Void

    var body: some View {
        HStack(spacing: 24) {
            Button(action: onTogglePause) {
                Image(systemName: isPaused ? "play.fill" : "pause.fill")
                    .font(JW.Font.title2)
                    .frame(width: 60, height: 60)
            }
            .jwGlassEffect()
            .buttonPressEffect()

            Button(action: onEnd) {
                Text("End Walk")
                    .font(JW.Font.headline)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 32)
                    .padding(.vertical, 16)
            }
            .jwGlassEffect(tintColor: JW.Color.danger)
            .buttonPressEffect()
        }
        .padding()
        .jwGlassEffect()
        .padding(.bottom, 40)
    }
}

#Preview {
    WalkControlBar(isPaused: false, onTogglePause: {}, onEnd: {})
        .padding()
        .background(Color.black)
}
