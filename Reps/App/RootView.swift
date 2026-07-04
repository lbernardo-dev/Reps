import StoreKit
import SwiftUI

struct RootView: View {
    @Environment(AppStore.self) private var store

    private var showsMainInterface: Bool {
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("-skipOnboarding") {
            return true
        }
        #endif
        return store.userProfile.onboardingCompleted
    }

    private var preferredColorScheme: ColorScheme? {
        switch store.userProfile.activeThemeMode {
        case .dark:   return .dark
        case .light:  return .light
        case .system: return nil
        }
    }

    var body: some View {
        @Bindable var store = store
        return Group {
            if showsMainInterface {
                MainTabView()
            } else {
                WelcomeView()
            }
        }
        .alert("storage_error", isPresented: Binding(
            get: { store.isUsingFallbackStorage },
            set: { store.isUsingFallbackStorage = $0 }
        )) {
            Button("aceptar", role: .cancel) {}
        } message: {
            Text("there_was_a_problem_loading_your_saved_data_the_app_is_in_temporary_mode_and_wil")
        }
        .fullScreenCover(item: $store.activePaywall) { presentation in
            PaywallView(presentation: presentation)
                .environment(store)
        }
        .preferredColorScheme(preferredColorScheme)
    }
}

// MARK: - Main Tab View

