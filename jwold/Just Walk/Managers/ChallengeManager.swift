//
//  ChallengeManager.swift
//  Just Walk
//
//  Singleton manager for challenge lifecycle.
//  Handles starting, tracking progress, completing, and rewarding challenges.
//

import Foundation
import Combine

/// Notification posted when a challenge is completed
extension Notification.Name {
    static let challengeCompleted = Notification.Name("challengeCompleted")
}

/// Manages the challenge system
@MainActor
final class ChallengeManager: ObservableObject {

    // MARK: - Singleton

    static let shared = ChallengeManager()

    // MARK: - Published State

    /// All available challenges (not started by user)
    @Published private(set) var availableChallenges: [Challenge] = []

    /// Active challenge progress (challenges the user has started)
    @Published private(set) var activeChallenges: [ChallengeProgress] = []

    /// Recently completed challenge (for celebration UI)
    @Published var recentlyCompletedChallenge: Challenge?

    /// Toast state for challenge completion overlay
    @Published var showCompletionToast = false
    @Published var completedChallengeIsPerfect: Bool = false

    // MARK: - Private State

    private var completedChallengeIds: Set<String> = []
    private var abandonedChallengeIds: Set<String> = []
    private var cancellables = Set<AnyCancellable>()

    private let stateKey = "challengeManagerState"

    // MARK: - Initialization

    private init() {
        loadState()
        setupStepObserver()
        refreshAvailableChallenges()
    }

    // MARK: - Step Observer

    private func setupStepObserver() {
        StepRepository.shared.$todaySteps
            .debounce(for: .seconds(5), scheduler: DispatchQueue.main)
            .sink { [weak self] steps in
                self?.updateActiveProgressWithSteps(steps)
            }
            .store(in: &cancellables)
    }

    private func updateActiveProgressWithSteps(_ steps: Int) {
        guard !activeChallenges.isEmpty else { return }

        for index in activeChallenges.indices {
            guard activeChallenges[index].status == .active else { continue }

            let challengeId = activeChallenges[index].challengeId
            guard let challenge = getChallenge(byId: challengeId) else { continue }

            // Update daily progress
            activeChallenges[index].updateTodayProgress(
                steps: steps,
                dailyTarget: challenge.dailyStepTarget
            )

            // Check for completion
            checkForCompletion(progressIndex: index, challenge: challenge)
        }

        saveState()
    }

    // MARK: - Public API

    /// Start a challenge
    /// - Returns: true if successfully started
    @discardableResult
    func startChallenge(_ challenge: Challenge) -> Bool {
        // Can't start completed challenges
        guard !completedChallengeIds.contains(challenge.id) else {
            print("⚠️ ChallengeManager: Challenge already completed: \(challenge.id)")
            return false
        }

        // Can't start if already active
        guard !activeChallenges.contains(where: { $0.challengeId == challenge.id }) else {
            print("⚠️ ChallengeManager: Challenge already active: \(challenge.id)")
            return false
        }

        // Check if challenge is currently available
        guard challenge.isCurrentlyAvailable || challenge.type == .quick else {
            print("⚠️ ChallengeManager: Challenge not currently available: \(challenge.id)")
            return false
        }

        // Create progress tracker
        var progress = ChallengeProgress(challengeId: challenge.id)
        progress.start(durationHours: challenge.durationHours)

        // Initialize with current steps if it's a quick challenge
        if challenge.isQuickChallenge {
            let currentSteps = StepRepository.shared.todaySteps
            progress.updateTodayProgress(steps: currentSteps, dailyTarget: challenge.dailyStepTarget)
        }

        activeChallenges.append(progress)

        // Remove from abandoned if it was there
        abandonedChallengeIds.remove(challenge.id)

        saveState()
        refreshAvailableChallenges()

        print("✅ ChallengeManager: Started challenge: \(challenge.title)")
        return true
    }

    /// Abandon an active challenge
    func abandonChallenge(_ challengeId: String) {
        guard let index = activeChallenges.firstIndex(where: { $0.challengeId == challengeId }) else {
            return
        }

        activeChallenges.remove(at: index)
        abandonedChallengeIds.insert(challengeId)

        saveState()
        refreshAvailableChallenges()

        print("✅ ChallengeManager: Abandoned challenge: \(challengeId)")
    }

    /// Update daily progress (called on app foreground)
    func updateDailyProgress() {
        let steps = StepRepository.shared.todaySteps
        updateActiveProgressWithSteps(steps)
        checkExpiredChallenges()
    }

    /// Refresh available challenges based on current date
    func refreshAvailableChallenges() {
        let allChallenges = ChallengeDatabase.availableChallenges()

        // Filter out completed, active, and abandoned challenges
        let activeChallengeIds = Set(activeChallenges.map { $0.challengeId })

        availableChallenges = allChallenges.filter { challenge in
            !completedChallengeIds.contains(challenge.id) &&
            !activeChallengeIds.contains(challenge.id) &&
            (challenge.type == .quick || !abandonedChallengeIds.contains(challenge.id)) &&
            (challenge.isCurrentlyAvailable || challenge.type == .quick)
        }

        // Sort: quick first, then by difficulty
        availableChallenges.sort { lhs, rhs in
            if lhs.type == .quick && rhs.type != .quick { return true }
            if lhs.type != .quick && rhs.type == .quick { return false }
            return lhs.difficultyLevel < rhs.difficultyLevel
        }
    }

