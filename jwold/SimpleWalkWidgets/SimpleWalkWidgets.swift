import WidgetKit
import SwiftUI

// MARK: - Widget Design System

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

// MARK: - Timeline Entry

struct SimpleEntry: TimelineEntry {
    let date: Date
    let steps: Int
    let goal: Int
    let distance: Double
    let usesMetric: Bool  // true = kilometers, false = miles
}


// MARK: - Goal State (Color Logic)

enum GoalState {
    case inProgress  // < 100% of goal
    case reached     // = 100% of goal
    case bonus       // > 100% of goal

    init(steps: Int, goal: Int) {
        let percentage = Double(steps) / Double(goal)
        if percentage > 1.0 {
            self = .bonus
        } else if percentage >= 1.0 {
            self = .reached
        } else {
            self = .inProgress
        }
    }

    var ringColor: Color {
        switch self {
        case .inProgress: return Color(red: 0, green: 0.78, blue: 0.75)  // #00C7BE Teal
        case .reached:    return Color(red: 1, green: 0.58, blue: 0)     // #FF9500 Orange
        case .bonus:      return Color(red: 0.2, green: 0.78, blue: 0.35) // #34C759 Green
        }
    }

    var textColor: Color {
        switch self {
        case .inProgress: return .white
        case .reached:    return Color(red: 1, green: 0.58, blue: 0)     // #FF9500 Orange
        case .bonus:      return Color(red: 0.2, green: 0.78, blue: 0.35) // #34C759 Green
        }
    }
}

struct Provider: TimelineProvider {
    // Widget is "dumb" - it only reads from App Group.
    // All step calculations happen in StepRepository (main app).

    // MARK: - Data Fetching

    private func loadData(completion: @escaping (Int, Double, Int, Bool) -> Void) {
        let sharedDefaults = UserDefaults(suiteName: "group.com.onworldtech.JustWalk")
        let udSteps = sharedDefaults?.integer(forKey: "todaySteps") ?? 0
        let udDistance = sharedDefaults?.double(forKey: "todayDistance") ?? 0.0
        let udGoal = sharedDefaults?.integer(forKey: "dailyStepGoal")
        let goal = (udGoal ?? 0) > 0 ? udGoal! : 10000

        // Read distance unit preference (defaults to miles)
        let unitPref = sharedDefaults?.string(forKey: "preferredDistanceUnit") ?? "Miles"
        let usesMetric = (unitPref == "Kilometers")

        // CRITICAL: Use forDate (the date the steps are FOR) instead of lastUpdateDate
        // This prevents showing yesterday's steps after midnight
        let forDate = sharedDefaults?.object(forKey: "forDate") as? Date
        let lastUpdate = sharedDefaults?.object(forKey: "lastUpdateDate") as? Date ?? Date.distantPast

        // Determine if cached data is valid:
        // 1. forDate must be today (preferred - new system)
        // 2. Fall back to lastUpdateDate for backward compatibility
        let today = Calendar.current.startOfDay(for: Date())
        let isForToday: Bool
        if let forDate = forDate {
            isForToday = Calendar.current.isDate(forDate, inSameDayAs: today)
        } else {
            // Backward compatibility: use lastUpdateDate
            isForToday = Calendar.current.isDateInToday(lastUpdate)
        }

        // Reject obviously corrupted values (100k+ steps = 50+ miles in a day)
        let maxReasonableSteps = 100_000
        let isReasonableData = udSteps <= maxReasonableSteps

        let cachedSteps = (isForToday && isReasonableData) ? udSteps : 0
        let cachedDistance = (isForToday && isReasonableData) ? udDistance : 0.0

        #if os(watchOS)
        // On watchOS, ALWAYS use App Group data from WatchHealthManager
        // Widget extensions on watchOS can get stale CoreMotion data that differs from the main app
        // WatchHealthManager keeps App Group in sync with HealthKit (the source of truth)
        completion(cachedSteps, cachedDistance, goal, usesMetric)
        #else
        // STRICT HEALTHKIT SYNC (iOS):
        // Do NOT query CoreMotion directly. Use the App Group data which is synced
        // from HealthKit by the main app. This ensures the widget matches Apple Health exactly.
        completion(cachedSteps, cachedDistance, goal, usesMetric)
        #endif
    }

    /// Calculate average steps per minute based on recent activity
    private func calculateStepsPerMinute(currentSteps: Int) -> Double {
        let sharedDefaults = UserDefaults(suiteName: "group.com.onworldtech.JustWalk")

        // Get the timestamp of the last update
        guard let lastUpdate = sharedDefaults?.object(forKey: "lastUpdateDate") as? Date,
              Calendar.current.isDateInToday(lastUpdate) else {
            return 0 // No recent data, assume idle
        }

        // Get the steps from the last recorded checkpoint
        let lastSteps = sharedDefaults?.integer(forKey: "lastCheckpointSteps") ?? 0
        let lastCheckpoint = sharedDefaults?.object(forKey: "lastCheckpointTime") as? Date ?? lastUpdate

        // Calculate minutes since last checkpoint
        let minutesSinceCheckpoint = Date().timeIntervalSince(lastCheckpoint) / 60.0

        // If more than 30 minutes since checkpoint, assume low activity
        guard minutesSinceCheckpoint > 0 && minutesSinceCheckpoint < 30 else {
            return 0
        }

        // Guard against division by near-zero or extremely short intervals
        // Only calculate rate if at least 1 minute has passed to ensure stability
        guard minutesSinceCheckpoint > 1.0 else {
            return 0
        }

        let stepsDelta = currentSteps - lastSteps
        if stepsDelta > 0 {
            let rate = Double(stepsDelta) / minutesSinceCheckpoint
            // Cap at realistic maximum (300 steps/min is ~running speed)
            // This prevents "500k steps" bugs if time delta is small or clocks sync oddly
            return min(rate, 300.0)
        }

        return 0
    }

    func placeholder(in context: Context) -> SimpleEntry {
        // More appealing preview: 8,234 steps (82% of 10K goal), ~6.3km walked
        SimpleEntry(date: Date(), steps: 8234, goal: 10000, distance: 6300.0, usesMetric: false)
    }

    func getSnapshot(in context: Context, completion: @escaping (SimpleEntry) -> ()) {
        if context.isPreview {
            // Widget gallery preview - show appealing data
            completion(SimpleEntry(date: Date(), steps: 8234, goal: 10000, distance: 6300.0, usesMetric: false))
        } else {
            loadData { steps, distance, goal, usesMetric in
                let entry = SimpleEntry(date: Date(), steps: steps, goal: goal, distance: distance, usesMetric: usesMetric)
                completion(entry)
            }
        }
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<SimpleEntry>) -> ()) {
        loadData { currentSteps, currentDistance, goal, usesMetric in
            var entries: [SimpleEntry] = []
            let now = Date()
            let calendar = Calendar.current

            // STRICT HEALTHKIT SYNC:
            // We have intentionally disabled predictive calculations (stepsPerMinute)
            // to prevent drift. Steps are now static based on the last known check.

            // ULTRA-AGGRESSIVE STRATEGY for Watch complications:
            // Generate entries every 2 minutes for the next 30 minutes
            // This maximizes freshness when user glances at their watch
            #if os(watchOS)
            let intervals = 15 // 15 entries x 2 min = 30 minutes of coverage
            let intervalMinutes = 2
            #else
            // iOS widgets can be less aggressive
            let intervals = 12 // 12 entries x 5 min = 60 minutes
            let intervalMinutes = 5
            #endif

            for i in 0..<intervals {
                guard let entryDate = calendar.date(byAdding: .minute, value: i * intervalMinutes, to: now) else { continue }

                // STRICT HEALTHKIT SYNC:
                // Disable optimistic step projection.
                // Previously, we guessed future steps based on cadence. This caused the widget/complication
                // to drift "ahead" of reality if the user stopped walking.
                // We now show ONLY the confirmed steps from the last sync.
                let projectedAdditionalSteps = 0

                let projectedSteps = currentSteps + projectedAdditionalSteps
                let projectedDistance = currentDistance // Distance also static

                let entry = SimpleEntry(
                    date: entryDate,
                    steps: projectedSteps,
                    goal: goal,
                    distance: projectedDistance,
                    usesMetric: usesMetric
                )
                entries.append(entry)
            }

            // STANDARDIZED REFRESH: Both iOS and watchOS use 15-minute refresh policy
            // This ensures widgets on both platforms stay in sync and show consistent data.
            // Previous issue: iOS used .atEnd (60-min) while watchOS used 15-min, causing discrepancies.
            let refreshDate = calendar.date(byAdding: .minute, value: 15, to: now) ?? now.addingTimeInterval(900)
            let timeline = Timeline(entries: entries, policy: .after(refreshDate))

            completion(timeline)
        }
    }

    /// Save checkpoint for activity rate calculation (called from main app)
    static func saveCheckpoint(steps: Int) {
        let sharedDefaults = UserDefaults(suiteName: "group.com.onworldtech.JustWalk")
        sharedDefaults?.set(steps, forKey: "lastCheckpointSteps")
        sharedDefaults?.set(Date(), forKey: "lastCheckpointTime")
    }
}


