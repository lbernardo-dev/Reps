import StoreKit
import SwiftUI

struct RootView: View {
  @Environment(AppStore.self) private var store
  @State private var chromeState = AppChromeState()
  @State private var showSplash = true

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
    return ZStack {
      Group {
        if showsMainInterface {
          MainTabView()
            .environment(chromeState)
        } else {
          WelcomeView()
        }
      }
      .alert(
        "storage_error",
        isPresented: Binding(
          get: { store.isUsingFallbackStorage },
          set: { store.isUsingFallbackStorage = $0 }
        )
      ) {
        Button("aceptar", role: .cancel) {}
      } message: {
        Text("there_was_a_problem_loading_your_saved_data_the_app_is_in_temporary_mode_and_wil")
      }
      .fullScreenCover(item: $store.activePaywall) { presentation in
        PaywallView(presentation: presentation)
          .environment(store)
      }

      if showSplash {
        AnimatedSplashView {
          showSplash = false
        }
        .transition(.identity)
        .zIndex(1)
      }
    }
    .preferredColorScheme(preferredColorScheme)
  }
}

// MARK: - Main Tab View

struct MainTabView: View {
  @Environment(AppStore.self) private var store
  @Environment(AppChromeState.self) private var chromeState
  @Environment(\.requestReview) private var requestReview

  @State private var selectedTab: AppTab = .today
  @State private var isQuickMenuExpanded = false
  @State private var presentedQuickAction: QuickAction?
  @State private var pendingWorkoutSummarySession: WorkoutSession?
  @State private var showCalendarSheet = false
  @State private var activePromotion: VitalsPathPromotion?
  @State private var promotionRemainingSeconds: Int = VitalsPathPromotionPolicy.visibleDuration
  @AppStorage("vitalspathPromotionPermanentlyHidden") private var isVitalsPathPromotionPermanentlyHidden = false
  @AppStorage("vitalspathPromotionOffsetX") private var vitalsPathPromotionOffsetXStorage: Double = 0
  @AppStorage("vitalspathPromotionOffsetY") private var vitalsPathPromotionOffsetYStorage: Double = 0
  @State private var vitalsPathPromotionDragTranslation: CGSize = .zero

  private var vitalsPathPromotionOffsetX: CGFloat {
    get { CGFloat(vitalsPathPromotionOffsetXStorage) }
    nonmutating set { vitalsPathPromotionOffsetXStorage = Double(newValue) }
  }

  private var vitalsPathPromotionOffsetY: CGFloat {
    get { CGFloat(vitalsPathPromotionOffsetYStorage) }
    nonmutating set { vitalsPathPromotionOffsetYStorage = Double(newValue) }
  }

  init() {
    _selectedTab = State(initialValue: Self.initialTabFromLaunchArguments())
  }

  var body: some View {
    @Bindable var store = store
    return
      activeTabSurface
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
      .overlay {
        promotionOverlay
      }
      .ignoresSafeArea(.keyboard, edges: .bottom)
      .sheet(
        item: $presentedQuickAction,
        onDismiss: {
          if let pending = pendingWorkoutSummarySession {
            pendingWorkoutSummarySession = nil
            store.finishedSessionForSummary = pending
          }
        }
      ) { action in
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
        TelemetryService.shared.log(
          .mainTabSelected,
          parameters: [
            "tab": selectedTab.telemetryName,
            "source": "initial",
          ])
        applyNotificationDestination(store.notificationDestination)
        consumePendingFreeWorkoutPresentation()
      }
      .onChange(of: selectedTab) { _, newTab in
        TelemetryService.shared.log(
          .mainTabSelected,
          parameters: [
            "tab": newTab.telemetryName,
            "source": "selection",
          ])
      }
      .onChange(of: store.pendingReviewRequest) { _, shouldRequest in
        if shouldRequest {
          store.pendingReviewRequest = false
          requestReview()
        }
      }
      .onChange(of: chromeState.isTabBarHidden) { _, hidden in
        guard hidden else { return }
        withAnimation(.snappy(duration: 0.22)) {
          isQuickMenuExpanded = false
        }
      }
      .onChange(of: store.pendingFreeWorkoutPresentation) { _, shouldPresent in
        guard shouldPresent else { return }
        consumePendingFreeWorkoutPresentation()
      }
      .onChange(of: store.notificationDestination) { _, destination in
        applyNotificationDestination(destination)
      }
      .onChange(of: store.pendingMainTabSelection) { _, tab in
        guard let tab else { return }
        select(tab)
        store.pendingMainTabSelection = nil
      }
      .task {
        await runVitalsPathPromotionScheduler()
      }
  }

