//
//  CoachingBannerView.swift
//  Just Walk
//
//  Created by Randy Chia on 1/8/26.
//

import SwiftUI

/// Reusable coaching tip banner component
struct CoachingBannerView: View {

    let tip: CoachingTip
    var onDismiss: (() -> Void)?
    var onRefresh: (() -> Void)?

    @State private var isExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Main content
            HStack(alignment: .top, spacing: 12) {
                // Icon
                ZStack {
                    Circle()
                        .fill(categoryColor.opacity(0.2))
                        .frame(width: 44, height: 44)

                    Image(systemName: tip.icon)
                        .font(.title3)
                        .foregroundStyle(categoryColor)
                }

                // Text content
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(tip.category.rawValue)
                            .font(.caption2)
                            .fontWeight(.medium)
                            .foregroundStyle(categoryColor)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(categoryColor.opacity(0.1))
                            .clipShape(Capsule())

                        Spacer()

                        if onRefresh != nil {
                            Button {
                                onRefresh?()
                            } label: {
                                Image(systemName: "arrow.clockwise")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }

                        if onDismiss != nil {
                            Button {
                                onDismiss?()
                            } label: {
                                Image(systemName: "xmark")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }

                    Text(tip.title)
                        .font(.callout)
                        .fontWeight(.semibold)

                    Text(tip.message)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(isExpanded ? nil : 2)
                }
            }
            .padding()
            .contentShape(Rectangle())
            .onTapGesture {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isExpanded.toggle()
                }
            }
        }
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.05), radius: 8, y: 2)
    }

    private var categoryColor: Color {
        switch tip.category {
        case .motivation:
            return .orange
        case .technique:
            return .purple
        case .progress:
            return .blue
        case .health:
            return .green
        case .iwt:
            return .red
        case .milestone:
            return .yellow
        }
    }
}

// MARK: - Coaching Card View (Larger variant)

struct CoachingCardView: View {

    let tip: CoachingTip
    var style: CardStyle = .standard

    enum CardStyle {
        case standard
        case compact
        case featured
    }

    var body: some View {
        switch style {
        case .standard:
            standardCard
        case .compact:
            compactCard
        case .featured:
            featuredCard
        }
    }

    private var standardCard: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(categoryGradient)
                    .frame(width: 56, height: 56)

                Image(systemName: tip.icon)
                    .font(.title2)
                    .foregroundStyle(.white)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(tip.title)
                    .font(.headline)

                Text(tip.message)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            Spacer()
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private var compactCard: some View {
        HStack(spacing: 12) {
            Image(systemName: tip.icon)
                .font(.title3)
                .foregroundStyle(categoryColor)
                .frame(width: 32)

            VStack(alignment: .leading, spacing: 2) {
                Text(tip.title)
                    .font(.subheadline.bold())
                Text(tip.message)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()
        }
        .padding(12)
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var featuredCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                ZStack {
                    Circle()
                        .fill(categoryGradient)
                        .frame(width: 48, height: 48)

                    Image(systemName: tip.icon)
                        .font(.title3)
                        .foregroundStyle(.white)
                }

                Spacer()

                Text(tip.category.rawValue)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 4)
                    .background(categoryColor)
                    .clipShape(Capsule())
            }

            VStack(alignment: .leading, spacing: 8) {
                Text(tip.title)
                    .font(.title3.bold())

                Text(tip.message)
                    .font(.body)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .background(
            LinearGradient(
                colors: [categoryColor.opacity(0.1), categoryColor.opacity(0.05)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }

    private var categoryColor: Color {
        switch tip.category {
        case .motivation: return .orange
        case .technique: return .purple
        case .progress: return .blue
        case .health: return .green
        case .iwt: return .red
        case .milestone: return .yellow
        }
    }

    private var categoryGradient: LinearGradient {
        LinearGradient(
            colors: [categoryColor, categoryColor.opacity(0.7)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

// MARK: - Coaching Limit Banner (Free Tier Upsell)

/// Banner shown when free users have exhausted their daily coaching tips
struct CoachingLimitBanner: View {
    var onUpgrade: () -> Void

    private let freeTierManager = FreeTierManager.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                // Icon
                ZStack {
                    Circle()
                        .fill(Color.orange.opacity(0.2))
                        .frame(width: 44, height: 44)

                    Image(systemName: "lightbulb.slash")
                        .font(.title3)
                        .foregroundStyle(.orange)
                }

                // Text content
                VStack(alignment: .leading, spacing: 4) {
                    Text("Daily Tips Used")
                        .font(.subheadline)
                        .fontWeight(.semibold)

                    Text("You've used all \(FreeTierManager.dailyCoachingTipsLimit) free tips for today")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()
            }

            // Upgrade button
            Button(action: onUpgrade) {
                HStack {
                    Image(systemName: "crown.fill")
                        .font(.caption)
                    Text("Unlock Unlimited Tips")
                        .font(.caption)
                        .fontWeight(.semibold)
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(
                    LinearGradient(
                        colors: [.teal, .blue],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .clipShape(Capsule())
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.05), radius: 8, y: 2)
        .overlay {
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.orange.opacity(0.3), lineWidth: 1)
        }
    }
}

/// Banner showing remaining tips for free users
struct CoachingTipsRemainingBanner: View {
    let remaining: Int

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "lightbulb.fill")
                .font(.caption)
                .foregroundStyle(.orange)

            Text("\(remaining) tip\(remaining == 1 ? "" : "s") remaining today")
                .font(.caption)
                .foregroundStyle(.secondary)

            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.orange.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

// MARK: - Preview

#Preview("Banner") {
    VStack(spacing: 16) {
        CoachingBannerView(
            tip: CoachingTipTemplates.progressTip(steps: 5000, goal: 10000),
            onDismiss: {},
            onRefresh: {}
        )

        CoachingBannerView(
            tip: CoachingTipTemplates.iwtTips[0]
        )
    }
    .padding()
    .background(Color(.systemGroupedBackground))
}

#Preview("Cards") {
    ScrollView {
        VStack(spacing: 16) {
            CoachingCardView(
                tip: CoachingTipTemplates.motivationTips[0],
                style: .featured
            )

            CoachingCardView(
                tip: CoachingTipTemplates.healthTips[0],
                style: .standard
            )

            CoachingCardView(
                tip: CoachingTipTemplates.iwtTips[0],
                style: .compact
            )
        }
        .padding()
    }
    .background(Color(.systemGroupedBackground))
}