// MARK: - Steps Widget Views

struct StepsWidgetView: View {
    var entry: SimpleEntry
    @Environment(\.widgetFamily) var family

    var body: some View {
        #if os(watchOS)
        switch family {
        case .accessoryCircular:
            StepsCircularView(entry: entry)
        case .accessoryRectangular:
            StepsRectangularView(entry: entry)
        case .accessoryInline:
            StepsInlineView(entry: entry)
        case .accessoryCorner:
            StepsCornerView(entry: entry)
        @unknown default:
            // Fallback for future families (including extra large)
            StepsExtraLargeView(entry: entry)
        }
        #else
        // Lock Screen Widgets only (iOS)
        Group {
            switch family {
            case .accessoryCircular:
                LockScreenCircularView(entry: entry)
            case .accessoryRectangular:
                LockScreenRectangularView(entry: entry)
            case .accessoryInline:
                LockScreenInlineView(entry: entry)
            default:
                LockScreenCircularView(entry: entry)
            }
        }
        .widgetURL(URL(string: "justwalk://home"))
        #endif
    }
}

// MARK: - Distance Widget View (Unified - Reads User Preference)

struct DistanceWidgetView: View {
    var entry: SimpleEntry
    @Environment(\.widgetFamily) var family

    var body: some View {
        #if os(watchOS)
        switch family {
        case .accessoryCircular:
            DistanceCircularView(entry: entry, useMiles: !entry.usesMetric)
        case .accessoryRectangular:
            DistanceRectangularView(entry: entry, useMiles: !entry.usesMetric)
        case .accessoryInline:
            DistanceInlineView(entry: entry, useMiles: !entry.usesMetric)
        case .accessoryCorner:
            DistanceCornerView(entry: entry, useMiles: !entry.usesMetric)
        @unknown default:
            DistanceExtraLargeView(entry: entry, useMiles: !entry.usesMetric)
        }
        #else
        // Lock Screen Widgets only (iOS)
        Group {
            switch family {
            case .accessoryCircular:
                LockScreenDistanceCircularView(entry: entry)
            case .accessoryRectangular:
                LockScreenDistanceRectangularView(entry: entry)
            case .accessoryInline:
                LockScreenDistanceInlineView(entry: entry)
            default:
                LockScreenDistanceCircularView(entry: entry)
            }
        }
        .widgetURL(URL(string: "justwalk://distance"))
        #endif
    }
}

// MARK: - iOS Views (Steps) - Minimalist Data-First Design

#if os(iOS)

// MARK: - Formatting Helpers (iOS)

/// Format remaining steps with commas for "to go" display
private func iOSFormatRemainingSteps(_ entry: SimpleEntry) -> String {
    let remaining = max(0, entry.goal - entry.steps)
    let formatter = NumberFormatter()
    formatter.numberStyle = .decimal
    return formatter.string(from: NSNumber(value: remaining)) ?? "\(remaining)"
}

/// Format bonus steps (steps over goal)
private func iOSFormatBonusSteps(_ entry: SimpleEntry) -> String {
    let bonus = max(0, entry.steps - entry.goal)
    let formatter = NumberFormatter()
    formatter.numberStyle = .decimal
    return "+\(formatter.string(from: NSNumber(value: bonus)) ?? "\(bonus)")"
}



// MARK: - Native Small Widget (iOS 17+)

struct NativeSmallWidgetView: View {
    var entry: StepWidgetEntry

    private var progress: Double {
        min(entry.progress, 1.0)
    }

    private var ringColor: Color {
        NativeWidgetDesign.ringColor(for: entry.progress)
    }

    private var formattedSteps: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return formatter.string(from: NSNumber(value: entry.steps)) ?? "\(entry.steps)"
    }

    var body: some View {
        ZStack {
            // Walking icon top-right (subtle brand presence)
            VStack {
                HStack {
                    Spacer()
                    Image(systemName: "figure.walk")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.tertiary)
                }
                Spacer()
            }
            .padding(12)

            // Ring + content centered
            VStack(spacing: 4) {
                ZStack {
                    // Track
                    Circle()
                        .stroke(NativeWidgetDesign.ringTrack, lineWidth: 8)

                    // Progress arc
                    Circle()
                        .trim(from: 0, to: progress)
                        .stroke(ringColor, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                        .rotationEffect(.degrees(-90))

                    // Center: step count
                    Text(formattedSteps)
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundStyle(.primary)
                        .minimumScaleFactor(0.6)
                }
                .frame(width: 90, height: 90)

                Text("steps")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.secondary)
            }
        }
        .containerBackground(.fill.tertiary, for: .widget)
    }
}

// MARK: - Native Medium Widget (iOS 17+)

struct NativeMediumWidgetView: View {
    var entry: StepWidgetEntry

    private var progress: Double {
        min(entry.progress, 1.0)
    }

    private var ringColor: Color {
        NativeWidgetDesign.ringColor(for: entry.progress)
    }

    private var formattedSteps: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return formatter.string(from: NSNumber(value: entry.steps)) ?? "\(entry.steps)"
    }

    private var stepsRemaining: Int {
        max(0, entry.goal - entry.steps)
    }

    private var formattedRemaining: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return formatter.string(from: NSNumber(value: stepsRemaining)) ?? "\(stepsRemaining)"
    }

    var body: some View {
        HStack(spacing: 16) {
            // Left: Walking icon + Progress ring with step count
            VStack {
                // Walking icon top-left
                HStack {
                    Image(systemName: "figure.walk")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.tertiary)
                    Spacer()
                }

                Spacer()

                // Progress ring
                ZStack {
                    Circle()
                        .stroke(NativeWidgetDesign.ringTrack, lineWidth: 6)

                    Circle()
                        .trim(from: 0, to: progress)
                        .stroke(ringColor, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                        .rotationEffect(.degrees(-90))

                    Text(formatCompactSteps(entry.steps))
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundStyle(.primary)
                }
                .frame(width: 60, height: 60)

                Spacer()
            }
            .frame(width: 72)

            // Right: Stats
            VStack(alignment: .leading, spacing: 6) {
                // Step count + "steps"
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(formattedSteps)
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundStyle(.primary)
                    Text("steps")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.secondary)
                }

                // Progress bar
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(NativeWidgetDesign.ringTrack)
                            .frame(height: 6)

                        RoundedRectangle(cornerRadius: 3)
                            .fill(ringColor)
                            .frame(width: geo.size.width * progress, height: 6)
                    }
                }
                .frame(height: 6)

                // Bottom row: "X to goal" + streak
                HStack {
                    if entry.goalReached {
                        Text("Goal reached!")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(NativeWidgetDesign.goldAccent)
                    } else {
                        Text("\(formattedRemaining) to goal")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    if entry.streakDays > 0 {
                        HStack(spacing: 2) {
                            Image(systemName: "flame.fill")
                                .font(.system(size: 10, weight: .semibold))
                            Text("\(entry.streakDays)")
                                .font(.system(size: 12, weight: .semibold, design: .rounded))
                        }
                        .foregroundStyle(NativeWidgetDesign.orangeAccent)
                    }
                }
            }
        }
        .padding(16)
        .containerBackground(.fill.tertiary, for: .widget)
    }
}

// MARK: - Native Large Widget (iOS 17+)

struct NativeLargeWidgetView: View {
    var entry: StepWidgetEntry

    private var progress: Double {
        min(entry.progress, 1.0)
    }

    private var ringColor: Color {
        NativeWidgetDesign.ringColor(for: entry.progress)
    }

    private var formattedSteps: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return formatter.string(from: NSNumber(value: entry.steps)) ?? "\(entry.steps)"
    }

    private var formattedGoal: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return formatter.string(from: NSNumber(value: entry.goal)) ?? "\(entry.goal)"
    }

    private var percentComplete: Int {
        Int(entry.progress * 100)
    }

    private let dayLabels = ["S", "M", "T", "W", "T", "F", "S"]

    var body: some View {
        VStack(spacing: 16) {
            // Header: "Just Walk" + streak badge
            HStack {
                Text("Just Walk")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.secondary)

                Spacer()

                if entry.streakDays > 0 {
                    HStack(spacing: 4) {
                        Image(systemName: "flame.fill")
                            .font(.system(size: 11, weight: .bold))
                        Text("\(entry.streakDays) days")
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                    }
                    .foregroundStyle(NativeWidgetDesign.orangeAccent)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(NativeWidgetDesign.orangeAccent.opacity(0.15))
                    )
                }
            }

            // Hero: Big step count + progress bar + percentage
            VStack(spacing: 8) {
                Text(formattedSteps)
                    .font(.system(size: 48, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)

                // Progress bar
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(NativeWidgetDesign.ringTrack)
                            .frame(height: 8)

                        RoundedRectangle(cornerRadius: 4)
                            .fill(ringColor)
                            .frame(width: geo.size.width * progress, height: 8)
                    }
                }
                .frame(height: 8)

                Text("\(percentComplete)% of \(formattedGoal) goal")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.secondary)
            }

            // Week chart
            NativeWeekChartView(weekData: entry.weekData, goal: entry.goal)

            Spacer()

            // Footer: Rank icon + title + days walking
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: entry.rankIcon)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(NativeWidgetDesign.tealAccent)
                    Text(entry.rankTitle)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.primary)
                }

                Spacer()

                Text("\(entry.daysAsWalker) days walking")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(16)
        .containerBackground(.fill.tertiary, for: .widget)
    }
}