  private func consumePendingFreeWorkoutPresentation() {
    guard store.pendingFreeWorkoutPresentation else { return }
    store.pendingFreeWorkoutPresentation = false
    select(.today)
    presentedQuickAction = .freeWorkout
  }

  // MARK: VitalsPath promotion

  @ViewBuilder
  private var promotionOverlay: some View {
    if let activePromotion,
       activePromotion.tab == selectedTab,
       !isVitalsPathPromotionPermanentlyHidden,
       !isQuickMenuExpanded,
       presentedQuickAction == nil,
       !chromeState.isTabBarHidden,
       store.finishedSessionForSummary == nil {
      GeometryReader { proxy in
        let maxDX = max(0, proxy.size.width / 2 - 48)
        let maxDY = max(0, proxy.size.height / 2 - 72)

        VitalsPathPromotionBanner(
          isPremium: store.hasProAccess,
          remainingSeconds: promotionRemainingSeconds,
          dismissCurrent: dismissCurrentPromotion,
          dismissPermanently: dismissPromotionPermanently,
          onDragChanged: { translation in
            vitalsPathPromotionDragTranslation = translation
          },
          onDragEnded: { translation in
            commitVitalsPathPromotionDrag(translation, maxDX: maxDX, maxDY: maxDY)
          }
        )
        .padding(.horizontal, PulseTheme.screenHorizontalPadding)
        .padding(.top, activePromotion.placement == .top ? proxy.safeAreaInsets.top + 56 : 0)
        .padding(.bottom, activePromotion.placement == .bottom ? proxy.safeAreaInsets.bottom + 118 : 0)
        .frame(
          maxWidth: .infinity,
          maxHeight: .infinity,
          alignment: activePromotion.placement.alignment
        )
        .offset(
          x: clamp(vitalsPathPromotionOffsetX + vitalsPathPromotionDragTranslation.width, to: -maxDX...maxDX),
          y: clamp(vitalsPathPromotionOffsetY + vitalsPathPromotionDragTranslation.height, to: -maxDY...maxDY)
        )
        .transition(
          .move(edge: activePromotion.placement.transitionEdge)
            .combined(with: .opacity)
        )
      }
      .allowsHitTesting(true)
    }
  }

  private func commitVitalsPathPromotionDrag(_ translation: CGSize, maxDX: CGFloat, maxDY: CGFloat) {
    vitalsPathPromotionOffsetX = clamp(vitalsPathPromotionOffsetX + translation.width, to: -maxDX...maxDX)
    vitalsPathPromotionOffsetY = clamp(vitalsPathPromotionOffsetY + translation.height, to: -maxDY...maxDY)
    vitalsPathPromotionDragTranslation = .zero
    TelemetryService.shared.breadcrumb("vitalspath_promo.repositioned")
  }

  private func clamp(_ value: CGFloat, to range: ClosedRange<CGFloat>) -> CGFloat {
    min(max(value, range.lowerBound), range.upperBound)
  }

