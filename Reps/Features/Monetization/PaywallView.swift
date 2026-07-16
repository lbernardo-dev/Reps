import RevenueCat
import RevenueCatUI
import SwiftUI
import UIKit

struct PaywallView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @Environment(AppStore.self) private var store

    let presentation: PaywallPresentation
    let onDismissReason: ((PaywallDismissReason) -> Void)?

    @State private var selectedPlan: SubscriptionBillingCycle = .yearly
    @State private var isPurchasing = false
    @State private var isRestoring = false
    @State private var showStoreKitInfo = false
    @State private var storeKitInfoMessage = ""
    @State private var didAppear = false

    init(presentation: PaywallPresentation, onDismissReason: ((PaywallDismissReason) -> Void)? = nil) {
        self.presentation = presentation
        self.onDismissReason = onDismissReason
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 22) {
                    paywallHero
                    ContextualPaywallPreview(source: presentation.source, feature: presentation.feature)
                    trialTimeline
                    PlanComparisonCard()
                    planSelector
                    legalFooter
                }
                .padding(.horizontal, PulseTheme.screenHorizontalPadding)
                .padding(.top, 12)
                .padding(.bottom, 148)
                .opacity(didAppear ? 1 : 0)
                .offset(y: didAppear ? 0 : 14)
            }
            .scrollBounceBehavior(.basedOnSize, axes: .vertical)
            .background(alignment: .top) {
                RadialGradient(
                    colors: [PulseTheme.accent.opacity(0.20), .clear],
                    center: .top,
                    startRadius: 8,
                    endRadius: 340
                )
                .frame(height: 380)
                .ignoresSafeArea(edges: .top)
            }

            ctaFooter
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .screenBackground()
        .overlay(alignment: .top) { toolbar }
        .task {
            await store.refreshStoreKitProducts()
            await store.refreshRevenueCatCustomerInfo()
        }
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.82)) {
                didAppear = true
            }
        }
        .alert(localizedString("info"), isPresented: $showStoreKitInfo) {
            Button("aceptar", role: .cancel) {}
        } message: {
            Text(storeKitInfoMessage)
        }
    }

    private var toolbar: some View {
        HStack {
            restoreButton
            Spacer()
            closeButton
        }
        .padding(.top, 8)
        .padding(.horizontal, PulseTheme.screenHorizontalPadding)
    }

    private var restoreButton: some View {
        Button {
            Task { await restorePurchases() }
        } label: {
            Group {
                if isRestoring {
                    ProgressView()
                        .tint(PulseTheme.textPrimary)
                } else {
                    Image(systemName: "arrow.counterclockwise")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(PulseTheme.textPrimary)
                }
            }
            .frame(minWidth: 44, minHeight: 44)
            .navigationGlassCircle(.secondary)
        }
        .buttonStyle(.plain)
        .disabled(isRestoring)
        .accessibilityLabel(localizedString("paywall_restore_licenses"))
    }

    private var closeButton: some View {
        Button {
            HapticService.impact(.light)
            close(reason: .close)
        } label: {
            Image(systemName: "xmark")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(PulseTheme.textPrimary)
                .frame(minWidth: 44, minHeight: 44)
                .navigationGlassCircle(.secondary)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(localizedString("close"))
    }

    private var paywallHero: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("reps_pro")
                    .font(.system(size: 46, weight: .black, design: .rounded))
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)

                Spacer(minLength: 12)

                Image(systemName: "bolt.heart.fill")
                    .font(.title2.weight(.black))
                    .foregroundStyle(PulseTheme.onColor(PulseTheme.accent))
                    .frame(width: 46, height: 46)
                    .background(PulseTheme.accent)
                    .clipShape(Circle())
            }

            Text("train_for_a_full_week_for_free")
                .font(.title2.weight(.black))

            Text("your_plan_advanced_analytics_and_automatic_progression_are_unlocked_today_cancel")
                .font(.body.weight(.semibold))
                .foregroundStyle(PulseTheme.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.top, 8)
    }

    private var primaryPurchaseButton: some View {
        Button {
            Task { await purchaseSelectedProduct() }
        } label: {
            HStack(spacing: 8) {
                if isPurchasing {
                    ProgressView()
                        .tint(PulseTheme.onColor(PulseTheme.accent))
                }
                Text(primaryButtonTitle)
                    .font(.headline)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 58)
            .foregroundStyle(PulseTheme.onColor(PulseTheme.accent))
            .background(PulseTheme.accent)
            .clipShape(RoundedRectangle(cornerRadius: PulseTheme.compactRadius, style: .continuous))
            .shadow(color: PulseTheme.accent.opacity(0.35), radius: 16, y: 6)
        }
        .buttonStyle(PressableCardStyle())
        .disabled(isPurchasing || selectedProduct == nil)
    }

    private var ctaFooter: some View {
        VStack(spacing: 10) {
            primaryPurchaseButton
            Text(purchaseDisclaimer)
                .font(.caption2)
                .foregroundStyle(PulseTheme.secondaryText)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, PulseTheme.screenHorizontalPadding)
        .padding(.top, 14)
        .padding(.bottom, 8)
        .background(alignment: .top) {
            Rectangle()
                .fill(PulseTheme.separator)
                .frame(height: 0.8)
        }
        .background(.ultraThinMaterial)
    }

    private var purchaseDisclaimer: String {
        selectedPlan.hasIntroTrial
            ? localizedString("value_7_days_free_included_in_weekly_monthly_and_annual_then_it_is_renewed_from")
            : localizedString("one_time_permanent_pro")
    }

    private var trialTimeline: some View {
        PulseCard(contentPadding: 18) {
            VStack(alignment: .leading, spacing: 18) {
                TrialTimelineRow(icon: "checkmark", title: "free_access", subtitle: "unlock_reps_pro_7_days")
                TrialTimelineRow(icon: "bell.fill", title: "day_5", subtitle: "trial_reminder_subtitle")
                TrialTimelineRow(icon: "chart.line.uptrend.xyaxis", title: "progress_label", subtitle: "trial_progress_subtitle")
            }
        }
    }

    private var planSelector: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(localizedKey("choose_your_access"))
                .font(.headline)

            VStack(spacing: 10) {
                ForEach(orderedPlans) { cycle in
                    Button {
                        selectPlan(cycle)
                    } label: {
                        PaywallPlanCard(
                            title: cycle.title,
                            subtitle: planSubtitle(for: cycle, product: store.storeKitProduct(for: cycle)),
                            price: priceText(for: cycle),
                            priceCaption: cycle == .yearly ? weeklyEquivalentCaption(for: cycle) : nil,
                            badge: badge(for: cycle),
                            hasTrial: cycle.hasIntroTrial,
                            isFeatured: cycle == .yearly,
                            isSelected: selectedPlan == cycle
                        )
                    }
                    .buttonStyle(PressableCardStyle())
                }
            }
        }
    }

    private var legalFooter: some View {
        VStack(spacing: 10) {
            Button {
                HapticService.selection()
                Purchases.shared.presentCodeRedemptionSheet()
            } label: {
                Text(localizedString("apply_promotional_code"))
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(PulseTheme.secondaryText)
            }
            .buttonStyle(.plain)

            VStack(spacing: 6) {
                HStack(spacing: 14) {
                    legalLink(localizedString("terms_of_service"), url: RepsLegalUrls.termsOfService, event: "paywall_terms_of_service")
                    Circle()
                        .fill(PulseTheme.tertiaryText)
                        .frame(width: 2.5, height: 2.5)
                    legalLink(localizedString("privacy_policy"), url: RepsLegalUrls.privacyPolicy, event: "paywall_privacy_policy")
                }
                legalLink(localizedString("subscription_terms"), url: RepsLegalUrls.subscriptionTerms, event: "paywall_subscription_terms")
            }
            .font(.caption2.weight(.semibold))
            .foregroundStyle(PulseTheme.tertiaryText)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 4)
    }

    private func legalLink(_ title: String, url: String, event: String) -> some View {
        Button {
            openLegalURL(url, event: event)
        } label: {
            Text(title)
                .underline()
        }
        .buttonStyle(.plain)
    }

    private func openLegalURL(_ urlString: String, event: String) {
        TelemetryService.shared.log(.supportSheetOpened, parameters: ["sheet": event])
        if let url = URL(string: urlString) {
            openURL(url)
        }
    }

    private var orderedPlans: [SubscriptionBillingCycle] {
        SubscriptionBillingCycle.allCases.filter { availablePlans.contains($0) }
    }

    private func selectPlan(_ cycle: SubscriptionBillingCycle) {
        guard selectedPlan != cycle else { return }
        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
            selectedPlan = cycle
        }
        store.trackPaywallPlanSelection(cycle, source: presentation.source)
    }

    private func priceText(for cycle: SubscriptionBillingCycle) -> String {
        store.storeKitProduct(for: cycle)?.storeProduct.localizedPriceString
            ?? localizedString("loading_app_store")
    }

    private func weeklyEquivalentCaption(for cycle: SubscriptionBillingCycle) -> String? {
        guard let perWeek = store.storeKitProduct(for: cycle)?.storeProduct.localizedPricePerWeek else {
            return nil
        }
        return "\(perWeek) \(localizedString("per_week"))"
    }

    private var availablePlans: [SubscriptionBillingCycle] {
        let loadedPlans = store.storeKitProducts.compactMap { package in
            StoreKitProductID(rawValue: package.identifier)?.billingCycle
        }

        if loadedPlans.isEmpty {
            return SubscriptionBillingCycle.allCases
        }

        return SubscriptionBillingCycle.allCases.filter { loadedPlans.contains($0) }
    }

    private var selectedProduct: Package? {
        store.storeKitProduct(for: selectedPlan)
    }

    private var primaryButtonTitle: String {
        guard selectedProduct != nil else {
            return localizedString("loading_app_store")
        }

        if selectedPlan.hasIntroTrial {
            return localizedString("redeem_free_week")
        }

        return localizedString("buy_lifetime")
    }

    private func planSubtitle(for cycle: SubscriptionBillingCycle, product: Package?) -> String {
        if cycle.hasIntroTrial {
            guard let price = product?.storeProduct.localizedPriceString else {
                return localizedString("loading_app_store")
            }
            return localizedFormat("first_week_free_then_format", price, renewalText(for: cycle))
        }

        return localizedString("one_time_permanent_pro")
    }

    private func renewalText(for cycle: SubscriptionBillingCycle) -> String {
        switch cycle {
        case .weekly: return localizedString("per_week")
        case .monthly: return localizedString("per_month")
        case .yearly: return localizedString("per_year")
        case .lifetime: return ""
        }
    }

    private func badge(for cycle: SubscriptionBillingCycle) -> String? {
        let base: String
        switch cycle {
        case .yearly: base = localizedString("best_value")
        case .monthly: base = localizedString("flexible_label")
        case .lifetime: return localizedString("one_time_payment")
        case .weekly: return localizedString("quick_trial")
        }

        guard let percent = discountPercent(for: cycle) else { return base }
        return "\(base) · \(localizedFormat("save_percent_format", percent))"
    }

    /// Savings vs. paying the weekly plan's price every week, using RevenueCat's
    /// per-week price breakdown so this tracks whatever prices are live in App
    /// Store Connect instead of hardcoded percentages.
    /// Weeks a plan is deemed equivalent to, for a weekly-price baseline comparison
    /// (e.g. a month "costs" 4 weekly renewals, a year 52).
    private func weeksEquivalent(for cycle: SubscriptionBillingCycle) -> Decimal? {
        switch cycle {
        case .monthly: return 4
        case .yearly: return 52
        case .weekly, .lifetime: return nil
        }
    }

    private func discountPercent(for cycle: SubscriptionBillingCycle) -> Int? {
        guard let weeks = weeksEquivalent(for: cycle),
              let weeklyPrice = store.storeKitProduct(for: .weekly)?.storeProduct.price,
              weeklyPrice > 0,
              let price = store.storeKitProduct(for: cycle)?.storeProduct.price else {
            return nil
        }

        let weeklyPriceValue = (weeklyPrice as NSDecimalNumber).doubleValue
        let priceValue = (price as NSDecimalNumber).doubleValue
        let weeksValue = (weeks as NSDecimalNumber).doubleValue

        let equivalentWeeklyCost = weeklyPriceValue * weeksValue
        guard priceValue < equivalentWeeklyCost, equivalentWeeklyCost > 0 else { return nil }

        let percent = (1 - priceValue / equivalentWeeklyCost) * 100
        return Int(percent.rounded())
    }

    private func purchaseSelectedProduct() async {
        guard let selectedProduct else {
            storeKitInfoMessage = store.storeKitErrorMessage ?? localizedString("storekit_products_unavailable")
            showStoreKitInfo = true
            return
        }

        HapticService.impact(.medium)
        isPurchasing = true
        defer { isPurchasing = false }

        store.trackPaywallCTA(selectedPlan, source: presentation.source)
        let didPurchase = await store.purchaseStoreKitProduct(selectedProduct)
        if didPurchase {
            HapticService.notification(.success)
            close(reason: .notNow)
        } else if let message = store.storeKitErrorMessage {
            HapticService.notification(.error)
            storeKitInfoMessage = message
            showStoreKitInfo = true
        }
    }

    private func restorePurchases() async {
        isRestoring = true
        defer { isRestoring = false }

        let restored = await store.restoreStoreKitPurchases()
        HapticService.notification(restored ? .success : .warning)
        storeKitInfoMessage = restored ? localizedString("licenses_restored_success") : localizedString("no_active_license_to_restore")
        showStoreKitInfo = true
    }

    private func close(reason: PaywallDismissReason) {
        if let onDismissReason {
            onDismissReason(reason)
        } else {
            store.dismissPaywall(reason: reason)
        }
        dismiss()
    }
}

