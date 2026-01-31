//
//  SupportLegalView.swift
//  JustWalk
//
//  Support & Legal sub-screen for Settings
//

import SwiftUI

struct SupportLegalView: View {
    let profile: UserProfile

    private var subscriptionManager: SubscriptionManager { SubscriptionManager.shared }
    @State private var versionTapCount = 0
    @State private var showTesterModeAlert = false

    var body: some View {
        List {
            Section("Support") {
                if let url = URL(string: "https://getjustwalk.com/privacy") {
                    Link(destination: url) {
                        Label("Privacy Policy", systemImage: "hand.raised")
                    }
                    .listRowBackground(JW.Color.backgroundCard)
                }

                if let url = URL(string: "https://getjustwalk.com/terms") {
                    Link(destination: url) {
                        Label("Terms of Service", systemImage: "doc.text")
                    }
                    .listRowBackground(JW.Color.backgroundCard)
                }

                if let url = URL(string: "mailto:info@onworld.tech") {
                    Link(destination: url) {
                        Label("Contact Support", systemImage: "envelope")
                    }
                    .listRowBackground(JW.Color.backgroundCard)
                }
            }

            if !profile.legacyBadges.isEmpty {
                Section {
                    NavigationLink("Legacy Badges") {
                        LegacyBadgesView(badges: profile.legacyBadges)
                    }
                    .listRowBackground(JW.Color.backgroundCard)
                }
            }

            Section {
                HStack {
                    Text("Version")
                    Spacer()
                    Text(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0")
                        .foregroundStyle(.secondary)
                }
                .listRowBackground(JW.Color.backgroundCard)
                .contentShape(Rectangle())
                .onTapGesture {
                    versionTapCount += 1
                    if versionTapCount >= 7 {
                        versionTapCount = 0
                        if subscriptionManager.isTesterModeEnabled {
                            subscriptionManager.disableTesterMode()
                        } else {
                            subscriptionManager.enableTesterMode()
                        }
                        showTesterModeAlert = true
                        JustWalkHaptics.success()
                    }
                }
                .alert("Tester Mode", isPresented: $showTesterModeAlert) {
                    Button("OK", role: .cancel) {}
                } message: {
                    Text(subscriptionManager.isTesterModeEnabled ? "Tester mode enabled. Pro features unlocked." : "Tester mode disabled.")
                }
            }

            Section {
                Text("JustWalk is not a medical device. Step counts and distance are estimates. Consult a physician before starting any exercise program.")
                    .font(JW.Font.caption)
                    .foregroundStyle(JW.Color.textSecondary)
                    .listRowBackground(JW.Color.backgroundCard)
            }
        }
        .scrollContentBackground(.hidden)
        .background(JW.Color.backgroundPrimary)
        .navigationTitle("Support & Legal")
    }
}
