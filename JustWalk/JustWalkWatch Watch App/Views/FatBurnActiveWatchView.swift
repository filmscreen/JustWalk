//
//  FatBurnActiveWatchView.swift
//  JustWalkWatch Watch App
//
//  Active session view for Fat Burn Zone walks with real-time HR zone feedback
//

import SwiftUI
import WatchKit

struct FatBurnActiveWatchView: View {
    @Bindable var session: WatchWalkSessionManager
    let onEnd: () -> Void

    @State private var showEndConfirmation = false
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.isLuminanceReduced) private var isLuminanceReduced

    @State private var selectedPage = 0

    // MARK: - Formatted Values

    private var formattedTime: String {
        let minutes = session.elapsedSeconds / 60
        let seconds = session.elapsedSeconds % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    private var formattedTimeInZone: String {
        let totalSeconds = Int(session.timeInZone)
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    private var useMetric: Bool {
        WatchPersistenceManager.shared.loadUseMetricUnits()
    }

    private var formattedDistance: String {
        if useMetric {
            let km = session.currentDistance / 1000
            if km >= 1 {
                return String(format: "%.2f km", km)
            } else {
                return "\(Int(session.currentDistance)) m"
            }
        } else {
            let miles = session.currentDistance / 1609.344
            return String(format: "%.2f mi", miles)
        }
    }

    private var zoneStatusColor: Color {
        switch session.fatBurnZoneStatus {
        case .below: return .blue
        case .inZone: return .green
        case .above: return .orange
        }
    }

    // MARK: - Body

    var body: some View {
        TabView(selection: $selectedPage) {
            // Page 1: Zone-focused main view
            mainZonePage
                .containerBackground(zoneBackground, for: .tabView)
                .tag(0)

            // Page 2: Stats & Controls
            controlsPage
                .containerBackground(Color.black.gradient, for: .tabView)
                .tag(1)
        }
        .tabViewStyle(PageTabViewStyle())
        .navigationBarBackButtonHidden(true)
        .confirmationDialog("End this walk?", isPresented: $showEndConfirmation) {
            Button("End Walk", role: .destructive, action: onEnd)
            Button("Cancel", role: .cancel) {}
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                session.ensureTimerRunning()
            }
        }
    }

    // MARK: - Zone Background

    private var zoneBackground: some ShapeStyle {
        switch session.fatBurnZoneStatus {
        case .below:
            return Color.blue.opacity(0.3).gradient
        case .inZone:
            return Color.green.opacity(0.3).gradient
        case .above:
            return Color.orange.opacity(0.3).gradient
        }
    }

    // MARK: - Main Zone Page

    private var mainZonePage: some View {
        VStack(spacing: 6) {
            // HERO: Heart rate — largest element, immediately readable
            hrDisplay

            // Zone bar with boundary labels
            if !isLuminanceReduced {
                zoneIndicatorBar
                    .padding(.horizontal, 8)
            }

            // Instruction or measuring state
            if session.heartRate > 0 {
                zoneInstruction
            } else {
                Text("Measuring\u{2026}")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            // Timer + calories at bottom (no icons)
            HStack(spacing: 6) {
                Text(formattedTime)
                    .font(.caption.monospacedDigit())
                Text("·")
                    .foregroundStyle(.secondary)
                Text("\(Int(session.activeCalories)) cal")
                    .font(.caption)
            }
            .foregroundStyle(.secondary)
        }
        .padding(.horizontal)
        .padding(.top, 4)
        .opacity(isLuminanceReduced ? 0.6 : 1.0)
    }

    // MARK: - Zone Instruction

    private var zoneInstruction: some View {
        HStack(spacing: 4) {
            Image(systemName: session.fatBurnZoneStatus.icon)
                .font(.caption2.bold())
            Text(session.fatBurnZoneStatus.label)
                .font(.caption.bold())
        }
        .foregroundStyle(zoneStatusColor)
        .animation(.easeInOut(duration: 0.3), value: session.fatBurnZoneStatus.rawValue)
    }

    // MARK: - HR Display

    private var hrDisplay: some View {
        VStack(spacing: 0) {
            HStack(spacing: 4) {
                Image(systemName: "heart.fill")
                    .font(.title3)
                    .foregroundStyle(.red)
                Text(session.heartRate > 0 ? "\(session.heartRate)" : "\u{2014}")
                    .font(.system(size: 48, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(session.heartRate > 0 ? zoneStatusColor : .secondary)
                    .contentTransition(.numericText())
                    .animation(.easeInOut(duration: 0.3), value: session.heartRate)
            }

            Text("BPM")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(session.heartRate > 0 ? "\(session.heartRate) beats per minute, \(session.fatBurnZoneStatus.label)" : "Heart rate not available")
    }

    // MARK: - Zone Indicator Bar

    private var zoneIndicatorBar: some View {
        VStack(spacing: 2) {
            GeometryReader { geometry in
                let totalWidth = geometry.size.width
                let barHeight: CGFloat = 6

                ZStack(alignment: .leading) {
                    // Background bar with three zones
                    HStack(spacing: 1) {
                        // Below zone (blue)
                        RoundedRectangle(cornerRadius: 3)
                            .fill(Color.blue.opacity(0.4))
                            .frame(width: totalWidth * 0.3)

                        // In zone (green) — the target
                        RoundedRectangle(cornerRadius: 0)
                            .fill(Color.green.opacity(0.6))
                            .frame(width: totalWidth * 0.4)

                        // Above zone (orange)
                        RoundedRectangle(cornerRadius: 3)
                            .fill(Color.orange.opacity(0.4))
                            .frame(width: totalWidth * 0.3)
                    }
                    .frame(height: barHeight)

                    // Current HR dot marker
                    if session.heartRate > 0 {
                        let position = hrDotPosition(in: totalWidth)
                        Circle()
                            .fill(.white)
                            .frame(width: 10, height: 10)
                            .shadow(color: zoneStatusColor, radius: 3)
                            .offset(x: position - 5)
                            .animation(.easeInOut(duration: 0.5), value: session.heartRate)
                    }
                }
            }
            .frame(height: 10)

            // Zone boundary labels
            HStack {
                Text("\(session.fatBurnZoneLow)")
                Spacer()
                Text("\(session.fatBurnZoneHigh)")
                Spacer()
                Text("\(session.fatBurnZoneHigh + 24)")
            }
            .font(.system(size: 9))
            .foregroundStyle(.tertiary)
        }
    }

    /// Calculate the position of the HR dot on the zone indicator bar
    private func hrDotPosition(in totalWidth: CGFloat) -> CGFloat {
        let minDisplay = max(50, session.fatBurnZoneLow - 30)
        let maxDisplay = session.fatBurnZoneHigh + 30
        let range = Double(maxDisplay - minDisplay)
        guard range > 0 else { return totalWidth / 2 }

        let normalized = Double(session.heartRate - minDisplay) / range
        let clamped = min(max(normalized, 0.02), 0.98) // Keep dot within bar
        return CGFloat(clamped) * totalWidth
    }

    // MARK: - Controls Page

    private var controlsPage: some View {
        VStack(spacing: 8) {
            // Timer + stats at top — user never loses track of time
            VStack(spacing: 4) {
                Text(formattedTime)
                    .font(.system(size: 24, weight: .bold, design: .monospaced))
                    .monospacedDigit()

                HStack(spacing: 6) {
                    Text("\(session.currentSteps) steps")
                    Text("·")
                        .foregroundStyle(.secondary)
                    Text(formattedDistance)
                }
                .font(.caption2)
                .foregroundStyle(.secondary)
            }

            if !isLuminanceReduced {
                Spacer()

                // Pause/Resume
                Button {
                    if session.isPaused {
                        session.resumeWalk()
                    } else {
                        session.pauseWalk()
                    }
                } label: {
                    Label(
                        session.isPaused ? "Resume" : "Pause",
                        systemImage: session.isPaused ? "play.fill" : "pause.fill"
                    )
                    .font(.footnote.bold())
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(session.isPaused ? Color.green.opacity(0.3) : Color.yellow.opacity(0.3))
                    .foregroundStyle(session.isPaused ? .green : .yellow)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                .buttonStyle(.plain)

                // End Walk
                Button(role: .destructive) {
                    if session.currentSteps > 500 || session.elapsedSeconds > 300 {
                        showEndConfirmation = true
                    } else {
                        onEnd()
                    }
                } label: {
                    Label(session.isEnding ? "Ending…" : "End Walk",
                          systemImage: session.isEnding ? "hourglass" : "stop.fill")
                        .font(.footnote.bold())
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(Color.red.opacity(session.isEnding ? 0.15 : 0.3))
                        .foregroundStyle(session.isEnding ? Color.secondary : Color.red)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                .buttonStyle(.plain)
                .disabled(session.isEnding)
            }
        }
        .padding(.horizontal)
        .padding(.top, 8)
        .opacity(isLuminanceReduced ? 0.6 : 1.0)
    }
}

#Preview {
    let session = WatchWalkSessionManager()
    FatBurnActiveWatchView(session: session, onEnd: {})
}
