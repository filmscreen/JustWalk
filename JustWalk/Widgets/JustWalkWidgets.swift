//
//  JustWalkWidgets.swift
//  JustWalk
//
//  Home Screen and Lock Screen widgets — "Quiet the Noise" philosophy
//
//  NOTE: Add a Widget Extension target in Xcode and include this file
//  in that target. Configure an App Group (e.g. "group.com.justwalk.shared")
//  in both the main app and the widget extension for shared data access.
//

import WidgetKit
import SwiftUI

// MARK: - Widget Colors (local to extension — can't import JW tokens)

private enum WidgetColors {
    static let accent = Color(red: 0x34/255, green: 0xD3/255, blue: 0x99/255)       // Green
    static let success = Color(red: 0x4D/255, green: 0xD9/255, blue: 0x66/255)      // Green
    static let streak = Color(red: 0xFF/255, green: 0x73/255, blue: 0x1A/255)       // Orange
    static let shield = Color(red: 0x22/255, green: 0xD3/255, blue: 0xEE/255)       // Cyan
    static let bgCard = Color(red: 0x1C/255, green: 0x1C/255, blue: 0x2E/255)

    // Ring gradient palette (emerald → brand green → bright mint)
    static let ringStart = Color(red: 0x20/255, green: 0xA0/255, blue: 0x80/255)
    static let ringEnd   = Color(red: 0x86/255, green: 0xEF/255, blue: 0xAC/255)

    static let ringGradient = AngularGradient(
        stops: [
            .init(color: ringStart, location: 0.0),
            .init(color: accent,    location: 0.35),
            .init(color: ringEnd,   location: 0.7),
            .init(color: ringStart, location: 1.0)
        ],
        center: .center,
        startAngle: .degrees(0),
        endAngle: .degrees(360)
    )
}

// MARK: - Shared Data

struct JustWalkWidgetData {
    static let appGroupID = "group.com.justwalk.shared"

    static var sharedDefaults: UserDefaults {
        UserDefaults(suiteName: appGroupID) ?? .standard
    }

    static func todaySteps() -> Int {
        sharedDefaults.integer(forKey: "widget_todaySteps")
    }

    static func stepGoal() -> Int {
        let goal = sharedDefaults.integer(forKey: "widget_stepGoal")
        return goal > 0 ? goal : 5000
    }

    static func currentStreak() -> Int {
        sharedDefaults.integer(forKey: "widget_currentStreak")
    }

    static func weekSteps() -> [Int] {
        sharedDefaults.array(forKey: "widget_weekSteps") as? [Int] ?? Array(repeating: 0, count: 7)
    }

    static func shieldCount() -> Int {
        sharedDefaults.integer(forKey: "widget_shieldCount")
    }

    /// Call from main app to push data for widgets
    static func updateWidgetData(
        todaySteps: Int,
        stepGoal: Int,
        currentStreak: Int,
        weekSteps: [Int],
        shieldCount: Int = 0
    ) {
        sharedDefaults.set(todaySteps, forKey: "widget_todaySteps")
        sharedDefaults.set(stepGoal, forKey: "widget_stepGoal")
        sharedDefaults.set(currentStreak, forKey: "widget_currentStreak")
        sharedDefaults.set(weekSteps, forKey: "widget_weekSteps")
        sharedDefaults.set(shieldCount, forKey: "widget_shieldCount")
        WidgetCenter.shared.reloadAllTimelines()
    }
}

// MARK: - Timeline Entry

struct JustWalkEntry: TimelineEntry {
    let date: Date
    let todaySteps: Int
    let stepGoal: Int
    let currentStreak: Int
    let weekSteps: [Int]
    let shieldCount: Int

    var stepProgress: Double {
        guard stepGoal > 0 else { return 0 }
        return min(Double(todaySteps) / Double(stepGoal), 1.0)
    }

    var stepsRemaining: Int {
        max(stepGoal - todaySteps, 0)
    }

    var goalComplete: Bool {
        todaySteps >= stepGoal
    }

    static let placeholder = JustWalkEntry(
        date: Date(),
        todaySteps: 4200,
        stepGoal: 5000,
        currentStreak: 12,
        weekSteps: [3200, 5100, 4800, 6200, 5000, 3800, 4200],
        shieldCount: 2
    )
}

// MARK: - Timeline Provider

struct JustWalkTimelineProvider: TimelineProvider {
    func placeholder(in context: Context) -> JustWalkEntry {
        .placeholder
    }

    func getSnapshot(in context: Context, completion: @escaping (JustWalkEntry) -> Void) {
        if context.isPreview {
            completion(.placeholder)
        } else {
            completion(currentEntry())
        }
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<JustWalkEntry>) -> Void) {
        let entry = currentEntry()

        // Refresh every 15 minutes
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 15, to: Date()) ?? Date()
        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
        completion(timeline)
    }

    private func currentEntry() -> JustWalkEntry {
        JustWalkEntry(
            date: Date(),
            todaySteps: JustWalkWidgetData.todaySteps(),
            stepGoal: JustWalkWidgetData.stepGoal(),
            currentStreak: JustWalkWidgetData.currentStreak(),
            weekSteps: JustWalkWidgetData.weekSteps(),
            shieldCount: JustWalkWidgetData.shieldCount()
        )
    }
}

