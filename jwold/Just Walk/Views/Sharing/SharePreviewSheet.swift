//
//  SharePreviewSheet.swift
//  Just Walk
//
//  Preview sheet shown before sharing an achievement card.
//  Shows a preview of the card and share options.
//

import SwiftUI

struct SharePreviewSheet: View {
    let cardType: ShareCardType
    let onDismiss: () -> Void

    @State private var caption: String = ""
    @State private var isSharing = false
    @Environment(\.dismiss) private var dismiss

    init(cardType: ShareCardType, onDismiss: @escaping () -> Void = {}) {
        self.cardType = cardType
        self.onDismiss = onDismiss
        self._caption = State(initialValue: cardType.suggestedCaption)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Card preview
                cardPreview
                    .padding(.top, JWDesign.Spacing.lg)

                Spacer().frame(height: JWDesign.Spacing.lg)

                // Caption editor
                captionSection

                Spacer()

                // Share button
                shareButton

                Spacer().frame(height: JWDesign.Spacing.lg)
            }
            .padding(.horizontal, JWDesign.Spacing.horizontalInset)
            .background(JWDesign.Colors.background)
            .navigationTitle("Share Your Achievement")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        dismiss()
                        onDismiss()
                    }
                }
            }
        }
    }

    // MARK: - Card Preview

    private var cardPreview: some View {
        // Preview at 1/3 scale
        ShareCardRenderer(cardType: cardType)
            .frame(width: 1080 / 3, height: 1920 / 3)
            .clipShape(RoundedRectangle(cornerRadius: JWDesign.Radius.card))
            .shadow(
                color: .black.opacity(0.3),
                radius: 20,
                y: 10
            )
    }

    // MARK: - Caption Section

    private var captionSection: some View {
        VStack(alignment: .leading, spacing: JWDesign.Spacing.sm) {
            Text("Caption")
                .font(JWDesign.Typography.caption)
                .foregroundStyle(.secondary)

            TextField("Add a caption...", text: $caption, axis: .vertical)
                .font(JWDesign.Typography.body)
                .padding(JWDesign.Spacing.md)
                .background(JWDesign.Colors.secondaryBackground)
                .clipShape(RoundedRectangle(cornerRadius: JWDesign.Radius.medium))
                .lineLimit(3...6)
        }
    }

    // MARK: - Share Button

    private var shareButton: some View {
        Button {
            shareCard()
        } label: {
            HStack(spacing: JWDesign.Spacing.sm) {
                if isSharing {
                    ProgressView()
                        .tint(.white)
                } else {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 18, weight: .semibold))
                }
                Text("Share")
                    .font(JWDesign.Typography.headlineBold)
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, JWDesign.Spacing.md)
            .background(JWDesign.Colors.brandSecondary)
            .clipShape(RoundedRectangle(cornerRadius: JWDesign.Radius.medium))
        }
        .disabled(isSharing)
    }

    // MARK: - Share Action

    private func shareCard() {
        isSharing = true
        HapticService.shared.playSelection()

        // Render the card to an image
        guard let image = ShareService.shared.renderShareCard(cardType) else {
            isSharing = false
            return
        }

        // Present native share sheet
        ShareService.shared.presentShareSheet(image: image, caption: caption)

        // Reset state after a delay (share sheet is presented modally)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            isSharing = false
        }
    }
}

// MARK: - Reusable Share Button Component

struct ShareAchievementButton: View {
    let cardType: ShareCardType
    @State private var showSharePreview = false

    var body: some View {
        Button {
            HapticService.shared.playSelection()
            showSharePreview = true
        } label: {
            HStack(spacing: JWDesign.Spacing.xs) {
                Image(systemName: "square.and.arrow.up")
                    .font(.system(size: 14, weight: .semibold))
                Text("Share")
                    .font(JWDesign.Typography.subheadlineBold)
            }
            .foregroundStyle(JWDesign.Colors.brandSecondary)
            .padding(.horizontal, JWDesign.Spacing.md)
            .padding(.vertical, JWDesign.Spacing.sm)
            .background(JWDesign.Colors.brandSecondary.opacity(0.15))
            .clipShape(Capsule())
        }
        .sheet(isPresented: $showSharePreview) {
            SharePreviewSheet(cardType: cardType)
                .presentationDetents([.large])
        }
    }
}

// MARK: - Compact Share Button (for inline use)

struct CompactShareButton: View {
    let cardType: ShareCardType
    @State private var showSharePreview = false

    var body: some View {
        Button {
            HapticService.shared.playSelection()
            showSharePreview = true
        } label: {
            Image(systemName: "square.and.arrow.up")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.secondary)
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .sheet(isPresented: $showSharePreview) {
            SharePreviewSheet(cardType: cardType)
                .presentationDetents([.large])
        }
    }
}

// MARK: - Preview

#Preview("Share Preview - Daily Goal") {
    SharePreviewSheet(
        cardType: .dailyGoal(DailyGoalShareData(
            date: Date(),
            steps: 12450,
            goal: 10000,
            distanceMiles: 5.2,
            celebrationPhrase: "Crushed it!"
        ))
    )
}

#Preview("Share Preview - Streak") {
    SharePreviewSheet(
        cardType: .streakMilestone(StreakMilestoneShareData(
            streakCount: 30,
            streakStartDate: Calendar.current.date(byAdding: .day, value: -30, to: Date()),
            motivationalText: "A full month of daily walks!",
            hasShield: true
        ))
    )
}

#Preview("Share Button") {
    VStack {
        ShareAchievementButton(
            cardType: .dailyGoal(DailyGoalShareData(
                date: Date(),
                steps: 12450,
                goal: 10000,
                distanceMiles: 5.2,
                celebrationPhrase: "Crushed it!"
            ))
        )

        CompactShareButton(
            cardType: .streakMilestone(StreakMilestoneShareData(
                streakCount: 30,
                streakStartDate: nil,
                motivationalText: "A full month!",
                hasShield: false
            ))
        )
    }
    .padding()
}
