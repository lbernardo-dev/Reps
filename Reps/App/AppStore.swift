import ActivityKit
import CoreLocation
import Foundation
import HealthKit
import Observation
import StoreKit
import UIKit
import UserNotifications
import WatchConnectivity

@Observable
@MainActor
final class AppStore {
    struct NotificationDestination: Equatable {
        let tab: AppTab
        let focusDate: Date?
        let scheduledWorkoutID: UUID?
    }

    var userProfile = UserProfile() {
        didSet {
            RepsLocalization.use(userProfile.preferredLanguage)
            if oldValue.remindersEnabled != userProfile.remindersEnabled {
                reconcileNotificationStateIfNeeded()
            }
            save(scope: .profile)
        }
    }
    var monetization = MonetizationState() { didSet { save(scope: .monetization) } }
    private(set) var storeKitProducts: [Product] = []
    private(set) var isLoadingStoreKitProducts = false
    private(set) var storeKitErrorMessage: String?
    private(set) var iCloudProRecordHash: String?
    private(set) var iCloudProEntitlementMessage: String?
    var activePlan = WorkoutPlan.empty { didSet { save(scope: .plans) } }
    var plans: [WorkoutPlan] = [] { didSet { save(scope: .plans) } }
    var workoutTemplates: [WorkoutDay] = SeedData.workoutTemplates { didSet { save(scope: .workoutTemplates) } }
    var exercises: [Exercise] = SeedData.exercises { didSet { save(scope: .exerciseLibrary) } }
    var scheduledWorkouts: [ScheduledWorkout] = [] {
        didSet {
            reconcileNotificationStateIfNeeded()
            save(scope: .scheduledWorkouts)
        }
    }
    var workoutSessions: [WorkoutSession] = [] { didSet { save(scope: .workoutSessions) } }
    var cardioLogs: [CardioLog] = [] { didSet { save(scope: .cardioLogs) } }
    var bodyMetrics: [BodyMetric] = [] { didSet { save(scope: .bodyMetrics) } }
    var progressPhotos: [ProgressPhoto] = [] { didSet { save(scope: .progressPhotos) } }
    var gymPasses: [GymPass] = [] { didSet { save(scope: .gymPasses) } }
    var gymVisits: [GymVisit] = [] { didSet { save(scope: .gymVisits) } }
    var goals: [Goal] = [] { didSet { save(scope: .goals) } }
    var health = HealthSyncState() { didSet { save(scope: .health) } }
    var isSyncingExerciseLibrary = false
    var exerciseLibrarySyncMessage: String?
    var savedShareCards: [SavedShareCard] = [] { didSet { save(scope: .savedShareCards) } }
    var finishedSessionForSummary: WorkoutSession? = nil
    var activeWorkoutStatus: ActiveWorkoutStatus? {
        didSet {
            let shouldReloadWidgets = shouldReloadWidgetTimelines(from: oldValue, to: activeWorkoutStatus)
            save(reloadWidgetTimelines: shouldReloadWidgets, scope: .profile)
            let snapshot = sharedWorkoutSnapshot()
            SharedWorkoutStore.save(snapshot, reloadTimelines: shouldReloadWidgets)
            WatchSyncService.shared.publish(snapshot: snapshot)
            RepsWorkoutLiveActivityController.shared.sync(snapshot)
            guard !isRestoring else { return }
            nativeWorkoutSessionService?.reconcile(
                status: activeWorkoutStatus,
                workout: activeWorkout,
                preferCompanionWorkout: WatchSyncService.shared.canStartCompanionWorkout
            )
        }
    }
    var activeWorkout: WorkoutDay? { didSet { save(scope: .profile) } }
    var activeWorkoutDrafts: [ExerciseSessionDraft] = [] { didSet { save(scope: .profile) } }
    var isUsingFallbackStorage = false
    var notificationDestination: NotificationDestination?
    var calendarFocusedDate: Date?
    var activePaywall: PaywallPresentation? {
        didSet {
            if activePaywall == nil, let previous = oldValue {
                monetization.lastPaywallDismissDate = .now
                TelemetryService.shared.log(.paywallDismissed, parameters: [
                    "source": previous.source.rawValue,
                    "feature": previous.feature?.rawValue,
                    "reason": pendingPaywallDismissReason?.rawValue ?? PaywallDismissReason.system.rawValue
                ])
                pendingPaywallDismissReason = nil
            }
        }
    }

    @ObservationIgnored private let persistence: SwiftDataPersistence
    @ObservationIgnored private let iCloudProEntitlementService: ICloudProEntitlementService
    @ObservationIgnored private let shareImageRenderer: (WorkoutSession?) -> UIImage
    @ObservationIgnored private let healthKitService = HealthKitService()
    @ObservationIgnored private var nativeWorkoutSessionService: NativeWorkoutSessionService?
    @ObservationIgnored private var isRestoring = false
    @ObservationIgnored private var hasAttemptedExerciseLibrarySync = false
    @ObservationIgnored private var saveTask: Task<Void, Never>?
    @ObservationIgnored private var pendingSaveScopes: Set<PersistenceScope> = []
    @ObservationIgnored private var pendingWidgetTimelineReload = false
    @ObservationIgnored private var pendingPaywallDismissReason: PaywallDismissReason?
    @ObservationIgnored private var transactionUpdatesTask: Task<Void, Never>?
    @ObservationIgnored private var isAutomaticHealthSyncInProgress = false
    @ObservationIgnored private var lastAutomaticHealthRefreshDate: Date?
    // Written once during init (MainActor) and read in deinit for cleanup.
    @ObservationIgnored nonisolated(unsafe) private var liveActivityCommandObserver: NSObjectProtocol?

    init(
        persistence: SwiftDataPersistence = SwiftDataPersistence(),
        iCloudProEntitlementService: ICloudProEntitlementService = .shared,
        shareImageRenderer: ((WorkoutSession?) -> UIImage)? = nil,
        startsBackgroundServices: Bool = true
    ) {
        self.persistence = persistence
        self.iCloudProEntitlementService = iCloudProEntitlementService
        self.shareImageRenderer = shareImageRenderer ?? { session in
            if let session {
                return WorkoutShareImageRenderer.render(session: session)
            }
            return WorkoutShareImageRenderer.render(title: "Reps Workout", duration: 0, volume: 0, sets: 0)
        }
        self.isUsingFallbackStorage = persistence.didFallbackToInMemory
        WatchSyncService.shared.configure(
            commandHandler: { [weak self] command in
                self?.handleWatchCommand(command)
            },
            routeMetricsHandler: { [weak self] metrics in
                self?.handleWatchRouteMetrics(metrics)
            },
            routeSummaryHandler: { [weak self] summary in
                self?.importWatchRouteWorkout(summary)
            },
            logSetHandler: { [weak self] logSet in
                self?.handleWatchLogSet(logSet)
            },
            strengthSummaryHandler: { [weak self] summary in
                self?.importWatchStrengthWorkout(summary)
            },
            intervalSummaryHandler: { [weak self] summary in
                self?.importWatchIntervalWorkout(summary)
            }
        )
        let nativeWorkoutSessionService = NativeWorkoutSessionService()
        nativeWorkoutSessionService.configure(
            metricsHandler: { [weak self] metrics in
                self?.handleNativeWorkoutMetrics(metrics)
            },
            mirroredStartHandler: { [weak self] payload in
                self?.handleMirroredNativeWorkoutStart(payload)
            },
            endedHandler: { [weak self] in
                self?.handleNativeWorkoutEnded()
            }
        )
        self.nativeWorkoutSessionService = nativeWorkoutSessionService
        if let snapshot = persistence.loadSnapshot() ?? Self.loadLegacySnapshot() {
            restore(snapshot)
        } else {
            restore(.empty)
            persistence.save(currentSnapshot)
            SharedWorkoutStore.save(sharedWorkoutSnapshot())
        }
        RepsLocalization.use(userProfile.preferredLanguage)

        let shouldStartBackgroundServices = startsBackgroundServices && !Self.isRunningUnitTests
        if shouldStartBackgroundServices {
            Task {
                await refreshStoreKitProducts()
                await refreshStoreKitEntitlements()
                await refreshICloudProEntitlement()
                await syncOpenExerciseLibraryIfNeeded()
            }

            transactionUpdatesTask = Task { [weak self] in
                await self?.listenForStoreKitTransactions()
            }

            startHealthKitWorkoutObserverIfAuthorized()
            nativeWorkoutSessionService.startMirroringListener()
            refreshHealthKitDataIfNeeded(reason: "launch")

            liveActivityCommandObserver = NotificationCenter.default.addObserver(
                forName: LiveActivityCommandBridge.notificationName,
                object: nil,
                queue: .main
            ) { [weak self] notification in
                guard let command = LiveActivityCommandBridge.command(from: notification) else { return }
                Task { @MainActor in
                    self?.handleWatchCommand(command)
                }
            }
        }
    }

    deinit {
        transactionUpdatesTask?.cancel()
        if let liveActivityCommandObserver {
            NotificationCenter.default.removeObserver(liveActivityCommandObserver)
        }
    }

    /// Immediately writes the latest computed snapshot to shared UserDefaults
    /// so that all widgets reflect current app state. Call this on foreground / launch.
    func syncWidgets() {
        let snapshot = sharedWorkoutSnapshot()
        SharedWorkoutStore.save(snapshot, forceReload: true)
        WatchSyncService.shared.publish(snapshot: snapshot)
    }

    func refreshNotificationSchedule() {
        reconcileNotificationStateIfNeeded()
    }

    func handleNotificationTarget(_ target: NotificationService.NotificationTarget) {
        switch target.kind {
        case .workoutReminder, .missedWorkoutCheck:
            let focusDate = target.scheduledDate ?? .now
            calendarFocusedDate = focusDate
            notificationDestination = NotificationDestination(
                tab: .calendar,
                focusDate: focusDate,
                scheduledWorkoutID: target.scheduledWorkoutID
            )
        case .dailySummary, .batteryRecoverySuggestion, .retentionNudge:
            notificationDestination = NotificationDestination(
                tab: .today,
                focusDate: nil,
                scheduledWorkoutID: nil
            )
        }
    }

    func consumeNotificationDestination() {
        notificationDestination = nil
    }

    var todaysWorkout: WorkoutDay {
        let calendar = Calendar.current
        if let scheduled = scheduledWorkouts.first(where: { calendar.isDateInToday($0.date) }) {
            return scheduled.workoutDay
        }
        if !activePlan.days.isEmpty {
            let count = activePlan.days.count
            let index = ((activePlan.activeDayIndex % count) + count) % count
            return activePlan.days[index]
        }
        return .freeWorkout
    }

    var streakDays: Int {
        let calendar = Calendar.current
        let workoutDays = Set(workoutSessions.map { calendar.startOfDay(for: $0.date) })
        var date = calendar.startOfDay(for: .now)
        
        if !workoutDays.contains(date) {
            let yesterday = calendar.date(byAdding: .day, value: -1, to: date) ?? date
            if workoutDays.contains(yesterday) {
                date = yesterday
            } else {
                return 0
            }
        }
        
        var streak = 0
        var checkDate = date
        while workoutDays.contains(checkDate) {
            streak += 1
            guard let prev = calendar.date(byAdding: .day, value: -1, to: checkDate) else { break }
            checkDate = prev
        }
        return streak
    }

    var weeklyCompletion: Double {
        let calendar = Calendar.current
        let weekStart = calendar.dateInterval(of: .weekOfYear, for: .now)?.start ?? .now.addingTimeInterval(-604_800)
        let completedThisWeek = workoutSessions.filter { $0.date >= weekStart }.count
        return FitnessMetrics.weeklyCompletion(completedWorkouts: completedThisWeek, plannedWorkouts: activePlan.daysPerWeek)
    }

    var currentWeight: Double {
        bodyMetrics.sorted { $0.date < $1.date }.last?.weightKg ?? 0
    }

    var currentHeight: Double {
        bodyMetrics.sorted { $0.date < $1.date }.last?.heightCm ?? 0
    }

    var hasBodyMetrics: Bool {
        bodyMetrics.contains { $0.weightKg > 0 || $0.heightCm > 0 }
    }

    var displayedWeight: (value: Double, unit: String) {
        switch userProfile.units {
        case .metric:
            (currentWeight, "kg")
        case .imperial:
            (UnitConverter.pounds(fromKilograms: currentWeight), "lb")
        }
    }

    var displayedHeight: (value: Double, unit: String) {
        switch userProfile.units {
        case .metric:
            (currentHeight, "cm")
        case .imperial:
            (UnitConverter.inches(fromCentimeters: currentHeight), "in")
        }
    }

    var bodyMassIndex: Double {
        guard currentWeight > 0, currentHeight > 0 else {
            return 0
        }
        return currentWeight / pow(max(currentHeight, 1) / 100, 2)
    }

    var basalMetabolicRate: Double {
        guard currentWeight > 0, currentHeight > 0 else {
            return 0
        }
        let age = userProfile.dateOfBirth.map { Calendar.current.dateComponents([.year], from: $0, to: .now).year ?? 30 } ?? 30
        let sexAdjustment = userProfile.sex == .female ? -161.0 : 5.0
        return 10 * currentWeight + 6.25 * currentHeight - 5 * Double(age) + sexAdjustment
    }

    var maintenanceCalories: Double {
        basalMetabolicRate * 1.45
    }

    var deficitCalories: Double {
        maintenanceCalories - 400
    }

    var recompositionCalories: Double {
        maintenanceCalories - 150
    }

    var leanBulkCalories: Double {
        maintenanceCalories + 250
    }

    var totalVolumeKg: Double {
        FitnessMetrics.totalVolumeKg(for: workoutSessions)
    }

    var bestEstimatedOneRepMaxKg: Double {
        FitnessMetrics.bestEstimatedOneRepMaxKg(for: workoutSessions) ?? 0
    }

    var todayHealthMetric: DailyHealthMetric? {
        let calendar = Calendar.current
        return health.latestDailyMetrics.last { calendar.isDateInToday($0.date) }
    }

    var dailySummary: String {
        let completedToday = workoutSessions.filter { Calendar.current.isDateInToday($0.date) }
        let workoutText = completedToday.isEmpty ? "Sin entreno registrado hoy" : "\(completedToday.count) entreno registrado"
        let healthText = todayHealthMetric.map { "\(Int($0.steps)) pasos, \(Int($0.activeEnergyKcal)) kcal activas" } ?? "Métricas de Salud sin sincronizar"
        return "\(workoutText). \(healthText)."
    }

    var trainingBattery: FitnessMetrics.TrainingBatteryStatus {
        FitnessMetrics.trainingBatteryStatus(
            sessions: workoutSessions,
            scheduledWorkouts: scheduledWorkouts,
            activePlan: activePlan,
            bodyMetrics: bodyMetrics,
            health: health
        )
    }

    func projectedBattery(after workout: WorkoutDay) -> Int {
        FitnessMetrics.projectedBatteryLevel(after: workout, from: trainingBattery.level)
    }

    var hasProAccess: Bool {
        monetization.hasProAccess
    }

    func hasFeatureAccess(_ feature: ProductFeature) -> Bool {
        ProductAccess.isEnabled(feature, proEnabled: hasProAccess)
    }

    @discardableResult
    func requireFeature(_ feature: ProductFeature, source: PaywallSource, trigger: PaywallTrigger = .featureGate) -> Bool {
        let enabled = hasFeatureAccess(feature)
        guard !enabled else {
            return true
        }

        TelemetryService.shared.log(.paywallFeatureGateHit, parameters: [
            "feature": feature.rawValue,
            "source": source.rawValue
        ])
        presentPaywall(source: source, feature: feature, trigger: trigger)
        return false
    }

    func presentPaywall(source: PaywallSource, feature: ProductFeature?, trigger: PaywallTrigger = .manual) {
        activePaywall = makePaywallPresentation(source: source, feature: feature, trigger: trigger)
    }

    func makePaywallPresentation(source: PaywallSource, feature: ProductFeature?, trigger: PaywallTrigger = .manual) -> PaywallPresentation {
        monetization.lastPaywallPresentationDate = .now
        monetization.lastPaywallSource = source
        monetization.paywallPresentationCount += 1
        let presentation = PaywallPresentation(source: source, feature: feature, trigger: trigger)
        TelemetryService.shared.log(.paywallPresented, parameters: [
            "source": presentation.source.rawValue,
            "feature": presentation.feature?.rawValue,
            "trigger": presentation.trigger.rawValue
        ])
        return presentation
    }

    func dismissPaywall(reason: PaywallDismissReason) {
        pendingPaywallDismissReason = reason
        activePaywall = nil
    }

    func trackPaywallDismissal(_ presentation: PaywallPresentation, reason: PaywallDismissReason) {
        monetization.lastPaywallDismissDate = .now
        TelemetryService.shared.log(.paywallDismissed, parameters: [
            "source": presentation.source.rawValue,
            "feature": presentation.feature?.rawValue,
            "reason": reason.rawValue
        ])
    }

    func trackPaywallPlanSelection(_ plan: SubscriptionBillingCycle, source: PaywallSource) {
        TelemetryService.shared.log(.paywallPlanSelected, parameters: [
            "plan": plan.rawValue,
            "source": source.rawValue
        ])
    }

    func trackPaywallCTA(_ plan: SubscriptionBillingCycle, source: PaywallSource) {
        TelemetryService.shared.log(.paywallCTASelected, parameters: [
            "plan": plan.rawValue,
            "source": source.rawValue
        ])
    }

    func refreshStoreKitProducts() async {
        guard !isLoadingStoreKitProducts else {
            return
        }

        isLoadingStoreKitProducts = true
        defer { isLoadingStoreKitProducts = false }

        do {
            let products = try await Product.products(for: StoreKitProductID.allProductIDs)
            storeKitProducts = products.sorted { lhs, rhs in
                storeKitSortIndex(for: lhs.id) < storeKitSortIndex(for: rhs.id)
            }
            storeKitErrorMessage = nil
        } catch {
            storeKitErrorMessage = error.localizedDescription
        }
    }

    func storeKitProduct(for cycle: SubscriptionBillingCycle) -> Product? {
        storeKitProducts.first { product in
            StoreKitProductID(rawValue: product.id)?.billingCycle == cycle
        }
    }