// ============================================================================
// MARK: - Widget 1: "Today" (Small)
// ============================================================================

struct TodayWidget: Widget {
    let kind = "StepsRingWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: JustWalkTimelineProvider()) { entry in
            TodayWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Today")
        .description("Today's step progress toward your goal.")
        .supportedFamilies([.systemSmall])
    }
}

struct TodayWidgetView: View {
    let entry: JustWalkEntry

    var body: some View {
        ZStack {
            Circle()
                .stroke(WidgetColors.ringStart.opacity(0.15), lineWidth: 8)
                .padding(16)

            Circle()
                .trim(from: 0, to: entry.stepProgress)
                .stroke(
                    entry.goalComplete
                        ? AnyShapeStyle(WidgetColors.success)
                        : AnyShapeStyle(WidgetColors.ringGradient),
                    style: StrokeStyle(lineWidth: 8, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .padding(16)

            VStack(spacing: 4) {
                Image(systemName: "figure.walk")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(WidgetColors.accent)

                Text(entry.todaySteps.formatted())
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .monospacedDigit()
            }
        }
    }
}

// ============================================================================
// MARK: - Widget 2: "Streak" (Small)
// ============================================================================

struct StreakWidget: Widget {
    let kind = "StreakFlameWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: JustWalkTimelineProvider()) { entry in
            StreakWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Streak")
        .description("Your current walking streak.")
        .supportedFamilies([.systemSmall])
    }
}

struct StreakWidgetView: View {
    let entry: JustWalkEntry

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: "flame.fill")
                .font(.system(size: 36))
                .foregroundStyle(flameGradient)

            Text("\(entry.currentStreak)")
                .font(.system(size: 40, weight: .bold, design: .rounded))
                .monospacedDigit()
                .minimumScaleFactor(0.6)
                .lineLimit(1)

            Text(entry.currentStreak == 1 ? "day" : "days")
                .font(.system(size: 14))
                .foregroundStyle(.secondary)
        }
        .padding(16)
    }

    private var flameGradient: some ShapeStyle {
        if entry.currentStreak >= 30 {
            return AnyShapeStyle(.linearGradient(
                colors: [.red, WidgetColors.streak, .yellow],
                startPoint: .bottom,
                endPoint: .top
            ))
        } else if entry.currentStreak >= 7 {
            return AnyShapeStyle(WidgetColors.streak)
        } else {
            return AnyShapeStyle(.gray)
        }
    }
}

// ============================================================================
// MARK: - Widget 3: "Today + Streak" (Medium — Fixed)
// ============================================================================

struct TodayStreakWidget: Widget {
    let kind = "TodayStreakWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: JustWalkTimelineProvider()) { entry in
            TodayStreakWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Today + Streak")
        .description("Steps, streak, and goal status at a glance.")
        .supportedFamilies([.systemMedium])
    }
}

struct TodayStreakWidgetView: View {
    let entry: JustWalkEntry

