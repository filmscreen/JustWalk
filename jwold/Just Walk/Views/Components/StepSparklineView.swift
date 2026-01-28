//
//  StepSparklineView.swift
//  Just Walk
//
//  Compact sparkline chart showing 7-day step trend.
//

import SwiftUI
import Charts

/// Compact sparkline visualization for step trends
struct StepSparklineView: View {
    let data: [Int]
    let accentColor: Color
    
    // Computed properties for chart
    private var chartData: [(index: Int, steps: Int)] {
        data.enumerated().map { (index: $0.offset, steps: $0.element) }
    }
    
    private var maxSteps: Int {
        data.max() ?? 10000
    }
    
    private var minSteps: Int {
        data.min() ?? 0
    }
    
    var body: some View {
        Chart(chartData, id: \.index) { item in
            // Area fill
            AreaMark(
                x: .value("Day", item.index),
                yStart: .value("Min", minSteps),
                yEnd: .value("Steps", item.steps)
            )
            .foregroundStyle(
                LinearGradient(
                    colors: [accentColor.opacity(0.3), accentColor.opacity(0.05)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .interpolationMethod(.catmullRom)
            
            // Line
            LineMark(
                x: .value("Day", item.index),
                y: .value("Steps", item.steps)
            )
            .foregroundStyle(accentColor)
            .lineStyle(StrokeStyle(lineWidth: 2, lineCap: .round))
            .interpolationMethod(.catmullRom)
            
            // Current day point (last item)
            if item.index == data.count - 1 {
                PointMark(
                    x: .value("Day", item.index),
                    y: .value("Steps", item.steps)
                )
                .foregroundStyle(accentColor)
                .symbolSize(30)
            }
        }
        .chartXAxis(.hidden)
        .chartYAxis(.hidden)
        .chartYScale(domain: max(0, minSteps - 1000)...(maxSteps + 1000))
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 20) {
        StepSparklineView(
            data: [6500, 8200, 7100, 9400, 10200, 8800, 11500],
            accentColor: .cyan
        )
        .frame(height: 50)
        .padding()
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        
        StepSparklineView(
            data: [3200, 4100, 5500, 4800, 6200, 7100, 8400],
            accentColor: .orange
        )
        .frame(height: 50)
        .padding()
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    .padding()
}
