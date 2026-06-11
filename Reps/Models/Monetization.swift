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
        case .unlimitedLogging:
            return "Registro ilimitado"
        case .exerciseLibrary:
            return "Biblioteca de ejercicios"
        case .customRoutines:
            return "Rutinas personalizadas"
        case .basicAnalytics:
            return "Analítica base"
        case .advancedAnalytics:
            return "Analítica avanzada"
        case .configurableProgression:
            return "Progresión avanzada"
        case .automaticBackups:
            return "Backups completos"
        case .shareCards:
            return "Tarjetas y recibos"
        }
    }

    var summary: String {
        switch self {
        case .unlimitedLogging:
            return "Guarda todas tus sesiones sin límites."
        case .exerciseLibrary:
            return "Explora y reutiliza tu biblioteca completa."
        case .customRoutines:
            return "Construye y adapta rutinas a tu equipo."
        case .basicAnalytics:
            return "Consulta progreso, rachas y métricas base."
        case .advancedAnalytics:
            return "Desbloquea historial, carga, récords y análisis detallados."
        case .configurableProgression:
            return "Activa RPE, RIR, tempo, tipo de serie y auto-progresión."
        case .automaticBackups:
            return "Exporta e importa copias completas en JSON."
        case .shareCards:
            return "Comparte recibos, tarjetas y resúmenes visuales."
        }
    }

    var conversionBenefit: String {
        switch self {
        case .unlimitedLogging:
            return "Construye el hábito base: registrar entrenos sin fricción."
        case .exerciseLibrary:
            return "Encuentra ejercicios para casa o gimnasio desde el día uno."
        case .customRoutines:
            return "Crea rutinas reales antes de decidir si necesitas automatización."
        case .basicAnalytics:
            return "Mide constancia, volumen y progreso básico gratis."
        case .advancedAnalytics:
            return "Convierte tus datos en decisiones: objetivo vs real, fatiga, estancamientos y próximas acciones."
        case .configurableProgression:
            return "Registra RPE/RIR, tempo y tipos de serie para ajustar cargas con más precisión."
        case .automaticBackups:
            return "Protege tu historial completo y muévelo entre instalaciones."
        case .shareCards:
            return "Convierte entrenos y récords en recibos visuales listos para compartir."
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
        case .advancedAnalytics, .configurableProgression, .automaticBackups, .shareCards:
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
        case .weekly:
            return "Semanal"
        case .monthly:
            return "Mensual"
        case .annual:
            return "Anual"
        case .lifetime:
            return "Lifetime"
        }
    }

    var priceSummary: String {
        switch self {
        case .weekly:
            return "Prueba Pro sin compromiso"
        case .monthly:
            return "Flexibilidad mensual"
        case .annual:
            return "Mejor valor para entrenar todo el año"
        case .lifetime:
            return "Pago único para desbloquear Pro para siempre"
        }
    }

    var hasIntroTrial: Bool {
        self != .lifetime
    }
}

enum SubscriptionProvider: String, Codable {
    case local
    case revenueCat
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
        case .onboarding:
            return "Desbloquea Reps Pro"
        case .profileSubscription:
            return "Gestiona Reps Pro"
        case .proPreferences:
            return "Activa preferencias Pro"
        case .workoutAdvancedFields:
            return "Mejora tu registro"
        case .progressAdvancedAnalytics:
            return "Abre analítica avanzada"
        case .progressLoad:
            return "Desbloquea carga y fatiga"
        case .backupCenter:
            return "Protege tus datos"
        case .shareCards:
            return "Comparte tu progreso"
        case .receiptGallery:
            return "Desbloquea la galería Pro"
        }
    }

    var subtitle: String {
        switch self {
        case .onboarding:
            return "Accede a los extras de progresión, analítica y compartición desde el primer día."
        case .profileSubscription:
            return "Consulta tu estado, ventajas incluidas y opciones de acceso Pro."
        case .proPreferences:
            return "RPE, RIR, tempo, tipo de serie y auto-progresión viven dentro de Pro."
        case .workoutAdvancedFields:
            return "Registra tus series con más contexto y aplica progresión automática."
        case .progressAdvancedAnalytics:
            return "Accede al historial detallado, récords y desglose profundo de ejercicios."
        case .progressLoad:
            return "Visualiza carga aguda, fatiga y cardio avanzado para decidir mejor."
        case .backupCenter:
            return "Exporta e importa backups completos para proteger tu historial."
        case .shareCards:
            return "Convierte tus entrenos y récords en tarjetas listas para compartir."
        case .receiptGallery:
            return "Guarda y revisa tus recibos visuales cuando quieras."
        }
    }

    var previewTitle: String {
        switch self {
        case .onboarding:
            return "Empieza gratis, escala con Pro"
        case .profileSubscription:
            return "Tu centro de acceso Pro"
        case .proPreferences, .workoutAdvancedFields:
            return "Registro avanzado en contexto"
        case .progressAdvancedAnalytics, .progressLoad:
            return "Decisiones de entrenamiento, no solo gráficas"
        case .backupCenter:
            return "Tu historial bajo control"
        case .shareCards, .receiptGallery:
            return "Progreso listo para compartir"
        }
    }

    var previewBullets: [String] {
        switch self {
        case .onboarding:
            return [
                "Free mantiene entrenos, rutinas y analítica base.",
                "Pro añade progresión automática, carga/fatiga y backups."
            ]
        case .profileSubscription:
            return [
                "Revisa estado, plan y ventajas incluidas.",
                "Desbloquea todo Pro desde una sola pantalla."
            ]
        case .proPreferences:
            return [
                "Activa RPE, RIR, tempo y tipo de serie.",
                "Ajusta incrementos y auto-progresión según tu historial."
            ]
        case .workoutAdvancedFields:
            return [
                "Registra más contexto sin salir del entreno activo.",
                "Mejora la calidad de las recomendaciones futuras."
            ]
        case .progressAdvancedAnalytics:
            return [
                "Detecta estancamientos por ejercicio.",
                "Compara tendencia, 1RM estimado y volumen efectivo."
            ]
        case .progressLoad:
            return [
                "Mide carga aguda, fatiga e intensidad.",
                "Decide cuándo apretar, descargar o recuperar."
            ]
        case .backupCenter:
            return [
                "Exporta/importa backups completos.",
                "Protege sesiones, planes, fotos y métricas."
            ]
        case .shareCards:
            return [
                "Genera tarjetas visuales de entrenos y récords.",
                "Comparte progreso sin capturas manuales."
            ]
        case .receiptGallery:
            return [
                "Guarda recibos visuales en tu galería.",
                "Reutiliza tus mejores resúmenes cuando quieras."
            ]
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
    var revenueCatConfigured = false

    var hasProAccess: Bool {
        entitlement == .pro && status.grantsAccess
    }

    var statusLabel: String {
        if hasProAccess {
            switch status {
            case .trial:
                return "Prueba Pro"
            case .active:
                return "Pro activa"
            case .gracePeriod:
                return "Pro en gracia"
            case .inactive, .cancelled, .expired:
                return "Reps Pro"
            }
        }

        switch status {
        case .cancelled:
            return "Pro cancelada"
        case .expired:
            return "Pro expirada"
        default:
            return "Reps Free"
        }
    }
}