    @discardableResult
    func purchaseStoreKitProduct(_ product: Product) async -> Bool {
        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                let transaction = try checkVerified(verification)
                await applyStoreKitEntitlement(from: transaction)
                await transaction.finish()
                await refreshStoreKitEntitlements()
                return true
            case .userCancelled, .pending:
                return false
            @unknown default:
                return false
            }
        } catch {
            storeKitErrorMessage = error.localizedDescription
            return false
        }
    }

    @discardableResult
    func restoreStoreKitPurchases() async -> Bool {
        do {
            try await StoreKit.AppStore.sync()
            return await refreshStoreKitEntitlements()
        } catch {
            storeKitErrorMessage = error.localizedDescription
            return false
        }
    }

    func presentStoreKitCodeRedemption() {
        SKPaymentQueue.default().presentCodeRedemptionSheet()
    }

    @discardableResult
    func refreshICloudProEntitlement() async -> Bool {
        do {
            let snapshot = try await iCloudProEntitlementService.evaluateCurrentAccount()
            iCloudProRecordHash = snapshot.identifierHash
            let sourceLabel = switch snapshot.source {
            case .cloudKitRecord:
                "CloudKit"
            case .ubiquityIdentityToken:
                "token iCloud local"
            }

            guard snapshot.isAllowed else {
                iCloudProEntitlementMessage = snapshot.allowedHashesConfigured
                    ? "Esta cuenta iCloud no está en la allowlist Pro."
                    : "Hash iCloud listo vía \(sourceLabel). Añádelo a RepsProICloudRecordIDHashes para activar Pro en tus dispositivos."
                revokeICloudOwnerEntitlementIfNeeded()
                return false
            }

            monetization.entitlement = .pro
            monetization.status = .active
            monetization.billingCycle = .lifetime
            monetization.provider = .iCloudOwner
            monetization.renewsAt = nil
            monetization.lastEntitlementSyncDate = .now
            iCloudProEntitlementMessage = "Acceso Pro de propietario activo por iCloud."
            return true
        } catch {
            iCloudProRecordHash = nil
            iCloudProEntitlementMessage = error.localizedDescription
            revokeICloudOwnerEntitlementIfNeeded()
            return false
        }
    }

    @discardableResult
    func refreshStoreKitEntitlements() async -> Bool {
        var latestTransaction: Transaction?

        for await result in Transaction.currentEntitlements {
            guard case .verified(let transaction) = result,
                  transaction.revocationDate == nil,
                  StoreKitProductID(rawValue: transaction.productID) != nil else {
                continue
            }

            if let current = latestTransaction {
                let currentDate = current.expirationDate ?? current.purchaseDate
                let nextDate = transaction.expirationDate ?? transaction.purchaseDate
                if nextDate > currentDate {
                    latestTransaction = transaction
                }
            } else {
                latestTransaction = transaction
            }
        }

        guard let latestTransaction else {
            if monetization.provider == .storeKit {
                monetization.entitlement = .free
                monetization.status = .inactive
                monetization.billingCycle = nil
                monetization.renewsAt = nil
                monetization.lastEntitlementSyncDate = .now
            }
            return false
        }

        await applyStoreKitEntitlement(from: latestTransaction)
        return true
    }

    private func listenForStoreKitTransactions() async {
        for await result in Transaction.updates {
            guard !Task.isCancelled else {
                return
            }

            guard case .verified(let transaction) = result,
                  StoreKitProductID(rawValue: transaction.productID) != nil else {
                continue
            }

            await applyStoreKitEntitlement(from: transaction)
            await transaction.finish()
        }
    }

    private func applyStoreKitEntitlement(from transaction: Transaction) async {
        guard transaction.revocationDate == nil,
              let productID = StoreKitProductID(rawValue: transaction.productID) else {
            await refreshStoreKitEntitlements()
            return
        }

        monetization.entitlement = .pro
        monetization.status = .active
        monetization.billingCycle = productID.billingCycle
        monetization.provider = .storeKit
        monetization.renewsAt = transaction.expirationDate
        monetization.lastEntitlementSyncDate = .now
    }

    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .verified(let value):
            return value
        case .unverified(_, let error):
            throw error
        }
    }

    private func storeKitSortIndex(for productID: String) -> Int {
        switch StoreKitProductID(rawValue: productID) {
        case .weekly: return 0
        case .monthly: return 1
        case .annual: return 2
        case .lifetime: return 3
        case nil: return Int.max
        }
    }

    private func revokeICloudOwnerEntitlementIfNeeded() {
        guard monetization.provider == .iCloudOwner else {
            return
        }

        monetization.entitlement = .free
        monetization.status = .inactive
        monetization.billingCycle = nil
        monetization.renewsAt = nil
        monetization.lastEntitlementSyncDate = .now
    }

    #if DEBUG
    func unlockProForDebug(plan: SubscriptionBillingCycle) {
        monetization.entitlement = .pro
        monetization.status = .active
        monetization.billingCycle = plan
        monetization.provider = .local
        monetization.lastEntitlementSyncDate = .now
    }

    func resetProAccessForDebug() {
        monetization = MonetizationState()
    }
    #endif

    func completeOnboarding(profile: UserProfile) {
        userProfile = profile
        sanitizeAvailableEquipment()
        userProfile.onboardingCompleted = true
        TelemetryService.shared.updateUserProperties(userProfile)
        TelemetryService.shared.log(.onboardingCompleted, parameters: [
            "source": "profile_only",
            "has_plan": false
        ])
    }

    func skipOnboarding() {
        var profile = UserProfile()
        profile.onboardingCompleted = true
        userProfile = profile
        monetization = MonetizationState()
        activePlan = .empty
        plans = []
        scheduledWorkouts = []
        workoutSessions = []
        cardioLogs = []
        bodyMetrics = []
        progressPhotos = []
        gymPasses = []
        gymVisits = []
        goals = []
        savedShareCards = []
        activeWorkoutStatus = nil
        activeWorkout = nil
        activeWorkoutDrafts = []
        TelemetryService.shared.updateUserProperties(userProfile)
        TelemetryService.shared.log(.onboardingSkipped)
    }

    func completeOnboarding(result: OnboardingResult) {
        userProfile = result.profile
        sanitizeAvailableEquipment()
        userProfile.onboardingCompleted = true
        bodyMetrics.append(result.bodyMetric)
        addPlan(result.plan, activate: true)
        TelemetryService.shared.updateUserProperties(userProfile)
        TelemetryService.shared.log(.onboardingCompleted, parameters: [
            "source": "profile_setup",
            "has_plan": true,
            "days_per_week": result.plan.daysPerWeek,
            "plan_days": result.plan.days.count
        ])
    }

    func saveBodyMetrics(weightKg: Double, heightCm: Double, source: BodyMetric.Source = .manual) {
        bodyMetrics.append(BodyMetric(date: Date(), weightKg: weightKg, heightCm: heightCm, source: source))
        TelemetryService.shared.log(.bodyMetricSaved, parameters: [
            "source": source.rawValue,
            "has_weight": weightKg > 0,
            "has_height": heightCm > 0
        ])
    }

    func saveBodyMetric(_ metric: BodyMetric) {
        bodyMetrics.append(metric)
        TelemetryService.shared.log(.bodyMetricSaved, parameters: [
            "source": metric.source.rawValue,
            "has_weight": metric.weightKg > 0,
            "has_height": metric.heightCm > 0
        ])
    }

    func updateLatestBodyMetrics(weightKg: Double, heightCm: Double) {
        if var latest = bodyMetrics.sorted(by: { $0.date < $1.date }).last,
           let index = bodyMetrics.firstIndex(where: { $0.id == latest.id }) {
            latest.weightKg = weightKg
            latest.heightCm = heightCm
            bodyMetrics[index] = latest
        } else {
            saveBodyMetrics(weightKg: weightKg, heightCm: heightCm)
        }
    }

    func updateAvatarImageData(_ data: Data?) {
        userProfile.avatarImageData = data
    }

    func addProgressPhoto(_ photo: ProgressPhoto) {
        progressPhotos.append(photo)
        TelemetryService.shared.log(.progressPhotoAdded, parameters: [
            "has_weight": photo.weightKg != nil,
            "has_note": photo.note?.isEmpty == false
        ])
    }

    func addGymPass(_ pass: GymPass) {
        gymPasses.append(pass)
        TelemetryService.shared.log(.gymPassAdded, parameters: [
            "code_type": pass.codeType.rawValue
        ])
    }

    func addGymVisit(_ visit: GymVisit) {
        gymVisits.append(visit)
    }

    @discardableResult
    func handleReceiptDeepLink(_ url: URL) -> Bool {
        guard let payload = WorkoutReceiptDeepLink.payload(from: url) else {
            return false
        }

        let alreadySaved = savedShareCards.contains { card in
            card.workoutTitle == payload.workoutTitle
                && abs(card.date.timeIntervalSince(payload.date)) < 1
        }

        let image = WorkoutShareImageRenderer.render(payload: payload)
        if let data = image.pngData(), !data.isEmpty {
            UIPasteboard.general.image = image

            if !alreadySaved {
                savedShareCards.append(
                    SavedShareCard(
                        date: payload.date,
                        workoutTitle: payload.workoutTitle,
                        imageData: data
                    )
                )
            }
        }

        TelemetryService.shared.log(.receiptDeepLinkImported, parameters: [
            "already_saved": alreadySaved,
            "exercise_count": payload.exercises.count
        ])

        return true
    }

    func addCardioLog(_ log: CardioLog) {
        cardioLogs.append(log)
        TelemetryService.shared.log(.cardioLogAdded, parameters: [
            "activity_type": log.activityType.rawValue,
            "duration_minutes": log.durationMinutes
        ])
    }

    func importCardioLogs(_ logs: [CardioLog]) -> Int {
        let existingKeys = Set(cardioLogs.map(\.dedupeKey))
        let newLogs = logs.filter { !existingKeys.contains($0.dedupeKey) }
        cardioLogs.append(contentsOf: newLogs)
        return newLogs.count
    }

    /// Applies the in-workout "aim for more sets next time" intent by bumping the matching
    /// planned exercise's target set count, so the next session reflects the athlete's choice.
    func applyAimForMoreIntent(from drafts: [ExerciseSessionDraft], dayID: UUID) {
        guard let dayIndex = activePlan.days.firstIndex(where: { $0.id == dayID }) else { return }
        var changed = false
        for draft in drafts where draft.workoutExercise.aimForMoreSetsNextTime {
            guard let exerciseIndex = activePlan.days[dayIndex].exercises.firstIndex(
                where: { $0.id == draft.workoutExercise.id }
            ) else { continue }
            let current = activePlan.days[dayIndex].exercises[exerciseIndex].targetSets
            activePlan.days[dayIndex].exercises[exerciseIndex].targetSets = min(current + 1, 10)
            activePlan.days[dayIndex].exercises[exerciseIndex].aimForMoreSetsNextTime = false
            changed = true
        }
        if changed, let planIndex = plans.firstIndex(where: { $0.id == activePlan.id }) {
            plans[planIndex] = activePlan
        }
    }

    func finishWorkout(_ session: WorkoutSession) {
        workoutSessions.append(session)
        TelemetryService.shared.log(.workoutFinished, parameters: [
            "origin": session.origin.rawValue,
            "location": session.location.rawValue,
            "duration_minutes": session.durationMinutes,
            "exercise_count": session.exerciseLogs?.count ?? 0,
            "set_count": session.sets.count
        ])
        
        // Render virtual receipt image and auto-save it to our profile gallery
        saveReceiptCard(for: session)
        
        self.finishedSessionForSummary = session
        activeWorkoutStatus = nil
        activeWorkout = nil
        activeWorkoutDrafts = []
        
        // Advance progress of the current plan's correct day if completed
        if !activePlan.days.isEmpty {
            let count = activePlan.days.count
            let index = ((activePlan.activeDayIndex % count) + count) % count
            let currentDay = activePlan.days[index]
            if session.workoutTitle == currentDay.title {
                activePlan.activeDayIndex = ((activePlan.activeDayIndex + 1) % count + count) % count
                if let index = plans.firstIndex(where: { $0.id == activePlan.id }) {
                    plans[index] = activePlan
                }
            }
        }
        
        let calendar = Calendar.current
        if let index = scheduledWorkouts.firstIndex(where: { calendar.isDateInToday($0.date) && $0.workoutDay.title == session.workoutTitle }) {
            scheduledWorkouts[index].status = .completed
        }

        let battery = trainingBattery
        if userProfile.remindersEnabled, battery.level < 55 {
            Task {
                try? await NotificationService.scheduleBatteryRecoverySuggestion(
                    level: battery.level,
                    suggestion: battery.suggestion
                )
            }
        }
    }

    private func saveReceiptCard(for session: WorkoutSession, replacingExisting: Bool = false) {
        let image = WorkoutShareImageRenderer.render(session: session)
        guard let data = image.pngData(), !data.isEmpty else {
            TelemetryService.shared.log(.nonFatalError, parameters: ["context": "receipt_render_empty_png"])
            return
        }

        let card = SavedShareCard(date: session.date, workoutTitle: session.workoutTitle, imageData: data)
        if replacingExisting, let existingIndex = receiptCardIndex(for: session) {
            savedShareCards[existingIndex] = card
        } else {
            savedShareCards.append(card)
        }
    }

    private func receiptCardIndex(for session: WorkoutSession) -> Int? {
        savedShareCards.firstIndex { card in
            card.workoutTitle == session.workoutTitle &&
            abs(card.date.timeIntervalSince(session.date)) < 2
        }
    }

    @discardableResult
    func finishActiveWorkoutFromSummaryCard() -> WorkoutSession? {
        guard let status = activeWorkoutStatus else {
            return nil
        }
        let elapsedSeconds = status.effectiveElapsedSeconds()
        let pausedSeconds = status.effectivePausedSeconds()

        let logs = activeWorkoutDrafts.compactMap { draft -> ExerciseLog? in
            let completedSets = draft.sets.filter(\.completed)
            guard !completedSets.isEmpty else {
                return nil
            }
            return ExerciseLog(
                exercise: draft.workoutExercise.exercise,
                notes: draft.notes,
                sets: completedSets,
                mediaAttachments: draft.mediaAttachments
            )
        }
        let allSets = logs.flatMap(\.sets)
        let location: WorkoutSession.Location
        if status.isOutdoorRoute == true {
            location = .outdoor
        } else if activeWorkout?.sessionType == .free {
            location = userProfile.trainingLocation == .home ? .home : .gym
        } else {
            location = activePlan.location == .home ? .home : .gym
        }
        let startedAt = status.startedAt == .distantPast
            ? Date().addingTimeInterval(TimeInterval(-elapsedSeconds))
            : status.startedAt

        let session = WorkoutSession(
            workoutTitle: activeWorkout?.title ?? status.workoutTitle,
            date: .now,
            startedAt: startedAt,
            endedAt: .now,
            origin: activeWorkout?.sessionType == .free ? .free : .routine,
            location: location,
            contextTag: .normal,
            durationMinutes: max(elapsedSeconds / 60, 1),
            sets: allSets,
            notes: logs.isEmpty ? nil : logs.map { "\($0.exercise.name): \($0.sets.count) sets" }.joined(separator: "\n"),
            exerciseLogs: logs,
            routePoints: [],
            pausedDurationSeconds: pausedSeconds
        )
        finishWorkout(session)
        return session
    }

    func startActiveWorkout(_ workout: WorkoutDay, elapsedSeconds: Int = 0, pausedSeconds: Int = 0, isPaused: Bool = false) {
        let isRouteWorkout = Self.isRouteWorkout(workout)
        let isOutdoorRoute = Self.isOutdoorRoute(workout)
        activeWorkout = workout
        activeWorkoutDrafts = workout.exercises.map { item in
            ExerciseSessionDraft(
                workoutExercise: item,
                notes: "",
                sets: (1...max(item.targetSets, 1)).map { setIndex in
                    SetLog(
                        setNumber: setIndex,
                        weightKg: defaultWeight(from: item.previous),
                        reps: defaultReps(from: item.repRange),
                        completed: false
                    )
                }
            )
        }
        activeWorkoutStatus = ActiveWorkoutStatus(
            planTitle: activePlan.days.isEmpty ? nil : activePlan.name,
            workoutTitle: workout.title,
            sessionTitle: workout.subtitle,
            elapsedSeconds: elapsedSeconds,
            pausedSeconds: pausedSeconds,
            completedSets: 0,
            totalSets: activeWorkoutDrafts.flatMap(\.sets).count,
            volumeKg: 0,
            isPaused: isPaused,
            isRouteWorkout: isRouteWorkout,
            isOutdoorRoute: isOutdoorRoute
        )
        TelemetryService.shared.log(.workoutStarted, parameters: [
            "session_type": workout.sessionType.rawValue,
            "exercise_count": workout.exercises.count,
            "origin_has_active_plan": activePlan.days.contains { $0.id == workout.id }
        ])
    }

    func startPreparedActiveWorkout(_ workout: WorkoutDay, drafts: [ExerciseSessionDraft], isPaused: Bool = false, startedAt: Date = .now) {
        var preparedWorkout = workout
        preparedWorkout.exercises = drafts.map(\.workoutExercise)
        let isRouteWorkout = Self.isRouteWorkout(preparedWorkout)
        let isOutdoorRoute = Self.isOutdoorRoute(preparedWorkout)
        activeWorkout = preparedWorkout
        activeWorkoutDrafts = drafts
        activeWorkoutStatus = ActiveWorkoutStatus(
            planTitle: activePlan.days.isEmpty ? nil : activePlan.name,
            workoutTitle: preparedWorkout.title,
            sessionTitle: preparedWorkout.subtitle,
            startedAt: startedAt,
            elapsedSeconds: 0,
            pausedSeconds: 0,
            completedSets: drafts.flatMap(\.sets).filter(\.completed).count,
            totalSets: drafts.flatMap(\.sets).count,
            volumeKg: 0,
            isPaused: isPaused,
            exerciseName: drafts.first?.workoutExercise.exercise.name,
            exerciseIndex: drafts.isEmpty ? nil : 1,
            totalExercises: drafts.count,
            isRouteWorkout: isRouteWorkout,
            isOutdoorRoute: isOutdoorRoute
        )
        TelemetryService.shared.log(.workoutStarted, parameters: [
            "session_type": preparedWorkout.sessionType.rawValue,
            "exercise_count": preparedWorkout.exercises.count,
            "origin_has_active_plan": activePlan.days.contains { $0.id == workout.id }
        ])
    }

    private static func isRouteWorkout(_ workout: WorkoutDay) -> Bool {
        workout.isCardioMovement
    }

    private static func isOutdoorRoute(_ workout: WorkoutDay) -> Bool {
        workout.isOutdoorRouteWorkout
    }

    private func defaultWeight(from previous: String) -> Double {
        let normalized = previous.replacingOccurrences(of: ",", with: ".")
        let number = normalized
            .split { character in
                !(character.isNumber || character == ".")
            }
            .compactMap { Double($0) }
            .first
        return number ?? 0
    }

    private func defaultReps(from repRange: String) -> Int {
        let digits = repRange.split { !$0.isNumber }.compactMap { Int($0) }
        return digits.first ?? 8
    }

    func updateActiveWorkout(
        elapsedSeconds: Int,
        pausedSeconds: Int,
        completedSets: Int,
        totalSets: Int,
        volumeKg: Int,
        isPaused: Bool,
        exerciseName: String? = nil,
        exerciseIndex: Int? = nil,
        totalExercises: Int? = nil,
        currentExerciseCompletedSets: Int? = nil,
        currentExerciseTotalSets: Int? = nil,
        currentSetWeightKg: Double? = nil,
        currentSetReps: Int? = nil,
        restSeconds: Int? = nil,
        restDurationSeconds: Int? = nil,
        estimatedRemainingSeconds: Int? = nil,
        waterLiters: Double? = nil,
        musicTitle: String? = nil,
        musicArtist: String? = nil,
        isMusicPlaying: Bool? = nil,
        nextExerciseName: String? = nil,
        exerciseHistorySummary: String? = nil,
        gymPass: GymPass? = nil,
        lastPausedAt: Date? = nil,
        isRouteWorkout: Bool = false,
        isOutdoorRoute: Bool? = nil,
        routeDistanceKm: Double? = nil,
        routePaceSecondsPerKm: Double? = nil,
        routeSpeedKmh: Double? = nil,
        routePointCount: Int? = nil,
        routeSteps: Double? = nil,
        liveHeartRate: Double? = nil,
        liveActiveEnergyKcal: Double? = nil
    ) {
        guard var status = activeWorkoutStatus else { return }
        status.planTitle = activePlan.name
        status.sessionTitle = activeWorkout?.subtitle
        status.elapsedSeconds = elapsedSeconds
        status.pausedSeconds = pausedSeconds
        status.completedSets = completedSets
        status.totalSets = totalSets
        status.volumeKg = volumeKg
        status.isPaused = isPaused
        status.exerciseName = exerciseName
        status.exerciseIndex = exerciseIndex
        status.totalExercises = totalExercises
        status.currentExerciseCompletedSets = currentExerciseCompletedSets
        status.currentExerciseTotalSets = currentExerciseTotalSets
        status.currentSetWeightKg = currentSetWeightKg
        status.currentSetReps = currentSetReps
        status.restSeconds = restSeconds
        status.restDurationSeconds = restDurationSeconds
        status.estimatedRemainingSeconds = estimatedRemainingSeconds
        status.waterLiters = waterLiters
        status.musicTitle = musicTitle
        status.musicArtist = musicArtist
        status.isMusicPlaying = isMusicPlaying
        status.nextExerciseName = nextExerciseName
        status.exerciseHistorySummary = exerciseHistorySummary
        status.gymPassName = gymPass?.gymName
        status.gymMembershipID = gymPass?.membershipID
        status.gymCodeValue = gymPass?.codeValue
        status.gymCodeType = gymPass?.codeType.rawValue
        status.lastPausedAt = lastPausedAt
        status.isRouteWorkout = isRouteWorkout || status.isRouteWorkout
        status.isOutdoorRoute = isOutdoorRoute ?? status.isOutdoorRoute
        if status.isRouteWorkout {
            status.routeDistanceKm = Self.bestRouteDistance(status.routeDistanceKm, routeDistanceKm)
            status.routePaceSecondsPerKm = Self.bestRouteMetric(status.routePaceSecondsPerKm, routePaceSecondsPerKm)
            status.routeSpeedKmh = Self.bestRouteMetric(status.routeSpeedKmh, routeSpeedKmh)
            status.routePointCount = max(status.routePointCount ?? 0, routePointCount ?? 0)
            status.routeSteps = Self.bestRouteMetric(status.routeSteps, routeSteps)
        } else {
            status.routeDistanceKm = nil
            status.routePaceSecondsPerKm = nil
            status.routeSpeedKmh = nil
            status.routePointCount = nil
            status.routeSteps = nil
        }
        if let liveHeartRate {
            status.liveHeartRate = liveHeartRate
        }
        if let liveActiveEnergyKcal {
            status.liveActiveEnergyKcal = liveActiveEnergyKcal
        }
        activeWorkoutStatus = status
    }

    func updateActiveWorkout(_ update: ActiveWorkoutStatusBuilder.Update) {
        updateActiveWorkout(
            elapsedSeconds: update.elapsedSeconds,
            pausedSeconds: update.pausedSeconds,
            completedSets: update.completedSets,
            totalSets: update.totalSets,
            volumeKg: update.volumeKg,
            isPaused: update.isPaused,
            exerciseName: update.exerciseName,
            exerciseIndex: update.exerciseIndex,
            totalExercises: update.totalExercises,
            currentExerciseCompletedSets: update.currentExerciseCompletedSets,
            currentExerciseTotalSets: update.currentExerciseTotalSets,
            currentSetWeightKg: update.currentSetWeightKg,
            currentSetReps: update.currentSetReps,
            restSeconds: update.restSeconds,
            restDurationSeconds: update.restDurationSeconds,
            estimatedRemainingSeconds: update.estimatedRemainingSeconds,
            waterLiters: update.waterLiters,
            musicTitle: update.musicTitle,
            musicArtist: update.musicArtist,
            isMusicPlaying: update.isMusicPlaying,
            nextExerciseName: update.nextExerciseName,
            exerciseHistorySummary: update.exerciseHistorySummary,
            gymPass: update.gymPass,
            lastPausedAt: update.lastPausedAt,
            isRouteWorkout: update.isRouteWorkout,
            isOutdoorRoute: update.isOutdoorRoute,
            routeDistanceKm: update.routeDistanceKm,
            routePaceSecondsPerKm: update.routePaceSecondsPerKm,
            routeSpeedKmh: update.routeSpeedKmh,
            routePointCount: update.routePointCount,
            routeSteps: update.routeSteps,
            liveHeartRate: update.liveHeartRate,
            liveActiveEnergyKcal: update.liveActiveEnergyKcal
        )
    }

    private static func bestRouteDistance(_ current: Double?, _ incoming: Double?) -> Double? {
        guard let incoming, incoming > 0 else { return current }
        guard let current, current > 0 else { return incoming }
        return max(current, incoming)
    }

    private static func bestRouteMetric(_ current: Double?, _ incoming: Double?) -> Double? {
        if let incoming, incoming > 0 {
            return incoming
        }
        return current
    }

    func setActiveWorkoutPaused(_ paused: Bool) {
        guard var status = activeWorkoutStatus else { return }
        status.isPaused = paused
        if paused {
            status.lastPausedAt = Date()
        } else {
            if let lastPaused = status.lastPausedAt {
                let duration = Int(Date().timeIntervalSince(lastPaused))
                status.pausedSeconds += duration
            }
            status.lastPausedAt = nil
        }
        activeWorkoutStatus = status
    }

    func clearActiveWorkout() {
        activeWorkoutStatus = nil
        activeWorkout = nil
        activeWorkoutDrafts = []
    }

    private func handleWatchCommand(_ command: WatchCommand) {
        switch command {
        case .pause:
            setActiveWorkoutPaused(true)
            NotificationCenter.default.post(name: command.notificationName, object: nil)
        case .resume:
            setActiveWorkoutPaused(false)
            NotificationCenter.default.post(name: command.notificationName, object: nil)
        case .stop:
            finishActiveWorkoutFromSummaryCard()
        case .musicToggle, .musicNext, .musicPrevious, .completeSet, .nextExercise, .previousExercise, .addWater, .voiceNote:
            NotificationCenter.default.post(name: command.notificationName, object: nil)
        }
    }

    private func handleWatchRouteMetrics(_ metrics: WatchRouteMetrics) {
        guard var status = activeWorkoutStatus else { return }
        status.isRouteWorkout = true
        status.routeDistanceKm = metrics.distanceKm ?? status.routeDistanceKm
        status.routePaceSecondsPerKm = metrics.paceSecondsPerKm ?? status.routePaceSecondsPerKm
        status.routeSpeedKmh = metrics.speedKmh ?? status.routeSpeedKmh
        status.routeSteps = metrics.steps ?? status.routeSteps
        status.routePointCount = max(status.routePointCount ?? 0, metrics.pointCount ?? 0)
        status.liveHeartRate = metrics.heartRate ?? status.liveHeartRate
        status.liveActiveEnergyKcal = metrics.activeEnergyKcal ?? status.liveActiveEnergyKcal
        activeWorkoutStatus = status
    }

    private func importWatchRouteWorkout(_ summary: WatchRouteWorkoutSummary) {
        let healthKitID = "watch-\(summary.id.uuidString)"
        let routePoints = summary.routePoints.map {
            RoutePoint(
                latitude: $0.latitude,
                longitude: $0.longitude,
                altitude: $0.altitude,
                horizontalAccuracy: $0.horizontalAccuracy,
                timestamp: $0.timestamp,
                heartRate: $0.heartRate,
                cadenceSpm: $0.cadenceSpm
            )
        }

        if let duplicateIndex = workoutSessions.firstIndex(where: { $0.id == summary.id || $0.healthKitUUIDString == healthKitID }) {
            var existing = workoutSessions[duplicateIndex]
            if existing.routePoints.isEmpty {
                existing.routePoints = routePoints
            }
            if !routePoints.isEmpty {
                existing.location = .outdoor
            }
            existing.distanceKm = Self.bestRouteDistance(existing.distanceKm, summary.distanceKm)
            existing.averagePaceSecondsPerKm = existing.averagePaceSecondsPerKm ?? summary.averagePaceSecondsPerKm
            workoutSessions[duplicateIndex] = existing
            saveReceiptCard(for: existing, replacingExisting: true)
            return
        }

        if let existingIndex = workoutSessions.firstIndex(where: { session in
            let sessionStart = session.startedAt ?? session.date
            let sessionEnd = session.endedAt ?? session.date
            let overlapsStart = abs(sessionStart.timeIntervalSince(summary.startedAt)) < 600
            let overlapsEnd = abs(sessionEnd.timeIntervalSince(summary.endedAt)) < 600
            return (session.isRouteSession || session.location == .outdoor) && (overlapsStart || overlapsEnd)
        }) {
            var existing = workoutSessions[existingIndex]
            existing.healthKitUUIDString = existing.healthKitUUIDString ?? healthKitID
            existing.healthKitActivityTypes = existing.healthKitActivityTypes.isEmpty ? [summary.activity == .running ? "Running" : "Walking"] : existing.healthKitActivityTypes
            existing.routePoints = existing.routePoints.isEmpty ? routePoints : existing.routePoints
            if !routePoints.isEmpty {
                existing.location = .outdoor
            }
            existing.distanceKm = Self.bestRouteDistance(existing.distanceKm, summary.distanceKm)
            existing.averagePaceSecondsPerKm = existing.averagePaceSecondsPerKm ?? summary.averagePaceSecondsPerKm
            existing.steps = Self.bestRouteMetric(existing.steps, summary.steps)
            existing.activeEnergyKcal = Self.bestRouteMetric(existing.activeEnergyKcal, summary.activeEnergyKcal)
            existing.estimatedCalories = Self.bestRouteMetric(existing.estimatedCalories, summary.activeEnergyKcal)
            existing.averageHeartRate = existing.averageHeartRate ?? summary.averageHeartRate
            existing.maxHeartRate = Self.bestRouteMetric(existing.maxHeartRate, summary.maxHeartRate)
            workoutSessions[existingIndex] = existing
            saveReceiptCard(for: existing, replacingExisting: true)

            let mergedActivityType: CardioLog.ActivityType = summary.activity == .running
                ? (existing.location == .outdoor || !routePoints.isEmpty ? .outdoorRun : .treadmill)
                : .walking
            let cardioLog = CardioLog(
                activityType: mergedActivityType,
                date: summary.startedAt,
                durationMinutes: summary.durationMinutes,
                distanceKm: summary.distanceKm,
                averageSpeedKmh: summary.averageSpeedKmh,
                averagePaceSecondsPerKm: summary.averagePaceSecondsPerKm,
                averageHeartRate: summary.averageHeartRate,
                maxHeartRate: summary.maxHeartRate,
                estimatedCalories: summary.activeEnergyKcal,
                steps: summary.steps,
                activeEnergyKcal: summary.activeEnergyKcal,
                heartRateBefore: nil,
                heartRateAfter: nil,
                rpe: nil,
                notes: routePoints.isEmpty ? "Cardio en cinta enriquecido desde Apple Watch." : "Ruta enriquecida desde Apple Watch.",
                routePoints: existing.location == .outdoor ? routePoints : []
            )
            _ = importCardioLogs([cardioLog])
            return
        }

        let title = summary.activity.title
        let session = WorkoutSession(
            id: summary.id,
            workoutTitle: title,
            date: summary.endedAt,
            startedAt: summary.startedAt,
            endedAt: summary.endedAt,
            origin: .free,
            location: .outdoor,
            contextTag: .normal,
            durationMinutes: summary.durationMinutes,
            sets: [],
            notes: "Iniciado y registrado desde Apple Watch.",
            exerciseLogs: [],
            sessionRPE: nil,
            energyBefore: nil,
            energyAfter: nil,
            estimatedCalories: summary.activeEnergyKcal,
            mediaAttachments: [],
            routePoints: routePoints,
            pausedDurationSeconds: summary.pausedSeconds,
            distanceKm: summary.distanceKm,
            averagePaceSecondsPerKm: summary.averagePaceSecondsPerKm,
            steps: summary.steps,
            activeEnergyKcal: summary.activeEnergyKcal,
            heartRateBefore: nil,
            heartRateAfter: nil,
            healthKitUUIDString: healthKitID,
            isImportedFromHealth: false,
            healthKitActivityTypes: [summary.activity == .running ? "Running" : "Walking"],
            averageHeartRate: summary.averageHeartRate,
            maxHeartRate: summary.maxHeartRate
        )

        workoutSessions.append(session)

        let cardioLog = CardioLog(
            activityType: summary.activity == .running ? .outdoorRun : .walking,
            date: summary.startedAt,
            durationMinutes: summary.durationMinutes,
            distanceKm: summary.distanceKm,
            averageSpeedKmh: summary.averageSpeedKmh,
            averagePaceSecondsPerKm: summary.averagePaceSecondsPerKm,
            averageHeartRate: summary.averageHeartRate,
            maxHeartRate: summary.maxHeartRate,
            estimatedCalories: summary.activeEnergyKcal,
            steps: summary.steps,
            activeEnergyKcal: summary.activeEnergyKcal,
            heartRateBefore: nil,
            heartRateAfter: nil,
            rpe: nil,
            notes: "Importado desde Apple Watch.",
            routePoints: routePoints
        )
        _ = importCardioLogs([cardioLog])

        saveReceiptCard(for: session)

        TelemetryService.shared.log(.workoutFinished, parameters: [
            "origin": session.origin.rawValue,
            "location": session.location.rawValue,
            "duration_minutes": session.durationMinutes,
            "exercise_count": 0,
            "set_count": 0,
            "source": "apple_watch"
        ])
    }

    // MARK: - Apple Watch strength & interval logging

    /// Applies a set logged live on the Watch to the active workout drafts and
    /// asks the active workout screen (if loaded) to recompute the rich status.
    private func handleWatchLogSet(_ logSet: WatchLogSet) {
        guard activeWorkoutStatus != nil else { return }
        var drafts = activeWorkoutDrafts
        guard drafts.indices.contains(logSet.exerciseIndex) else { return }
        var sets = drafts[logSet.exerciseIndex].sets
        let type = SetLog.SetType(rawValue: logSet.setType) ?? .work
        if sets.indices.contains(logSet.setIndex) {
            sets[logSet.setIndex].weightKg = logSet.weightKg
            sets[logSet.setIndex].reps = logSet.reps
            sets[logSet.setIndex].completed = logSet.completed
            sets[logSet.setIndex].setType = type
        } else {
            sets.append(SetLog(
                setNumber: sets.count + 1,
                weightKg: logSet.weightKg,
                reps: logSet.reps,
                completed: logSet.completed,
                setType: type
            ))
        }
        drafts[logSet.exerciseIndex].sets = sets
        activeWorkoutDrafts = drafts
        NotificationCenter.default.post(name: .watchDidLogSet, object: nil)
        SharedWorkoutStore.save(sharedWorkoutSnapshot())
    }

    /// Resolves an exercise from the library by normalized name, falling back to
    /// a minimal exercise when the Watch logged a free / unknown movement.
    private func resolvedExercise(named name: String, trackingType: String) -> Exercise {
        let key = name.normalizedExerciseKey
        if let match = exercises.first(where: { $0.name.normalizedExerciseKey == key }) {
            return match
        }
        return Exercise(
            name: name,
            muscleGroup: "Full Body",
            equipment: "Other",
            trackingType: Exercise.TrackingType(rawValue: trackingType) ?? .weightReps
        )
    }

    /// Imports a complete strength workout logged on the Watch (offline dump),
    /// mirroring `importWatchRouteWorkout` with dedupe by id.
    private func importWatchStrengthWorkout(_ summary: WatchStrengthWorkoutSummary) {
        let healthKitID = "watch-\(summary.id.uuidString)"
        guard !workoutSessions.contains(where: { $0.id == summary.id || $0.healthKitUUIDString == healthKitID }) else {
            return
        }

        let exerciseLogs: [ExerciseLog] = summary.exercises.compactMap { shared in
            let loggedSets: [SetLog] = shared.sets.enumerated().compactMap { index, set in
                guard set.completed else { return nil }
                return SetLog(
                    setNumber: index + 1,
                    weightKg: set.weightKg,
                    reps: set.reps,
                    completed: true,
                    setType: SetLog.SetType(rawValue: set.setType) ?? .work,
                    rpe: set.rpe
                )
            }
            guard !loggedSets.isEmpty else { return nil }
            return ExerciseLog(
                exercise: resolvedExercise(named: shared.name, trackingType: shared.trackingType),
                notes: "",
                sets: loggedSets
            )
        }
        guard !exerciseLogs.isEmpty else { return }
        let allSets = exerciseLogs.flatMap(\.sets)

        let session = WorkoutSession(
            id: summary.id,
            workoutTitle: summary.title,
            date: summary.endedAt,
            startedAt: summary.startedAt,
            endedAt: summary.endedAt,
            origin: .free,
            location: .gym,
            contextTag: .normal,
            durationMinutes: summary.durationMinutes,
            sets: allSets,
            notes: "Registrado desde Apple Watch.",
            exerciseLogs: exerciseLogs,
            sessionRPE: nil,
            energyBefore: nil,
            energyAfter: nil,
            estimatedCalories: summary.activeEnergyKcal,
            mediaAttachments: [],
            routePoints: [],
            pausedDurationSeconds: summary.pausedSeconds,
            distanceKm: nil,
            averagePaceSecondsPerKm: nil,
            steps: nil,
            activeEnergyKcal: summary.activeEnergyKcal,
            heartRateBefore: nil,
            heartRateAfter: nil,
            healthKitUUIDString: healthKitID,
            isImportedFromHealth: false,
            healthKitActivityTypes: [],
            averageHeartRate: summary.averageHeartRate,
            maxHeartRate: summary.maxHeartRate
        )

        workoutSessions.append(session)
        saveReceiptCard(for: session)

        TelemetryService.shared.log(.workoutFinished, parameters: [
            "origin": session.origin.rawValue,
            "location": session.location.rawValue,
            "duration_minutes": session.durationMinutes,
            "exercise_count": exerciseLogs.count,
            "set_count": allSets.count,
            "source": "apple_watch"
        ])
    }

    /// Imports an interval / HIIT workout run on the Watch as a HIIT cardio log.
    private func importWatchIntervalWorkout(_ summary: WatchIntervalWorkoutSummary) {
        let log = CardioLog(
            id: summary.id,
            activityType: .hiit,
            date: summary.startedAt,
            durationMinutes: summary.durationMinutes,
            distanceKm: nil,
            averageSpeedKmh: nil,
            averagePaceSecondsPerKm: nil,
            averageHeartRate: summary.averageHeartRate,
            maxHeartRate: summary.maxHeartRate,
            estimatedCalories: summary.activeEnergyKcal,
            steps: nil,
            activeEnergyKcal: summary.activeEnergyKcal,
            heartRateBefore: nil,
            heartRateAfter: nil,
            rpe: nil,
            notes: "Intervalos registrados desde Apple Watch.",
            routePoints: []
        )
        _ = importCardioLogs([log])
    }

    private func handleNativeWorkoutMetrics(_ metrics: NativeWorkoutMetrics) {
        guard var status = activeWorkoutStatus else { return }

        if let heartRate = metrics.heartRate {
            status.liveHeartRate = heartRate
        }
        if let activeEnergyKcal = metrics.activeEnergyKcal {
            status.liveActiveEnergyKcal = activeEnergyKcal
        }
        if status.isRouteWorkout || metrics.distanceKm != nil {
            status.isRouteWorkout = true
            status.routeDistanceKm = Self.bestRouteDistance(status.routeDistanceKm, metrics.distanceKm)
            status.routeSteps = Self.bestRouteMetric(status.routeSteps, metrics.steps)
        }

        activeWorkoutStatus = status
    }

    private func handleMirroredNativeWorkoutStart(_ payload: NativeWorkoutStartPayload) {
        guard activeWorkoutStatus == nil else { return }

        let workout = Self.workoutDay(for: payload)
        startPreparedActiveWorkout(workout, drafts: [], isPaused: false, startedAt: payload.startedAt)
        if var status = activeWorkoutStatus {
            status.planTitle = localizedString("apple_watch_2")
            status.isRouteWorkout = workout.isCardioMovement
            status.isOutdoorRoute = payload.locationType == .outdoor
            activeWorkoutStatus = status
        }
        health.message = localizedString("workout_started_from_apple_watch")
    }

    private func handleNativeWorkoutEnded() {
        guard activeWorkoutStatus != nil else { return }
        _ = finishActiveWorkoutFromSummaryCard()
        refreshHealthKitDataIfNeeded(force: true, reason: "native_workout_ended")
    }

    private static func workoutDay(for payload: NativeWorkoutStartPayload) -> WorkoutDay {
        WorkoutDay(
            title: nameForActivityType(payload.activityType),
            subtitle: "started_from_apple_watch",
            durationMinutes: 45,
            exercises: [],
            sessionType: sessionType(for: payload.activityType),
            cardioEnvironment: payload.locationType == .indoor ? .treadmill : .outdoor
        )
    }

    private static func sessionType(for activityType: HKWorkoutActivityType) -> WorkoutDay.SessionType {
        switch activityType {
        case .running:
            return .cardioRun
        case .walking, .hiking:
            return .cardioWalk
        case .traditionalStrengthTraining, .functionalStrengthTraining, .coreTraining:
            return .free
        case .yoga, .pilates, .flexibility:
            return .mobility
        default:
            return .free
        }
    }

    /// Estimated max heart rate (≈ 220 − age) for HR-zone coloring on the Watch.
    private var watchEstimatedMaxHeartRate: Double? {
        guard let dob = userProfile.dateOfBirth else { return nil }
        let years = Calendar.current.dateComponents([.year], from: dob, to: .now).year ?? 0
        guard years > 0, years < 120 else { return nil }
        return Double(220 - years)
    }

    /// Encodes the active strength drafts into the shared planned-exercise shape
    /// so the Watch can render the full list and log sets live. Returns nil for
    /// non-strength / empty sessions.
    private func watchExercisesData() -> Data? {
        let drafts = activeWorkoutDrafts
        guard !drafts.isEmpty else { return nil }
        let language = userProfile.preferredLanguage
        let planned: [SharedPlannedExercise] = drafts.map { draft in
            SharedPlannedExercise(
                name: RepsText.exerciseName(draft.workoutExercise.exercise.name, language: language),
                trackingType: draft.workoutExercise.exercise.trackingType.rawValue,
                targetSets: draft.workoutExercise.targetSets,
                repRange: draft.workoutExercise.repRange,
                restSeconds: draft.workoutExercise.restSeconds,
                previous: draft.workoutExercise.previous.isEmpty ? nil : draft.workoutExercise.previous,
                sets: draft.sets.map { set in
                    SharedPlannedSet(
                        weightKg: set.weightKg,
                        reps: set.reps,
                        completed: set.completed,
                        setType: set.setType.rawValue,
                        rpe: set.rpe
                    )
                }
            )
        }
        return try? JSONEncoder().encode(planned)
    }

    private func sharedWorkoutSnapshot() -> SharedWorkoutSnapshot {
        let battery = trainingBattery
        let streak = streakDays
        let completion = weeklyCompletion
        let nextWorkout = todaysWorkout

        guard let status = activeWorkoutStatus else {
            return SharedWorkoutSnapshot(
                hasActiveWorkout: false,
                planTitle: activePlan.days.isEmpty ? nil : activePlan.name,
                workoutTitle: "Reps",
                sessionTitle: nil,
                elapsedSeconds: 0,
                pausedSeconds: 0,
                completedSets: 0,
                totalSets: 0,
                volumeKg: 0,
                isPaused: false,
                exerciseName: nil,
                exerciseIndex: nil,
                totalExercises: nil,
                currentExerciseCompletedSets: nil,
                currentExerciseTotalSets: nil,
                currentSetWeightKg: nil,
                currentSetReps: nil,
                restSeconds: nil,
                restDurationSeconds: nil,
                estimatedRemainingSeconds: nil,
                waterLiters: todayHealthMetric?.waterLiters,
                musicTitle: nil,
                musicArtist: nil,
                isMusicPlaying: nil,
                nextExerciseName: nil,
                exerciseHistorySummary: nil,
                gymPassName: gymPasses.first?.gymName,
                gymMembershipID: gymPasses.first?.membershipID,
                gymCodeValue: gymPasses.first?.codeValue,
                gymCodeType: gymPasses.first?.codeType.rawValue,
                heartRate: todayHealthMetric?.restingHeartRate,
                activeEnergyKcal: todayHealthMetric?.activeEnergyKcal,
                isRouteWorkout: false,
                isOutdoorRoute: nil,
                routeDistanceKm: nil,
                routePaceSecondsPerKm: nil,
                routeSpeedKmh: nil,
                routePointCount: nil,
                routeSteps: nil,
                summary: dailySummary,
                updatedAt: .now,
                streakDays: streak,
                weeklyCompletion: completion,
                trainingBatteryLevel: battery.level,
                trainingBatteryState: battery.state.rawValue,
                trainingBatteryTitle: battery.title,
                trainingBatterySuggestion: battery.suggestion,
                trainingBatterySystemImage: battery.systemImage,
                nextWorkoutDayName: activePlan.days.isEmpty ? nil : nextWorkout.title,
                nextWorkoutDayDescription: activePlan.days.isEmpty ? nil : nextWorkout.subtitle,
                widgetAccentColorName: userProfile.widgetAccentColorName,
                preferredLanguage: userProfile.preferredLanguage,
                exercisesData: nil,
                estimatedMaxHeartRate: watchEstimatedMaxHeartRate
            )
        }

        let elapsedSeconds = status.effectiveElapsedSeconds()
        let pausedSeconds = status.effectivePausedSeconds()
        return SharedWorkoutSnapshot(
            hasActiveWorkout: true,
            planTitle: status.planTitle ?? (activePlan.days.isEmpty ? nil : activePlan.name),
            workoutTitle: status.workoutTitle,
            sessionTitle: status.sessionTitle,
            elapsedSeconds: elapsedSeconds,
            pausedSeconds: pausedSeconds,
            completedSets: status.completedSets,
            totalSets: status.totalSets,
            volumeKg: status.volumeKg,
            isPaused: status.isPaused,
            exerciseName: status.exerciseName,
            exerciseIndex: status.exerciseIndex,
            totalExercises: status.totalExercises,
            currentExerciseCompletedSets: status.currentExerciseCompletedSets,
            currentExerciseTotalSets: status.currentExerciseTotalSets,
            currentSetWeightKg: status.currentSetWeightKg,
            currentSetReps: status.currentSetReps,
            restSeconds: status.restSeconds,
            restDurationSeconds: status.restDurationSeconds,
            estimatedRemainingSeconds: status.estimatedRemainingSeconds,
            waterLiters: status.waterLiters ?? todayHealthMetric?.waterLiters,
            musicTitle: status.musicTitle,
            musicArtist: status.musicArtist,
            isMusicPlaying: status.isMusicPlaying,
            nextExerciseName: status.nextExerciseName,
            exerciseHistorySummary: status.exerciseHistorySummary,
            gymPassName: status.gymPassName ?? gymPasses.first?.gymName,
            gymMembershipID: status.gymMembershipID ?? gymPasses.first?.membershipID,
            gymCodeValue: status.gymCodeValue ?? gymPasses.first?.codeValue,
            gymCodeType: status.gymCodeType ?? gymPasses.first?.codeType.rawValue,
            heartRate: status.liveHeartRate ?? todayHealthMetric?.restingHeartRate,
            activeEnergyKcal: status.liveActiveEnergyKcal ?? todayHealthMetric?.activeEnergyKcal,
            isRouteWorkout: status.isRouteWorkout,
            isOutdoorRoute: status.isOutdoorRoute,
            routeDistanceKm: status.routeDistanceKm,
            routePaceSecondsPerKm: status.routePaceSecondsPerKm,
            routeSpeedKmh: status.routeSpeedKmh,
            routePointCount: status.routePointCount,
            routeSteps: status.routeSteps,
            summary: dailySummary,
            updatedAt: .now,
            streakDays: streak,
            weeklyCompletion: completion,
            trainingBatteryLevel: battery.level,
            trainingBatteryState: battery.state.rawValue,
            trainingBatteryTitle: battery.title,
            trainingBatterySuggestion: battery.suggestion,
            trainingBatterySystemImage: battery.systemImage,
            nextWorkoutDayName: activePlan.days.isEmpty ? nil : nextWorkout.title,
            nextWorkoutDayDescription: activePlan.days.isEmpty ? nil : nextWorkout.subtitle,
            widgetAccentColorName: userProfile.widgetAccentColorName,
            preferredLanguage: userProfile.preferredLanguage,
            exercisesData: status.isRouteWorkout ? nil : watchExercisesData(),
            estimatedMaxHeartRate: watchEstimatedMaxHeartRate
        )
    }

    func addPlan(_ plan: WorkoutPlan, activate: Bool) {
        plans.append(plan)
        TelemetryService.shared.log(.planCreated, parameters: [
            "activate": activate,
            "days_per_week": plan.daysPerWeek,
            "plan_days": plan.days.count,
            "location": plan.location.rawValue
        ])
        if activate {
            scheduledWorkouts.removeAll { $0.status == .scheduled }
            activePlan = plan
            generateSchedule(for: plan)
        }
    }

    func activatePlan(_ plan: WorkoutPlan) {
        // Save current activePlan progress to plans list first
        if let index = plans.firstIndex(where: { $0.id == activePlan.id }) {
            plans[index] = activePlan
        }
        activePlan = plan
        
        // Clear all non-completed scheduled workouts so they don't override the new plan
        scheduledWorkouts.removeAll { $0.status == .scheduled }
        
        if let index = plans.firstIndex(where: { $0.id == plan.id }) {
            plans[index] = plan
        }
        generateSchedule(for: plan)
        TelemetryService.shared.log(.planActivated, parameters: [
            "days_per_week": plan.daysPerWeek,
            "plan_days": plan.days.count,
            "location": plan.location.rawValue
        ])
    }

    func selectWorkoutDayForToday(_ day: WorkoutDay) {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)
        
        // 1. Remove all scheduled/incomplete workouts for today
        scheduledWorkouts.removeAll { calendar.isDate($0.date, inSameDayAs: today) }
        
        // 2. Add the selected day as scheduled for today
        let scheduled = ScheduledWorkout(date: Date(), workoutDay: day, status: .scheduled)
        scheduledWorkouts.append(scheduled)
        normalizeScheduledWorkouts()
        
        // 3. Align active plan's day index if this day is part of it
        if let index = activePlan.days.firstIndex(where: { $0.id == day.id }) {
            activePlan.activeDayIndex = index
            if let planIndex = plans.firstIndex(where: { $0.id == activePlan.id }) {
                plans[planIndex] = activePlan
            }
        }
        
        save()
    }

    func restoreSuggestedWorkoutForToday() {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)
        
        // Remove scheduled workouts for today
        scheduledWorkouts.removeAll { calendar.isDate($0.date, inSameDayAs: today) }
        
        // Re-generate schedule for today (meaning the active plan's current day will be scheduled)
        if !activePlan.days.isEmpty {
            let count = activePlan.days.count
            let index = ((activePlan.activeDayIndex % count) + count) % count
            let day = activePlan.days[index]
            let scheduled = ScheduledWorkout(date: Date(), workoutDay: day, status: .scheduled)
            scheduledWorkouts.append(scheduled)
        }

        normalizeScheduledWorkouts()
        
        save()
    }

    func updatePlan(_ plan: WorkoutPlan) {
        if let index = plans.firstIndex(where: { $0.id == plan.id }) {
            plans[index] = plan
        }

        if activePlan.id == plan.id {
            activePlan = plan
            generateSchedule(for: plan)
        }
    }

    func addWorkoutTemplate(_ workout: WorkoutDay) {
        workoutTemplates.append(workout)
    }

    func updateWorkoutTemplate(_ workout: WorkoutDay) {
        if let index = workoutTemplates.firstIndex(where: { $0.id == workout.id }) {
            workoutTemplates[index] = workout
        }

        for planIndex in plans.indices {
            if let dayIndex = plans[planIndex].days.firstIndex(where: { $0.id == workout.id }) {
                plans[planIndex].days[dayIndex] = workout
            }
        }

        if let dayIndex = activePlan.days.firstIndex(where: { $0.id == workout.id }) {
            activePlan.days[dayIndex] = workout
        }
    }

    func deleteWorkoutTemplate(_ workout: WorkoutDay) {
        workoutTemplates.removeAll { $0.id == workout.id }
    }

    func addWorkoutToActivePlan(_ workout: WorkoutDay) {
        var updated = activePlan
        updated.days.append(workout)
        updatePlan(updated)
    }

    func addExerciseToActivePlanDay(_ exercise: Exercise, dayID: WorkoutDay.ID, targetSets: Int, repRange: String) {
        var updated = activePlan
        guard let dayIndex = updated.days.firstIndex(where: { $0.id == dayID }) else {
            return
        }

        updated.days[dayIndex].exercises.append(
            WorkoutExercise(
                exercise: exercise,
                targetSets: targetSets,
                repRange: repRange,
                previous: "-"
            )
        )
        updatePlan(updated)
    }

    func scheduleSingleExercise(_ exercise: Exercise, date: Date, targetSets: Int, repRange: String) {
        let workout = WorkoutDay(
            title: exercise.name,
            subtitle: "technique_practice",
            durationMinutes: exercise.trackingType == .duration ? 20 : max(20, targetSets * 8),
            exercises: [
                WorkoutExercise(
                    exercise: exercise,
                    targetSets: targetSets,
                    repRange: repRange,
                    previous: "-"
                )
            ]
        )
        addScheduledWorkout(workout, date: date)
    }

    @discardableResult
    func executeCompetitiveAction(_ action: AnalyticsEngine.CompetitiveAction) -> AppTab? {
        switch action {
        case .scheduleUndertrainedMuscle(let muscleGroup):
            scheduleMuscleFocusSession(muscleGroup: muscleGroup)
            return .calendar
        case .scheduleDeloadExercise(let exerciseID):
            guard let exercise = exercises.first(where: { $0.id == exerciseID }) else {
                return .progress
            }
            scheduleDeloadSession(for: exercise)
            return .calendar
        case .reviewPlan:
            health.message = localizedString("review_plan_distribution_and_schedule_the_next_session_to_recover_adherence")
            return .plans
        case .scheduleRecovery:
            scheduleRecoverySession()
            return .calendar
        case .none:
            return nil
        }
    }

    private func scheduleMuscleFocusSession(muscleGroup: String) {
        let candidates = exercises
            .filter { $0.muscleGroup.localizedCaseInsensitiveCompare(muscleGroup) == .orderedSame }
            .sorted { lhs, rhs in
                let lhsAvailable = availableEquipmentMatches(lhs)
                let rhsAvailable = availableEquipmentMatches(rhs)
                if lhsAvailable == rhsAvailable {
                    return lhs.name < rhs.name
                }
                return lhsAvailable && !rhsAvailable
            }
        let selected = Array(candidates.prefix(3))
        guard !selected.isEmpty else {
            health.message = localizedFormat("muscle_focus_no_exercises_message", muscleGroup)
            return
        }

        let workout = WorkoutDay(
            title: localizedFormat("muscle_focus_workout_title", muscleGroup),
            subtitle: "guided_session_to_close_the_weekly_gap",
            durationMinutes: max(24, selected.count * 10),
            exercises: selected.map { exercise in
                WorkoutExercise(
                    exercise: exercise,
                    targetSets: 3,
                    repRange: exercise.trackingType == .duration ? "30-45 sec" : "10-15",
                    previous: "-",
                    restSeconds: 75,
                    priority: .accessory,
                    progressionType: .none
                )
            }
        )
        addScheduledWorkout(workout, date: nextRetentionActionDate())
        health.message = localizedFormat("muscle_focus_scheduled_tomorrow_message", muscleGroup)
        scheduleRetentionNudge(
            title: localizedFormat("muscle_focus_workout_title", muscleGroup),
            body: localizedKey("short_session_to_close_weekly_gap")
        )
    }

    private func scheduleDeloadSession(for exercise: Exercise) {
        let workout = WorkoutDay(
            title: "Descarga: \(exercise.name)",
            subtitle: "reduce_load_and_recover_progression",
            durationMinutes: 24,
            exercises: [
                WorkoutExercise(
                    exercise: exercise,
                    targetSets: 3,
                    repRange: exercise.trackingType == .duration ? "30 sec suave" : "6-8",
                    previous: "-",
                    restSeconds: 120,
                    priority: .primary,
                    progressionType: .rpeTarget,
                    targetRPE: 6
                )
            ]
        )
        addScheduledWorkout(workout, date: nextRetentionActionDate())
        health.message = localizedFormat("deload_exercise_scheduled_tomorrow_message", exercise.name)
        scheduleRetentionNudge(
            title: localizedKey("scheduled_deload"),
            body: localizedFormat("tomorrow_reduce_fatigue_and_progress_exercise", exercise.name)
        )
    }

    private func scheduleRecoverySession() {
        let mobilityExercises = exercises
            .filter { $0.exerciseType == .mobility || $0.exerciseType == .stretching }
            .prefix(4)
        let fallback = [
            Exercise(name: "Full Body Mobility Flow", muscleGroup: "Full Body", equipment: "Bodyweight", trackingType: .duration, exerciseType: .mobility),
            Exercise(name: "Hip Flexor Stretch", muscleGroup: "Legs", equipment: "Bodyweight", trackingType: .duration, exerciseType: .stretching)
        ]
        let selected = Array(mobilityExercises.isEmpty ? fallback.prefix(4) : mobilityExercises)
        let workout = WorkoutDay(
            title: "active_recovery",
            subtitle: "easy_mobility_to_absorb_volume",
            durationMinutes: 20,
            exercises: selected.map { exercise in
                WorkoutExercise(
                    exercise: exercise,
                    targetSets: 2,
                    repRange: "45-60 sec",
                    previous: "-",
                    restSeconds: 30,
                    priority: .accessory,
                    progressionType: .none
                )
            },
            sessionType: .mobility,
            restBetweenExercisesSeconds: 30
        )
        addScheduledWorkout(workout, date: nextRetentionActionDate())
        health.message = localizedString("active_recovery_scheduled_for_tomorrow")
        scheduleRetentionNudge(title: localizedKey("active_recovery"), body: localizedKey("gentle_session_for_next_workout"))
    }

    private func nextRetentionActionDate() -> Date {
        let calendar = Calendar.current
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: .now) ?? .now.addingTimeInterval(86_400)
        return calendar.date(bySettingHour: 10, minute: 0, second: 0, of: tomorrow) ?? tomorrow
    }

    private func availableEquipmentMatches(_ exercise: Exercise) -> Bool {
        let equipment = Set(userProfile.availableEquipment.map(Self.normalizedText))
        guard !equipment.isEmpty else {
            return true
        }

        let required = exercise.requiredEquipment.isEmpty ? [exercise.equipment] : exercise.requiredEquipment
        let normalizedRequired = Set(required.map(Self.normalizedText))
        return normalizedRequired.contains("bodyweight")
            || normalizedRequired.contains("body only")
            || !normalizedRequired.isDisjoint(with: equipment)
            || equipment.contains(Self.normalizedText(exercise.equipment))
    }

    private func scheduleRetentionNudge(title: String, body: String) {
        guard userProfile.remindersEnabled else {
            return
        }

        Task {
            try? await NotificationService.scheduleRetentionNudge(
                title: title,
                body: body,
                date: nextRetentionActionDate()
            )
        }
    }

    func deactivatePlan(_ plan: WorkoutPlan) {
        guard activePlan.id == plan.id else {
            return
        }

        if let replacement = plans.first(where: { $0.id != plan.id }) {
            activatePlan(replacement)
        } else {
            scheduledWorkouts.removeAll { $0.status == .scheduled }
        }
    }

    func deletePlan(_ plan: WorkoutPlan) {
        plans.removeAll { $0.id == plan.id }
        if activePlan.id == plan.id {
            activePlan = plans.first ?? .empty
        }
    }

    func addExercise(_ exercise: Exercise) {
        exercises.append(exercise)
    }

    func updateExercise(_ exercise: Exercise) {
        if let index = exercises.firstIndex(where: { $0.id == exercise.id }) {
            exercises[index] = exercise
        }

        for planIndex in plans.indices {
            for dayIndex in plans[planIndex].days.indices {
                for exerciseIndex in plans[planIndex].days[dayIndex].exercises.indices
                    where plans[planIndex].days[dayIndex].exercises[exerciseIndex].exercise.id == exercise.id {
                    plans[planIndex].days[dayIndex].exercises[exerciseIndex].exercise = exercise
                }
            }
        }

        for dayIndex in activePlan.days.indices {
            for exerciseIndex in activePlan.days[dayIndex].exercises.indices
                where activePlan.days[dayIndex].exercises[exerciseIndex].exercise.id == exercise.id {
                activePlan.days[dayIndex].exercises[exerciseIndex].exercise = exercise
            }
        }

        for templateIndex in workoutTemplates.indices {
            for exerciseIndex in workoutTemplates[templateIndex].exercises.indices
                where workoutTemplates[templateIndex].exercises[exerciseIndex].exercise.id == exercise.id {
                workoutTemplates[templateIndex].exercises[exerciseIndex].exercise = exercise
            }
        }
    }

    func syncOpenExerciseLibraryIfNeeded() async {
        guard !hasAttemptedExerciseLibrarySync else {
            return
        }

        hasAttemptedExerciseLibrarySync = true
        await syncOpenExerciseLibrary()
    }

    func syncOpenExerciseLibrary() async {
        guard !isSyncingExerciseLibrary else {
            return
        }

        isSyncingExerciseLibrary = true
        defer { isSyncingExerciseLibrary = false }

        do {
            let remoteExercises = try await OpenExerciseLibraryClient().fetchExercises()
            let mappedExercises = remoteExercises.compactMap(\.domainExercise)
            
            // Build key map for faster search and updates
            var existingExercisesByKey: [String: Int] = [:]
            for (index, exercise) in exercises.enumerated() {
                for key in exercise.libraryLookupKeys {
                    existingExercisesByKey[key] = index
                }
            }

            var mergedCount = 0
            var addedCount = 0

            for remoteExercise in mappedExercises {
                let key = remoteExercise.name.normalizedExerciseKey
                if let index = existingExercisesByKey[key] {
                    var modified = false
                    // If instructions or mediaURL are empty on existing (such as Seed exercises), complete them.
                    if exercises[index].mediaURL == nil || exercises[index].mediaURL?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == true {
                        exercises[index].mediaURL = remoteExercise.mediaURL
                        modified = true
                    }
                    if exercises[index].instructions == nil || exercises[index].instructions?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == true {
                        exercises[index].instructions = remoteExercise.instructions
                        modified = true
                    }
                    if exercises[index].videoURL == nil || exercises[index].videoURL?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == true {
                        exercises[index].videoURL = remoteExercise.videoURL
                        modified = true
                    }
                    if modified {
                        mergedCount += 1
                    }
                } else {
                    exercises.append(remoteExercise)
                    addedCount += 1
                    for lookupKey in remoteExercise.libraryLookupKeys {
                        existingExercisesByKey[lookupKey] = exercises.count - 1
                    }
                }
            }

            if addedCount == 0 && mergedCount == 0 {
                exerciseLibrarySyncMessage = localizedString("the_exercise_library_is_updated")
            } else {
                exerciseLibrarySyncMessage = localizedFormat("library_updated_counts_message", addedCount, mergedCount)
            }
        } catch {
            exerciseLibrarySyncMessage = localizedString("the_library_could_not_be_updated_the_offline_catalog_is_still_available")
            TelemetryService.shared.record(error, context: "exercise_library_sync")
            TelemetryService.shared.log(.nonFatalError, parameters: ["context": "exercise_library_sync"])
        }
    }

    func addScheduledWorkout(_ workoutDay: WorkoutDay, date: Date) {
        scheduledWorkouts.append(ScheduledWorkout(date: date, workoutDay: workoutDay, status: .scheduled))
        normalizeScheduledWorkouts()
        TelemetryService.shared.log(.workoutScheduled, parameters: [
            "session_type": workoutDay.sessionType.rawValue,
            "exercise_count": workoutDay.exercises.count,
            "has_active_plan": !activePlan.days.isEmpty,
            "scheduled_day_offset": Calendar.current.dateComponents(
                [.day],
                from: Calendar.current.startOfDay(for: .now),
                to: Calendar.current.startOfDay(for: date)
            ).day ?? 0
        ])
    }

    func addGoal(_ goal: Goal) {
        goals.append(goal)
        TelemetryService.shared.log(.goalCreated, parameters: [
            "kind": goal.kind.rawValue,
            "has_deadline": goal.deadline != nil
        ])
    }

    @discardableResult
    func createSuggestedPlanForAvailableEquipment() -> WorkoutPlan {
        sanitizeAvailableEquipment()
        let equipment = Set(userProfile.availableEquipment.map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() })
        let prefersHome = userProfile.trainingLocation == .home
            || equipment.contains("dumbbells")
            || equipment.contains("resistance band")
            || equipment.contains("bodyweight")
        let template = prefersHome ? SeedData.homeStrengthPlan : SeedData.pushPullLegsPlan
        var suggested = template
        suggested.id = UUID()
        suggested.name = prefersHome ? localizedKey("home_based_on_my_equipment") : localizedKey("recommended_gym")
        addPlan(suggested, activate: true)
        health.message = localizedFormat("routine_created_active_in_plans_message", suggested.name)
        return suggested
    }

    func disconnectHealth() {
        stopHealthKitObservers()
        health = HealthSyncState(
            isAvailable: health.isAvailable,
            isAuthorized: false,
            lastSyncDate: nil,
            message: "apple_health_offline_in_reps_you_can_revoke_permissions_in_the_health_app",
            latestDailyMetrics: []
        )
    }

    func exportBackupURL() throws -> URL {
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(currentSnapshot)
            let url = exportURL(fileName: "reps-backup-\(Self.exportDateStamp()).json")
            try writeProtected(data, to: url)
            TelemetryService.shared.log(.backupExported)
            return url
        } catch {
            TelemetryService.shared.record(error, context: "backup_export")
            TelemetryService.shared.log(.nonFatalError, parameters: ["context": "backup_export"])
            throw error
        }
    }

    func exportCSVURL() throws -> URL {
        do {
            let csv = CSVExporter(snapshot: currentSnapshot).makeCSV()
            let url = exportURL(fileName: "reps-export-\(Self.exportDateStamp()).csv")
            let data = Data(csv.utf8)
            try writeProtected(data, to: url)
            TelemetryService.shared.log(.csvExported)
            return url
        } catch {
            TelemetryService.shared.record(error, context: "csv_export")
            TelemetryService.shared.log(.nonFatalError, parameters: ["context": "csv_export"])
            throw error
        }
    }

    func importBackup(from url: URL) throws {
        do {
            let data = try Data(contentsOf: url)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let snapshot = try decoder.decode(AppSnapshot.self, from: data)
            restore(snapshot)
            TelemetryService.shared.log(.backupImported, parameters: [
                "plan_count": snapshot.plans.count,
                "session_count": snapshot.workoutSessions.count
            ])
        } catch {
            TelemetryService.shared.record(error, context: "backup_import")
            TelemetryService.shared.log(.nonFatalError, parameters: ["context": "backup_import"])
            throw error
        }
    }

    func importCSV(from url: URL) throws {
        do {
            let csv = try String(contentsOf: url, encoding: .utf8)
            let importer = CSVImporter(csv: csv)
            let importedCardio = importer.cardioLogs()
            let importedBody = importer.bodyMetrics()
            if !importedCardio.isEmpty {
                _ = importCardioLogs(importedCardio)
            }
            if !importedBody.isEmpty {
                bodyMetrics.append(contentsOf: importedBody)
            }
            TelemetryService.shared.log(.csvImported, parameters: [
                "cardio_count": importedCardio.count,
                "body_metric_count": importedBody.count
            ])
        } catch {
            TelemetryService.shared.record(error, context: "csv_import")
            TelemetryService.shared.log(.nonFatalError, parameters: ["context": "csv_import"])
            throw error
        }
    }

    func exportWorkoutShareImageURL(session: WorkoutSession? = nil) throws -> URL {
        let selected = session ?? workoutSessions.sorted { $0.date > $1.date }.first
        let url = exportURL(fileName: "reps-share-\(Self.exportDateStamp()).png")
        let image = shareImageRenderer(selected)
        guard let data = image.pngData(), !data.isEmpty else {
            throw CocoaError(.fileWriteUnknown)
        }
        try writeProtected(data, to: url)
        return url
    }

    func resetAllData() {
        restore(.empty)
        userProfile.onboardingCompleted = false
        TelemetryService.shared.log(.allDataReset)
    }

    private func generateSchedule(for plan: WorkoutPlan) {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)
        let days = plan.days.isEmpty ? [SeedData.pushDay] : plan.days
        let count = min(plan.daysPerWeek, max(days.count, 1))
        let startDayIndex = plan.activeDayIndex

        let generated = (0..<count).compactMap { offset -> ScheduledWorkout? in
            guard let date = calendar.date(byAdding: .day, value: offset * 2, to: today) else {
                return nil
            }
            let dayIndex = (startDayIndex + offset) % days.count
            return ScheduledWorkout(date: date, workoutDay: days[dayIndex], status: .scheduled)
        }

        scheduledWorkouts = scheduledWorkouts.filter { !calendar.isDate($0.date, equalTo: today, toGranularity: .weekOfYear) || $0.status == .completed }
        scheduledWorkouts.append(contentsOf: generated)
        normalizeScheduledWorkouts()
    }

    private func reconcileNotificationStateIfNeeded() {
        guard !isRestoring else {
            return
        }

        let remindersEnabled = userProfile.remindersEnabled
        let scheduled = scheduledWorkouts

        Task {
            let settings = await UNUserNotificationCenter.current().notificationSettings()
            let isAuthorized = settings.authorizationStatus == .authorized

            if !remindersEnabled || !isAuthorized {
                NotificationService.clearWorkoutReminders()
                return
            }

            await NotificationService.reconcileScheduledReminders(
                for: scheduled,
                includeDailySummary: true
            )
        }
    }

    private func normalizeScheduledWorkouts() {
        let normalized = Self.normalizedScheduledWorkouts(scheduledWorkouts)
        guard normalized.count != scheduledWorkouts.count else {
            return
        }

        scheduledWorkouts = normalized
    }

    private static func normalizedScheduledWorkouts(_ workouts: [ScheduledWorkout]) -> [ScheduledWorkout] {
        let calendar = Calendar.current
        var seen = Set<String>()

        return workouts
            .sorted { $0.date < $1.date }
            .filter { workout in
                let day = calendar.dateComponents([.year, .month, .day], from: workout.date)
                let dayKey = "\(day.year ?? 0)-\(day.month ?? 0)-\(day.day ?? 0)"
                let workoutKey = "\(dayKey)-\(workout.workoutDay.id.uuidString)-\(workout.status.rawValue)"
                return seen.insert(workoutKey).inserted
            }
    }

    private static func normalizedText(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines)
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
            .lowercased()
    }

    private func save(reloadWidgetTimelines: Bool = true, scope: PersistenceScope? = nil) {
        guard !isRestoring else {
            return
        }

        if let scope {
            pendingSaveScopes.insert(scope)
        } else {
            pendingSaveScopes = PersistenceScope.all
        }
        pendingWidgetTimelineReload = pendingWidgetTimelineReload || reloadWidgetTimelines

        saveTask?.cancel()
        saveTask = Task {
            try? await Task.sleep(nanoseconds: 500_000_000) // 500ms debounce
            guard !Task.isCancelled else { return }
            commitPendingSave()
        }
    }

    /// Writes any debounced changes to disk immediately. Called when the app
    /// resigns active so a suspension/termination inside the debounce window
    /// cannot drop the user's latest data.
    func flushPendingSave() {
        guard !pendingSaveScopes.isEmpty else { return }
        saveTask?.cancel()
        saveTask = nil
        commitPendingSave()
    }

    private func commitPendingSave() {
        let scopes = pendingSaveScopes
        let reloadTimelines = pendingWidgetTimelineReload
        pendingSaveScopes = []
        pendingWidgetTimelineReload = false
        guard !scopes.isEmpty else { return }

        persistence.save(currentSnapshot, scopes: scopes)

        // Keep shared widgets & watch in sync with data mutations
        let snapshot = sharedWorkoutSnapshot()
        SharedWorkoutStore.save(snapshot, reloadTimelines: reloadTimelines)
        WatchSyncService.shared.publish(snapshot: snapshot)
    }

    private func shouldReloadWidgetTimelines(
        from previous: ActiveWorkoutStatus?,
        to current: ActiveWorkoutStatus?
    ) -> Bool {
        switch (previous, current) {
        case (nil, nil):
            return false
        case (nil, _), (_, nil):
            return true
        case let (previous?, current?):
            return previous.workoutTitle != current.workoutTitle
                || previous.sessionTitle != current.sessionTitle
                || previous.completedSets != current.completedSets
                || previous.totalSets != current.totalSets
                || previous.volumeKg != current.volumeKg
                || previous.isPaused != current.isPaused
                || previous.exerciseName != current.exerciseName
                || previous.exerciseIndex != current.exerciseIndex
                || previous.totalExercises != current.totalExercises
                || previous.currentExerciseCompletedSets != current.currentExerciseCompletedSets
                || previous.currentExerciseTotalSets != current.currentExerciseTotalSets
                || previous.currentSetWeightKg != current.currentSetWeightKg
                || previous.currentSetReps != current.currentSetReps
                || (previous.restSeconds ?? 0 > 0) != (current.restSeconds ?? 0 > 0)
                || previous.restDurationSeconds != current.restDurationSeconds
                || previous.waterLiters != current.waterLiters
                || previous.musicTitle != current.musicTitle
                || previous.musicArtist != current.musicArtist
                || previous.isMusicPlaying != current.isMusicPlaying
                || previous.nextExerciseName != current.nextExerciseName
                || previous.exerciseHistorySummary != current.exerciseHistorySummary
                || previous.gymPassName != current.gymPassName
                || previous.gymMembershipID != current.gymMembershipID
                || previous.gymCodeValue != current.gymCodeValue
                || previous.gymCodeType != current.gymCodeType
        }
    }

    private func exportURL(fileName: String) -> URL {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("RepsExports", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory.appendingPathComponent(fileName)
    }

    private func writeProtected(_ data: Data, to url: URL) throws {
        try data.write(to: url, options: [.atomic, .completeFileProtection])
    }

    private static func exportDateStamp() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd-HHmm"
        return formatter.string(from: .now)
    }

    private static var isRunningUnitTests: Bool {
        ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
    }

    private var currentSnapshot: AppSnapshot {
        AppSnapshot(
            userProfile: userProfile,
            monetization: monetization,
            activePlan: activePlan,
            plans: plans,
            workoutTemplates: workoutTemplates,
            exercises: exercises,
            scheduledWorkouts: scheduledWorkouts,
            workoutSessions: workoutSessions,
            cardioLogs: cardioLogs,
            bodyMetrics: bodyMetrics,
            progressPhotos: progressPhotos,
            gymPasses: gymPasses,
            gymVisits: gymVisits,
            goals: goals,
            health: health,
            activeWorkout: activeWorkout,
            activeWorkoutDrafts: activeWorkoutDrafts,
            activeWorkoutStatus: activeWorkoutStatus,
            savedShareCards: savedShareCards
        )
    }

    func sanitizeAvailableEquipment() {
        let mapped = userProfile.availableEquipment.map { eq in
            switch eq.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
            case "barra", "barbell": return "Barbell"
            case "mancuernas", "mancuerna", "dumbbell", "dumbbells": return "Dumbbells"
            case "kettlebell", "kettlebells", "pesa rusa": return "Kettlebell"
            case "bandas", "banda", "resistance band": return "Resistance Band"
            case "poleas", "polea", "cable": return "Cable"
            case "maquinas", "maquina", "máquinas", "máquina", "machine", "machines": return "Machine"
            case "banco", "bench": return "Bench"
            case "rack": return "Rack"
            case "dominadas", "pullup bar": return "Pullup Bar"
            case "cardio", "cardio machine": return "Cardio Machine"
            default: return eq
            }
        }
        let unique = Array(Set(mapped)).sorted()
        if unique != userProfile.availableEquipment {
            userProfile.availableEquipment = unique
        }
    }

    private func restore(_ snapshot: AppSnapshot) {
        isRestoring = true
        userProfile = snapshot.userProfile
        monetization = snapshot.monetization
        activePlan = snapshot.activePlan
        plans = mergeSeedPlans(into: snapshot.plans)
        workoutTemplates = mergeSeedWorkouts(into: snapshot.workoutTemplates.isEmpty ? snapshot.activePlan.days : snapshot.workoutTemplates)
        exercises = mergeSeedExercises(into: snapshot.exercises.isEmpty ? SeedData.exercises : snapshot.exercises)
        scheduledWorkouts = Self.normalizedScheduledWorkouts(snapshot.scheduledWorkouts)
        workoutSessions = snapshot.workoutSessions
        cardioLogs = snapshot.cardioLogs
        bodyMetrics = snapshot.bodyMetrics
        progressPhotos = snapshot.progressPhotos
        gymPasses = snapshot.gymPasses
        gymVisits = snapshot.gymVisits
        goals = snapshot.goals
        health = snapshot.health
        activeWorkout = snapshot.activeWorkout
        activeWorkoutDrafts = snapshot.activeWorkoutDrafts ?? []
        activeWorkoutStatus = snapshot.activeWorkoutStatus
        savedShareCards = snapshot.savedShareCards
        
        sanitizeAvailableEquipment()
        
        isRestoring = false
        persistence.save(currentSnapshot)
        
        // Keep shared widgets & watch in sync after database restore
        let widgetSnapshot = sharedWorkoutSnapshot()
        SharedWorkoutStore.save(widgetSnapshot)
        WatchSyncService.shared.publish(snapshot: widgetSnapshot)
    }
    
    // MARK: - HealthKit Synchronization & Background Observers
    
    private let healthStore = HKHealthStore()
    private var healthKitWorkoutObserverStarted = false
    private var healthKitDailyMetricsObserverStarted = false
    private var healthKitWorkoutObserverQuery: HKObserverQuery?
    private var healthKitDailyMetricObserverQueries: [HKObserverQuery] = []
    private static let automaticHealthSyncMinimumInterval: TimeInterval = 10 * 60
    private static var observedDailyHealthSampleTypes: [HKSampleType] {
        [
            HKQuantityType(.stepCount),
            HKQuantityType(.activeEnergyBurned),
            HKQuantityType(.distanceWalkingRunning),
            HKQuantityType(.appleExerciseTime),
            HKQuantityType(.dietaryEnergyConsumed),
            HKQuantityType(.dietaryWater),
            HKQuantityType(.restingHeartRate),
            HKQuantityType(.heartRateVariabilitySDNN),
            HKCategoryType(.sleepAnalysis)
        ]
    }
    
    func startHealthKitWorkoutObserverIfAuthorized() {
        health.isAvailable = HKHealthStore.isHealthDataAvailable()
        guard HKHealthStore.isHealthDataAvailable() else { return }
        guard health.isAuthorized else { return }
        startHealthKitDailyMetricsObserverIfAuthorized()
        guard !healthKitWorkoutObserverStarted else { return }
        
        let workoutType = HKWorkoutType.workoutType()
        guard healthStore.authorizationStatus(for: workoutType) != .notDetermined else { return }

        let query = HKObserverQuery(sampleType: workoutType, predicate: nil) { [weak self] _, completionHandler, error in
            if let error = error {
                print("Error de observador de HealthKit: \(error.localizedDescription)")
                completionHandler()
                return
            }
            
            struct SendableWorkoutCompletion: @unchecked Sendable {
                let handler: () -> Void
            }
            let wrapped = SendableWorkoutCompletion(handler: completionHandler)
            
            Task {
                if let self = self {
                    await self.syncWorkoutsFromHealthKit()
                }
                wrapped.handler()
            }
        }
        healthStore.execute(query)
        healthKitWorkoutObserverQuery = query
        healthKitWorkoutObserverStarted = true
        
        // Habilitar envío en segundo plano
        healthStore.enableBackgroundDelivery(for: workoutType, frequency: .immediate) { success, error in
            if let error = error {
                print("No se pudo habilitar el envío en segundo plano de HealthKit: \(error.localizedDescription)")
                Task { @MainActor in
                    TelemetryService.shared.record(error, context: "healthkit_enable_background_delivery")
                }
            }
        }
    }

    func refreshHealthKitDataIfNeeded(force: Bool = false, reason: String = "foreground") {
        Task { @MainActor [weak self] in
            await self?.performAutomaticHealthSyncIfNeeded(force: force, reason: reason)
        }
    }

    private func startHealthKitDailyMetricsObserverIfAuthorized() {
        guard HKHealthStore.isHealthDataAvailable(), health.isAuthorized else { return }
        guard !healthKitDailyMetricsObserverStarted else { return }

        for sampleType in Self.observedDailyHealthSampleTypes {
            let query = HKObserverQuery(sampleType: sampleType, predicate: nil) { [weak self] _, completionHandler, error in
                struct SendableHealthCompletion: @unchecked Sendable {
                    let handler: () -> Void
                }

                let wrapped = SendableHealthCompletion(handler: completionHandler)

                Task { @MainActor in
                    defer { wrapped.handler() }

                    if let error {
                        TelemetryService.shared.record(error, context: "healthkit_daily_metric_observer")
                        return
                    }

                    guard let self else { return }
                    await self.performAutomaticHealthSyncIfNeeded(reason: "background_metric_observer")
                }
            }

            healthStore.execute(query)
            healthKitDailyMetricObserverQueries.append(query)
            healthStore.enableBackgroundDelivery(for: sampleType, frequency: .hourly) { _, error in
                if let error {
                    Task { @MainActor in
                        TelemetryService.shared.record(error, context: "healthkit_daily_background_delivery")
                    }
                }
            }
        }

        healthKitDailyMetricsObserverStarted = true
    }

    private func stopHealthKitObservers() {
        if let healthKitWorkoutObserverQuery {
            healthStore.stop(healthKitWorkoutObserverQuery)
        }
        for query in healthKitDailyMetricObserverQueries {
            healthStore.stop(query)
        }

        healthKitWorkoutObserverQuery = nil
        healthKitDailyMetricObserverQueries = []
        healthKitWorkoutObserverStarted = false
        healthKitDailyMetricsObserverStarted = false
        isAutomaticHealthSyncInProgress = false
        lastAutomaticHealthRefreshDate = nil

        guard HKHealthStore.isHealthDataAvailable() else { return }
        healthStore.disableBackgroundDelivery(for: HKWorkoutType.workoutType()) { _, error in
            if let error {
                Task { @MainActor in
                    TelemetryService.shared.record(error, context: "healthkit_disable_workout_background_delivery")
                }
            }
        }
        for sampleType in Self.observedDailyHealthSampleTypes {
            healthStore.disableBackgroundDelivery(for: sampleType) { _, error in
                if let error {
                    Task { @MainActor in
                        TelemetryService.shared.record(error, context: "healthkit_disable_daily_background_delivery")
                    }
                }
            }
        }
    }

    private func performAutomaticHealthSyncIfNeeded(force: Bool = false, reason: String) async {
        health.isAvailable = HKHealthStore.isHealthDataAvailable()
        guard health.isAvailable, health.isAuthorized else { return }
        startHealthKitWorkoutObserverIfAuthorized()
        guard !isAutomaticHealthSyncInProgress else { return }

        let now = Date()
        let mostRecentRefresh = lastAutomaticHealthRefreshDate ?? health.lastSyncDate
        if !force,
           let mostRecentRefresh,
           now.timeIntervalSince(mostRecentRefresh) < Self.automaticHealthSyncMinimumInterval {
            return
        }

        isAutomaticHealthSyncInProgress = true
        lastAutomaticHealthRefreshDate = now
        defer { isAutomaticHealthSyncInProgress = false }

        do {
            let dailyMetrics = try await healthKitService.fetchDailyMetrics()
            health.latestDailyMetrics = dailyMetrics
            health.lastSyncDate = .now
            await syncWorkoutsFromHealthKit()
        } catch {
            TelemetryService.shared.record(error, context: "healthkit_automatic_sync_\(reason)")
            TelemetryService.shared.log(.nonFatalError, parameters: ["context": "healthkit_automatic_sync"])
        }
    }
    
    func syncWorkoutsFromHealthKit() async {
        guard HKHealthStore.isHealthDataAvailable() else { return }
        
        let calendar = Calendar.current
        let startDate = calendar.date(byAdding: .day, value: -7, to: .now) ?? .now
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: .now)
        
        let descriptor = HKSampleQueryDescriptor(
            predicates: [.workout(predicate)],
            sortDescriptors: [SortDescriptor(\.endDate, order: .reverse)],
            limit: 30
        )
        
        do {
            let workouts = try await descriptor.result(for: healthStore)
            for workout in workouts {
                await processHealthKitWorkout(workout)
            }
        } catch {
            print("Error al consultar entrenamientos de HealthKit: \(error.localizedDescription)")
            TelemetryService.shared.record(error, context: "healthkit_sync_workouts")
            TelemetryService.shared.log(.nonFatalError, parameters: ["context": "healthkit_sync_workouts"])
        }
    }
    
    private func processHealthKitWorkout(_ workout: HKWorkout) async {
        let uuidString = workout.uuid.uuidString
        
        // 1. Avoid duplicates, but still refresh routes because HealthKit can publish
        // the workout before its HKWorkoutRoute samples are available.
        if workoutSessions.contains(where: { $0.healthKitUUIDString == uuidString }) {
            await refreshExistingHealthKitRouteIfNeeded(for: workout, uuidString: uuidString)
            return
        }
        
        // Obtener datos del pulso
        let heartRate = await heartRateSummary(for: workout)
        let routePoints = await workoutRoutePoints(for: workout)
        let distanceKm = workout.totalDistance?.doubleValue(for: .meterUnit(with: .kilo))
        let averagePaceSecondsPerKm = Self.averagePaceSecondsPerKm(duration: workout.duration, distanceKm: distanceKm)
        let steps = await workoutQuantitySum(for: workout, type: HKQuantityType(.stepCount), unit: .count())
        
        // Obtener actividades
        var activities: [String] = []
        if #available(iOS 16.0, *) {
            for activity in workout.workoutActivities {
                activities.append(Self.nameForActivityType(activity.workoutConfiguration.activityType))
            }
        }
        if activities.isEmpty {
            activities.append(Self.nameForActivityType(workout.workoutActivityType))
        }
        let uniqueActivities = Array(Set(activities)).sorted()
        
        let calories = workout.totalEnergyBurned?.doubleValue(for: .kilocalorie())
        let sessionLocation = Self.location(for: workout)
        
        // 2. Comprobar si hay un entrenamiento en progreso coincidente para finalizar o mezclar
        if let activeStatus = activeWorkoutStatus,
           abs(activeStatus.startedAt.timeIntervalSince(workout.startDate)) < 5400 { // Margen de 1.5 horas
            
            // Compilar sesión activa
            let logs = activeWorkoutDrafts.compactMap { draft -> ExerciseLog? in
                let completedSets = draft.sets.filter(\.completed)
                guard !completedSets.isEmpty else { return nil }
                return ExerciseLog(
                    exercise: draft.workoutExercise.exercise,
                    notes: draft.notes,
                    sets: completedSets,
                    mediaAttachments: draft.mediaAttachments
                )
            }
            
            let allSets = logs.flatMap(\.sets)
            let durationMin = max(Int(workout.duration / 60), 1)
            let activeIsOutdoorRoute = activeStatus.isOutdoorRoute ?? !routePoints.isEmpty
            
            let mergedSession = WorkoutSession(
                workoutTitle: activeStatus.workoutTitle,
                date: workout.endDate,
                startedAt: workout.startDate,
                endedAt: workout.endDate,
                origin: activeWorkout?.sessionType == .free ? .free : .routine,
                location: activeIsOutdoorRoute ? .outdoor : (activeWorkout?.sessionType == .free ? (userProfile.trainingLocation == .home ? .home : .gym) : (activePlan.location == .home ? .home : .gym)),
                contextTag: .normal,
                durationMinutes: durationMin,
                sets: allSets,
                notes: localizedString("synced_and_enriched_with_apple_health"),
                exerciseLogs: logs,
                sessionRPE: 7.0,
                energyBefore: 3,
                energyAfter: 3,
                estimatedCalories: calories,
                mediaAttachments: [],
                routePoints: routePoints,
                pausedDurationSeconds: activeStatus.pausedSeconds,
                distanceKm: Self.bestRouteDistance(activeStatus.routeDistanceKm, distanceKm),
                averagePaceSecondsPerKm: activeStatus.routePaceSecondsPerKm ?? averagePaceSecondsPerKm,
                steps: Self.bestRouteMetric(activeStatus.routeSteps, steps),
                activeEnergyKcal: calories,
                healthKitUUIDString: uuidString,
                isImportedFromHealth: false,
                healthKitActivityTypes: uniqueActivities,
                averageHeartRate: heartRate.average,
                maxHeartRate: heartRate.max
            )
            
            finishWorkout(mergedSession)
            return
        }
        
        // 3. Comprobar solapamiento con sesiones guardadas existentes para enriquecerlas
        if let index = workoutSessions.firstIndex(where: {
            abs($0.date.timeIntervalSince(workout.endDate)) < 3600 && $0.healthKitUUIDString == nil
        }) {
            var existing = workoutSessions[index]
            existing.healthKitUUIDString = uuidString
            existing.estimatedCalories = calories ?? existing.estimatedCalories
            existing.averageHeartRate = heartRate.average
            existing.maxHeartRate = heartRate.max
            existing.healthKitActivityTypes = uniqueActivities
            existing.routePoints = existing.routePoints.isEmpty ? routePoints : existing.routePoints
            existing.distanceKm = Self.bestRouteDistance(existing.distanceKm, distanceKm)
            existing.averagePaceSecondsPerKm = existing.averagePaceSecondsPerKm ?? averagePaceSecondsPerKm
            existing.steps = Self.bestRouteMetric(existing.steps, steps)
            existing.activeEnergyKcal = Self.bestRouteMetric(existing.activeEnergyKcal, calories)
            if existing.isOutdoorRouteSession || !routePoints.isEmpty {
                existing.location = .outdoor
            }
            workoutSessions[index] = existing
            if existing.isRouteSession {
                saveReceiptCard(for: existing, replacingExisting: true)
            }
            return
        }
        
        // 4. Si no coincide con nada, importar de forma automática e independiente
        let importedTitle = uniqueActivities.joined(separator: " + ")
        let importedSession = WorkoutSession(
            workoutTitle: importedTitle.isEmpty ? "Entrenamiento Apple Health" : importedTitle,
            date: workout.endDate,
            startedAt: workout.startDate,
            endedAt: workout.endDate,
            origin: .free,
            location: sessionLocation,
            contextTag: .normal,
            durationMinutes: max(Int(workout.duration / 60), 1),
            sets: [],
            notes: localizedString("automatically_imported_from_apple_health"),
            exerciseLogs: [],
            sessionRPE: nil,
            energyBefore: nil,
            energyAfter: nil,
            estimatedCalories: calories,
            mediaAttachments: [],
            routePoints: routePoints,
            pausedDurationSeconds: 0,
            distanceKm: distanceKm,
            averagePaceSecondsPerKm: averagePaceSecondsPerKm,
            steps: steps,
            activeEnergyKcal: calories,
            healthKitUUIDString: uuidString,
            isImportedFromHealth: true,
            healthKitActivityTypes: uniqueActivities,
            averageHeartRate: heartRate.average,
            maxHeartRate: heartRate.max
        )
        
        workoutSessions.append(importedSession)
        
        // También generar recibo para la galería de este entreno importado de salud
        saveReceiptCard(for: importedSession)
    }

    private func refreshExistingHealthKitRouteIfNeeded(for workout: HKWorkout, uuidString: String) async {
        guard let existing = workoutSessions.first(where: { $0.healthKitUUIDString == uuidString }) else {
            return
        }
        if existing.routePoints.count >= 2 {
            saveReceiptCard(for: existing, replacingExisting: true)
            return
        }

        let routePoints = await workoutRoutePoints(for: workout)
        guard !routePoints.isEmpty,
              let index = workoutSessions.firstIndex(where: { $0.healthKitUUIDString == uuidString }) else {
            return
        }

        var updated = workoutSessions[index]
        updated.routePoints = routePoints
        updated.location = .outdoor
        updated.distanceKm = Self.bestRouteDistance(
            updated.distanceKm,
            workout.totalDistance?.doubleValue(for: .meterUnit(with: .kilo))
        )
        updated.averagePaceSecondsPerKm = updated.averagePaceSecondsPerKm ?? Self.averagePaceSecondsPerKm(
            duration: workout.duration,
            distanceKm: updated.distanceKm
        )
        workoutSessions[index] = updated
        saveReceiptCard(for: updated, replacingExisting: true)
    }
    
    private func heartRateSummary(for workout: HKWorkout) async -> (average: Double?, max: Double?) {
        let heartRateType = HKQuantityType(.heartRate)
        let predicate = HKQuery.predicateForObjects(from: workout)
        let samplePredicate = HKSamplePredicate.quantitySample(type: heartRateType, predicate: predicate)
        let descriptor = HKStatisticsQueryDescriptor(
            predicate: samplePredicate,
            options: [.discreteAverage, .discreteMax]
        )
        
        do {
            let statistics = try await descriptor.result(for: healthStore)
            let unit = HKUnit.count().unitDivided(by: .minute())
            return (
                statistics?.averageQuantity()?.doubleValue(for: unit),
                statistics?.maximumQuantity()?.doubleValue(for: unit)
            )
        } catch {
            return (nil, nil)
        }
    }

    private func workoutQuantitySum(for workout: HKWorkout, type: HKQuantityType, unit: HKUnit) async -> Double? {
        let predicate = HKQuery.predicateForObjects(from: workout)
        let samplePredicate = HKSamplePredicate.quantitySample(type: type, predicate: predicate)
        let descriptor = HKStatisticsQueryDescriptor(predicate: samplePredicate, options: .cumulativeSum)

        do {
            let statistics = try await descriptor.result(for: healthStore)
            let value = statistics?.sumQuantity()?.doubleValue(for: unit)
            guard let value, value > 0 else { return nil }
            return value
        } catch {
            return nil
        }
    }

    private func workoutRoutePoints(for workout: HKWorkout) async -> [RoutePoint] {
        let routeType = HKSeriesType.workoutRoute()
        let predicate = HKQuery.predicateForObjects(from: workout)

        let routes: [HKWorkoutRoute] = await withCheckedContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: routeType,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: nil
            ) { _, samples, _ in
                continuation.resume(returning: samples as? [HKWorkoutRoute] ?? [])
            }
            healthStore.execute(query)
        }

        var routePoints: [RoutePoint] = []
        for route in routes {
            let locations = await locations(for: route)
            routePoints.append(contentsOf: locations.map { location in
                RoutePoint(
                    latitude: location.coordinate.latitude,
                    longitude: location.coordinate.longitude,
                    altitude: location.altitude,
                    horizontalAccuracy: location.horizontalAccuracy,
                    timestamp: location.timestamp
                )
            })
        }

        let sorted = routePoints.sorted { $0.timestamp < $1.timestamp }
        return await enrichRoutePoints(sorted, for: workout)
    }

    /// Aligns per-point heart-rate and cadence samples to the route's GPS points.
    private func enrichRoutePoints(_ points: [RoutePoint], for workout: HKWorkout) async -> [RoutePoint] {
        guard !points.isEmpty else { return points }

        let heartRates = await heartRateSamples(for: workout)
        let cadences = await cadenceSamples(for: workout)
        guard !heartRates.isEmpty || !cadences.isEmpty else { return points }

        return points.map { point in
            var enriched = point
            enriched.heartRate = Self.nearestValue(in: heartRates, to: point.timestamp, tolerance: 30)
            enriched.cadenceSpm = Self.cadenceValue(in: cadences, at: point.timestamp)
            return enriched
        }
    }

    /// Discrete heart-rate samples (date, bpm) for the workout, sorted by time.
    private func heartRateSamples(for workout: HKWorkout) async -> [(date: Date, value: Double)] {
        let type = HKQuantityType(.heartRate)
        let predicate = HKQuery.predicateForObjects(from: workout)
        let unit = HKUnit.count().unitDivided(by: .minute())
        let samples: [HKQuantitySample] = await withCheckedContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: type,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)]
            ) { _, samples, _ in
                continuation.resume(returning: samples as? [HKQuantitySample] ?? [])
            }
            healthStore.execute(query)
        }
        return samples.map { sample in
            let mid = sample.startDate.addingTimeInterval(sample.endDate.timeIntervalSince(sample.startDate) / 2)
            return (mid, sample.quantity.doubleValue(for: unit))
        }
    }

    /// Step-count samples mapped to cadence (steps/min) over each sample's interval.
    private func cadenceSamples(for workout: HKWorkout) async -> [(start: Date, end: Date, value: Double)] {
        let type = HKQuantityType(.stepCount)
        let predicate = HKQuery.predicateForObjects(from: workout)
        let samples: [HKQuantitySample] = await withCheckedContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: type,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)]
            ) { _, samples, _ in
                continuation.resume(returning: samples as? [HKQuantitySample] ?? [])
            }
            healthStore.execute(query)
        }
        return samples.compactMap { sample in
            let duration = sample.endDate.timeIntervalSince(sample.startDate)
            guard duration > 0 else { return nil }
            let steps = sample.quantity.doubleValue(for: .count())
            let spm = steps / (duration / 60.0)
            guard spm > 0, spm < 400 else { return nil }
            return (sample.startDate, sample.endDate, spm)
        }
    }

    /// Nearest sample value to `target`, within `tolerance` seconds; samples sorted by date.
    private static func nearestValue(
        in samples: [(date: Date, value: Double)],
        to target: Date,
        tolerance: TimeInterval
    ) -> Double? {
        guard !samples.isEmpty else { return nil }
        var best: (gap: TimeInterval, value: Double)?
        for sample in samples {
            let gap = abs(sample.date.timeIntervalSince(target))
            if best == nil || gap < best!.gap {
                best = (gap, sample.value)
            } else if sample.date > target {
                break // sorted: gaps only grow once we pass the target
            }
        }
        guard let best, best.gap <= tolerance else { return nil }
        return best.value
    }

    /// Cadence covering `target` (interval containing it, else nearest by start).
    private static func cadenceValue(
        in samples: [(start: Date, end: Date, value: Double)],
        at target: Date
    ) -> Double? {
        guard !samples.isEmpty else { return nil }
        if let containing = samples.first(where: { $0.start <= target && target <= $0.end }) {
            return containing.value
        }
        return samples.min { abs($0.start.timeIntervalSince(target)) < abs($1.start.timeIntervalSince(target)) }?.value
    }

    private func locations(for route: HKWorkoutRoute) async -> [CLLocation] {
        await withCheckedContinuation { continuation in
            let accumulator = RouteLocationAccumulator()
            let query = HKWorkoutRouteQuery(route: route) { _, batch, done, _ in
                accumulator.append(contentsOf: batch ?? [])
                if done {
                    continuation.resume(returning: accumulator.snapshot())
                }
            }
            healthStore.execute(query)
        }
    }

    private static func averagePaceSecondsPerKm(duration: TimeInterval, distanceKm: Double?) -> Double? {
        guard let distanceKm, distanceKm > 0.02 else {
            return nil
        }
        return duration / distanceKm
    }

    private static func location(for workout: HKWorkout) -> WorkoutSession.Location {
        if workout.metadata?[HKMetadataKeyIndoorWorkout] as? Bool == true {
            return .gym
        }
        if !workout.workoutActivities.isEmpty {
            let hasOutdoorActivity = workout.workoutActivities.contains { activity in
                activity.workoutConfiguration.locationType == .outdoor
            }
            let hasIndoorActivity = workout.workoutActivities.contains { activity in
                activity.workoutConfiguration.locationType == .indoor
            }
            if hasOutdoorActivity {
                return .outdoor
            }
            if hasIndoorActivity {
                return .gym
            }
        }

        switch workout.workoutActivityType {
        case .walking, .running, .cycling, .hiking, .swimming:
            return .outdoor
        default:
            return .gym
        }
    }

    private static func location(for activityType: HKWorkoutActivityType) -> WorkoutSession.Location {
        switch activityType {
        case .walking, .running, .cycling, .hiking, .swimming:
            return .outdoor
        default:
            return .gym
        }
    }
    
    static func nameForActivityType(_ type: HKWorkoutActivityType) -> String {
        switch type {
        case .traditionalStrengthTraining: return "Fuerza tradicional"
        case .functionalStrengthTraining: return "Fuerza funcional"
        case .coreTraining: return "Core / Abdomen"
        case .swimming: return "Natación"
        case .running: return "Carrera"
        case .walking: return "Caminata"
        case .cycling: return "Ciclismo"
        case .yoga: return "Yoga"
        case .pilates: return "Pilates"
        case .highIntensityIntervalTraining: return "HIIT"
        case .flexibility: return "Estiramiento / Flexibilidad"
        case .crossTraining: return "CrossFit"
        case .cardioDance: return "Baile"
        case .elliptical: return "Elíptica"
        case .rowing: return "Remo"
        default: return "Otro deporte"
        }
    }

    private static func loadLegacySnapshot() -> AppSnapshot? {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        let url = appSupport.appendingPathComponent("Reps", isDirectory: true).appendingPathComponent("store.json")

        guard let data = try? Data(contentsOf: url) else {
            return nil
        }

        return try? JSONDecoder().decode(AppSnapshot.self, from: data)
    }

    private func mergeSeedExercises(into storedExercises: [Exercise]) -> [Exercise] {
        let curatedStored = storedExercises.filter { $0.sourceName != "free-exercise-db" }
        let existingNames = Set(curatedStored.map { $0.name.lowercased() })
        let missing = SeedData.exercises.filter { !existingNames.contains($0.name.lowercased()) }
        return curatedStored + missing
    }

    private func mergeSeedWorkouts(into storedWorkouts: [WorkoutDay]) -> [WorkoutDay] {
        let existingTitles = Set(storedWorkouts.map { $0.title.lowercased() })
        let missing = SeedData.workoutTemplates.filter { !existingTitles.contains($0.title.lowercased()) }
        return storedWorkouts + missing
    }

    private func mergeSeedPlans(into storedPlans: [WorkoutPlan]) -> [WorkoutPlan] {
        let existingNames = Set(storedPlans.map { $0.name.lowercased() })
        let missing = SeedData.defaultPlans.filter { !existingNames.contains($0.name.lowercased()) }
        return storedPlans + missing
    }
}