struct SubscriptionCenterView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppStore.self) private var store
    @State private var presentingCustomerCenter = false

    var body: some View {
        NavigationStack {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 18) {
                    PulseCard {
                        VStack(alignment: .leading, spacing: 12) {
                            Text(verbatim: store.monetization.statusLabel)
                                .font(.title3.bold())
                            Text(verbatim: store.monetization.hasProAccess ? localizedString("pro_access_active_on_device") : localizedString("currently_on_reps_free"))
                                .foregroundStyle(PulseTheme.secondaryText)

                            if let cycle = store.monetization.billingCycle, store.monetization.hasProAccess {
                                Label(localizedFormat("plan_cycle_format", cycle.title.lowercased()), systemImage: "checkmark.seal.fill")
                                    .foregroundStyle(PulseTheme.accent)
                            }
                        }
                    }

                    PulseCard {
                        VStack(alignment: .leading, spacing: 12) {
                            Text(verbatim: localizedString("incluye_reps_pro"))
                                .font(.headline)
                            ForEach([
                                ProductFeature.configurableProgression,
                                .advancedAnalytics,
                                .automaticBackups
                            ]) { feature in
                                PaywallBenefitRow(feature: feature)
                            }
                        }
                    }

                    Button {
                        dismiss()
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                            store.presentPaywall(source: .profileSubscription, feature: nil, trigger: .manual)
                        }
                    } label: {
                        Text(store.monetization.hasProAccess ? localizedString("paywall_manage_pro_title") : localizedString("paywall_unlock_pro_title"))
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .frame(height: 52)
                            .foregroundStyle(PulseTheme.onColor(PulseTheme.accent))
                            .background(PulseTheme.accent)
                            .clipShape(RoundedRectangle(cornerRadius: PulseTheme.compactRadius, style: .continuous))
                    }
                    .buttonStyle(.plain)

                    if store.monetization.hasProAccess {
                        Button {
                            presentingCustomerCenter = true
                        } label: {
                            Label(localizedString("manage_subscription"), systemImage: "person.crop.circle.badge.checkmark")
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                                .frame(height: 52)
                                .foregroundStyle(PulseTheme.accent)
                                .background(PulseTheme.grouped)
                                .clipShape(RoundedRectangle(cornerRadius: PulseTheme.compactRadius, style: .continuous))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, PulseTheme.screenHorizontalPadding)
                .padding(.vertical, 20)
                .padding(.bottom, 24)
            }
            .scrollBounceBehavior(.basedOnSize, axes: .vertical)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .navigationTitle(localizedString("subscription"))
            .navigationBarTitleDisplayMode(.inline)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .screenBackground()
        .presentCustomerCenter(
            isPresented: $presentingCustomerCenter,
            onDismiss: {
                presentingCustomerCenter = false
                Task { await store.refreshRevenueCatCustomerInfo() }
            }
        )
    }
}

