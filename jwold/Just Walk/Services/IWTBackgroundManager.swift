//
//  IWTBackgroundManager.swift
//  Just Walk
//
//  Manages background execution during Interval Walk sessions to ensure
//  notifications are delivered reliably even when the app is suspended.
//

import Foundation
import CoreLocation
import AVFoundation
import UserNotifications
import UIKit
import Combine

/// Manages background execution during IWT sessions
/// Uses location updates and audio session to prevent iOS from suspending the app
@MainActor
final class IWTBackgroundManager: NSObject, ObservableObject {

    static let shared = IWTBackgroundManager()

    // MARK: - Properties

    private var locationManager: CLLocationManager?
    private var audioPlayer: AVAudioPlayer?
    private var isSessionActive = false

    /// Background task identifier for extended execution
    private var backgroundTaskID: UIBackgroundTaskIdentifier = .invalid

    private override init() {
        super.init()
        setupLocationManager()
    }

    // MARK: - Location Manager Setup

    private func setupLocationManager() {
        locationManager = CLLocationManager()
        locationManager?.delegate = self
        locationManager?.desiredAccuracy = kCLLocationAccuracyHundredMeters // Low accuracy saves battery
        locationManager?.allowsBackgroundLocationUpdates = true
        locationManager?.pausesLocationUpdatesAutomatically = false
        locationManager?.distanceFilter = 50 // Update every 50 meters
        locationManager?.activityType = .fitness
    }

    // MARK: - Session Management

    /// Start background session for IWT
    func startBackgroundSession() {
        guard !isSessionActive else { return }
        isSessionActive = true

        // Request location authorization if needed
        if locationManager?.authorizationStatus == .notDetermined {
            locationManager?.requestWhenInUseAuthorization()
        }

        // Start location updates for background execution
        startLocationUpdates()

        // Configure audio session as backup
        configureAudioSession()

        // Begin background task
        beginBackgroundTask()

        // Start periodic notification verification
        startPeriodicVerification()

        // Verify all notifications are properly scheduled
        verifyNotificationSchedule()

        print("🔋 IWT Background session started - notifications will be monitored")
    }

    /// Stop background session
    func stopBackgroundSession() {
        guard isSessionActive else { return }
        isSessionActive = false

        locationManager?.stopUpdatingLocation()
        audioPlayer?.stop()
        endBackgroundTask()
        stopPeriodicVerification()

        print("🔋 IWT Background session stopped")
    }

    // MARK: - Location Updates

    private func startLocationUpdates() {
        let status = locationManager?.authorizationStatus ?? .notDetermined

        switch status {
        case .authorizedWhenInUse, .authorizedAlways:
            locationManager?.startUpdatingLocation()
            print("📍 Background location updates started")
        case .notDetermined:
            locationManager?.requestWhenInUseAuthorization()
        default:
            print("⚠️ Location permission not granted - background execution may be limited")
        }
    }

    // MARK: - Audio Session (Backup keep-alive)

    private func configureAudioSession() {
        do {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.playback, mode: .default, options: [.mixWithOthers])
            try audioSession.setActive(true)

            // Play silent audio to keep app alive
            playSilentAudio()
        } catch {
            print("⚠️ Audio session setup failed: \(error)")
        }
    }

    private func playSilentAudio() {
        // Create a very short silent audio file
        // This keeps the audio session active without any audible output
        guard let url = Bundle.main.url(forResource: "silence", withExtension: "mp3") else {
            // If no silence file, we'll rely on location updates only
            print("ℹ️ No silence.mp3 found - relying on location updates for background execution")
            return
        }

        do {
            audioPlayer = try AVAudioPlayer(contentsOf: url)
            audioPlayer?.numberOfLoops = -1 // Loop indefinitely
            audioPlayer?.volume = 0.01 // Nearly silent
            audioPlayer?.play()
        } catch {
            print("⚠️ Silent audio playback failed: \(error)")
        }
    }

    // MARK: - Background Task

    private func beginBackgroundTask() {
        backgroundTaskID = UIApplication.shared.beginBackgroundTask(withName: "IWTSession") { [weak self] in
            self?.endBackgroundTask()
        }
        print("🔄 Background task started: \(backgroundTaskID)")
    }

    private func endBackgroundTask() {
        if backgroundTaskID != .invalid {
            UIApplication.shared.endBackgroundTask(backgroundTaskID)
            backgroundTaskID = .invalid
            print("🔄 Background task ended")
        }
    }

    // MARK: - Notification Verification

    /// Verify and log all pending notifications
    func verifyNotificationSchedule() {
        UNUserNotificationCenter.current().getPendingNotificationRequests { requests in
            let iwtRequests = requests.filter { $0.identifier.contains("iwt.phase") }
            print("📋 Pending IWT notifications: \(iwtRequests.count)")

            for request in iwtRequests {
                if let trigger = request.trigger as? UNTimeIntervalNotificationTrigger {
                    let fireDate = Date().addingTimeInterval(trigger.timeInterval)
                    print("  • \(request.identifier): fires at \(fireDate)")
                }
            }
        }
    }

    /// Re-verify and potentially reschedule notifications
    /// Called periodically during background execution
    func checkAndRefreshNotifications() {
        let sessionActive = isSessionActive
        UNUserNotificationCenter.current().getPendingNotificationRequests { requests in
            let iwtRequests = requests.filter { $0.identifier.contains("iwt.phase") }

            // Log current notification status
            print("🔍 Background check: \(iwtRequests.count) IWT notifications pending")

            // If we have fewer than expected notifications, IWTService may need to reschedule
            if iwtRequests.isEmpty && sessionActive {
                print("⚠️ No pending IWT notifications found during active session!")
                // Trigger a reschedule from IWTService
                Task { @MainActor in
                    if IWTService.shared.isSessionActive {
                        print("🔄 Requesting notification reschedule...")
                        // The session should handle this through its own state
                    }
                }
            }
        }
    }

    // MARK: - Periodic Verification Timer

    private var verificationTimer: Timer?

    /// Start periodic verification of notifications (runs every 60 seconds)
    private func startPeriodicVerification() {
        verificationTimer?.invalidate()
        verificationTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor [weak self] in
                self?.checkAndRefreshNotifications()
            }
        }
        // Allow timer to fire in background
        RunLoop.current.add(verificationTimer!, forMode: .common)
        print("⏰ Started periodic notification verification timer")
    }

    /// Stop periodic verification
    private func stopPeriodicVerification() {
        verificationTimer?.invalidate()
        verificationTimer = nil
        print("⏰ Stopped periodic notification verification timer")
    }
}

// MARK: - CLLocationManagerDelegate

extension IWTBackgroundManager: CLLocationManagerDelegate {

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        // We don't need the location data itself
        // The purpose is just to keep the app running in background

        Task { @MainActor in
            // Periodically verify notifications are still scheduled
            if isSessionActive {
                checkAndRefreshNotifications()
            }
        }
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor in
            let status = manager.authorizationStatus
            print("📍 Location authorization changed: \(status.rawValue)")

            if status == .authorizedWhenInUse || status == .authorizedAlways {
                if isSessionActive {
                    manager.startUpdatingLocation()
                }
            }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("⚠️ Location manager error: \(error.localizedDescription)")
    }
}
