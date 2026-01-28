//
//  PostWalkSummaryView.swift
//  JustWalk
//
//  Post-walk summary showing achievements and stats with animations
//

import SwiftUI
import MapKit
import StoreKit

struct PostWalkSummaryView: View {
    let walk: TrackedWalk
    var insightContent: AnyView? = nil

    @Environment(\.dismiss) private var dismiss
    @Environment(\.requestReview) private var requestReview

    @State private var showConfetti = false
    @State private var isSaving = false
    @State private var showSaveSuccess = false

    // Animated stat values
    @State private var animatedDuration = 0
    @State private var animatedSteps = 0
    @State private var animatedDistance = 0.0
    @State private var statsAnimationComplete = false

    private var isSubstantialWalk: Bool {
        walk.durationMinutes >= 5
    }

    private var isIntervalWalk: Bool {
        walk.intervalProgram != nil
    }

    private var isIntervalCompleted: Bool {
        walk.intervalProgram != nil && walk.intervalCompleted == true
    }

    private var headerTitle: String {
        if isIntervalWalk {
            return "Interval Complete"
        }
        return isSubstantialWalk ? "Walk Complete!" : "Walk Logged"
    }

    var body: some View {
        ZStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Header
                    VStack(spacing: 8) {
                        if isIntervalCompleted {
                            AnimatedCheckmark()
                                .padding(.bottom, 4)
                        }

                        Text(headerTitle)
                            .font(.title.bold())

                        if !isSubstantialWalk && !isIntervalWalk {
                            Text("Nice effort! Keep building the habit.")
                                .font(JW.Font.subheadline)
                                .foregroundStyle(JW.Color.textSecondary)
                                .multilineTextAlignment(.center)
                        }
                    }
                    .padding(.top, 24)

                    // Stats Row (animated)
                    HStack(spacing: 8) {
                        StatCard(icon: "clock", value: formatDuration(animatedDuration), label: "Duration")
                            .staggeredAppearance(index: 0, delay: 0.08)
                        StatCard(icon: "figure.walk", value: animatedSteps.formatted(), label: "Steps")
                            .staggeredAppearance(index: 1, delay: 0.08)
                        StatCard(icon: "map", value: formatDistance(animatedDistance), label: "Distance")
                            .staggeredAppearance(index: 2, delay: 0.08)
                    }
                    .padding(.horizontal)

                    // Interval preset info
                    if let program = walk.intervalProgram {
                        VStack(spacing: 4) {
                            Text("\(program.displayName) · \(program.intervalCount) cycles")
                                .font(JW.Font.headline)
                                .foregroundStyle(JW.Color.textPrimary)
                            Text(program.structureLabel)
                                .font(JW.Font.caption)
                                .foregroundStyle(JW.Color.textSecondary)
                        }
                    }

                    // Upgrade prompt — above map so it's prominent
                    IntervalUpsellBanner(walk: walk)
                        .padding(.horizontal)

                    // Mini Map with route drawing animation
                    if walk.routeCoordinates.count >= 2 {
                        AnimatedPostWalkMapView(coordinates: walk.routeCoordinates)
                            .frame(height: 200)
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                            .padding(.horizontal)
                    } else {
                        RouteNotAvailablePlaceholder()
                            .padding(.horizontal)
                    }

                    // Interval insight card
                    if isIntervalWalk {
                        IntervalInsightCard()
                            .padding(.horizontal)
                    }

                    // Optional insight content slot
                    if let insightContent {
                        insightContent
                            .padding(.horizontal)
                    }

                    // Share card — only for substantial walks
                    if isSubstantialWalk {
                        ShareWalkCard(walk: walk, onShare: { shareWalk() }, onSave: { saveWalkImage() })
                            .padding(.horizontal)
                    }

                    // Short walk education — only for non-interval, almost-qualifying walks
                    if !isIntervalWalk && walk.durationMinutes >= 2 && walk.durationMinutes < 5 {
                        ShortWalkEducationView()
                            .padding(.horizontal)
                    }

                    Spacer(minLength: 100)
                }
            }

            // Done button
            VStack {
                Spacer()

                Button(action: {
                    dismiss()
                }) {
                    Text("Done")
                        .font(JW.Font.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(JW.Color.accent)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                }
                .pressEffect()
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
            }

            // Confetti overlay
            ConfettiView(isActive: $showConfetti)
        }
        .onAppear {
            startCountingAnimation()

            if isSubstantialWalk {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    showConfetti = true
                    JustWalkHaptics.goalComplete()
                }
            }

            // Extra confetti burst for interval completion
            if isIntervalCompleted {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                    showConfetti = true
                }
            }

            // Request App Store review after substantial walks (iOS rate-limits automatically)
            if isSubstantialWalk && walk.durationMinutes >= 15 {
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                    requestReview()
                }
            }
        }
        .background(JW.Color.backgroundPrimary)
        .interactiveDismissDisabled()
    }

    // MARK: - Counting Animation

    private func startCountingAnimation() {
        let totalFrames = 30 // ~1.5s at 20fps
        var frame = 0
        Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { timer in
            frame += 1
            let progress = Double(frame) / Double(totalFrames)
            let eased = easeOutCubic(progress)

            animatedDuration = Int(Double(walk.durationMinutes) * eased)
            animatedSteps = Int(Double(walk.steps) * eased)
            animatedDistance = walk.distanceMeters * eased

            if frame >= totalFrames {
                timer.invalidate()
                // Set exact final values
                animatedDuration = walk.durationMinutes
                animatedSteps = walk.steps
                animatedDistance = walk.distanceMeters
                statsAnimationComplete = true
            }
        }
    }

    private func easeOutCubic(_ t: Double) -> Double {
        let t1 = t - 1
        return t1 * t1 * t1 + 1
    }

    // MARK: - Sharing

    private var useMetric: Bool {
        PersistenceManager.shared.cachedUseMetric
    }

    private func renderWalkCard() -> UIImage? {
        let card = WalkCompleteShareCard(
            durationMinutes: walk.durationMinutes,
            steps: walk.steps,
            distanceMeters: walk.distanceMeters,
            routeMapImage: nil,
            useMetric: useMetric
        )
        return ShareCardRenderer.render(card, size: WalkCompleteShareCard.cardSize)
    }

    private func shareWalk() {
        guard let image = renderWalkCard() else { return }
        ShareCardRenderer.shareImage(image)
    }

    private func saveWalkImage() {
        guard !isSaving else { return }
        isSaving = true
        guard let image = renderWalkCard() else {
            isSaving = false
            return
        }
        ShareCardRenderer.saveToPhotos(image) { success in
            isSaving = false
            showSaveSuccess = success
        }
    }

    private func formatDuration(_ minutes: Int) -> String {
        minutes < 1 ? "<1 min" : "\(minutes) min"
    }

    private func formatDistance(_ meters: Double) -> String {
        if useMetric {
            if meters < 1000 {
                return "\(Int(meters))m"
            } else {
                return String(format: "%.1f km", meters / 1000)
            }
        } else {
            let miles = meters / 1609.344
            return String(format: "%.2f mi", miles)
        }
    }
}

