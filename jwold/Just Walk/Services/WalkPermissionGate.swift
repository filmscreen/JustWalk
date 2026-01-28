//
//  WalkPermissionGate.swift
//  Just Walk
//
//  Centralized permission validation for starting walks.
//  Checks HealthKit, Motion, and Location permissions before walk start.
//

import Foundation
import HealthKit
import SwiftUI
import Combine
import CoreLocation

@MainActor
final class WalkPermissionGate: ObservableObject {
    static let shared = WalkPermissionGate()

    // MARK: - Published State

    @Published private(set) var canStartWalk: Bool = true
    @Published private(set) var blockingPermission: BlockingPermission? = nil
    @Published private(set) var locationWarning: LocationWarning? = nil

    // MARK: - Dismissal Tracking

    @AppStorage("permissionDismissedThisSession") private var dismissedThisSession = false

    // MARK: - Types

    enum BlockingPermission {
        case healthKitDenied
        case motionDenied
        case bothDenied
        case deviceNotSupported

        var icon: String {
            switch self {
            case .healthKitDenied:
                return "heart.text.square"
            case .motionDenied:
                return "figure.walk"
            case .bothDenied:
                return "exclamationmark.triangle"
            case .deviceNotSupported:
                return "exclamationmark.triangle"
            }
        }

        var title: String {
            switch self {
            case .healthKitDenied:
                return "Health Access Required"
            case .motionDenied:
                return "Motion Access Required"
            case .bothDenied:
                return "Permissions Required"
            case .deviceNotSupported:
                return "Device Not Supported"
            }
        }

        var message: String {
            switch self {
            case .healthKitDenied:
                return "Just Walk needs access to Health to track your steps and progress."
            case .motionDenied:
                return "Just Walk needs motion access to count your steps while walking."
            case .bothDenied:
                return "Just Walk needs Health or Motion access to track your steps."
            case .deviceNotSupported:
                return "This device doesn't support health tracking. Just Walk requires an iPhone with Health capabilities."
            }
        }

        var buttonTitle: String {
            switch self {
            case .healthKitDenied:
                return "Open Health Settings"
            case .motionDenied:
                return "Open Settings"
            case .bothDenied:
                return "Open Settings"
            case .deviceNotSupported:
                return ""
            }
        }

        var opensHealth: Bool {
            switch self {
            case .healthKitDenied:
                return true
            case .motionDenied, .bothDenied, .deviceNotSupported:
                return false
            }
        }
    }

    enum LocationWarning {
        case denied
        case reducedAccuracy

        var message: String {
            switch self {
            case .denied:
                return "Without location access, we can't track your route or calculate accurate distance."
            case .reducedAccuracy:
                return "With reduced location accuracy, your route tracking may be less precise."
            }
        }
    }

    // MARK: - Initialization

    private init() {}

    // MARK: - Public API

    /// Check all permissions and return whether walk can start
    func checkPermissions() async -> Bool {
        await PermissionManager.shared.checkCurrentStatus()
        let pm = PermissionManager.shared

        // Check device support
        guard HKHealthStore.isHealthDataAvailable() else {
            blockingPermission = .deviceNotSupported
            canStartWalk = false
            return false
        }

        // Required: HealthKit OR Motion
        let hasHealthKit = pm.healthKitStatus == .authorized
        let hasMotion = pm.motionStatus == .authorized

        if !hasHealthKit && !hasMotion {
            if pm.healthKitStatus == .denied && pm.motionStatus == .denied {
                blockingPermission = .bothDenied
            } else if pm.healthKitStatus == .denied {
                blockingPermission = .healthKitDenied
            } else {
                blockingPermission = .motionDenied
            }
            canStartWalk = false
            return false
        }

        // Check optional location
        let lpm = LocationPermissionManager.shared
        if lpm.authorizationStatus == .denied || lpm.authorizationStatus == .restricted {
            locationWarning = .denied
        } else if lpm.accuracyAuthorization == .reducedAccuracy {
            locationWarning = .reducedAccuracy
        } else {
            locationWarning = nil
        }

        blockingPermission = nil
        canStartWalk = true
        return true
    }

    func markDismissed() {
        dismissedThisSession = true
    }

    func resetSessionDismissal() {
        dismissedThisSession = false
    }

    var shouldShowLocationWarning: Bool {
        locationWarning != nil && !dismissedThisSession
    }

    // MARK: - Deep Links

    func openHealthSettings() {
        #if os(iOS)
        if let url = URL(string: "x-apple-health://"),
           UIApplication.shared.canOpenURL(url) {
            UIApplication.shared.open(url)
        } else {
            openAppSettings()
        }
        #endif
    }

    func openAppSettings() {
        #if os(iOS)
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
        #endif
    }
}
