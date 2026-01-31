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

    // Dark indigo backgrounds (matches app theme)
    static let backgroundPrimary = Color(red: 0x12/255, green: 0x12/255, blue: 0x20/255)

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

    /// Relevance score tells WidgetKit how important this entry is.
    /// Higher scores increase chances of widget being shown in Smart Stack.
    let relevance: TimelineEntryRelevance?

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
        shieldCount: 2,
        relevance: nil
    )
}

// MARK: - Timeline Provider

struct JustWalkTimelineProvider: TimelineProvider {
    /// Refresh interval in minutes - 2 minutes is the most aggressive viable option.
    /// Apple allows this for health/fitness apps where timely data matters.
    private static let refreshIntervalMinutes = 2
    /// Number of entries to batch - 30 entries = 1 hour of coverage at 2-min intervals.
    /// Batching doesn't count against the daily budget - only reloadAllTimelines() calls do.
    private static let batchedEntryCount = 30

    func placeholder(in context: Context) -> JustWalkEntry {
        .placeholder
    }

    func getSnapshot(in context: Context, completion: @escaping (JustWalkEntry) -> Void) {
        if context.isPreview {
            completion(.placeholder)
        } else {
            completion(currentEntry(for: Date(), index: 0))
        }
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<JustWalkEntry>) -> Void) {
        // Generate batched entries for the next hour at 2-minute intervals.
        // This maximizes refresh frequency without using the daily reload budget.
        // Timeline entries don't count against budget - only reloadAllTimelines() calls do.
        var entries: [JustWalkEntry] = []
        let now = Date()
        let calendar = Calendar.current

        for i in 0..<Self.batchedEntryCount {
            guard let entryDate = calendar.date(byAdding: .minute, value: i * Self.refreshIntervalMinutes, to: now) else {
                continue
            }
            entries.append(currentEntry(for: entryDate, index: i))
        }

        // Use .atEnd so WidgetKit requests new timeline only after all entries are used.
        // This is more budget-efficient than .after(date) for batched entries.
        let timeline = Timeline(entries: entries, policy: .atEnd)
        completion(timeline)
    }

    private func currentEntry(for date: Date, index: Int) -> JustWalkEntry {
        let steps = JustWalkWidgetData.todaySteps()
        let goal = JustWalkWidgetData.stepGoal()
        let streak = JustWalkWidgetData.currentStreak()

        // Calculate relevance score for Smart Stack prioritization
        let relevance = calculateRelevance(steps: steps, goal: goal, streak: streak, entryIndex: index)

        return JustWalkEntry(
            date: date,
            todaySteps: steps,
            stepGoal: goal,
            currentStreak: streak,
            weekSteps: JustWalkWidgetData.weekSteps(),
            shieldCount: JustWalkWidgetData.shieldCount(),
            relevance: relevance
        )
    }

    /// Calculate relevance score for Smart Stack prioritization.
    /// Higher scores make the widget more likely to appear at the top of Smart Stack.
    private func calculateRelevance(steps: Int, goal: Int, streak: Int, entryIndex: Int) -> TimelineEntryRelevance {
        var score: Float = 0.0

        // Base score: entries closer to now are more relevant
        // First entry (index 0) gets highest base score, decreasing over time
        let timeDecay = max(0, 1.0 - Float(entryIndex) * 0.03)
        score += timeDecay * 0.3

        // Progress boost: higher relevance when close to goal (80-99%)
        let progress = goal > 0 ? Float(steps) / Float(goal) : 0
        if progress >= 0.8 && progress < 1.0 {
            score += 0.4 // Close to goal - very relevant!
        } else if progress >= 1.0 {
            score += 0.3 // Goal achieved - still relevant
        } else if progress >= 0.5 {
            score += 0.2 // Good progress
        }

        // Streak boost: active streaks are more engaging
        if streak >= 7 {
            score += 0.2 // Week+ streak
        } else if streak >= 3 {
            score += 0.1 // Building streak
        }

        // Time-of-day boost: higher relevance during typical activity hours
        let hour = Calendar.current.component(.hour, from: Date())
        if (7...9).contains(hour) || (17...20).contains(hour) {
            score += 0.1 // Morning or evening - common activity times
        }

        // Clamp to valid range [0, 1]
        score = min(max(score, 0), 1)

        // Duration: how long this entry remains highly relevant (in seconds)
        let duration: TimeInterval = TimeInterval(Self.refreshIntervalMinutes * 60)

        return TimelineEntryRelevance(score: score, duration: duration)
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
                .environment(\.colorScheme, .dark)
                .containerBackground(WidgetColors.backgroundPrimary, for: .widget)
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
                .stroke(WidgetColors.ringStart.opacity(0.15), lineWidth: 10)
                .padding(10)

            Circle()
                .trim(from: 0, to: entry.stepProgress)
                .stroke(
                    entry.goalComplete
                        ? AnyShapeStyle(WidgetColors.success)
                        : AnyShapeStyle(WidgetColors.ringGradient),
                    style: StrokeStyle(lineWidth: 10, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .padding(10)

            VStack(spacing: 4) {
                Image(systemName: "figure.walk")
                    .font(.system(size: 24, weight: .medium))
                    .foregroundStyle(WidgetColors.accent)

                Text(entry.todaySteps.formatted())
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
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
                .environment(\.colorScheme, .dark)
                .containerBackground(WidgetColors.backgroundPrimary, for: .widget)
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
                .font(.system(size: 40))
                .foregroundStyle(flameGradient)

            Text("\(entry.currentStreak)")
                .font(.system(size: 44, weight: .bold, design: .rounded))
                .monospacedDigit()
                .minimumScaleFactor(0.6)
                .lineLimit(1)

            Text(entry.currentStreak == 1 ? "day" : "days")
                .font(.system(size: 15))
                .foregroundStyle(.secondary)
        }
        .padding(12)
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
                .environment(\.colorScheme, .dark)
                .containerBackground(WidgetColors.backgroundPrimary, for: .widget)
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
                    .stroke(WidgetColors.ringStart.opacity(0.15), lineWidth: 9)

                Circle()
                    .trim(from: 0, to: entry.stepProgress)
                    .stroke(
                        entry.goalComplete
                            ? AnyShapeStyle(WidgetColors.success)
                            : AnyShapeStyle(WidgetColors.ringGradient),
                        style: StrokeStyle(lineWidth: 9, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))

                VStack(spacing: 2) {
                    Image(systemName: "figure.walk")
                        .font(.system(size: 24, weight: .medium))
                        .foregroundStyle(WidgetColors.accent)

                    Text(entry.todaySteps.formatted())
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .minimumScaleFactor(0.6)
                        .lineLimit(1)
                }
                .padding(.top, 2)
            }
            .frame(width: 104, height: 104)

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

                // Shields status
                HStack(spacing: 4) {
                    Image(systemName: entry.shieldCount > 0 ? "shield.fill" : "shield")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(WidgetColors.shield)

                    if entry.shieldCount == 0 {
                        Text("No shields")
                            .font(.system(size: 14))
                            .foregroundStyle(.secondary)
                    } else {
                        Text("\(entry.shieldCount)")
                            .font(.system(.title3, design: .rounded).bold().monospacedDigit())

                        Text(entry.shieldCount == 1 ? "shield" : "shields")
                            .font(.system(size: 14))
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .frame(maxWidth: .infinity)
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
                .environment(\.colorScheme, .dark)
                .containerBackground(WidgetColors.backgroundPrimary, for: .widget)
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
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .frame(maxHeight: 86)

            // Goal line label
            HStack {
                Rectangle()
                    .fill(Color.secondary.opacity(0.3))
                    .frame(height: 1)
                Text("\(entry.stepGoal.formatted()) goal")
                    .font(.system(size: 9))
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
                .environment(\.colorScheme, .dark)
                .containerBackground(WidgetColors.backgroundPrimary, for: .widget)
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
                .font(.system(size: 40))
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
// MARK: - Lock Screen Widgets
// ============================================================================

// MARK: Steps Formatting Helper

private func formatSteps(_ steps: Int, compact: Bool = false) -> String {
    if compact && steps >= 100000 {
        return "\(steps / 1000)k"
    } else if compact && steps >= 10000 {
        return String(format: "%.1fk", Double(steps) / 1000)
    } else {
        return steps.formatted()
    }
}

// MARK: - 1. Steps Circular (accessoryCircular)

struct StepsGaugeWidget: Widget {
    let kind = "StepsGaugeWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: JustWalkTimelineProvider()) { entry in
            StepsGaugeWidgetView(entry: entry)
        }
        .configurationDisplayName("Steps")
        .description("Today's step progress with ring.")
        .supportedFamilies([.accessoryCircular])
    }
}

struct StepsGaugeWidgetView: View {
    let entry: JustWalkEntry

    var body: some View {
        Gauge(value: entry.stepProgress) {
            Image(systemName: "figure.walk")
                .font(.caption2)
        } currentValueLabel: {
            Text(formattedSteps)
                .font(.system(.body, design: .rounded).bold())
                .minimumScaleFactor(0.6)
        }
        .gaugeStyle(.accessoryCircularCapacity)
    }

    private var formattedSteps: String {
        // Show full number under 10k, abbreviated above
        formatSteps(entry.todaySteps, compact: entry.todaySteps >= 10000)
    }
}

// MARK: - 2. Steps Inline (accessoryInline)

struct StepsInlineWidget: Widget {
    let kind = "StepsInlineWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: JustWalkTimelineProvider()) { entry in
            StepsInlineWidgetView(entry: entry)
        }
        .configurationDisplayName("Steps Inline")
        .description("Today's steps in a single line.")
        .supportedFamilies([.accessoryInline])
    }
}

struct StepsInlineWidgetView: View {
    let entry: JustWalkEntry

    var body: some View {
        Label("\(entry.todaySteps.formatted()) steps", systemImage: "figure.walk")
    }
}

// MARK: - 3. Steps Rectangular (accessoryRectangular)

struct StepsRectangularWidget: Widget {
    let kind = "StepsRectangularWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: JustWalkTimelineProvider()) { entry in
            StepsRectangularWidgetView(entry: entry)
        }
        .configurationDisplayName("Steps Detail")
        .description("Steps with goal progress.")
        .supportedFamilies([.accessoryRectangular])
    }
}

