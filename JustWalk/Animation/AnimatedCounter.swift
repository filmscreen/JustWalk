//
//  AnimatedCounter.swift
//  JustWalk
//
//  Animated numeric counter with smooth transitions
//

import SwiftUI

struct AnimatedCounter: View {
    let value: Int
    let font: Font
    let color: Color
    let format: NumberFormat

    enum NumberFormat {
        case plain
        case comma
        case abbreviated

        func format(_ value: Int) -> String {
            switch self {
            case .plain:
                return "\(value)"
            case .comma:
                let formatter = NumberFormatter()
                formatter.numberStyle = .decimal
                return formatter.string(from: NSNumber(value: value)) ?? "\(value)"
            case .abbreviated:
                if value >= 1_000_000 {
                    return String(format: "%.1fM", Double(value) / 1_000_000)
                } else if value >= 1_000 {
                    return String(format: "%.1fK", Double(value) / 1_000)
                }
                return "\(value)"
            }
        }
    }

    init(
        value: Int,
        font: Font = .title,
        color: Color = .primary,
        format: NumberFormat = .comma
    ) {
        self.value = value
        self.font = font
        self.color = color
        self.format = format
    }

    var body: some View {
        Text(format.format(value))
            .font(font)
            .foregroundStyle(color)
            .contentTransition(.numericText(value: Double(value)))
            .animation(JustWalkAnimation.morph, value: value)
    }
}

// MARK: - Step Counter

struct StepCounter: View {
    let steps: Int
    let goal: Int?
    let font: Font

    init(steps: Int, goal: Int? = nil, font: Font = .largeTitle) {
        self.steps = steps
        self.goal = goal
        self.font = font
    }

    var body: some View {
        HStack(alignment: .lastTextBaseline, spacing: 4) {
            AnimatedCounter(value: steps, font: font.bold(), format: .comma)

            if let goal = goal {
                Text("/")
                    .font(font)
                    .foregroundStyle(.secondary)

                Text(AnimatedCounter.NumberFormat.comma.format(goal))
                    .font(font)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

// MARK: - Timer Counter

struct TimerCounter: View {
    let seconds: Int
    let font: Font
    let color: Color

    init(seconds: Int, font: Font = .title2, color: Color = .primary) {
        self.seconds = seconds
        self.font = font
        self.color = color
    }

    var body: some View {
        Text(formattedTime)
            .font(font.monospacedDigit())
            .foregroundStyle(color)
            .contentTransition(.numericText())
            .animation(JustWalkAnimation.morph, value: seconds)
    }

    private var formattedTime: String {
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60
        let secs = seconds % 60

        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, secs)
        } else {
            return String(format: "%d:%02d", minutes, secs)
        }
    }
}

// MARK: - Distance Counter

struct DistanceCounter: View {
    let meters: Double
    let font: Font
    let useMetric: Bool

    init(meters: Double, font: Font = .title2, useMetric: Bool = true) {
        self.meters = meters
        self.font = font
        self.useMetric = useMetric
    }

    var body: some View {
        HStack(alignment: .lastTextBaseline, spacing: 4) {
            Text(formattedValue)
                .font(font.bold().monospacedDigit())
                .contentTransition(.numericText())
                .animation(JustWalkAnimation.morph, value: meters)

            Text(unit)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var formattedValue: String {
        if useMetric {
            if meters >= 1000 {
                return String(format: "%.2f", meters / 1000)
            }
            return String(format: "%.0f", meters)
        } else {
            let miles = meters / 1609.344
            return String(format: "%.2f", miles)
        }
    }

    private var unit: String {
        if useMetric {
            return meters >= 1000 ? "km" : "m"
        } else {
            return "mi"
        }
    }
}

// MARK: - Percentage Counter

struct PercentageCounter: View {
    let value: Double // 0.0 to 1.0
    let font: Font
    let color: Color

    init(value: Double, font: Font = .title2, color: Color = .primary) {
        self.value = value
        self.font = font
        self.color = color
    }

    var body: some View {
        HStack(spacing: 0) {
            Text("\(Int(value * 100))")
                .font(font.monospacedDigit())
                .foregroundStyle(color)
                .contentTransition(.numericText(value: value))
                .animation(JustWalkAnimation.morph, value: value)

            Text("%")
                .font(font)
                .foregroundStyle(color.opacity(0.8))
        }
    }
}

// MARK: - Countdown Counter

struct CountdownCounter: View {
    let seconds: Int
    let font: Font
    let urgentThreshold: Int

    init(seconds: Int, font: Font = .largeTitle, urgentThreshold: Int = 10) {
        self.seconds = seconds
        self.font = font
        self.urgentThreshold = urgentThreshold
    }

    var body: some View {
        Text("\(seconds)")
            .font(font.bold().monospacedDigit())
            .foregroundStyle(seconds <= urgentThreshold ? .red : .primary)
            .contentTransition(.numericText(countsDown: true))
            .animation(JustWalkAnimation.morph, value: seconds)
    }
}

#Preview {
    VStack(spacing: 20) {
        AnimatedCounter(value: 8547, font: .largeTitle)
        StepCounter(steps: 8547, goal: 10000)
        TimerCounter(seconds: 3723)
        DistanceCounter(meters: 5432)
        PercentageCounter(value: 0.85)
        CountdownCounter(seconds: 5)
    }
    .padding()
}