    /// Get challenge by ID from available or database
    func getChallenge(byId id: String) -> Challenge? {
        if let available = availableChallenges.first(where: { $0.id == id }) {
            return available
        }
        return ChallengeDatabase.availableChallenges().first(where: { $0.id == id })
    }

    /// Get progress for a specific challenge
    func getProgress(forChallengeId id: String) -> ChallengeProgress? {
        activeChallenges.first(where: { $0.challengeId == id })
    }

    /// Check if a challenge is completed
    func isChallengeCompleted(_ challengeId: String) -> Bool {
        completedChallengeIds.contains(challengeId)
    }

    // MARK: - Completion Logic

    private func checkForCompletion(progressIndex: Int, challenge: Challenge) {
        var progress = activeChallenges[progressIndex]

        if challenge.isQuickChallenge {
            // Quick challenge: check if steps met within time
            if progress.isQuickChallengeExpired {
                // Time ran out - fail
                progress.fail()
                activeChallenges[progressIndex] = progress
                print("❌ ChallengeManager: Quick challenge failed (time expired): \(challenge.title)")
            } else if progress.totalSteps >= challenge.dailyStepTarget {
                // Steps met within time - success!
                completeChallenge(progressIndex: progressIndex, challenge: challenge)
            }
        } else {
            // Multi-day challenge: check if required days completed
            if progress.daysCompleted >= challenge.targetDays {
                completeChallenge(progressIndex: progressIndex, challenge: challenge)
            }
        }
    }

    private func completeChallenge(progressIndex: Int, challenge: Challenge) {
        let progress = activeChallenges[progressIndex]
        activeChallenges[progressIndex].complete()
        completedChallengeIds.insert(challenge.id)

        // Set for celebration UI
        recentlyCompletedChallenge = challenge

        // Calculate isPerfect: no missed days (daysCompleted == targetDays)
        let isPerfect = progress.daysCompleted == challenge.targetDays

        // Set toast state
        completedChallengeIsPerfect = isPerfect
        showCompletionToast = true

        // Post notification
        NotificationCenter.default.post(name: .challengeCompleted, object: challenge)

        saveState()

        print("🎉 ChallengeManager: Completed challenge: \(challenge.title), perfect: \(isPerfect)")
    }

    private func checkExpiredChallenges() {
        let now = Date()

        for index in activeChallenges.indices {
            guard activeChallenges[index].status == .active else { continue }

            let challengeId = activeChallenges[index].challengeId
            guard let challenge = getChallenge(byId: challengeId) else { continue }

            // Check if multi-day challenge has expired
            if !challenge.isQuickChallenge && now > challenge.endDate {
                activeChallenges[index].fail()
                print("❌ ChallengeManager: Challenge expired: \(challenge.title)")
            }

            // Check if quick challenge timer expired
            if challenge.isQuickChallenge && activeChallenges[index].isQuickChallengeExpired {
                activeChallenges[index].fail()
                print("❌ ChallengeManager: Quick challenge time expired: \(challenge.title)")
            }
        }

        // Remove failed challenges from active list after a delay
        activeChallenges.removeAll { $0.status == .failed || $0.status == .expired }

        saveState()
    }

    // MARK: - Persistence

    private func saveState() {
        let state = ChallengeManagerState(
            activeProgress: activeChallenges,
            completedChallengeIds: completedChallengeIds,
            lastUpdated: Date(),
            abandonedChallengeIds: abandonedChallengeIds
        )

        do {
            let data = try JSONEncoder().encode(state)
            UserDefaults.standard.set(data, forKey: stateKey)
        } catch {
            print("❌ ChallengeManager: Failed to save state: \(error)")
        }
    }

    private func loadState() {
        guard let data = UserDefaults.standard.data(forKey: stateKey) else {
            print("ℹ️ ChallengeManager: No saved state found")
            return
        }

        do {
            let state = try JSONDecoder().decode(ChallengeManagerState.self, from: data)
            activeChallenges = state.activeProgress
            completedChallengeIds = state.completedChallengeIds
            abandonedChallengeIds = state.abandonedChallengeIds

            print("✅ ChallengeManager: Loaded state - \(activeChallenges.count) active challenges")
        } catch {
            print("❌ ChallengeManager: Failed to load state: \(error)")
        }
    }

    // MARK: - Debug

    #if DEBUG
    func resetForTesting() {
        activeChallenges = []
        completedChallengeIds = []
        abandonedChallengeIds = []
        recentlyCompletedChallenge = nil
        UserDefaults.standard.removeObject(forKey: stateKey)
        refreshAvailableChallenges()
        print("🧪 ChallengeManager: Reset for testing")
    }

    func debugCompleteChallenge(_ challengeId: String) {
        guard let challenge = getChallenge(byId: challengeId) else { return }

        if let index = activeChallenges.firstIndex(where: { $0.challengeId == challengeId }) {
            completeChallenge(progressIndex: index, challenge: challenge)
        } else {
            // Start and immediately complete
            var progress = ChallengeProgress(challengeId: challengeId)
            progress.start(durationHours: challenge.durationHours)
            progress.complete()
            activeChallenges.append(progress)
            completeChallenge(progressIndex: activeChallenges.count - 1, challenge: challenge)
        }
    }
    #endif
}