// MARK: - Native Week Chart (Large Widget)

struct NativeWeekChartView: View {
    let weekData: [DayData]
    let goal: Int

    private let dayLabels = ["S", "M", "T", "W", "T", "F", "S"]

    private var maxSteps: Int {
        max(weekData.map { $0.steps }.max() ?? goal, goal)
    }

    var body: some View {
        VStack(spacing: 4) {
            // Bars
            HStack(alignment: .bottom, spacing: 8) {
                ForEach(0..<7, id: \.self) { index in
                    let day = weekData.indices.contains(index) ? weekData[index] : DayData(date: Date(), steps: 0, goalMet: false)
                    let height = maxSteps > 0 ? CGFloat(day.steps) / CGFloat(maxSteps) : 0

                    VStack(spacing: 4) {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(day.goalMet ? NativeWidgetDesign.tealAccent : NativeWidgetDesign.ringTrack)
                            .frame(height: max(4, height * 44))

                        Text(dayLabel(for: day.date, fallbackIndex: index))
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
    }

    private func dayLabel(for date: Date, fallbackIndex: Int) -> String {
        let weekday = Calendar.current.component(.weekday, from: date)
        return dayLabels[(weekday - 1) % 7]
    }
}

// MARK: - Native Lock Screen Circular Widget (iOS 17+)

struct NativeLockScreenCircularView: View {
    var entry: StepWidgetEntry

    private var progress: Double {
        min(entry.progress, 1.0)
    }

    private var goalReached: Bool {
        entry.steps >= entry.goal
    }

    var body: some View {
        Gauge(value: progress, in: 0...1) {
            EmptyView()
        } currentValueLabel: {
            if goalReached {
                Image(systemName: "checkmark")
                    .font(.system(size: 14, weight: .bold))
            } else {
                Text(formatCompactSteps(entry.steps))
                    .font(.system(size: 12, weight: .bold, design: .rounded))
            }
        }
        .gaugeStyle(.accessoryCircularCapacity)
        .tint(goalReached ? NativeWidgetDesign.orangeAccent : NativeWidgetDesign.tealAccent)
    }
}

// MARK: - Native Lock Screen Rectangular Widget (iOS 17+)

struct NativeLockScreenRectangularView: View {
    var entry: StepWidgetEntry

    private var progress: Double {
        min(entry.progress, 1.0)
    }

    private var goalReached: Bool {
        entry.steps >= entry.goal
    }

    private var stepsRemaining: Int {
        max(0, entry.goal - entry.steps)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: "figure.walk")
                    .font(.system(size: 12, weight: .medium))

                if goalReached {
                    Text("Goal reached!")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                } else {
                    Text("\(stepsRemaining.formatted()) to go")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                }
            }

            Gauge(value: progress, in: 0...1) { EmptyView() }
                .gaugeStyle(.accessoryLinearCapacity)
                .tint(goalReached ? NativeWidgetDesign.orangeAccent : NativeWidgetDesign.tealAccent)
        }
    }
}

// MARK: - Native Lock Screen Inline Widget (iOS 17+)

struct NativeLockScreenInlineView: View {
    var entry: StepWidgetEntry

    var body: some View {
        Label {
            if entry.streakDays > 0 {
                Text("\(entry.steps.formatted()) steps · 🔥 \(entry.streakDays)")
            } else {
                Text("\(entry.steps.formatted()) steps")
            }
        } icon: {
            Image(systemName: "figure.walk")
        }
    }
}

// MARK: - Widget View Router (iOS 17+)

struct RedesignedStepsWidgetView: View {
    var entry: StepWidgetEntry
    @Environment(\.widgetFamily) var family

    var body: some View {
        Group {
            switch family {
            case .systemSmall:
                NativeSmallWidgetView(entry: entry)
            case .systemMedium:
                NativeMediumWidgetView(entry: entry)
            case .systemLarge:
                NativeLargeWidgetView(entry: entry)
            case .accessoryCircular:
                NativeLockScreenCircularView(entry: entry)
            case .accessoryRectangular:
                NativeLockScreenRectangularView(entry: entry)
            case .accessoryInline:
                NativeLockScreenInlineView(entry: entry)
            default:
                NativeSmallWidgetView(entry: entry)
            }
        }
        .widgetURL(URL(string: "justwalk://home"))
    }
}

// MARK: - Small Widget (Dark Background with Colored Ring)

struct SmallWidgetView: View {
    var entry: SimpleEntry

    private var progress: Double {
        min(Double(entry.steps) / Double(entry.goal), 1.0)
    }

    private var state: GoalState {
        GoalState(steps: entry.steps, goal: entry.goal)
    }

    // Ring configuration
    private let ringStroke: CGFloat = 10.0

    var body: some View {
        GeometryReader { geometry in
            let size = min(geometry.size.width, geometry.size.height)
            let ringSize = size * 0.85

            ZStack {
                // Dark background
                WidgetColors.background

                // Subtle walking man icon in corner
                VStack {
                    HStack {
                        Spacer()
                        WalkingManIcon(size: 14, opacity: 0.4)
                    }
                    Spacer()
                }
                .padding(12)

                // Progress ring
                ZStack {
                    // Track
                    Circle()
                        .stroke(WidgetColors.ringTrack, lineWidth: ringStroke)

                    // Progress arc (colored based on goal state)
                    Circle()
                        .trim(from: 0, to: progress)
                        .stroke(
                            state.ringColor,
                            style: StrokeStyle(lineWidth: ringStroke, lineCap: .round)
                        )
                        .rotationEffect(.degrees(-90))

                    // Center content
                    VStack(spacing: 0) {
                        // Trophy for goal reached
                        if state != .inProgress {
                            Text("🏆")
                                .font(.system(size: 16))
                        }

                        // Step count (formatted with K suffix)
                        Text(formatStepCountCompact(entry.steps))
                            .font(.system(size: 32, weight: .bold, design: .rounded))
                            .foregroundStyle(state.textColor)
                            .minimumScaleFactor(0.5)

                        // "steps" label
                        Text("steps")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(WidgetColors.textSecondary)
                    }
                }
                .frame(width: ringSize, height: ringSize)
            }
        }
        .containerBackground(WidgetColors.background, for: .widget)
    }
}

/// Format step count with K suffix for compact display
private func formatStepCountCompact(_ steps: Int) -> String {
    if steps >= 10000 {
        let k = Double(steps) / 1000.0
        return String(format: "%.1fK", k)
    } else if steps >= 1000 {
        let k = Double(steps) / 1000.0
        return String(format: "%.1fK", k)
    }
    return "\(steps)"
}

// MARK: - Medium Widget (Dark Background with Horizontal Progress Bar)

struct MediumWidgetView: View {
    var entry: SimpleEntry

    private var progress: Double {
        Double(entry.steps) / Double(entry.goal)
    }

    private var formattedSteps: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return formatter.string(from: NSNumber(value: entry.steps)) ?? "\(entry.steps)"
    }

    var body: some View {
        ZStack {
            WidgetColors.background

            VStack(alignment: .leading, spacing: 12) {
                // Walking man icon - top LEFT
                WalkingManIcon(size: 16, opacity: 0.4)

                Spacer()

                // Main content - steps only, no progress bar
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(formattedSteps)
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundColor(WidgetColors.textColor(for: progress))

                    Text("steps")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(WidgetColors.textSecondary)
                }
            }
            .padding(16)
        }
        .containerBackground(WidgetColors.background, for: .widget)
    }
}

// MARK: - Steps Remaining Widget Views (NEW)

struct SmallStepsRemainingWidgetView: View {
    var entry: SimpleEntry

    private var state: GoalState {
        GoalState(steps: entry.steps, goal: entry.goal)
    }

    private var remaining: Int {
        max(0, entry.goal - entry.steps)
    }

    private var progress: Double {
        min(Double(entry.steps) / Double(entry.goal), 1.0)
    }

    private let ringStroke: CGFloat = 8.0

