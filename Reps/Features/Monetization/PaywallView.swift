import SwiftUI

struct PaywallView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var store: AppStore

    let presentation: PaywallPresentation

    @State private var selectedPlan: SubscriptionBillingCycle = .annual
    @State private var showCheckoutInfo = false

    private let includedFeatures: [ProductFeature] = [
        .configurableProgression,
        .advancedAnalytics,
        .automaticBackups,
        .shareCards
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack(spacing: 10) {
                            Image(systemName: "crown.fill")
                                .font(.title2.weight(.bold))
                                .foregroundStyle(.black)
                                .frame(width: 42, height: 42)
                                .background(PulseTheme.accent)
                                .clipShape(Circle())

                            VStack(alignment: .leading, spacing: 2) {
                                Text("Reps Pro")
                                    .font(.system(size: 28, weight: .bold, design: .rounded))
                                Text(presentation.source.title)
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(PulseTheme.secondaryText)
                            }
                        }

                        Text(presentation.source.subtitle)
                            .font(.subheadline)
                            .foregroundStyle(PulseTheme.secondaryText)

                        if let feature = presentation.feature {
                            LockedFeatureSummary(feature: feature)
                        }
                    }

                    VStack(spacing: 12) {
                        ForEach(includedFeatures) { feature in
                            PaywallBenefitRow(feature: feature)
                        }
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        Text("Elige plan")
                            .font(.headline)

                        ForEach(SubscriptionBillingCycle.allCases) { cycle in
                            Button {
                                selectedPlan = cycle
                                store.trackPaywallPlanSelection(cycle, source: presentation.source)
                            } label: {
                                PaywallPlanCard(
                                    title: cycle.title,
                                    subtitle: cycle.priceSummary,
                                    badge: cycle == .annual ? "Recomendado" : nil,
                                    isSelected: selectedPlan == cycle
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    VStack(spacing: 10) {
                        Button {
                            store.trackPaywallCTA(selectedPlan, source: presentation.source)
                            showCheckoutInfo = true
                        } label: {
                            Text("Continuar con \(selectedPlan.title)")
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                                .frame(height: 52)
                                .foregroundStyle(.black)
                                .background(PulseTheme.accent)
                                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        }
                        .buttonStyle(.plain)

                        Button {
                            store.dismissPaywall(reason: .notNow)
                            dismiss()
                        } label: {
                            Text("Ahora no")
                                .font(.subheadline.weight(.semibold))
                                .frame(maxWidth: .infinity)
                                .frame(height: 46)
                                .foregroundStyle(PulseTheme.secondaryText)
                                .background(PulseTheme.grouped)
                                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        }
                        .buttonStyle(.plain)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Estado")
                            .font(.headline)
                        Text(store.monetization.revenueCatConfigured ? "La compra se resolverá con tu capa de suscripción configurada." : "La UI, reglas de acceso y puntos de entrada ya están listos. Falta conectar la compra real.")
                            .font(.footnote)
                            .foregroundStyle(PulseTheme.secondaryText)
                    }

                    #if DEBUG
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Desarrollo")
                            .font(.headline)
                        HStack(spacing: 10) {
                            Button("Activar Pro local") {
                                store.unlockProForDebug(plan: selectedPlan)
                                dismiss()
                            }
                            .buttonStyle(.borderedProminent)

                            Button("Resetear acceso") {
                                store.resetProAccessForDebug()
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                    #endif
                }
                .padding(20)
                .padding(.bottom, 32)
            }
            .screenBackground()
            .navigationTitle("Suscripción")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        store.dismissPaywall(reason: .close)
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.subheadline.weight(.bold))
                    }
                }
            }
            .alert("Compra no conectada todavía", isPresented: $showCheckoutInfo) {
                Button("Aceptar", role: .cancel) {}
            } message: {
                Text("El siguiente paso es conectar RevenueCat sobre esta capa ya preparada.")
            }
        }
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
            .screenBackground()
            .navigationTitle("Suscripción")
            .navigationBarTitleDisplayMode(.inline)
        }
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
                .foregroundStyle(PulseTheme.primary)
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
    let badge: String?
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(title)
                        .font(.headline)
                    if let badge {
                        Text(badge)
                            .font(.caption2.weight(.bold))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .foregroundStyle(.black)
                            .background(PulseTheme.accent)
                            .clipShape(Capsule())
                    }
                }

                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(PulseTheme.secondaryText)
            }

            Spacer()

            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                .font(.title3)
                .foregroundStyle(isSelected ? PulseTheme.primary : PulseTheme.secondaryText)
        }
        .padding(16)
        .background(isSelected ? PulseTheme.elevated : PulseTheme.card)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(isSelected ? PulseTheme.primary : PulseTheme.separator, lineWidth: 1)
        }
    }
}
