//
//  WatchOnboardingReadyView.swift
//  Just Walk Watch App
//
//  Final ready screen showing step goal.
//  Completes onboarding when user taps Start Walking.
//

import SwiftUI
import WatchKit

struct WatchOnboardingReadyView: View {
    let onComplete: () -> Void

    @State private var showCheckmark = false

    var body: some View {
        VStack(spacing: 12) {
            Spacer()

            // Checkmark with animation
            ZStack {
                Circle()
                    .fill(Color.green.opacity(0.2))
                    .frame(width: 50, height: 50)

                Image(systemName: "checkmark")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(.green)
                    .scaleEffect(showCheckmark ? 1.0 : 0.5)
                    .opacity(showCheckmark ? 1.0 : 0)
            }

            // Title
            Text("You're all set!")
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(.white)

            // Goal info
            VStack(spacing: 4) {
                Text("Your step goal is")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)

                Text("\(WatchHealthManager.shared.stepGoal.formatted()) steps")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Color(hex: "00C7BE"))
            }

            Spacer()

            // Button
            Button {
                WKInterfaceDevice.current().play(.success)
                onComplete()
            } label: {
                Text("Start Walking")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color(hex: "00C7BE"))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 12)
        .padding(.bottom, 8)
        .onAppear {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.6).delay(0.2)) {
                showCheckmark = true
            }
        }
    }
}

// MARK: - Preview

#Preview {
    WatchOnboardingReadyView(onComplete: {})
}
