//
//  IntervalVoiceManager.swift
//  JustWalk
//
//  Voice announcement manager for interval walking phases
//

import Foundation
import AVFoundation
import Combine

@Observable
class IntervalVoiceManager: NSObject, ObservableObject {
    static let shared = IntervalVoiceManager()

    private let synthesizer = AVSpeechSynthesizer()

    // MARK: - Persisted Preferences

    var isEnabled: Bool {
        didSet { UserDefaults.standard.set(isEnabled, forKey: "voice_isEnabled") }
    }

    var duckMusicDuringCues: Bool {
        didSet { UserDefaults.standard.set(duckMusicDuringCues, forKey: "voice_duckMusic") }
    }

    private var pendingText: String?

    private override init() {
        let defaults = UserDefaults.standard
        defaults.register(defaults: [
            "voice_isEnabled": true,
            "voice_duckMusic": true
        ])

        self.isEnabled = defaults.bool(forKey: "voice_isEnabled")
        self.duckMusicDuringCues = defaults.bool(forKey: "voice_duckMusic")

        super.init()

        // Observe audio interruptions (phone calls, Siri, etc.)
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAudioInterruption),
            name: AVAudioSession.interruptionNotification,
            object: AVAudioSession.sharedInstance()
        )
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    @objc private func handleAudioInterruption(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let typeValue = userInfo[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: typeValue) else { return }

        switch type {
        case .began:
            // Interruption started (phone call, Siri, etc.) — stop speaking
            if synthesizer.isSpeaking {
                synthesizer.stopSpeaking(at: .immediate)
            }
        case .ended:
            // Interruption ended — re-activate audio session
            if let optionsValue = userInfo[AVAudioSessionInterruptionOptionKey] as? UInt {
                let options = AVAudioSession.InterruptionOptions(rawValue: optionsValue)
                if options.contains(.shouldResume) {
                    try? AVAudioSession.sharedInstance().setActive(true)
                }
            }
        @unknown default:
            break
        }
    }

    // MARK: - Phase Announcements

    func announce(phase: IntervalPhase) {
        guard isEnabled else { return }

        let text: String
        switch phase.type {
        case .warmup:
            text = "Warm up. Walk at an easy pace."
        case .fast:
            text = "Pick up the pace."
        case .slow:
            text = "Slow down. Easy pace."
        case .cooldown:
            text = "Cool down. Almost done."
        }

        speak(text)
    }

    func announceComplete() {
        guard isEnabled else { return }
        speak("Interval complete. Great work!")
    }

    func announceCountdown(_ seconds: Int) {
        guard isEnabled, seconds <= 10, seconds > 0 else { return }
        speak("\(seconds)")
    }

    func announceHalfway() {
        guard isEnabled else { return }
        speak("Halfway there. Keep going!")
    }

    // MARK: - Speech Synthesis

    private func speak(_ text: String) {
        // Stop any current speech
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }

        // Configure audio session based on duck preference
        let session = AVAudioSession.sharedInstance()
        do {
            if duckMusicDuringCues {
                try session.setCategory(.playback, options: .duckOthers)
            } else {
                try session.setCategory(.playback, options: .mixWithOthers)
            }
            try session.setActive(true)
        } catch {
            // Continue speaking even if audio session config fails
        }

        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
        utterance.rate = 0.5
        utterance.pitchMultiplier = 1.0
        utterance.volume = 1.0

        synthesizer.speak(utterance)
    }

    // MARK: - Control

    func stop() {
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }
    }

    func toggle() {
        isEnabled.toggle()
        if !isEnabled {
            stop()
        }
    }
}