    var body: some View {
        GeometryReader { geometry in
            let ringSize = min(geometry.size.width, geometry.size.height) * 0.7

            ZStack {
                WidgetColors.background

                ZStack {
                    // Background ring track
                    Circle()
                        .stroke(Color.white.opacity(0.2), lineWidth: ringStroke)

                    // Progress ring
                    Circle()
                        .trim(from: 0, to: progress)
                        .stroke(state.ringColor, style: StrokeStyle(lineWidth: ringStroke, lineCap: .round))
                        .rotationEffect(.degrees(-90))

                    // Center content
                    if state == .inProgress {
                        Text(formatCompact(remaining))
                            .font(.system(size: 24, weight: .bold, design: .rounded))
                            .foregroundStyle(state.textColor)
                            .minimumScaleFactor(0.6)
                    } else {
                        // Goal reached - show checkmark
                        VStack(spacing: 2) {
                            Text("🏆")
                                .font(.system(size: 14))
                            Image(systemName: "checkmark")
                                .font(.system(size: 20, weight: .bold))
                                .foregroundStyle(state.textColor)
                        }
                    }
                }
                .frame(width: ringSize, height: ringSize)
            }
        }
        .containerBackground(WidgetColors.background, for: .widget)
    }

    private func formatCompact(_ n: Int) -> String {
        if n > 99999 {
            return String(format: "%.1fK", Double(n) / 1000)
        }
        return NumberFormatter.localizedString(from: NSNumber(value: n), number: .decimal)
    }
}

struct MediumStepsRemainingWidgetView: View {
    var entry: SimpleEntry

    private var state: GoalState {
        GoalState(steps: entry.steps, goal: entry.goal)
    }

    private var remaining: Int {
        max(0, entry.goal - entry.steps)
    }

    private var progress: Double {
        min(Double(entry.steps) / Double(entry.goal), 1.0)
    }

    var body: some View {
        ZStack {
            WidgetColors.background

            VStack(alignment: .leading, spacing: 8) {
                // Header row
                HStack(spacing: 6) {
                    if state != .inProgress {
                        Text("🏆")
                            .font(.system(size: 18))
                    }

                    if state == .inProgress {
                        Text("\(remaining.formatted()) to go")
                            .font(.system(size: 22, weight: .bold, design: .rounded))
                            .foregroundStyle(state.textColor)
                    } else {
                        Text("Goal reached!")
                            .font(.system(size: 22, weight: .bold, design: .rounded))
                            .foregroundStyle(state.textColor)
                    }
                }

                // Progress bar
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        // Track
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.white.opacity(0.2))
                            .frame(height: 8)

                        // Fill
                        RoundedRectangle(cornerRadius: 4)
                            .fill(state.ringColor)
                            .frame(width: geo.size.width * progress, height: 8)
                    }
                }
                .frame(height: 8)
            }
            .padding(16)
        }
        .containerBackground(WidgetColors.background, for: .widget)
    }
}

struct StepsRemainingWidgetView: View {
    var entry: SimpleEntry
    @Environment(\.widgetFamily) var family

    var body: some View {
        Group {
            switch family {
            case .systemSmall:
                SmallStepsRemainingWidgetView(entry: entry)
            case .systemMedium:
                MediumStepsRemainingWidgetView(entry: entry)
            default:
                SmallStepsRemainingWidgetView(entry: entry)
            }
        }
        .widgetURL(URL(string: "justwalk://home"))
    }
}

// MARK: - Small Distance Widget (Unified - iOS)

struct SmallDistanceWidgetView: View {
    var entry: SimpleEntry

    private var distanceValue: Double {
        entry.usesMetric ? entry.distance * 0.001 : entry.distance * 0.000621371
    }

    private var unitLabel: String {
        entry.usesMetric ? "km" : "mi"
    }

    private var distanceGoal: Double {
        entry.usesMetric ? Double(entry.goal) * 0.0008 : Double(entry.goal) * 0.0005
    }

    private var state: GoalState {
        let percentage = distanceValue / distanceGoal
        if percentage > 1.0 { return .bonus }
        if percentage >= 1.0 { return .reached }
        return .inProgress
    }

    private var progress: Double {
        min(distanceValue / distanceGoal, 1.0)
    }

    private let ringStroke: CGFloat = 8.0

    var body: some View {
        GeometryReader { geometry in
            let ringSize = min(geometry.size.width, geometry.size.height) * 0.7

            ZStack {
                WidgetColors.background

                ZStack {
                    Circle()
                        .stroke(Color.white.opacity(0.2), lineWidth: ringStroke)

                    Circle()
                        .trim(from: 0, to: progress)
                        .stroke(state.ringColor, style: StrokeStyle(lineWidth: ringStroke, lineCap: .round))
                        .rotationEffect(.degrees(-90))

                    VStack(spacing: 2) {
                        if state != .inProgress {
                            Text("🏆")
                                .font(.system(size: 14))
                        }
                        Text(String(format: "%.1f", distanceValue))
                            .font(.system(size: 24, weight: .bold, design: .rounded))
                            .foregroundStyle(state.textColor)
                            .minimumScaleFactor(0.6)
                        Text(unitLabel)
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(WidgetColors.textSecondary)
                    }
                }
                .frame(width: ringSize, height: ringSize)
            }
        }
        .containerBackground(WidgetColors.background, for: .widget)
    }
}

// MARK: - Medium Distance Widget (Unified - iOS)

struct MediumDistanceWidgetView: View {
    var entry: SimpleEntry

    private var distanceValue: Double {
        entry.usesMetric ? entry.distance * 0.001 : entry.distance * 0.000621371
    }

    private var unitLabel: String {
        entry.usesMetric ? "km" : "miles"
    }

    private var distanceGoal: Double {
        entry.usesMetric ? Double(entry.goal) * 0.0008 : Double(entry.goal) * 0.0005
    }

    private var progress: Double {
        distanceValue / distanceGoal
    }

    private var formattedDistance: String {
        String(format: "%.1f", distanceValue)
    }

    var body: some View {
        ZStack {
            WidgetColors.background

            VStack(alignment: .leading, spacing: 12) {
                // Walking man icon - top LEFT
                WalkingManIcon(size: 16, opacity: 0.4)

                Spacer()

                // Main content
                VStack(alignment: .leading, spacing: 8) {
                    // Number and unit
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text(formattedDistance)
                            .font(.system(size: 32, weight: .bold, design: .rounded))
                            .foregroundColor(WidgetColors.textColor(for: progress))

                        Text(unitLabel)
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(WidgetColors.textSecondary)
                    }

                    // Progress bar
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(WidgetColors.ringTrack)
                                .frame(height: 8)

                            RoundedRectangle(cornerRadius: 4)
                                .fill(WidgetColors.barColor(for: progress))
                                .frame(width: geo.size.width * min(progress, 1.0), height: 8)
                        }
                    }
                    .frame(height: 8)
                }
            }
            .padding(16)
        }
        .containerBackground(WidgetColors.background, for: .widget)
    }
}

// MARK: - iOS Lock Screen Views (Steps)

/// Circular Lock Screen widget showing progress gauge with remaining or trophy
struct LockScreenCircularView: View {
    var entry: SimpleEntry

    private var progress: Double {
        guard entry.goal > 0 else { return 0 }
        return min(Double(entry.steps) / Double(entry.goal), 1.0)
    }

    private var goalReached: Bool { entry.steps >= entry.goal }

    var body: some View {
        Gauge(value: progress, in: 0...1) {
            // Label (not shown in circular)
        } currentValueLabel: {
            if goalReached {
                Image(systemName: "trophy.fill")
                    .font(.system(size: 14, weight: .semibold))
            } else {
                Image(systemName: "figure.walk")
                    .font(.system(size: 14, weight: .semibold))
            }
        }
        .gaugeStyle(.accessoryCircularCapacity)
        .tint(Gradient(colors: goalReached ? [.yellow, .orange] : [.teal, .cyan]))
    }
}

/// Rectangular Lock Screen widget showing "X to go" or "Goal hit! +X"
struct LockScreenRectangularView: View {
    var entry: SimpleEntry

    private var progress: Double {
        guard entry.goal > 0 else { return 0 }
        return min(Double(entry.steps) / Double(entry.goal), 1.0)
    }

    private var goalReached: Bool { entry.steps >= entry.goal }

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            // Row 1: "X to go" or "Goal hit! +X"
            HStack(spacing: 4) {
                Image(systemName: goalReached ? "trophy.fill" : "figure.walk")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(goalReached ? .yellow : .primary)
                if goalReached {
                    Text("Goal hit!")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundStyle(.yellow)
                    Text(iOSFormatBonusSteps(entry))
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.yellow.opacity(0.8))
                } else {
                    Text(iOSFormatRemainingSteps(entry))
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                    Text("to go")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.secondary)
                }
            }

            // Row 2: Progress bar
            Gauge(value: progress, in: 0...1) {
                EmptyView()
            }
            .gaugeStyle(.accessoryLinearCapacity)
            .tint(Gradient(colors: goalReached ? [.yellow, .orange] : [.teal, .cyan]))
        }
    }
}

/// Inline Lock Screen widget showing "X to go" or "+X" bonus
struct LockScreenInlineView: View {
    var entry: SimpleEntry

    private var goalReached: Bool { entry.steps >= entry.goal }

