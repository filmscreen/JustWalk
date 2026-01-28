//
//  RankUpCelebrationView.swift
//  Just Walk
//
//  Full-screen celebration overlay shown when user ranks up.
//  Uses confetti and haptic feedback to create a memorable moment.
//

import SwiftUI

struct RankUpCelebrationView: View {
    let rank: WalkerRank
    let onDismiss: () -> Void

    @State private var showContent = false
    @State private var showConfetti = false

    var body: some View {
        ZStack {
            // Dark scrim background
            Color.black.opacity(0.85)
                .ignoresSafeArea()

            // Confetti overlay
            if showConfetti {
                ConfettiView()
                    .allowsHitTesting(false)
            }

            // Main content
            VStack(spacing: 24) {
                Spacer()

                // Large rank icon (80pt in colored circle)
                ZStack {
                    Circle()
                        .fill(rank.color.opacity(0.15))
                        .frame(width: 120, height: 120)

                    Image(systemName: rank.icon)
                        .font(.system(size: 56, weight: .medium))
                        .foregroundStyle(rank.color)
                }
                .scaleEffect(showContent ? 1.0 : 0.5)
                .opacity(showContent ? 1.0 : 0.0)

                // "You've become a"
                Text("You've become a")
                    .font(.system(size: 17, weight: .regular))
                    .foregroundStyle(.white.opacity(0.7))
                    .opacity(showContent ? 1.0 : 0.0)

                // Rank title (large, rank color)
                Text(rank.title.uppercased())
                    .font(.system(size: 34, weight: .bold))
                    .foregroundStyle(rank.color)
                    .opacity(showContent ? 1.0 : 0.0)

                // Identity statement
                Text("\"\(rank.identityStatement)\"")
                    .font(.system(size: 17, weight: .regular))
                    .foregroundStyle(.white.opacity(0.7))
                    .opacity(showContent ? 1.0 : 0.0)

                Spacer()

                // Buttons
                HStack(spacing: 16) {
                    // Share button (secondary outline)
                    Button {
                        shareRankUp()
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "square.and.arrow.up")
                            Text("Share")
                        }
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            RoundedRectangle(cornerRadius: 14)
                                .stroke(Color.white.opacity(0.3), lineWidth: 1.5)
                        )
                    }

                    // Continue button (primary teal)
                    Button {
                        onDismiss()
                    } label: {
                        Text("Continue")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Color(hex: "00C7BE"))
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 32)
                .opacity(showContent ? 1.0 : 0.0)
            }
        }
        .onAppear {
            // Trigger haptic
            HapticService.shared.playSuccess()

            // Animate content in
            withAnimation(.easeOut(duration: 0.5).delay(0.2)) {
                showContent = true
            }

            // Show confetti
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                showConfetti = true
            }
        }
    }

    // MARK: - Share

    private func shareRankUp() {
        let text = "I just became a \(rank.title) in Just Walk! \"\(rank.identityStatement)\""
        let activityVC = UIActivityViewController(
            activityItems: [text],
            applicationActivities: nil
        )

        // Present the share sheet
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first,
           let rootVC = window.rootViewController {
            rootVC.present(activityVC, animated: true)
        }
    }
}

// MARK: - Previews

#Preview("Strider") {
    RankUpCelebrationView(rank: .strider) {
        print("Dismissed")
    }
}

#Preview("Centurion") {
    RankUpCelebrationView(rank: .centurion) {
        print("Dismissed")
    }
}

#Preview("Just Walker") {
    RankUpCelebrationView(rank: .justWalker) {
        print("Dismissed")
    }
}
