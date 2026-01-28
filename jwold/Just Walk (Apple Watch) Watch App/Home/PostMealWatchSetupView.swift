//
//  PostMealWatchSetupView.swift
//  Just Walk Watch App
//
//  Setup screen for the Post-Meal Walk on Apple Watch.
//  Simple layout: icon, title, duration, and a Start button.
//  Consistent with iPhone PostMealSetupView design.
//

import SwiftUI
import WatchKit

struct PostMealWatchSetupView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var sessionManager = WatchSessionManager.shared

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                // Icon
                Image(systemName: "fork.knife")
                    .font(.system(size: 32))
                    .foregroundStyle(.orange)
                    .padding(.top, 8)

                // Title
                Text("Post-Meal Walk")
                    .font(.system(size: 18, weight: .bold, design: .rounded))

                // Duration badge
                VStack(spacing: 2) {
                    Text("10")
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                    Text("min")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.secondary)
                }
                .frame(width: 72, height: 72)
                .background(Color.gray.opacity(0.15))
                .clipShape(RoundedRectangle(cornerRadius: 12))

                // Reassurance
                Text("Just walk after eating")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)

                // Start button
                Button {
                    WKInterfaceDevice.current().play(.click)
                    startPostMealWalk()
                } label: {
                    Text("Start")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color.orange)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                .padding(.top, 4)
            }
            .padding(.horizontal, 8)
        }
    }

    private func startPostMealWalk() {
        dismiss()
        // Small delay to let sheet dismiss before starting session
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            sessionManager.startSession(mode: .postMeal)
        }
    }
}

// MARK: - Preview

#Preview {
    PostMealWatchSetupView()
}
