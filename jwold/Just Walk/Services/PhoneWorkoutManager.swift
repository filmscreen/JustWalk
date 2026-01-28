//
//  PhoneWorkoutManager.swift
//  Just Walk
//
//  Manages iPhone-side workout recording with GPS tracking.
//  Records walking routes with HKWorkoutRouteBuilder for HealthKit.
//
//  SAFEGUARDS:
//  1. Pocket Protection: allowsBackgroundLocationUpdates managed per-session
//  2. Battery Guard: deinit stops GPS if view leaks
//  3. Accuracy Filter: Skips locations with horizontalAccuracy > 50m
//  4. Permission Grace: Skips route builder if reduced accuracy authorization
//

import Foundation
import CoreLocation
import CoreMotion
import HealthKit
import Combine

// MARK: - Workout State

enum PhoneWorkoutState: String, Sendable {
    case idle
    case recording
    case paused
    case finishing
}

// MARK: - Error Types

enum PhoneWorkoutError: LocalizedError {
    case workoutAlreadyActive
    case noActiveWorkout
    case locationAccessDenied
    case workoutBuilderFailed
    case routeBuilderFailed
    case healthKitNotAuthorized

    var errorDescription: String? {
        switch self {
        case .workoutAlreadyActive:
            return "A workout is already in progress."
        case .noActiveWorkout:
            return "No active workout to stop."
        case .locationAccessDenied:
            return "Location access is required for GPS tracking. Please enable in Settings."
        case .workoutBuilderFailed:
            return "Failed to save workout to Health."
        case .routeBuilderFailed:
            return "Failed to save workout route."
        case .healthKitNotAuthorized:
            return "Health access is required. Please enable in Settings."
        }
    }
}

// MARK: - Workout Summary

struct PhoneWorkoutSummary {
    let startTime: Date
    let endTime: Date
    let duration: TimeInterval
    let steps: Int
    let distance: Double // meters
    let gpsDistance: Double // meters (GPS-calculated)
    let calories: Double
    let routeRecorded: Bool
    let workout: HKWorkout?
    let hkWorkoutId: UUID? // HealthKit workout UUID for fetching later

    var formattedDuration: String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    var distanceMiles: Double {
        distance * 0.000621371
    }

    var formattedDistance: String {
        String(format: "%.2f mi", distanceMiles)
    }
}

// MARK: - PhoneWorkoutManager

@MainActor
final class PhoneWorkoutManager: NSObject, ObservableObject {

    static let shared = PhoneWorkoutManager()

    // MARK: - Dependencies

    private let healthStore = HKHealthStore()
    private let locationManager = CLLocationManager()
    private let pedometer = CMPedometer()

    // MARK: - Published State

    /// Current workout state
    @Published private(set) var state: PhoneWorkoutState = .idle

    /// Whether GPS route recording is active
    @Published private(set) var isRecordingRoute: Bool = false

    /// Live step count during session
    @Published private(set) var sessionSteps: Int = 0

    /// Live distance in meters (from pedometer)
    @Published private(set) var sessionDistance: Double = 0

    /// GPS-calculated distance (more accurate for outdoor routes)
    @Published private(set) var gpsDistance: Double = 0

    /// Current pace (seconds per meter)
    @Published private(set) var currentPace: Double? = nil

    /// Current cadence (steps per second)
    @Published private(set) var currentCadence: Double? = nil

    /// Elapsed duration
    @Published private(set) var elapsedTime: TimeInterval = 0

    /// Active calories burned (estimated)
    @Published private(set) var activeCalories: Double = 0

    /// Current location accuracy (for UI display)
    @Published private(set) var locationAccuracy: CLLocationAccuracy = 0

    /// Whether we have good GPS signal (horizontalAccuracy <= 50m)
    @Published private(set) var hasGPSSignal: Bool = true

    /// Live route coordinates for map display during workout
    @Published private(set) var liveCoordinates: [CLLocationCoordinate2D] = []

    /// Error state
    @Published private(set) var error: PhoneWorkoutError?

    // MARK: - Internal State

    /// Workout session start time
    private var startTime: Date?

    /// Workout session end time
    private var endTime: Date?

    /// HKWorkoutBuilder for creating the workout
    private var workoutBuilder: HKWorkoutBuilder?

    /// HKWorkoutRouteBuilder for GPS route
    private var routeBuilder: HKWorkoutRouteBuilder?

    /// Collected GPS locations (filtered by accuracy)
    private var collectedLocations: [CLLocation] = []

