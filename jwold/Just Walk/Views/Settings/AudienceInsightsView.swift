//
//  AudienceInsightsView.swift
//  Just Walk
//
//  Created by Randy Chia on 1/11/26.
//

import SwiftUI

struct AudienceInsightsView: View {
    @State private var breakdown: AudienceBreakdown?
    @State private var isLoading = true
    @State private var errorMessage: String?
    
    // For CSV Export
    @State private var isShareSheetPresented = false
    @State private var csvURL: URL?

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Header
                VStack(spacing: 8) {
                    Text("Audience Intelligence")
                        .font(.title2.bold())
                    Text("Real-time demographic segmentation for ad targeting.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.top)
                
                if isLoading {
                    ProgressView("Analyzing Userbase...")
                        .padding(.top, 40)
                } else if let data = breakdown {
                    // Summary Cards
                    HStack(spacing: 16) {
                        AudienceStatCard(title: "Total Users", value: "\(data.totalUsers)")
                        AudienceStatCard(title: "Segments", value: "\(data.ageDistribution.keys.count + data.genderDistribution.keys.count)")
                    }
                    
                    // Age Distribution
                    InsightSection(title: "Age Demographics") {
                        if data.ageDistribution.isEmpty {
                            Text("No age data collected yet.")
                                .foregroundStyle(.secondary)
                        } else {
                            ForEach(data.ageDistribution.sorted(by: { $0.key < $1.key }), id: \.key) { key, count in
                                DistributionRow(label: key, count: count, total: data.totalUsers, color: .blue)
                            }
                        }
                    }
                    
                    // Gender Distribution
                    InsightSection(title: "Gender Split") {
                        if data.genderDistribution.isEmpty {
                            Text("No gender data collected yet.")
                                .foregroundStyle(.secondary)
                        } else {
                            ForEach(data.genderDistribution.sorted(by: { $0.value > $1.value }), id: \.key) { key, count in
                                DistributionRow(label: key, count: count, total: data.totalUsers, color: .purple)
                            }
                        }
                    }
                    
                    // Export Action
                    Button {
                        generateCSV(data: data)
                    } label: {
                        Label("Export Media Kit CSV", systemImage: "square.and.arrow.up")
                            .font(.headline)
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.green)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .padding(.top, 16)
                    
                } else if let error = errorMessage {
                    VStack {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.largeTitle)
                            .foregroundStyle(.yellow)
                        Text("Analysis Failed")
                            .font(.headline)
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding()
                }
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Marketer Dashboard")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            do {
                breakdown = try await NewsletterService.shared.fetchAudienceStats()
                isLoading = false
            } catch {
                errorMessage = error.localizedDescription
                isLoading = false
            }
        }
        .sheet(isPresented: $isShareSheetPresented) {
            if let url = csvURL {
                ShareSheet(activityItems: [url])
            }
        }
    }
    
    // MARK: - CSV Generation
    private func generateCSV(data: AudienceBreakdown) {
        var csvString = "Segment Type,Segment Value,Count,Percentage\n"
        
        let total = Double(data.totalUsers)
        
        // Age
        for (age, count) in data.ageDistribution {
            let percentage = (Double(count) / total) * 100
            csvString += "Age,\(age),\(count),\(String(format: "%.1f", percentage))%\n"
        }
        
        // Gender
        for (gender, count) in data.genderDistribution {
            let percentage = (Double(count) / total) * 100
            csvString += "Gender,\(gender),\(count),\(String(format: "%.1f", percentage))%\n"
        }
        
        // Save to temporary file
        let fileName = "Audience_Media_Kit_\(Date().formatted(date: .numeric, time: .omitted)).csv"
        let path = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        
        do {
            try csvString.write(to: path, atomically: true, encoding: .utf8)
            csvURL = path
            isShareSheetPresented = true
        } catch {
            print("Failed to ensure CSV: \(error)")
        }
    }
}

// MARK: - Subviews

// MARK: - Subviews

struct AudienceStatCard: View {
    let title: String
    let value: String
    
    var body: some View {
        VStack(spacing: 8) {
            Text(value)
                .font(.system(size: 32, weight: .bold, design: .rounded))
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

struct InsightSection<Content: View>: View {
    let title: String
    let content: Content
    
    init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(title)
                .font(.headline)
                .foregroundStyle(.primary)
            
            VStack(spacing: 12) {
                content
            }
            .padding()
            .background(Color(UIColor.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }
}

struct DistributionRow: View {
    let label: String
    let count: Int
    let total: Int
    let color: Color
    
    var percentage: Double {
        guard total > 0 else { return 0 }
        return Double(count) / Double(total)
    }
    
    var body: some View {
        VStack(spacing: 6) {
            HStack {
                Text(label)
                    .font(.subheadline.bold())
                    .foregroundStyle(.primary)
                Spacer()
                Text("\(count) users")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("(\(Int(percentage * 100))%)")
                    .font(.caption.bold())
                    .foregroundStyle(.primary)
            }
            
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color(UIColor.systemGray5))
                        .frame(height: 8)
                    
                    Capsule()
                        .fill(color)
                        .frame(width: geo.size.width * percentage, height: 8)
                }
            }
            .frame(height: 8)
        }
    }
}

// Wrapper for Share Sheet
struct ShareSheet: UIViewControllerRepresentable {
    var activityItems: [Any]
    var applicationActivities: [UIActivity]? = nil

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: activityItems, applicationActivities: applicationActivities)
        return controller
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

#Preview {
    AudienceInsightsView()
}
