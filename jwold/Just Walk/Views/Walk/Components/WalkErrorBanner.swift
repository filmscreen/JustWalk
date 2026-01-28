//
//  WalkErrorBanner.swift
//  Just Walk
//
//  Inline banner for during-walk errors like GPS signal loss or pedometer issues.
//

import SwiftUI

enum WalkErrorType {
    case gpsSignalLost
    case pedometerPaused
    case locationDenied

    var icon: String {
        switch self {
        case .gpsSignalLost:
            return "location.slash"
        case .pedometerPaused:
            return "figure.walk"
        case .locationDenied:
            return "location"
        }
    }

    var message: String {
        switch self {
        case .gpsSignalLost:
            return "GPS signal lost • Distance may be inaccurate"
        case .pedometerPaused:
            return "Step tracking paused • Try restarting the app"
        case .locationDenied:
            return "Location disabled • Route not recorded"
        }
    }

    var backgroundColor: Color {
        switch self {
        case .gpsSignalLost:
            return .orange
        case .pedometerPaused:
            return .red
        case .locationDenied:
            return .yellow
        }
    }

    var textColor: Color {
        switch self {
        case .gpsSignalLost, .pedometerPaused:
            return .white
        case .locationDenied:
            return .black
        }
    }
}

struct WalkErrorBanner: View {
    let errorType: WalkErrorType
    var onDismiss: (() -> Void)? = nil

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: errorType.icon)
                .font(.caption.bold())

            Text(errorType.message)
                .font(.caption)
                .lineLimit(1)

            Spacer()

            if let dismiss = onDismiss {
                Button(action: dismiss) {
                    Image(systemName: "xmark")
                        .font(.caption.bold())
                }
            }
        }
        .foregroundStyle(errorType.textColor)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(errorType.backgroundColor.gradient)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

// MARK: - Preview

#Preview("GPS Signal Lost") {
    VStack {
        WalkErrorBanner(errorType: .gpsSignalLost)
        WalkErrorBanner(errorType: .gpsSignalLost, onDismiss: {})
    }
    .padding()
}

#Preview("Pedometer Paused") {
    VStack {
        WalkErrorBanner(errorType: .pedometerPaused)
        WalkErrorBanner(errorType: .pedometerPaused, onDismiss: {})
    }
    .padding()
}

#Preview("Location Denied") {
    VStack {
        WalkErrorBanner(errorType: .locationDenied)
        WalkErrorBanner(errorType: .locationDenied, onDismiss: {})
    }
    .padding()
}
