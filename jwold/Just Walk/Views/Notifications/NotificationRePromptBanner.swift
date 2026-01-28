//
//  NotificationRePromptBanner.swift
//  Just Walk
//
//  Subtle banner shown 30+ days after user dismissed notification prompt.
//

import SwiftUI

struct NotificationRePromptBanner: View {
    var onEnable: () -> Void
    var onDismiss: () -> Void

    var body: some View {
        HStack(spacing: JWDesign.Spacing.sm) {
            // Bell icon
            Image(systemName: "bell.badge")
                .font(.system(size: 18))
                .foregroundStyle(.orange)

            // Message
            Text("Want streak reminders?")
                .font(JWDesign.Typography.subheadline)

            Spacer()

            // Enable button
            Button {
                onEnable()
            } label: {
                Text("Enable")
                    .font(JWDesign.Typography.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(.teal)
            }

            // Dismiss button
            Button {
                onDismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
                    .padding(6)
            }
        }
        .padding(.horizontal, JWDesign.Spacing.md)
        .padding(.vertical, JWDesign.Spacing.sm)
        .background(Color.orange.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: JWDesign.Radius.card))
    }
}

// MARK: - Preview

#Preview {
    VStack {
        NotificationRePromptBanner(
            onEnable: { print("Enable tapped") },
            onDismiss: { print("Dismiss tapped") }
        )
        .padding()
    }
    .background(Color.gray.opacity(0.1))
}
