//
//  WorkoutHistoryManager.swift
//  Just Walk
//
//  Fetches and manages workout history from SwiftData.
//  Supports freemium gating (7-day limit for free users).
//

import Foundation
import SwiftData
import Combine
import HealthKit

// MARK: - Workout History Item Model

struct WorkoutHistoryItem: Identifiable {
    let id: UUID
    let startDate: Date
    let endDate: Date
    let duration: TimeInterval
    let distance: Double // meters
    let steps: Int?
    let calories: Double?
    let isIWTSession: Bool
    let hkWorkoutId: UUID? // HealthKit workout UUID for fetching route/details

    // MARK: - Computed Properties

    var distanceMiles: Double {
        distance * 0.000621371
    }

    var formattedDistance: String {
        String(format: "%.1f mi", distanceMiles)
    }

    var formattedDuration: String {
        let minutes = Int(duration) / 60
        let hours = minutes / 60
        let remainingMinutes = minutes % 60

        if hours > 0 {
            return "\(hours)h \(remainingMinutes)m"
        } else if minutes > 0 {
            return "\(minutes)m"
        } else {
            let seconds = Int(duration) % 60
            return "\(seconds)s"
        }
    }

    var formattedDate: String {
        let formatter = DateFormatter()
        let calendar = Calendar.current

        if calendar.isDateInToday(startDate) {
            return "Today"
        } else if calendar.isDateInYesterday(startDate) {
            return "Yesterday"
        } else {
            formatter.dateFormat = "EEEE" // "Friday"
            return formatter.string(from: startDate)
        }
    }

    var fullFormattedDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, yyyy" // "Jan 15, 2026"
        return formatter.string(from: startDate)
    }

    var shortDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d" // "Jan 18"
        return formatter.string(from: startDate)
    }

    var timeRange: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a" // "2:30 PM"
        let start = formatter.string(from: startDate)
        let end = formatter.string(from: endDate)
        return "\(start) – \(end)"
    }

    var monthYearKey: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy" // "January 2026"
        return formatter.string(from: startDate)
    }

    var sortableMonthKey: Date {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.year, .month], from: startDate)
        return calendar.date(from: components) ?? startDate
    }
}

// MARK: - Workout History Manager

@MainActor
final class WorkoutHistoryManager: ObservableObject {

    static let shared = WorkoutHistoryManager()

    // MARK: - Published State

    @Published private(set) var workouts: [WorkoutHistoryItem] = []
    @Published private(set) var isLoading = false
    @Published private(set) var error: Error?

    // MARK: - Private

    private var modelContext: ModelContext?
    private let monthsToFetch = 12

    // MARK: - Initialization

    private init() {}

    // MARK: - Public API

    /// Set the model context for querying SwiftData
    func setModelContext(_ context: ModelContext) {
        self.modelContext = context
    }

    /// Sync walking workouts from HealthKit into SwiftData.
    /// Only imports workouts not already tracked (by hkWorkoutId).
    /// This includes workouts from Apple Watch and other sources.
    func syncHealthKitWorkouts() async {
        guard let context = modelContext else {
            print("⚠️ WorkoutHistoryManager: No model context for sync")
            return
        }

        let calendar = Calendar.current
        let endDate = Date()
        guard let startDate = calendar.date(byAdding: .month, value: -monthsToFetch, to: endDate) else {
            return
        }

        do {
            let hkWorkouts = try await HealthKitService.shared.fetchWalkingWorkouts(
                from: startDate,
                to: endDate
            )

            // Fetch existing hkWorkoutIds from SwiftData to avoid duplicates
            let existingDescriptor = FetchDescriptor<WalkingSession>()
            let existingSessions = try context.fetch(existingDescriptor)
            let existingIds = Set(existingSessions.compactMap { $0.hkWorkoutId })

            var importedCount = 0

            for hkWorkout in hkWorkouts {
                // Skip if already in SwiftData
                if existingIds.contains(hkWorkout.uuid) { continue }

                // Create WalkingSession from HKWorkout
                let session = WalkingSession()
                session.startTime = hkWorkout.startDate
                session.endTime = hkWorkout.endDate
                session.duration = hkWorkout.duration
                session.distance = hkWorkout.totalDistance?.doubleValue(for: .meter()) ?? 0
                session.caloriesBurned = hkWorkout.totalEnergyBurned?.doubleValue(for: .kilocalorie()) ?? 0
                session.isIWTSession = false
                session.hkWorkoutId = hkWorkout.uuid

                // Fetch steps separately (not stored on HKWorkout directly)
                if let steps = try? await HealthKitService.shared.fetchSteps(
                    from: hkWorkout.startDate,
                    to: hkWorkout.endDate
                ) {
                    session.steps = steps
                }

                context.insert(session)
                importedCount += 1
            }

            if importedCount > 0 {
                try context.save()
                print("✅ WorkoutHistoryManager: Synced \(importedCount) workouts from HealthKit")
            }

        } catch {
            print("❌ WorkoutHistoryManager: HealthKit sync failed - \(error)")
        }
    }