struct PaywallLockedCard: View {
    let title: String
    let message: String
    let buttonTitle: String
    let action: () -> Void

    var body: some View {
        PulseCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 10) {
                    Image(systemName: "lock.fill")
                        .foregroundStyle(PulseTheme.onColor(PulseTheme.accent))
                        .frame(width: 34, height: 34)
                        .background(PulseTheme.accent)
                        .clipShape(Circle())
                    Text(localizedKey(title))
                        .font(.headline)
                }

                Text(localizedKey(message))
                    .font(.subheadline)
                    .foregroundStyle(PulseTheme.secondaryText)

                Button(action: action) {
                    Text(localizedKey(buttonTitle))
                        .font(.subheadline.weight(.bold))
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                        .foregroundStyle(PulseTheme.onColor(PulseTheme.accent))
                        .background(PulseTheme.accent)
                        .clipShape(RoundedRectangle(cornerRadius: PulseTheme.compactRadius, style: .continuous))
                }
                .buttonStyle(.plain)
            }
        }
    }
}

private struct PaywallBenefitRow: View {
    let feature: ProductFeature

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(PulseTheme.accent)
                .padding(.top, 1)

            VStack(alignment: .leading, spacing: 4) {
                Text(feature.title)
                    .font(.headline)
                Text(feature.summary)
                    .font(.subheadline)
                    .foregroundStyle(PulseTheme.secondaryText)
            }

