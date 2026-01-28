//
//  NotificationPermissionView.swift
//  Just Walk
//
//  Pre-permission screen shown before triggering the system notification prompt.
//

import SwiftUI

struct NotificationPermissionView: View {
    var onEnable: () -> Void
    var onNotNow: () -> Void

    var body: some View {
        VStack(spacing: JWDesign.Spacing.xl) {
            Spacer()

            // Notification mockup illustration
            notificationMockup

            // Headline
            Text("Stay on Track")
                .font(.title.bold())
                .multilineTextAlignment(.center)

            // Subtext
            Text("Get a gentle reminder when your streak is at risk, or celebrate when you hit your goal.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, JWDesign.Spacing.lg)

            Spacer()

            // Primary button
            Button(action: onEnable) {
                Text("Enable Reminders")
                    .font(JWDesign.Typography.headlineBold)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, JWDesign.Spacing.md)
                    .background(Color.teal)
                    .clipShape(RoundedRectangle(cornerRadius: JWDesign.Radius.button))
            }
            .padding(.horizontal, JWDesign.Spacing.horizontalInset)

            // Secondary link
            Button("Not Now") {
                onNotNow()
            }
            .font(.footnote)
            .foregroundStyle(.secondary)
            .padding(.bottom, JWDesign.Spacing.xl)
        }
        .background(JWDesign.Colors.background)
    }

    // MARK: - Notification Mockup

    /// Visual mockup of a notification to show users what they'll receive
    private var notificationMockup: some View {
        VStack(spacing: 0) {
            // Notification card
            VStack(alignment: .leading, spacing: 8) {
                // Header row
                HStack {
                    // App icon placeholder
                    ZStack {
                        RoundedRectangle(cornerRadius: 6)
                            .fill(LinearGradient(colors: [.blue, .cyan], startPoint: .topLeading, endPoint: .bottomTrailing))
                            .frame(width: 24, height: 24)

                        Image(systemName: "figure.walk")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(.white)
                    }

                    Text("Just Walk")
                        .font(.caption.bold())

                    Spacer()

                    Text("now")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                // Notification body
                Text("You're 2,000 steps away from keeping your streak!")
                    .font(.subheadline)
                    .foregroundStyle(.primary)
            }
            .padding()
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .shadow(color: .black.opacity(0.1), radius: 10, y: 4)
        }
        .padding(.horizontal, 40)
        .padding(.bottom, JWDesign.Spacing.lg)
    }
}

// MARK: - Preview

#Preview {
    NotificationPermissionView(
        onEnable: { print("Enable tapped") },
        onNotNow: { print("Not Now tapped") }
    )
}
