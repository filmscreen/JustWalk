//
//  PermissionRequiredSheet.swift
//  Just Walk
//
//  Modal for blocked permission states when starting a walk.
//  Shows which permissions are needed and provides deep links to settings.
//

import SwiftUI

struct PermissionRequiredSheet: View {
    let permission: WalkPermissionGate.BlockingPermission
    var onDismiss: () -> Void = {}
    var onOpenSettings: () -> Void = {}

    private let tealColor = Color(hex: "00C7BE")

    var body: some View {
        VStack(spacing: 24) {
            // Icon
            ZStack {
                Circle()
                    .fill(Color.orange.opacity(0.15))
                    .frame(width: 80, height: 80)
                Image(systemName: permission.icon)
                    .font(.system(size: 36))
                    .foregroundStyle(.orange)
            }
            .padding(.top, 20)

            // Title
            Text(permission.title)
                .font(.system(size: 22, weight: .bold))

            // Message
            Text(permission.message)
                .font(.system(size: 15))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            Spacer()

            // Primary action
            if permission != .deviceNotSupported {
                Button(action: onOpenSettings) {
                    Text(permission.buttonTitle)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(tealColor)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }

            // Dismiss
            Button("Not Now") {
                onDismiss()
            }
            .font(.system(size: 15))
            .foregroundStyle(.secondary)
            .padding(.bottom, 20)
        }
        .padding(.horizontal, 24)
        .presentationDetents([.medium])
    }
}

// MARK: - Location Warning Sheet

/// Sheet for graceful degradation when location is denied but walk can continue
struct LocationWarningSheet: View {
    var onEnableLocation: () -> Void = {}
    var onContinueAnyway: () -> Void = {}

    private let tealColor = Color(hex: "00C7BE")

    var body: some View {
        VStack(spacing: 20) {
            // Icon
            ZStack {
                Circle()
                    .fill(Color.orange.opacity(0.15))
                    .frame(width: 64, height: 64)
                Image(systemName: "location.slash")
                    .font(.system(size: 28))
                    .foregroundStyle(.orange)
            }

            Text("Location Access Limited")
                .font(.system(size: 20, weight: .bold))

            Text("Without location access, we can't track your route or calculate accurate distance.")
                .font(.system(size: 15))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            Spacer()

            // Enable Location button
            Button(action: onEnableLocation) {
                Text("Enable Location")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(tealColor)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }

            // Continue Anyway
            Button("Continue Anyway") {
                onContinueAnyway()
            }
            .font(.system(size: 15))
            .foregroundStyle(.secondary)
        }
        .padding(24)
    }
}

// MARK: - Previews

#Preview("HealthKit Denied") {
    PermissionRequiredSheet(permission: .healthKitDenied)
}

#Preview("Motion Denied") {
    PermissionRequiredSheet(permission: .motionDenied)
}

#Preview("Both Denied") {
    PermissionRequiredSheet(permission: .bothDenied)
}

#Preview("Device Not Supported") {
    PermissionRequiredSheet(permission: .deviceNotSupported)
}

#Preview("Location Warning") {
    LocationWarningSheet()
}