private extension CardioLog {
    var dedupeKey: String {
        "\(activityType.rawValue)-\(Int(date.timeIntervalSince1970 / 60))-\(durationMinutes)-\(Int((distanceKm ?? 0) * 100))"
    }
}

private struct OpenExerciseLibraryClient {
    private let datasetURL = URL(string: "https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/dist/exercises.json")!

    func fetchExercises() async throws -> [OpenExerciseRecord] {
        var request = URLRequest(url: datasetURL)
        request.timeoutInterval = 25
        request.cachePolicy = .returnCacheDataElseLoad

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              (200..<300).contains(httpResponse.statusCode) else {
            throw URLError(.badServerResponse)
        }

        return try JSONDecoder().decode([OpenExerciseRecord].self, from: data)
    }
}

private struct OpenExerciseRecord: Decodable {
    let id: String
    let name: String
    let level: String?
    let equipment: String?
    let primaryMuscles: [String]
    let secondaryMuscles: [String]
    let instructions: [String]
    let category: String?
    let images: [String]

    var domainExercise: Exercise? {
        guard !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return nil
        }

        return Exercise(
            name: name,
            aliases: [],
            muscleGroup: primaryMuscles.first.map(Self.displayMuscleGroup) ?? "Full Body",
            secondaryMuscles: secondaryMuscles.map(Self.displayMuscleGroup),
            equipment: equipment.map(Self.displayEquipment) ?? "Other",
            requiredEquipment: equipment.map { [Self.displayEquipment($0)] } ?? [],
            trackingType: trackingType,
            exerciseType: exerciseType,
            difficulty: difficulty,
            environment: environment,
            tags: [category, level].compactMap { $0 }.map(Self.displayName),
            mediaURL: images.first.map { Self.imageBaseURL + $0 },
            instructions: instructions.enumerated().map { index, instruction in
                "\(index + 1). \(instruction)"
            }.joined(separator: "\n"),
            commonMistakes: [],
            notes: sourceNotes,
            sourceID: id,
            sourceName: "free-exercise-db",
            sourceLicense: "Unlicense",
            sourceURL: "https://github.com/yuhonas/free-exercise-db"
        )
    }

    private var exerciseType: Exercise.ExerciseType {
        switch category?.lowercased() {
        case "cardio":
            return .cardio
        case "stretching":
            return .stretching
        default:
            return .strength
        }
    }

    private var difficulty: Exercise.Difficulty {
        switch level?.lowercased() {
        case "beginner":
            return .low
        case "expert":
            return .high
        default:
            return .medium
        }
    }

    private var environment: Exercise.Environment {
        switch equipment?.lowercased() {
        case "body only", "bands", "dumbbell", "kettlebells":
            return .both
        case "machine", "cable", "barbell":
            return .gym
        default:
            return .both
        }
    }

    private var trackingType: Exercise.TrackingType {
        switch category?.lowercased() {
        case "cardio", "stretching":
            return .duration
        default:
            if equipment?.lowercased() == "body only" {
                return .repsOnly
            }
            return .weightReps
        }
    }

    private var sourceNotes: String {
        [
            "Source: free-exercise-db (Unlicense)",
            level.map { "Level: \(Self.displayName($0))" },
            category.map { "Category: \(Self.displayName($0))" },
            secondaryMuscles.isEmpty ? nil : "Secondary muscles: \(secondaryMuscles.map(Self.displayName).joined(separator: ", "))"
        ]
        .compactMap { $0 }
        .joined(separator: "\n")
    }

    private static let imageBaseURL = "https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/"

    private static func displayMuscleGroup(_ rawValue: String) -> String {
        switch rawValue.lowercased() {
        case "abdominals": return "Abs"
        case "adductors": return "Adductors"
        case "abductors": return "Abductors"
        case "calves": return "Calves"
        case "hamstrings": return "Hamstrings"
        case "quadriceps": return "Quadriceps"
        case "glutes": return "Glutes"
        case "lats": return "Lats"
        case "middle back": return "Upper Back"
        case "lower back": return "Lower Back"
        case "traps": return "Traps"
        case "chest": return "Chest"
        case "shoulders": return "Shoulders"
        case "biceps": return "Biceps"
        case "triceps": return "Triceps"
        case "forearms": return "Forearms"
        default: return displayName(rawValue)
        }
    }

    private static func displayEquipment(_ rawValue: String) -> String {
        switch rawValue.lowercased() {
        case "body only": return "Bodyweight"
        case "e-z curl bar": return "EZ Bar"
        case "bands": return "Resistance Band"
        default: return displayName(rawValue)
        }
    }

    private static func displayName(_ rawValue: String) -> String {
        rawValue
            .replacingOccurrences(of: "_", with: " ")
            .split(separator: " ")
            .map { word in
                word.prefix(1).uppercased() + word.dropFirst().lowercased()
            }
            .joined(separator: " ")
    }
}

