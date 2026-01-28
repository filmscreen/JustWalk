//
//  TurnIconView.swift
//  Just Walk
//
//  SF Symbol-based turn direction indicator for navigation.
//

import SwiftUI

/// Turn direction icon using SF Symbols
struct TurnIconView: View {
    let maneuver: TurnManeuver
    var size: CGFloat = 24
    var color: Color = .primary

    var body: some View {
        Image(systemName: maneuver.iconName)
            .font(.system(size: size, weight: .semibold))
            .foregroundStyle(color)
            .rotationEffect(.degrees(maneuver.iconRotation))
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 20) {
        Text("Turn Icons")
            .font(.headline)

        HStack(spacing: 24) {
            VStack {
                TurnIconView(maneuver: .straight, size: 32)
                Text("Straight").font(.caption)
            }
            VStack {
                TurnIconView(maneuver: .slightLeft, size: 32)
                Text("Slight L").font(.caption)
            }
            VStack {
                TurnIconView(maneuver: .slightRight, size: 32)
                Text("Slight R").font(.caption)
            }
        }

        HStack(spacing: 24) {
            VStack {
                TurnIconView(maneuver: .left, size: 32)
                Text("Left").font(.caption)
            }
            VStack {
                TurnIconView(maneuver: .right, size: 32)
                Text("Right").font(.caption)
            }
            VStack {
                TurnIconView(maneuver: .uTurn, size: 32)
                Text("U-Turn").font(.caption)
            }
        }

        HStack(spacing: 24) {
            VStack {
                TurnIconView(maneuver: .sharpLeft, size: 32)
                Text("Sharp L").font(.caption)
            }
            VStack {
                TurnIconView(maneuver: .sharpRight, size: 32)
                Text("Sharp R").font(.caption)
            }
            VStack {
                TurnIconView(maneuver: .arrival, size: 32)
                Text("Arrival").font(.caption)
            }
        }

        Divider()

        Text("Different Sizes")
            .font(.headline)

        HStack(spacing: 24) {
            TurnIconView(maneuver: .left, size: 16)
            TurnIconView(maneuver: .left, size: 24)
            TurnIconView(maneuver: .left, size: 32)
            TurnIconView(maneuver: .left, size: 48)
        }

        Divider()

        Text("Different Colors")
            .font(.headline)

        HStack(spacing: 24) {
            TurnIconView(maneuver: .right, size: 32, color: .teal)
            TurnIconView(maneuver: .right, size: 32, color: .orange)
            TurnIconView(maneuver: .right, size: 32, color: .white)
                .padding(8)
                .background(Color.black)
                .clipShape(Circle())
        }
    }
    .padding()
}
