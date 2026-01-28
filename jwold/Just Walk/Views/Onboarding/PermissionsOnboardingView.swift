//
//  PermissionsOnboardingView.swift
//  Just Walk
//
//  Created by Randy Chia on 1/8/26.
//

import SwiftUI
import CoreMotion
import UserNotifications

/// Unified onboarding flow: Welcome -> Features -> Permissions -> Goal -> Ready
struct PermissionsOnboardingView: View {

    @Environment(\.dismiss) private var dismiss
    @State private var currentPage = 0
    @State private var isRequestingPermissions = false
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var showSettingsAlert = false
    @State private var settingsAlertTitle = ""
    @State private var settingsAlertMessage = ""
    
    // Permission State
    @State private var healthStatus: PermissionStatus = .notDetermined
    @State private var motionStatus: PermissionStatus = .notDetermined
    @State private var locationStatus: PermissionStatus = .notDetermined
    @State private var notificationStatus: PermissionStatus = .notDetermined

    // Pre-permission screen state
    @State private var showHealthKitPrePermission = false

    enum PermissionStatus {
        case notDetermined
        case authorized
        case denied
    }
    
    // Email State - Removed as per new requirement
    // @State private var emailAddress = ""
    // @State private var newsletterOptIn = true 
    // @State private var isEmailValid = false
    // @State private var showEmailForm = false
    
    // Goal Selection State
    @AppStorage("dailyStepGoal") private var dailyStepGoal = 10000
    // 500-step increments from 0 to 20,000 (41 options, 10k at center)
    private let stepOptions = Array(stride(from: 0, through: 20000, by: 500))
    @State private var sliderValue: Double = 20.0 // Defaults to index 20 (10,000)
    
    // Animation State
    @State private var welcomeOpacity = 0.0