    var body: some View {
        Label {
            if goalReached {
                Text(iOSFormatBonusSteps(entry))
            } else {
                Text("\(iOSFormatRemainingSteps(entry)) to go")
            }
        } icon: {
            Image(systemName: goalReached ? "trophy.fill" : "figure.walk")
        }
    }
}

// MARK: - iOS Lock Screen Views (Distance - Unified)

struct LockScreenDistanceCircularView: View {
    var entry: SimpleEntry

    private var distanceValue: Double {
        entry.usesMetric ? entry.distance * 0.001 : entry.distance * 0.000621371
    }

    private var distanceGoal: Double {
        entry.usesMetric ? 8.0 : 5.0  // 8 km or 5 miles
    }

    private var progress: Double {
        min(distanceValue / distanceGoal, 1.0)
    }

    private var goalReached: Bool { distanceValue >= distanceGoal }

    var body: some View {
        Gauge(value: progress, in: 0...1) {
        } currentValueLabel: {
            Text(String(format: "%.1f", distanceValue))
                .font(.system(size: 12, weight: .bold, design: .rounded))
        }
        .gaugeStyle(.accessoryCircularCapacity)
        .tint(Gradient(colors: goalReached ? [.yellow, .orange] : [.teal, .mint]))
    }
}

struct LockScreenDistanceRectangularView: View {
    var entry: SimpleEntry

    private var distanceValue: Double {
        entry.usesMetric ? entry.distance * 0.001 : entry.distance * 0.000621371
    }

    private var unitLabel: String {
        entry.usesMetric ? "km" : "mi"
    }

    private var distanceGoal: Double {
        entry.usesMetric ? 8.0 : 5.0
    }

    private var progress: Double {
        min(distanceValue / distanceGoal, 1.0)
    }

    private var goalReached: Bool { distanceValue >= distanceGoal }

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 4) {
                Image(systemName: "location.fill")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.teal)
                Text(String(format: "%.2f", distanceValue))
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                Text(unitLabel)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
                Text("/ \(Int(distanceGoal))\(unitLabel)")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.secondary)
            }

            Gauge(value: progress, in: 0...1) {
                EmptyView()
            }
            .gaugeStyle(.accessoryLinearCapacity)
            .tint(Gradient(colors: goalReached ? [.yellow, .orange] : [.teal, .mint]))
        }
    }
}

struct LockScreenDistanceInlineView: View {
    var entry: SimpleEntry

    private var distanceValue: Double {
        entry.usesMetric ? entry.distance * 0.001 : entry.distance * 0.000621371
    }

    private var unitLabel: String {
        entry.usesMetric ? "km" : "mi"
    }

    var body: some View {
        Label {
            Text(String(format: "%.2f %@", distanceValue, unitLabel))
        } icon: {
            Image(systemName: "location.fill")
        }
    }
}

#endif

// MARK: - Watch Views (Steps)

#if os(watchOS)

// MARK: - Formatting Helpers (watchOS)

/// Format remaining steps with commas for "to go" display
private func formatRemainingSteps(_ entry: SimpleEntry) -> String {
    let remaining = max(0, entry.goal - entry.steps)
    let formatter = NumberFormatter()
    formatter.numberStyle = .decimal
    return formatter.string(from: NSNumber(value: remaining)) ?? "\(remaining)"
}

/// Format bonus steps (steps over goal)
private func formatBonusSteps(_ entry: SimpleEntry) -> String {
    let bonus = max(0, entry.steps - entry.goal)
    let formatter = NumberFormatter()
    formatter.numberStyle = .decimal
    return "+\(formatter.string(from: NSNumber(value: bonus)) ?? "\(bonus)")"
}

/// Format compact (e.g., "2.5k") for small spaces
private func formatCompactStepsRemaining(_ value: Int) -> String {
    if value >= 10000 {
        return String(format: "%.0fk", Double(value) / 1000)
    } else if value >= 1000 {
        return String(format: "%.1fk", Double(value) / 1000)
    }
    return "\(value)"
}

/// Format steps with full numbers (commas) for complications
/// Returns (formattedString, fontSize) tuple for dynamic sizing
private func formatFullSteps(_ value: Int, baseSize: CGFloat) -> (String, CGFloat) {
    // 100,000+ edge case: abbreviate with one decimal
    if value >= 100000 {
        let thousands = Double(value) / 1000.0
        return (String(format: "%.1fK", thousands), baseSize * 0.7)
    }

    // Format with commas
    let formatter = NumberFormatter()
    formatter.numberStyle = .decimal
    let formatted = formatter.string(from: NSNumber(value: value)) ?? "\(value)"

    // Dynamic font sizing based on digit count
    let fontSize: CGFloat
    switch value {
    case 0..<1000:
        fontSize = baseSize           // "847" - 3 chars, large
    case 1000..<10000:
        fontSize = baseSize * 0.85    // "8,472" - 5 chars, medium
    case 10000..<100000:
        fontSize = baseSize * 0.7     // "12,847" - 6 chars, small
    default:
        fontSize = baseSize * 0.6     // Fallback
    }

    return (formatted, fontSize)
}

/// Brand progress ring gradient for watchOS (teal→cyan→blue→teal)
private var watchBrandGradient: AngularGradient {
    AngularGradient(
        colors: [.teal, .cyan, .blue, .teal],
        center: .center,
        startAngle: .degrees(-90),
        endAngle: .degrees(270)
    )
}

/// Premium thick-stroke gradient for Ultra display
/// Deeper, richer colors for high-brightness OLED
private var ultraPremiumGradient: AngularGradient {
    AngularGradient(
        colors: [
            Color(red: 0.0, green: 0.7, blue: 0.65),   // Deep Teal
            Color(red: 0.0, green: 0.85, blue: 0.9),  // Bright Cyan
            Color(red: 0.15, green: 0.5, blue: 0.95), // Rich Blue
            Color(red: 0.0, green: 0.7, blue: 0.65)   // Back to Teal
        ],
        center: .center,
        startAngle: .degrees(-90),
        endAngle: .degrees(270)
    )
}

/// Goal reached celebration gradient (gold/orange)
private var ultraCelebrationGradient: AngularGradient {
    AngularGradient(
        colors: [
            Color(red: 1.0, green: 0.85, blue: 0.2),  // Gold
            Color(red: 1.0, green: 0.6, blue: 0.1),   // Orange
            Color(red: 1.0, green: 0.85, blue: 0.2)   // Gold
        ],
        center: .center,
        startAngle: .degrees(-90),
        endAngle: .degrees(270)
    )
}

// MARK: - Premium Thick-Stroke Circular Complication
// Designed for Apple Watch Ultra 3 high-brightness display
// Shows full step count with commas (e.g., 10,000) for clarity

struct StepsCircularView: View {
    var entry: SimpleEntry
    var progress: Double { Double(entry.steps) / Double(entry.goal) }

    /// Reduced stroke width to make room for full step count
    private let strokeWidth: CGFloat = 5.0

    /// Inner padding to prevent text overlap with ring
    private let innerPadding: CGFloat = 2.0

    var body: some View {
        GeometryReader { geometry in
            let size = min(geometry.size.width, geometry.size.height)
            let ringDiameter = size - strokeWidth

            ZStack {
                // MARK: - Background Track Ring
                // Subtle dark track for contrast
                Circle()
                    .stroke(
                        Color.white.opacity(0.12),
                        style: StrokeStyle(lineWidth: strokeWidth, lineCap: .round)
                    )
                    .frame(width: ringDiameter, height: ringDiameter)

                // MARK: - Progress Ring (Bold Stroke)
                Circle()
                    .trim(from: 0.0, to: CGFloat(min(progress, 1.0)))
                    .stroke(
                        progress >= 1.0 ? ultraCelebrationGradient : ultraPremiumGradient,
                        style: StrokeStyle(lineWidth: strokeWidth, lineCap: .round)
                    )
                    .frame(width: ringDiameter, height: ringDiameter)
                    .rotationEffect(.degrees(-90))

                // MARK: - Overlap Ring (>100% Progress)
                if progress > 1.0 {
                    Circle()
                        .trim(from: 0.0, to: CGFloat(progress - 1.0))
                        .stroke(
                            ultraCelebrationGradient,
                            style: StrokeStyle(lineWidth: strokeWidth, lineCap: .round)
                        )
                        .frame(width: ringDiameter, height: ringDiameter)
                        .rotationEffect(.degrees(-90))
                }

                // MARK: - Center Content
                VStack(spacing: 0) {
                    if progress >= 1.0 {
                        // Goal reached: trophy + full step count
                        Image(systemName: "trophy.fill")
                            .font(.system(size: 7, weight: .bold))
                            .foregroundStyle(.yellow)
                    }
                    // Always show full step count
                    let (stepsText, stepsSize) = formatFullSteps(entry.steps, baseSize: 11)
                    Text(stepsText)
                        .font(.system(size: stepsSize, weight: .heavy, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(progress >= 1.0 ? .yellow : .white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                }
                .frame(width: ringDiameter - strokeWidth - innerPadding * 2)
            }
            .frame(width: size, height: size)
        }
    }
}

// MARK: - Premium Rectangular Complication (Motivational)
// Shows "X to go" or "Goal hit!" with action hint

struct StepsRectangularView: View {
    var entry: SimpleEntry
    var progress: Double { Double(entry.steps) / Double(entry.goal) }

    /// Thick progress bar height for legibility
    private let barHeight: CGFloat = 7.0

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            // Row 1: Icon + total steps
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                if progress >= 1.0 {
                    Image(systemName: "trophy.fill")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.yellow)
                } else {
                    Image(systemName: "figure.walk")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.cyan)
                }
                // Always show total steps
                Text(entry.steps.formatted())
                    .font(.system(size: 24, weight: .heavy, design: .rounded))
                    .minimumScaleFactor(0.7)
                    .foregroundStyle(progress >= 1.0 ? .yellow : .white)
                Text("steps")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.secondary)
                Spacer()
            }

            // Row 2: Thick progress bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // Track
                    RoundedRectangle(cornerRadius: barHeight / 2)
                        .fill(Color.white.opacity(0.12))
                        .frame(height: barHeight)

                    // Progress fill with gradient
                    RoundedRectangle(cornerRadius: barHeight / 2)
                        .fill(
                            LinearGradient(
                                colors: progress >= 1.0
                                    ? [.yellow, .orange]
                                    : [.teal, .cyan, .blue],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: geometry.size.width * min(progress, 1.0), height: barHeight)
                }
            }
            .frame(height: barHeight)

            // Row 3: Action hint
            HStack(spacing: 4) {
                Image(systemName: "figure.walk")
                    .font(.system(size: 9, weight: .semibold))
                Text("Tap to walk")
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
            }
            .foregroundStyle(.cyan)
        }
    }
}