    /// Previous location for distance calculation
    private var previousLocation: CLLocation?

    /// Previous step thousands for milestone tracking
    private var previousStepThousands: Int = 0

    /// Timer for elapsed time updates
    private var elapsedTimer: Timer?

    /// Total paused duration
    private var totalPausedTime: TimeInterval = 0

    /// Pause start timestamp
    private var pauseStartTime: Date?

    /// Whether we have full accuracy authorization (vs reduced)
    private var hasFullAccuracyAuthorization: Bool = false

    // MARK: - Constants

    /// Minimum horizontal accuracy to accept a location point (SAFEGUARD #3)
    private let minimumAccuracyThreshold: CLLocationAccuracy = 50.0

    /// Minimum distance change to record a new point (reduces noise)
    private let minimumDistanceFilter: CLLocationDistance = 5.0

    // MARK: - Initialization

    private override init() {
        super.init()
        setupLocationManager()
    }

    /// SAFEGUARD #2 - Battery Guard: Stop GPS if manager is deallocated
    deinit {
        // Direct calls to CLLocationManager are thread-safe
        locationManager.stopUpdatingLocation()
        locationManager.allowsBackgroundLocationUpdates = false
        elapsedTimer?.invalidate()
    }

    // MARK: - Location Manager Setup

    private func setupLocationManager() {
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.distanceFilter = minimumDistanceFilter

        // SAFEGUARD #1 - Pocket Protection settings
        locationManager.activityType = .fitness
        locationManager.pausesLocationUpdatesAutomatically = false
        // Note: allowsBackgroundLocationUpdates is set only during active recording
    }

    /// SAFEGUARD #4 - Check and update accuracy authorization status
    private func checkAccuracyAuthorization() {
        hasFullAccuracyAuthorization = (locationManager.accuracyAuthorization == .fullAccuracy)
    }

    // MARK: - HealthKit Authorization

    /// Request HealthKit authorization for workout recording
    private func requestHealthKitAuthorization() async throws {
        guard HKHealthStore.isHealthDataAvailable() else {
            throw PhoneWorkoutError.healthKitNotAuthorized
        }

        let typesToWrite: Set<HKSampleType> = [
            HKObjectType.workoutType(),
            HKSeriesType.workoutRoute(),
            HKObjectType.quantityType(forIdentifier: .stepCount)!,
            HKObjectType.quantityType(forIdentifier: .distanceWalkingRunning)!,
            HKObjectType.quantityType(forIdentifier: .activeEnergyBurned)!
        ]

        let typesToRead: Set<HKObjectType> = [
            HKObjectType.workoutType(),
            HKSeriesType.workoutRoute(),
            HKObjectType.quantityType(forIdentifier: .stepCount)!,
            HKObjectType.quantityType(forIdentifier: .distanceWalkingRunning)!,
            HKObjectType.quantityType(forIdentifier: .heartRate)!,
            HKObjectType.quantityType(forIdentifier: .activeEnergyBurned)!
        ]

        try await healthStore.requestAuthorization(toShare: typesToWrite, read: typesToRead)
    }

    // MARK: - Workout Control

    /// Start a new workout session with GPS tracking
    func startWorkout() async throws {
        guard state == .idle else {
            throw PhoneWorkoutError.workoutAlreadyActive
        }

        // Request HealthKit authorization for workout recording
        try await requestHealthKitAuthorization()

        // Request location authorization if needed
        try await requestLocationAuthorizationIfNeeded()

        // SAFEGUARD #4 - Check accuracy authorization
        checkAccuracyAuthorization()

        // Initialize state
        state = .recording
        startTime = Date()
        endTime = nil
        sessionSteps = 0
        sessionDistance = 0
        gpsDistance = 0
        activeCalories = 0
        elapsedTime = 0
        totalPausedTime = 0
        collectedLocations.removeAll()
        liveCoordinates.removeAll()
        previousLocation = nil
        previousStepThousands = 0
        error = nil

        // Setup HKWorkoutBuilder
        let workoutConfiguration = HKWorkoutConfiguration()
        workoutConfiguration.activityType = .walking
        workoutConfiguration.locationType = .outdoor

        workoutBuilder = HKWorkoutBuilder(
            healthStore: healthStore,
            configuration: workoutConfiguration,
            device: .local()
        )

        // Begin workout collection
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            workoutBuilder?.beginCollection(withStart: startTime!) { success, error in
                if success {
                    continuation.resume()
                } else {
                    continuation.resume(throwing: error ?? PhoneWorkoutError.workoutBuilderFailed)
                }
            }
        }