    /// Fetch walking sessions from SwiftData (last 12 months)
    /// First syncs any new HealthKit workouts (e.g., from Apple Watch)
    func fetchWorkouts() async {
        guard let context = modelContext else {
            print("⚠️ WorkoutHistoryManager: No model context set")
            return
        }

        isLoading = true
        error = nil

        // Sync any new HealthKit workouts (Watch, iPhone) before fetching
        await syncHealthKitWorkouts()

        do {
            let calendar = Calendar.current
            let endDate = Date()
            guard let startDate = calendar.date(byAdding: .month, value: -monthsToFetch, to: endDate) else {
                isLoading = false
                return
            }

            let predicate = #Predicate<WalkingSession> { session in
                session.startTime >= startDate && session.startTime <= endDate
            }

            var descriptor = FetchDescriptor<WalkingSession>(predicate: predicate)
            descriptor.sortBy = [SortDescriptor(\.startTime, order: .reverse)]

            let sessions = try context.fetch(descriptor)

            workouts = sessions.map { session in
                WorkoutHistoryItem(
                    id: session.id,
                    startDate: session.startTime,
                    endDate: session.endTime ?? session.startTime.addingTimeInterval(session.duration),
                    duration: session.duration,
                    distance: session.distance,
                    steps: session.steps,
                    calories: session.caloriesBurned,
                    isIWTSession: session.isIWTSession,
                    hkWorkoutId: session.hkWorkoutId
                )
            }

            print("✅ WorkoutHistoryManager: Fetched \(workouts.count) sessions from SwiftData")
        } catch {
            self.error = error
            print("❌ WorkoutHistoryManager: \(error.localizedDescription)")
        }

        isLoading = false
    }

    /// Get the date of the last workout (most recent)
    var lastWorkoutDate: Date? {
        workouts.first?.startDate
    }

    /// Filter workouts based on subscription status
    /// - Parameter isPro: Whether user has Pro subscription
    /// - Returns: All workouts for Pro, last 7 days for Free
    func filteredWorkouts(isPro: Bool) -> [WorkoutHistoryItem] {
        if isPro {
            return workouts
        } else {
            let sevenDaysAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
            return workouts.filter { $0.startDate >= sevenDaysAgo }
        }
    }

    /// Check if free user has hidden (older) workouts
    /// - Parameter isPro: Whether user has Pro subscription
    /// - Returns: True if there are workouts older than 7 days
    func hasHiddenWorkouts(isPro: Bool) -> Bool {
        guard !isPro else { return false }
        let sevenDaysAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        return workouts.contains { $0.startDate < sevenDaysAgo }
    }

    /// Group workouts by month for display
    /// - Parameter isPro: Whether user has Pro subscription
    /// - Returns: Array of (monthKey, workouts) sorted newest first
    func groupedWorkouts(isPro: Bool) -> [(key: String, workouts: [WorkoutHistoryItem])] {
        let filtered = filteredWorkouts(isPro: isPro)
        let grouped = Dictionary(grouping: filtered) { $0.monthYearKey }

        // Sort by actual date (newest month first)
        return grouped.sorted { first, second in
            guard let firstWorkout = first.value.first,
                  let secondWorkout = second.value.first else {
                return first.key > second.key
            }
            return firstWorkout.sortableMonthKey > secondWorkout.sortableMonthKey
        }.map { (key: $0.key, workouts: $0.value) }
    }

    /// Delete a workout from SwiftData
    /// - Parameter id: The UUID of the workout to delete
    func deleteWorkout(id: UUID) async {
        guard let context = modelContext else {
            print("⚠️ WorkoutHistoryManager: No model context for delete")
            return
        }

        do {
            let targetId = id
            let predicate = #Predicate<WalkingSession> { session in
                session.id == targetId
            }
            let descriptor = FetchDescriptor<WalkingSession>(predicate: predicate)

            if let session = try context.fetch(descriptor).first {
                context.delete(session)
                try context.save()

                // Remove from local array
                workouts.removeAll { $0.id == id }

                print("✅ WorkoutHistoryManager: Deleted workout \(id)")
            }
        } catch {
            print("❌ WorkoutHistoryManager: Failed to delete - \(error.localizedDescription)")
        }
    }
}