            Spacer()
        }
        .padding(14)
        .background(PulseTheme.card)
        .clipShape(RoundedRectangle(cornerRadius: PulseTheme.compactRadius, style: .continuous))
    }
}

private struct TrialTimelineRow: View {
    let icon: String
    let title: String
    let subtitle: String

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            VStack(spacing: 0) {
                Image(systemName: icon)
                    .font(.subheadline.weight(.black))
                    .foregroundStyle(PulseTheme.onColor(PulseTheme.accent))
                    .frame(width: 40, height: 40)
                    .background(PulseTheme.accent)
                    .clipShape(Circle())
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(localizedKey(title))
                    .font(.headline)
                Text(localizedKey(subtitle))
                    .font(.subheadline)
                    .foregroundStyle(PulseTheme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
    }
}

private struct ContextualPaywallPreview: View {
    let source: PaywallSource
    let feature: ProductFeature?

    var body: some View {
        PulseCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: feature?.systemImage ?? "sparkles")
                        .font(.headline.weight(.bold))
                        .foregroundStyle(PulseTheme.onColor(PulseTheme.accent))
                        .frame(width: 42, height: 42)
                        .background(PulseTheme.accent)
                        .clipShape(RoundedRectangle(cornerRadius: PulseTheme.compactRadius, style: .continuous))

