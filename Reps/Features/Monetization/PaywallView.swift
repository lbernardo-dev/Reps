import StoreKit
import SwiftUI

struct PaywallView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var store: AppStore

    let presentation: PaywallPresentation
    let onDismissReason: ((PaywallDismissReason) -> Void)?

    @State private var selectedPlan: SubscriptionBillingCycle = .annual
    @State private var isPurchasing = false
    @State private var isRestoring = false
    @State private var showStoreKitInfo = false
    @State private var storeKitInfoMessage = ""

    private let includedFeatures: [ProductFeature] = [
        .configurableProgression,
        .advancedAnalytics,
        .automaticBackups,
        .shareCards
    ]

    init(presentation: PaywallPresentation, onDismissReason: ((PaywallDismissReason) -> Void)? = nil) {
        self.presentation = presentation
        self.onDismissReason = onDismissReason
    }

    var body: some View {
        NavigationStack {
            ScrollView(.vertical, showsIndicators: true) {
                VStack(alignment: .leading, spacing: 22) {
                    paywallHero

                    if let feature = presentation.feature {
                        LockedFeatureSummary(feature: feature)
                    }

                    trialTimeline

                    PulseCard {
                        VStack(alignment: .leading, spacing: 14) {
                            Text("Lo que mantiene tu progreso vivo")
                                .font(.headline)

                            VStack(spacing: 12) {
                                ForEach(includedFeatures) { feature in
                                    PaywallBenefitRow(feature: feature)
                                }
                            }
                        }
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        Text("Elige tu acceso")
                            .font(.headline)

                        ForEach(availablePlans) { cycle in
                            Button {
                                selectedPlan = cycle
                                store.trackPaywallPlanSelection(cycle, source: presentation.source)
                            } label: {
                                let product = store.storeKitProduct(for: cycle)
                                PaywallPlanCard(
                                    title: cycle.title,
                                    subtitle: planSubtitle(for: cycle, product: product),
                                    price: product?.displayPrice ?? fallbackPrice(for: cycle),
                                    badge: badge(for: cycle),
                                    isSelected: selectedPlan == cycle
                                )
                            }
                            .buttonStyle(.plain)
                        }

                        if store.isLoadingStoreKitProducts {
                            ProgressView("Cargando planes de App Store...")
                                .font(.footnote)
                                .foregroundStyle(PulseTheme.secondaryText)
                        } else if store.storeKitProducts.isEmpty {
                            Text("No se pudieron cargar los productos de App Store. Revisa conectividad, sandbox o configuración de productos.")
                                .font(.footnote)
                                .foregroundStyle(PulseTheme.secondaryText)
                        }
                    }

                    VStack(spacing: 10) {
                        Button {
                            Task { await purchaseSelectedProduct() }
                        } label: {
                            HStack(spacing: 8) {
                                if isPurchasing {
                                    ProgressView()
                                        .tint(.black)
                                }
                                Text(primaryButtonTitle)
                                    .font(.headline)
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 58)
                            .foregroundStyle(.black)
                            .background(PulseTheme.accent)
                            .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                        .disabled(isPurchasing || selectedProduct == nil)

                        Button {
                            close(reason: .notNow)
                        } label: {
                            Text("Ahora no")
                                .font(.subheadline.weight(.semibold))
                                .frame(maxWidth: .infinity)
                                .frame(height: 46)
                                .foregroundStyle(PulseTheme.secondaryText)
                                .background(PulseTheme.grouped)
                                .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)

                        Button {
                            Task { await restorePurchases() }
                        } label: {
                            Text(isRestoring ? "Restaurando..." : "Restaurar licencias")
                                .font(.footnote.weight(.semibold))
                                .frame(maxWidth: .infinity)
                                .foregroundStyle(PulseTheme.primary)
                        }
                        .buttonStyle(.plain)
                        .disabled(isRestoring)

                        Button {
                            store.presentStoreKitCodeRedemption()
                        } label: {
                            Text("Aplicar código promocional")
                                .font(.footnote.weight(.semibold))
                                .frame(maxWidth: .infinity)
                                .foregroundStyle(PulseTheme.primary)
                        }
                        .buttonStyle(.plain)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Label("7 días gratis incluidos en semanal, mensual y anual. Después se renueva desde tu cuenta de App Store.", systemImage: "checkmark.seal.fill")
                            .font(.footnote)
                            .foregroundStyle(PulseTheme.secondaryText)
                        Label("Lifetime es un pago único y no admite prueba gratis en App Store Connect.", systemImage: "infinity")
                            .font(.footnote)
                            .foregroundStyle(PulseTheme.secondaryText)
                        Text("El acceso se aplica a analítica avanzada, preferencias de progresión, backups y recibos compartibles.")
                            .font(.footnote)
                            .foregroundStyle(PulseTheme.secondaryText)
                    }

                    #if DEBUG
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Desarrollo")
                            .font(.headline)
                        Button("Resetear acceso Pro local") {
                            store.resetProAccessForDebug()
                        }
                        .buttonStyle(.bordered)
                    }
                    #endif
                }
                .padding(20)
                .padding(.bottom, 32)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .scrollBounceBehavior(.basedOnSize, axes: .vertical)
            .clipped()
            .navigationTitle("Suscripción")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        close(reason: .close)
                    } label: {
                        Image(systemName: "xmark")
                            .font(.subheadline.weight(.bold))
                    }
                }
            }
            .task {
                await store.refreshStoreKitProducts()
                if store.storeKitProduct(for: selectedPlan) == nil,
                   let firstPlan = availablePlans.first {
                    selectedPlan = firstPlan
                }
            }
            .alert("StoreKit", isPresented: $showStoreKitInfo) {
                Button("Aceptar", role: .cancel) {}
            } message: {
                Text(storeKitInfoMessage)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .screenBackground()
    }

    private var paywallHero: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Reps Pro")
                    .font(.system(size: 46, weight: .black, design: .rounded))
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)

                Spacer(minLength: 12)

                Image(systemName: "bolt.heart.fill")
                    .font(.title2.weight(.black))
                    .foregroundStyle(.black)
                    .frame(width: 46, height: 46)
                    .background(PulseTheme.accent)
                    .clipShape(Circle())
            }

            Text("Entrena una semana completa gratis.")
                .font(.title2.weight(.black))

            Text("Tu plan, analítica avanzada y progresión automática se desbloquean hoy. Cancela desde App Store cuando quieras.")
                .font(.body.weight(.semibold))
                .foregroundStyle(PulseTheme.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.top, 8)
    }

    private var trialTimeline: some View {
        PulseCard(contentPadding: 18) {
            VStack(alignment: .leading, spacing: 18) {
                TrialTimelineRow(icon: "checkmark", title: "Acceso gratis", subtitle: "Desbloquea Reps Pro durante 7 días.")
                TrialTimelineRow(icon: "bell.fill", title: "Día 5", subtitle: "Recibirás un recordatorio antes de que termine la prueba.")
                TrialTimelineRow(icon: "chart.line.uptrend.xyaxis", title: "Progreso", subtitle: "Entrena, registra y deja que Reps ajuste tus métricas.")
            }
        }
    }

    private var availablePlans: [SubscriptionBillingCycle] {
        let loadedPlans = store.storeKitProducts.compactMap { product in
            StoreKitProductID(rawValue: product.id)?.billingCycle
        }

        if loadedPlans.isEmpty {
            return SubscriptionBillingCycle.allCases
        }

        return SubscriptionBillingCycle.allCases.filter { loadedPlans.contains($0) }
    }

    private var selectedProduct: Product? {
        store.storeKitProduct(for: selectedPlan)
    }

    private var primaryButtonTitle: String {
        guard selectedProduct != nil else {
            return "Cargando App Store"
        }

        if selectedPlan.hasIntroTrial {
            return "Canjear mi semana gratis"
        }

        return "Comprar Lifetime"
    }

    private func planSubtitle(for cycle: SubscriptionBillingCycle, product: Product?) -> String {
        if cycle.hasIntroTrial {
            let price = product?.displayPrice ?? fallbackPrice(for: cycle)
            return "Primera semana gratis, luego \(price) \(renewalText(for: cycle))"
        }

        return "Pago único. Acceso Pro permanente."
    }

    private func renewalText(for cycle: SubscriptionBillingCycle) -> String {
        switch cycle {
        case .weekly: return "por semana"
        case .monthly: return "al mes"
        case .annual: return "al año"
        case .lifetime: return ""
        }
    }

    private func fallbackPrice(for cycle: SubscriptionBillingCycle) -> String {
        switch cycle {
        case .weekly: return "0,99 €"
        case .monthly: return "1,99 €"
        case .annual: return "9,99 €"
        case .lifetime: return "19,99 €"
        }
    }

    private func badge(for cycle: SubscriptionBillingCycle) -> String? {
        switch cycle {
        case .annual: return "Mejor valor"
        case .monthly: return "Flexible"
        case .lifetime: return "Pago único"
        case .weekly: return "Prueba rápida"
        }
    }

    private func purchaseSelectedProduct() async {
        guard let selectedProduct else {
            storeKitInfoMessage = store.storeKitErrorMessage ?? "Los productos de StoreKit aún no están disponibles."
            showStoreKitInfo = true
            return
        }

        isPurchasing = true
        defer { isPurchasing = false }

        store.trackPaywallCTA(selectedPlan, source: presentation.source)
        let didPurchase = await store.purchaseStoreKitProduct(selectedProduct)
        if didPurchase {
            close(reason: .notNow)
        } else if let message = store.storeKitErrorMessage {
            storeKitInfoMessage = message
            showStoreKitInfo = true
        }
    }

    private func restorePurchases() async {
        isRestoring = true
        defer { isRestoring = false }

        let restored = await store.restoreStoreKitPurchases()
        storeKitInfoMessage = restored ? "Licencias restauradas correctamente." : "No se encontró ninguna licencia activa para restaurar."
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
    @EnvironmentObject private var store: AppStore

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    PulseCard {
                        VStack(alignment: .leading, spacing: 12) {
                            Text(store.monetization.statusLabel)
                                .font(.title3.bold())
                            Text(store.monetization.hasProAccess ? "Tu acceso Pro está activo en esta instalación." : "Actualmente estás en Reps Free.")
                                .foregroundStyle(PulseTheme.secondaryText)

                            if let cycle = store.monetization.billingCycle, store.monetization.hasProAccess {
                                Label("Plan \(cycle.title.lowercased())", systemImage: "checkmark.seal.fill")
                                    .foregroundStyle(PulseTheme.primary)
                            }
                        }
                    }

                    PulseCard {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Incluye Reps Pro")
                                .font(.headline)
                            ForEach([
                                ProductFeature.configurableProgression,
                                .advancedAnalytics,
                                .automaticBackups,
                                .shareCards
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
                        Text(store.monetization.hasProAccess ? "Ver estado Pro" : "Desbloquear Reps Pro")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .frame(height: 52)
                            .foregroundStyle(.black)
                            .background(PulseTheme.accent)
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
                .padding(20)
                .padding(.bottom, 24)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .navigationTitle("Suscripción")
            .navigationBarTitleDisplayMode(.inline)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .screenBackground()
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
                        .foregroundStyle(.black)
                        .frame(width: 34, height: 34)
                        .background(PulseTheme.accent)
                        .clipShape(Circle())
                    Text(title)
                        .font(.headline)
                }

                Text(message)
                    .font(.subheadline)
                    .foregroundStyle(PulseTheme.secondaryText)

                Button(action: action) {
                    Text(buttonTitle)
                        .font(.subheadline.weight(.bold))
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                        .foregroundStyle(.black)
                        .background(PulseTheme.accent)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
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
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
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
                    .foregroundStyle(.black)
                    .frame(width: 40, height: 40)
                    .background(PulseTheme.accent)
                    .clipShape(Circle())
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(PulseTheme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
    }
}

private struct LockedFeatureSummary: View {
    let feature: ProductFeature

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "sparkles.rectangle.stack.fill")
                .foregroundStyle(PulseTheme.primary)
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
        .background(PulseTheme.grouped)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

private struct PaywallPlanCard: View {
    let title: String
    let subtitle: String
    let price: String
    let badge: String?
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                .font(.title3.weight(.bold))
                .foregroundStyle(isSelected ? .black : PulseTheme.secondaryText)
                .frame(width: 34, height: 34)
                .background(isSelected ? PulseTheme.accent : Color.clear)
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(title)
                        .font(.headline)
                        .lineLimit(1)
                    if let badge {
                        Text(badge)
                            .font(.caption2.weight(.bold))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .foregroundStyle(isSelected ? .black : PulseTheme.accent)
                            .background(isSelected ? PulseTheme.accent : PulseTheme.accent.opacity(0.14))
                            .clipShape(Capsule())
                            .lineLimit(1)
                            .minimumScaleFactor(0.85)
                    }
                }

                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(PulseTheme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .layoutPriority(1)
            .frame(maxWidth: .infinity, alignment: .leading)

            VStack(alignment: .trailing, spacing: 6) {
                if title != "Lifetime" {
                    Text("semana gratis")
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
            }
            .frame(width: 112, alignment: .trailing)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(isSelected ? PulseTheme.accentMuted : PulseTheme.card)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(isSelected ? PulseTheme.accent : PulseTheme.separator, lineWidth: isSelected ? 1.5 : 1)
        }
    }
}
