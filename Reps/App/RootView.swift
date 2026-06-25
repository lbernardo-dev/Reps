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
        case .dark: return .dark
        case .light: return .light
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

struct MainTabView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.requestReview) private var requestReview
    @State private var selectedTab: AppTab = .today
    @State private var isTabBarHidden = false
    @State private var isQuickMenuExpanded = false
    @State private var presentedQuickAction: QuickAction?
    @State private var todayResetID = UUID()
    @State private var calendarResetID = UUID()
    @State private var plansResetID = UUID()
    @State private var progressResetID = UUID()

    private var freeWorkout: WorkoutDay {
        WorkoutDay.freeWorkout
    }

    var body: some View {
        @Bindable var store = store
        return nativeTabView
            .overlay(alignment: .bottom) {
                if isQuickMenuExpanded {
                    quickMenuOverlay
                }
            }
            .overlay(alignment: .bottomTrailing) {
                if showsLegacyQuickActionButton {
                    quickActionFloatingButton
                        .padding(.trailing, 16)
                        .padding(.bottom, quickActionFloatingButtonBottomPadding)
                        .animation(.spring(response: 0.32, dampingFraction: 0.78), value: isQuickMenuExpanded)
                        .transition(.scale(scale: 0.6, anchor: .bottomTrailing).combined(with: .opacity))
                }
            }
            .overlay {
                if !store.pendingAchievementUnlocks.isEmpty {
                    AchievementUnlockOverlay()
                        .environment(store)
                }
            }
            .ignoresSafeArea(.keyboard, edges: .bottom)
        .sheet(item: $presentedQuickAction) { action in
            quickActionDestination(action)
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
        .onAppear {
            TelemetryService.shared.log(.mainTabSelected, parameters: [
                "tab": selectedTab.telemetryName,
                "source": "initial"
            ])
            // Cold launch / post-onboarding: a notification destination set
            // before this view mounted is not delivered by .onChange, so drain
            // any pending destination here as well.
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
                if hidden {
                    isQuickMenuExpanded = false
                }
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

    private func applyNotificationDestination(_ destination: AppStore.NotificationDestination?) {
        guard let destination else {
            return
        }

        TelemetryService.shared.breadcrumb("notif.apply_destination", [
            "tab": destination.tab.telemetryName
        ])
        select(destination.tab)
        if destination.tab == .calendar {
            store.calendarFocusedDate = destination.focusDate
            if destination.action == .logWorkout {
                store.calendarWorkoutToOpenID = destination.scheduledWorkoutID
            }
        }
        store.consumeNotificationDestination()
    }

    @ViewBuilder
    private var nativeTabView: some View {
        if #available(iOS 26.0, *) {
            mainTabView
                .tabViewBottomAccessory {
                    if !isQuickMenuExpanded {
                        QuickLogTabAccessory {
                            toggleQuickMenu()
                        }
                    }
                }
                .tabBarMinimizeBehavior(.onScrollDown)
        } else {
            mainTabView
        }
    }

    private var mainTabView: some View {
        TabView(selection: tabSelection) {
            TodayView(onSelectTab: { select($0) })
                .id(todayResetID)
                .toolbar(isMainTabBarHidden ? .hidden : .visible, for: .tabBar)
                .tabItem { Label(AppTab.today.title, systemImage: AppTab.today.systemImage) }
                .tag(AppTab.today)

            CalendarView()
                .id(calendarResetID)
                .toolbar(isMainTabBarHidden ? .hidden : .visible, for: .tabBar)
                .tabItem { Label(AppTab.calendar.title, systemImage: AppTab.calendar.systemImage) }
                .tag(AppTab.calendar)

            PlansView()
                .id(plansResetID)
                .toolbar(isMainTabBarHidden ? .hidden : .visible, for: .tabBar)
                .tabItem { Label(AppTab.plans.title, systemImage: AppTab.plans.systemImage) }
                .tag(AppTab.plans)

            ProgressDashboardView(onSelectTab: { select($0) })
                .id(progressResetID)
                .toolbar(isMainTabBarHidden ? .hidden : .visible, for: .tabBar)
                .tabItem { Label(AppTab.progress.title, systemImage: AppTab.progress.systemImage) }
                .tag(AppTab.progress)
        }
    }

    private var isMainTabBarHidden: Bool {
        if isTabBarHidden {
            return true
        }
        if #available(iOS 26.0, *) {
            return isQuickMenuExpanded
        }
        return false
    }

    private var showsLegacyQuickActionButton: Bool {
        guard !isTabBarHidden else {
            return false
        }
        if #available(iOS 26.0, *) {
            return false
        }
        return true
    }

    private var tabSelection: Binding<AppTab> {
        Binding(
            get: { selectedTab },
            set: { newTab in
                withAnimation(.snappy(duration: 0.18)) {
                    isQuickMenuExpanded = false
                }
                if newTab == selectedTab {
                    reset(newTab)
                }
                selectedTab = newTab
            }
        )
    }

    private var quickActionFloatingButton: some View {
        Button {
            toggleQuickMenu()
        } label: {
            ZStack {
                Image(systemName: "plus")
                    .font(.system(size: isQuickMenuExpanded ? 25 : 22, weight: .heavy))
                    .foregroundStyle(.white)
                    .rotationEffect(.degrees(isQuickMenuExpanded ? 135 : 0))
            }
            .frame(width: quickActionButtonSize, height: quickActionButtonSize)
            .navigationGlassCircle(.primary)
            .scaleEffect(isQuickMenuExpanded ? 1.08 : 1.0)
            .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(isQuickMenuExpanded ? localizedString("quick_menu_close") : localizedString("quick_menu_open"))
    }

    private var quickActionFloatingButtonBottomPadding: CGFloat {
        isQuickMenuExpanded ? 18 : 74
    }

    private var quickActionButtonSize: CGFloat {
        isQuickMenuExpanded ? 58 : 52
    }

    /// The active window's top safe-area inset. The quick-menu overlay can be hosted by views
    /// that already bleed under the status bar, so geometry alone can occasionally report 0.
    private var windowTopSafeAreaInset: CGFloat {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .filter { $0.activationState == .foregroundActive }
            .flatMap(\.windows)
            .map { $0.safeAreaInsets.top }
            .max() ?? 0
    }

    private var quickMenuOverlay: some View {
        GeometryReader { proxy in
            quickMenuOverlayContent(
                topInset: max(proxy.safeAreaInsets.top, windowTopSafeAreaInset),
                bottomInset: proxy.safeAreaInsets.bottom
            )
        }
        .ignoresSafeArea(.container, edges: .top)
    }

    private func quickMenuTopPadding(for topInset: CGFloat) -> CGFloat {
        max(topInset + 32, 96)
    }

    private func quickMenuOverlayContent(topInset: CGFloat, bottomInset: CGFloat) -> some View {
        VStack(spacing: 0) {
            QuickMenuProgressionChart()
                .padding(.top, quickMenuTopPadding(for: topInset))
                .padding(.horizontal, 16)
                .transition(.move(edge: .top).combined(with: .opacity))

            Spacer(minLength: 16)

            VStack(alignment: .trailing, spacing: 11) {
                Text("quick_actions")
                    .font(.system(size: 10, weight: .black, design: .rounded))
                    .tracking(2)
                    .textCase(.uppercase)
                    .foregroundStyle(.white.opacity(0.45))
                    .padding(.trailing, 8)
                    .padding(.bottom, 2)

                ForEach(Array(QuickAction.allCases.enumerated()), id: \.element.id) { index, action in
                    Button {
                        open(action)
                    } label: {
                        QuickActionRow(action: action)
                    }
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
            .padding(.bottom, quickMenuActionsBottomPadding)

            if #available(iOS 26.0, *) {
                QuickMenuCloseButton {
                    toggleQuickMenu()
                }
                .padding(.horizontal, 16)
                .padding(.bottom, max(bottomInset, 12) + 12)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
        .background { quickMenuBackdrop(bottomInset: bottomInset) }
    }

    private var quickMenuActionsBottomPadding: CGFloat {
        if #available(iOS 26.0, *) {
            return 18
        }
        return 172
    }

    @ViewBuilder
    private func quickMenuBackdrop(bottomInset: CGFloat) -> some View {
        if #available(iOS 26.0, *) {
            quickMenuBackdropFill
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture {
                    withAnimation(.spring(response: 0.32, dampingFraction: 0.82)) {
                        isQuickMenuExpanded = false
                    }
                }
                .transition(.opacity)
        } else {
            quickMenuBackdropFill
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

    private var quickMenuBackdropFill: some View {
        ZStack {
            Color.black

            Circle()
                .fill(PulseTheme.accent.opacity(0.07))
                .frame(width: 320, height: 320)
                .blur(radius: 80)
                .offset(x: -160, y: -260)

            Circle()
                .fill(PulseTheme.primaryBright.opacity(0.05))
                .frame(width: 320, height: 320)
                .blur(radius: 80)
                .offset(x: 160, y: -220)
        }
        .background(.ultraThinMaterial)
    }

    private func select(_ tab: AppTab) {
        withAnimation(.snappy(duration: 0.18)) {
            isQuickMenuExpanded = false
        }

        if tab == selectedTab {
            reset(tab)
        }
        selectedTab = tab
    }

    private func toggleQuickMenu() {
        HapticService.selection()
        withAnimation(.spring(response: 0.32, dampingFraction: 0.78)) {
            isQuickMenuExpanded.toggle()
        }
        TelemetryService.shared.log(.quickMenuToggled, parameters: [
            "expanded": isQuickMenuExpanded
        ])
    }

    private func open(_ action: QuickAction) {
        withAnimation(.spring(response: 0.28, dampingFraction: 0.86)) {
            isQuickMenuExpanded = false
        }
        TelemetryService.shared.log(.quickActionOpened, parameters: [
            "action": action.telemetryName
        ])
        presentedQuickAction = action
    }

    @ViewBuilder
    private func quickActionDestination(_ action: QuickAction) -> some View {
        switch action {
        case .freeWorkout:
            NavigationStack {
                FreeWorkoutStartView()
            }
        case .scheduleWorkout:
            ScheduleWorkoutView()
        case .createPlan:
            CreatePlanView()
        case .customExercise:
            AddCustomExerciseView()
        }
    }

    private func reset(_ tab: AppTab) {
        switch tab {
        case .today:
            todayResetID = UUID()
        case .calendar:
            calendarResetID = UUID()
        case .plans:
            plansResetID = UUID()
        case .progress:
            progressResetID = UUID()
        }
    }
}

@available(iOS 26.0, *)
private struct QuickLogTabAccessory: View {
    @Environment(\.tabViewBottomAccessoryPlacement) private var placement

    let action: () -> Void

    private var isInline: Bool {
        placement == .inline
    }

    var body: some View {
        Button(action: action) {
            accessoryContent
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: isInline ? 58 : 56)
                .contentShape(Capsule(style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(localizedString("quick_menu_open"))
    }

    private var accessoryContent: some View {
        HStack(spacing: 12) {
            Image(systemName: "plus")
                .font(.system(size: 19, weight: .bold))
                .frame(width: 34, height: 34)

            Text("Quick Log")
                .font(.system(size: isInline ? 19 : 18, weight: .bold, design: .rounded))
                .lineLimit(1)
                .minimumScaleFactor(0.82)

            Spacer(minLength: 8)

            Image(systemName: "bolt.fill")
                .font(.system(size: 20, weight: .bold))
                .symbolRenderingMode(.hierarchical)
                .frame(width: 34, height: 34)
        }
    }
}

@available(iOS 26.0, *)
private struct QuickMenuCloseButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: "xmark")
                    .font(.system(size: 18, weight: .bold))
                    .frame(width: 34, height: 34)

                Text("Close")
                    .font(.system(size: 19, weight: .bold, design: .rounded))
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)

                Spacer(minLength: 8)

                Image(systemName: "chevron.down")
                    .font(.system(size: 19, weight: .bold))
                    .symbolRenderingMode(.hierarchical)
                    .frame(width: 34, height: 34)
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 58)
            .padding(.horizontal, 18)
            .contentShape(Capsule(style: .continuous))
            .glassEffect(.regular.interactive(), in: Capsule(style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(localizedString("quick_menu_close"))
    }
}

enum AppTab: CaseIterable {
    case progress
    case today
    case plans
    case calendar

    var title: LocalizedStringKey {
        switch self {
        case .today: "Workout"
        case .calendar: "Calendar"
        case .plans: "Plans"
        case .progress: "Progress"
        }
    }

    var systemImage: String {
        switch self {
        case .today: "dumbbell"
        case .calendar: "calendar"
        case .plans: "rectangle.stack"
        case .progress: "chart.bar.fill"
        }
    }

    var telemetryName: String {
        switch self {
        case .today: "today"
        case .calendar: "calendar"
        case .plans: "plans"
        case .progress: "progress"
        }
    }
}

private enum QuickAction: String, CaseIterable, Identifiable {
    case freeWorkout
    case scheduleWorkout
    case createPlan
    case customExercise

    var id: String { rawValue }

    var telemetryName: String { rawValue }

    var title: LocalizedStringKey {
        switch self {
        case .freeWorkout: "Train"
        case .scheduleWorkout: "Schedule"
        case .createPlan: "Create Plan"
        case .customExercise: "Exercise"
        }
    }

    var subtitle: LocalizedStringKey {
        switch self {
        case .freeWorkout: "Free"
        case .scheduleWorkout: "Date"
        case .createPlan: "Routine"
        case .customExercise: "Custom"
        }
    }

    var systemImage: String {
        switch self {
        case .freeWorkout: "play.fill"
        case .scheduleWorkout: "calendar.badge.plus"
        case .createPlan: "square.stack.3d.up.fill"
        case .customExercise: "sparkles"
        }
    }

}

private struct QuickActionRow: View {
    let action: QuickAction

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .trailing, spacing: 1) {
                Text(action.title)
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                Text(action.subtitle)
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(PulseTheme.secondaryText)
            }
            .lineLimit(1)
            .minimumScaleFactor(0.8)

            Image(systemName: action.systemImage)
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 44, height: 44)
                .background(PulseTheme.fitActionGradient)
                .clipShape(Circle())
                .shadow(color: PulseTheme.fitOrange.opacity(0.35), radius: 8, x: 0, y: 4)
        }
        .padding(.leading, 18)
        .padding(.trailing, 6)
        .padding(.vertical, 6)
        .background(.ultraThinMaterial, in: Capsule())
        .overlay(
            Capsule()
                .stroke(.white.opacity(0.10), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.30), radius: 14, x: 0, y: 6)
        .contentShape(Capsule())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(action.title)
        .accessibilityHint(action.subtitle)
    }
}


struct MainTabBarHiddenPreferenceKey: PreferenceKey {
    static let defaultValue = false

    static func reduce(value: inout Bool, nextValue: () -> Bool) {
        value = value || nextValue()
    }
}
