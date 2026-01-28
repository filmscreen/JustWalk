//
//  SessionPersistenceService.swift
//  Just Walk
//
//  Created by Randy Chia on 1/8/26.
//

import Foundation
import SwiftData
import Combine

/// Service for persisting walking sessions to SwiftData
@MainActor
final class SessionPersistenceService {

    static let shared = SessionPersistenceService()

    private var modelContext: ModelContext?

    private init() {}

    /// Set the model context for persistence
    func setModelContext(_ context: ModelContext) {
        self.modelContext = context
    }

    // MARK: - Save Sessions

    /// Save a walking session to SwiftData and optionally to HealthKit
    func saveIWTSession(
        _ summary: IWTSessionSummary,
        steps: Int,
        distance: Double,
        isIWTSession: Bool,
        hkWorkoutId: UUID? = nil
    ) async throws {
        print("💾 SessionPersistenceService.saveIWTSession called")
        print("💾 hkWorkoutId parameter: \(hkWorkoutId?.uuidString ?? "nil")")

        guard let context = modelContext else {
            print("❌ SessionPersistenceService: No model context!")
            throw PersistenceError.noContext
        }

        // Calculate calories burned (use Watch data if available, else rough estimate: ~0.04 cal per step)
        let calories = summary.activeCalories > 0 ? summary.activeCalories : Double(steps) * 0.04

        // Calculate average pace
        let duration = summary.endTime.timeIntervalSince(summary.startTime)
        let averagePace = distance > 0 ? (duration / distance) * 1000 / 60 : 0

        // Create SwiftData session
        let session = WalkingSession(
            startTime: summary.startTime,
            endTime: summary.endTime,
            steps: steps,
            distance: distance,
            duration: duration,
            isIWTSession: isIWTSession,
            briskIntervals: summary.briskIntervals,
            slowIntervals: summary.slowIntervals,
            averagePace: averagePace,
            caloriesBurned: calories,
            hkWorkoutId: hkWorkoutId
        )

        context.insert(session)
        print("💾 Session inserted with hkWorkoutId: \(session.hkWorkoutId?.uuidString ?? "nil")")

        do {
            try context.save()
            print("✅ Session saved successfully to SwiftData")

            // Update daily stats
            try await updateDailyStats(for: summary.startTime, context: context)

            // NOTE: HealthKit write removed - we are READ-ONLY from HealthKit now.
            // Sessions are persisted to SwiftData (syncs to CloudKit), not to HealthKit.
            // This prevents duplicate step data and simplifies the data architecture.

            // Notify that a workout was saved (for UI refresh)
            NotificationCenter.default.post(name: .workoutSaved, object: nil)
        } catch {
            throw PersistenceError.saveFailed(error)
        }
    }

    // MARK: - Daily Stats

    /// Update or create daily stats for a given date
    private func updateDailyStats(for date: Date, context: ModelContext) async throws {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)

        // Fetch existing daily stats for this date
        let predicate = #Predicate<DailyStats> { stats in
            stats.date == startOfDay
        }

        let descriptor = FetchDescriptor<DailyStats>(predicate: predicate)
        let existingStats = try context.fetch(descriptor).first

        // Fetch all sessions for this day
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!
        let sessionPredicate = #Predicate<WalkingSession> { session in
            session.startTime >= startOfDay && session.startTime < endOfDay
        }

        let sessionDescriptor = FetchDescriptor<WalkingSession>(predicate: sessionPredicate)
        let sessions = try context.fetch(sessionDescriptor)

        // Calculate totals
        let totalSteps = sessions.reduce(0) { $0 + $1.steps }
        let totalDistance = sessions.reduce(0) { $0 + $1.distance }
        let totalDuration = sessions.reduce(0) { $0 + $1.duration }
        let totalCalories = sessions.reduce(0) { $0 + $1.caloriesBurned }
        let iwtSessions = sessions.filter { $0.isIWTSession }.count

        // Get user's actual step goal
        let userGoal = StepTrackingService.shared.stepGoal
        let goalReached = totalSteps >= userGoal

        if let stats = existingStats {
            // Update existing stats
            let wasGoalReached = stats.goalReached
            stats.totalSteps = totalSteps
            stats.totalDistance = totalDistance
            stats.totalDuration = totalDuration
            stats.sessionsCompleted = sessions.count
            stats.iwtSessionsCompleted = iwtSessions
            stats.goalReached = goalReached
            stats.caloriesBurned = totalCalories
            stats.historicalGoal = userGoal  // Snapshot current goal (prevents retroactive changes)

            // Notify streak service if goal was just reached
            if goalReached && !wasGoalReached {
                StreakService.shared.goalReached(for: date, context: context)
            }
        } else {
            // Create new stats
            let newStats = DailyStats(
                date: startOfDay,
                totalSteps: totalSteps,
                totalDistance: totalDistance,
                totalDuration: totalDuration,
                sessionsCompleted: sessions.count,
                iwtSessionsCompleted: iwtSessions,
                goalReached: goalReached,
                caloriesBurned: totalCalories,
                historicalGoal: userGoal  // Snapshot current goal (prevents retroactive changes)
            )
            context.insert(newStats)

            // Notify streak service if goal reached on creation
            if goalReached {
                StreakService.shared.goalReached(for: date, context: context)
            }
        }

        try context.save()
    }

    // MARK: - Fetch Sessions

    /// Fetch all IWT sessions
    func fetchIWTSessions(limit: Int = 20) throws -> [WalkingSession] {
        guard let context = modelContext else {
            throw PersistenceError.noContext
        }

        let predicate = #Predicate<WalkingSession> { session in
            session.isIWTSession == true
        }

        var descriptor = FetchDescriptor<WalkingSession>(predicate: predicate)
        descriptor.sortBy = [SortDescriptor(\.startTime, order: .reverse)]
        descriptor.fetchLimit = limit

        return try context.fetch(descriptor)
    }

    /// Fetch sessions for a specific date
    func fetchSessions(for date: Date) throws -> [WalkingSession] {
        guard let context = modelContext else {
            throw PersistenceError.noContext
        }

        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        guard let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) else {
            return []
        }

        let predicate = #Predicate<WalkingSession> { session in
            session.startTime >= startOfDay && session.startTime < endOfDay
        }

        var descriptor = FetchDescriptor<WalkingSession>(predicate: predicate)
        descriptor.sortBy = [SortDescriptor(\.startTime, order: .reverse)]

        return try context.fetch(descriptor)
    }

    /// Fetch daily stats for a date range
    func fetchDailyStats(from startDate: Date, to endDate: Date) throws -> [DailyStats] {
        guard let context = modelContext else {
            throw PersistenceError.noContext
        }

        let predicate = #Predicate<DailyStats> { stats in
            stats.date >= startDate && stats.date <= endDate
        }

        var descriptor = FetchDescriptor<DailyStats>(predicate: predicate)
        descriptor.sortBy = [SortDescriptor(\.date, order: .forward)]

        return try context.fetch(descriptor)
    }
}

// MARK: - Errors

enum PersistenceError: LocalizedError {
    case noContext
    case saveFailed(Error)

    var errorDescription: String? {
        switch self {
        case .noContext:
            return "Database context not initialized."
        case .saveFailed(let error):
            return "Failed to save session: \(error.localizedDescription)"
        }
    }
}

// MARK: - Notifications

extension Notification.Name {
    static let workoutSaved = Notification.Name("workoutSaved")
}