struct WatchRouteMetrics: Sendable {
    var distanceKm: Double?
    var paceSecondsPerKm: Double?
    var speedKmh: Double?
    var steps: Double?
    var pointCount: Int?
    var heartRate: Double?
    var activeEnergyKcal: Double?
}

extension Notification.Name {
    /// Posted after a Watch-logged set is applied to the active workout drafts,
    /// so the active workout screen can recompute and republish its status.
    static let watchDidLogSet = Notification.Name("WatchCommand.didLogSet")
}

/// A single set logged on the Watch and pushed to the iPhone in real time.
struct WatchLogSet: Sendable {
    var exerciseIndex: Int
    var setIndex: Int
    var weightKg: Double
    var reps: Int
    var setType: String
    var completed: Bool
}

private final class RouteLocationAccumulator: @unchecked Sendable {
    private let lock = NSLock()
    private var locations: [CLLocation] = []

    func append(contentsOf newLocations: [CLLocation]) {
        lock.lock()
        locations.append(contentsOf: newLocations)
        lock.unlock()
    }

    func snapshot() -> [CLLocation] {
        lock.lock()
        let value = locations
        lock.unlock()
        return value
    }
}

struct NativeWorkoutMetrics: Sendable {
    var heartRate: Double?
    var activeEnergyKcal: Double?
    var distanceKm: Double?
    var steps: Double?
}