// MARK: - Inline Complication (Motivational)
// Shows "X to go" or trophy + bonus

struct StepsInlineView: View {
    var entry: SimpleEntry
    var progress: Double { Double(entry.steps) / Double(entry.goal) }

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: progress >= 1.0 ? "trophy.fill" : "figure.walk")
                .foregroundStyle(progress >= 1.0 ? .yellow : .cyan)
            Text("\(entry.steps.formatted()) steps")
                .fontWeight(.bold)
                .monospacedDigit()
        }
    }
}

// MARK: - Premium Corner Complication
// Thick curved progress gauge for corner placement

struct StepsCornerView: View {
    var entry: SimpleEntry
    var progress: Double { Double(entry.steps) / Double(entry.goal) }

    var body: some View {
        ZStack {
            if progress >= 1.0 {
                // Goal reached: trophy icon
                Image(systemName: "trophy.fill")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.yellow)
            } else {
                // Show total steps
                let (stepsText, stepsSize) = formatFullSteps(entry.steps, baseSize: 11)
                Text(stepsText)
                    .font(.system(size: stepsSize, weight: .heavy, design: .rounded))
                    .monospacedDigit()
                    .minimumScaleFactor(0.5)
                    .foregroundStyle(.white)
            }
        }
        .widgetLabel {
            // The curved gauge around the corner
            Gauge(value: min(progress, 1.0)) {
                // Empty - we show the value in the main view
            }
            .gaugeStyle(.accessoryLinearCapacity)
            .tint(
                Gradient(colors: progress >= 1.0
                    ? [.yellow, .orange]
                    : [.teal, .cyan, .blue])
            )
        }
    }
}

// MARK: - Extra Large Complication (Ultra-Optimized)
// Full-size automotive-grade dial for Apple Watch Ultra displays

struct StepsExtraLargeView: View {
    var entry: SimpleEntry
    var progress: Double { Double(entry.steps) / Double(entry.goal) }

    /// Ultra-thick stroke for extra large display
    private let strokeWidth: CGFloat = 10.0

    var body: some View {
        GeometryReader { geometry in
            let size = min(geometry.size.width, geometry.size.height)
            let ringDiameter = size - strokeWidth - 8

            ZStack {
                // MARK: - Background Track
                Circle()
                    .stroke(
                        Color.white.opacity(0.1),
                        style: StrokeStyle(lineWidth: strokeWidth, lineCap: .round)
                    )
                    .frame(width: ringDiameter, height: ringDiameter)

                // MARK: - Progress Ring (Ultra Thick)
                Circle()
                    .trim(from: 0.0, to: CGFloat(min(progress, 1.0)))
                    .stroke(
                        progress >= 1.0 ? ultraCelebrationGradient : ultraPremiumGradient,
                        style: StrokeStyle(lineWidth: strokeWidth, lineCap: .round)
                    )
                    .frame(width: ringDiameter, height: ringDiameter)
                    .rotationEffect(.degrees(-90))

                // MARK: - Overlap Ring
                if progress > 1.0 {
                    Circle()
                        .trim(from: 0.0, to: CGFloat(min(progress - 1.0, 1.0)))
                        .stroke(
                            ultraCelebrationGradient,
                            style: StrokeStyle(lineWidth: strokeWidth, lineCap: .round)
                        )
                        .frame(width: ringDiameter, height: ringDiameter)
                        .rotationEffect(.degrees(-90))
                }

                // MARK: - Center Content Stack
                VStack(spacing: 2) {
                    if progress >= 1.0 {
                        Image(systemName: "trophy.fill")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(.yellow)
                    } else {
                        Image(systemName: "figure.walk")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(.cyan)
                    }
                    // Always show total steps
                    Text(entry.steps.formatted())
                        .font(.system(size: 26, weight: .heavy, design: .rounded))
                        .minimumScaleFactor(0.5)
                        .lineLimit(1)
                        .foregroundStyle(progress >= 1.0 ? .yellow : .white)
                    Text("steps")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.secondary)
                    if progress < 1.0 {
                        Text("Tap to walk")
                            .font(.system(size: 9, weight: .medium))
                            .foregroundStyle(.cyan.opacity(0.8))
                    }
                }
            }
            .frame(width: size, height: size)
        }
    }
}
#endif

// MARK: - Watch Views (Distance) - Premium Ultra-Optimized

#if os(watchOS)

// MARK: - Distance Circular Complication (Supports Miles/Kilometers)

struct DistanceCircularView: View {
    var entry: SimpleEntry
    var useMiles: Bool = true

    private var distanceValue: Double {
        useMiles ? entry.distance * 0.000621371 : entry.distance * 0.001
    }

    private var distanceGoal: Double {
        useMiles ? 5.0 : 8.0  // 5 miles or 8 km
    }

    private var unitLabel: String {
        useMiles ? "mi" : "km"
    }

    private var progress: Double { distanceValue / distanceGoal }

    private let strokeWidth: CGFloat = 5.0
    private let innerPadding: CGFloat = 2.0

    var body: some View {
        GeometryReader { geometry in
            let size = min(geometry.size.width, geometry.size.height)
            let ringDiameter = size - strokeWidth

            ZStack {
                Circle()
                    .stroke(
                        Color.white.opacity(0.12),
                        style: StrokeStyle(lineWidth: strokeWidth, lineCap: .round)
                    )
                    .frame(width: ringDiameter, height: ringDiameter)

                Circle()
                    .trim(from: 0.0, to: CGFloat(min(progress, 1.0)))
                    .stroke(
                        progress >= 1.0 ? ultraCelebrationGradient : ultraPremiumGradient,
                        style: StrokeStyle(lineWidth: strokeWidth, lineCap: .round)
                    )
                    .frame(width: ringDiameter, height: ringDiameter)
                    .rotationEffect(.degrees(-90))

                if progress > 1.0 {
                    Circle()
                        .trim(from: 0.0, to: CGFloat(progress - 1.0))
                        .stroke(
                            ultraCelebrationGradient,
                            style: StrokeStyle(lineWidth: strokeWidth, lineCap: .round)
                        )
                        .frame(width: ringDiameter, height: ringDiameter)
                        .rotationEffect(.degrees(-90))
                }

                VStack(spacing: 0) {
                    if progress >= 1.0 {
                        Image(systemName: "trophy.fill")
                            .font(.system(size: 7, weight: .bold))
                            .foregroundStyle(.yellow)
                    }
                    let (distanceText, distanceSize) = formatDistance(distanceValue, baseSize: 11)
                    Text(distanceText)
                        .font(.system(size: distanceSize, weight: .heavy, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(progress >= 1.0 ? .yellow : .white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)

                    Text(unitLabel)
                        .font(.system(size: 7, weight: .semibold))
                        .foregroundStyle(progress >= 1.0 ? .yellow.opacity(0.8) : .teal)
                }
                .frame(width: ringDiameter - strokeWidth - innerPadding * 2)
            }
            .frame(width: size, height: size)
        }
    }

    private func formatDistance(_ value: Double, baseSize: CGFloat) -> (String, CGFloat) {
        let formatted = String(format: "%.1f", value)
        let fontSize: CGFloat
        switch value {
        case 0..<10:
            fontSize = baseSize
        case 10..<100:
            fontSize = baseSize * 0.85
        default:
            fontSize = baseSize * 0.7
        }
        return (formatted, fontSize)
    }
}

// MARK: - Distance Rectangular Complication (Supports Miles/Kilometers)

struct DistanceRectangularView: View {
    var entry: SimpleEntry
    var useMiles: Bool = true

    private var distanceValue: Double {
        useMiles ? entry.distance * 0.000621371 : entry.distance * 0.001
    }

    private var distanceGoal: Double {
        useMiles ? 5.0 : 8.0
    }

    private var unitLabel: String {
        useMiles ? "mi" : "km"
    }

    private var progress: Double { distanceValue / distanceGoal }

    private let barHeight: CGFloat = 7.0

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                if progress >= 1.0 {
                    Image(systemName: "trophy.fill")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.yellow)
                } else {
                    Image(systemName: "map.fill")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.cyan)
                }
                Text(String(format: "%.2f", distanceValue))
                    .font(.system(size: 24, weight: .heavy, design: .rounded))
                    .minimumScaleFactor(0.7)
                    .foregroundStyle(progress >= 1.0 ? .yellow : .white)
                Text(unitLabel)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.secondary)
                Spacer()
            }

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: barHeight / 2)
                        .fill(Color.white.opacity(0.12))
                        .frame(height: barHeight)

                    RoundedRectangle(cornerRadius: barHeight / 2)
                        .fill(
                            LinearGradient(
                                colors: progress >= 1.0
                                    ? [.yellow, .orange]
                                    : [.teal, .cyan, .blue],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: geometry.size.width * min(progress, 1.0), height: barHeight)
                }
            }
            .frame(height: barHeight)

            HStack(spacing: 4) {
                Image(systemName: "figure.walk")
                    .font(.system(size: 9, weight: .semibold))
                Text("Tap to walk")
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
            }
            .foregroundStyle(.cyan)
        }
    }
}

