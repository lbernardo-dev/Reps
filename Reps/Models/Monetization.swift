import Foundation

enum StoreKitProductID: String, CaseIterable, Identifiable {
    case weekly = "com.romerodev.repsfitness.pro.weekly"
    case monthly = "com.romerodev.repsfitness.pro.monthly"
    case annual = "com.romerodev.repsfitness.pro.annual"
    case lifetime = "com.romerodev.repsfitness.pro.lifetime"

    var id: String { rawValue }

    static let subscriptions: [StoreKitProductID] = [.weekly, .monthly, .annual]
    static let allProductIDs = StoreKitProductID.allCases.map(\.rawValue)

    var billingCycle: SubscriptionBillingCycle {
        switch self {
        case .weekly: return .weekly
        case .monthly: return .monthly
        case .annual: return .annual
        case .lifetime: return .lifetime
        }
    }
}

enum ProductFeature: String, CaseIterable, Identifiable, Codable {
    case unlimitedLogging
    case exerciseLibrary
    case customRoutines
    case basicAnalytics
    case advancedAnalytics
    case configurableProgression
    case automaticBackups
    case shareCards
    case watchIntegration

    var id: String { rawValue }

    enum Tier: String {
        case free = "Free"
        case pro = "Pro"
    }

    var tier: Tier {
        ProductAccess.isEnabled(self) ? .free : .pro
    }

    var title: String {
        switch self {
        case .unlimitedLogging:       return localizedString("unlimited_logging_title")
        case .exerciseLibrary:        return localizedString("exercise_library_title")
        case .customRoutines:         return localizedString("custom_routines_title")
        case .basicAnalytics:         return localizedString("basic_analytics_title")
        case .advancedAnalytics:      return localizedString("advanced_analytics_title")
        case .configurableProgression: return localizedString("configurable_progression_title")
        case .automaticBackups:       return localizedString("automatic_backups_title")
        case .shareCards:             return localizedString("share_cards_title")
        case .watchIntegration:       return localizedString("watch_integration_title")
        }
    }

    var summary: String {
        switch self {
        case .unlimitedLogging:       return localizedString("unlimited_logging_summary")
        case .exerciseLibrary:        return localizedString("exercise_library_summary")
        case .customRoutines:         return localizedString("custom_routines_summary")
        case .basicAnalytics:         return localizedString("basic_analytics_summary")
        case .advancedAnalytics:      return localizedString("advanced_analytics_summary")
        case .configurableProgression: return localizedString("configurable_progression_summary")
        case .automaticBackups:       return localizedString("automatic_backups_summary")
        case .shareCards:             return localizedString("share_cards_summary")
        case .watchIntegration:       return localizedString("watch_integration_summary")
        }
    }

    var conversionBenefit: String {
        switch self {
        case .unlimitedLogging:       return localizedString("unlimited_logging_benefit")
        case .exerciseLibrary:        return localizedString("exercise_library_benefit")
        case .customRoutines:         return localizedString("custom_routines_benefit")
        case .basicAnalytics:         return localizedString("basic_analytics_benefit")
        case .advancedAnalytics:      return localizedString("advanced_analytics_benefit")
        case .configurableProgression: return localizedString("configurable_progression_benefit")
        case .automaticBackups:       return localizedString("automatic_backups_benefit")
        case .shareCards:             return localizedString("share_cards_benefit")
        case .watchIntegration:       return localizedString("watch_integration_benefit")
        }
    }

    var systemImage: String {
        switch self {
        case .unlimitedLogging:
            return "list.clipboard.fill"
        case .exerciseLibrary:
            return "books.vertical.fill"
        case .customRoutines:
            return "rectangle.stack.fill"
        case .basicAnalytics:
            return "chart.bar.fill"
        case .advancedAnalytics:
            return "chart.line.uptrend.xyaxis"
        case .configurableProgression:
            return "slider.horizontal.3"
        case .automaticBackups:
            return "externaldrive.fill"
        case .shareCards:
            return "square.and.arrow.up.fill"
        case .watchIntegration:
            return "applewatch"
        }
    }
}

enum ProductAccess {
    static let freeFeatures: [ProductFeature] = ProductFeature.allCases.filter { isEnabled($0) }
    static let proFeatures: [ProductFeature] = ProductFeature.allCases.filter { !isEnabled($0) }

    static func isEnabled(_ feature: ProductFeature, proEnabled: Bool = false) -> Bool {
        switch feature {
        case .unlimitedLogging, .exerciseLibrary, .customRoutines, .basicAnalytics:
            return true
        case .shareCards, .advancedAnalytics, .configurableProgression, .automaticBackups, .watchIntegration:
            return proEnabled
        }
    }
}

enum SubscriptionEntitlement: String, Codable {
    case free
    case pro
}

enum SubscriptionStatus: String, Codable {
    case inactive
    case trial
    case active
    case gracePeriod
    case cancelled
    case expired

    var grantsAccess: Bool {
        switch self {
        case .trial, .active, .gracePeriod:
            return true
        case .inactive, .cancelled, .expired:
            return false
        }
    }
}

enum SubscriptionBillingCycle: String, Codable, CaseIterable, Identifiable {
    case weekly
    case monthly
    case annual
    case lifetime

    var id: String { rawValue }

    var title: String {
        switch self {
        case .weekly:   return localizedString("weekly_billing_title")
        case .monthly:  return localizedString("monthly_billing_title")
        case .annual:   return localizedString("annual_billing_title")
        case .lifetime: return localizedString("Lifetime")
        }
    }

    var priceSummary: String {
        switch self {
        case .weekly:   return localizedString("weekly_price_summary")
        case .monthly:  return localizedString("monthly_price_summary")
        case .annual:   return localizedString("annual_price_summary")
        case .lifetime: return localizedString("lifetime_price_summary")
        }
    }