struct NativeWorkoutStartPayload: Sendable {
    var activityType: HKWorkoutActivityType
    var locationType: HKWorkoutSessionLocationType
    var startedAt: Date
}

/// Drives HealthKit workout sessions from the iPhone.
///
/// Mirroring (receiving the watch session), remote control (pause/resume/end)
/// and launching the watch app are available from iOS 17. Running a primary
/// session on the iPhone itself (HKLiveWorkoutBuilder) and session recovery
/// require iOS 26, so those paths are gated individually.
@MainActor
final class NativeWorkoutSessionService: NSObject {
    private let healthStore = HKHealthStore()
    private var session: HKWorkoutSession?
    private var builderStorage: Any?
    @available(iOS 26.0, *)
    private var builder: HKLiveWorkoutBuilder? {
        get { builderStorage as? HKLiveWorkoutBuilder }
        set { builderStorage = newValue }
    }
    private var activeStatusID: UUID?
    private var pendingFallbackStartTask: Task<Void, Never>?
    private var isStartingPrimarySession = false
    private var isEndingFromAppState = false
    private var metricsHandler: (@MainActor @Sendable (NativeWorkoutMetrics) -> Void)?
    private var mirroredStartHandler: (@MainActor @Sendable (NativeWorkoutStartPayload) -> Void)?
    private var endedHandler: (@MainActor @Sendable () -> Void)?
    private var companionLaunchStatusID: UUID?
    private var isLaunchingCompanionWorkout = false

