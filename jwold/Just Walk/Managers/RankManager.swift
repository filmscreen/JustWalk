//
//  RankManager.swift
//  Just Walk
//
//  Manages walker identity rank progression.
//  Integrates with workout saves and streak updates.
//

import Foundation
import Combine

// MARK: - Notification

extension Notification.Name {
    static let rankPromoted = Notification.Name("rankPromoted")
}

// MARK: - RankManager

@MainActor
final class RankManager: ObservableObject {

    static let shared = RankManager()

    // MARK: - Published State

    @Published var profile: WalkerProfile

    // MARK: - Private

    private let profileKey = "walkerProfile"
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Initialization

    private init() {
        // Load saved profile or create new one
        if let data = UserDefaults.standard.data(forKey: profileKey),
           let saved = try? JSONDecoder().decode(WalkerProfile.self, from: data) {
            self.profile = saved
        } else {
            self.profile = WalkerProfile()
        }

        // Subscribe to workout saved notifications
        NotificationCenter.default.addObserver(
            forName: .workoutSaved,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                await self?.onWorkoutCompleted()
            }
        }

        // Subscribe to streak updates from StreakService
        StreakService.shared.$currentStreak
            .receive(on: DispatchQueue.main)
            .sink { [weak self] newStreak in
                guard let self = self else { return }
                self.profile.currentStreak = newStreak
                self.profile.longestStreak = max(self.profile.longestStreak, newStreak)
                self.save()
                _ = self.checkForPromotion()
            }
            .store(in: &cancellables)

        // Sync total miles on init
        syncTotalMiles()
    }

    // MARK: - Persistence

    func save() {
        if let data = try? JSONEncoder().encode(profile) {
            UserDefaults.standard.set(data, forKey: profileKey)
        }
    }

    // MARK: - Workout Completion Handler

    private func onWorkoutCompleted() async {
        // Increment walk count
        profile.totalWalks += 1

        // Set first walk date if not set
        if profile.firstWalkDate == nil {
            profile.firstWalkDate = Date()
        }

        // Sync miles from history
        syncTotalMiles()

        save()
        _ = checkForPromotion()

        print("🚶 RankManager: Walk recorded. Total: \(profile.totalWalks), Miles: \(String(format: "%.1f", profile.totalMiles))")
    }

    // MARK: - Miles Sync

    func syncTotalMiles() {
        let historyManager = WorkoutHistoryManager.shared
        let totalMeters = historyManager.workouts.reduce(0.0) { $0 + $1.distance }
        profile.totalMiles = totalMeters * 0.000621371  // meters to miles
        save()
    }

    // MARK: - Promotion Logic

    func checkForPromotion() -> WalkerRank? {
        let newRank = calculateRank()
        if newRank > profile.currentRank {
            let previousRank = profile.currentRank
            profile.currentRank = newRank
            profile.rankAchievedDate = Date()
            save()

            // Post notification for UI celebration
            NotificationCenter.default.post(
                name: .rankPromoted,
                object: nil,
                userInfo: ["newRank": newRank, "previousRank": previousRank]
            )

            print("🏅 RankManager: Promoted to \(newRank.title)!")
            return newRank
        }
        return nil
    }

    private func calculateRank() -> WalkerRank {
        // Just Walker: 365-day streak OR 1000 walks OR 1000 miles
        if profile.currentStreak >= 365 || profile.totalWalks >= 1000 || profile.totalMiles >= 1000 {
            return .justWalker
        }
        // Centurion: 100-day streak OR 500 walks OR 500 miles
        if profile.currentStreak >= 100 || profile.totalWalks >= 500 || profile.totalMiles >= 500 {
            return .centurion
        }
        // Wayfarer: 30-day streak OR 100 walks OR 200 miles
        if profile.currentStreak >= 30 || profile.totalWalks >= 100 || profile.totalMiles >= 200 {
            return .wayfarer
        }
        // Strider: 7-day streak OR 14 walks
        if profile.currentStreak >= 7 || profile.totalWalks >= 14 {
            return .strider
        }
        // Walker: Has completed at least 1 walk
        if profile.totalWalks >= 1 {
            return .walker
        }
        return .walker
    }

    // MARK: - Progress to Next Rank

    /// Returns progress metrics for the next rank.
    /// Each tuple: (current value, required value, metric name)
    func progressToNextRank() -> [(current: Double, required: Double, metric: String)]? {
        switch profile.currentRank {
        case .walker:
            return [
                (Double(profile.currentStreak), 7, "day streak"),
                (Double(profile.totalWalks), 14, "walks")
            ]
        case .strider:
            return [
                (Double(profile.currentStreak), 30, "day streak"),
                (Double(profile.totalWalks), 100, "walks"),
                (profile.totalMiles, 200, "miles")
            ]
        case .wayfarer:
            return [
                (Double(profile.currentStreak), 100, "day streak"),
                (Double(profile.totalWalks), 500, "walks"),
                (profile.totalMiles, 500, "miles")
            ]
        case .centurion:
            return [
                (Double(profile.currentStreak), 365, "day streak"),
                (Double(profile.totalWalks), 1000, "walks"),
                (profile.totalMiles, 1000, "miles")
            ]
        case .justWalker:
            return nil  // Max rank - no further progress
        }
    }

    // MARK: - Closest Path to Next Rank

    /// Returns the single path with highest completion percentage
    func closestPathToNextRank() -> (metric: String, current: Double, required: Double, progress: Double)? {
        guard let allPaths = progressToNextRank() else { return nil }

        let pathsWithProgress = allPaths.map { path in
            let progress = path.required > 0 ? min(path.current / path.required, 1.0) : 0
            return (metric: path.metric, current: path.current, required: path.required, progress: progress)
        }

        return pathsWithProgress.max(by: { $0.progress < $1.progress })
    }

    /// Returns user-friendly tip about fastest path
    func fastestPathHint() -> String? {
        guard let closest = closestPathToNextRank() else { return nil }
        let remaining = Int(closest.required - closest.current)

        switch closest.metric {
        case "day streak":
            return "Your streak is your fastest path!"
        case "walks":
            return "Keep walking! \(remaining) walks to go."
        case "miles":
            return "Keep moving! \(remaining) miles to go."
        default:
            return nil
        }
    }

    // MARK: - Manual Recording (for direct calls)

    func recordWalk(steps: Int, miles: Double) {
        if profile.firstWalkDate == nil {
            profile.firstWalkDate = Date()
        }
        profile.totalWalks += 1
        profile.totalMiles += miles
        save()
        _ = checkForPromotion()
    }

    func updateStreak(_ streak: Int) {
        profile.currentStreak = streak
        if streak > profile.longestStreak {
            profile.longestStreak = streak
        }
        save()
        _ = checkForPromotion()
    }

    // MARK: - Debug / Bonus

    /// Add bonus progress (for testing or challenge rewards)
    func addBonusProgress(walks: Int, miles: Double) {
        profile.totalWalks += walks
        profile.totalMiles += miles
        save()
        _ = checkForPromotion()

        print("🎁 RankManager: Added bonus progress - \(walks) walks, \(String(format: "%.1f", miles)) miles")
    }

    #if DEBUG
    /// Reset profile to initial state (debug only)
    func debugReset() {
        profile = WalkerProfile()
        save()
        print("🔧 RankManager: Profile reset to initial state")
    }

    /// Set a specific rank for testing (debug only)
    func debugSetRank(_ rank: WalkerRank) {
        profile.currentRank = rank
        profile.rankAchievedDate = Date()
        save()
        print("🔧 RankManager: Rank set to \(rank.title)")
    }
    #endif
}
