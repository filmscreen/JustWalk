//
//  WalkNotificationManager.swift
//  JustWalk
//
//  Smart daily walk nudge scheduling
//

import Foundation
import UserNotifications

struct WalkNotificationContent {
    let title: String
    let body: String
    let walkType: WalkMode?
}

final class WalkNotificationManager {
    static let shared = WalkNotificationManager()

    static let notificationIdentifier = "walk_reminder"
    static let notificationCategory = "WALK_REMINDER"
    static let notificationActionKey = "walk_notification_action"
    static let notificationTypeKey = "walk_notification_type"
    static let pendingActionKey = "walk_notification_pending_action"

    private let center = UNUserNotificationCenter.current()
    private let persistence = PersistenceManager.shared
    private let patternManager = PatternManager.shared
    private let calendar = Calendar.current
    private let defaults = UserDefaults.standard

    private var state: WalkNotificationState {
        didSet { saveState() }
    }

    private init() {
        state = Self.loadState(from: defaults)
        defaults.register(defaults: [
            "walk_notifications_enabled": true,
            "walk_notifications_smart_timing": true
        ])
    }

    // MARK: - Public Settings

    var notificationsEnabled: Bool {
        get { state.notificationsEnabled }
        set { state.notificationsEnabled = newValue }
    }

    var smartTimingEnabled: Bool {
        get { state.smartTimingEnabled }
        set { state.smartTimingEnabled = newValue }
    }

    var preferredTime: Date? {
        get { state.userPreferredTime }
        set { state.userPreferredTime = newValue }
    }

    // MARK: - Scheduling

    func scheduleNotificationIfNeeded(force: Bool = false) {
        Task {
            await scheduleNotificationIfNeededAsync(force: force)
        }
    }

    private func scheduleNotificationIfNeededAsync(force: Bool) async {
        let settings = await center.notificationSettings()
        let allowed = settings.authorizationStatus == .authorized ||
            settings.authorizationStatus == .provisional ||
            settings.authorizationStatus == .ephemeral

        let steps = HealthKitManager.shared.todaySteps
        let goal = persistence.loadProfile().dailyStepGoal
        let now = Date()

        guard shouldScheduleToday(
            now: now,
            goal: goal,
            currentSteps: steps,
            notificationsAllowed: allowed,
            state: state,
            force: force,
            calendar: calendar
        ) else {
            cancelPendingNotifications()
            return
        }

        let stepsRemaining = max(0, goal - steps)
        let targetDate = computeOptimalNotificationTime(
            now: now,
            stepsRemaining: stepsRemaining,
            typicalHour: patternManager.cachedTypicalHour,
            preferredTime: state.userPreferredTime,
            smartTimingEnabled: state.smartTimingEnabled,
            calendar: calendar
        )

        guard let scheduled = targetDate, scheduled > now else {
            cancelPendingNotifications()
            return
        }

        let content = selectNotificationContent(
            stepsRemaining: stepsRemaining,
            currentStreak: StreakManager.shared.streakData.currentStreak,
            typicalWalkHour: patternManager.cachedTypicalHour,
            preferredWalkType: walkTypeFromPattern()
        )

        let request = buildNotificationRequest(content: content, fireAt: scheduled)
        cancelPendingNotifications()
        try? await center.add(request)

        state.lastNotificationScheduledDate = now
    }

    func shouldScheduleToday(
        now: Date,
        goal: Int,
        currentSteps: Int,
        notificationsAllowed: Bool,
        state: WalkNotificationState,
        force: Bool,
        calendar: Calendar
    ) -> Bool {
        guard notificationsAllowed else { return false }
        guard state.notificationsEnabled else { return false }
        guard goal > 0 else { return false }

        let goalMet = currentSteps >= goal
        guard !goalMet else { return false }

        if let lastSent = state.lastNotificationSentDate, calendar.isDateInToday(lastSent) {
            return false
        }
        if !force, let lastScheduled = state.lastNotificationScheduledDate, calendar.isDateInToday(lastScheduled) {
            return false
        }

        let nowHour = calendar.component(.hour, from: now)
        if nowHour > 21 {
            return false
        }

        return true
    }

