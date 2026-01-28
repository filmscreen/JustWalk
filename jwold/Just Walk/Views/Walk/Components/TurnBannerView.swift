//
//  TurnBannerView.swift
//  Just Walk
//
//  Top banner displaying current turn instruction with multiple states:
//  - Normal: Direction icon + distance
//  - Approaching: "Turn Now" with pulse animation
//  - Off-route: Orange warning with guidance
//

import SwiftUI
import CoreLocation

/// Banner view displaying turn-by-turn navigation instructions
struct TurnBannerView: View {
    let instruction: TurnInstruction
    let isOffRoute: Bool
    let voiceEnabled: Bool
    var onToggleVoice: () -> Void = {}

    // MARK: - State

    @State private var isPulsing = false

    // MARK: - Computed Properties

    private var distanceInFeet: Double {
        instruction.distanceMeters * 3.28084
    }

    private var state: BannerState {
        if isOffRoute {
            return .offRoute
        } else if distanceInFeet < 50 {
            return .turnNow
        } else if distanceInFeet < 150 {
            return .approaching
        } else {
            return .upcoming
        }
    }

    private var accentColor: Color {
        switch state {
        case .offRoute:
            return .orange
        case .turnNow, .approaching:
            return Color(hex: "00C7BE")  // Teal
        case .upcoming:
            return Color(hex: "00C7BE")  // Teal
        }
    }

    // MARK: - Body

    var body: some View {
        HStack(spacing: 12) {
            // Left: Turn icon
            iconView
                .frame(width: 44, height: 44)

            // Center: Instruction text
            VStack(alignment: .leading, spacing: 2) {
                if isOffRoute {
                    Text("Getting back on route...")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.primary)
                } else {
                    Text(instruction.maneuver.displayName)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.primary)

                    Text(instruction.displayDistance)
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            // Right: Voice toggle
            Button {
                HapticService.shared.playSelection()
                onToggleVoice()
            } label: {
                Image(systemName: voiceEnabled ? "speaker.wave.2.fill" : "speaker.slash.fill")
                    .font(.system(size: 18))
                    .foregroundStyle(voiceEnabled ? accentColor : .secondary)
                    .frame(width: 36, height: 36)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(backgroundView)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(borderColor, lineWidth: state == .turnNow ? 2 : 0)
        )
        .scaleEffect(state == .turnNow && isPulsing ? 1.02 : 1.0)
        .animation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true), value: isPulsing)
        .onAppear {
            if state == .turnNow {
                isPulsing = true
            }
        }
        .onChange(of: state) { _, newState in
            isPulsing = (newState == .turnNow)
        }
    }

    // MARK: - Subviews

    @ViewBuilder
    private var iconView: some View {
        ZStack {
            Circle()
                .fill(accentColor.opacity(0.15))

            if isOffRoute {
                Image(systemName: "location.fill")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(accentColor)
            } else {
                TurnIconView(
                    maneuver: instruction.maneuver,
                    size: 20,
                    color: accentColor
                )
            }
        }
    }

    @ViewBuilder
    private var backgroundView: some View {
        if isOffRoute {
            Color.orange.opacity(0.1)
                .background(.ultraThinMaterial)
        } else {
            Color.clear
                .background(.ultraThinMaterial)
        }
    }

    private var borderColor: Color {
        switch state {
        case .turnNow:
            return accentColor
        default:
            return .clear
        }
    }
}

// MARK: - Banner State

private enum BannerState {
    case upcoming      // > 150 ft
    case approaching   // 50-150 ft
    case turnNow       // < 50 ft
    case offRoute
}

// MARK: - Preview

#Preview("Normal State") {
    VStack(spacing: 16) {
        TurnBannerView(
            instruction: TurnInstruction(
                maneuver: .left,
                distanceMeters: 60,
                streetName: "Oak Street",
                coordinate: .init(latitude: 37.7749, longitude: -122.4194)
            ),
            isOffRoute: false,
            voiceEnabled: true
        )

        TurnBannerView(
            instruction: TurnInstruction(
                maneuver: .right,
                distanceMeters: 300,
                streetName: nil,
                coordinate: .init(latitude: 37.7749, longitude: -122.4194)
            ),
            isOffRoute: false,
            voiceEnabled: false
        )
    }
    .padding()
}

#Preview("Turn Now State") {
    TurnBannerView(
        instruction: TurnInstruction(
            maneuver: .left,
            distanceMeters: 10,
            streetName: "Oak Street",
            coordinate: .init(latitude: 37.7749, longitude: -122.4194)
        ),
        isOffRoute: false,
        voiceEnabled: true
    )
    .padding()
}

#Preview("Off Route State") {
    TurnBannerView(
        instruction: TurnInstruction(
            maneuver: .straight,
            distanceMeters: 100,
            streetName: nil,
            coordinate: .init(latitude: 37.7749, longitude: -122.4194)
        ),
        isOffRoute: true,
        voiceEnabled: true
    )
    .padding()
}

#Preview("All States") {
    VStack(spacing: 16) {
        Text("Upcoming (>150 ft)")
            .font(.caption)
        TurnBannerView(
            instruction: TurnInstruction(
                maneuver: .right,
                distanceMeters: 100,
                streetName: nil,
                coordinate: .init(latitude: 37.7749, longitude: -122.4194)
            ),
            isOffRoute: false,
            voiceEnabled: true
        )

        Text("Approaching (50-150 ft)")
            .font(.caption)
        TurnBannerView(
            instruction: TurnInstruction(
                maneuver: .left,
                distanceMeters: 30,
                streetName: nil,
                coordinate: .init(latitude: 37.7749, longitude: -122.4194)
            ),
            isOffRoute: false,
            voiceEnabled: true
        )

        Text("Turn Now (<50 ft)")
            .font(.caption)
        TurnBannerView(
            instruction: TurnInstruction(
                maneuver: .left,
                distanceMeters: 10,
                streetName: nil,
                coordinate: .init(latitude: 37.7749, longitude: -122.4194)
            ),
            isOffRoute: false,
            voiceEnabled: true
        )

        Text("Off Route")
            .font(.caption)
        TurnBannerView(
            instruction: TurnInstruction(
                maneuver: .straight,
                distanceMeters: 50,
                streetName: nil,
                coordinate: .init(latitude: 37.7749, longitude: -122.4194)
            ),
            isOffRoute: true,
            voiceEnabled: true
        )

        Text("Arrival")
            .font(.caption)
        TurnBannerView(
            instruction: TurnInstruction(
                maneuver: .arrival,
                distanceMeters: 100,
                streetName: nil,
                coordinate: .init(latitude: 37.7749, longitude: -122.4194)
            ),
            isOffRoute: false,
            voiceEnabled: true
        )
    }
    .padding()
}