    var hasIntroTrial: Bool {
        self != .lifetime
    }
}

enum SubscriptionProvider: String, Codable {
    case local
    case storeKit
    case iCloudOwner
}

enum PaywallSource: String, Codable, CaseIterable, Identifiable {
    case onboarding
    case profileSubscription
    case proPreferences
    case workoutAdvancedFields
    case progressAdvancedAnalytics
    case progressLoad
    case backupCenter
    case shareCards
    case receiptGallery

    var id: String { rawValue }

    var title: String {
        switch self {
        case .onboarding:               return localizedString("paywall_unlock_pro_title")
        case .profileSubscription:      return localizedString("paywall_manage_pro_title")
        case .proPreferences:           return localizedString("paywall_activate_pro_prefs_title")
        case .workoutAdvancedFields:    return localizedString("paywall_improve_tracking_title")
        case .progressAdvancedAnalytics: return localizedString("paywall_open_advanced_analytics_title")
        case .progressLoad:             return localizedString("paywall_unlock_load_fatigue_title")
        case .backupCenter:             return localizedString("paywall_protect_data_title")
        case .shareCards:               return localizedString("paywall_share_progress_title")
        case .receiptGallery:           return localizedString("paywall_unlock_pro_gallery_title")
        }
    }

    var subtitle: String {
        switch self {
        case .onboarding:               return localizedString("paywall_onboarding_subtitle")
        case .profileSubscription:      return localizedString("paywall_manage_subtitle")
        case .proPreferences:           return localizedString("paywall_pro_prefs_subtitle")
        case .workoutAdvancedFields:    return localizedString("paywall_advanced_fields_subtitle")
        case .progressAdvancedAnalytics: return localizedString("paywall_advanced_analytics_subtitle")
        case .progressLoad:             return localizedString("paywall_load_subtitle")
        case .backupCenter:             return localizedString("paywall_backup_subtitle")
        case .shareCards:               return localizedString("paywall_share_cards_subtitle")
        case .receiptGallery:           return localizedString("paywall_receipt_gallery_subtitle")
        }
    }

    var previewTitle: String {
        switch self {
        case .onboarding:                        return localizedString("paywall_preview_start_free")
        case .profileSubscription:               return localizedString("paywall_preview_pro_center")
        case .proPreferences, .workoutAdvancedFields: return localizedString("paywall_preview_advanced_tracking")
        case .progressAdvancedAnalytics, .progressLoad: return localizedString("paywall_preview_decisions")
        case .backupCenter:                      return localizedString("paywall_preview_history_control")
        case .shareCards, .receiptGallery:       return localizedString("paywall_preview_share_progress")
        }
    }

    var previewBullets: [String] {
        switch self {
        case .onboarding:
            return [localizedString("paywall_onboarding_bullet_1"), localizedString("paywall_onboarding_bullet_2")]
        case .profileSubscription:
            return [localizedString("paywall_manage_bullet_1"), localizedString("paywall_manage_bullet_2")]
        case .proPreferences:
            return [localizedString("paywall_pro_prefs_bullet_1"), localizedString("paywall_pro_prefs_bullet_2")]
        case .workoutAdvancedFields:
            return [localizedString("paywall_advanced_fields_bullet_1"), localizedString("paywall_advanced_fields_bullet_2")]
        case .progressAdvancedAnalytics:
            return [localizedString("paywall_advanced_analytics_bullet_1"), localizedString("paywall_advanced_analytics_bullet_2")]
        case .progressLoad:
            return [localizedString("paywall_load_bullet_1"), localizedString("paywall_load_bullet_2")]
        case .backupCenter:
            return [localizedString("paywall_backup_bullet_1"), localizedString("paywall_backup_bullet_2")]
        case .shareCards:
            return [localizedString("paywall_share_cards_bullet_1"), localizedString("paywall_share_cards_bullet_2")]
        case .receiptGallery:
            return [localizedString("paywall_receipt_gallery_bullet_1"), localizedString("paywall_receipt_gallery_bullet_2")]
        }
    }
}

enum PaywallTrigger: String, Codable {
    case manual
    case featureGate
    case onboarding
}

enum PaywallDismissReason: String {
    case close
    case notNow
    case system
}

struct PaywallPresentation: Identifiable, Equatable {
    let id = UUID()
    let source: PaywallSource
    let feature: ProductFeature?
    let trigger: PaywallTrigger
}

struct MonetizationState: Codable, Equatable {
    var entitlement: SubscriptionEntitlement = .free
    var status: SubscriptionStatus = .inactive
    var billingCycle: SubscriptionBillingCycle?
    var provider: SubscriptionProvider = .local
    var trialStartDate: Date?
    var trialEndDate: Date?
    var renewsAt: Date?
    var lastPaywallPresentationDate: Date?
    var lastPaywallDismissDate: Date?
    var lastPaywallSource: PaywallSource?
    var paywallPresentationCount = 0
    var lastEntitlementSyncDate: Date?

    var hasProAccess: Bool {
        entitlement == .pro && status.grantsAccess
    }

    var statusLabel: String {
        if hasProAccess {
            switch status {
            case .trial:                        return localizedString("pro_trial_status")
            case .active:                       return localizedString("pro_active_status")
            case .gracePeriod:                  return localizedString("pro_grace_status")
            case .inactive, .cancelled, .expired: return localizedString("Reps Pro")
            }
        }

        switch status {
        case .cancelled: return localizedString("pro_cancelled_status")
        case .expired:   return localizedString("pro_expired_status")
        default:         return localizedString("Reps Free")
        }
    }
}
