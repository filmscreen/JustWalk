//
//  PermissionBanner.swift
//  Just Walk
//
//  Unified post-onboarding permission banner component.
//

import SwiftUI

struct PermissionBanner: View {
    let type: PermissionBannerType
    var onEnable: () -> Void = {}
    var onDismiss: () -> Void = {}

    var body: some View {
        HStack(alignment: .top, spacing: JWDesign.Spacing.md) {
            // Icon
            Image(systemName: type.icon)
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 32, height: 32)
                .background(.white.opacity(0.2))
                .clipShape(Circle())

            // Content
            VStack(alignment: .leading, spacing: JWDesign.Spacing.xs) {
                Text(type.title)
                    .font(JWDesign.Typography.headline)
                    .foregroundStyle(.white)

                Text(type.message)
                    .font(JWDesign.Typography.caption)
                    .foregroundStyle(.white.opacity(0.9))
                    .fixedSize(horizontal: false, vertical: true)

                // Action button
                Button(action: onEnable) {
                    Text(type.actionTitle)
                        .font(JWDesign.Typography.subheadline.weight(.semibold))
                        .foregroundStyle(buttonTextColor)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(.white)
                        .clipShape(Capsule())
                }
                .padding(.top, 4)
            }

            Spacer()

            // Dismiss button
            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.7))
                    .frame(width: 28, height: 28)
                    .background(.white.opacity(0.15))
                    .clipShape(Circle())
            }
        }
        .padding(JWDesign.Spacing.md)
        .background(bannerGradient)
        .clipShape(RoundedRectangle(cornerRadius: JWDesign.Radius.card))
    }

    // MARK: - Computed Properties

    private var bannerGradient: LinearGradient {
        switch type {
        case .health:
            return LinearGradient(
                colors: [Color(hex: "FF3B30"), Color(hex: "FF6B6B")],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .location:
            return LinearGradient(
                colors: [Color(hex: "007AFF"), Color(hex: "5AC8FA")],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .notifications:
            return LinearGradient(
                colors: [Color(hex: "FF9500"), Color(hex: "FFCC00")],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }

    private var buttonTextColor: Color {
        switch type {
        case .health:
            return Color(hex: "FF3B30")
        case .location:
            return Color(hex: "007AFF")
        case .notifications:
            return Color(hex: "FF9500")
        }
    }
}

#Preview("Health Banner") {
    VStack {
        PermissionBanner(
            type: .health,
            onEnable: { print("Enable tapped") },
            onDismiss: { print("Dismiss tapped") }
        )
        .padding()
    }
    .background(Color.gray.opacity(0.2))
}

#Preview("Location Banner") {
    VStack {
        PermissionBanner(
            type: .location,
            onEnable: { print("Enable tapped") },
            onDismiss: { print("Dismiss tapped") }
        )
        .padding()
    }
    .background(Color.gray.opacity(0.2))
}

#Preview("Notifications Banner") {
    VStack {
        PermissionBanner(
            type: .notifications,
            onEnable: { print("Enable tapped") },
            onDismiss: { print("Dismiss tapped") }
        )
        .padding()
    }
    .background(Color.gray.opacity(0.2))
}
