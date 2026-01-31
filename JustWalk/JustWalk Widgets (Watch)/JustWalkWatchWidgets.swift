//
//  JustWalkWatchWidgets.swift
//  JustWalk
//
//  Watch complications: Steps progress ring + Streak flame
//

import WidgetKit
import SwiftUI

// MARK: - Shared Data

private struct WatchWidgetData {
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
}

// MARK: - Timeline Entry

struct WatchWidgetEntry: TimelineEntry {
    let date: Date
    let todaySteps: Int
    let stepGoal: Int
    let currentStreak: Int

    var stepProgress: Double {
        guard stepGoal > 0 else { return 0 }
        return min(Double(todaySteps) / Double(stepGoal), 1.0)
    }

    static let placeholder = WatchWidgetEntry(
        date: Date(),
        todaySteps: 4200,
        stepGoal: 5000,
        currentStreak: 12
    )
}

// MARK: - Timeline Provider

struct WatchTimelineProvider: TimelineProvider {
    /// Refresh interval in minutes - 2 minutes is the most aggressive viable option.
    /// Apple allows this for health/fitness apps where timely data matters.
    private static let refreshIntervalMinutes = 2
    /// Number of entries to batch - 30 entries = 1 hour of coverage at 2-min intervals.
    /// Batching doesn't count against the daily budget - only reloadAllTimelines() calls do.
    private static let batchedEntryCount = 30

    func placeholder(in context: Context) -> WatchWidgetEntry {
        .placeholder
    }

    func getSnapshot(in context: Context, completion: @escaping (WatchWidgetEntry) -> Void) {
        if context.isPreview {
            completion(.placeholder)
        } else {
            completion(currentEntry(for: Date()))
        }
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<WatchWidgetEntry>) -> Void) {
        // Generate batched entries for the next hour at 5-minute intervals.
        // This maximizes refresh frequency without using the daily reload budget.
        // Timeline entries don't count against budget - only reloadAllTimelines() calls do.
        var entries: [WatchWidgetEntry] = []
        let now = Date()
        let calendar = Calendar.current

        for i in 0..<Self.batchedEntryCount {
            guard let entryDate = calendar.date(byAdding: .minute, value: i * Self.refreshIntervalMinutes, to: now) else {
                continue
            }
            entries.append(currentEntry(for: entryDate))
        }

        // Use .atEnd so WidgetKit requests new timeline only after all entries are used.
        // This is more budget-efficient than .after(date) for batched entries.
        let timeline = Timeline(entries: entries, policy: .atEnd)
        completion(timeline)
    }

    private func currentEntry(for date: Date) -> WatchWidgetEntry {
        WatchWidgetEntry(
            date: date,
            todaySteps: WatchWidgetData.todaySteps(),
            stepGoal: WatchWidgetData.stepGoal(),
            currentStreak: WatchWidgetData.currentStreak()
        )
    }
}

// MARK: - Steps Widget (Circular)

struct WatchStepsWidget: Widget {
    let kind = "WatchStepsWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: WatchTimelineProvider()) { entry in
            WatchStepsWidgetView(entry: entry)
        }
        .configurationDisplayName("Steps")
        .description("Today's step progress.")
        .supportedFamilies([.accessoryCircular])
    }
}

struct WatchStepsWidgetView: View {
    let entry: WatchWidgetEntry

    // Brand green palette (emerald → accent → bright mint)
    private static let ringStart    = Color(red: 0x20/255, green: 0xA0/255, blue: 0x80/255)
    private static let accentGreen  = Color(red: 0x34/255, green: 0xD3/255, blue: 0x99/255)
    private static let ringEnd      = Color(red: 0x86/255, green: 0xEF/255, blue: 0xAC/255)

    private var ringGradient: AngularGradient {
        AngularGradient(
            stops: [
                .init(color: Self.ringStart,    location: 0.0),
                .init(color: Self.accentGreen,  location: 0.35),
                .init(color: Self.ringEnd,      location: 0.7),
                .init(color: Self.ringStart,    location: 1.0)
            ],
            center: .center,
            startAngle: .degrees(0),
            endAngle: .degrees(360)
        )
    }

    private var ringLineWidth: CGFloat { 5.5 }

    private var stepsText: String {
        entry.todaySteps.formatted()
    }

    private var stepsFontSize: CGFloat {
        stepsText.count >= 6 ? 11 : 12
    }

    private var stepsHorizontalPadding: CGFloat {
        stepsText.count >= 6 ? 4 : 6
    }

