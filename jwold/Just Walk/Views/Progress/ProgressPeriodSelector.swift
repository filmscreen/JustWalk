//
//  ProgressPeriodSelector.swift
//  Just Walk
//
//  Period selector for the Progress tab.
//  Supports Week, Month, Year, and All Time (Pro only).
//

import SwiftUI

// MARK: - Progress Period Enum

enum ProgressPeriod: String, CaseIterable, Identifiable {
    case week = "Week"
    case month = "Month"
    case year = "Year"
    case allTime = "All Time"

    var id: String { rawValue }

    /// Days of data for this period
    var days: Int? {
        switch self {
        case .week: return 7
        case .month: return 30
        case .year: return 365
        case .allTime: return nil // All historical data
        }
    }

    /// Whether this period requires Pro subscription
    var requiresPro: Bool {
        false // TESTING: disabled for testing
        // self == .allTime
    }
}

// MARK: - Progress Period Selector

struct ProgressPeriodSelector: View {
    @Binding var selectedPeriod: ProgressPeriod
    let isPro: Bool
    var onProRequired: () -> Void = {}

    var body: some View {
        Picker("Period", selection: $selectedPeriod) {
            ForEach(ProgressPeriod.allCases) { period in
                Text(period.rawValue)
                    .tag(period)
            }
        }
        .pickerStyle(.segmented)
        .onChange(of: selectedPeriod) { _, newValue in
            if newValue.requiresPro && !isPro {
                // Reset to year and show paywall
                selectedPeriod = .year
                onProRequired()
            }
        }
    }
}

// MARK: - Preview

#Preview("Free User") {
    VStack {
        ProgressPeriodSelector(
            selectedPeriod: .constant(.week),
            isPro: false,
            onProRequired: { print("Pro required") }
        )
    }
    .padding()
}

#Preview("Pro User") {
    VStack {
        ProgressPeriodSelector(
            selectedPeriod: .constant(.allTime),
            isPro: true
        )
    }
    .padding()
}