        // SAFEGUARD #4 - Setup route builder only if full accuracy authorized
        if hasFullAccuracyAuthorization {
            routeBuilder = HKWorkoutRouteBuilder(healthStore: healthStore, device: .local())
            isRecordingRoute = true
            print("📍 Route recording enabled (full accuracy)")
        } else {
            routeBuilder = nil
            isRecordingRoute = false
            print("⚠️ Route recording disabled (reduced accuracy - SAFEGUARD #4)")
        }

        // Start location updates
        startLocationUpdates()

        // Start pedometer
        startPedometerUpdates()

        // Start elapsed timer
        startElapsedTimer()

        // Start Live Activity for lock screen/Dynamic Island
        Task {
            let dailySteps = await StepTrackingService.shared.queryTodayStepsFromPedometer() ?? StepRepository.shared.todaySteps
            await ClassicWalkLiveActivityManager.shared.startActivity(
                startTime: startTime!,
                stepsAtStart: dailySteps,
                dailyGoal: StepRepository.shared.stepGoal
            )
        }

        print("🏃 Workout started")
    }

    private func requestLocationAuthorizationIfNeeded() async throws {
        let status = locationManager.authorizationStatus

        switch status {
        case .notDetermined:
            locationManager.requestWhenInUseAuthorization()
            // Give time for user to respond
            try await Task.sleep(nanoseconds: 500_000_000)

        case .denied, .restricted:
            throw PhoneWorkoutError.locationAccessDenied

        case .authorizedWhenInUse, .authorizedAlways:
            break // Ready to go

        @unknown default:
            break
        }
    }

    /// Stop the workout and save to HealthKit
    func stopWorkout() async throws -> PhoneWorkoutSummary {
        guard state == .recording || state == .paused else {
            throw PhoneWorkoutError.noActiveWorkout
        }

        state = .finishing
        endTime = Date()

        // Stop location updates - SAFEGUARD #1
        stopLocationUpdates()

        // Stop pedometer
        pedometer.stopUpdates()

        // Stop elapsed timer
        elapsedTimer?.invalidate()
        elapsedTimer = nil

        // End Live Activity (completed)
        await ClassicWalkLiveActivityManager.shared.endActivity(
            finalSteps: sessionSteps,
            finalDistance: max(sessionDistance, gpsDistance),
            completed: true
        )

        // Calculate final duration
        let duration = elapsedTime

        // Add samples to workout builder
        try await addSamplesToWorkoutBuilder()

        // End workout collection
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            workoutBuilder?.endCollection(withEnd: endTime!, completion: { success, error in
                if success {
                    continuation.resume()
                } else {
                    continuation.resume(throwing: error ?? PhoneWorkoutError.workoutBuilderFailed)
                }
            })
        }

        // Finish workout and get HKWorkout
        let workout: HKWorkout = try await withCheckedThrowingContinuation { continuation in
            workoutBuilder?.finishWorkout(completion: { workout, error in
                if let workout = workout {
                    continuation.resume(returning: workout)
                } else {
                    continuation.resume(throwing: error ?? PhoneWorkoutError.workoutBuilderFailed)
                }
            })
        }

        // Finish route and associate with workout (if route was recorded)
        if routeBuilder != nil, !collectedLocations.isEmpty {
            try await finishRouteBuilder(for: workout)
        }

        // Create summary
        let summary = PhoneWorkoutSummary(
            startTime: startTime!,
            endTime: endTime!,
            duration: duration,
            steps: sessionSteps,
            distance: max(sessionDistance, gpsDistance),
            gpsDistance: gpsDistance,
            calories: activeCalories,
            routeRecorded: isRecordingRoute && !collectedLocations.isEmpty,
            workout: workout,
            hkWorkoutId: workout.uuid
        )

        // Reset state
        resetState()

        print("✅ Workout saved: \(summary.steps) steps, \(summary.formattedDistance)")

        return summary
    }

    private func addSamplesToWorkoutBuilder() async throws {
        guard let startTime = startTime, let endTime = endTime else { return }
        guard let builder = workoutBuilder else { return }

        var samples: [HKSample] = []

        // Step count sample
        if let stepType = HKQuantityType.quantityType(forIdentifier: .stepCount), sessionSteps > 0 {
            let stepQuantity = HKQuantity(unit: .count(), doubleValue: Double(sessionSteps))
            let stepSample = HKQuantitySample(type: stepType, quantity: stepQuantity, start: startTime, end: endTime)
            samples.append(stepSample)
        }

        // Distance sample (use GPS distance if available, otherwise pedometer)
        if let distanceType = HKQuantityType.quantityType(forIdentifier: .distanceWalkingRunning) {
            let distance = max(sessionDistance, gpsDistance)
            if distance > 0 {
                let distanceQuantity = HKQuantity(unit: .meter(), doubleValue: distance)
                let distanceSample = HKQuantitySample(type: distanceType, quantity: distanceQuantity, start: startTime, end: endTime)
                samples.append(distanceSample)
            }
        }

        // Active calories sample
        if let energyType = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned), activeCalories > 0 {
            let energyQuantity = HKQuantity(unit: .kilocalorie(), doubleValue: activeCalories)
            let energySample = HKQuantitySample(type: energyType, quantity: energyQuantity, start: startTime, end: endTime)
            samples.append(energySample)
        }

        guard !samples.isEmpty else { return }

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            builder.add(samples) { success, error in
                if success {
                    continuation.resume()
                } else {
                    continuation.resume(throwing: error ?? PhoneWorkoutError.workoutBuilderFailed)
                }
            }
        }
    }

    private func finishRouteBuilder(for workout: HKWorkout) async throws {
        guard let routeBuilder = routeBuilder else { return }

        // Insert collected locations
        if !collectedLocations.isEmpty {
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                routeBuilder.insertRouteData(collectedLocations) { success, error in
                    if success {
                        continuation.resume()
                    } else {
                        continuation.resume(throwing: error ?? PhoneWorkoutError.routeBuilderFailed)
                    }
                }
            }
        }

        // Finish route and associate with workout
        let locationCount = collectedLocations.count
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            routeBuilder.finishRoute(with: workout, metadata: nil) { route, error in
                if route != nil {
                    continuation.resume()
                    print("📍 Route saved with \(locationCount) points")
                } else {
                    continuation.resume(throwing: error ?? PhoneWorkoutError.routeBuilderFailed)
                }
            }
        }
    }

    private func resetState() {
        state = .idle
        workoutBuilder = nil
        routeBuilder = nil
        isRecordingRoute = false
        collectedLocations.removeAll()
        liveCoordinates.removeAll()
        previousLocation = nil
        previousStepThousands = 0
    }

    /// Pause the workout
    func pauseWorkout() {
        guard state == .recording else { return }

        state = .paused
        pauseStartTime = Date()

        // Stop location updates to save battery
        stopLocationUpdates()

        // Stop pedometer
        pedometer.stopUpdates()

        // Pause Live Activity
        Task {
            await ClassicWalkLiveActivityManager.shared.pauseActivity(
                sessionSteps: sessionSteps,
                sessionDistance: max(sessionDistance, gpsDistance),
                elapsedSeconds: elapsedTime
            )
        }

        print("⏸️ Workout paused")
    }

    /// Resume the workout
    func resumeWorkout() {
        guard state == .paused else { return }

        state = .recording

        // Calculate pause duration
        if let pauseStart = pauseStartTime {
            totalPausedTime += Date().timeIntervalSince(pauseStart)
        }
        pauseStartTime = nil

        // Resume location updates
        startLocationUpdates()

        // Resume pedometer
        startPedometerUpdates()

        // Resume Live Activity
        Task {
            await ClassicWalkLiveActivityManager.shared.resumeActivity(
                sessionSteps: sessionSteps,
                sessionDistance: max(sessionDistance, gpsDistance),
                elapsedSeconds: elapsedTime
            )
        }

        print("▶️ Workout resumed")
    }

    /// Cancel the workout without saving
    func cancelWorkout() {
        guard state != .idle else { return }

        // Stop all tracking
        stopLocationUpdates()
        pedometer.stopUpdates()
        elapsedTimer?.invalidate()
        elapsedTimer = nil

        // End Live Activity (not completed)
        Task {
            await ClassicWalkLiveActivityManager.shared.endActivity(
                finalSteps: sessionSteps,
                finalDistance: max(sessionDistance, gpsDistance),
                completed: false
            )
        }

        // Discard workout builder (don't save)
        workoutBuilder?.discardWorkout()

        // Reset state
        resetState()

        print("🗑️ Workout cancelled")
    }

    // MARK: - Location Updates

    private func startLocationUpdates() {
        // SAFEGUARD #1 - Pocket Protection: Enable background updates during recording
        locationManager.allowsBackgroundLocationUpdates = true
        #if os(iOS)
        locationManager.showsBackgroundLocationIndicator = true
        #endif
        locationManager.startUpdatingLocation()
        print("📍 Location updates started (background mode enabled)")
    }

    private func stopLocationUpdates() {
        locationManager.stopUpdatingLocation()
        // SAFEGUARD #1 - Pocket Protection: Disable background updates when not recording
        locationManager.allowsBackgroundLocationUpdates = false
        #if os(iOS)
        locationManager.showsBackgroundLocationIndicator = false
        #endif
        print("📍 Location updates stopped (background mode disabled)")
    }

    // MARK: - Pedometer Updates

    private func startPedometerUpdates() {
        guard CMPedometer.isStepCountingAvailable() else {
            print("⚠️ Pedometer not available")
            return
        }

        guard let startTime = startTime else { return }

        pedometer.startUpdates(from: startTime) { [weak self] data, error in
            guard let data = data, error == nil else { return }

            Task { @MainActor [weak self] in
                guard let self = self, self.state == .recording else { return }

                let newSteps = data.numberOfSteps.intValue
                let newThousands = newSteps / 1000

                // Check for 1000-step milestone
                if newThousands > self.previousStepThousands {
                    HapticService.shared.playProgressTick()
                    self.previousStepThousands = newThousands
                }

                self.sessionSteps = newSteps
                self.sessionDistance = data.distance?.doubleValue ?? 0
                self.currentPace = data.currentPace?.doubleValue
                self.currentCadence = data.currentCadence?.doubleValue

                // Update Live Activity with current stats
                Task {
                    await ClassicWalkLiveActivityManager.shared.updateActivity(
                        sessionSteps: data.numberOfSteps.intValue,
                        sessionDistance: data.distance?.doubleValue ?? 0,
                        elapsedSeconds: self.elapsedTime,
                        isPaused: false
                    )
                }
            }
        }
    }

    // MARK: - Elapsed Timer

    private func startElapsedTimer() {
        elapsedTimer?.invalidate()

        elapsedTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self = self, self.state == .recording else { return }
                guard let start = self.startTime else { return }

                self.elapsedTime = Date().timeIntervalSince(start) - self.totalPausedTime
            }
        }
    }
}

