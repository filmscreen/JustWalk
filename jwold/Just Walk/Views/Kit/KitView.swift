//
//  KitView.swift
//  Just Walk
//
//  Gear recommendations with horizontal carousels and coaching insights.
//

import SwiftUI

struct KitView: View {
    @ObservedObject private var prioritizationService = KitPrioritizationService.shared
    @EnvironmentObject var storeManager: StoreManager
    @State private var showFocusModePaywall = false
    @State private var selectedProduct: KitProduct?

    var body: some View {
        NavigationStack {
            ScrollViewReader { proxy in
                VStack(spacing: 0) {
                    // Header matching Dashboard style
                    HStack {
                        Text("Progress")
                            .font(JWDesign.Typography.displaySmall)
                            .foregroundStyle(.primary)
                        Spacer()
                    }
                    .padding(.horizontal, JWDesign.Spacing.horizontalInset)
                    .padding(.top, JWDesign.Spacing.md)
                    .padding(.bottom, JWDesign.Spacing.sm)

                    ScrollView {
                        VStack(spacing: JWDesign.Spacing.xxxl) {
                            // Full Activity Chart (moved from Today tab)
                            ActivityTileView()
                                .padding(.horizontal, JWDesign.Spacing.horizontalInset)

                            // Daily Coaching Insights (Teal accent)
                            coachingInsightsSection

                            // Curated Gear Header
                            gearSectionHeader

                            // Product Carousels (Orange accent)
                            gearCarousel(
                                title: "Footwear",
                                subtitle: "The right shoes protect your joints and keep you walking longer without pain.",
                                icon: "shoe.fill",
                                products: prioritizationService.footwearProducts
                            )

                            gearCarousel(
                                title: "Walk From Home",
                                subtitle: "Get your steps in rain or shine—no excuses, no weather worries.",
                                icon: "figure.walk.treadmill",
                                products: prioritizationService.walkingPadsProducts
                            )

                            gearCarousel(
                                title: "Recovery & Wellness",
                                subtitle: "Help your muscles bounce back faster so you're ready to walk again tomorrow.",
                                icon: "heart.circle.fill",
                                products: prioritizationService.recoveryProducts
                            )

                            gearCarousel(
                                title: "Supplements",
                                subtitle: "Give your body the fuel it needs to stay strong and keep moving.",
                                icon: "pills.fill",
                                products: prioritizationService.supplementsProducts
                            )

                            gearCarousel(
                                title: "Intensity",
                                subtitle: "Burn more calories and build strength by adding weight to your walks.",
                                icon: "flame.fill",
                                products: prioritizationService.intensityProducts
                            )
                        }
                        .padding(.vertical, JWDesign.Spacing.lg)
                        .padding(.bottom, JWDesign.Spacing.tabBarSafeArea)
                        .id("top")
                    }
                }
                .onReceive(NotificationCenter.default.publisher(for: .scrollToTop)) { notification in
                    if let tab = notification.object as? AppTab, tab == .levelUp {
                        withAnimation {
                            proxy.scrollTo("top", anchor: .top)
                        }
                    }
                }
            }
            .background(JWDesign.Colors.background)
            .toolbar(.hidden, for: .navigationBar)
            .task {
                await prioritizationService.evaluatePrioritization()
            }
        }
        .sheet(isPresented: $showFocusModePaywall) {
            ProPaywallView()
        }
        .sheet(item: $selectedProduct) { product in
            ProductDetailSheet(
                product: product,
                onDirectLink: { openDirectLink(product) },
                onAmazonLink: { openAmazonLink(product) },
                onMensLink: { openMensLink(product) },
                onWomensLink: { openWomensLink(product) }
            )
            .presentationDetents([.medium, .large])
        }
    }

    // MARK: - Daily Coaching Insights Section