    let onComplete: () -> Void

    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                colors: [.blue, .cyan],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 32) {
                Spacer()

                Group {
                    switch currentPage {
                    case 0:
                        welcomePage
                            .transition(.asymmetric(insertion: .move(edge: .trailing), removal: .move(edge: .leading)))
                    case 1:
                        featuresOverviewPage
                            .transition(.asymmetric(insertion: .move(edge: .trailing), removal: .move(edge: .leading)))
                    case 2:
                        permissionsPage
                            .transition(.asymmetric(insertion: .move(edge: .trailing), removal: .move(edge: .leading)))
                    case 3:
                        goalSelectionPage
                            .transition(.asymmetric(insertion: .move(edge: .trailing), removal: .move(edge: .leading)))
                    case 4:
                        readyPage
                            .transition(.asymmetric(insertion: .move(edge: .trailing), removal: .move(edge: .leading)))
                    default:
                        EmptyView()
                    }
                }
                .animation(.easeInOut, value: currentPage)

                Spacer()

                // Action button
                actionButton
                    .padding(.horizontal, 32)
                    .padding(.bottom, 48)
            }
        }
        .alert("Permission Error", isPresented: $showError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage)
        }
        .alert(settingsAlertTitle, isPresented: $showSettingsAlert) {
            Button("Open Settings", role: .none) {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text(settingsAlertMessage)
        }
        .sheet(isPresented: $showHealthKitPrePermission) {
            HealthKitPermissionView {
                // User tapped "Allow Step Tracking" - now trigger the actual system prompt
                showHealthKitPrePermission = false
                Task {
                    await requestHealthKitPermission()
                }
            }
        }
    }

    // MARK: - Pages

    private var welcomePage: some View {
        VStack(spacing: 28) {
            Image(systemName: "figure.walk.circle.fill")
                .font(.system(size: 100))
                .foregroundStyle(.white)
                .symbolEffect(.pulse, options: .repeating)

            Text("Just Walk")
                .font(.system(size: 42, weight: .bold, design: .rounded))
                .foregroundStyle(.white)

            VStack(spacing: 8) {
                Text("Walk more. Feel better.")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.white)

                Text("The simple way to build a healthier you,\none step at a time.")
                    .font(.body)
                    .foregroundStyle(.white.opacity(0.85))
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 40)
        }
        .opacity(welcomeOpacity)
        .onAppear {
            withAnimation(.easeIn(duration: 0.8)) {
                welcomeOpacity = 1.0
            }
        }
    }
    
    // MARK: - Features Overview (Consolidated)

    private var featuresOverviewPage: some View {
        VStack(spacing: 28) {
            Text("Here's what you get")
                .font(.title2.bold())
                .foregroundStyle(.white)

            VStack(spacing: 12) {
                FeatureRowCompact(
                    icon: "checkmark.circle.fill",
                    iconColor: .green,
                    title: "Count Your Steps",
                    description: "Track every step on your phone, watch, and home screen widgets."
                )

                FeatureRowCompact(
                    icon: "shield.fill",
                    iconColor: .orange,
                    title: "Protect Your Streak",
                    description: "Missed a day? Life happens. Use Streak Shields to keep your momentum going.",
                    isPro: true
                )

                FeatureRowCompact(
                    icon: "figure.walk.motion",
                    iconColor: .orange,
                    title: "Walk with Precision",
                    description: "Map your routes and try Interval Walking, proven to boost fitness faster.",
                    isPro: true
                )

                FeatureRowCompact(
                    icon: "lock.shield.fill",
                    iconColor: .green,
                    title: "Your Data, Your Device",
                    description: "No account needed. No cloud. Your data stays private on your phone."
                )
            }
            .padding(.horizontal, 24)

            // Pro footnote
            HStack(spacing: 6) {
                Image(systemName: "sparkles")
                    .font(.caption)
                    .foregroundStyle(.yellow)
                Text("PRO feature included with Just Walk Pro")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.7))
            }
            .padding(.top, 4)
        }
        .padding(.top, 60)
    }

    private var permissionsPage: some View {
        VStack(spacing: 28) {
            // Header
            VStack(spacing: 12) {
                Image(systemName: "heart.circle.fill")
                    .font(.system(size: 70))
                    .foregroundStyle(.white)
                    .symbolEffect(.pulse)

                Text("Let's get connected")
                    .font(.title2.bold())
                    .foregroundStyle(.white)

                Text("We need a few permissions\nfor the best experience.")
                    .font(.body)
                    .foregroundStyle(.white.opacity(0.85))
                    .multilineTextAlignment(.center)
            }

            VStack(spacing: 12) {
                // Health Access Row (includes steps, distance, calories, heart rate)
                PermissionRow(
                    icon: "heart.fill",
                    iconColor: .pink,
                    title: "Health Data",
                    subtitle: "Steps, distance, calories & heart rate",
                    isEnabled: healthStatus == .authorized,
                    onEnable: {
                        // Show pre-permission screen first
                        showHealthKitPrePermission = true
                    }
                )

                // Motion Access Row
                PermissionRow(
                    icon: "figure.walk",
                    iconColor: .green,
                    title: "Motion",
                    subtitle: "Count steps in real time",
                    isEnabled: motionStatus == .authorized,
                    onEnable: {
                        Task { await requestMotionPermission() }
                    }
                )

                // Location Access Row
                PermissionRow(
                    icon: "location.fill",
                    iconColor: .blue,
                    title: "Location",
                    subtitle: "Track your walking routes on the map",
                    isEnabled: locationStatus == .authorized,
                    onEnable: {
                        Task { await requestLocationPermission() }
                    }
                )

                // Notification Access Row - CRITICAL for Interval Walking
                PermissionRow(
                    icon: "bell.badge.fill",
                    iconColor: .orange,
                    title: "Notifications",
                    subtitle: "Alerts for Interval Walking phases",
                    isEnabled: notificationStatus == .authorized,
                    onEnable: {
                        Task { await requestNotificationPermission() }
                    }
                )
            }
            .padding(.horizontal, 24)
        }
        .onAppear {
            checkCurrentPermissions()
        }
    }
    
    private var goalSelectionPage: some View {
        VStack(spacing: 28) {
            // Header
            VStack(spacing: 12) {
                Image(systemName: "flag.checkered.circle.fill")
                    .font(.system(size: 70))
                    .foregroundStyle(.white)

                Text("Pick your daily goal")
                    .font(.title2.bold())
                    .foregroundStyle(.white)
            }

            // Step count display
            VStack(spacing: 16) {
                Text("\(dailyStepGoal.formatted())")
                    .font(.system(size: 56, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .contentTransition(.numericText())

                Text("steps per day")
                    .font(.headline)
                    .foregroundStyle(.white.opacity(0.8))
            }

            // Slider
            VStack(spacing: 12) {
                Slider(
                    value: $sliderValue,
                    in: 0...Double(stepOptions.count - 1),
                    step: 1
                )
                .tint(.white)
                .onChange(of: sliderValue) {
                    let index = Int(sliderValue)
                    if index >= 0 && index < stepOptions.count {
                        dailyStepGoal = stepOptions[index]
                        let impact = UIImpactFeedbackGenerator(style: .light)
                        impact.impactOccurred()
                    }
                }

                HStack {
                    Text("0")
                    Spacer()
                    Text("20,000")
                }
                .font(.caption)
                .foregroundStyle(.white.opacity(0.7))
            }
            .padding(.horizontal, 32)

            // Tip
            Text("Most people start with 10,000 steps.\nYou can change this anytime.")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.7))
                .multilineTextAlignment(.center)
                .padding(.top, 8)
        }
        .onAppear {
            if let index = stepOptions.firstIndex(of: dailyStepGoal) {
                sliderValue = Double(index)
            }
        }
    }
    
    private var readyPage: some View {
        VStack(spacing: 24) {
            if #available(iOS 18.0, *) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 80))
                    .foregroundStyle(.white)
                    .symbolEffect(.bounce, options: .nonRepeating)
            } else {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 80))
                    .foregroundStyle(.white)
            }

            Text("You're ready!")
                .font(.title.bold())
                .foregroundStyle(.white)

            VStack(spacing: 8) {
                Text("Your goal: \(dailyStepGoal.formatted()) steps a day")
                    .font(.title3.weight(.medium))
                    .foregroundStyle(.white)

                Text("Every step gets you closer to\na healthier, happier you.")
                    .font(.body)
                    .foregroundStyle(.white.opacity(0.85))
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 32)
        }
    }

    // MARK: - Action Button

    @ViewBuilder
    private var actionButton: some View {
        VStack(spacing: 12) {
            Button(action: handleButtonTap) {
                HStack(spacing: 8) {
                    if isRequestingPermissions {
                        ProgressView()
                            .progressViewStyle(.circular)
                            .tint(.blue)
                    } else {
                        Text(buttonTitle)
                            .font(.headline.weight(.semibold))
                    }
                }
                .foregroundStyle(.blue)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(.white)
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .shadow(color: .black.opacity(0.1), radius: 8, y: 4)
            }
            .disabled(isRequestingPermissions || isNextDisabled)
            .opacity(isNextDisabled ? 0.6 : 1.0)

            // Skip option on permissions page
            if currentPage == 2 && (healthStatus != .authorized || motionStatus != .authorized) {
                Text("You can turn these on later in Settings")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.7))
            }
        }
    }
    
    // Validation helper - currently no required fields block progress
    private var isNextDisabled: Bool {
        return false
    }
    
    private var buttonTitle: String {
        switch currentPage {
        case 0:
            return "Get Started"
        case 1:
            return "Continue"
        case 2:
            return "Continue"
        case 3:
            return "Set My Goal"
        case 4:
            return "Let's Go!"
        default:
            return "Continue"
        }
    }

    // MARK: - Actions

    private func handleButtonTap() {
        switch currentPage {
        case 0:
            // Welcome -> Features Overview
            withAnimation {
                currentPage = 1
            }

        case 1:
            // Features Overview -> Permissions
            withAnimation {
                currentPage = 2
            }

        case 2:
            // Permissions -> Goal Selection
            withAnimation {
                currentPage = 3
            }

        case 3:
            // Goal Selection -> Ready
            withAnimation {
                currentPage = 4
            }

        case 4:
            // Complete onboarding
            completeOnboarding()

        default:
            break
        }
    }
    
    private func checkCurrentPermissions() {
        if HealthKitService.shared.isHealthKitAuthorized {
            healthStatus = .authorized
        }
        // Motion check is harder to check synchronously without triggering, assume not determined initially

        // Check location permission status
        let locManager = LocationPermissionManager.shared
        switch locManager.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            locationStatus = .authorized
        case .denied, .restricted:
            locationStatus = .denied
        case .notDetermined:
            locationStatus = .notDetermined
        @unknown default:
            locationStatus = .notDetermined
        }

        // Check notification permission status
        Task {
            let settings = await UNUserNotificationCenter.current().notificationSettings()
            await MainActor.run {
                switch settings.authorizationStatus {
                case .authorized, .provisional, .ephemeral:
                    notificationStatus = .authorized
                case .denied:
                    notificationStatus = .denied
                case .notDetermined:
                    notificationStatus = .notDetermined
                @unknown default:
                    notificationStatus = .notDetermined
                }
            }
        }
    }
    


    private func requestHealthKitPermission() async {
        guard HealthKitService.isHealthDataAvailable else {
            errorMessage = "Health app is not available on this device."
            showError = true
            // Still allow to continue to goal page (index 5)
            withAnimation {
                currentPage = 5
            }
            return
        }

        isRequestingPermissions = true

        do {
            // Always attempt to request authorization - let HealthKit handle already-determined cases
            try await HealthKitService.shared.requestAuthorization()

            // Force refresh data immediately after permission granted
            StepTrackingService.shared.refreshHealthKitData()

            // Do not move to next page automatically, let user click Continue
            healthStatus = .authorized
        } catch {
            // If the system won't show dialog (already denied), direct to Settings
            settingsAlertTitle = "Health Access Required"
            settingsAlertMessage = "Please enable Health access in Settings to track your steps."
            showSettingsAlert = true
            healthStatus = .denied
        }

        isRequestingPermissions = false
    }
    
    private func requestMotionPermission() async {
        isRequestingPermissions = true

        do {
            // Request ONLY CoreMotion/Pedometer permission (not HealthKit)
            // HealthKit is requested separately via the "Health Data" button
            try await StepTrackingService.shared.requestPedometerAuthorization()

            // Start tracking now that we have permission
            StepTrackingService.shared.loadTodaySteps()
            StepTrackingService.shared.startTodayUpdates()

            // Update UI status
            motionStatus = .authorized
        } catch {
            errorMessage = "Motion access is required to track your steps without an Apple Watch."
            showError = true
            motionStatus = .denied
        }

        isRequestingPermissions = false
    }

    private func requestNotificationPermission() async {
        isRequestingPermissions = true

        // Check if already determined
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        if settings.authorizationStatus == .denied {
            // Already denied - prompt to go to Settings
            await MainActor.run {
                settingsAlertTitle = "Notifications Required"
                settingsAlertMessage = "Notifications are essential for Interval Walking. When your phone is in your pocket, notifications alert you when to speed up or slow down. Please enable them in Settings."
                showSettingsAlert = true
                isRequestingPermissions = false
            }
            return
        }

        do {
            // Request authorization with options for maximum attention
            // .alert - show visual alert
            // .sound - play sound (respects silent mode unless critical alert entitlement)
            // .badge - show badge on app icon
            // Note: Time-sensitive delivery is set per-notification, not at authorization
            let granted = try await UNUserNotificationCenter.current().requestAuthorization(
                options: [.alert, .sound, .badge]
            )

            await MainActor.run {
                if granted {
                    notificationStatus = .authorized
                    // Register notification categories for IWT
                    IWTService.registerNotificationCategories()
                    print("✅ Notification permission granted")
                } else {
                    notificationStatus = .denied
                    errorMessage = "Notifications help you know when to change pace during Interval Walking. You can enable them later in Settings."
                    showError = true
                }
                isRequestingPermissions = false
            }
        } catch {
            await MainActor.run {
                notificationStatus = .denied
                errorMessage = "Could not request notification permission. Please enable in Settings."
                showError = true
                isRequestingPermissions = false
            }
        }
    }

    private func requestLocationPermission() async {
        let locationManager = LocationPermissionManager.shared

        // Check if already determined
        if locationManager.isDenied {
            // Already denied - prompt to go to Settings
            settingsAlertTitle = "Location Access Required"
            settingsAlertMessage = "Location access is needed to track your walking routes on the map. Please enable it in Settings."
            showSettingsAlert = true
            locationStatus = .denied
            return
        }

        if locationManager.isAuthorized {
            locationStatus = .authorized
            return
        }

        isRequestingPermissions = true

        // Request authorization
        locationManager.requestWhenInUseAuthorization()

        // Wait briefly for user response
        try? await Task.sleep(nanoseconds: 500_000_000)

        // Update status
        if locationManager.isAuthorized {
            locationStatus = .authorized
        } else if locationManager.isDenied {
            locationStatus = .denied
        }

        isRequestingPermissions = false
    }

    private func completeOnboarding() {
        // Sync step goal to StepRepository (Single Source of Truth for dashboard & charts)
        StepRepository.shared.stepGoal = dailyStepGoal

        // Mark onboarding as completed
        UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")
        onComplete()
    }
}