    var body: some View {
        HStack(spacing: 20) {
            // Ring
            ZStack {
                Circle()
                    .stroke(WidgetColors.ringStart.opacity(0.15), lineWidth: 8)

                Circle()
                    .trim(from: 0, to: entry.stepProgress)
                    .stroke(
                        entry.goalComplete
                            ? AnyShapeStyle(WidgetColors.success)
                            : AnyShapeStyle(WidgetColors.ringGradient),
                        style: StrokeStyle(lineWidth: 8, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))

                Text(entry.todaySteps.formatted())
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
            }
            .frame(width: 90, height: 90)

            VStack(alignment: .leading, spacing: 8) {
                // Streak
                HStack(spacing: 4) {
                    Image(systemName: "flame.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(WidgetColors.streak)

                    Text("\(entry.currentStreak)")
                        .font(.system(.title3, design: .rounded).bold().monospacedDigit())

                    Text(entry.currentStreak == 1 ? "day" : "days")
                        .font(.system(size: 14))
                        .foregroundStyle(.secondary)
                }

                // Dynamic goal status
                Text(dynamicStatusText)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(dynamicStatusColor)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .frame(maxWidth: .infinity)
    }

    private var dynamicStatusText: String {
        if entry.goalComplete {
            return "Goal hit"
        } else if entry.todaySteps == 0 {
            return "Keep moving"
        } else if entry.stepsRemaining == 1 {
            return "1 step to go"
        } else {
            return "\(entry.stepsRemaining.formatted()) steps to go"
        }
    }

    private var dynamicStatusColor: Color {
        if entry.goalComplete {
            return WidgetColors.success
        } else {
            return .secondary
        }
    }
}

// ============================================================================
// MARK: - Widget 4: "This Week" (Medium)
// ============================================================================

struct ThisWeekWidget: Widget {
    let kind = "TrendsWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: JustWalkTimelineProvider()) { entry in
            ThisWeekWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("This Week")
        .description("Your step activity over the past week.")
        .supportedFamilies([.systemMedium])
    }
}

struct ThisWeekWidgetView: View {
    let entry: JustWalkEntry

    private let dayLabels = ["M", "T", "W", "T", "F", "S", "S"]

    private var maxSteps: Int {
        max(entry.weekSteps.max() ?? 1, entry.stepGoal, 1)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Spacer()
                Text("\(weekTotal.formatted()) steps")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            HStack(alignment: .bottom, spacing: 6) {
                ForEach(Array(entry.weekSteps.suffix(7).enumerated()), id: \.offset) { index, steps in
                    VStack(spacing: 4) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(steps >= entry.stepGoal ? WidgetColors.success : WidgetColors.accent.opacity(0.4))
                            .frame(height: barHeight(for: steps))

                        Text(dayLabels[index % dayLabels.count])
                            .font(.system(size: 9))
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .frame(maxHeight: 80)

            // Goal line label
            HStack {
                Rectangle()
                    .fill(Color.secondary.opacity(0.3))
                    .frame(height: 1)
                Text("\(entry.stepGoal.formatted()) goal")
                    .font(.system(size: 8))
                    .foregroundStyle(.secondary)
                    .fixedSize()
            }
        }
        .padding(.horizontal, 4)
    }

    private var weekTotal: Int {
        entry.weekSteps.suffix(7).reduce(0, +)
    }

    private func barHeight(for steps: Int) -> CGFloat {
        let ratio = CGFloat(steps) / CGFloat(maxSteps)
        return max(ratio * 70, 4)
    }
}

// ============================================================================
// MARK: - Widget 5: "Shields" (Medium)
// ============================================================================

struct ShieldsWidget: Widget {
    let kind = "ShieldsWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: JustWalkTimelineProvider()) { entry in
            ShieldsWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Shields")
        .description("Your streak protection status.")
        .supportedFamilies([.systemMedium])
    }
}

struct ShieldsWidgetView: View {
    let entry: JustWalkEntry

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: entry.shieldCount > 0 ? "shield.fill" : "shield")
                .font(.system(size: 36))
                .foregroundStyle(entry.shieldCount > 0 ? WidgetColors.shield : .gray)

            VStack(spacing: 2) {
                Text(shieldCountText)
                    .font(.system(.title2, design: .rounded).bold().monospacedDigit())

                Text("available")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var shieldCountText: String {
        if entry.shieldCount == 0 {
            return "No shields"
        } else {
            return "\(entry.shieldCount) \(entry.shieldCount == 1 ? "shield" : "shields")"
        }
    }
}

// ============================================================================
// MARK: - Lock Screen Widgets (Kept)
// ============================================================================

// Steps Gauge (Lock Screen Circular)

struct StepsGaugeWidget: Widget {
    let kind = "StepsGaugeWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: JustWalkTimelineProvider()) { entry in
            StepsGaugeWidgetView(entry: entry)
        }
        .configurationDisplayName("Steps Gauge")
        .description("Step progress at a glance.")
        .supportedFamilies([.accessoryCircular])
    }
}

struct StepsGaugeWidgetView: View {
    let entry: JustWalkEntry

    var body: some View {
        Gauge(value: entry.stepProgress) {
            Image(systemName: "figure.walk")
        } currentValueLabel: {
            Text(abbreviatedSteps)
                .font(.system(.body, design: .rounded).bold())
        }
        .gaugeStyle(.accessoryCircular)
    }

    private var abbreviatedSteps: String {
        if entry.todaySteps >= 1000 {
            return String(format: "%.1fk", Double(entry.todaySteps) / 1000.0)
        }
        return "\(entry.todaySteps)"
    }
}

// Streak Count (Lock Screen Inline)

struct StreakCountWidget: Widget {
    let kind = "StreakCountWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: JustWalkTimelineProvider()) { entry in
            StreakCountWidgetView(entry: entry)
        }
        .configurationDisplayName("Streak Count")
        .description("Your current streak on the lock screen.")
        .supportedFamilies([.accessoryInline])
    }
}

struct StreakCountWidgetView: View {
    let entry: JustWalkEntry

    var body: some View {
        if entry.currentStreak > 0 {
            Label("\(entry.currentStreak)-day streak", systemImage: "flame.fill")
        } else {
            Label("Start your streak!", systemImage: "flame")
        }
    }
}

// ============================================================================
// MARK: - Widget Bundle
// ============================================================================

@main
struct JustWalkWidgetBundle: WidgetBundle {
    var body: some Widget {
        // Small widgets
        TodayWidget()
        StreakWidget()

        // Medium widgets
        TodayStreakWidget()
        ThisWeekWidget()
        ShieldsWidget()

        // Lock screen widgets
        StepsGaugeWidget()
        StreakCountWidget()
    }
}