// MARK: - Animated Checkmark

struct AnimatedCheckmark: View {
    @State private var progress: CGFloat = 0

    var body: some View {
        ZStack {
            Circle()
                .fill(JW.Color.accent.opacity(0.15))
                .frame(width: 88, height: 88)

            CompletionCheckmarkShape()
                .trim(from: 0, to: progress)
                .stroke(JW.Color.accent, style: StrokeStyle(lineWidth: 6, lineCap: .round, lineJoin: .round))
                .frame(width: 44, height: 44)
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.6).delay(0.3)) {
                progress = 1
            }
        }
    }
}

struct CompletionCheckmarkShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let w = rect.width
        let h = rect.height
        // Start from left, go down to bottom-center, then up to top-right
        path.move(to: CGPoint(x: w * 0.15, y: h * 0.5))
        path.addLine(to: CGPoint(x: w * 0.4, y: h * 0.78))
        path.addLine(to: CGPoint(x: w * 0.85, y: h * 0.22))
        return path
    }
}

// MARK: - Animated Post Walk Map View

struct AnimatedPostWalkMapView: View {
    let coordinates: [CodableCoordinate]

    @State private var visibleCount = 0
    @State private var region: MKCoordinateRegion = .init()

    private var clCoordinates: [CLLocationCoordinate2D] {
        coordinates.map { CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude) }
    }

    private var visibleCoordinates: [CLLocationCoordinate2D] {
        Array(clCoordinates.prefix(visibleCount))
    }

    var body: some View {
        Map {
            if visibleCoordinates.count >= 2 {
                MapPolyline(coordinates: visibleCoordinates)
                    .stroke(JW.Color.accent, lineWidth: 4)
            }

            // Start marker
            if let first = clCoordinates.first {
                Annotation("Start", coordinate: first) {
                    Circle()
                        .fill(.green)
                        .frame(width: 12, height: 12)
                }
            }

            // End marker (only when animation complete)
            if visibleCount >= clCoordinates.count, let last = clCoordinates.last {
                Annotation("End", coordinate: last) {
                    Circle()
                        .fill(.red)
                        .frame(width: 12, height: 12)
                }
            }
        }
        .mapStyle(.standard(elevation: .flat))
        .allowsHitTesting(false)
        .onAppear {
            animateRoute()
        }
    }

    private func animateRoute() {
        guard !clCoordinates.isEmpty else { return }
        let total = clCoordinates.count
        let duration = 1.5 // seconds
        let interval = duration / Double(total)

        Timer.scheduledTimer(withTimeInterval: max(0.02, interval), repeats: true) { timer in
            if visibleCount < total {
                visibleCount += max(1, total / 60) // at least 60 frames
            } else {
                visibleCount = total
                timer.invalidate()
            }
        }
    }
}

