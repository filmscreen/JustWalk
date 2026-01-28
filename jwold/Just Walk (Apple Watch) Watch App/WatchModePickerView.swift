//
//  WatchModePickerView.swift
//  Just Walk Watch App
//
//  Mode selection sheet for choosing walk type on Watch.
//  Open Walk (free) + Goal-Based modes (Pro).
//

import SwiftUI
import WatchKit

struct WatchModePickerView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var sessionManager: WatchSessionManager

    // Callbacks
    var onStartOpenWalk: () -> Void
    var onStartWithGoal: (WalkGoal) -> Void
    var onStartInterval: () -> Void
    var onStartMagicRoute: () -> Void = {}

    // State for value picker navigation
    @State private var selectedGoalType: WalkGoalType? = nil
    @State private var showValuePicker = false

    private var isPro: Bool {
        sessionManager.isPro
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 8) {
                // Header
                Text("Choose Your Walk")
                    .font(.headline)
                    .padding(.bottom, 4)

                // Open Walk button (always free)
                openWalkButton

                // Pro Walks section divider
                HStack(spacing: 6) {
                    Rectangle()
                        .fill(Color.gray.opacity(0.3))
                        .frame(height: 1)
                    Text("Pro Walks")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Rectangle()
                        .fill(Color.gray.opacity(0.3))
                        .frame(height: 1)
                }
                .padding(.vertical, 4)

                // Interval Walk button (first Pro option)
                intervalWalkButton

                // Magic Route button (second Pro option)
                magicRouteButton

                // Goal mode buttons
                goalModeButton(.steps)
                goalModeButton(.time)
                goalModeButton(.distance)

                // Unlock message for free users
                if !isPro {
                    unlockMessage
                }
            }
            .padding(.horizontal, 8)
        }
        .sheet(isPresented: $showValuePicker) {
            if let goalType = selectedGoalType {
                WatchGoalValuePicker(
                    goalType: goalType,
                    onSelect: { goal in
                        showValuePicker = false
                        onStartWithGoal(goal)
                    },
                    onCancel: {
                        showValuePicker = false
                    }
                )
            }
        }
    }

    // MARK: - Open Walk Button

    private var openWalkButton: some View {
        Button {
            WKInterfaceDevice.current().play(.click)
            onStartOpenWalk()
        } label: {
            HStack {
                Image(systemName: "figure.walk")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Color(hex: "34C759"))
                Text("Open Walk")
                    .font(.system(size: 14, weight: .medium))
                Spacer()
                Text("Start")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Color(hex: "34C759"))
                    .clipShape(Capsule())
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 10)
            .background(Color(hex: "2C2C2E"))
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Goal Mode Button

    private func goalModeButton(_ type: WalkGoalType) -> some View {
        Button {
            WKInterfaceDevice.current().play(.click)
            if isPro {
                selectedGoalType = type
                showValuePicker = true
            }
            // Free users see lock icon - no action needed
        } label: {
            HStack {
                Image(systemName: type.icon)
                    .font(.system(size: 14))
                    .foregroundStyle(isPro ? Color(hex: "00C7BE") : .gray)
                    .frame(width: 20)
                Text(type.label)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(isPro ? .white : .gray)
                Spacer()

                if isPro {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.gray)
                } else {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(.gray)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 10)
            .background(Color(hex: "2C2C2E"))
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Interval Walk Button

    private var intervalWalkButton: some View {
        Button {
            WKInterfaceDevice.current().play(.click)
            if isPro {
                onStartInterval()
            }
            // Free users see lock icon - no action needed
        } label: {
            HStack {
                Image(systemName: "arrow.2.squarepath")
                    .font(.system(size: 14))
                    .foregroundStyle(isPro ? Color(hex: "FF9500") : .gray)
                    .frame(width: 20)
                VStack(alignment: .leading, spacing: 1) {
                    Text("Interval")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(isPro ? .white : .gray)
                    Text("Power Walk")
                        .font(.system(size: 10))
                        .foregroundStyle(.gray)
                }
                Spacer()

                if isPro {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.gray)
                } else {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(.gray)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 10)
            .background(Color(hex: "2C2C2E"))
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Magic Route Button

    private var magicRouteButton: some View {
        Button {
            WKInterfaceDevice.current().play(.click)
            if isPro {
                onStartMagicRoute()
            }
            // Free users see lock icon - no action needed
        } label: {
            HStack {
                Image(systemName: "wand.and.stars")
                    .font(.system(size: 14))
                    .foregroundStyle(isPro ? Color(hex: "AF52DE") : .gray)
                    .frame(width: 20)
                VStack(alignment: .leading, spacing: 1) {
                    Text("Magic Route")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(isPro ? .white : .gray)
                    Text("Use iPhone")
                        .font(.system(size: 10))
                        .foregroundStyle(.gray)
                }
                Spacer()

                if !isPro {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(.gray)
                } else {
                    Image(systemName: "iphone")
                        .font(.system(size: 12))
                        .foregroundStyle(.gray)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 10)
            .background(Color(hex: "2C2C2E"))
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Unlock Message

    private var unlockMessage: some View {
        HStack(spacing: 4) {
            Image(systemName: "iphone")
                .font(.system(size: 10))
            Text("Unlock on iPhone")
                .font(.caption2)
        }
        .foregroundStyle(.orange)
        .padding(.top, 4)
    }
}

// MARK: - Goal Value Picker

struct WatchGoalValuePicker: View {
    let goalType: WalkGoalType
    var onSelect: (WalkGoal) -> Void
    var onCancel: () -> Void

    @State private var selectedIndex: Int = 0

    private var values: [Double] {
        switch goalType {
        case .none: return []
        case .steps: return [1000, 2000, 3000, 4000, 5000, 6000, 7000, 8000, 9000, 10000]
        case .time: return [15, 30, 45, 60, 75, 90, 105, 120, 135, 150, 165, 180]
        case .distance: return stride(from: 0.25, through: 10.0, by: 0.25).map { $0 }
        }
    }

    var body: some View {
        VStack(spacing: 8) {
            Text("Select \(goalType.label)")
                .font(.headline)

            Picker("", selection: $selectedIndex) {
                ForEach(0..<values.count, id: \.self) { index in
                    Text(labelFor(values[index]))
                        .tag(index)
                }
            }
            .pickerStyle(.wheel)
            .frame(height: 80)

            HStack(spacing: 12) {
                Button {
                    WKInterfaceDevice.current().play(.click)
                    onCancel()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 44, height: 44)
                        .background(Color.gray.opacity(0.3))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)

                Button {
                    WKInterfaceDevice.current().play(.click)
                    let goal = buildGoal(from: values[selectedIndex])
                    onSelect(goal)
                } label: {
                    Image(systemName: "checkmark")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 44, height: 44)
                        .background(Color(hex: "00C7BE"))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding()
        .onAppear {
            switch goalType {
            case .none: break
            case .steps: selectedIndex = 2   // 3K steps
            case .time: selectedIndex = 1    // 30 min
            case .distance: selectedIndex = 3 // 1.0 mi
            }
        }
    }

    private func labelFor(_ value: Double) -> String {
        switch goalType {
        case .none:
            return "Open Walk"
        case .steps:
            let intValue = Int(value)
            if intValue >= 1000 {
                let k = Double(intValue) / 1000.0
                if k == floor(k) {
                    return "\(Int(k))K steps"
                }
                return String(format: "%.1fK steps", k)
            }
            return "\(intValue) steps"
        case .time:
            let minutes = Int(value)
            if minutes < 60 {
                return "\(minutes) min"
            } else if minutes == 60 {
                return "1 hour"
            } else {
                let hours = minutes / 60
                let mins = minutes % 60
                if mins == 0 {
                    return "\(hours) hours"
                } else {
                    return "\(hours) hr \(mins) min"
                }
            }
        case .distance:
            // Convert miles to user's preferred unit
            let unit = WatchDistanceUnit.preferred
            let distanceInMeters = value * 1609.34
            let convertedValue = distanceInMeters * unit.conversionFromMeters
            if convertedValue == floor(convertedValue) {
                return "\(Int(convertedValue)) \(unit.abbreviation)"
            }
            return String(format: "%.1f %@", convertedValue, unit.abbreviation)
        }
    }

    private func buildGoal(from value: Double) -> WalkGoal {
        switch goalType {
        case .none:
            return .none
        case .steps:
            return WalkGoal.steps(count: value)
        case .time:
            return WalkGoal.time(minutes: value)
        case .distance:
            return WalkGoal.distance(miles: value)
        }
    }
}

// MARK: - Preview

#Preview("Free User") {
    WatchModePickerView(
        sessionManager: WatchSessionManager.shared,
        onStartOpenWalk: { print("Start open walk") },
        onStartWithGoal: { print("Start with goal: \($0)") },
        onStartInterval: { print("Start interval") },
        onStartMagicRoute: { print("Start magic route") }
    )
}

#Preview("Value Picker") {
    WatchGoalValuePicker(
        goalType: .steps,
        onSelect: { print("Selected: \($0)") },
        onCancel: { print("Cancelled") }
    )
}