struct StepsRectangularWidgetView: View {
    let entry: JustWalkEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 4) {
                Image(systemName: "figure.walk")
                    .font(.headline)
                Text("\(entry.todaySteps.formatted()) steps")
                    .font(.headline)
            }

            if entry.goalComplete {
                Text("Goal complete")
                    .font(.caption)
                    .foregroundStyle(WidgetColors.success)
            } else {
                Text("\(entry.stepsRemaining.formatted()) to goal")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            ProgressView(value: entry.stepProgress)
                .tint(entry.goalComplete ? WidgetColors.success : WidgetColors.accent)
        }
    }
}

// MARK: - 4. Streak Circular (accessoryCircular)

struct StreakCircularWidget: Widget {
    let kind = "StreakCircularWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: JustWalkTimelineProvider()) { entry in
            StreakCircularWidgetView(entry: entry)
        }
        .configurationDisplayName("Streak")
        .description("Your walking streak.")
        .supportedFamilies([.accessoryCircular])
    }
}

struct StreakCircularWidgetView: View {
    let entry: JustWalkEntry

    var body: some View {
        VStack(spacing: 0) {
            Image(systemName: "flame.fill")
                .font(.title3)
                .foregroundStyle(flameColor)

            Text("\(entry.currentStreak)")
                .font(.system(.title2, design: .rounded).bold())
                .minimumScaleFactor(0.6)

            Text("days")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }

    private var flameColor: Color {
        if entry.currentStreak >= 30 {
            return .red
        } else if entry.currentStreak >= 7 {
            return WidgetColors.streak
        } else {
            return .gray
        }
    }
}

// MARK: - 5. Streak Inline (accessoryInline)

struct StreakCountWidget: Widget {
    let kind = "StreakCountWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: JustWalkTimelineProvider()) { entry in
            StreakCountWidgetView(entry: entry)
        }
        .configurationDisplayName("Streak Inline")
        .description("Your streak in a single line.")
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
// MARK: - Live Activity Widget
// ============================================================================

struct WalkLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: WalkActivityAttributes.self) { context in
            // Lock Screen / Banner view
            WalkLockScreenView(context: context)
                .environment(\.colorScheme, .dark)
                .background(WidgetColors.backgroundPrimary)
        } dynamicIsland: { context in
            DynamicIsland {
                // Expanded view
                DynamicIslandExpandedRegion(.leading) {
                    HStack(spacing: 4) {
                        Image(systemName: "figure.walk")
                            .foregroundStyle(WidgetColors.accent)
                        Text("\(context.state.steps)")
                            .font(.title2.bold().monospacedDigit())
                    }
                }
                DynamicIslandExpandedRegion(.trailing) {
                    intervalAwareTimer(context)
                        .font(.title2.monospacedDigit())
                }
                DynamicIslandExpandedRegion(.bottom) {
                    HStack {
                        Text(formatDistance(context.state.distance))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)

                        Spacer()

                        if context.state.isPaused {
                            Label("Paused", systemImage: "pause.fill")
                                .font(.subheadline)
                                .foregroundStyle(.orange)
                        } else if context.attributes.mode == "interval",
                                  let label = context.state.intervalPhaseType {
                            Text(label)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.secondary)
                        } else {
                            Text(walkModeLabel(context.attributes.mode))
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            } compactLeading: {
                Image(systemName: context.state.isPaused ? "pause.fill" : "figure.walk")
                    .font(.system(size: 14))
                    .foregroundStyle(context.state.isPaused ? .orange : WidgetColors.accent)
                    .frame(width: 20, height: 20)
            } compactTrailing: {
                compactTimerText(context)
                    .font(.system(size: 12, weight: .medium).monospacedDigit())
                    .foregroundStyle(WidgetColors.accent)
                    .frame(minWidth: 32, maxWidth: 44)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            } minimal: {
                Image(systemName: "figure.walk")
                    .font(.system(size: 12))
                    .foregroundStyle(WidgetColors.accent)
                    .frame(width: 16, height: 16)
            }
        }
    }

    private func formatDuration(_ seconds: Int) -> String {
        let mins = seconds / 60
        let secs = seconds % 60
        return String(format: "%d:%02d", mins, secs)
    }

    private func formatDistance(_ meters: Double) -> String {
        // Convert to miles for US users
        let miles = meters / 1609.34
        if miles < 0.1 {
            return "\(Int(meters))m"
        }
        return String(format: "%.2f mi", miles)
    }

    private func walkModeLabel(_ mode: String) -> String {
        switch mode {
        case "interval": return "Interval"
        case "fatBurn": return "Fat Burn"
        case "postMeal": return "Post-Meal"
        default: return "Walking"
        }
    }

    @ViewBuilder
    private func intervalAwareTimer(_ context: ActivityViewContext<WalkActivityAttributes>) -> some View {
        let isCountdownMode = context.attributes.mode == "interval" || context.attributes.mode == "postMeal"
        if isCountdownMode {
            if context.state.isPaused {
                Text(formatDuration(context.state.intervalPhaseRemaining ?? 0))
            } else if let endDate = context.state.intervalPhaseEndDate, endDate > Date() {
                Text(timerInterval: Date()...endDate, countsDown: true)
            } else {
                Text(formatDuration(context.state.intervalPhaseRemaining ?? 0))
            }
        } else {
            if context.state.isPaused {
                Text(formatDuration(context.state.elapsedSeconds))
            } else {
                Text(context.state.startDate, style: .timer)
            }
        }
    }

    @ViewBuilder
    private func intervalAwareCompactTimer(_ context: ActivityViewContext<WalkActivityAttributes>) -> some View {
        let isCountdownMode = context.attributes.mode == "interval" || context.attributes.mode == "postMeal"
        if isCountdownMode {
            if context.state.isPaused {
                Text(formatDuration(context.state.intervalPhaseRemaining ?? 0))
            } else if let endDate = context.state.intervalPhaseEndDate, endDate > Date() {
                Text(timerInterval: Date()...endDate, countsDown: true)
            } else {
                Text(formatDuration(context.state.intervalPhaseRemaining ?? 0))
            }
        } else {
            if context.state.isPaused {
                Text(formatDuration(context.state.elapsedSeconds))
            } else {
                Text(context.state.startDate, style: .timer)
            }
        }
    }

    /// Compact timer text for Dynamic Island compact trailing view.
    /// Uses abbreviated format to fit within ~44pt width constraint.
    @ViewBuilder
    private func compactTimerText(_ context: ActivityViewContext<WalkActivityAttributes>) -> some View {
        let isCountdownMode = context.attributes.mode == "interval" || context.attributes.mode == "postMeal"
        if isCountdownMode {
            // For countdown modes, show remaining time in short format
            if context.state.isPaused {
                Text(formatCompactDuration(context.state.intervalPhaseRemaining ?? 0))
            } else if let endDate = context.state.intervalPhaseEndDate, endDate > Date() {
                // Use timerInterval for live countdown, but with short format
                Text(timerInterval: Date()...endDate, countsDown: true)
                    .contentTransition(.numericText())
            } else {
                Text(formatCompactDuration(context.state.intervalPhaseRemaining ?? 0))
            }
        } else {
            // For regular mode, show elapsed time in short format (e.g., "5m" or "1:23")
            if context.state.isPaused {
                Text(formatCompactDuration(context.state.elapsedSeconds))
            } else {
                // Show minutes only for compact view to save space
                let minutes = max(0, context.state.elapsedSeconds / 60)
                Text("\(minutes)m")
            }
        }
    }

    /// Format duration for compact view - shorter format to fit width constraints
    private func formatCompactDuration(_ seconds: Int) -> String {
        let mins = seconds / 60
        let secs = seconds % 60
        if mins >= 60 {
            // For 1+ hours, show "1h5m" format
            let hours = mins / 60
            let remainingMins = mins % 60
            return "\(hours)h\(remainingMins)m"
        } else if mins >= 10 {
            // For 10+ minutes, show just minutes
            return "\(mins)m"
        } else {
            // For under 10 minutes, show m:ss
            return "\(mins):\(String(format: "%02d", secs))"
        }
    }
}

