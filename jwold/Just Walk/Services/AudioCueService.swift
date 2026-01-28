//
//  AudioCueService.swift
//  Just Walk
//
//  Audio cueing service for Power Walk intervals.
//  Provides voice guidance, sound effects, and music ducking.
//

import AVFoundation
import Combine

/// Audio cueing service for Power Walk intervals
@MainActor
final class AudioCueService: NSObject, ObservableObject {
    static let shared = AudioCueService()

    // MARK: - Settings (Published for UI binding)

    @Published var voiceGuidanceEnabled: Bool = true {
        didSet { saveSettings() }
    }
    @Published var countdownEnabled: Bool = true {
        didSet { saveSettings() }
    }
    @Published var soundEffectsEnabled: Bool = true {
        didSet { saveSettings() }
    }
    @Published var duckMusicEnabled: Bool = true {
        didSet { saveSettings() }
    }
    @Published var preWarningsEnabled: Bool = true {
        didSet { saveSettings() }
    }
    @Published var stepMilestonesEnabled: Bool = true {
        didSet { saveSettings() }
    }
    @Published var goalReachedAudioEnabled: Bool = true {
        didSet { saveSettings() }
    }
    @Published var achievementAudioEnabled: Bool = true {
        didSet { saveSettings() }
    }
    @Published var routeGuidanceEnabled: Bool = true {
        didSet { saveSettings() }
    }

    // MARK: - Audio Components

    private let speechSynthesizer = AVSpeechSynthesizer()
    private var soundPlayers: [SoundEffect: AVAudioPlayer] = [:]

    // MARK: - State

    private var isDucking: Bool = false
    private var lastCueTime: Date = .distantPast
    private var variationIndices: [CueType: Int] = [:]
    private var announcedPreWarnings: Set<String> = []
    private var announcedCountdowns: Set<Int> = []

    // MARK: - Cue Variations

    private let easyToBriskCues = [
        "Brisk. Pick it up.",
        "Time to push. Brisk pace.",
        "Let's go brisk."
    ]

    private let briskToEasyCues = [
        "Easy. Slow it down.",
        "Nice work. Easy pace now.",
        "Recover. Take it easy."
    ]

    private enum CueType: Hashable {
        case easyToBrisk
        case briskToEasy
    }

    // MARK: - Persistence Keys

    private let settingsKey = "audioCue_settings"

    // MARK: - Initialization