// MARK: - Stat Card

struct StatCard: View {
    let icon: String
    let value: String
    let label: String

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(JW.Font.body)
                .foregroundStyle(JW.Color.accentBlue)

            Text(value)
                .font(JW.Font.subheadline.bold())
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            Text(label)
                .font(JW.Font.caption2)
                .foregroundStyle(JW.Color.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .padding(.horizontal, 8)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(JW.Color.backgroundCard)
        )
    }
}

// MARK: - Post Walk Map View (non-animated, kept for backward compatibility)

struct PostWalkMapView: View {
    let coordinates: [CodableCoordinate]

    @State private var region: MKCoordinateRegion = .init()

    private var clCoordinates: [CLLocationCoordinate2D] {
        coordinates.map { CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude) }
    }

    var body: some View {
        Map {
            if clCoordinates.count >= 2 {
                MapPolyline(coordinates: clCoordinates)
                    .stroke(JW.Color.accent, lineWidth: 4)

                // Start marker
                if let first = clCoordinates.first {
                    Annotation("Start", coordinate: first) {
                        Circle()
                            .fill(.green)
                            .frame(width: 12, height: 12)
                    }
                }

                // End marker
                if let last = clCoordinates.last {
                    Annotation("End", coordinate: last) {
                        Circle()
                            .fill(.red)
                            .frame(width: 12, height: 12)
                    }
                }
            }
        }
        .mapStyle(.standard(elevation: .flat))
        .allowsHitTesting(false)
        .onAppear {
            calculateRegion()
        }
    }

    private func calculateRegion() {
        guard !clCoordinates.isEmpty else { return }

        let latitudes = clCoordinates.map { $0.latitude }
        let longitudes = clCoordinates.map { $0.longitude }

        let minLat = latitudes.min() ?? 0
        let maxLat = latitudes.max() ?? 0
        let minLon = longitudes.min() ?? 0
        let maxLon = longitudes.max() ?? 0

        let center = CLLocationCoordinate2D(
            latitude: (minLat + maxLat) / 2,
            longitude: (minLon + maxLon) / 2
        )

        let span = MKCoordinateSpan(
            latitudeDelta: (maxLat - minLat) * 1.3 + 0.005,
            longitudeDelta: (maxLon - minLon) * 1.3 + 0.005
        )

        region = MKCoordinateRegion(center: center, span: span)
    }
}

// MARK: - Short Walk Education View

struct ShortWalkEducationView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "lightbulb.fill")
                    .foregroundStyle(.yellow)

                Text("Why 5 Minutes?")
                    .font(JW.Font.headline)
            }

            Text("Research shows that walks of at least 5 minutes provide meaningful health benefits. Shorter walks are still tracked and count toward your daily steps!")
                .font(JW.Font.subheadline)
                .foregroundStyle(JW.Color.textSecondary)

            HStack(spacing: 16) {
                BenefitBadge(icon: "heart.fill", text: "Heart Health", color: .red)
                BenefitBadge(icon: "brain.head.profile", text: "Mental Clarity", color: .purple)
                BenefitBadge(icon: "flame.fill", text: "Burn Calories", color: .orange)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(JW.Color.backgroundCard)
        )
    }
}

struct BenefitBadge: View {
    let icon: String
    let text: String
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(JW.Font.title3)
                .foregroundStyle(color)

