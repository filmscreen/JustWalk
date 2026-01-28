//
//  WatchHealthKitManager.swift
//  JustWalkWatch Watch App
//
//  HealthKit integration for watchOS with simulator fallback
//

import Foundation
import HealthKit
import os

@Observable
class WatchHealthKitManager {
    static let shared = WatchHealthKitManager()

    private static let logger = Logger(subsystem: "com.justwalk.watch", category: "HealthKit")

    private let healthStore = HKHealthStore()

    var todaySteps: Int = 0
    var isAuthorized: Bool = false
    var authorizationDenied: Bool = false
    var healthDataUnavailable: Bool = false

    #if targetEnvironment(simulator)
    private let isSimulator = true
    private let mockDailySteps = 4500
    #else
    private let isSimulator = false
    private let mockDailySteps = 0
    #endif

    private init() {}

    // MARK: - Authorization

    func requestAuthorization() async -> Bool {
        if isSimulator {
            isAuthorized = true
            todaySteps = mockStepsForTimeOfDay()
            return true
        }

        guard HKHealthStore.isHealthDataAvailable() else {
            healthDataUnavailable = true
            Self.logger.warning("HealthKit not available on this device")
            return false
        }

        let stepType = HKQuantityType(.stepCount)
        let distanceType = HKQuantityType(.distanceWalkingRunning)
        let dobType = HKObjectType.characteristicType(forIdentifier: .dateOfBirth)!
        let typesToRead: Set<HKObjectType> = [stepType, distanceType, dobType]

        do {
            try await healthStore.requestAuthorization(toShare: [], read: typesToRead)
            isAuthorized = true
            authorizationDenied = false
            return true
        } catch {
            Self.logger.error("HealthKit authorization failed: \(error.localizedDescription)")
            authorizationDenied = true
            return false
        }
    }

    // MARK: - Today Steps

    func fetchTodaySteps() async -> Int {
        if isSimulator {
            let steps = mockStepsForTimeOfDay()
            todaySteps = steps
            return steps
        }

        guard isAuthorized else {
            Self.logger.info("Skipping step fetch — not authorized")
            return 0
        }

        let stepType = HKQuantityType(.stepCount)
        let now = Date()
        let startOfDay = Calendar.current.startOfDay(for: now)
        let predicate = HKQuery.predicateForSamples(withStart: startOfDay, end: now, options: .strictStartDate)

        let steps = await querySum(type: stepType, predicate: predicate, unit: .count())
        todaySteps = Int(steps)
        return Int(steps)
    }

    // MARK: - Walk Data

    func fetchStepsDuring(start: Date, end: Date) async -> Int {
        if isSimulator {
            let minutes = end.timeIntervalSince(start) / 60
            return Int(minutes * 100)
        }

        let stepType = HKQuantityType(.stepCount)
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)
        return Int(await querySum(type: stepType, predicate: predicate, unit: .count()))
    }

    func fetchDistanceDuring(start: Date, end: Date) async -> Double {
        if isSimulator {
            let minutes = end.timeIntervalSince(start) / 60
            return minutes * 80
        }

        let distanceType = HKQuantityType(.distanceWalkingRunning)
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)
        return await querySum(type: distanceType, predicate: predicate, unit: .meter())
    }

    // MARK: - Private

    private func querySum(type: HKQuantityType, predicate: NSPredicate, unit: HKUnit) async -> Double {
        await withCheckedContinuation { continuation in
            let query = HKStatisticsQuery(
                quantityType: type,
                quantitySamplePredicate: predicate,
                options: .cumulativeSum
            ) { _, result, error in
                if let error = error {
                    Self.logger.error("HealthKit query failed for \(type.identifier): \(error.localizedDescription)")
                    continuation.resume(returning: 0)
                    return
                }
                guard let result = result, let sum = result.sumQuantity() else {
                    continuation.resume(returning: 0)
                    return
                }
                continuation.resume(returning: sum.doubleValue(for: unit))
            }
            healthStore.execute(query)
        }
    }

    private func mockStepsForTimeOfDay() -> Int {
        let calendar = Calendar.current
        let now = Date()
        let startOfDay = calendar.startOfDay(for: now)
        let secondsElapsed = now.timeIntervalSince(startOfDay)
        let progress = secondsElapsed / 86400
        return Int(Double(mockDailySteps) * progress)
    }
}