// MARK: - CLLocationManagerDelegate

extension PhoneWorkoutManager: CLLocationManagerDelegate {

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        Task { @MainActor in
            processLocationUpdates(locations)
        }
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor in
            handleAuthorizationChange()
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor in
            print("⚠️ Location error: \(error.localizedDescription)")
            // Don't fail the workout, just log the error
        }
    }

    // MARK: - Private Location Handling

    private func processLocationUpdates(_ locations: [CLLocation]) {
        guard state == .recording else { return }

        for location in locations {
            // Update accuracy display
            locationAccuracy = location.horizontalAccuracy

            // Update GPS signal status
            let goodSignal = location.horizontalAccuracy >= 0 && location.horizontalAccuracy <= minimumAccuracyThreshold
            if hasGPSSignal != goodSignal {
                hasGPSSignal = goodSignal
            }

            // SAFEGUARD #3 - Accuracy Filter: Skip if > 50m
            guard location.horizontalAccuracy >= 0 &&
                  location.horizontalAccuracy <= minimumAccuracyThreshold else {
                print("📍 Skipping low-accuracy location: \(location.horizontalAccuracy)m (SAFEGUARD #3)")
                continue
            }

            // Calculate GPS distance from previous point
            if let previous = previousLocation {
                let delta = location.distance(from: previous)
                gpsDistance += delta
            }

            previousLocation = location

            // Add to collected locations for route
            if isRecordingRoute {
                collectedLocations.append(location)
                liveCoordinates.append(location.coordinate)
            }

            // Estimate calories (rough: ~0.05 kcal per meter for walking)
            activeCalories = gpsDistance * 0.05
        }
    }

    private func handleAuthorizationChange() {
        let status = locationManager.authorizationStatus

        if status == .denied || status == .restricted {
            error = .locationAccessDenied
        }

        // SAFEGUARD #4 - Re-check accuracy authorization
        checkAccuracyAuthorization()

        // If accuracy changed during recording, update route recording status
        if state == .recording && !hasFullAccuracyAuthorization && isRecordingRoute {
            isRecordingRoute = false
            print("⚠️ Route recording disabled - accuracy reduced (SAFEGUARD #4)")
        }
    }
}
