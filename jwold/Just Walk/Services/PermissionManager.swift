//
//  PermissionManager.swift
//  Just Walk
//
//  Centralized permission orchestration for onboarding.
//  Handles HealthKit, CoreMotion, and Notifications in sequence.
//

import Foundation
import HealthKit
import CoreMotion
import UserNotifications
import Combine
import CoreLocation

/// Centralized manager for requesting all app permissions.
/// Used during onboarding to coordinate permission requests.
@MainActor
final class PermissionManager: ObservableObject {

    // MARK: - Singleton

    static let shared = PermissionManager()

    // MARK: - Published State

    @Published private(set) var healthKitStatus: PermissionStatus = .notDetermined
    @Published private(set) var motionStatus: PermissionStatus = .notDetermined
    @Published private(set) var locationStatus: PermissionStatus = .notDetermined
    @Published private(set) var notificationStatus: PermissionStatus = .notDetermined
    @Published private(set) var isRequestingPermissions = false

    // MARK: - Permission Status

    enum PermissionStatus: String {
        case notDetermined = "Not Determined"
        case authorized = "Authorized"
        case denied = "Denied"
    }

    // MARK: - Private Properties

    private let healthStore = HKHealthStore()
    private let pedometer = CMPedometer()

    // MARK: - Computed Properties

    /// Whether all permissions have been handled (authorized or denied)
    var allPermissionsHandled: Bool {
        healthKitStatus != .notDetermined &&
        motionStatus != .notDetermined &&
        locationStatus != .notDetermined &&
        notificationStatus != .notDetermined
    }

    /// Whether at least one critical permission is authorized
    var hasMinimumPermissions: Bool {
        healthKitStatus == .authorized || motionStatus == .authorized
    }

    // MARK: - Initialization

    private init() {
        // Check current status on init
        Task {
            await checkCurrentStatus()
        }
    }

    // MARK: - Public API

    /// Request all permissions in sequence.
    /// This is the main entry point called from OnboardingView.
    func requestAllPermissions() async {
        isRequestingPermissions = true

        // 1. HealthKit (read-only: steps, distance, calories)
        await requestHealthKit()

        // 2. CoreMotion (pedometer for live updates)
        await requestMotion()

        // 3. Location (for map in Walk tab)
        await requestLocation()

        // 4. Notifications (streaks, milestones, IWT phases)
        await requestNotifications()

        // 5. THE HOOK: Hydrate history regardless of permission outcomes
        // This ensures charts show data immediately after onboarding
        await StepRepository.shared.hydrateHistoricalData()

        isRequestingPermissions = false
    }

    /// Check current permission status without requesting
    func checkCurrentStatus() async {
        // HealthKit status
        if HKHealthStore.isHealthDataAvailable() {
            let stepType = HKQuantityType.quantityType(forIdentifier: .stepCount)!
            let status = healthStore.authorizationStatus(for: stepType)
            switch status {
            case .notDetermined:
                healthKitStatus = .notDetermined
            case .sharingAuthorized:
                healthKitStatus = .authorized
            case .sharingDenied:
                healthKitStatus = .denied
            @unknown default:
                healthKitStatus = .notDetermined
            }
        } else {
            healthKitStatus = .denied
        }

        // Motion status - CMPedometer doesn't have a direct status check
        // We infer from CMMotionActivityManager
        let motionActivityStatus = CMMotionActivityManager.authorizationStatus()
        switch motionActivityStatus {
        case .notDetermined:
            motionStatus = .notDetermined
        case .authorized:
            motionStatus = .authorized
        case .denied, .restricted:
            motionStatus = .denied
        @unknown default:
            motionStatus = .notDetermined
        }

        // Location status
        let locManager = LocationPermissionManager.shared
        switch locManager.authorizationStatus {
        case .notDetermined:
            locationStatus = .notDetermined
        case .authorizedWhenInUse, .authorizedAlways:
            locationStatus = .authorized
        case .denied, .restricted:
            locationStatus = .denied
        @unknown default:
            locationStatus = .notDetermined
        }

        // Notification status
        let notificationSettings = await UNUserNotificationCenter.current().notificationSettings()
        switch notificationSettings.authorizationStatus {
        case .notDetermined:
            notificationStatus = .notDetermined
        case .authorized, .provisional, .ephemeral:
            notificationStatus = .authorized
        case .denied:
            notificationStatus = .denied
        @unknown default:
            notificationStatus = .notDetermined
        }
    }