  /// Runs for the lifetime of the tab view: periodically rolls whether to show the
  /// promotion, displays it for `visibleDuration` seconds, then waits a fresh random
  /// interval before rolling again — repeating for as long as the app is in use.
  private func runVitalsPathPromotionScheduler() async {
    #if DEBUG
      if ProcessInfo.processInfo.arguments.contains("-showVitalsPathPromotion") {
        await presentVitalsPathPromotion(
          VitalsPathPromotion(tab: selectedTab, placement: .top)
        )
      }
    #endif

    while !Task.isCancelled {
      let delay = Double.random(
        in: VitalsPathPromotionPolicy.minimumInterval...VitalsPathPromotionPolicy.maximumInterval
      )
      do {
        try await Task.sleep(for: .seconds(delay))
      } catch {
        return
      }

      // Never interrupt a brand-new user: cross-promotion only starts once
      // they have at least one completed workout behind them.
      guard !isVitalsPathPromotionPermanentlyHidden,
            !store.workoutSessions.isEmpty,
            activePromotion == nil,
            !isQuickMenuExpanded,
            presentedQuickAction == nil,
            !chromeState.isTabBarHidden,
            store.finishedSessionForSummary == nil
      else { continue }

      guard let promotion = VitalsPathPromotionPolicy.promotion(
        for: selectedTab,
        appearanceRoll: .random(in: 0..<1),
        placementRoll: .random(in: 0..<1)
      ) else { continue }

      await presentVitalsPathPromotion(promotion)
    }
  }

  private func presentVitalsPathPromotion(_ promotion: VitalsPathPromotion) async {
    withAnimation(.spring(response: 0.38, dampingFraction: 0.86)) {
      activePromotion = promotion
    }
    TelemetryService.shared.breadcrumb(
      "vitalspath_promo.impression",
      ["tab": promotion.tab.telemetryName]
    )

    promotionRemainingSeconds = VitalsPathPromotionPolicy.visibleDuration
    while promotionRemainingSeconds > 0 {
      do {
        try await Task.sleep(for: .seconds(1))
      } catch {
        return
      }
      guard activePromotion == promotion else { return }
      promotionRemainingSeconds -= 1
    }

    guard activePromotion == promotion else { return }
    withAnimation(.easeOut(duration: 0.2)) {
      activePromotion = nil
    }
    TelemetryService.shared.breadcrumb("vitalspath_promo.auto_hide")
  }

  private func dismissCurrentPromotion() {
    withAnimation(.easeOut(duration: 0.2)) {
      activePromotion = nil
    }
    TelemetryService.shared.breadcrumb("vitalspath_promo.dismiss_current")
  }

  private func dismissPromotionPermanently() {
    guard store.hasProAccess else { return }
    isVitalsPathPromotionPermanentlyHidden = true
    withAnimation(.easeOut(duration: 0.2)) {
      activePromotion = nil
    }
    TelemetryService.shared.breadcrumb("vitalspath_promo.dismiss_permanently")
  }

  // MARK: Tab shell

  private var showsQuickActionAccessory: Bool {
    !isQuickMenuExpanded &&
    presentedQuickAction == nil &&
    !chromeState.isTabBarHidden &&
    !chromeState.isQuickActionAccessoryHidden
  }

  // The tab shell stays mounted while the quick menu or a quick-action sheet
  // is up — swapping it out for a flat background here used to reset every
  // tab's scroll position and navigation state on each open. The quick-menu
  // overlay draws its own opaque backdrop above this surface.
  private var activeTabSurface: some View {
    tabShell
      .accessibilityHidden(isQuickMenuExpanded)
  }

