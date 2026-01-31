//
//  ActiveWalkBanner.swift
//  JustWalk
//
//  Persistent banner shown when user navigates away from an active walk
//

import SwiftUI

struct ActiveWalkBanner: View {
    @StateObject private var walkSession = WalkSessionManager.shared
    @State private var isPulsing = false

    let onTap: () -> Void

    var body: some View {
        Button(action: {
            JustWalkHaptics.buttonTap()
            onTap()
        }) {
            HStack(spacing: JW.Spacing.sm) {
                Image(systemName: "figure.walk")
                    .font(.system(size: 16, weight: .semibold))

                Text("Walk in progress")
                    .font(JW.Font.subheadline)
                    .fontWeight(.medium)

                Text("·")
                    .foregroundStyle(.white.opacity(0.7))

                Text(elapsedTimeString)
                    .font(JW.Font.subheadline)
                    .monospacedDigit()
                    .fontWeight(.medium)

                Spacer()

                Text("Tap to return")
                    .font(JW.Font.caption)
                    .foregroundStyle(.white.opacity(0.8))

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.8))
            }
            .padding(.horizontal, JW.Spacing.lg)
            .padding(.vertical, JW.Spacing.md)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: JW.Radius.md)
                    .fill(JW.Color.accent)
            )
            .foregroundStyle(.white)
            .opacity(isPulsing ? 1.0 : 0.88)
        }
        .buttonStyle(.plain)
        .padding(.horizontal, JW.Spacing.lg)
        .padding(.top, JW.Spacing.sm)
        .onAppear {
            withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                isPulsing = true
            }
        }
    }

    private var elapsedTimeString: String {
        let seconds = walkSession.elapsedSeconds
        let minutes = seconds / 60
        let secs = seconds % 60
        return String(format: "%d:%02d", minutes, secs)
    }
}

#Preview {
    ZStack {
        JW.Color.backgroundPrimary.ignoresSafeArea()

        VStack {
            ActiveWalkBanner {
                print("Tapped!")
            }
            Spacer()
        }
    }
}