struct MainTabView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.requestReview) private var requestReview

    @State private var selectedTab: AppTab = .today
    @State private var isTabBarHidden = false
    @State private var isQuickMenuExpanded = false
    @State private var presentedQuickAction: QuickAction?
    @State private var pendingWorkoutSummarySession: WorkoutSession?
    @State private var showCalendarSheet = false
    @State private var todayResetID     = UUID()
    @State private var trainResetID     = UUID()
    @State private var progressResetID  = UUID()
    @State private var exercisesResetID = UUID()
    @State private var profileResetID   = UUID()

    var body: some View {
        @Bindable var store = store
        return activeTabSurface
            .overlay(alignment: .bottom) {
                if isQuickMenuExpanded {
                    quickMenuOverlay
                }
            }
            .overlay {
                if !store.pendingAchievementUnlocks.isEmpty && store.finishedSessionForSummary == nil {
                    AchievementUnlockOverlay()
                        .environment(store)
                }
            }
            .ignoresSafeArea(.keyboard, edges: .bottom)
            .sheet(item: $presentedQuickAction, onDismiss: {
                if let pending = pendingWorkoutSummarySession {
                    pendingWorkoutSummarySession = nil
                    store.finishedSessionForSummary = pending
                }
            }) { action in
                quickActionDestination(action)
            }
            .sheet(isPresented: $showCalendarSheet) {
                CalendarView()
            }
            .sheet(item: $store.finishedSessionForSummary) { session in
                WorkoutSummaryView(session: session) {
                    store.finishedSessionForSummary = nil
                    store.pendingMainTabSelection = .progress
                    if store.pendingMilestonePaywall {
                        store.pendingMilestonePaywall = false
                        store.presentPaywall(source: .onboarding, feature: nil, trigger: .featureGate)
                    }
                }
            }
            .onChange(of: store.finishedSessionForSummary?.id) { _, newID in
                // The Free Workout picker ("Empezar") is itself presented as
                // presentedQuickAction's sheet, so ActiveWorkoutView's finish
                // flow lands back on it instead of dismissing it. Two sibling
                // .sheet(item:) modifiers on this view can't stack, so the
                // summary sheet above would silently fail to present while
                // that sheet is still up. Dismiss it first and re-trigger the
                // summary from its onDismiss once it's fully gone.
                guard newID != nil, presentedQuickAction != nil else { return }
                pendingWorkoutSummarySession = store.finishedSessionForSummary
                store.finishedSessionForSummary = nil
                presentedQuickAction = nil
            }
            .onAppear {
                TelemetryService.shared.log(.mainTabSelected, parameters: [
                    "tab": selectedTab.telemetryName,
                    "source": "initial"
                ])
                applyNotificationDestination(store.notificationDestination)
            }
            .onChange(of: selectedTab) { _, newTab in
                TelemetryService.shared.log(.mainTabSelected, parameters: [
                    "tab": newTab.telemetryName,
                    "source": "selection"
                ])
            }
            .onChange(of: store.pendingReviewRequest) { _, shouldRequest in
                if shouldRequest {
                    store.pendingReviewRequest = false
                    requestReview()
                }
            }
            .onPreferenceChange(MainTabBarHiddenPreferenceKey.self) { hidden in
                withAnimation(.snappy(duration: 0.22)) {
                    isTabBarHidden = hidden
                    if hidden { isQuickMenuExpanded = false }
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .repsStartFreeWorkoutIntent)) { _ in
                select(.today)
                presentedQuickAction = .freeWorkout
            }
            .onChange(of: store.notificationDestination) { _, destination in
                applyNotificationDestination(destination)
            }
            .onChange(of: store.pendingMainTabSelection) { _, tab in
                guard let tab else { return }
                select(tab)
                store.pendingMainTabSelection = nil
            }
    }

    // MARK: Tab shell

    @ViewBuilder
    private var activeTabSurface: some View {
        if isQuickMenuExpanded || presentedQuickAction != nil {
            PulseTheme.background
                .ignoresSafeArea()
                .accessibilityHidden(true)
        } else {
            tabShell
        }
    }

    private var tabShell: some View {
        TabView(selection: tabSelection) {
            // — Hoy: readiness + today's plan + streak. No deep analytics.
            Tab(value: AppTab.today) {
                TodayView(onSelectTab: { select($0) })
                    .id(todayResetID)
                    .toolbar(isTabBarHidden ? .hidden : .visible, for: .tabBar)
            } label: {
                AppTab.today.label
            }

            // — Entrenar: quick start, plans/routines, library, tools, schedule.
            Tab(value: AppTab.train) {
                PlansView()
                    .id(trainResetID)
                    .toolbar(isTabBarHidden ? .hidden : .visible, for: .tabBar)
            } label: {
                AppTab.train.label
            }

            // — Progreso: analytics, trends, records, history.
            Tab(value: AppTab.progress) {
                ProgressDashboardView(onSelectTab: { select($0) })
                    .id(progressResetID)
                    .toolbar(isTabBarHidden ? .hidden : .visible, for: .tabBar)
            } label: {
                AppTab.progress.label
            }

            // — Ejercicios: browse and manage the exercise library.
            Tab(value: AppTab.exercises) {
                ExerciseLibraryView(isTabRoot: true)
                    .id(exercisesResetID)
                    .toolbar(isTabBarHidden ? .hidden : .visible, for: .tabBar)
            } label: {
                AppTab.exercises.label
            }

            // — Perfil: body, achievements, social, gym, settings. Rendered as a
            // detached avatar bubble (role: .search) à la Apple Music's search tab.
            Tab(value: AppTab.profile, role: .search) {
                NavigationStack {
                    ProfileView(isTabRoot: true)
                }
                .id(profileResetID)
                .toolbar(isTabBarHidden ? .hidden : .visible, for: .tabBar)
            } label: {
                profileTabLabel
            }
        }
        .tint(MetricDomain.strength.tint)
        .tabViewBottomAccessory {
            if !isQuickMenuExpanded {
                QuickLogTabAccessory { toggleQuickMenu() }
            }
        }
        .tabBarMinimizeBehavior(.onScrollDown)
    }

    // MARK: Quick menu

    private var quickMenuOverlay: some View {
        GeometryReader { proxy in
            quickMenuContent(bottomInset: proxy.safeAreaInsets.bottom)
        }
    }

    private func quickMenuContent(bottomInset: CGFloat) -> some View {
        VStack(spacing: 0) {
            QuickMenuProgressionChart()
                .transition(.move(edge: .top).combined(with: .opacity))

            Spacer(minLength: 16)

            VStack(alignment: .trailing, spacing: 11) {
                Text("quick_actions")
                    .font(.system(size: 10, weight: .black, design: .rounded))
                    .tracking(2)
                    .textCase(.uppercase)
                    .foregroundStyle(PulseTheme.tertiaryText)
                    .padding(.trailing, 8)
                    .padding(.bottom, 2)

                ForEach(Array(QuickAction.allCases.enumerated()), id: \.element.id) { index, action in
                    Button { open(action) } label: { QuickActionRow(action: action) }
                        .buttonStyle(.plain)
                        .transition(
                            .move(edge: .trailing)
                            .combined(with: .opacity)
                            .animation(.spring(response: 0.36, dampingFraction: 0.78).delay(Double(index) * 0.05))
                        )
                }
            }
            .frame(maxWidth: .infinity, alignment: .trailing)
            .padding(.trailing, 20)
            .padding(.bottom, 18)

            QuickMenuCloseButton { toggleQuickMenu() }
                .padding(.horizontal, 16)
                .padding(.bottom, max(bottomInset, 12) + 12)
                .transition(.move(edge: .bottom).combined(with: .opacity))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
        .background {
            quickMenuBackdrop
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture {
                    withAnimation(.spring(response: 0.32, dampingFraction: 0.82)) {
                        isQuickMenuExpanded = false
                    }
                }
                .transition(.opacity)
        }
    }

    private var quickMenuBackdrop: some View {
        ZStack {
            PulseTheme.background
            Circle()
                .fill(PulseTheme.accent.opacity(0.05))
                .frame(width: 320, height: 320)
                .blur(radius: 80)
                .offset(x: -160, y: -260)
            Circle()
                .fill(PulseTheme.ringStand.opacity(0.035))
                .frame(width: 320, height: 320)
                .blur(radius: 80)
                .offset(x: 160, y: -220)
        }
        .background(.thinMaterial)
    }

    // MARK: Profile tab avatar

    @ViewBuilder
    private var profileTabLabel: some View {
        if let data = store.userProfile.avatarImageData, let avatar = circularTabAvatar(from: data) {
            Image(uiImage: avatar)
                .renderingMode(.original)
                .accessibilityLabel(Text(verbatim: AppTab.profile.title))
        } else {
            AppTab.profile.label
        }
    }

    private func circularTabAvatar(from data: Data, diameter: CGFloat = 44) -> UIImage? {
        guard let source = UIImage(data: data) else { return nil }
        let format = UIGraphicsImageRendererFormat()
        format.scale = UITraitCollection.current.displayScale
        format.opaque = false
        let size = CGSize(width: diameter, height: diameter)
        let rendered = UIGraphicsImageRenderer(size: size, format: format).image { _ in
            UIBezierPath(ovalIn: CGRect(origin: .zero, size: size)).addClip()
            let fillScale = max(size.width / source.size.width, size.height / source.size.height)
            let scaledSize = CGSize(width: source.size.width * fillScale, height: source.size.height * fillScale)
            let origin = CGPoint(x: (size.width - scaledSize.width) / 2, y: (size.height - scaledSize.height) / 2)
            source.draw(in: CGRect(origin: origin, size: scaledSize))
        }
        // Tab bar icons render as template (monochrome) images by default; this
        // forces the actual photo colors to survive the tab bar's snapshotting.
        return rendered.withRenderingMode(.alwaysOriginal)
    }

    // MARK: Helpers

    private func select(_ tab: AppTab) {
        withAnimation(.snappy(duration: 0.18)) { isQuickMenuExpanded = false }
        guard tab != .calendar else {
            showCalendarSheet = true
            return
        }
        if tab == selectedTab { reset(tab) }
        selectedTab = tab
    }

    private func toggleQuickMenu() {
        HapticService.selection()
        withAnimation(.spring(response: 0.32, dampingFraction: 0.78)) {
            isQuickMenuExpanded.toggle()
        }
        TelemetryService.shared.log(.quickMenuToggled, parameters: ["expanded": isQuickMenuExpanded])
    }

    private func open(_ action: QuickAction) {
        withAnimation(.spring(response: 0.28, dampingFraction: 0.86)) { isQuickMenuExpanded = false }
        TelemetryService.shared.log(.quickActionOpened, parameters: ["action": action.telemetryName])
        presentedQuickAction = action
    }

    private var tabSelection: Binding<AppTab> {
        Binding(
            get: { selectedTab },
            set: { newTab in
                withAnimation(.snappy(duration: 0.18)) { isQuickMenuExpanded = false }
                if newTab == selectedTab { reset(newTab) }
                selectedTab = newTab
            }
        )
    }

    private func reset(_ tab: AppTab) {
        switch tab {
        case .today:     todayResetID     = UUID()
        case .train:     trainResetID     = UUID()
        case .progress:  progressResetID  = UUID()
        case .exercises: exercisesResetID = UUID()
        case .profile:   profileResetID   = UUID()
        case .calendar:  break
        }
    }

    @ViewBuilder
    private func quickActionDestination(_ action: QuickAction) -> some View {
        switch action {
        case .freeWorkout:
            NavigationStack { FreeWorkoutStartView() }
        case .scheduleWorkout:
            ScheduleWorkoutView()
        case .createPlan:
            CreatePlanView()
        case .customExercise:
            AddCustomExerciseView()
        case .timers:
            NavigationStack { TimersView() }
        }
    }

    private func applyNotificationDestination(_ destination: AppStore.NotificationDestination?) {
        guard let destination else { return }
        TelemetryService.shared.breadcrumb("notif.apply_destination", ["tab": destination.tab.telemetryName])
        select(destination.tab)
        if destination.tab == .calendar {
            store.calendarFocusedDate = destination.focusDate
            if destination.action == .logWorkout {
                store.calendarWorkoutToOpenID = destination.scheduledWorkoutID
            }
        }
        store.consumeNotificationDestination()
    }
}

