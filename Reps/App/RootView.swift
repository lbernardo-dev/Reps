import SwiftUI

struct RootView: View {
    @EnvironmentObject private var store: AppStore

    private var preferredColorScheme: ColorScheme? {
        switch store.userProfile.activeThemeMode {
        case .dark: return .dark
        case .light: return .light
        case .system: return nil
        }
    }

    var body: some View {
        Group {
            if store.userProfile.onboardingCompleted {
                MainTabView()
            } else {
                WelcomeView()
            }
        }
        .alert("Error de Almacenamiento", isPresented: Binding(
            get: { store.isUsingFallbackStorage },
            set: { store.isUsingFallbackStorage = $0 }
        )) {
            Button("Aceptar", role: .cancel) {}
        } message: {
            Text("Hubo un problema al cargar tus datos guardados. La aplicación está en modo temporal y no guardará los datos permanentemente.")
        }
        .fullScreenCover(item: $store.activePaywall) { presentation in
            PaywallView(presentation: presentation)
                .environmentObject(store)
        }
        .preferredColorScheme(preferredColorScheme)
    }
}

struct MainTabView: View {
    @EnvironmentObject private var store: AppStore
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
        ZStack(alignment: .bottom) {
            switch selectedTab {
            case .today:
                TodayView(onSelectTab: { select($0) })
                    .id(todayResetID)
            case .calendar:
                CalendarView()
                    .id(calendarResetID)
            case .plans:
                PlansView()
                    .id(plansResetID)
            case .progress:
                ProgressDashboardView()
                    .id(progressResetID)
            }

            if !isTabBarHidden {
                if isQuickMenuExpanded {
                    // Full Screen Ambient Glow Background
                    ZStack {
                        Color.black
                            .ignoresSafeArea()
                        
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
                    .ignoresSafeArea()
                    .onTapGesture {
                        withAnimation(.spring(response: 0.32, dampingFraction: 0.82)) {
                            isQuickMenuExpanded = false
                        }
                    }
                    .transition(.opacity)
                    .zIndex(1)

                    VStack {
                        QuickMenuProgressionChart()
                            .padding(.top, 10)
                            .padding(.horizontal, 16)
                        
                        Spacer()
                    }
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .zIndex(2)

                    QuickActionFan { action in
                        open(action)
                    }
                    .padding(.bottom, 82)
                    .transition(.scale(scale: 0.72, anchor: .bottom).combined(with: .opacity))
                    .zIndex(2)
                }

                BottomBarBackdrop()
                    .allowsHitTesting(false)
                    .zIndex(3)

                FloatingTabBar(
                    selectedTab: selectedTab,
                    isQuickMenuExpanded: isQuickMenuExpanded,
                    onQuickActionTap: {
                        withAnimation(.spring(response: 0.32, dampingFraction: 0.78)) {
                            isQuickMenuExpanded.toggle()
                        }
                        TelemetryService.shared.log(.quickMenuToggled, parameters: [
                            "expanded": isQuickMenuExpanded
                        ])
                    }
                ) { tab in
                    select(tab)
                }
                .padding(.horizontal, 18)
                .padding(.bottom, 2)
                .offset(y: 16)
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .zIndex(4)
            }
        }
        .ignoresSafeArea(.keyboard, edges: .bottom)
        .sheet(item: $presentedQuickAction) { action in
            quickActionDestination(action)
        }
        .sheet(item: $store.finishedSessionForSummary) { session in
            WorkoutSummaryView(session: session) {
                store.finishedSessionForSummary = nil
            }
        }
        .onAppear {
            TelemetryService.shared.log(.mainTabSelected, parameters: [
                "tab": selectedTab.telemetryName,
                "source": "initial"
            ])
        }
        .onChange(of: selectedTab) { _, newTab in
            TelemetryService.shared.log(.mainTabSelected, parameters: [
                "tab": newTab.telemetryName,
                "source": "selection"
            ])
        }
        .onPreferenceChange(MainTabBarHiddenPreferenceKey.self) { hidden in
            withAnimation(.snappy(duration: 0.22)) {
                isTabBarHidden = hidden
                if hidden {
                    isQuickMenuExpanded = false
                }
            }
        }
        .onChange(of: store.notificationDestination) { _, destination in
            guard let destination else {
                return
            }

            select(destination.tab)
            if destination.tab == .calendar {
                store.calendarFocusedDate = destination.focusDate
            }
            store.consumeNotificationDestination()
        }
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
                ActiveWorkoutView(workout: freeWorkout, origin: .free)
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

    var selectedSystemImage: String {
        switch self {
        case .today: "dumbbell.fill"
        case .calendar: "calendar"
        case .plans: "rectangle.stack.fill"
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

    var offset: CGSize {
        switch self {
        case .freeWorkout: CGSize(width: -132, height: -22)
        case .scheduleWorkout: CGSize(width: -58, height: -92)
        case .createPlan: CGSize(width: 58, height: -92)
        case .customExercise: CGSize(width: 132, height: -22)
        }
    }
}

private struct QuickActionFan: View {
    let onSelect: (QuickAction) -> Void

    var body: some View {
        ZStack {
            ForEach(Array(QuickAction.allCases.enumerated()), id: \.element.id) { index, action in
                Button {
                    onSelect(action)
                } label: {
                    QuickActionButton(action: action)
                }
                .buttonStyle(.plain)
                .offset(action.offset)
                .transition(.asymmetric(
                    insertion: .scale(scale: 0.2, anchor: .bottom).combined(with: .opacity),
                    removal: .scale(scale: 0.2, anchor: .bottom).combined(with: .opacity)
                ))
                .animation(
                    .spring(response: 0.36, dampingFraction: 0.72).delay(Double(index) * 0.035),
                    value: action.id
                )
            }
        }
        .frame(width: 360, height: 150)
        .accessibilityElement(children: .contain)
    }
}

private struct QuickActionButton: View {
    let action: QuickAction

    var body: some View {
        VStack(spacing: 7) {
            Image(systemName: action.systemImage)
                .font(.headline.weight(.bold))
                .foregroundStyle(.white)
                .frame(width: 50, height: 50)
                .background(
                    LinearGradient(
                        colors: [PulseTheme.primary, PulseTheme.accent],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .clipShape(Circle())
                .shadow(color: PulseTheme.primary.opacity(0.30), radius: 12, x: 0, y: 7)

            VStack(spacing: 1) {
                Text(action.title)
                    .font(.caption.weight(.bold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.76)
                Text(action.subtitle)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(PulseTheme.secondaryText)
                    .lineLimit(1)
            }
            .frame(width: 82)
            .padding(.horizontal, 6)
            .padding(.vertical, 5)
            .background(PulseTheme.card)
            .clipShape(Capsule())
        }
        .accessibilityLabel(action.title)
    }
}

private struct FloatingTabBar: View {
    let selectedTab: AppTab
    let isQuickMenuExpanded: Bool
    let onQuickActionTap: () -> Void
    let onSelect: (AppTab) -> Void
    
    @Namespace private var animationNamespace

    var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(AppTab.allCases.enumerated()), id: \.element) { index, tab in
                if index == 2 {
                    Button {
                        HapticService.selection()
                        onQuickActionTap()
                    } label: {
                        ZStack {
                            Circle()
                                .fill(
                                    LinearGradient(
                                        colors: [
                                            PulseTheme.accent,
                                            PulseTheme.primary
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 58, height: 58)
                                .overlay {
                                    Circle()
                                        .stroke(.white.opacity(0.26), lineWidth: 1.5)
                                }
                                .shadow(color: PulseTheme.accent.opacity(0.22), radius: 12, x: 0, y: 7)

                            Image(systemName: "plus")
                                .font(.system(size: 25, weight: .heavy))
                                .foregroundStyle(.white)
                                .rotationEffect(.degrees(isQuickMenuExpanded ? 135 : 0))
                        }
                        .scaleEffect(isQuickMenuExpanded ? 1.12 : 1.0)
                        .frame(maxWidth: .infinity)
                        .frame(height: 58)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .offset(y: -11)
                    .accessibilityLabel(isQuickMenuExpanded ? "Cerrar menú rápido" : "Abrir menú rápido")
                }
                
                Button {
                    HapticService.selection()
                    onSelect(tab)
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: selectedTab == tab ? tab.selectedSystemImage : tab.systemImage)
                            .font(.headline)
                            .foregroundStyle(selectedTab == tab ? PulseTheme.accent : PulseTheme.secondaryText)
                        Text(tab.title)
                            .font(.system(size: 10, weight: .bold))
                            .lineLimit(1)
                            .minimumScaleFactor(0.76)
                            .foregroundStyle(selectedTab == tab ? .white : PulseTheme.secondaryText)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 54)
                    .contentShape(Rectangle())
                    .background {
                        if selectedTab == tab {
                            Capsule()
                                .fill(PulseTheme.accentMuted)
                                .matchedGeometryEffect(id: "activeTabPill", in: animationNamespace)
                                .transition(.asymmetric(insertion: .identity, removal: .identity))
                        }
                    }
                }
                .buttonStyle(.plain)
                .accessibilityLabel(tab.title)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 7)
        .background {
            Capsule()
                .fill(.ultraThinMaterial)
                .overlay(Capsule().stroke(PulseTheme.separator, lineWidth: 1))
        }
        .contentShape(Capsule())
    }
}

struct MainTabBarHiddenPreferenceKey: PreferenceKey {
    static let defaultValue = false

    static func reduce(value: inout Bool, nextValue: () -> Bool) {
        value = value || nextValue()
    }
}

private struct BottomBarBackdrop: View {
    var body: some View {
        LinearGradient(
            stops: [
                .init(color: PulseTheme.background.opacity(0), location: 0),
                .init(color: PulseTheme.background.opacity(0), location: 0.34),
                .init(color: PulseTheme.background.opacity(0.88), location: 0.72),
                .init(color: PulseTheme.background, location: 1)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        .frame(height: 112)
        .ignoresSafeArea(.container, edges: .bottom)
    }
}