// MARK: - Lock Screen View

private struct WalkLockScreenView: View {
    let context: ActivityViewContext<WalkActivityAttributes>

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Image(systemName: "figure.walk")
                        .foregroundStyle(WidgetColors.accent)
                    Text(walkModeLabel)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    if context.state.isPaused {
                        Text("• Paused")
                            .font(.subheadline)
                            .foregroundStyle(.orange)
                    }
                }

                intervalAwareLockScreenTimer(context)
                    .font(.system(size: 36, weight: .bold, design: .rounded).monospacedDigit())
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 8) {
                HStack(spacing: 4) {
                    Text("\(context.state.steps)")
                        .font(.title2.bold().monospacedDigit())
                    Text("steps")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Text(formatDistance(context.state.distance))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
    }

    private var walkModeLabel: String {
        if context.attributes.mode == "interval",
           let label = context.state.intervalPhaseType {
            return "\(label) Interval"
        }
        switch context.attributes.mode {
        case "interval": return "Interval Walk"
        case "fatBurn": return "Fat Burn"
        case "postMeal": return "Post-Meal Walk"
        default: return "Walking"
        }
    }

    private func formatDuration(_ seconds: Int) -> String {
        let mins = seconds / 60
        let secs = seconds % 60
        return String(format: "%d:%02d", mins, secs)
    }

    private func formatDistance(_ meters: Double) -> String {
        let miles = meters / 1609.34
        if miles < 0.1 {
            return "\(Int(meters))m"
        }
        return String(format: "%.2f mi", miles)
    }

    @ViewBuilder
    private func intervalAwareLockScreenTimer(_ context: ActivityViewContext<WalkActivityAttributes>) -> some View {
        let isCountdownMode = context.attributes.mode == "interval" || context.attributes.mode == "postMeal"
        if isCountdownMode {
            if context.state.isPaused {
                Text(formatDuration(context.state.intervalPhaseRemaining ?? 0))
            } else if let endDate = context.state.intervalPhaseEndDate, endDate > Date() {
                Text(timerInterval: Date()...endDate, countsDown: true)
            } else {
                Text(formatDuration(context.state.intervalPhaseRemaining ?? 0))
            }
        } else if context.state.isPaused {
            Text(formatDuration(context.state.elapsedSeconds))
        } else {
            Text(context.state.startDate, style: .timer)
        }
    }
}

// ============================================================================
// MARK: - Widget Bundle
// ============================================================================

@main
struct JustWalkWidgetBundle: WidgetBundle {
    var body: some Widget {
        // Live Activity
        WalkLiveActivity()

        // Home Screen - Small
        TodayWidget()
        StreakWidget()

        // Home Screen - Medium
        TodayStreakWidget()
        ThisWeekWidget()
        ShieldsWidget()

        // Lock Screen - Steps
        StepsGaugeWidget()        // Circular with ring
        StepsInlineWidget()       // Inline text
        StepsRectangularWidget()  // Detail with progress bar

        // Lock Screen - Streak
        StreakCircularWidget()    // Circular with flame
        StreakCountWidget()       // Inline text
    }
}
