//
//  SettingsView.swift
//  JustWalk
//
//  Settings screen with goals, streak info, preferences, and more
//

import StoreKit
import SwiftUI
import UserNotifications

struct SettingsView: View {
    private var persistence: PersistenceManager { PersistenceManager.shared }
    private var subscriptionManager: SubscriptionManager { SubscriptionManager.shared }
    private var notificationManager: NotificationManager { NotificationManager.shared }
    private var walkNotificationManager: WalkNotificationManager { WalkNotificationManager.shared }
    private var hapticsManager: HapticsManager { HapticsManager.shared }
    private var streakManager: StreakManager { StreakManager.shared }
    private var shieldManager: ShieldManager { ShieldManager.shared }
    private var healthKitManager: HealthKitManager { HealthKitManager.shared }

    @State private var profile: UserProfile = .default
    @State private var showProPaywall = false
    @State private var showDeleteConfirmation = false
    @State private var showDeleteSheet = false
    @State private var showStreakDetail = false
    @State private var showShieldDetail = false
    @State private var showStreakReminderSheet = false
    @State private var showWalkReminderSheet = false
    @State private var showShieldPurchaseSheet = false
    @State private var showPrivacySheet = false

    @State private var notificationPermissionStatus: UNAuthorizationStatus = .notDetermined
    @AppStorage("liveActivity_promptShown") private var liveActivityPromptShown = false
    @AppStorage("iCloudSyncEnabled") private var iCloudSyncEnabled = true

    // HealthKit sync state
    @State private var isSyncingHealthKit = false
    @State private var showSyncResult = false
    @State private var syncResultMessage = ""