            Text(text)
                .font(JW.Font.caption2)
                .foregroundStyle(JW.Color.textSecondary)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Share Walk Card

struct ShareWalkCard: View {
    let walk: TrackedWalk
    var onShare: () -> Void = {}
    var onSave: () -> Void = {}

    var body: some View {
        VStack(spacing: 12) {
            Text("Share Your Walk")
                .font(JW.Font.headline)

            HStack(spacing: 16) {
                ShareButton(icon: "square.and.arrow.up", label: "Share", action: onShare)
                ShareButton(icon: "camera.fill", label: "Save Image", action: onSave)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(JW.Color.backgroundCard)
        )
    }
}

struct ShareButton: View {
    let icon: String
    let label: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(JW.Font.title2)

                Text(label)
                    .font(JW.Font.caption)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(JW.Color.accentBlue.opacity(0.1))
            .foregroundStyle(JW.Color.accentBlue)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonPressEffect()
    }
}

// MARK: - Interval Insight Card

struct IntervalInsightCard: View {
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "chart.line.uptrend.xyaxis")
                .font(.title3)
                .foregroundStyle(JW.Color.accent)

            VStack(alignment: .leading, spacing: 2) {
                Text("You burned approximately 15% more calories than a regular walk. Nice work.")
                    .font(JW.Font.subheadline)
                    .foregroundStyle(JW.Color.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(JW.Color.backgroundCard)
        )
    }
}

// MARK: - Interval Upsell Banner

struct IntervalUpsellBanner: View {
    let walk: TrackedWalk

    @State private var showUpgrade = false

    private var shouldShow: Bool {
        walk.intervalProgram != nil
        && !SubscriptionManager.shared.isPro
        && (WalkUsageManager.shared.remainingFree(for: .interval) ?? 1) == 0
        && walk.durationMinutes >= 5 // Only show if walk counted against limit
    }

    var body: some View {
        if shouldShow {
            VStack(spacing: JW.Spacing.md) {
                HStack(spacing: JW.Spacing.sm) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title3)
                        .foregroundStyle(JW.Color.danger)

                    Text("You've used your free interval walk this week.")
                        .font(JW.Font.subheadline.weight(.medium))
                        .foregroundStyle(JW.Color.textPrimary)

                    Spacer()
                }

                Button {
                    showUpgrade = true
                } label: {
                    Text("Upgrade to Pro")
                        .font(JW.Font.subheadline.weight(.semibold))
                        .foregroundStyle(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, JW.Spacing.md)
                        .background(JW.Color.accent)
                        .clipShape(RoundedRectangle(cornerRadius: JW.Radius.md))
                }
                .buttonPressEffect()
            }
            .padding(JW.Spacing.lg)
            .background(
                RoundedRectangle(cornerRadius: JW.Radius.lg)
                    .fill(JW.Color.backgroundCard)
            )
            .overlay(
                RoundedRectangle(cornerRadius: JW.Radius.lg)
                    .stroke(JW.Color.danger.opacity(0.3), lineWidth: 1)
            )
            .sheet(isPresented: $showUpgrade) {
                ProUpgradeView(onComplete: { showUpgrade = false })
            }
        }
    }
}

// MARK: - Preview

#Preview("Substantial Walk") {
    PostWalkSummaryView(
        walk: TrackedWalk(
            id: UUID(),
            startTime: Date().addingTimeInterval(-1800),
            endTime: Date(),
            durationMinutes: 30,
            steps: 3500,
            distanceMeters: 2800,
            mode: .free,
            intervalProgram: nil,
            intervalCompleted: nil,
            routeCoordinates: []
        )
    )
}

#Preview("Interval Completed") {
    PostWalkSummaryView(
        walk: TrackedWalk(
            id: UUID(),
            startTime: Date().addingTimeInterval(-1800),
            endTime: Date(),
            durationMinutes: 30,
            steps: 3500,
            distanceMeters: 2800,
            mode: .interval,
            intervalProgram: .medium,
            intervalCompleted: true,
            routeCoordinates: []
        )
    )
}

#Preview("Short Walk") {
    PostWalkSummaryView(
        walk: TrackedWalk(
            id: UUID(),
            startTime: Date().addingTimeInterval(-180),
            endTime: Date(),
            durationMinutes: 3,
            steps: 350,
            distanceMeters: 280,
            mode: .free,
            intervalProgram: nil,
            intervalCompleted: nil,
            routeCoordinates: []
        )
    )
}