// MARK: - Tab Bar Accessory (iOS 26)

private struct QuickLogTabAccessory: View {
    @Environment(\.tabViewBottomAccessoryPlacement) private var placement
    let action: () -> Void

    private var isInline: Bool { placement == .inline }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: "plus")
                    .font(.system(size: 19, weight: .bold))
                    .frame(width: 30, height: 34)
                Text(verbatim: localizedString("quick_log"))
                    .font(.system(size: isInline ? 18 : 17, weight: .bold, design: .rounded))
                    .lineLimit(1)
                    .minimumScaleFactor(0.70)
                    .layoutPriority(1)
                Spacer(minLength: 4)
                Image(systemName: "bolt.fill")
                    .font(.system(size: 20, weight: .bold))
                    .symbolRenderingMode(.hierarchical)
                    .frame(width: 30, height: 34)
            }
            .foregroundStyle(PulseTheme.textPrimary)
            .frame(maxWidth: .infinity)
            .frame(height: isInline ? 58 : 56)
            .padding(.horizontal, 16)
            .contentShape(Capsule(style: .continuous))
            .glassEffect(
                .regular.tint(PulseTheme.surfaceRaised.opacity(0.18)).interactive(),
                in: Capsule(style: .continuous)
            )
            .overlay {
                Capsule(style: .continuous)
                    .stroke(PulseTheme.cardStroke.opacity(0.9), lineWidth: 0.8)
            }
            .shadow(color: PulseTheme.surfaceShadow, radius: 12, y: 5)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(localizedString("quick_menu_open"))
    }
}