    var body: some View {
        NavigationStack {
            List {
                goalSection
                streakShieldsSection
                notificationsSection
                walksSection
                privacySection
                displaySection
                proSection
                dataSupportSection

                #if DEBUG
                // Debug/Developer section
                Section("Developer") {
                    NavigationLink("Debug Settings") {
                        DebugSettingsView()
                    }
                    .listRowBackground(JW.Color.backgroundCard)
                }
                #endif
            }
            .scrollContentBackground(.hidden)
            .background(JW.Color.backgroundPrimary)
            .toolbar(.hidden, for: .navigationBar)
            .onAppear {
                profile = persistence.loadProfile()
                loadPermissionStatuses()
            }
            .onChange(of: profile) { _, newValue in
                persistence.saveProfile(newValue)
                UserDefaults.standard.set(newValue.dailyStepGoal, forKey: "dailyStepGoal")
                StepDataManager.shared.updateTodaySteps(
                    HealthKitManager.shared.todaySteps,
                    goalTarget: newValue.dailyStepGoal
                )
            }
            .sheet(isPresented: $showProPaywall) {
                ProUpgradeView(onComplete: { showProPaywall = false })
            }
            .sheet(isPresented: $showStreakDetail) {
                StreakDetailSheet()
            }
            .sheet(isPresented: $showShieldDetail) {
                ShieldDetailSheet()
            }
            .sheet(isPresented: $showStreakReminderSheet) {
                StreakReminderSheet()
            }
            .sheet(isPresented: $showWalkReminderSheet) {
                WalkReminderSheet()
            }
            .sheet(isPresented: $showShieldPurchaseSheet) {
                ShieldPurchaseSheet(
                    isPro: subscriptionManager.isPro,
                    onShieldPurchased: { },
                    onRequestProUpgrade: { showProPaywall = true }
                )
            }
            .sheet(isPresented: $showPrivacySheet) {
                PrivacySheetView()
            }
            .sheet(isPresented: $showDeleteSheet) {
                DeleteDataConfirmationView(onConfirmDelete: {
                    // Reset local state after deletion
                    profile = .default
                    // Post notification to reset app to onboarding
                    NotificationCenter.default.post(name: .didDeleteAllData, object: nil)
                })
            }
            .alert("HealthKit Sync", isPresented: $showSyncResult) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(syncResultMessage)
            }
        }
    }

    // MARK: - 1. Your Goal

    private var goalSection: some View {
        Section("Your Goal") {
            HStack {
                Button {
                    if profile.dailyStepGoal > 1000 {
                        profile.dailyStepGoal -= 500
                        JustWalkHaptics.selectionChanged()
                    }
                } label: {
                    Image(systemName: "minus.circle.fill")
                        .font(.title2)
                        .foregroundStyle(profile.dailyStepGoal > 1000 ? JW.Color.accent : .gray)
                }
                .buttonStyle(.plain)

                Spacer()

                Text("\(profile.dailyStepGoal.formatted()) steps")
                    .font(.headline)
                    .monospacedDigit()
                    .contentTransition(.numericText())
                    .animation(.default, value: profile.dailyStepGoal)

                Spacer()

                Button {
                    if profile.dailyStepGoal < 25000 {
                        profile.dailyStepGoal += 500
                        JustWalkHaptics.selectionChanged()
                    }
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.title2)
                        .foregroundStyle(profile.dailyStepGoal < 25000 ? JW.Color.accent : .gray)
                }
                .buttonStyle(.plain)
            }
            .padding(.vertical, 4)
            .listRowBackground(JW.Color.backgroundCard)
        }
    }

    // MARK: - 2. Streak & Shields

    private var streakShieldsSection: some View {
        Section("Streak & Shields") {
            HStack {
                Image(systemName: "flame.fill")
                    .foregroundStyle(JW.Color.streak)
                Text("\(streakManager.streakData.currentStreak) \(streakManager.streakData.currentStreak == 1 ? "day" : "days")")
            }
            .listRowBackground(JW.Color.backgroundCard)

            Button {
                showShieldDetail = true
            } label: {
                HStack {
                    Image(systemName: "shield.fill")
                        .foregroundStyle(JW.Color.accentBlue)
                    Text("\(shieldManager.shieldData.availableShields) \(shieldManager.shieldData.availableShields == 1 ? "shield" : "shields") available")
                        .foregroundStyle(.primary)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .listRowBackground(JW.Color.backgroundCard)

            if shieldManager.shieldData.availableShields == 0 {
                Button {
                    showShieldPurchaseSheet = true
                } label: {
                    HStack {
                        Image(systemName: "shield.badge.plus")
                            .foregroundStyle(JW.Color.accentBlue)
                        Text("Get More Shields")
                        Spacer()
                        Text(subscriptionManager.shieldDisplayPrice)
                            .foregroundStyle(.secondary)
                    }
                }
                .listRowBackground(JW.Color.backgroundCard)
            }

            Button {
                showStreakDetail = true
            } label: {
                Text("View Calendar")
            }
            .listRowBackground(JW.Color.backgroundCard)
        }
    }

    // MARK: - 3. Notifications

    private var systemNotificationsAllowed: Bool {
        switch notificationPermissionStatus {
        case .authorized, .provisional, .ephemeral: return true
        default: return false
        }
    }

    private var streakReminderTimeLabel: String {
        var components = DateComponents()
        components.hour = notificationManager.streakReminderHour
        components.minute = notificationManager.streakReminderMinute
        guard let date = Calendar.current.date(from: components) else { return "7:00 PM" }
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    private var walkReminderTimeLabel: String {
        if !walkNotificationManager.notificationsEnabled {
            return "Off"
        }
        if walkNotificationManager.smartTimingEnabled {
            return "Smart"
        }
        guard let time = walkNotificationManager.preferredTime else { return "6:00 PM" }
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: time)
    }

    private var notificationsSection: some View {
        Section("Notifications") {
            if systemNotificationsAllowed {
                Button {
                    showWalkReminderSheet = true
                } label: {
                    HStack {
                        Text("Daily Walk Reminder")
                            .foregroundStyle(.primary)
                        Spacer()
                        Text(walkReminderTimeLabel)
                            .foregroundStyle(.secondary)
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .listRowBackground(JW.Color.backgroundCard)

                // Streak Reminder — tapping opens detail sheet
                Button {
                    showStreakReminderSheet = true
                } label: {
                    HStack {
                        Text("Streak Reminder")
                            .foregroundStyle(.primary)
                        Spacer()
                        Text(notificationManager.streakRemindersEnabled ? streakReminderTimeLabel : "Off")
                            .foregroundStyle(.secondary)
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .listRowBackground(JW.Color.backgroundCard)

                // Goal Celebrations — simple toggle
                Toggle("Goal Celebrations", isOn: Binding(
                    get: { notificationManager.goalCelebrationsEnabled },
                    set: { notificationManager.goalCelebrationsEnabled = $0 }
                ))
                .listRowBackground(JW.Color.backgroundCard)
            } else if notificationPermissionStatus == .denied {
                Button {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                } label: {
                    HStack {
                        Text("Notifications")
                            .foregroundStyle(.primary)
                        Spacer()
                        Text("Blocked")
                            .font(.caption)
                            .fontWeight(.medium)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Color.red.opacity(0.15))
                            .foregroundStyle(.red)
                            .clipShape(Capsule())
                    }
                }
                .listRowBackground(JW.Color.backgroundCard)
            } else {
                Button {
                    Task {
                        _ = await notificationManager.requestAuthorization()
                        loadPermissionStatuses()
                    }
                } label: {
                    HStack {
                        Text("Notifications")
                            .foregroundStyle(.primary)
                        Spacer()
                        Text("Enable")
                            .foregroundStyle(JW.Color.accentBlue)
                    }
                }
                .listRowBackground(JW.Color.backgroundCard)
            }
        }
    }

    // MARK: - 4. Walks

    private var walksSection: some View {
        Section("Walks") {
            Toggle("Haptics", isOn: Binding(
                get: { hapticsManager.isEnabled },
                set: { hapticsManager.isEnabled = $0 }
            ))
            .listRowBackground(JW.Color.backgroundCard)

        }
    }

    // MARK: - Privacy

    private var privacySection: some View {
        Section("Privacy") {
            Button {
                showPrivacySheet = true
            } label: {
                HStack {
                    Text("Your Data")
                        .foregroundStyle(.primary)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .foregroundStyle(.secondary)
                }
            }
            .listRowBackground(JW.Color.backgroundCard)

            Toggle(isOn: $iCloudSyncEnabled) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("iCloud Sync")
                    Text("Sync walks and streaks across your Apple devices.\nUses your iCloud account — we never see this data.")
                        .font(JW.Font.caption)
                        .foregroundStyle(JW.Color.textSecondary)
                }
            }
            .listRowBackground(JW.Color.backgroundCard)
            .onChange(of: iCloudSyncEnabled) { _, enabled in
                if enabled {
                    Task {
                        let success = await CloudKitSyncManager.shared.setup()
                        if success {
                            CloudKitSyncManager.shared.pushAllToCloud()
                        }
                    }
                }
            }

            if let url = URL(string: "https://getjustwalk.com/privacy") {
                Link(destination: url) {
                    HStack {
                        Text("Privacy Policy")
                        Spacer()
                        Image(systemName: "arrow.up.right.square")
                            .foregroundStyle(.secondary)
                    }
                }
                .listRowBackground(JW.Color.backgroundCard)
            }
        }
    }

    // MARK: - 5. Display

    private var displaySection: some View {
        Section("Display") {
            Toggle("Use Metric (km)", isOn: $profile.useMetricUnits)
                .listRowBackground(JW.Color.backgroundCard)

            Toggle("Show Live Activity setup tip", isOn: Binding(
                get: { !liveActivityPromptShown },
                set: { liveActivityPromptShown = !$0 }
            ))
            .listRowBackground(JW.Color.backgroundCard)
        }
    }

    // MARK: - 6. Pro

    private var proSection: some View {
        Section {
            if subscriptionManager.isPro {
                HStack {
                    Text("Status")
                    Spacer()
                    Label("Pro", systemImage: "checkmark.seal.fill")
                        .foregroundStyle(JW.Color.accent)
                }
                .listRowBackground(JW.Color.backgroundCard)
            } else {
                Button {
                    showProPaywall = true
                } label: {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text("Upgrade to Pro")
                                .fontWeight(.semibold)
                            Spacer()
                            Text("\(subscriptionManager.proAnnualProduct?.displayPrice ?? "$29.99")/year")
                                .foregroundStyle(.secondary)
                        }
                        Text("Unlimited Walks · AI Food Logging · Full Protection")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .listRowBackground(JW.Color.backgroundCard)
            }

            Button("Restore Purchases") {
                Task {
                    await subscriptionManager.restorePurchases()
                }
            }
            .listRowBackground(JW.Color.backgroundCard)
        }
    }

    // MARK: - 8. Data & Support

    private var dataSupportSection: some View {
        Section("Data & Support") {
            Button {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            } label: {
                HStack {
                    Text("Health Data Access")
                        .foregroundStyle(.primary)
                    Spacer()
                    Text(healthKitManager.isAuthorized ? "Granted" : "Not Granted")
                        .foregroundStyle(healthKitManager.isAuthorized ? .green : .secondary)
                }
            }
            .listRowBackground(JW.Color.backgroundCard)

            // Sync HealthKit History button
            Button {
                Task {
                    isSyncingHealthKit = true
                    let goal = profile.dailyStepGoal
                    let result = await healthKitManager.syncHealthKitHistory(days: HealthKitManager.historySyncDays, dailyGoal: goal)
                    isSyncingHealthKit = false

                    if result.synced > 0 {
                        syncResultMessage = "Synced \(result.synced) days of step data from HealthKit."
                    } else if result.total > 0 {
                        syncResultMessage = "All \(result.total) days are already up to date."
                    } else {
                        syncResultMessage = "No HealthKit data found. Make sure Health access is granted."
                    }
                    showSyncResult = true
                }
            } label: {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Sync HealthKit History")
                            .foregroundStyle(.primary)
                        Text("Last \(HealthKitManager.historySyncDays) days")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    if isSyncingHealthKit {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .disabled(isSyncingHealthKit)
            .listRowBackground(JW.Color.backgroundCard)

            if let shareURL = URL(string: "https://apps.apple.com/app/just-walk/id6740066018") {
                ShareLink(
                    item: shareURL,
                    message: Text("Check out Just Walk — it makes walking fun!")
                ) {
                    HStack {
                        Text("Share Just Walk")
                        Spacer()
                        Image(systemName: "square.and.arrow.up")
                            .foregroundStyle(.secondary)
                    }
                }
                .listRowBackground(JW.Color.backgroundCard)
            }

            NavigationLink("Support & Legal") {
                SupportLegalView(profile: profile)
            }
            .listRowBackground(JW.Color.backgroundCard)

            Button(role: .destructive) {
                showDeleteSheet = true
            } label: {
                HStack {
                    Text("Delete All Data")
                    Spacer()
                    Image(systemName: "trash")
                        .foregroundStyle(.red)
                }
            }
            .listRowBackground(JW.Color.backgroundCard)
        }
    }

    // MARK: - Helpers

    private func loadPermissionStatuses() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            DispatchQueue.main.async {
                notificationPermissionStatus = settings.authorizationStatus
            }
        }
    }
}

// MARK: - Streak Reminder Sheet

struct StreakReminderSheet: View {
    @Environment(\.dismiss) private var dismiss
    private var notificationManager: NotificationManager { NotificationManager.shared }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Toggle("Streak Reminder", isOn: Binding(
                        get: { notificationManager.streakRemindersEnabled },
                        set: { notificationManager.streakRemindersEnabled = $0 }
                    ))
                    .listRowBackground(JW.Color.backgroundCard)
                } footer: {
                    Text("Get a daily nudge in the evening if you haven't hit your daily goal yet.")
                        .font(JW.Font.caption)
                }

                if notificationManager.streakRemindersEnabled {
                    Section("Reminder Time") {
                        DatePicker("Time", selection: streakReminderTime, displayedComponents: .hourAndMinute)
                            .labelsHidden()
                            .datePickerStyle(.wheel)
                            .listRowBackground(JW.Color.backgroundCard)
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(JW.Color.backgroundPrimary)
            .navigationTitle("Streak Reminder")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
    }

    private var streakReminderTime: Binding<Date> {
        Binding(
            get: {
                var components = DateComponents()
                components.hour = notificationManager.streakReminderHour
                components.minute = notificationManager.streakReminderMinute
                return Calendar.current.date(from: components) ?? Date()
            },
            set: { newDate in
                let components = Calendar.current.dateComponents([.hour, .minute], from: newDate)
                notificationManager.streakReminderHour = components.hour ?? 19
                notificationManager.streakReminderMinute = components.minute ?? 0
            }
        )
    }
}

// MARK: - Walk Reminder Sheet

struct WalkReminderSheet: View {
    @Environment(\.dismiss) private var dismiss
    private var manager: WalkNotificationManager { WalkNotificationManager.shared }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Toggle("Daily Walk Reminder", isOn: Binding(
                        get: { manager.notificationsEnabled },
                        set: { newValue in
                            manager.notificationsEnabled = newValue
                            manager.scheduleNotificationIfNeeded(force: true)
                        }
                    ))
                    .listRowBackground(JW.Color.backgroundCard)
                } footer: {
                    Text("One helpful daily nudge, only if you haven't hit your goal.")
                        .font(JW.Font.caption)
                }

                if manager.notificationsEnabled {
                    Section {
                        Toggle("Smart Timing", isOn: Binding(
                            get: { manager.smartTimingEnabled },
                            set: { newValue in
                                manager.smartTimingEnabled = newValue
                                manager.scheduleNotificationIfNeeded(force: true)
                            }
                        ))
                        .listRowBackground(JW.Color.backgroundCard)
                    } footer: {
                        Text("Smart timing uses your usual walk time when available.")
                            .font(JW.Font.caption)
                    }

                    if !manager.smartTimingEnabled {
                        Section("Remind Me At") {
                            DatePicker("Time", selection: preferredTime, displayedComponents: .hourAndMinute)
                                .labelsHidden()
                                .datePickerStyle(.wheel)
                                .listRowBackground(JW.Color.backgroundCard)
                        }
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(JW.Color.backgroundPrimary)
            .navigationTitle("Daily Walk Reminder")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        manager.scheduleNotificationIfNeeded(force: true)
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
    }

    private var preferredTime: Binding<Date> {
        Binding(
            get: {
                manager.preferredTime ?? defaultPreferredTime()
            },
            set: { newDate in
                manager.preferredTime = newDate
                manager.scheduleNotificationIfNeeded(force: true)
            }
        )
    }

    private func defaultPreferredTime() -> Date {
        var components = DateComponents()
        components.hour = 18
        components.minute = 0
        return Calendar.current.date(from: components) ?? Date()
    }
}

// MARK: - Legacy Badges View

struct LegacyBadgesView: View {
    let badges: [LegacyBadge]

    var body: some View {
        List(badges) { badge in
            HStack {
                Image(systemName: "rosette")
                    .font(.title)
                    .foregroundStyle(JW.Color.streak)

                VStack(alignment: .leading) {
                    Text(badge.name)
                        .font(.headline)
                    Text("Earned \(badge.earnedAt.formatted(date: .abbreviated, time: .omitted))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .listRowBackground(JW.Color.backgroundCard)
        }
        .scrollContentBackground(.hidden)
        .background(JW.Color.backgroundPrimary)
        .navigationTitle("Legacy Badges")
    }
}