    func configure(
        metricsHandler: (@MainActor @Sendable (NativeWorkoutMetrics) -> Void)?,
        mirroredStartHandler: (@MainActor @Sendable (NativeWorkoutStartPayload) -> Void)?,
        endedHandler: (@MainActor @Sendable () -> Void)?
    ) {
        self.metricsHandler = metricsHandler
        self.mirroredStartHandler = mirroredStartHandler
        self.endedHandler = endedHandler
    }

    func startMirroringListener() {
        guard HKHealthStore.isHealthDataAvailable() else { return }

        healthStore.workoutSessionMirroringStartHandler = { [weak self] mirroredSession in
            Task { @MainActor in
                await self?.attachMirroredSession(mirroredSession)
            }
        }

        guard #available(iOS 26.0, *) else { return }
        healthStore.recoverActiveWorkoutSession { [weak self] recoveredSession, error in
            guard let recoveredSession else {
                if let error {
                    Task { @MainActor in
                        TelemetryService.shared.record(error, context: "healthkit_recover_active_workout")
                    }
                }
                return
            }

            Task { @MainActor in
                await self?.attachMirroredSession(recoveredSession)
            }
        }
    }

    func reconcile(status: ActiveWorkoutStatus?, workout: WorkoutDay?, preferCompanionWorkout: Bool) {
        guard HKHealthStore.isHealthDataAvailable() else { return }

        guard let status else {
            pendingFallbackStartTask?.cancel()
            pendingFallbackStartTask = nil
            companionLaunchStatusID = nil
            isLaunchingCompanionWorkout = false
            endCurrentSession(notifyApp: false)
            return
        }

        if activeStatusID != status.id {
            activeStatusID = status.id
        }

        if session == nil {
            if preferCompanionWorkout {
                startCompanionWorkout(status: status, workout: workout)
                schedulePrimaryFallback(status: status, workout: workout)
            } else if #available(iOS 26.0, *) {
                startPrimarySession(status: status, workout: workout)
            }
            return
        }