private struct QuickMenuCloseButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: "xmark")
                    .font(.system(size: 18, weight: .bold))
                    .frame(width: 34, height: 34)
                Text(verbatim: localizedString("close"))
                    .font(.system(size: 19, weight: .bold, design: .rounded))
                    .lineLimit(1)
                Spacer(minLength: 8)
                Image(systemName: "chevron.down")
                    .font(.system(size: 19, weight: .bold))
                    .symbolRenderingMode(.hierarchical)
                    .frame(width: 34, height: 34)
            }
            .foregroundStyle(PulseTheme.textPrimary)
            .frame(maxWidth: .infinity)
            .frame(height: 58)
            .padding(.horizontal, 18)
            .contentShape(Capsule(style: .continuous))
            .glassEffect(.regular.tint(PulseTheme.surfaceRaised.opacity(0.16)).interactive(), in: Capsule(style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(localizedString("quick_menu_close"))
    }
}

// MARK: - Tab Definition

/// The app's navigation destinations. `.calendar` is not shown as a tab —
/// it is opened as a sheet from wherever it is selected (see `select(_:)` in
/// `MainTabView`) since scheduling lives inside Entrenar/Progreso, not as a
/// persistent tab. See PLAN_REFORMA_INTEGRAL.md §3.1 for the IA rationale.
enum AppTab: CaseIterable {
    case today
    case train
    case progress
    case exercises
    case profile
    case calendar

