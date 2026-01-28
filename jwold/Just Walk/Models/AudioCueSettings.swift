//
//  AudioCueSettings.swift
//  Just Walk
//
//  Settings model for audio cues during Power Walk.
//

import Foundation

/// Settings for audio cues during Power Walk
struct AudioCueSettings: Codable, Equatable {
    var voiceGuidanceEnabled: Bool
    var countdownEnabled: Bool
    var soundEffectsEnabled: Bool
    var duckMusicEnabled: Bool
    var preWarningsEnabled: Bool
    var stepMilestonesEnabled: Bool
    var milestoneInterval: Int  // steps between milestones
    var goalReachedAudioEnabled: Bool
    var achievementAudioEnabled: Bool
    var routeGuidanceEnabled: Bool  // Turn-by-turn voice guidance

    init(
        voiceGuidanceEnabled: Bool = true,
        countdownEnabled: Bool = true,
        soundEffectsEnabled: Bool = true,
        duckMusicEnabled: Bool = true,
        preWarningsEnabled: Bool = true,
        stepMilestonesEnabled: Bool = true,
        milestoneInterval: Int = 1000,
        goalReachedAudioEnabled: Bool = true,
        achievementAudioEnabled: Bool = true,
        routeGuidanceEnabled: Bool = true
    ) {
        self.voiceGuidanceEnabled = voiceGuidanceEnabled
        self.countdownEnabled = countdownEnabled
        self.soundEffectsEnabled = soundEffectsEnabled
        self.duckMusicEnabled = duckMusicEnabled
        self.preWarningsEnabled = preWarningsEnabled
        self.stepMilestonesEnabled = stepMilestonesEnabled
        self.milestoneInterval = milestoneInterval
        self.goalReachedAudioEnabled = goalReachedAudioEnabled
        self.achievementAudioEnabled = achievementAudioEnabled
        self.routeGuidanceEnabled = routeGuidanceEnabled
    }

    static let `default` = AudioCueSettings()
}
