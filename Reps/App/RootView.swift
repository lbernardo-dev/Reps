import SwiftUI

struct RootView: View {
    @EnvironmentObject private var store: AppStore

    var body: some View {
        Group {
            if store.userProfile.onboardingCompleted {
                MainTabView()
            } else {
                WelcomeView()
            }
        }
    }
}

struct MainTabView: View {
    @State private var selectedTab: AppTab = .today
    @State private var isTabBarHidden = false
    @State private var isQuickMenuExpanded = false
    @State private var presentedQuickAction: QuickAction?
    @State private var todayResetID = UUID()
    @State private var calendarResetID = UUID()
    @State private var plansResetID = UUID()
    @State private var progressResetID = UUID()
    @State private var profileResetID = UUID()

    private var freeWorkout: WorkoutDay {
        WorkoutDay(
            title: "Entrenamiento libre",
            subtitle: "Añade ejercicios durante la sesión",
            durationMinutes: 45,
            exercises: []
        )
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            switch selectedTab {
            case .today:
                TodayView()
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
            case .profile:
                ProfileView()
                    .id(profileResetID)
            }

            if !isTabBarHidden {
                if isQuickMenuExpanded {
                    Color.black.opacity(0.58)
                        .ignoresSafeArea()
                        .onTapGesture {
                            withAnimation(.spring(response: 0.32, dampingFraction: 0.82)) {
                                isQuickMenuExpanded = false
                            }
                        }
                        .transition(.opacity)
                        .zIndex(1)

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
        .onPreferenceChange(MainTabBarHiddenPreferenceKey.self) { hidden in
            withAnimation(.snappy(duration: 0.22)) {
                isTabBarHidden = hidden
                if hidden {
                    isQuickMenuExpanded = false
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    private func select(_ tab: AppTab) {
        withAnimation(.snappy(duration: 0.22)) {
            isQuickMenuExpanded = false
            if tab == selectedTab {
                reset(tab)
            }
            selectedTab = tab
        }
    }

    private func open(_ action: QuickAction) {
        withAnimation(.spring(response: 0.28, dampingFraction: 0.86)) {
            isQuickMenuExpanded = false
        }
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
        case .profile:
            profileResetID = UUID()
        }
    }
}

private enum AppTab: CaseIterable {
    case progress
    case today
    case plans
    case calendar
    case profile

    var title: LocalizedStringKey {
        switch self {
        case .today: "Entreno"
        case .calendar: "Agenda"
        case .plans: "Programas"
        case .progress: "Progreso"
        case .profile: "Perfil"
        }
    }

    var systemImage: String {
        switch self {
        case .today: "dumbbell"
        case .calendar: "calendar"
        case .plans: "waterbottle"
        case .progress: "chart.bar.fill"
        case .profile: "person"
        }
    }

    var selectedSystemImage: String {
        switch self {
        case .today: "dumbbell.fill"
        case .calendar: "calendar"
        case .plans: "waterbottle.fill"
        case .progress: "chart.bar.fill"
        case .profile: "person.fill"
        }
    }
}

private enum QuickAction: String, CaseIterable, Identifiable {
    case freeWorkout
    case scheduleWorkout
    case createPlan
    case customExercise

    var id: String { rawValue }

    var title: LocalizedStringKey {
        switch self {
        case .freeWorkout: "Entrenar"
        case .scheduleWorkout: "Programar"
        case .createPlan: "Crear plan"
        case .customExercise: "Ejercicio"
        }
    }

    var subtitle: LocalizedStringKey {
        switch self {
        case .freeWorkout: "Libre"
        case .scheduleWorkout: "Fecha"
        case .createPlan: "Rutina"
        case .customExercise: "Propio"
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

    var body: some View {
        HStack(spacing: 0) {
            ForEach(AppTab.allCases, id: \.self) { tab in
                Button {
                    onSelect(tab)
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: selectedTab == tab ? tab.selectedSystemImage : tab.systemImage)
                            .font(.headline)
                        Text(tab.title)
                            .font(.caption2.weight(.semibold))
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .foregroundStyle(selectedTab == tab ? .white : PulseTheme.secondaryText)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(tab.title)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial)
        .clipShape(Capsule())
        .overlay(Capsule().stroke(PulseTheme.separator, lineWidth: 1))
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