        if status.isPaused, session?.state == .running {
            session?.pause()
        } else if !status.isPaused, session?.state == .paused {
            session?.resume()
        }
    }

    private func startCompanionWorkout(status: ActiveWorkoutStatus, workout: WorkoutDay?) {
        guard companionLaunchStatusID != status.id, !isLaunchingCompanionWorkout else { return }
        companionLaunchStatusID = status.id
        isLaunchingCompanionWorkout = true

        let configuration = Self.configuration(status: status, workout: workout)
        Task {
            do {
                try await requestAuthorization()
                healthStore.startWatchApp(with: configuration) { [weak self] success, error in
                    Task { @MainActor in
                        guard let self else { return }
                        self.isLaunchingCompanionWorkout = false
                        if let error {
                            TelemetryService.shared.record(error, context: "healthkit_start_watch_app")
                        }
                        if !success {
                            self.companionLaunchStatusID = nil
                        }
                    }
                }
            } catch {
                TelemetryService.shared.record(error, context: "healthkit_start_watch_app_authorization")
                isLaunchingCompanionWorkout = false
                if companionLaunchStatusID == status.id {
                    self.companionLaunchStatusID = nil
                }
            }
        }
    }

    private func schedulePrimaryFallback(status: ActiveWorkoutStatus, workout: WorkoutDay?) {
        guard #available(iOS 26.0, *) else { return }
        guard pendingFallbackStartTask == nil else { return }
        pendingFallbackStartTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(4))
            guard !Task.isCancelled else { return }
            await MainActor.run {
                guard let self, self.session == nil else { return }
                self.startPrimarySession(status: status, workout: workout)
                self.pendingFallbackStartTask = nil
            }
        }
    }

    @available(iOS 26.0, *)
    private func startPrimarySession(status: ActiveWorkoutStatus, workout: WorkoutDay?) {
        guard session == nil, !isStartingPrimarySession else { return }
        isStartingPrimarySession = true

        Task {
            do {
                try await requestAuthorization()
                let configuration = Self.configuration(status: status, workout: workout)
                let workoutSession = try HKWorkoutSession(healthStore: healthStore, configuration: configuration)
                let workoutBuilder = workoutSession.associatedWorkoutBuilder()
                workoutBuilder.dataSource = HKLiveWorkoutDataSource(
                    healthStore: healthStore,
                    workoutConfiguration: configuration
                )
                workoutSession.delegate = self
                workoutBuilder.delegate = self

                session = workoutSession
                builder = workoutBuilder
                let startDate = status.startedAt == .distantPast ? Date() : status.startedAt
                workoutSession.startActivity(with: startDate)
                try await workoutBuilder.beginCollection(at: startDate)
                if status.isPaused {
                    workoutSession.pause()
                }
            } catch {
                TelemetryService.shared.record(error, context: "healthkit_start_native_workout")
            }
            isStartingPrimarySession = false
        }
    }

    private func attachMirroredSession(_ mirroredSession: HKWorkoutSession) async {
        pendingFallbackStartTask?.cancel()
        pendingFallbackStartTask = nil
        companionLaunchStatusID = nil
        isLaunchingCompanionWorkout = false

        if let existingSession = session, existingSession !== mirroredSession {
            session = existingSession
            endCurrentSession(notifyApp: false)
        }

        mirroredSession.delegate = self
        session = mirroredSession
        if #available(iOS 26.0, *) {
            let workoutBuilder = mirroredSession.associatedWorkoutBuilder()
            workoutBuilder.delegate = self
            builder = workoutBuilder
        }

        let configuration = mirroredSession.workoutConfiguration
        mirroredStartHandler?(NativeWorkoutStartPayload(
            activityType: configuration.activityType,
            locationType: configuration.locationType,
            startedAt: mirroredSession.startDate ?? Date()
        ))
    }

    private func endCurrentSession(notifyApp: Bool) {
        guard let session else { return }
        isEndingFromAppState = !notifyApp
        let endDate = Date()

        session.end()
        if #available(iOS 26.0, *) {
            let workoutBuilder = builder
            Task {
                try? await workoutBuilder?.endCollection(at: endDate)
                _ = try? await workoutBuilder?.finishWorkout()
            }
        }
        self.session = nil
        builderStorage = nil
        activeStatusID = nil
        isStartingPrimarySession = false
    }

    private func requestAuthorization() async throws {
        let shareTypes: Set<HKSampleType> = [
            HKWorkoutType.workoutType(),
            HKQuantityType(.activeEnergyBurned),
            HKQuantityType(.distanceWalkingRunning)
        ]
        let readTypes: Set<HKObjectType> = [
            HKWorkoutType.workoutType(),
            HKQuantityType(.heartRate),
            HKQuantityType(.activeEnergyBurned),
            HKQuantityType(.distanceWalkingRunning),
            HKQuantityType(.stepCount)
        ]
        try await healthStore.requestAuthorization(toShare: shareTypes, read: readTypes)
    }

    private static func configuration(status: ActiveWorkoutStatus, workout: WorkoutDay?) -> HKWorkoutConfiguration {
        let configuration = HKWorkoutConfiguration()
        configuration.activityType = activityType(status: status, workout: workout)
        if status.isOutdoorRoute == true {
            configuration.locationType = .outdoor
        } else {
            configuration.locationType = .indoor
        }
        return configuration
    }

    private static func activityType(status: ActiveWorkoutStatus, workout: WorkoutDay?) -> HKWorkoutActivityType {
        if let workout {
            switch workout.sessionType {
            case .cardioRun:
                return .running
            case .cardioWalk:
                return .walking
            case .mobility:
                return .flexibility
            case .mixedRoute:
                return status.workoutTitle.localizedCaseInsensitiveContains("run") ||
                    status.workoutTitle.localizedCaseInsensitiveContains("carrera") ? .running : .walking
            case .strength, .free:
                break
            }
        }

        let title = status.workoutTitle.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
        if title.localizedCaseInsensitiveContains("carrera") || title.localizedCaseInsensitiveContains("run") {
            return .running
        }
        if title.localizedCaseInsensitiveContains("camina") || title.localizedCaseInsensitiveContains("walk") {
            return .walking
        }
        return .traditionalStrengthTraining
    }
}

