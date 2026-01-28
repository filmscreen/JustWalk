import SwiftUI
import WidgetKit

// MARK: - Widget Colors

struct WidgetColors {
    static let background = Color(red: 28/255, green: 28/255, blue: 30/255) // #1C1C1E

    static let ringTrack = Color.white.opacity(0.15)
    static let ringProgress = Color(red: 0, green: 199/255, blue: 190/255) // #00C7BE
    static let ringGoalReached = Color(red: 255/255, green: 149/255, blue: 0) // #FF9500
    static let ringBonus = Color(red: 52/255, green: 199/255, blue: 89/255) // #34C759

    static let textPrimary = Color.white
    static let textSecondary = Color.white.opacity(0.6)
    static let textTertiary = Color.white.opacity(0.5)
    static let iconSubtle = Color.white.opacity(0.4)

    static func ringColor(for progress: Double) -> Color {
        if progress > 1.0 { return ringBonus }
        if progress >= 1.0 { return ringGoalReached }
        return ringProgress
    }

    static func textColor(for progress: Double) -> Color {
        if progress > 1.0 { return ringBonus }
        if progress >= 1.0 { return ringGoalReached }
        return textPrimary
    }

    // MARK: - Progress Bar Colors

    static let goalReachedColor = Color(red: 1.0, green: 0.85, blue: 0.2)  // Gold

    static func barColor(for progress: Double) -> LinearGradient {
        if progress >= 1.0 {
            return LinearGradient(
                colors: [Color(red: 1.0, green: 0.85, blue: 0.2), Color(red: 1.0, green: 0.6, blue: 0.1)],
                startPoint: .leading,
                endPoint: .trailing
            )
        } else {
            return LinearGradient(
                colors: [Color(red: 0.0, green: 0.7, blue: 0.65), Color(red: 0.0, green: 0.85, blue: 0.9), Color(red: 0.15, green: 0.5, blue: 0.95)],
                startPoint: .leading,
                endPoint: .trailing
            )
        }
    }
}

// MARK: - Progress Ring

struct WidgetProgressRing: View {
    let progress: Double
    let lineWidth: CGFloat
    let size: CGFloat

    var body: some View {
        ZStack {
            Circle()
                .stroke(WidgetColors.ringTrack, lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: min(progress, 1.0))
                .stroke(
                    WidgetColors.ringColor(for: progress),
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
        }
        .frame(width: size, height: size)
    }
}

// MARK: - Walking Man Icon

struct WalkingManIcon: View {
    let size: CGFloat
    let opacity: Double

    init(size: CGFloat = 16, opacity: Double = 0.4) {
        self.size = size
        self.opacity = opacity
    }

    var body: some View {
        Image(systemName: "figure.walk")
            .font(.system(size: size, weight: .medium))
            .foregroundColor(Color.white.opacity(opacity))
    }
}

// MARK: - Formatters

struct WidgetFormatters {
    static func formatSteps(_ steps: Int) -> String {
        if steps >= 100_000 {
            return String(format: "%.0fK", Double(steps) / 1000)
        }
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return formatter.string(from: NSNumber(value: steps)) ?? "\(steps)"
    }

    static func formatDistance(_ distance: Double, unit: String) -> String {
        if distance >= 100 {
            return String(format: "%.0f", distance)
        } else if distance >= 10 {
            return String(format: "%.1f", distance)
        }
        return String(format: "%.1f", distance)
    }
}