    /// The 5 tabs actually rendered in the tab bar, in display order.
    static let tabBarCases: [AppTab] = [.today, .train, .progress, .exercises, .profile]

    var title: String {
        switch self {
        case .today:     localizedString("today_3")
        case .train:     localizedString("train")
        case .progress:  localizedString("progress_2")
        case .exercises: localizedString("exercises_3")
        case .profile:   localizedString("profile")
        case .calendar:  localizedString("schedule")
        }
    }

    var label: some View {
        Label {
            Text(verbatim: title)
        } icon: {
            Image(systemName: systemImage)
        }
    }

    var systemImage: String {
        switch self {
        case .today:     "sun.max.fill"
        case .train:     "dumbbell.fill"
        case .progress:  "chart.line.uptrend.xyaxis"
        case .exercises: "figure.strengthtraining.traditional"
        case .profile:   "person.crop.circle.fill"
        case .calendar:  "calendar"
        }
    }

    var telemetryName: String {
        switch self {
        case .today:     "today"
        case .train:     "train"
        case .progress:  "progress"
        case .exercises: "exercises"
        case .profile:   "profile"
        case .calendar:  "calendar"
        }
    }
}

// MARK: - Quick Actions

private enum QuickAction: String, CaseIterable, Identifiable {
    case freeWorkout
    case scheduleWorkout
    case createPlan
    case customExercise
    case timers

    var id: String { rawValue }
    var telemetryName: String { rawValue }

    var title: String {
        switch self {
        case .freeWorkout:    localizedString("train")
        case .scheduleWorkout: localizedString("schedule")
        case .createPlan:     localizedString("create_plan")
        case .customExercise: localizedString("exercise_2")
        case .timers:         localizedString("timers")
        }
    }

    var subtitle: String {
        switch self {
        case .freeWorkout:    localizedString("free_2")
        case .scheduleWorkout: localizedString("date_2")
        case .createPlan:     localizedString("routine")
        case .customExercise: localizedString("custom")
        case .timers:         localizedString("timers_subtitle")
        }
    }

    var systemImage: String {
        switch self {
        case .freeWorkout:    "play.fill"
        case .scheduleWorkout: "calendar.badge.plus"
        case .createPlan:     "square.stack.3d.up.fill"
        case .customExercise: "sparkles"
        case .timers:         "stopwatch.fill"
        }
    }
}

private struct QuickActionRow: View {
    let action: QuickAction

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .trailing, spacing: 1) {
                Text(verbatim: action.title)
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(PulseTheme.textPrimary)
                Text(verbatim: action.subtitle)
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(PulseTheme.secondaryText)
            }
            .lineLimit(1)
            .minimumScaleFactor(0.8)

            Image(systemName: action.systemImage)
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(PulseTheme.onColor(PulseTheme.accent))
                .frame(width: 44, height: 44)
                .background(PulseTheme.accent)
                .clipShape(Circle())
                .shadow(color: PulseTheme.accent.opacity(0.14), radius: 6, x: 0, y: 3)
        }
        .padding(.leading, 18)
        .padding(.trailing, 6)
        .padding(.vertical, 6)
        .background(PulseTheme.card.opacity(0.82), in: Capsule(style: .continuous))
        .overlay(Capsule(style: .continuous).stroke(PulseTheme.cardStroke, lineWidth: 0.6))
        .shadow(color: PulseTheme.surfaceShadow, radius: 7, x: 0, y: 3)
        .contentShape(Capsule())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(action.title)
        .accessibilityHint(action.subtitle)
    }
}

// MARK: - Preference Key

struct MainTabBarHiddenPreferenceKey: PreferenceKey {
    static let defaultValue = false
    static func reduce(value: inout Bool, nextValue: () -> Bool) {
        value = value || nextValue()
    }
}
