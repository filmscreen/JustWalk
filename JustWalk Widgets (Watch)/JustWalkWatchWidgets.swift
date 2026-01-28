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
    func placeholder(in context: Context) -> WatchWidgetEntry {
        .placeholder
    }

    func getSnapshot(in context: Context, completion: @escaping (WatchWidgetEntry) -> Void) {
        if context.isPreview {
            completion(.placeholder)
        } else {
            completion(currentEntry())
        }
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<WatchWidgetEntry>) -> Void) {
        let entry = currentEntry()
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 15, to: Date()) ?? Date()
        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
        completion(timeline)
    }

    private func currentEntry() -> WatchWidgetEntry {
        WatchWidgetEntry(
            date: Date(),
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

    var body: some View {
        ZStack {
            // Background ring
            Circle()
                .stroke(Self.ringStart.opacity(0.3), lineWidth: 3.5)

            // Progress ring — brand green gradient, solid green when goal met
            Circle()
                .trim(from: 0, to: entry.stepProgress)
                .stroke(
                    entry.stepProgress >= 1.0
                        ? AnyShapeStyle(Self.accentGreen)
                        : AnyShapeStyle(ringGradient),
                    style: StrokeStyle(lineWidth: 3.5, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))

            // Full step count with comma formatting
            Text(entry.todaySteps.formatted())
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .minimumScaleFactor(0.4)
                .lineLimit(1)
                .padding(.horizontal, 6)
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

// MARK: - Widget Bundle

@main
struct JustWalkWatchWidgetBundle: WidgetBundle {
    var body: some Widget {
        WatchStepsWidget()
        WatchStreakWidget()
    }
}