  @ViewBuilder
  private var tabShell: some View {
    if #available(iOS 26.1, *) {
      tabShellBase
        .tabViewBottomAccessory(isEnabled: showsQuickActionAccessory) {
          QuickLogTabAccessory { toggleQuickMenu() }
        }
    } else {
      tabShellBase
        .tabViewBottomAccessory {
          QuickLogTabAccessory { toggleQuickMenu() }
        }
    }
  }

  private var tabShellBase: some View {
    tabViewContent
      .environment(\.navigateToToday, NavigateToTodayAction {
        select(.today)
      })
      .tabBarMinimizeBehavior(.onScrollDown)
  }

  private var tabViewContent: some View {
    TabView(selection: tabSelection) {
      // — Hoy: readiness + today's plan + streak. No deep analytics.
      Tab(value: AppTab.today) {
        TodayView(onSelectTab: { select($0) })
          .toolbar(chromeState.isTabBarHidden ? .hidden : .visible, for: .tabBar)
      } label: {
        AppTab.today.label
      }

      // — Entrenar: quick start, plans/routines, library, tools, schedule.
      Tab(value: AppTab.train) {
        PlansView()
          .toolbar(chromeState.isTabBarHidden ? .hidden : .visible, for: .tabBar)
      } label: {
        AppTab.train.label
      }

      // — Progreso: analytics, trends, records, history.
      Tab(value: AppTab.progress) {
        ProgressDashboardView(onSelectTab: { select($0) })
          .toolbar(chromeState.isTabBarHidden ? .hidden : .visible, for: .tabBar)
      } label: {
        AppTab.progress.label
      }

      // — Ejercicios: browse and manage the exercise library.
      Tab(value: AppTab.exercises) {
        ExerciseLibraryView(isTabRoot: true)
          .toolbar(chromeState.isTabBarHidden ? .hidden : .visible, for: .tabBar)
      } label: {
        AppTab.exercises.label
      }

      // — Perfil: body, achievements, social, gym, settings. Rendered as a
      // detached avatar bubble (role: .search) à la Apple Music's search tab.
      Tab(value: AppTab.profile, role: .search) {
        NavigationStack {
          ProfileView(isTabRoot: true)
        }
        .toolbar(chromeState.isTabBarHidden ? .hidden : .visible, for: .tabBar)
      } label: {
        profileTabLabel
      }
    }
    .tint(MetricDomain.strength.tint)
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
    ProfileTabAvatarLabel(data: store.userProfile.avatarImageData)
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

  private static func initialTabFromLaunchArguments() -> AppTab {
    #if DEBUG
    let arguments = ProcessInfo.processInfo.arguments
    guard let index = arguments.firstIndex(of: "-initialTab"),
          arguments.indices.contains(arguments.index(after: index))
    else {
      return .today
    }
    switch arguments[arguments.index(after: index)].lowercased() {
    case "train", "entrenar":
      return .train
    case "progress", "progreso":
      return .progress
    case "exercises", "ejercicios":
      return .exercises
    case "profile", "perfil":
      return .profile
    default:
      return .today
    }
    #else
    return .today
    #endif
  }

  private func reset(_ tab: AppTab) {
    TelemetryService.shared.log(.mainTabSelected, parameters: [
      "tab": tab.telemetryName,
      "source": "reselect",
    ])
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
    TelemetryService.shared.breadcrumb(
      "notif.apply_destination", ["tab": destination.tab.telemetryName])
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

private struct ProfileTabAvatarLabel: View {
  private struct Signature: Hashable {
    let count: Int
    let prefix: UInt64
    let suffix: UInt64
  }

  let data: Data?
  @State private var renderedAvatar: UIImage?

  var body: some View {
    Group {
      if let renderedAvatar {
        Image(uiImage: renderedAvatar)
          .renderingMode(.original)
          .accessibilityLabel(Text(verbatim: AppTab.profile.title))
      } else {
        AppTab.profile.label
      }
    }
    .task(id: signature) {
      guard let data else {
        renderedAvatar = nil
        return
      }
      renderedAvatar = Self.circularTabAvatar(from: data)
    }
  }

  private var signature: Signature? {
    guard let data else { return nil }
    return Signature(
      count: data.count,
      prefix: data.prefix(8).reduce(0) { ($0 << 8) | UInt64($1) },
      suffix: data.suffix(8).reduce(0) { ($0 << 8) | UInt64($1) }
    )
  }

  private static func circularTabAvatar(from data: Data, diameter: CGFloat = 44) -> UIImage? {
    guard let source = UIImage(data: data) else { return nil }
    let format = UIGraphicsImageRendererFormat()
    format.scale = UITraitCollection.current.displayScale
    format.opaque = false
    let size = CGSize(width: diameter, height: diameter)
    let rendered = UIGraphicsImageRenderer(size: size, format: format).image { _ in
      UIBezierPath(ovalIn: CGRect(origin: .zero, size: size)).addClip()
      let fillScale = max(size.width / source.size.width, size.height / source.size.height)
      let scaledSize = CGSize(
        width: source.size.width * fillScale, height: source.size.height * fillScale)
      let origin = CGPoint(
        x: (size.width - scaledSize.width) / 2,
        y: (size.height - scaledSize.height) / 2
      )
      source.draw(in: CGRect(origin: origin, size: scaledSize))
    }
    return rendered.withRenderingMode(.alwaysOriginal)
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
      .frame(maxWidth: .infinity)
      .frame(height: isInline ? 58 : 56)
      .padding(.horizontal, 16)
      .contentShape(Capsule(style: .continuous))
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
      //.foregroundStyle(PulseTheme.textPrimary)
      .frame(maxWidth: .infinity)
      .frame(height: 58)
      .padding(.horizontal, 18)
      .contentShape(Capsule(style: .continuous))
      .destructiveGlassCapsule(.translucent)
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
    case .today: localizedString("today_3")
    case .train: localizedString("train")
    case .progress: localizedString("progress_2")
    case .exercises: localizedString("exercises_3")
    case .profile: localizedString("profile")
    case .calendar: localizedString("schedule")
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
    case .today: "sun.max.fill"
    case .train: "dumbbell.fill"
    case .progress: "chart.line.uptrend.xyaxis"
    case .exercises: "figure.strengthtraining.traditional"
    case .profile: "person.crop.circle.fill"
    case .calendar: "calendar"
    }
  }

  var telemetryName: String {
    switch self {
    case .today: "today"
    case .train: "train"
    case .progress: "progress"
    case .exercises: "exercises"
    case .profile: "profile"
    case .calendar: "calendar"
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
    case .freeWorkout: localizedString("train")
    case .scheduleWorkout: localizedString("schedule")
    case .createPlan: localizedString("create_plan")
    case .customExercise: localizedString("exercise_2")
    case .timers: localizedString("timers")
    }
  }

  var subtitle: String {
    switch self {
    case .freeWorkout: localizedString("free_2")
    case .scheduleWorkout: localizedString("date_2")
    case .createPlan: localizedString("routine")
    case .customExercise: localizedString("custom")
    case .timers: localizedString("timers_subtitle")
    }
  }

  var systemImage: String {
    switch self {
    case .freeWorkout: "play.fill"
    case .scheduleWorkout: "calendar.badge.plus"
    case .createPlan: "square.stack.3d.up.fill"
    case .customExercise: "sparkles"
    case .timers: "stopwatch.fill"
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
        .foregroundStyle(PulseTheme.onColor(action == .freeWorkout ? PulseTheme.playControl : PulseTheme.accent))
        .frame(width: 44, height: 44)
        .background(action == .freeWorkout ? PulseTheme.playControl : PulseTheme.accent)
        .clipShape(Circle())
        .shadow(color: (action == .freeWorkout ? PulseTheme.playControl : PulseTheme.accent).opacity(0.14), radius: 6, x: 0, y: 3)
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

@MainActor
@Observable
final class AppChromeState {
  private var tabBarHiddenTokens: Set<UUID> = []
  private var quickActionAccessoryHiddenTokens: Set<UUID> = []

  var isTabBarHidden: Bool {
    !tabBarHiddenTokens.isEmpty
  }

  var isQuickActionAccessoryHidden: Bool {
    !quickActionAccessoryHiddenTokens.isEmpty
  }

  func setTabBarHidden(token: UUID, hidden: Bool) {
    if hidden {
      tabBarHiddenTokens.insert(token)
    } else {
      tabBarHiddenTokens.remove(token)
    }
  }

  func setQuickActionAccessoryHidden(token: UUID, hidden: Bool) {
    if hidden {
      quickActionAccessoryHiddenTokens.insert(token)
    } else {
      quickActionAccessoryHiddenTokens.remove(token)
    }
  }
}

struct NavigateToTodayAction: Sendable {
  let action: @MainActor @Sendable () -> Void

  init(_ action: @escaping @MainActor @Sendable () -> Void = {}) {
    self.action = action
  }

  @MainActor
  func callAsFunction() {
    action()
  }
}

private struct NavigateToTodayKey: EnvironmentKey {
  static let defaultValue = NavigateToTodayAction()
}

extension EnvironmentValues {
  var navigateToToday: NavigateToTodayAction {
    get { self[NavigateToTodayKey.self] }
    set { self[NavigateToTodayKey.self] = newValue }
  }
}
