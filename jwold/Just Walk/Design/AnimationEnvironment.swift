//
//  AnimationEnvironment.swift
//  Just Walk
//
//  Environment key to suppress animations during initial data load.
//  This prevents UI jitter when async HealthKit data arrives.
//

import SwiftUI

private struct SuppressAnimationsKey: EnvironmentKey {
    static let defaultValue: Bool = false
}

extension EnvironmentValues {
    var suppressAnimations: Bool {
        get { self[SuppressAnimationsKey.self] }
        set { self[SuppressAnimationsKey.self] = newValue }
    }
}

extension View {
    func suppressAnimations(_ suppress: Bool) -> some View {
        environment(\.suppressAnimations, suppress)
    }
}