                    VStack(alignment: .leading, spacing: 4) {
                        Text(source.previewTitle)
                            .font(.headline)
                        if let feature {
                            Text(feature.conversionBenefit)
                                .font(.subheadline)
                                .foregroundStyle(PulseTheme.secondaryText)
                                .fixedSize(horizontal: false, vertical: true)
                        } else {
                            Text(source.subtitle)
                                .font(.subheadline)
                                .foregroundStyle(PulseTheme.secondaryText)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    Spacer()
                }

                VStack(alignment: .leading, spacing: 8) {
                    ForEach(source.previewBullets, id: \.self) { bullet in
                        Label(bullet, systemImage: "checkmark.circle.fill")
                            .font(.subheadline)
                            .foregroundStyle(PulseTheme.secondaryText)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
    }
}

private struct PlanComparisonCard: View {
    var body: some View {
        PulseCard {
            VStack(alignment: .leading, spacing: 14) {
                Text("what_stays_free_vs_pro")
                    .font(.headline)

                HStack(alignment: .top, spacing: 12) {
                    FeatureTierColumn(
                        title: "Free",
                        subtitle: localizedString("basic_habit"),
                        color: PulseTheme.ringStand,
                        features: ProductAccess.freeFeatures
                    )
                    FeatureTierColumn(
                        title: "Pro",
                        subtitle: localizedString("advanced_decisions"),
                        color: PulseTheme.accent,
                        features: ProductAccess.proFeatures
                    )
                }
            }
        }
    }
}

private struct FeatureTierColumn: View {
    let title: String
    let subtitle: String
    let color: Color
    let features: [ProductFeature]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(localizedKey(title))
                    .font(.headline)
                    .foregroundStyle(color)
                Text(localizedKey(subtitle))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(PulseTheme.secondaryText)
            }

            ForEach(features) { feature in
                HStack(alignment: .top, spacing: 7) {
                    Image(systemName: feature.systemImage)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(color)
                        .frame(width: 16)
                    Text(feature.title)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.primary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .background(PulseTheme.grouped)
        .clipShape(RoundedRectangle(cornerRadius: PulseTheme.compactRadius, style: .continuous))
    }
}

private struct PaywallPlanCard: View {
    let title: String
    let subtitle: String
    let price: String
    let priceCaption: String?
    let badge: String?
    let hasTrial: Bool
    let isFeatured: Bool
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                .font(.title3.weight(.bold))
                .foregroundStyle(isSelected ? PulseTheme.onColor(PulseTheme.accent) : PulseTheme.secondaryText)
                .frame(width: 34, height: 34)
                .background(isSelected ? PulseTheme.accent : Color.clear)
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                    .lineLimit(1)

                if let badge {
                    Text(badge)
                        .font(.caption2.weight(.bold))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .foregroundStyle(isSelected ? PulseTheme.onColor(PulseTheme.accent) : PulseTheme.accent)
                        .background(isSelected ? PulseTheme.accent : PulseTheme.accent.opacity(0.14))
                        .clipShape(Capsule())
                        .fixedSize()
                }

                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(PulseTheme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .layoutPriority(1)
            .frame(maxWidth: .infinity, alignment: .leading)

            VStack(alignment: .trailing, spacing: 4) {
                if hasTrial {
                    Text("free_week")
                        .font(.caption.weight(.black))
                        .foregroundStyle(isSelected ? PulseTheme.accent : .primary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                }
                Text(price)
                    .font(.headline.monospacedDigit())
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                if let priceCaption {
                    Text(priceCaption)
                        .font(.caption2)
                        .foregroundStyle(PulseTheme.secondaryText)
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                }
            }
            .frame(width: 118, alignment: .trailing)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(isSelected ? PulseTheme.accentMuted : PulseTheme.card)
        .clipShape(RoundedRectangle(cornerRadius: PulseTheme.cardRadius, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: PulseTheme.cardRadius, style: .continuous)
                .stroke(isSelected ? PulseTheme.accent : PulseTheme.separator, lineWidth: isSelected ? 1.5 : 1)
        }
        .shadow(color: isSelected ? PulseTheme.accent.opacity(0.22) : .clear, radius: 14, y: 4)
        .animation(.spring(response: 0.3, dampingFraction: 0.75), value: isSelected)
    }
}