// MARK: - Distance Inline Complication (Supports Miles/Kilometers)

struct DistanceInlineView: View {
    var entry: SimpleEntry
    var useMiles: Bool = true

    private var distanceValue: Double {
        useMiles ? entry.distance * 0.000621371 : entry.distance * 0.001
    }

    private var distanceGoal: Double {
        useMiles ? 5.0 : 8.0
    }

    private var unitLabel: String {
        useMiles ? "mi" : "km"
    }

    private var progress: Double { distanceValue / distanceGoal }

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: progress >= 1.0 ? "trophy.fill" : "location.fill")
                .foregroundStyle(progress >= 1.0 ? .yellow : .cyan)
            Text(String(format: "%.2f %@", distanceValue, unitLabel))
                .fontWeight(.bold)
                .monospacedDigit()
        }
    }
}

// MARK: - Distance Corner Complication (Supports Miles/Kilometers)

struct DistanceCornerView: View {
    var entry: SimpleEntry
    var useMiles: Bool = true

    private var distanceValue: Double {
        useMiles ? entry.distance * 0.000621371 : entry.distance * 0.001
    }

    private var distanceGoal: Double {
        useMiles ? 5.0 : 8.0
    }

    private var progress: Double { distanceValue / distanceGoal }

    var body: some View {
        ZStack {
            if progress >= 1.0 {
                Image(systemName: "trophy.fill")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.yellow)
            } else {
                Text(String(format: "%.1f", distanceValue))
                    .font(.system(size: 11, weight: .heavy, design: .rounded))
                    .monospacedDigit()
                    .minimumScaleFactor(0.5)
                    .foregroundStyle(.white)
            }
        }
        .widgetLabel {
            Gauge(value: min(progress, 1.0)) {
            }
            .gaugeStyle(.accessoryLinearCapacity)
            .tint(
                Gradient(colors: progress >= 1.0
                    ? [.yellow, .orange]
                    : [.teal, .cyan, .blue])
            )
        }
    }
}

// MARK: - Distance Extra Large Complication (Supports Miles/Kilometers)

struct DistanceExtraLargeView: View {
    var entry: SimpleEntry
    var useMiles: Bool = true

    private var distanceValue: Double {
        useMiles ? entry.distance * 0.000621371 : entry.distance * 0.001
    }

    private var distanceGoal: Double {
        useMiles ? 5.0 : 8.0
    }

    private var unitLabel: String {
        useMiles ? "miles" : "kilometers"
    }

    private var progress: Double { distanceValue / distanceGoal }

    private let strokeWidth: CGFloat = 10.0

    var body: some View {
        GeometryReader { geometry in
            let size = min(geometry.size.width, geometry.size.height)
            let ringDiameter = size - strokeWidth - 8

            ZStack {
                Circle()
                    .stroke(
                        Color.white.opacity(0.1),
                        style: StrokeStyle(lineWidth: strokeWidth, lineCap: .round)
                    )
                    .frame(width: ringDiameter, height: ringDiameter)

                Circle()
                    .trim(from: 0.0, to: CGFloat(min(progress, 1.0)))
                    .stroke(
                        progress >= 1.0 ? ultraCelebrationGradient : ultraPremiumGradient,
                        style: StrokeStyle(lineWidth: strokeWidth, lineCap: .round)
                    )
                    .frame(width: ringDiameter, height: ringDiameter)
                    .rotationEffect(.degrees(-90))

                if progress > 1.0 {
                    Circle()
                        .trim(from: 0.0, to: CGFloat(min(progress - 1.0, 1.0)))
                        .stroke(
                            ultraCelebrationGradient,
                            style: StrokeStyle(lineWidth: strokeWidth, lineCap: .round)
                        )
                        .frame(width: ringDiameter, height: ringDiameter)
                        .rotationEffect(.degrees(-90))
                }

                VStack(spacing: 2) {
                    if progress >= 1.0 {
                        Image(systemName: "trophy.fill")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(.yellow)
                    } else {
                        Image(systemName: "map.fill")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(.cyan)
                    }
                    Text(String(format: "%.2f", distanceValue))
                        .font(.system(size: 26, weight: .heavy, design: .rounded))
                        .minimumScaleFactor(0.5)
                        .lineLimit(1)
                        .foregroundStyle(progress >= 1.0 ? .yellow : .white)
                    Text(unitLabel)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.secondary)
                    if progress < 1.0 {
                        Text("Tap to walk")
                            .font(.system(size: 9, weight: .medium))
                            .foregroundStyle(.cyan.opacity(0.8))
                    }
                }
            }
            .frame(width: size, height: size)
        }
    }
}

// MARK: - Steps Remaining Circular Complication (watchOS)
// Shows remaining steps to reach goal, or celebration when goal hit

struct StepsRemainingCircularView: View {
    var entry: SimpleEntry
    var progress: Double { Double(entry.steps) / Double(entry.goal) }
    var remaining: Int { max(0, entry.goal - entry.steps) }

    /// Stroke width matches Steps (5.0)
    private let strokeWidth: CGFloat = 5.0

    /// Inner padding to prevent text overlap with ring
    private let innerPadding: CGFloat = 2.0

    var body: some View {
        GeometryReader { geometry in
            let size = min(geometry.size.width, geometry.size.height)
            let ringDiameter = size - strokeWidth

            ZStack {
                // MARK: - Background Track Ring
                Circle()
                    .stroke(
                        Color.white.opacity(0.12),
                        style: StrokeStyle(lineWidth: strokeWidth, lineCap: .round)
                    )
                    .frame(width: ringDiameter, height: ringDiameter)

                // MARK: - Progress Ring (Bold Stroke)
                Circle()
                    .trim(from: 0.0, to: CGFloat(min(progress, 1.0)))
                    .stroke(
                        progress >= 1.0 ? ultraCelebrationGradient : ultraPremiumGradient,
                        style: StrokeStyle(lineWidth: strokeWidth, lineCap: .round)
                    )
                    .frame(width: ringDiameter, height: ringDiameter)
                    .rotationEffect(.degrees(-90))

                // MARK: - Overlap Ring (>100% Progress)
                if progress > 1.0 {
                    Circle()
                        .trim(from: 0.0, to: CGFloat(progress - 1.0))
                        .stroke(
                            ultraCelebrationGradient,
                            style: StrokeStyle(lineWidth: strokeWidth, lineCap: .round)
                        )
                        .frame(width: ringDiameter, height: ringDiameter)
                        .rotationEffect(.degrees(-90))
                }

                // MARK: - Center Content
                VStack(spacing: 0) {
                    if progress >= 1.0 {
                        // Goal reached: trophy + checkmark
                        Image(systemName: "trophy.fill")
                            .font(.system(size: 7, weight: .bold))
                            .foregroundStyle(.yellow)
                        Image(systemName: "checkmark")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(.yellow)
                    } else {
                        // Show remaining steps
                        let (remainingText, remainingSize) = formatFullSteps(remaining, baseSize: 11)
                        Text(remainingText)
                            .font(.system(size: remainingSize, weight: .heavy, design: .rounded))
                            .monospacedDigit()
                            .foregroundStyle(.white)
                            .lineLimit(1)
                            .minimumScaleFactor(0.5)
                    }
                }
                .frame(width: ringDiameter - strokeWidth - innerPadding * 2)
            }
            .frame(width: size, height: size)
        }
    }
}