    override private init() {
        super.init()
        speechSynthesizer.delegate = self
        loadSettings()
        preloadSounds()
        configureAudioSession()

        // Register for interruption notifications
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleInterruption),
            name: AVAudioSession.interruptionNotification,
            object: nil
        )
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    // MARK: - Audio Session Configuration

    /// Configure audio session for voice cues with music ducking
    func configureAudioSession() {
        do {
            let session = AVAudioSession.sharedInstance()

            // .playback allows audio when locked
            // .duckOthers reduces other app volume during our audio
            // .interruptSpokenAudioAndMixWithOthers handles podcasts properly
            try session.setCategory(
                .playback,
                mode: .voicePrompt,
                options: [.duckOthers, .interruptSpokenAudioAndMixWithOthers]
            )

            try session.setActive(true)
        } catch {
            print("❌ Audio session configuration failed: \(error)")
        }
    }

    /// Configure for background execution
    func configureForBackground() {
        configureAudioSession()
    }

    // MARK: - Music Ducking

    /// Begin ducking other audio (before playing cue)
    private func beginDucking() {
        guard duckMusicEnabled, !isDucking else { return }

        do {
            let session = AVAudioSession.sharedInstance()
            try session.setActive(true, options: [])
            isDucking = true
        } catch {
            print("❌ Failed to begin ducking: \(error)")
        }
    }

    /// End ducking (after cue completes)
    private func endDucking() {
        guard isDucking else { return }

        // Delay slightly to prevent audio pop
        Task {
            try? await Task.sleep(nanoseconds: 500_000_000) // 0.5s

            do {
                let session = AVAudioSession.sharedInstance()
                try session.setActive(false, options: [.notifyOthersOnDeactivation])
                await MainActor.run {
                    self.isDucking = false
                }
            } catch {
                print("❌ Failed to end ducking: \(error)")
            }
        }
    }

    // MARK: - Speech

    /// Speak a voice cue with optional sound effect
    func speak(
        _ text: String,
        soundEffect: SoundEffect? = nil,
        priority: CuePriority = .normal
    ) {
        guard voiceGuidanceEnabled else {
            // Still play sound effect even if voice off
            if let effect = soundEffect, soundEffectsEnabled {
                playSound(effect)
            }
            return
        }

        // Check minimum spacing (except for high priority)
        let now = Date()
        let minimumSpacing: TimeInterval = priority == .high ? 0.5 : 1.5
        guard now.timeIntervalSince(lastCueTime) >= minimumSpacing else {
            return // Skip if too soon after last cue
        }
        lastCueTime = now

        // Begin ducking
        beginDucking()

        // Play sound effect first (if any)
        if let effect = soundEffect, soundEffectsEnabled {
            playSound(effect)
        }

        // Configure utterance
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
        utterance.rate = 0.52  // Slightly faster than default (0.5)
        utterance.pitchMultiplier = 1.0
        utterance.volume = 1.0
        utterance.preUtteranceDelay = soundEffect != nil ? 0.3 : 0.1  // Wait for sound effect
        utterance.postUtteranceDelay = 0.3

        // Speak
        speechSynthesizer.speak(utterance)
    }

    /// Stop any current speech
    func stopSpeaking() {
        speechSynthesizer.stopSpeaking(at: .immediate)
        endDucking()
    }

    // MARK: - Sound Effects

    /// Preload sound effects for instant playback
    func preloadSounds() {
        for effect in SoundEffect.allCases {
            guard let url = Bundle.main.url(
                forResource: effect.rawValue,
                withExtension: "mp3"
            ) else {
                // Sound file not found - will use system sounds as fallback
                continue
            }

            do {
                let player = try AVAudioPlayer(contentsOf: url)
                player.prepareToPlay()
                soundPlayers[effect] = player
            } catch {
                print("❌ Failed to load sound \(effect.rawValue): \(error)")
            }
        }
    }

    /// Play a sound effect
    func playSound(_ effect: SoundEffect) {
        guard soundEffectsEnabled else { return }

        if let player = soundPlayers[effect] {
            player.currentTime = 0
            player.play()
        } else {
            // Fallback to system sound
            playSystemSound(for: effect)
        }
    }

    /// Fallback to system sounds if custom sounds not available
    private func playSystemSound(for effect: SoundEffect) {
        let soundID: SystemSoundID
        switch effect {
        case .briskStart:
            soundID = 1025 // Ascending
        case .easyStart:
            soundID = 1026 // Descending
        case .workoutComplete:
            soundID = 1025 // Fanfare-like
        case .countdown:
            soundID = 1057 // Tick
        case .milestone:
            soundID = 1054 // Ding
        case .goalReached:
            soundID = 1025 // Celebration
        }
        AudioServicesPlaySystemSound(soundID)
    }

    // MARK: - Phase Transition Cues

    /// Announce phase transition
    func announcePhaseTransition(
        from previousPhase: PowerWalkPhase,
        to newPhase: PowerWalkPhase,
        context: PhaseContext
    ) {
        // Reset per-phase tracking
        announcedPreWarnings.removeAll()
        announcedCountdowns.removeAll()

        let text: String
        let sound: SoundEffect?

        switch (previousPhase, newPhase, context) {
        // Workout start
        case (_, .easy, .workoutStart):
            text = "Let's start easy. Find a comfortable pace."
            sound = nil

        // Warmup start
        case (_, .easy, .warmupStart):
            text = "Starting warmup. 2 minutes easy pace."
            sound = nil

        // Warmup complete → First intervals
        case (.easy, .easy, .warmupComplete):
            text = "Warmup complete. Get ready for intervals."
            sound = nil

        // Easy → Brisk
        case (.easy, .brisk, .firstBrisk):
            text = "First brisk interval. You've got this."
            sound = .briskStart

        case (.easy, .brisk, .lastBrisk):
            text = "Final push. Give it everything."
            sound = .briskStart

        case (.easy, .brisk, _):
            text = getNextVariation(from: easyToBriskCues, for: .easyToBrisk)
            sound = .briskStart

        // Brisk → Easy
        case (.brisk, .easy, .lastEasy):
            text = "Last interval. Nice and easy to the finish."
            sound = .easyStart

        case (.brisk, .easy, _):
            text = getNextVariation(from: briskToEasyCues, for: .briskToEasy)
            sound = .easyStart

        // Cooldown
        case (_, .easy, .cooldownStart):
            text = "Starting cooldown. 2 minutes to finish."
            sound = .easyStart

        // Workout complete
        case (_, .completed, _):
            text = "Workout complete. You crushed it."
            sound = .workoutComplete

        default:
            return
        }

        speak(text, soundEffect: sound, priority: .high)

        // Play phase-specific haptic
        switch newPhase {
        case .brisk:
            HapticService.shared.playBriskStart()
        case .easy:
            HapticService.shared.playEasyStart()
        case .completed:
            HapticService.shared.playWorkoutComplete()
        }
    }

    /// Announce pre-warning (10 seconds before transition)
    func announcePreWarning(nextPhase: PowerWalkPhase) {
        guard preWarningsEnabled else { return }

        // Prevent duplicate announcements
        let key = "preWarning_\(nextPhase.rawValue)"
        guard !announcedPreWarnings.contains(key) else { return }
        announcedPreWarnings.insert(key)

        let text: String
        switch nextPhase {
        case .brisk:
            text = "10 seconds to brisk"
        case .easy:
            text = "10 seconds to easy"
        default:
            return
        }

        speak(text, priority: .normal)

        // Play pre-warning haptic
        HapticService.shared.playPreWarning()
    }

    /// Announce countdown
    func announceCountdown(_ count: Int) {
        guard countdownEnabled, count >= 1, count <= 3 else { return }

        // Prevent duplicate announcements
        guard !announcedCountdowns.contains(count) else { return }
        announcedCountdowns.insert(count)

        speak("\(count)", soundEffect: .countdown, priority: .low)
    }

    // MARK: - Milestone Cues

    /// Announce step milestone
    func announceStepMilestone(_ steps: Int) {
        guard stepMilestonesEnabled else { return }

        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        let stepsFormatted = formatter.string(from: NSNumber(value: steps)) ?? "\(steps)"
        let text = "\(stepsFormatted) steps"

        speak(text, soundEffect: .milestone, priority: .low)

        // Play step milestone haptic
        HapticService.shared.playStepMilestone()
    }

    /// Announce halfway to goal
    func announceHalfwayToGoal() {
        guard stepMilestonesEnabled else { return }
        speak("Halfway to your goal", soundEffect: .milestone, priority: .normal)
    }

    /// Announce goal reached
    func announceGoalReached() {
        speak("Goal complete! Amazing!", soundEffect: .goalReached, priority: .high)
        HapticService.shared.playGoalReached()
    }

    // MARK: - Route Guidance

    /// Announce turn instruction
    func announceTurn(_ instruction: TurnInstruction) {
        guard routeGuidanceEnabled, voiceGuidanceEnabled else { return }
        speak(instruction.voicePrompt, priority: .normal)
    }

    /// Announce "turn now" when very close
    func announceImmediateTurn(_ maneuver: TurnManeuver) {
        guard routeGuidanceEnabled, voiceGuidanceEnabled else { return }
        speak("\(maneuver.displayName) now", priority: .high)
    }

    /// Announce off-route
    func announceOffRoute() {
        guard routeGuidanceEnabled, voiceGuidanceEnabled else { return }
        speak("You appear to be off route", priority: .high)
    }

    /// Announce back on route
    func announceBackOnRoute() {
        guard routeGuidanceEnabled, voiceGuidanceEnabled else { return }
        speak("Back on route", priority: .normal)
    }

    /// Announce arrival at destination
    func announceArrival() {
        guard routeGuidanceEnabled, voiceGuidanceEnabled else { return }
        speak("Approaching your starting point", soundEffect: .workoutComplete, priority: .high)
    }

    // MARK: - Session Lifecycle

    /// Called when session starts
    func onSessionStart() {
        configureAudioSession()
        preloadSounds()
        variationIndices.removeAll()
        announcedPreWarnings.removeAll()
        announcedCountdowns.removeAll()
    }

    /// Called when session ends
    func onSessionEnd() {
        stopSpeaking()
    }

    /// Called on phase time update - handles pre-warnings and countdown
    func onPhaseTimeUpdate(remaining: TimeInterval, nextPhase: PowerWalkPhase) {
        // Pre-warning at 10 seconds
        if remaining <= 10.5 && remaining > 9.5 {
            announcePreWarning(nextPhase: nextPhase)
        }

        // Countdown
        if remaining <= 3.5 && remaining > 2.5 {
            announceCountdown(3)
        } else if remaining <= 2.5 && remaining > 1.5 {
            announceCountdown(2)
        } else if remaining <= 1.5 && remaining > 0.5 {
            announceCountdown(1)
        }
    }

    /// Called when steps are updated - handles milestones
    func onStepsUpdated(totalSteps: Int, previousSteps: Int, dailyGoal: Int) {
        // Check for 1000-step milestone crossings
        let previousThousand = previousSteps / 1000
        let currentThousand = totalSteps / 1000

        if currentThousand > previousThousand {
            announceStepMilestone(currentThousand * 1000)
        }

        // Check halfway (only if not already past)
        let halfwayPoint = dailyGoal / 2
        if previousSteps < halfwayPoint && totalSteps >= halfwayPoint {
            announceHalfwayToGoal()
        }

        // Check goal reached
        if previousSteps < dailyGoal && totalSteps >= dailyGoal {
            announceGoalReached()
        }
    }

    // MARK: - Variation Rotation

    private func getNextVariation(from variations: [String], for type: CueType) -> String {
        let index = variationIndices[type, default: 0]
        let text = variations[index % variations.count]
        variationIndices[type] = index + 1
        return text
    }

    // MARK: - Interruption Handling

    @objc private func handleInterruption(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let typeValue = userInfo[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: typeValue) else {
            return
        }

        switch type {
        case .began:
            // Audio interrupted (e.g., phone call)
            speechSynthesizer.pauseSpeaking(at: .word)

        case .ended:
            // Interruption ended
            if let optionsValue = userInfo[AVAudioSessionInterruptionOptionKey] as? UInt {
                let options = AVAudioSession.InterruptionOptions(rawValue: optionsValue)
                if options.contains(.shouldResume) {
                    try? AVAudioSession.sharedInstance().setActive(true)
                    speechSynthesizer.continueSpeaking()
                }
            }

        @unknown default:
            break
        }
    }

    // MARK: - Settings Persistence

    private func loadSettings() {
        guard let data = UserDefaults.standard.data(forKey: settingsKey),
              let settings = try? JSONDecoder().decode(AudioCueSettings.self, from: data) else {
            return
        }

        voiceGuidanceEnabled = settings.voiceGuidanceEnabled
        countdownEnabled = settings.countdownEnabled
        soundEffectsEnabled = settings.soundEffectsEnabled
        duckMusicEnabled = settings.duckMusicEnabled
        preWarningsEnabled = settings.preWarningsEnabled
        stepMilestonesEnabled = settings.stepMilestonesEnabled
        goalReachedAudioEnabled = settings.goalReachedAudioEnabled
        achievementAudioEnabled = settings.achievementAudioEnabled
        routeGuidanceEnabled = settings.routeGuidanceEnabled
    }

    private func saveSettings() {
        let settings = AudioCueSettings(
            voiceGuidanceEnabled: voiceGuidanceEnabled,
            countdownEnabled: countdownEnabled,
            soundEffectsEnabled: soundEffectsEnabled,
            duckMusicEnabled: duckMusicEnabled,
            preWarningsEnabled: preWarningsEnabled,
            stepMilestonesEnabled: stepMilestonesEnabled,
            goalReachedAudioEnabled: goalReachedAudioEnabled,
            achievementAudioEnabled: achievementAudioEnabled,
            routeGuidanceEnabled: routeGuidanceEnabled
        )

        if let data = try? JSONEncoder().encode(settings) {
            UserDefaults.standard.set(data, forKey: settingsKey)
        }
    }
}

// MARK: - AVSpeechSynthesizerDelegate

extension AudioCueService: AVSpeechSynthesizerDelegate {
    nonisolated func speechSynthesizer(
        _ synthesizer: AVSpeechSynthesizer,
        didFinish utterance: AVSpeechUtterance
    ) {
        Task { @MainActor in
            self.endDucking()
        }
    }

    nonisolated func speechSynthesizer(
        _ synthesizer: AVSpeechSynthesizer,
        didCancel utterance: AVSpeechUtterance
    ) {
        Task { @MainActor in
            self.endDucking()
        }
    }
}

// MARK: - Cue Priority

enum CuePriority: Int, Comparable {
    case low = 3
    case normal = 2
    case high = 1

    static func < (lhs: CuePriority, rhs: CuePriority) -> Bool {
        lhs.rawValue > rhs.rawValue // Lower rawValue = higher priority
    }
}
