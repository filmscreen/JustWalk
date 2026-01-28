//
//  ErrorBannerView.swift
//  Just Walk
//
//  Created by Randy Chia on 1/8/26.
//

import SwiftUI

/// Reusable error banner view for displaying errors throughout the app
struct ErrorBannerView: View {
    let error: Error
    let onDismiss: () -> Void
    let onAction: (() -> Void)?

    init(error: Error, onDismiss: @escaping () -> Void, onAction: (() -> Void)? = nil) {
        self.error = error
        self.onDismiss = onDismiss
        self.onAction = onAction
    }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.white)
                .font(.title3)

            VStack(alignment: .leading, spacing: 4) {
                Text("Error")
                    .font(.subheadline.bold())
                    .foregroundStyle(.white)

                Text(error.localizedDescription)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.9))
                    .lineLimit(2)
            }

            Spacer()

            if let action = onAction {
                Button(action: action) {
                    Text("Fix")
                        .font(.caption.bold())
                        .foregroundStyle(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(.white.opacity(0.2))
                        .clipShape(Capsule())
                }
            }

            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .foregroundStyle(.white)
                    .font(.caption.bold())
                    .frame(width: 24, height: 24)
            }
        }
        .padding()
        .background(Color.red.gradient)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.1), radius: 5, y: 2)
    }
}

/// Permission error banner specifically for health/motion permissions
struct PermissionErrorBanner: View {
    let permissionType: PermissionType
    let onDismiss: () -> Void

    enum PermissionType {
        case motion
        case healthKit

        var title: String {
            switch self {
            case .motion: return "Motion Access Required"
            case .healthKit: return "Health Access Recommended"
            }
        }

        var message: String {
            switch self {
            case .motion:
                return "Just Walk needs motion access to track your steps. Enable it in Settings."
            case .healthKit:
                return "Enable Health access for unlimited step history and better insights."
            }
        }

        var icon: String {
            switch self {
            case .motion: return "figure.walk"
            case .healthKit: return "heart.fill"
            }
        }
    }

    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 12) {
                Image(systemName: permissionType.icon)
                    .foregroundStyle(.white)
                    .font(.title2)

                VStack(alignment: .leading, spacing: 4) {
                    Text(permissionType.title)
                        .font(.subheadline.bold())
                        .foregroundStyle(.white)

                    Text(permissionType.message)
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.9))
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer()

                Button {
                    openSettings()
                } label: {
                    Text("Settings")
                        .font(.caption.bold())
                        .foregroundStyle(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(.white.opacity(0.2))
                        .clipShape(Capsule())
                }

                Button(action: onDismiss) {
                    Image(systemName: "xmark")
                        .foregroundStyle(.white)
                        .font(.caption.bold())
                        .frame(width: 24, height: 24)
                }
            }

            // Helper text for HealthKit
            if permissionType == .healthKit {
                Text("Tap Health → Turn on all permissions")
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.7))
            }
        }
        .padding()
        .background(
            LinearGradient(
                colors: permissionType == .motion ? [.orange, .red] : [.blue, .cyan],
                startPoint: .leading,
                endPoint: .trailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.1), radius: 5, y: 2)
    }

    @MainActor
    private func openSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }
}

#Preview("Error Banner") {
    VStack(spacing: 16) {
        ErrorBannerView(
            error: NSError(domain: "Test", code: 1, userInfo: [NSLocalizedDescriptionKey: "Something went wrong while loading your data."]),
            onDismiss: {},
            onAction: {
                print("Action tapped")
            }
        )

        PermissionErrorBanner(
            permissionType: .motion,
            onDismiss: {}
        )

        PermissionErrorBanner(
            permissionType: .healthKit,
            onDismiss: {}
        )
    }
    .padding()
    .background(Color(.systemGroupedBackground))
}