// MARK: - Feature Row

struct FeatureRow: View {
    let icon: String
    let title: String
    let description: String

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(.white)
                .frame(width: 40)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(.white)

                Text(description)
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.8))
            }

            Spacer()
        }
    }
}

// MARK: - Feature Row Compact (for consolidated features page)

struct FeatureRowCompact: View {
    let icon: String
    var iconColor: Color = .white
    let title: String
    let description: String
    var isPro: Bool = false

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(.white.opacity(0.15))
                    .frame(width: 44, height: 44)

                Image(systemName: icon)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(iconColor)
            }

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)

                    if isPro {
                        Text("PRO")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundStyle(.black.opacity(0.8))
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(.yellow)
                            .clipShape(Capsule())
                    }
                }

                Text(description)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.75))
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(14)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}

// MARK: - Permission Row

struct PermissionRow: View {
    let icon: String
    var iconColor: Color = .white
    let title: String
    let subtitle: String
    let isEnabled: Bool
    let onEnable: () -> Void

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(iconColor.opacity(0.2))
                    .frame(width: 44, height: 44)

                Image(systemName: icon)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(iconColor)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)

                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.7))
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Spacer(minLength: 8)

            if isEnabled {
                Image(systemName: "checkmark.circle.fill")
                    .font(.title3)
                    .foregroundStyle(.green)
            } else {
                Button(action: onEnable) {
                    Text("Allow")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.blue)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(.white)
                        .clipShape(Capsule())
                }
            }
        }
        .padding(14)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}

#Preview {
    PermissionsOnboardingView {
        print("Onboarding completed")
    }
}
