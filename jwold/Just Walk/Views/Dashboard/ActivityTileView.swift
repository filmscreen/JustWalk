//
//  ActivityTileView.swift
//  Just Walk
//
//  Full 90-day scrollable Activity chart tile.
//  Shown on the Progress tab.
//

import SwiftUI

struct ActivityTileView: View {
    @StateObject private var activityDataViewModel = DataViewModel()
    @ObservedObject private var streakService = StreakService.shared
    @State private var showActivityScrollToEnd = false
    @State private var visibleActivityItemId: UUID?

    // Dynamic tile height based on screen size
    private var tileMinHeight: CGFloat {
        let screenHeight = UIScreen.main.bounds.height
        if screenHeight >= 920 {
            return 330 // Pro Max
        } else if screenHeight >= 850 {
            return 250 // Standard Pro / Plus
        } else {
            return 210 // Smaller devices
        }
    }

    /// Last 90 days of data
    private var chartData: [DayStepData] {
        Array(activityDataViewModel.yearData.prefix(90))
    }

    var body: some View {
        ZStack(alignment: .trailing) {
            // Main tile content
            VStack(alignment: .leading, spacing: JWDesign.Spacing.sm) {
                Text("Activity")
                    .font(JWDesign.Typography.headline)

                // Scrollable chart
                ScrollViewReader { proxy in
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(alignment: .bottom, spacing: 12) {
                            ForEach(chartData.reversed()) { day in
                                VStack(spacing: 2) {
                                    Spacer(minLength: 0)

                                    // Step count above bar
                                    Text(activityDataViewModel.formatCompact(day.steps))
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)
                                        .fixedSize(horizontal: true, vertical: false)

                                    // Bar
                                    Capsule()
                                        .fill(barColor(for: day))
                                        .frame(width: 38, height: barHeight(for: day))

                                    // Date label
                                    VStack(spacing: 2) {
                                        Text(day.date.formatted(.dateTime.weekday(.abbreviated)))
                                            .font(.system(size: 10))
                                            .lineLimit(1)
                                        Text(day.date.formatted(.dateTime.day()))
                                            .font(.system(size: 12, weight: .semibold))
                                            .lineLimit(1)
                                        Text(day.date.formatted(.dateTime.month(.abbreviated)))
                                            .font(.system(size: 10))
                                            .lineLimit(1)
                                    }
                                    .fixedSize(horizontal: true, vertical: false)
                                    .foregroundStyle(.secondary)
                                    .padding(.top, 2)
                                }
                                .id(day.id)
                            }
                        }
                        .frame(minHeight: tileMinHeight - 60)
                        .scrollTargetLayout()
                        .padding(.leading, JWDesign.Spacing.lg)
                    }
                    .scrollPosition(id: $visibleActivityItemId, anchor: .trailing)
                    .scrollTargetBehavior(.viewAligned(limitBehavior: .never))
                    .onChange(of: visibleActivityItemId) { _, newId in
                        let mostRecentId = chartData.first?.id
                        withAnimation(.easeInOut(duration: 0.2)) {
                            showActivityScrollToEnd = (newId != mostRecentId && newId != nil)
                        }
                    }
                    .onChange(of: chartData) { _, newData in
                        if let lastItem = newData.first {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                proxy.scrollTo(lastItem.id, anchor: .trailing)
                            }
                        }
                    }
                    .onAppear {
                        if let lastItem = chartData.first {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                proxy.scrollTo(lastItem.id, anchor: .trailing)
                            }
                        }
                    }
                }
            }
            .padding(JWDesign.Spacing.md)
            .background(JWDesign.Colors.secondaryBackground)
            .clipShape(RoundedRectangle(cornerRadius: JWDesign.Radius.card))

            // Scroll-to-end button
            if showActivityScrollToEnd {
                Button {
                    if let mostRecentId = chartData.first?.id {
                        withAnimation {
                            visibleActivityItemId = mostRecentId
                        }
                    }
                } label: {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 24, height: 24)
                        .background(Circle().fill(Color.gray.opacity(0.7)))
                }
                .padding(.trailing, 16)
                .padding(.top, 20)
                .transition(.opacity.combined(with: .scale(scale: 0.8)))
            }
        }
        .onAppear {
            if activityDataViewModel.yearData.isEmpty {
                Task {
                    await activityDataViewModel.loadData()
                }
            }
        }
    }

    // MARK: - Helpers

    private func barHeight(for day: DayStepData) -> CGFloat {
        let maxHeight: CGFloat = tileMinHeight - 90
        let maxSteps: CGFloat = 15000
        let ratio = CGFloat(day.steps) / maxSteps
        return max(8, min(maxHeight, ratio * maxHeight))
    }

    private func barColor(for day: DayStepData) -> Color {
        if day.isGoalMet {
            return .mint
        } else if streakService.isDateShielded(day.date) {
            return .orange
        } else if Calendar.current.isDateInToday(day.date) {
            return .blue
        } else {
            return .blue.opacity(0.4)
        }
    }
}

#Preview {
    ActivityTileView()
        .padding()
}