    private var coachingInsightsSection: some View {
        VStack(alignment: .leading, spacing: JWDesign.Spacing.md) {
            // Section header with teal accent (coaching = teal)
            HStack(spacing: JWDesign.Spacing.sm) {
                Image(systemName: "brain.head.profile")
                    .font(.system(size: JWDesign.IconSize.medium))
                    .foregroundStyle(JWDesign.Colors.brandSecondary)
                Text("Daily Coaching Insights")
                    .font(JWDesign.Typography.headline)
                    .foregroundStyle(.primary)
            }
            .padding(.horizontal, JWDesign.Spacing.horizontalInset)

            // Horizontal scroll of InsightCards
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: JWDesign.Spacing.md) {
                    ForEach(DailyInsightsManager.shared.todaysInsights) { insight in
                        InsightCard(insight: insight)
                    }
                }
                .padding(.horizontal, JWDesign.Spacing.horizontalInset)
            }
        }
    }

    // MARK: - Curated Gear Header

    private var gearSectionHeader: some View {
        HStack(spacing: JWDesign.Spacing.sm) {
            Image(systemName: "sparkles")
                .font(.system(size: JWDesign.IconSize.medium))
                .foregroundStyle(.orange)
            Text("Curated Gear")
                .font(JWDesign.Typography.headline)
                .foregroundStyle(.primary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, JWDesign.Spacing.horizontalInset)
    }

    // MARK: - Gear Carousel

    private func gearCarousel(
        title: String,
        subtitle: String,
        icon: String,
        products: [KitProduct]
    ) -> some View {
        VStack(alignment: .leading, spacing: JWDesign.Spacing.md) {
            // Section header with orange accent (commerce = orange)
            VStack(alignment: .leading, spacing: JWDesign.Spacing.xxs) {
                HStack(spacing: JWDesign.Spacing.md) {
                    Image(systemName: icon)
                        .font(.system(size: JWDesign.IconSize.small))
                        .foregroundStyle(.orange)
                        .frame(width: JWDesign.IconSize.small, alignment: .center)
                    Text(title)
                        .font(JWDesign.Typography.subheadlineBold)
                        .foregroundStyle(.primary)
                    Spacer()
                }
                Text(subtitle)
                    .font(JWDesign.Typography.caption)
                    .foregroundStyle(.tertiary)
                    .padding(.leading, JWDesign.IconSize.small + JWDesign.Spacing.md)
            }
            .padding(.horizontal, JWDesign.Spacing.horizontalInset)

            // Horizontal scroll of compact cards
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: JWDesign.Spacing.md) {
                    ForEach(products) { product in
                        CompactProductCard(product: product) {
                            selectedProduct = product
                        }
                    }
                }
                .padding(.horizontal, JWDesign.Spacing.horizontalInset)
            }
        }
    }

    // MARK: - Actions

    private func openDirectLink(_ product: KitProduct) {
        if let url = product.directURL {
            UIApplication.shared.open(url)
        }
    }

    private func openAmazonLink(_ product: KitProduct) {
        openAmazonURL(product.amazonURL)
    }

    private func openMensLink(_ product: KitProduct) {
        openAmazonURL(product.amazonMensURL)
    }

    private func openWomensLink(_ product: KitProduct) {
        openAmazonURL(product.amazonWomensURL)
    }

    private func openAmazonURL(_ url: URL?) {
        guard let url = url else { return }
        UIApplication.shared.open(url)
    }
}

struct InsightCard: View {
    let insight: LevelUpInsight
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: JWDesign.Spacing.sm) {
            HStack {
                Image(systemName: insight.icon)
                    .font(.title2)
                    .foregroundStyle(.white)
                    .padding(JWDesign.Spacing.sm)
                    .background(JWDesign.Gradients.brand)
                    .clipShape(Circle())
                Spacer()
            }

            Text(insight.title)
                .font(JWDesign.Typography.headlineBold)
                .foregroundStyle(.primary)

            Text(insight.description)
                .font(JWDesign.Typography.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(nil)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(JWDesign.Spacing.cardPadding)
        .frame(width: 240, height: 195)
        .background(JWDesign.Colors.secondaryBackground)
        .clipShape(RoundedRectangle(cornerRadius: JWDesign.Radius.xxl))
        .shadow(
            color: JWDesign.Shadows.card(colorScheme: colorScheme).color,
            radius: 5,
            y: 2
        )
    }
}

#Preview {
    KitView()
        .environmentObject(StoreManager.shared)
}
