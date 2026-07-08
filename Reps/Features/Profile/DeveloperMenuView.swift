#if DEBUG || targetEnvironment(simulator)
import SwiftUI

struct DeveloperMenuView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppStore.self) private var store

    @State private var showDeleteAllConfirmation = false
    @State private var showRestartOnboardingConfirmation = false
    @State private var localPaywall: PaywallPresentation?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    LabeledContent("entitlement", value: store.monetization.entitlement.rawValue)
                    LabeledContent("estado", value: store.monetization.status.rawValue)
                    if let billingCycle = store.monetization.billingCycle {
                        LabeledContent("plan", value: billingCycle.rawValue)
                    }
                } header: {
                    Text("suscripcion")
                }

                Section {
                    ForEach(SubscriptionBillingCycle.allCases) { cycle in
                        Button {
                            HapticService.selection()
                            store.unlockProForDebug(plan: cycle)
                        } label: {
                            Text(localizedFormat("dev_activate_pro_plan_format", cycle.title))
                        }
                    }

                    Button(role: .destructive) {
                        HapticService.selection()
                        store.resetProAccessForDebug()
                    } label: {
                        Text("dev_deactivate_pro")
                    }

                    Button {
                        HapticService.selection()
                        localPaywall = store.makePaywallPresentation(source: .profileSubscription, feature: nil)
                    } label: {
                        Text("dev_preview_paywall")
                    }
                } header: {
                    Text("dev_pro_access")
                }

                Section {
                    Button {
                        HapticService.selection()
                        showRestartOnboardingConfirmation = true
                    } label: {
                        Text("dev_restart_onboarding")
                    }
                } header: {
                    Text("onboarding")
                } footer: {
                    Text("dev_restart_onboarding_footer")
                }

                Section {
                    Toggle("dev_simulate_storage_error", isOn: Binding(
                        get: { store.isUsingFallbackStorage },
                        set: { store.isUsingFallbackStorage = $0 }
                    ))

                    Button(role: .destructive) {
                        HapticService.selection()
                        showDeleteAllConfirmation = true
                    } label: {
                        Text("delete_all_data")
                    }
                } header: {
                    Text("data_center")
                }

                Section {
                    LabeledContent("dev_app_version", value: appVersionText)
                    LabeledContent("dev_bundle_id", value: Bundle.main.bundleIdentifier ?? "-")
                } footer: {
                    Text("dev_menu_debug_only_footer")
                }
            }
            .navigationTitle("dev_menu_title")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("ok") { dismiss() }
                }
            }
            .confirmationDialog(
                "delete_all_data",
                isPresented: $showDeleteAllConfirmation,
                titleVisibility: .visible
            ) {
                Button("delete_all", role: .destructive) {
                    store.resetAllData()
                }
                Button("cancel", role: .cancel) {}
            } message: {
                Text("workouts_routines_metrics_photos_cards_and_local_settings_will_be_removed_export")
            }
            .confirmationDialog(
                "dev_restart_onboarding",
                isPresented: $showRestartOnboardingConfirmation,
                titleVisibility: .visible
            ) {
                Button("dev_restart_onboarding", role: .destructive) {
                    store.userProfile.onboardingCompleted = false
                }
                Button("cancel", role: .cancel) {}
            } message: {
                Text("dev_restart_onboarding_footer")
            }
            .fullScreenCover(item: $localPaywall) { presentation in
                PaywallView(presentation: presentation) { reason in
                    store.trackPaywallDismissal(presentation, reason: reason)
                    localPaywall = nil
                }
                .environment(store)
            }
        }
    }

    private var appVersionText: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "-"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "-"
        return "\(version) (\(build))"
    }
}
#endif
