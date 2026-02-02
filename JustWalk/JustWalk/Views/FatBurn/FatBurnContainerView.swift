//
//  FatBurnContainerView.swift
//  JustWalk
//
//  Entry point for the Fat Burn Zone flow (Pro only). Handles:
//  1. Watch availability check → WatchRequiredView if no Watch
//  2. HealthKit age auto-fetch
//  3. Landing page → FatBurnLandingView
//

import SwiftUI

struct FatBurnContainerView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var connectivity = PhoneConnectivityManager.shared
    @AppStorage("userAge") private var storedAge: Int?

    @State private var hasCheckedHealthKit = false

    private var watchAvailable: Bool {
        #if targetEnvironment(simulator)
        return true
        #else
        return connectivity.canCommunicateWithWatch
        #endif
    }

    var body: some View {
        Group {
            if !watchAvailable {
                WatchRequiredView()
            } else {
                FatBurnLandingView(onFlowComplete: { dismiss() })
            }
        }
        .task {
            await checkHealthKitAge()
        }
        .toolbar(.hidden, for: .tabBar)
    }

    /// Try to get age from HealthKit first, so we don't have to ask
    private func checkHealthKitAge() async {
        guard !hasCheckedHealthKit, storedAge == nil else { return }
        hasCheckedHealthKit = true

        if let age = await FatBurnZoneManager.shared.fetchAgeFromHealthKit(), age > 0, age < 120 {
            storedAge = age
            FatBurnZoneManager.shared.recalculateZone()
        }
    }
}

#Preview {
    NavigationStack {
        FatBurnContainerView()
    }
}
