//
//  ChallengeCompleteToast.swift
//  Just Walk
//
//  Toast overlay that displays when a challenge is completed,
//  with slide-down animation, teal confetti burst, and optional "Perfect Score!" badge.
//

import SwiftUI

struct ChallengeCompleteToast: View {
    let isPerfect: Bool
    var onDismiss: () -> Void = {}

    @State private var isVisible = false
    @State private var showConfetti = false

    var body: some View {
        VStack {
            if isVisible {
                toastContent
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
            Spacer()
        }
        .onAppear {
            HapticService.shared.playSuccess()
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                isVisible = true
            }
            showConfetti = true

            // Auto-dismiss after 3 seconds
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                dismiss()
            }
        }
        .onTapGesture {
            dismiss()
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityMessage)
        .accessibilityAddTraits(.isButton)
        .accessibilityHint("Tap to dismiss")
    }

    private var toastContent: some View {
        VStack(spacing: 4) {
            HStack(spacing: 8) {
                Text("🎉")
                    .accessibilityHidden(true)
                Text("Challenge Complete!")
                    .font(.system(size: 16, weight: .semibold))
            }

            if isPerfect {
                HStack(spacing: 4) {
                    Text("🏆")
                        .accessibilityHidden(true)
                    Text("Perfect Score!")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(Color(hex: "00C7BE"))
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .background(.ultraThinMaterial)
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.15), radius: 10, y: 4)
        .padding(.top, 8)
        .overlay {
            if showConfetti {
                TealConfettiBurst()
            }
        }
    }

    private func dismiss() {
        withAnimation(.easeOut(duration: 0.25)) {
            isVisible = false
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            onDismiss()
        }
    }

    private var accessibilityMessage: String {
        var message = "Challenge Complete!"
        if isPerfect {
            message += " Perfect Score!"
        }
        return message
    }
}

// MARK: - Preview

#Preview("Standard") {
    ZStack {
        Color.black.opacity(0.3)
        ChallengeCompleteToast(isPerfect: false)
    }
}

#Preview("Perfect Score") {
    ZStack {
        Color.black.opacity(0.3)
        ChallengeCompleteToast(isPerfect: true)
    }
}