    func computeOptimalNotificationTime(
        now: Date,
        stepsRemaining: Int,
        typicalHour: Int?,
        preferredTime: Date?,
        smartTimingEnabled: Bool,
        calendar: Calendar
    ) -> Date? {
        let baseDate = calendar.startOfDay(for: now)

        if smartTimingEnabled, let hour = typicalHour {
            var minutes = (hour * 60) - 15
            minutes = max(minutes, 17 * 60)
            minutes = min(minutes, 21 * 60)
            return calendar.date(byAdding: .minute, value: minutes, to: baseDate)
        }

        if let preferredTime {
            let components = calendar.dateComponents([.hour, .minute], from: preferredTime)
            return calendar.date(bySettingHour: components.hour ?? 18, minute: components.minute ?? 0, second: 0, of: now)
        }

        let fallbackHour: Int
        let fallbackMinute: Int
        switch stepsRemaining {
        case 4001...:
            fallbackHour = 17; fallbackMinute = 30
        case 2000...4000:
            fallbackHour = 18; fallbackMinute = 30
        default:
            fallbackHour = 19; fallbackMinute = 30
        }
        return calendar.date(bySettingHour: fallbackHour, minute: fallbackMinute, second: 0, of: now)
    }

    // MARK: - Content Selection

    func selectNotificationContent(
        stepsRemaining: Int,
        currentStreak: Int,
        typicalWalkHour: Int?,
        preferredWalkType: WalkMode?
    ) -> WalkNotificationContent {
        let walkType = preferredWalkType ?? .postMeal

        // Pattern-based: mention their actual typical time
        if let hour = typicalWalkHour {
            let timeString = formatHourNaturally(hour)
            return WalkNotificationContent(
                title: "You often walk around \(timeString).",
                body: "Ready when you are.",
                walkType: walkType
            )
        }

        // Long streak protection (30+ days)
        if currentStreak >= 30 {
            return WalkNotificationContent(
                title: "Day \(currentStreak) is on the line.",
                body: "A short walk keeps it going.",
                walkType: walkType
            )
        }

        // Building streak (7+ days)
        if currentStreak >= 7 {
            return WalkNotificationContent(
                title: "\(currentStreak) days and counting.",
                body: "A quick walk keeps your streak alive.",
                walkType: walkType
            )
        }

        // Steps-based messaging
        switch stepsRemaining {
        case 0..<1000:
            return WalkNotificationContent(
                title: "You're almost there.",
                body: "Under 1,000 steps to go.",
                walkType: walkType
            )
        case 1000..<2500:
            return WalkNotificationContent(
                title: "A short walk closes it out.",
                body: "\(stepsRemaining.formatted()) steps left today.",
                walkType: walkType
            )
        case 2500..<4000:
            return WalkNotificationContent(
                title: "Good time for a walk.",
                body: "\(stepsRemaining.formatted()) steps to your goal.",
                walkType: walkType
            )
        default:
            return WalkNotificationContent(
                title: "Ready for a walk?",
                body: "Plenty of daylight left.",
                walkType: walkType
            )
        }
    }

    private func formatHourNaturally(_ hour: Int) -> String {
        switch hour {
        case 6: return "6am"
        case 7: return "7am"
        case 8: return "8am"
        case 9: return "9am"
        case 10: return "10am"
        case 11: return "11am"
        case 12: return "noon"
        case 13: return "1pm"
        case 14: return "2pm"
        case 15: return "3pm"
        case 16: return "4pm"
        case 17: return "5pm"
        case 18: return "6pm"
        case 19: return "7pm"
        case 20: return "8pm"
        case 21: return "9pm"
        default: return "\(hour > 12 ? hour - 12 : hour)\(hour >= 12 ? "pm" : "am")"
        }
    }

    // MARK: - Notification Handling

    func handleNotificationResponse(_ userInfo: [AnyHashable: Any]) {
        guard let action = userInfo[Self.notificationActionKey] as? String,
              action == "start_walk" else { return }

        let walkTypeRaw = userInfo[Self.notificationTypeKey] as? String
        let walkMode = WalkMode(rawValue: walkTypeRaw ?? "")
        let cardAction = cardActionForWalkMode(walkMode)

        defaults.set(cardAction.rawValue, forKey: Self.pendingActionKey)
        state.lastNotificationSentDate = Date()
        state.notificationTappedToday = true

        NotificationCenter.default.post(
            name: .walkNotificationAction,
            object: nil,
            userInfo: ["action": cardAction.rawValue]
        )
    }