extension NativeWorkoutSessionService: HKWorkoutSessionDelegate {
    nonisolated func workoutSession(
        _ workoutSession: HKWorkoutSession,
        didChangeTo toState: HKWorkoutSessionState,
        from fromState: HKWorkoutSessionState,
        date: Date
    ) {
        guard toState == .ended || toState == .stopped else { return }
        Task { @MainActor in
            let shouldNotify = !isEndingFromAppState
            isEndingFromAppState = false
            session = nil
            builderStorage = nil
            activeStatusID = nil
            if shouldNotify {
                endedHandler?()
            }
        }
    }

    nonisolated func workoutSession(_ workoutSession: HKWorkoutSession, didFailWithError error: Error) {
        Task { @MainActor in
            TelemetryService.shared.record(error, context: "healthkit_native_workout_session")
        }
    }
}

@available(iOS 26.0, *)
extension NativeWorkoutSessionService: HKLiveWorkoutBuilderDelegate {
    nonisolated func workoutBuilderDidCollectEvent(_ workoutBuilder: HKLiveWorkoutBuilder) {}

    nonisolated func workoutBuilder(_ workoutBuilder: HKLiveWorkoutBuilder, didCollectDataOf collectedTypes: Set<HKSampleType>) {
        Task { @MainActor in
            var metrics = NativeWorkoutMetrics()
            for sampleType in collectedTypes {
                guard let quantityType = sampleType as? HKQuantityType,
                      let statistics = workoutBuilder.statistics(for: quantityType) else {
                    continue
                }

                switch quantityType {
                case HKQuantityType(.heartRate):
                    metrics.heartRate = statistics.mostRecentQuantity()?
                        .doubleValue(for: HKUnit.count().unitDivided(by: .minute()))
                case HKQuantityType(.activeEnergyBurned):
                    metrics.activeEnergyKcal = statistics.sumQuantity()?.doubleValue(for: .kilocalorie())
                case HKQuantityType(.distanceWalkingRunning):
                    metrics.distanceKm = statistics.sumQuantity()?.doubleValue(for: .meterUnit(with: .kilo))
                case HKQuantityType(.stepCount):
                    metrics.steps = statistics.sumQuantity()?.doubleValue(for: .count())
                default:
                    break
                }
            }

            metricsHandler?(metrics)
        }
    }
}

final class WatchSyncService: NSObject, WCSessionDelegate, @unchecked Sendable {
    static let shared = WatchSyncService()
    private var commandHandler: (@MainActor @Sendable (WatchCommand) -> Void)?
    private var routeMetricsHandler: (@MainActor @Sendable (WatchRouteMetrics) -> Void)?
    private var routeSummaryHandler: (@MainActor @Sendable (WatchRouteWorkoutSummary) -> Void)?
    private var logSetHandler: (@MainActor @Sendable (WatchLogSet) -> Void)?
    private var strengthSummaryHandler: (@MainActor @Sendable (WatchStrengthWorkoutSummary) -> Void)?
    private var intervalSummaryHandler: (@MainActor @Sendable (WatchIntervalWorkoutSummary) -> Void)?

    private override init() {
        super.init()
    }

    var canStartCompanionWorkout: Bool {
        guard WCSession.isSupported() else { return false }
        let session = WCSession.default
        return session.activationState == .activated &&
            session.isPaired &&
            session.isWatchAppInstalled &&
            HKHealthStore.isHealthDataAvailable()
    }

    func configure(
        commandHandler: (@MainActor @Sendable (WatchCommand) -> Void)? = nil,
        routeMetricsHandler: (@MainActor @Sendable (WatchRouteMetrics) -> Void)? = nil,
        routeSummaryHandler: (@MainActor @Sendable (WatchRouteWorkoutSummary) -> Void)? = nil,
        logSetHandler: (@MainActor @Sendable (WatchLogSet) -> Void)? = nil,
        strengthSummaryHandler: (@MainActor @Sendable (WatchStrengthWorkoutSummary) -> Void)? = nil,
        intervalSummaryHandler: (@MainActor @Sendable (WatchIntervalWorkoutSummary) -> Void)? = nil
    ) {
        self.commandHandler = commandHandler
        self.routeMetricsHandler = routeMetricsHandler
        self.routeSummaryHandler = routeSummaryHandler
        self.logSetHandler = logSetHandler
        self.strengthSummaryHandler = strengthSummaryHandler
        self.intervalSummaryHandler = intervalSummaryHandler
        guard WCSession.isSupported() else { return }
        let session = WCSession.default
        guard session.delegate == nil else { return }
        session.delegate = self
        session.activate()
    }

    func publish(snapshot: SharedWorkoutSnapshot) {
        guard WCSession.isSupported() else { return }
        let session = WCSession.default
        guard session.activationState == .activated else { return }
        guard session.isWatchAppInstalled else { return }

        var context: [String: Any] = [
            "summary": snapshot.summary,
            "updatedAt": snapshot.updatedAt.timeIntervalSince1970,
            "hasActiveWorkout": snapshot.hasActiveWorkout,
            "workoutTitle": snapshot.workoutTitle,
            "elapsedSeconds": snapshot.elapsedSeconds,
            "pausedSeconds": snapshot.pausedSeconds,
            "completedSets": snapshot.completedSets,
            "totalSets": snapshot.totalSets,
            "volumeKg": snapshot.volumeKg,
            "isPaused": snapshot.isPaused
        ]
        context["planTitle"] = snapshot.planTitle
        context["sessionTitle"] = snapshot.sessionTitle
        context["exerciseName"] = snapshot.exerciseName
        context["exerciseIndex"] = snapshot.exerciseIndex
        context["totalExercises"] = snapshot.totalExercises
        context["currentExerciseCompletedSets"] = snapshot.currentExerciseCompletedSets
        context["currentExerciseTotalSets"] = snapshot.currentExerciseTotalSets
        context["currentSetWeightKg"] = snapshot.currentSetWeightKg
        context["currentSetReps"] = snapshot.currentSetReps
        context["restSeconds"] = snapshot.restSeconds
        context["restDurationSeconds"] = snapshot.restDurationSeconds
        context["estimatedRemainingSeconds"] = snapshot.estimatedRemainingSeconds
        context["waterLiters"] = snapshot.waterLiters
        context["musicTitle"] = snapshot.musicTitle
        context["musicArtist"] = snapshot.musicArtist
        context["isMusicPlaying"] = snapshot.isMusicPlaying
        context["nextExerciseName"] = snapshot.nextExerciseName
        context["exerciseHistorySummary"] = snapshot.exerciseHistorySummary
        context["gymPassName"] = snapshot.gymPassName
        context["gymMembershipID"] = snapshot.gymMembershipID
        context["gymCodeValue"] = snapshot.gymCodeValue
        context["gymCodeType"] = snapshot.gymCodeType
        if let heartRate = snapshot.heartRate {
            context["heartRate"] = heartRate
        }
        if let activeEnergyKcal = snapshot.activeEnergyKcal {
            context["activeEnergyKcal"] = activeEnergyKcal
        }
        context["isRouteWorkout"] = snapshot.isRouteWorkout
        context["isOutdoorRoute"] = snapshot.isOutdoorRoute
        context["routeDistanceKm"] = snapshot.routeDistanceKm
        context["routePaceSecondsPerKm"] = snapshot.routePaceSecondsPerKm
        context["routeSpeedKmh"] = snapshot.routeSpeedKmh
        context["routePointCount"] = snapshot.routePointCount
        context["routeSteps"] = snapshot.routeSteps
        context["streakDays"] = snapshot.streakDays
        context["weeklyCompletion"] = snapshot.weeklyCompletion
        context["trainingBatteryLevel"] = snapshot.trainingBatteryLevel
        context["trainingBatteryState"] = snapshot.trainingBatteryState
        context["trainingBatteryTitle"] = snapshot.trainingBatteryTitle
        context["trainingBatterySuggestion"] = snapshot.trainingBatterySuggestion
        context["trainingBatterySystemImage"] = snapshot.trainingBatterySystemImage
        context["nextWorkoutDayName"] = snapshot.nextWorkoutDayName
        context["nextWorkoutDayDescription"] = snapshot.nextWorkoutDayDescription
        context["widgetAccentColorName"] = snapshot.widgetAccentColorName
        context["preferredLanguage"] = snapshot.preferredLanguage
        context["exercisesData"] = snapshot.exercisesData
        context["estimatedMaxHeartRate"] = snapshot.estimatedMaxHeartRate

        try? session.updateApplicationContext(context)
        if session.isReachable {
            session.sendMessage(context, replyHandler: nil)
        }
    }

    func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: Error?
    ) {}

    func sessionDidBecomeInactive(_ session: WCSession) {}

    func sessionDidDeactivate(_ session: WCSession) {
        session.activate()
    }

    func session(
        _ session: WCSession,
        didReceiveMessage message: [String: Any],
        replyHandler: @escaping ([String: Any]) -> Void
    ) {
        handle(message)
        replyHandler(["received": true])
    }

    func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        handle(message)
    }

    func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        handlePersistentPayload(applicationContext)
    }

    func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any]) {
        handlePersistentPayload(userInfo)
    }

    private func handlePersistentPayload(_ message: [String: Any]) {
        if message["kind"] as? String == "routeWorkoutSummary",
           let data = message["routeWorkoutSummary"] as? Data,
           let summary = try? JSONDecoder().decode(WatchRouteWorkoutSummary.self, from: data) {
            let handler = routeSummaryHandler
            Task { @MainActor in
                handler?(summary)
            }
        }
        if message["kind"] as? String == "strengthWorkoutSummary",
           let data = message["strengthWorkoutSummary"] as? Data,
           let summary = try? JSONDecoder().decode(WatchStrengthWorkoutSummary.self, from: data) {
            let handler = strengthSummaryHandler
            Task { @MainActor in
                handler?(summary)
            }
        }
        if message["kind"] as? String == "intervalWorkoutSummary",
           let data = message["intervalWorkoutSummary"] as? Data,
           let summary = try? JSONDecoder().decode(WatchIntervalWorkoutSummary.self, from: data) {
            let handler = intervalSummaryHandler
            Task { @MainActor in
                handler?(summary)
            }
        }
    }

    private func handle(_ message: [String: Any]) {
        if let kind = message["kind"] as? String,
           kind == "routeWorkoutSummary" || kind == "strengthWorkoutSummary" || kind == "intervalWorkoutSummary" {
            handlePersistentPayload(message)
            return
        }
        if message["kind"] as? String == "logSet",
           let exerciseIndex = message["exerciseIndex"] as? Int,
           let setIndex = message["setIndex"] as? Int {
            let logSet = WatchLogSet(
                exerciseIndex: exerciseIndex,
                setIndex: setIndex,
                weightKg: message["weightKg"] as? Double ?? 0,
                reps: message["reps"] as? Int ?? 0,
                setType: message["setType"] as? String ?? "work",
                completed: message["completed"] as? Bool ?? true
            )
            let handler = logSetHandler
            Task { @MainActor in
                handler?(logSet)
            }
            return
        }
        if message["kind"] as? String == "routeMetrics" {
            let metrics = WatchRouteMetrics(
                distanceKm: message["routeDistanceKm"] as? Double,
                paceSecondsPerKm: message["routePaceSecondsPerKm"] as? Double,
                speedKmh: message["routeSpeedKmh"] as? Double,
                steps: message["routeSteps"] as? Double,
                pointCount: message["routePointCount"] as? Int,
                heartRate: message["heartRate"] as? Double,
                activeEnergyKcal: message["activeEnergyKcal"] as? Double
            )
            let handler = routeMetricsHandler
            Task { @MainActor in
                handler?(metrics)
            }
            return
        }

        guard let rawCommand = message["command"] as? String,
              let command = WatchCommand(rawValue: rawCommand) else {
            return
        }

        let handler = commandHandler
        Task { @MainActor in
            handler?(command)
        }
    }
}

@MainActor
final class RepsWorkoutLiveActivityController {
    static let shared = RepsWorkoutLiveActivityController()

    private var lastSignature: LiveActivitySnapshotSignature?

    private init() {}

    func sync(_ snapshot: SharedWorkoutSnapshot) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        let signature = LiveActivitySnapshotSignature(snapshot: snapshot)
        guard signature != lastSignature else { return }
        lastSignature = signature

        Task {
            if snapshot.hasActiveWorkout {
                let activities = Activity<RepsWorkoutActivityAttributes>.activities
                let content = ActivityContent(
                    state: RepsWorkoutActivityAttributes.ContentState(snapshot: snapshot),
                    staleDate: snapshot.liveActivityStaleDate,
                    relevanceScore: 75
                )
                if !activities.isEmpty {
                    for activity in activities {
                        await activity.update(content)
                    }
                } else {
                    let attributes = RepsWorkoutActivityAttributes(workoutTitle: snapshot.workoutTitle)
                    _ = try? Activity<RepsWorkoutActivityAttributes>.request(
                        attributes: attributes,
                        content: content,
                        pushType: nil
                    )
                }
            } else {
                for activity in Activity<RepsWorkoutActivityAttributes>.activities {
                    await activity.end(ActivityContent(
                        state: RepsWorkoutActivityAttributes.ContentState(snapshot: snapshot),
                        staleDate: nil
                    ), dismissalPolicy: .after(Date().addingTimeInterval(30)))
                }
            }
        }
    }
}

private struct LiveActivitySnapshotSignature: Equatable {
    let hasActiveWorkout: Bool
    let workoutTitle: String
    let exerciseName: String?
    let nextExerciseName: String?
    let completedSets: Int
    let totalSets: Int
    let volumeKg: Int
    let isPaused: Bool
    let elapsedStartBucket: Int
    let restEndBucket: Int?
    let restDurationSeconds: Int?
    let estimatedRemainingSeconds: Int?
    let widgetAccentColorName: String

    init(snapshot: SharedWorkoutSnapshot) {
        hasActiveWorkout = snapshot.hasActiveWorkout
        workoutTitle = snapshot.workoutTitle
        exerciseName = snapshot.exerciseName
        nextExerciseName = snapshot.nextExerciseName
        completedSets = snapshot.completedSets
        totalSets = snapshot.totalSets
        volumeKg = snapshot.volumeKg
        isPaused = snapshot.isPaused
        elapsedStartBucket = Int(snapshot.elapsedStartDate.timeIntervalSince1970.rounded())
        restEndBucket = snapshot.restEndDate.map { Int($0.timeIntervalSince1970.rounded()) }
        restDurationSeconds = snapshot.restDurationSeconds
        estimatedRemainingSeconds = snapshot.estimatedRemainingSeconds
        widgetAccentColorName = snapshot.widgetAccentColorName
    }
}

private extension SharedWorkoutSnapshot {
    var liveActivityStaleDate: Date {
        if let restEndDate {
            return restEndDate.addingTimeInterval(90)
        }
        return Date().addingTimeInterval(isPaused ? 900 : 300)
    }
}

private extension String {
    var normalizedExerciseKey: String {
        trimmingCharacters(in: .whitespacesAndNewlines)
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            .replacingOccurrences(of: "-", with: " ")
            .replacingOccurrences(of: "_", with: " ")
            .split(separator: " ")
            .joined(separator: " ")
    }
}

private extension Exercise {
    var libraryLookupKeys: Set<String> {
        let explicitFallbacks: [String]
        switch name.normalizedExerciseKey {
        case "bulgarian split squat":
            explicitFallbacks = ["Split Squat with Dumbbells", "Split Squats"]
        default:
            explicitFallbacks = []
        }

        return Set(([name] + aliases + explicitFallbacks)
            .map(\.normalizedExerciseKey)
            .filter { !$0.isEmpty })
    }
}