// MARK: - Steps Remaining Rectangular Complication (watchOS)

struct StepsRemainingRectangularView: View {
    var entry: SimpleEntry
    var progress: Double { Double(entry.steps) / Double(entry.goal) }
    var remaining: Int { max(0, entry.goal - entry.steps) }

    /// Thick progress bar height for legibility
    private let barHeight: CGFloat = 7.0

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            // Row 1: Icon + remaining or goal hit
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                if progress >= 1.0 {
                    Image(systemName: "trophy.fill")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.yellow)
                    Text("Goal hit!")
                        .font(.system(size: 24, weight: .heavy, design: .rounded))
                        .minimumScaleFactor(0.7)
                        .foregroundStyle(.yellow)
                } else {
                    Image(systemName: "figure.walk")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.cyan)
                    Text(remaining.formatted())
                        .font(.system(size: 24, weight: .heavy, design: .rounded))
                        .minimumScaleFactor(0.7)
                        .foregroundStyle(.white)
                    Text("to go")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }

            // Row 2: Thick progress bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // Track
                    RoundedRectangle(cornerRadius: barHeight / 2)
                        .fill(Color.white.opacity(0.12))
                        .frame(height: barHeight)

                    // Progress fill with gradient
                    RoundedRectangle(cornerRadius: barHeight / 2)
                        .fill(
                            LinearGradient(
                                colors: progress >= 1.0
                                    ? [.yellow, .orange]
                                    : [.teal, .cyan, .blue],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: geometry.size.width * min(progress, 1.0), height: barHeight)
                }
            }
            .frame(height: barHeight)

            // Row 3: Action hint
            HStack(spacing: 4) {
                Image(systemName: "figure.walk")
                    .font(.system(size: 9, weight: .semibold))
                Text("Tap to walk")
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
            }
            .foregroundStyle(.cyan)
        }
    }
}

// MARK: - Steps Remaining Inline Complication (watchOS)

struct StepsRemainingInlineView: View {
    var entry: SimpleEntry
    var progress: Double { Double(entry.steps) / Double(entry.goal) }
    var remaining: Int { max(0, entry.goal - entry.steps) }

    var body: some View {
        HStack(spacing: 4) {
            if progress >= 1.0 {
                Image(systemName: "trophy.fill")
                    .foregroundStyle(.yellow)
                Text("Done!")
                    .fontWeight(.bold)
            } else {
                Image(systemName: "figure.walk")
                    .foregroundStyle(.cyan)
                Text("\(remaining.formatted()) to go")
                    .fontWeight(.bold)
                    .monospacedDigit()
            }
        }
    }
}

// MARK: - Steps Remaining Corner Complication (watchOS)

struct StepsRemainingCornerView: View {
    var entry: SimpleEntry
    var progress: Double { Double(entry.steps) / Double(entry.goal) }
    var remaining: Int { max(0, entry.goal - entry.steps) }

    var body: some View {
        ZStack {
            if progress >= 1.0 {
                // Goal reached: trophy icon
                Image(systemName: "trophy.fill")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.yellow)
            } else {
                // Show remaining steps
                let (remainingText, remainingSize) = formatFullSteps(remaining, baseSize: 11)
                Text(remainingText)
                    .font(.system(size: remainingSize, weight: .heavy, design: .rounded))
                    .monospacedDigit()
                    .minimumScaleFactor(0.5)
                    .foregroundStyle(.white)
            }
        }
        .widgetLabel {
            // The curved gauge around the corner
            Gauge(value: min(progress, 1.0)) {
                // Empty - we show the value in the main view
            }
            .gaugeStyle(.accessoryLinearCapacity)
            .tint(
                Gradient(colors: progress >= 1.0
                    ? [.yellow, .orange]
                    : [.teal, .cyan, .blue])
            )
        }
    }
}

// MARK: - Steps Remaining Extra Large Complication (watchOS)

struct StepsRemainingExtraLargeView: View {
    var entry: SimpleEntry
    var progress: Double { Double(entry.steps) / Double(entry.goal) }
    var remaining: Int { max(0, entry.goal - entry.steps) }

    /// Ultra-thick stroke for extra large display
    private let strokeWidth: CGFloat = 10.0

    var body: some View {
        GeometryReader { geometry in
            let size = min(geometry.size.width, geometry.size.height)
            let ringDiameter = size - strokeWidth - 8

            ZStack {
                // MARK: - Background Track
                Circle()
                    .stroke(
                        Color.white.opacity(0.1),
                        style: StrokeStyle(lineWidth: strokeWidth, lineCap: .round)
                    )
                    .frame(width: ringDiameter, height: ringDiameter)

                // MARK: - Progress Ring (Ultra Thick)
                Circle()
                    .trim(from: 0.0, to: CGFloat(min(progress, 1.0)))
                    .stroke(
                        progress >= 1.0 ? ultraCelebrationGradient : ultraPremiumGradient,
                        style: StrokeStyle(lineWidth: strokeWidth, lineCap: .round)
                    )
                    .frame(width: ringDiameter, height: ringDiameter)
                    .rotationEffect(.degrees(-90))

                // MARK: - Overlap Ring
                if progress > 1.0 {
                    Circle()
                        .trim(from: 0.0, to: CGFloat(min(progress - 1.0, 1.0)))
                        .stroke(
                            ultraCelebrationGradient,
                            style: StrokeStyle(lineWidth: strokeWidth, lineCap: .round)
                        )
                        .frame(width: ringDiameter, height: ringDiameter)
                        .rotationEffect(.degrees(-90))
                }

                // MARK: - Center Content Stack
                VStack(spacing: 2) {
                    if progress >= 1.0 {
                        Image(systemName: "trophy.fill")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(.yellow)
                        Text("Done!")
                            .font(.system(size: 20, weight: .heavy, design: .rounded))
                            .foregroundStyle(.yellow)
                    } else {
                        Image(systemName: "figure.walk")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(.cyan)
                        // Show remaining
                        Text(remaining.formatted())
                            .font(.system(size: 26, weight: .heavy, design: .rounded))
                            .minimumScaleFactor(0.5)
                            .lineLimit(1)
                            .foregroundStyle(.white)
                        Text("to go")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(.secondary)
                        Text("Tap to walk")
                            .font(.system(size: 9, weight: .medium))
                            .foregroundStyle(.cyan.opacity(0.8))
                    }
                }
            }
            .frame(width: size, height: size)
        }
    }
}

// MARK: - Steps Remaining Watch Widget View Router

struct StepsRemainingWatchWidgetView: View {
    var entry: SimpleEntry
    @Environment(\.widgetFamily) var family

    var body: some View {
        switch family {
        case .accessoryCircular:
            StepsRemainingCircularView(entry: entry)
        case .accessoryRectangular:
            StepsRemainingRectangularView(entry: entry)
        case .accessoryInline:
            StepsRemainingInlineView(entry: entry)
        case .accessoryCorner:
            StepsRemainingCornerView(entry: entry)
        @unknown default:
            StepsRemainingCircularView(entry: entry)
        }
    }
}
#endif

// MARK: - Steps Widget

struct SimpleWalkStepsWidget: Widget {
    // Keep this ID for existing users
    let kind: String = "SimpleWalkWidgets"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            StepsWidgetView(entry: entry)
        }
        .configurationDisplayName("Steps")
        .description("Daily step count with goal progress.")
        #if os(watchOS)
        .supportedFamilies([.accessoryCircular, .accessoryRectangular, .accessoryInline, .accessoryCorner])
        #else
        .supportedFamilies([
            .accessoryCircular,    // Lock Screen
            .accessoryRectangular, // Lock Screen
            .accessoryInline       // Lock Screen
        ])
        #endif
    }
}


// MARK: - Steps Remaining Watch Widget (watchOS only)

#if os(watchOS)
struct StepsRemainingWatchWidget: Widget {
    let kind: String = "StepsRemainingWatchWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            StepsRemainingWatchWidgetView(entry: entry)
        }
        .configurationDisplayName("Steps Remaining")
        .description("Steps left to reach your daily goal.")
        .supportedFamilies([.accessoryCircular, .accessoryRectangular, .accessoryInline, .accessoryCorner])
    }
}
#endif

// MARK: - Distance Widget (Unified - Reads User Preference)

struct DistanceWidget: Widget {
    let kind: String = "DistanceWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            DistanceWidgetView(entry: entry)
        }
        .configurationDisplayName("Distance")
        .description("Distance walked today with progress.")
        #if os(watchOS)
        .supportedFamilies([.accessoryCircular, .accessoryRectangular, .accessoryInline, .accessoryCorner])
        #else
        .supportedFamilies([
            .accessoryCircular,    // Lock Screen
            .accessoryRectangular, // Lock Screen
            .accessoryInline       // Lock Screen
        ])
        #endif
    }
}