    // MARK: - Private Permission Requests

    /// Request HealthKit read access
    private func requestHealthKit() async {
        guard HKHealthStore.isHealthDataAvailable() else {
            healthKitStatus = .denied
            return
        }

        let typesToRead: Set<HKObjectType> = [
            HKQuantityType.quantityType(forIdentifier: .stepCount)!,
            HKQuantityType.quantityType(forIdentifier: .distanceWalkingRunning)!,
            HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned)!,
            HKObjectType.workoutType(),  // Required when requesting workoutRoute
            HKSeriesType.workoutRoute()
        ]

        // READ-ONLY: No write permissions needed
        let typesToWrite: Set<HKSampleType> = []

        do {
            try await healthStore.requestAuthorization(toShare: typesToWrite, read: typesToRead)
            // Authorization request completed - mark as authorized
            // Note: For read-only apps, Apple hides actual read status for privacy.
            // We trust that if the request succeeded without error, user saw the prompt.
            healthKitStatus = .authorized

            // Sync with HealthKitService so the persistent flag is set
            HealthKitService.shared.markAuthorizationCompleted()

            print("✅ PermissionManager: HealthKit \(healthKitStatus.rawValue)")
        } catch {
            healthKitStatus = .denied
            print("❌ PermissionManager: HealthKit request failed: \(error)")
        }
    }

    /// Request CoreMotion pedometer access
    private func requestMotion() async {
        guard CMPedometer.isStepCountingAvailable() else {
            motionStatus = .denied
            return
        }

        // CMPedometer triggers permission on first query
        // We do a brief historical query to trigger the prompt
        return await withCheckedContinuation { continuation in
            let now = Date()
            let oneHourAgo = now.addingTimeInterval(-3600)

            pedometer.queryPedometerData(from: oneHourAgo, to: now) { [weak self] data, error in
                Task { @MainActor in
                    if let _ = data {
                        self?.motionStatus = .authorized
                        print("✅ PermissionManager: CoreMotion Authorized")
                    } else {
                        // Query failed - check authorization status directly
                        // This handles denied permissions, restrictions, or other errors
                        let status = CMMotionActivityManager.authorizationStatus()
                        self?.motionStatus = (status == .authorized) ? .authorized : .denied
                        if let error = error {
                            print("⚠️ PermissionManager: CoreMotion query error: \(error.localizedDescription)")
                        }
                        print("⚠️ PermissionManager: CoreMotion status: \(self?.motionStatus.rawValue ?? "unknown")")
                    }
                    continuation.resume()
                }
            }
        }
    }

    /// Request location permission for map features
    private func requestLocation() async {
        let locationManager = LocationPermissionManager.shared

        // Check current status
        switch locationManager.authorizationStatus {
        case .notDetermined:
            locationManager.requestWhenInUseAuthorization()
            // Wait briefly for user response
            try? await Task.sleep(nanoseconds: 500_000_000)
            locationStatus = locationManager.isAuthorized ? .authorized : .denied
        case .authorizedWhenInUse, .authorizedAlways:
            locationStatus = .authorized
        case .denied, .restricted:
            locationStatus = .denied
        @unknown default:
            locationStatus = .notDetermined
        }

        print("📍 PermissionManager: Location \(locationStatus.rawValue)")
    }

    /// Request notification permissions
    private func requestNotifications() async {
        let center = UNUserNotificationCenter.current()

        do {
            let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge])
            notificationStatus = granted ? .authorized : .denied
            print("✅ PermissionManager: Notifications \(notificationStatus.rawValue)")

            // Register notification categories for IWT phase actions
            if granted {
                IWTService.registerNotificationCategories()
            }
        } catch {
            notificationStatus = .denied
            print("❌ PermissionManager: Notification request failed: \(error)")
        }
    }
}