    func markNotificationDeliveredIfNeeded(_ userInfo: [AnyHashable: Any]) {
        guard let action = userInfo[Self.notificationActionKey] as? String,
              action == "start_walk" else { return }
        state.lastNotificationSentDate = Date()
    }

    func cancelPendingNotifications() {
        center.removePendingNotificationRequests(withIdentifiers: [Self.notificationIdentifier])
    }

    // MARK: - Helpers

    private func buildNotificationRequest(content: WalkNotificationContent, fireAt date: Date) -> UNNotificationRequest {
        let notificationContent = UNMutableNotificationContent()
        notificationContent.title = content.title
        notificationContent.body = content.body
        notificationContent.sound = .default
        notificationContent.categoryIdentifier = Self.notificationCategory
        notificationContent.userInfo = [
            Self.notificationActionKey: "start_walk",
            Self.notificationTypeKey: content.walkType?.rawValue ?? WalkMode.postMeal.rawValue
        ]

        let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: date)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        return UNNotificationRequest(
            identifier: Self.notificationIdentifier,
            content: notificationContent,
            trigger: trigger
        )
    }

    private func walkTypeFromPattern() -> WalkMode? {
        guard let cached = patternManager.cachedPreferredWalkType else { return nil }
        switch cached {
        case "intervals": return .interval
        case "fatBurn": return .fatBurn
        case "postMeal": return .postMeal
        default: return nil
        }
    }

    private func cardActionForWalkMode(_ walkMode: WalkMode?) -> CardAction {
        switch walkMode {
        case .interval:
            return .startIntervalWalk
        case .fatBurn:
            return .startFatBurnWalk
        default:
            return .startPostMealWalk
        }
    }

    // MARK: - Persistence

    private static func loadState(from defaults: UserDefaults) -> WalkNotificationState {
        guard let data = defaults.data(forKey: "walk_notification_state"),
              let decoded = try? JSONDecoder().decode(WalkNotificationState.self, from: data) else {
            return .empty
        }
        return decoded
    }

    private func saveState() {
        if let data = try? JSONEncoder().encode(state) {
            defaults.set(data, forKey: "walk_notification_state")
        }
    }
}

extension WalkMode {
    var displayName: String {
        switch self {
        case .free: return "walk"
        case .interval: return "interval"
        case .fatBurn: return "fat burn"
        case .postMeal: return "post-meal walk"
        }
    }
}

extension CardAction {
    var rawValue: String {
        switch self {
        case .navigateToIntervals: return "navigateToIntervals"
        case .navigateToWalksTab: return "navigateToWalksTab"
        case .navigateToFuelTab: return "navigateToFuelTab"
        case .startPostMealWalk: return "startPostMealWalk"
        case .startIntervalWalk: return "startIntervalWalk"
        case .startFatBurnWalk: return "startFatBurnWalk"
        case .openWatchSetup: return "openWatchSetup"
        // These actions are not used in notifications
        case .useShieldForDate: return "useShieldForDate"
        case .letStreakBreak: return "letStreakBreak"
        case .dismissFuelUpsell: return "dismissFuelUpsell"
        }
    }

    static func fromRawValue(_ value: String?) -> CardAction? {
        switch value {
        case "navigateToIntervals": return .navigateToIntervals
        case "navigateToWalksTab": return .navigateToWalksTab
        case "navigateToFuelTab": return .navigateToFuelTab
        case "startPostMealWalk": return .startPostMealWalk
        case "startIntervalWalk": return .startIntervalWalk
        case "startFatBurnWalk": return .startFatBurnWalk
        case "openWatchSetup": return .openWatchSetup
        // Streak protection and fuel upsell actions can't be restored from notifications
        default: return nil
        }
    }
}

extension Notification.Name {
    static let walkNotificationAction = Notification.Name("walk_notification_action")
}
