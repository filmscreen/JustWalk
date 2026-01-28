//
//  WalkMode.swift
//  JustWalk
//
//  Enum for walk tracking modes
//

import Foundation

enum WalkMode: String, Codable {
    case free       // No goal, just walk
    case interval   // Structured interval program
    case fatBurn    // Heart-rate guided fat burn zone
    case postMeal   // Timed post-meal walk
}
