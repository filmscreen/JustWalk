//
//  HomeProgressRing.swift
//  Just Walk Watch App
//
//  Centered progress ring for home screen with step count inside.
//

import SwiftUI

struct HomeProgressRing: View {
    let currentSteps: Int
    let goal: Int
    let todayDistance: Double  // Distance in meters
    var onTap: () -> Void = {}

    // MARK: - Computed Properties

    private var progress: Double {
        guard goal > 0 else { return 0 }
        return Double(currentSteps) / Double(goal)
    }

    private var goalReached: Bool { currentSteps >= goal }

    // Distance formatting (in miles)
    private var formattedDistance: String {
        let miles = todayDistance * 0.000621371
        if miles >= 10 {
            return "\(Int(miles)) mi"
        } else {
            return String(format: "%.1f mi", miles)
        }
    }

    // MARK: - Styling

    private let strokeWidth: CGFloat = 8.0

    /// Brand gradient: teal → cyan → blue (always used, including goal reached)
    private var brandGradient: AngularGradient {
        AngularGradient(
            colors: [
                Color(hex: "00C7BE"),  // Teal
                .cyan,
                .blue,
                Color(hex: "00C7BE")   // Back to teal
            ],
            center: .center,
            startAngle: .degrees(-90),
            endAngle: .degrees(270)
        )
    }

    // MARK: - Body

    var body: some View {
        GeometryReader { geometry in
            let size = min(geometry.size.width, geometry.size.height)
            let ringDiameter = size - strokeWidth

            ZStack {
                // MARK: - Background Track
                Circle()
                    .stroke(
                        Color.white.opacity(0.2),
                        style: StrokeStyle(lineWidth: strokeWidth, lineCap: .round)
                    )
                    .frame(width: ringDiameter, height: ringDiameter)

                // MARK: - Progress Ring
                Circle()
                    .trim(from: 0.0, to: min(CGFloat(progress), 1.0))
                    .stroke(
                        brandGradient,
                        style: StrokeStyle(lineWidth: strokeWidth, lineCap: .round)
                    )
                    .frame(width: ringDiameter, height: ringDiameter)
                    .rotationEffect(.degrees(-90))

                // MARK: - Overflow Ring (>100%)
                if progress > 1.0 {
                    Circle()
                        .trim(from: 0.0, to: CGFloat(progress - 1.0))
                        .stroke(
                            brandGradient,
                            style: StrokeStyle(lineWidth: strokeWidth, lineCap: .round)
                        )
                        .frame(width: ringDiameter, height: ringDiameter)
                        .rotationEffect(.degrees(-90))
                }

                // MARK: - Center Content
                VStack(spacing: 2) {
                    // Trophy animation when goal reached
                    if goalReached {
                        PulsingTrophy()
                    }

                    // Primary: Total step count
                    Text(currentSteps.formatted())
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundStyle(goalReached ? (currentSteps > goal ? .mint : Color(hex: "00C7BE")) : .white)
                        .monospacedDigit()
                        .minimumScaleFactor(0.6)
                        .lineLimit(1)

                    // Secondary: Distance (always shown)
                    Text(formattedDistance)
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(.gray)
                }
                .frame(width: ringDiameter - strokeWidth * 2 - 8)
                .contentShape(Circle())
                .onTapGesture {
                    if goalReached { onTap() }
                }
            }
            .frame(width: size, height: size)
        }
    }
}

// MARK: - Pulsing Trophy Animation

struct PulsingTrophy: View {
    @State private var opacity: Double = 1.0

    var body: some View {
        Image(systemName: "trophy.fill")
            .font(.system(size: 16))
            .foregroundColor(.yellow)
            .opacity(opacity)
            .onAppear {
                withAnimation(
                    .easeInOut(duration: 1.0)
                    .repeatForever(autoreverses: true)
                ) {
                    opacity = 0.6
                }
            }
    }
}

// MARK: - Preview

#Preview("In Progress") {
    HomeProgressRing(
        currentSteps: 6500,
        goal: 10000,
        todayDistance: 4500.0
    )
    .frame(width: 100, height: 100)
}

#Preview("Goal Reached") {
    HomeProgressRing(
        currentSteps: 12500,
        goal: 10000,
        todayDistance: 9800.0
    )
    .frame(width: 100, height: 100)
}

#Preview("Early Progress") {
    HomeProgressRing(
        currentSteps: 2000,
        goal: 10000,
        todayDistance: 1500.0
    )
    .frame(width: 100, height: 100)
}
