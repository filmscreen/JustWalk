//
//  WatchCountdownView.swift
//  Just Walk Watch App
//
//  3-2-1-GO countdown before starting a walk.
//

import SwiftUI
import WatchKit

struct WatchCountdownView: View {
    let walkMode: WalkMode
    let onComplete: () -> Void
    let onCancel: () -> Void

    @State private var currentNumber: Int? = nil
    @State private var showGo = false
    @State private var scale: CGFloat = 0.5
    @State private var opacity: Double = 0

    var body: some View {
        ZStack {
            // Background gradient
            backgroundGradient
                .ignoresSafeArea()

            VStack {
                Spacer()

                // Countdown display
                if let number = currentNumber {
                    Text("\(number)")
                        .font(.system(size: 80, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .scaleEffect(scale)
                        .opacity(opacity)
                } else if showGo {
                    Text("GO!")
                        .font(.system(size: 60, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .scaleEffect(scale)
                        .opacity(opacity)
                }

                Spacer()

                // Cancel button
                Button("Cancel") {
                    onCancel()
                }
                .foregroundStyle(.white.opacity(0.7))
                .padding(.bottom, 8)
            }
        }
        .onAppear {
            startCountdown()
        }
    }

    private var backgroundGradient: LinearGradient {
        switch walkMode {
        case .classic:
            return LinearGradient(
                colors: [Color.mint, Color.mint.opacity(0.8)],
                startPoint: .top,
                endPoint: .bottom
            )
        case .interval:
            return LinearGradient(
                colors: [Color(hex: "00C7BE"), Color(hex: "00C7BE").opacity(0.8)],
                startPoint: .top,
                endPoint: .bottom
            )
        }
    }

    private func startCountdown() {
        // 3
        animateNumber(3) {
            // 2
            animateNumber(2) {
                // 1
                animateNumber(1) {
                    // GO!
                    animateGo()
                }
            }
        }
    }

    private func animateNumber(_ number: Int, completion: @escaping () -> Void) {
        currentNumber = number
        showGo = false
        scale = 0.5
        opacity = 0

        // Haptic
        WKInterfaceDevice.current().play(.click)

        // Animate in
        withAnimation(.spring(response: 0.2, dampingFraction: 0.6)) {
            scale = 1.0
            opacity = 1.0
        }

        // Hold, then fade
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            withAnimation(.easeOut(duration: 0.2)) {
                opacity = 0
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                completion()
            }
        }
    }

    private func animateGo() {
        currentNumber = nil
        showGo = true
        scale = 0.5
        opacity = 0

        // Strong haptic
        WKInterfaceDevice.current().play(.success)

        withAnimation(.spring(response: 0.2, dampingFraction: 0.6)) {
            scale = 1.0
            opacity = 1.0
        }

        // Complete after brief hold
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            onComplete()
        }
    }
}

// MARK: - Preview

#Preview {
    WatchCountdownView(
        walkMode: .classic,
        onComplete: {},
        onCancel: {}
    )
}