    var body: some View {
        ZStack {
            // Background ring
            Circle()
                .stroke(Self.ringStart.opacity(0.3), lineWidth: ringLineWidth)

            // Progress ring — brand green gradient, solid green when goal met
            Circle()
                .trim(from: 0, to: entry.stepProgress)
                .stroke(
                    entry.stepProgress >= 1.0
                        ? AnyShapeStyle(Self.accentGreen)
                        : AnyShapeStyle(ringGradient),
                    style: StrokeStyle(lineWidth: ringLineWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))

            // Full step count with comma formatting
            Text(stepsText)
                .font(.system(size: stepsFontSize, weight: .bold, design: .rounded))
                .minimumScaleFactor(0.4)
                .lineLimit(1)
                .padding(.horizontal, stepsHorizontalPadding)
        }
        .widgetAccentable()
    }
}

// MARK: - Streak Widget (Circular)

struct WatchStreakWidget: Widget {
    let kind = "WatchStreakWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: WatchTimelineProvider()) { entry in
            WatchStreakWidgetView(entry: entry)
        }
        .configurationDisplayName("Streak")
        .description("Your current walking streak.")
        .supportedFamilies([.accessoryCircular])
    }
}

struct WatchStreakWidgetView: View {
    let entry: WatchWidgetEntry

    var body: some View {
        VStack(spacing: 1) {
            Image(systemName: entry.currentStreak > 0 ? "flame.fill" : "flame")
                .font(.system(size: 18))
                .foregroundStyle(entry.currentStreak > 0 ? .orange : .gray)
                .widgetAccentable()

            Text("\(entry.currentStreak)")
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .minimumScaleFactor(0.5)
        }
    }
}

// MARK: - Center Modular Widget (Rectangular)

struct WatchCenterWidget: Widget {
    let kind = "WatchCenterWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: WatchTimelineProvider()) { entry in
            WatchCenterWidgetView(entry: entry)
        }
        .configurationDisplayName("Just Walk")
        .description("Steps, goal progress, and streak at a glance.")
        .supportedFamilies([.accessoryRectangular])
    }
}

struct WatchCenterWidgetView: View {
    let entry: WatchWidgetEntry

    // Brand green palette
    private static let ringStart = Color(red: 0x20/255, green: 0xA0/255, blue: 0x80/255)
    private static let accentGreen = Color(red: 0x34/255, green: 0xD3/255, blue: 0x99/255)
    private static let ringEnd = Color(red: 0x86/255, green: 0xEF/255, blue: 0xAC/255)
    private static let streakOrange = Color(red: 0xFF/255, green: 0x73/255, blue: 0x1A/255)

    private var progressGradient: LinearGradient {
        LinearGradient(
            colors: [Self.ringStart, Self.accentGreen, Self.ringEnd],
            startPoint: .leading,
            endPoint: .trailing
        )
    }

    var body: some View {
        HStack(spacing: 8) {
            // Left: Walking icon
            Image(systemName: "figure.walk")
                .font(.system(size: 24, weight: .semibold))
                .foregroundStyle(Self.accentGreen)
                .frame(width: 32, height: 32)

            // Right: Steps info + streak
            VStack(alignment: .leading, spacing: 2) {
                // Steps count
                Text(entry.todaySteps.formatted())
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)

                // Goal progress bar
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Self.ringStart.opacity(0.3))
                            .frame(height: 4)

                        RoundedRectangle(cornerRadius: 2)
                            .fill(progressGradient)
                            .frame(width: geo.size.width * entry.stepProgress, height: 4)
                    }
                }
                .frame(height: 4)

                // Goal text + streak
                HStack(spacing: 4) {
                    Text("of \(entry.stepGoal.formatted())")
                        .font(.system(size: 10, weight: .medium, design: .rounded))
                        .foregroundStyle(.secondary)

                    Spacer()

                    if entry.currentStreak > 0 {
                        Image(systemName: "flame.fill")
                            .font(.system(size: 9))
                            .foregroundStyle(Self.streakOrange)
                        Text("\(entry.currentStreak)")
                            .font(.system(size: 10, weight: .bold, design: .rounded))
                            .foregroundStyle(Self.streakOrange)
                    }
                }
            }
        }
        .widgetAccentable()
    }
}

// MARK: - Widget Bundle

@main
struct JustWalkWatchWidgetBundle: WidgetBundle {
    var body: some Widget {
        WatchStepsWidget()
        WatchStreakWidget()
        WatchCenterWidget()
    }
}
