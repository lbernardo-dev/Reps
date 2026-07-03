import CryptoKit
import MuscleMap
import SwiftUI

// MARK: - Design Tokens

enum PulseTheme {

    // MARK: Brand accent — single tunable token
    static let accent = Color(red: 0.69, green: 0.99, blue: 0.16)      // neon green  #B0FC29

    // MARK: Activity ring semantics (mirrors Apple Fitness)
    static let ringMove     = Color(red: 0.98, green: 0.07, blue: 0.31) // red-pink    #FA1250
    static let ringExercise = Color(red: 0.57, green: 0.91, blue: 0.16) // green       #92E82A
    static let ringStand    = Color(red: 0.12, green: 0.92, blue: 0.94) // cyan        #1EEAEF

    // MARK: Semantic / functional
    static let destructive  = Color(red: 0.93, green: 0.24, blue: 0.22)
    static let warning      = Color(red: 1.00, green: 0.60, blue: 0.14)
    static let growth       = Color(red: 0.20, green: 0.78, blue: 0.45)
    static let appleMusic   = Color(red: 0.98, green: 0.24, blue: 0.34)
    static let fitOrange    = Color(red: 0.99, green: 0.52, blue: 0.30)

    // MARK: HR zone colors (5-stop, shared with Watch)
    static let hrZones: [Color] = [
        Color(red: 0.00, green: 0.48, blue: 1.00),  // Z1 recovery – blue
        Color(red: 0.20, green: 0.80, blue: 0.35),  // Z2 easy – green
        Color.yellow,                                 // Z3 moderate
        Color.orange,                                 // Z4 hard
        Color.red                                     // Z5 max
    ]
    static func hrZoneColor(_ zone: Int?) -> Color {
        guard let zone, (1...5).contains(zone) else { return Color.white.opacity(0.4) }
        return hrZones[zone - 1]
    }

    // MARK: Surface colors — true black canvas (Apple Fitness style)
    static let background = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? .black
            : UIColor(red: 0.95, green: 0.95, blue: 0.97, alpha: 1.0)
    })

    static let card = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.11, green: 0.11, blue: 0.12, alpha: 1.0)  // #1C1C1E
            : .white
    })

    static let grouped = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.17, green: 0.17, blue: 0.18, alpha: 1.0)
            : UIColor(red: 0.91, green: 0.91, blue: 0.94, alpha: 1.0)
    })

    static let elevated = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.23, green: 0.23, blue: 0.25, alpha: 1.0)
            : UIColor(red: 0.86, green: 0.86, blue: 0.89, alpha: 1.0)
    })

    static let secondaryText = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.56, green: 0.56, blue: 0.58, alpha: 1.0)
            : UIColor(red: 0.40, green: 0.40, blue: 0.45, alpha: 1.0)
    })

    static let tertiaryText = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.36, green: 0.36, blue: 0.38, alpha: 1.0)
            : UIColor(red: 0.60, green: 0.60, blue: 0.65, alpha: 1.0)
    })

    static let separator = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor.white.withAlphaComponent(0.07)
            : UIColor.black.withAlphaComponent(0.08)
    })

    // MARK: Geometry
    static let controlRadius: CGFloat = 12
    static let compactRadius: CGFloat = 16
    static let cardRadius: CGFloat = 22
    static let screenHorizontalPadding: CGFloat = 16
    static let minTapTarget: CGFloat = 44

    // MARK: Typography
    static func heroNumeric(size: CGFloat = 52) -> Font {
        .system(size: size, weight: .heavy, design: .rounded)
    }
    static func metricNumeric(size: CGFloat = 34) -> Font {
        .system(size: size, weight: .bold, design: .rounded)
    }

    // MARK: Gradients
    static var heroGradientColors: [Color] { [ringMove, ringExercise] }
    static var fitActionGradient: LinearGradient {
        LinearGradient(
            colors: [accent, ringExercise],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    // MARK: Backward-compat aliases (56 files reference these; keep names stable)
    static var primary: Color         { accent }
    static var primaryBright: Color   { ringStand }
    static var recovery: Color        { growth }
    static var accentMuted: Color     { accent.opacity(0.15) }

    // MARK: Contrast-safe foreground
    /// Returns `.black` or `.white`, whichever gives better WCAG contrast
    /// against `background`. Several brand colors (accent, ringStand,
    /// ringExercise, warning…) are bright enough that white text on them
    /// fails contrast — always route text/icon color on a colored fill
    /// through this instead of hardcoding `.white`.
    static func onColor(_ background: Color) -> Color {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        UIColor(background).getRed(&r, green: &g, blue: &b, alpha: &a)
        func channel(_ c: CGFloat) -> CGFloat {
            c <= 0.03928 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4)
        }
        let luminance = 0.2126 * channel(r) + 0.7152 * channel(g) + 0.0722 * channel(b)
        return luminance > 0.5 ? .black : .white
    }
}

// MARK: - Glass Button Prominence

enum NavigationGlassProminence {
    case primary, secondary, disabled

    var tintOpacity: Double {
        switch self {
        case .primary:   0.28
        case .secondary: 0.16
        case .disabled:  0.08
        }
    }
    var strokeOpacity: Double {
        switch self {
        case .primary:   0.50
        case .secondary: 0.30
        case .disabled:  0.16
        }
    }
    var shadowOpacity: Double {
        switch self {
        case .primary:   0.18
        case .secondary: 0.08
        case .disabled:  0.03
        }
    }
}

// MARK: - Glass Button Modifiers (iOS 26 Liquid Glass — no fallbacks)

extension View {
    func navigationGlassCapsule(
        _ prominence: NavigationGlassProminence = .primary,
        tint: Color = PulseTheme.accent
    ) -> some View {
        modifier(NavigationGlassCapsuleModifier(prominence: prominence, tint: tint))
    }

    func navigationGlassCircle(
        _ prominence: NavigationGlassProminence = .secondary,
        tint: Color = PulseTheme.accent
    ) -> some View {
        modifier(NavigationGlassCircleModifier(prominence: prominence, tint: tint))
    }

    func destructiveGlassCapsule(_ prominence: NavigationGlassProminence = .secondary) -> some View {
        navigationGlassCapsule(prominence, tint: PulseTheme.destructive)
    }

    func destructiveGlassCircle(_ prominence: NavigationGlassProminence = .secondary) -> some View {
        navigationGlassCircle(prominence, tint: PulseTheme.destructive)
    }
}

private struct NavigationGlassCapsuleModifier: ViewModifier {
    let prominence: NavigationGlassProminence
    let tint: Color

    func body(content: Content) -> some View {
        content
            .background {
                Capsule(style: .continuous)
                    .fill(.clear)
                    .glassEffect(
                        .regular.tint(tint.opacity(prominence.tintOpacity)).interactive(),
                        in: Capsule(style: .continuous)
                    )
            }
            .overlay {
                Capsule(style: .continuous)
                    .stroke(
                        LinearGradient(
                            colors: [.white.opacity(0.22), tint.opacity(prominence.strokeOpacity * 0.5)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 0.5
                    )
            }
            .shadow(color: tint.opacity(prominence.shadowOpacity), radius: 16, y: 6)
    }
}

private struct NavigationGlassCircleModifier: ViewModifier {
    let prominence: NavigationGlassProminence
    let tint: Color

    func body(content: Content) -> some View {
        content
            .background {
                Circle()
                    .fill(.clear)
                    .glassEffect(
                        .regular.tint(tint.opacity(prominence.tintOpacity)).interactive(),
                        in: Circle()
                    )
            }
            .overlay {
                Circle()
                    .stroke(
                        LinearGradient(
                            colors: [.white.opacity(0.22), tint.opacity(prominence.strokeOpacity * 0.5)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 0.5
                    )
            }
            .shadow(color: tint.opacity(prominence.shadowOpacity), radius: 10, y: 4)
    }
}

// MARK: - Activity Rings

/// Concentric activity rings in the Apple Fitness style.
/// `rings[0]` = outermost (Move), `rings[1]` = middle (Exercise), `rings[2]` = innermost (Stand).
/// Progress > 1.0 renders a translucent lap overlay.
struct RepsActivityRings: View {

    struct Ring: Identifiable {
        let id: Int
        let progress: Double    // 0…1+
        let color: Color

        static func `default`(
            moveProgress: Double,
            exerciseProgress: Double,
            standProgress: Double
        ) -> [Ring] {
            [
                Ring(id: 0, progress: moveProgress,     color: PulseTheme.ringMove),
                Ring(id: 1, progress: exerciseProgress, color: PulseTheme.ringExercise),
                Ring(id: 2, progress: standProgress,    color: PulseTheme.ringStand),
            ]
        }
    }

    let rings: [Ring]
    var lineWidth: CGFloat = 14
    var gap: CGFloat = 5

    @State private var displayed: [Double] = []

    var body: some View {
        GeometryReader { proxy in
            let side = min(proxy.size.width, proxy.size.height)
            ZStack {
                ForEach(Array(rings.enumerated()), id: \.offset) { idx, ring in
                    let r = (side / 2) - (lineWidth / 2) - CGFloat(idx) * (lineWidth + gap)
                    let prog = displayed.indices.contains(idx) ? displayed[idx] : 0

                    // Track
                    Circle()
                        .stroke(ring.color.opacity(0.18), lineWidth: lineWidth)
                        .frame(width: r * 2, height: r * 2)

                    // Fill arc
                    Circle()
                        .trim(from: 0, to: min(prog, 1.0))
                        .stroke(ring.color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                        .frame(width: r * 2, height: r * 2)
                        .rotationEffect(.degrees(-90))

                    // Lap (> 100%)
                    if prog > 1.0 {
                        Circle()
                            .trim(from: 0, to: prog - 1.0)
                            .stroke(ring.color.opacity(0.55),
                                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                            .frame(width: r * 2, height: r * 2)
                            .rotationEffect(.degrees(-90))
                    }
                }
            }
            .frame(width: side, height: side)
            .position(x: proxy.size.width / 2, y: proxy.size.height / 2)
        }
        .onAppear {
            displayed = rings.map { _ in 0 }
            withAnimation(.spring(response: 1.4, dampingFraction: 0.80).delay(0.15)) {
                displayed = rings.map(\.progress)
            }
        }
        .onChange(of: rings.map(\.progress)) { _, newVals in
            withAnimation(.spring(response: 0.9, dampingFraction: 0.86)) {
                displayed = newVals
            }
        }
    }
}

// MARK: - Text Utilities

enum RepsText {
    static func exerciseName(_ value: String, language: String) -> String {
        guard language.hasPrefix("es") else { return value }
        return switch normalized(value) {
        case "barbell bench press": "Press banca con barra"
        case "incline dumbbell press": "Press inclinado con mancuernas"
        case "overhead press": "Press militar"
        case "barbell deadlift": "Peso muerto con barra"
        case "barbell squat": "Sentadilla con barra"
        case "barbell back squat": "Sentadilla trasera con barra"
        case "dumbbell row": "Remo con mancuerna"
        case "push-up": "Flexiones"
        case "plank": "Plancha"
        case "walking lunge": "Zancadas caminando"
        case "pull-up": "Dominadas"
        case "inverted row": "Remo invertido"
        case "goblet squat": "Sentadilla goblet"
        case "romanian deadlift": "Peso muerto rumano"
        case "dumbbell romanian deadlift": "Peso muerto rumano con mancuernas"
        case "dumbbell deadlift": "Peso muerto con mancuernas"
        case "hip thrust": "Hip thrust"
        case "band row": "Remo con banda"
        case "band face pull": "Face pull con banda"
        case "dumbbell floor press": "Press en suelo con mancuernas"
        case "lateral raise": "Elevación lateral"
        case "dumbbell curl": "Curl con mancuernas"
        case "dumbbell preacher curl": "Curl predicador con mancuernas"
        case "overhead triceps extension": "Extensión de tríceps sobre cabeza"
        case "bulgarian split squat": "Sentadilla búlgara"
        case "standing calf raise": "Elevación de gemelos"
        case "mountain climber": "Escalador"
        case "kettlebell swing": "Swing con kettlebell"
        case "stationary bike": "Bicicleta estática"
        case "treadmill run": "Carrera en cinta"
        case "rowing machine": "Remo en máquina"
        case "t-bar row (chest supported)": "Remo T con apoyo de pecho"
        case "leg press (plate-loaded)": "Prensa de piernas"
        case "machine chest press": "Press de pecho en máquina"
        case "cable kneeling crunch": "Crunch arrodillado en polea"
        case "cable pushdown (with rope)": "Jalón de tríceps con cuerda"
        case "cable straight arm pulldown": "Pulldown brazos rectos en polea"
        case "machine seated leg extension": "Extensión de piernas en máquina"
        case "smith machine calf raise (with block)": "Elevación de gemelos en Smith"
        default: value
        }
    }

    static func muscle(_ value: String, language: String) -> String {
        guard language.hasPrefix("es") else { return value == "Abdominals" ? "Core" : value }
        return switch normalized(value) {
        case "arms": "Brazos"
        case "back": "Espalda"
        case "biceps": "Bíceps"
        case "cardio": "Cardio"
        case "chest": "Pecho"
        case "core", "abdominals": "Core"
        case "abs": "Abdominales"
        case "adductors": "Aductores"
        case "abductors": "Abductores"
        case "calves": "Gemelos"
        case "forearms": "Antebrazos"
        case "full body": "Cuerpo completo"
        case "glutes": "Glúteos"
        case "hamstrings": "Isquios"
        case "lats": "Dorsales"
        case "legs": "Piernas"
        case "lower back": "Lumbar"
        case "neck": "Cuello"
        case "quadriceps": "Cuádriceps"
        case "shoulders": "Hombros"
        case "traps": "Trapecios"
        case "triceps": "Tríceps"
        case "upper back": "Espalda alta"
        default: value
        }
    }

    static func equipment(_ value: String, language: String) -> String {
        guard language.hasPrefix("es") else { return value }
        return switch normalized(value) {
        case "barbell": "Barra"
        case "body only", "bodyweight": "Peso corporal"
        case "cable": "Polea"
        case "cardio machine": "Máquina de cardio"
        case "dumbbell", "dumbbells": "Mancuernas"
        case "ez bar", "e-z curl bar": "Barra Z"
        case "kettlebell", "kettlebells": "Kettlebell"
        case "leg press": "Prensa de piernas"
        case "machine", "machines": "Máquina"
        case "medicine ball": "Balón medicinal"
        case "other": "Otro"
        case "resistance band": "Banda elástica"
        case "bench": "Banco"
        case "rack": "Rack"
        case "smith machine": "Multipower / Smith"
        case "suspension trainer": "TRX / suspensión"
        case "pullup bar": "Dominadas"
        case "cardio": "Cardio"
        default: value
        }
    }

    static func equipmentIcon(_ value: String) -> String {
        switch normalized(value) {
        case "barbell", "barra":
            return "figure.strengthtraining.traditional"
        case "ez bar", "e-z curl bar", "barra z":
            return "waveform.path.ecg"
        case "dumbbell", "dumbbells", "mancuerna", "mancuernas":
            return "dumbbell.fill"
        case "kettlebell", "kettlebells", "pesa rusa":
            return "kettlebell.fill"
        case "resistance band", "banda", "bandas":
            return "point.3.connected.trianglepath.dotted"
        case "suspension trainer", "trx":
            return "figure.core.training"
        case "cable", "polea", "poleas":
            return "point.3.connected.trianglepath.dotted"
        case "machine", "machines", "maquina", "maquinas":
            return "rectangle.3.group.bubble.left"
        case "smith machine", "multipower":
            return "square.grid.3x3.middle.filled"
        case "leg press", "prensa de piernas":
            return "figure.strengthtraining.traditional"
        case "cardio machine", "cardio", "maquina de cardio":
            return "figure.run"
        case "medicine ball", "balon medicinal", "balón medicinal":
            return "circle.hexagongrid.fill"
        case "bodyweight", "body only", "peso corporal":
            return "figure.walk"
        case "bench", "banco":
            return "table.furniture"
        case "rack":
            return "square.split.3x3"
        case "pullup bar", "dominadas":
            return "figure.pull.ups"
        default:
            return "checkmark.seal"
        }
    }

    static func workoutTitle(_ value: String, language: String) -> String {
        guard language.hasPrefix("es") else { return value }
        return switch normalized(value) {
        case "push day": "Día de empuje"
        case "pull day": "Día de tirón"
        case "leg day": "Día de pierna"
        case "home full body a": "Full body casa A"
        case "home full body b": "Full body casa B"
        default: value
        }
    }

    static func localizedWorkoutSubtitle(_ value: String, language: String) -> String {
        guard language.hasPrefix("es") else { return value }
        return switch normalized(value) {
        case "upper body & core", "upper body and core": "Tren superior y core"
        case "back & biceps", "back and biceps": "Espalda y bíceps"
        case "lower body": "Tren inferior"
        case "dumbbells, bands & bodyweight", "dumbbells, bands and bodyweight": "Mancuernas, bandas y peso corporal"
        case "limited equipment strength": "Fuerza con equipamiento limitado"
        default: value
        }
    }

    private static func normalized(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines)
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
            .lowercased()
    }
}

// MARK: - Cards

struct PulseCard<Content: View>: View {
    let content: Content
    var minHeight: CGFloat?
    var contentPadding: CGFloat = 16
    var backgroundColor: Color = PulseTheme.card

    init(
        minHeight: CGFloat? = nil,
        contentPadding: CGFloat = 16,
        backgroundColor: Color = PulseTheme.card,
        @ViewBuilder content: () -> Content
    ) {
        self.content = content()
        self.minHeight = minHeight
        self.contentPadding = contentPadding
        self.backgroundColor = backgroundColor
    }

    var body: some View {
        content
            .frame(maxWidth: .infinity, maxHeight: minHeight != nil ? .infinity : nil, alignment: .leading)
            .padding(contentPadding)
            .frame(minHeight: minHeight, alignment: .leading)
            .background(backgroundColor)
            .clipShape(RoundedRectangle(cornerRadius: PulseTheme.cardRadius, style: .continuous))
    }
}

// MARK: - Buttons

struct PrimaryButton: View {
    let title: LocalizedStringKey
    let systemImage: String?
    let action: () -> Void

    init(_ title: LocalizedStringKey, systemImage: String? = nil, action: @escaping () -> Void) {
        self.title = title
        self.systemImage = systemImage
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                if let systemImage {
                    Image(systemName: systemImage)
                }
                Text(localizedKey(title))
            }
            .font(.system(size: 17, weight: .bold, design: .rounded))
            .frame(maxWidth: .infinity)
            .frame(height: 56)
        }
        .buttonStyle(.plain)
        .foregroundStyle(.black)
        .background(PulseTheme.accent)
        .clipShape(Capsule(style: .continuous))
        .shadow(color: PulseTheme.accent.opacity(0.30), radius: 14, y: 6)
    }
}

struct SecondaryButton: View {
    let title: LocalizedStringKey
    let systemImage: String?
    let action: () -> Void

    init(_ title: LocalizedStringKey, systemImage: String? = nil, action: @escaping () -> Void) {
        self.title = title
        self.systemImage = systemImage
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            Label {
                Text(localizedKey(title))
            } icon: {
                if let systemImage {
                    Image(systemName: systemImage)
                }
            }
            .font(.system(size: 16, weight: .semibold, design: .rounded))
            .frame(maxWidth: .infinity)
            .frame(height: 52)
        }
        .buttonStyle(.plain)
        .foregroundStyle(.white)
        .navigationGlassCapsule(.secondary)
        .accessibilityAddTraits(.isButton)
    }
}

// MARK: - Typography Components

struct SectionHeader: View {
    let title: String
    @Environment(\.locale) private var locale

    var body: some View {
        Text(verbatim: String(localized: String.LocalizationValue(title), locale: locale).capitalizingFirstLetter())
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(PulseTheme.secondaryText)
            .accessibilityAddTraits(.isHeader)
    }
}

struct CardTitle: View {
    private let key: String?
    private let verbatimText: String?

    init(_ key: String) {
        self.key = key
        self.verbatimText = nil
    }

    init(verbatim string: String) {
        self.key = nil
        self.verbatimText = string
    }

    var body: some View {
        let text: String = if let key {
            localizedString(key).capitalizingFirstLetter()
        } else {
            (verbatimText ?? "").capitalizingFirstLetter()
        }
        Text(verbatim: text)
            .font(.headline)
    }
}

extension String {
    func capitalizingFirstLetter() -> String {
        guard let first else { return self }
        return first.uppercased() + dropFirst()
    }
}

// MARK: - Pulse Header Bar

/// The blurred, rounded-bottom-corner title bar shared by every primary
/// screen (Today, Progress, Plans, Calendar, Exercises). `title` is verbatim
/// display text (already resolved/localized by the caller); `subtitleKey` is
/// a localization key. Use the `titleContent` initializer when the title row
/// needs richer, dynamic content than a single `Text` (e.g. the quick-menu
/// chart header, which swaps in a live value readout while dragging).
struct PulseHeaderBar<TitleContent: View, Accessory: View>: View {
    let subtitleKey: String?
    let backAction: (() -> Void)?
    let titleContent: TitleContent
    let accessory: Accessory

    init(
        subtitleKey: String? = nil,
        backAction: (() -> Void)? = nil,
        @ViewBuilder titleContent: () -> TitleContent,
        @ViewBuilder accessory: () -> Accessory
    ) {
        self.subtitleKey = subtitleKey
        self.backAction = backAction
        self.titleContent = titleContent()
        self.accessory = accessory()
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .center, spacing: 12) {
                if let backAction {
                    Button {
                        HapticService.selection()
                        backAction()
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(width: 42, height: 42)
                            .navigationGlassCircle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("back_2")
                }

                VStack(alignment: .leading, spacing: 3) {
                    if let subtitleKey {
                        Text(localizedKey(subtitleKey))
                            .font(.caption.weight(.bold))
                            .textCase(.uppercase)
                            .foregroundStyle(PulseTheme.accent)
                            .lineLimit(1)
                    }
                    titleContent
                }

                Spacer(minLength: 12)
                accessory
            }
            .padding(.horizontal, PulseTheme.screenHorizontalPadding)
            .padding(.top, 10)
            .padding(.bottom, 14)
            .background {
                UnevenRoundedRectangle(
                    cornerRadii: .init(bottomLeading: 28, bottomTrailing: 28),
                    style: .continuous
                )
                .fill(.ultraThinMaterial)
                .ignoresSafeArea(edges: .top)
            }
            .overlay(alignment: .bottom) {
                StickyHeaderBottomBorder(cornerRadius: 28)
                    .stroke(PulseTheme.separator, lineWidth: 1)
                    .frame(height: 28)
                    .allowsHitTesting(false)
            }

            LinearGradient(
                colors: [PulseTheme.background.opacity(0.72), .clear],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 16)
            .allowsHitTesting(false)
        }
    }
}

struct PulseHeaderTitleText: View {
    let title: String

    var body: some View {
        Text(verbatim: title.capitalizingFirstLetter())
            .font(.system(size: 28, weight: .bold, design: .rounded))
            .lineLimit(1)
            .minimumScaleFactor(0.76)
    }
}

extension PulseHeaderBar where TitleContent == PulseHeaderTitleText {
    /// Convenience initializer for the common case: a single verbatim,
    /// already-resolved/localized title string.
    init(
        title: String,
        subtitleKey: String? = nil,
        backAction: (() -> Void)? = nil,
        @ViewBuilder accessory: () -> Accessory
    ) {
        self.init(subtitleKey: subtitleKey, backAction: backAction) {
            PulseHeaderTitleText(title: title)
        } accessory: {
            accessory()
        }
    }
}

// MARK: - Sticky Header Scaffold

struct StickyHeaderScaffold<Accessory: View, Content: View>: View {
    let title: String
    let subtitle: String?
    let topContentPadding: CGFloat
    let backAction: (() -> Void)?
    let accessory: Accessory
    let content: Content

    @State private var activeTitle: String
    /// Measured height of `stickyHeader`, used as the scroll threshold for
    /// switching the active section title. A hardcoded threshold drifted out
    /// of sync with the header's real height (subtitle presence, Dynamic
    /// Type, accessory size all change it), so a section could be marked
    /// "current" while its content was still visually under the blurred
    /// header — reads as washed-out/low-contrast content near the top.
    @State private var headerHeight: CGFloat = 116
    @Environment(\.locale) private var locale

    init(
        title: String,
        subtitle: String? = nil,
        topContentPadding: CGFloat = 86,
        backAction: (() -> Void)? = nil,
        @ViewBuilder accessory: () -> Accessory,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.subtitle = subtitle
        self.topContentPadding = topContentPadding
        self.backAction = backAction
        self.accessory = accessory()
        self.content = content()
        _activeTitle = State(initialValue: title)
    }

    private func localizedTitle(for key: String) -> String {
        localizedString(key)
    }

    var body: some View {
        ZStack(alignment: .top) {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 18) {
                    content
                }
                .frame(maxWidth: .infinity)
                .padding(.horizontal, PulseTheme.screenHorizontalPadding)
                .safeAreaPadding(.top, max(topContentPadding, headerHeight + 12))
                .padding(.bottom, 104)
            }
            .scrollBounceBehavior(.basedOnSize, axes: .vertical)
            .coordinateSpace(.named(StickyHeaderTitleReader.coordinateSpaceName))
            .onPreferenceChange(StickyHeaderTitlePreferenceKey.self) { markers in
                let nextTitle = titleForVisibleSection(markers)
                guard activeTitle != nextTitle else { return }
                DispatchQueue.main.async {
                    guard activeTitle != nextTitle else { return }
                    withAnimation(.snappy(duration: 0.18)) {
                        activeTitle = nextTitle
                    }
                }
            }

            stickyHeader
                .background {
                    GeometryReader { proxy in
                        Color.clear.preference(key: StickyHeaderHeightPreferenceKey.self, value: proxy.size.height)
                    }
                }
        }
        .screenBackground()
        .onChange(of: locale) { _, _ in
            activeTitle = title
        }
        .onPreferenceChange(StickyHeaderHeightPreferenceKey.self) { height in
            guard height > 0, headerHeight != height else { return }
            DispatchQueue.main.async {
                headerHeight = height
            }
        }
    }

    private var displayTitle: String {
        activeTitle == title ? localizedTitle(for: title) : activeTitle
    }

    private var stickyHeader: some View {
        PulseHeaderBar(title: displayTitle, subtitleKey: subtitle, backAction: backAction) {
            accessory
        }
    }

    private func titleForVisibleSection(_ markers: [StickyHeaderTitleMarker]) -> String {
        // Small safety margin so content clears the header's blurred edge
        // before it's treated as "current", instead of just touching it.
        let threshold = headerHeight + 12
        return markers
            .filter { $0.minY <= threshold }
            .max { $0.minY < $1.minY }?
            .title ?? title
    }
}

struct StickyHeaderBottomBorder: Shape {
    let cornerRadius: CGFloat

    func path(in rect: CGRect) -> Path {
        let radius = min(cornerRadius, rect.height, rect.width / 2)
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addQuadCurve(
            to: CGPoint(x: rect.minX + radius, y: rect.maxY),
            control: CGPoint(x: rect.minX, y: rect.maxY)
        )
        path.addLine(to: CGPoint(x: rect.maxX - radius, y: rect.maxY))
        path.addQuadCurve(
            to: CGPoint(x: rect.maxX, y: rect.minY),
            control: CGPoint(x: rect.maxX, y: rect.maxY)
        )
        return path
    }
}

struct StickyHeaderTitleReader: View {
    static let coordinateSpaceName = "reps-sticky-header-scroll"
    let title: String

    var body: some View {
        GeometryReader { proxy in
            Color.clear.preference(
                key: StickyHeaderTitlePreferenceKey.self,
                value: [
                    StickyHeaderTitleMarker(
                        title: title,
                        minY: proxy.frame(in: .named(Self.coordinateSpaceName)).minY
                    )
                ]
            )
        }
    }
}

struct StickyHeaderTitleMarker: Equatable {
    let title: String
    let minY: CGFloat
}

struct StickyHeaderTitlePreferenceKey: PreferenceKey {
    static let defaultValue: [StickyHeaderTitleMarker] = []

    static func reduce(value: inout [StickyHeaderTitleMarker], nextValue: () -> [StickyHeaderTitleMarker]) {
        value.append(contentsOf: nextValue())
    }
}

struct StickyHeaderHeightPreferenceKey: PreferenceKey {
    static let defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

// MARK: - Reusable Components

/// A glass-styled circular avatar button, sized to match the other header
/// accessory buttons (bell, back chevron). Falls back to a placeholder icon
/// when no avatar image is set.
struct HeaderAvatarButton: View {
    let imageData: Data?
    let accessibilityLabel: LocalizedStringKey
    let action: () -> Void

    var body: some View {
        Button {
            HapticService.selection()
            action()
        } label: {
            ZStack {
                if let imageData, let image = UIImage(data: imageData) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                } else {
                    Circle()
                        .fill(PulseTheme.accent.opacity(0.14))
                    Image(systemName: "person.crop.circle.fill")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(PulseTheme.accent)
                }
            }
            .frame(width: PulseTheme.minTapTarget, height: PulseTheme.minTapTarget)
            .clipShape(Circle())
            .navigationGlassCircle(.secondary)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel)
    }
}

struct PulseListRow<Trailing: View>: View {
    let title: LocalizedStringKey
    let subtitle: LocalizedStringKey
    let systemImage: String
    let trailing: Trailing

    init(
        title: LocalizedStringKey,
        subtitle: LocalizedStringKey,
        systemImage: String,
        @ViewBuilder trailing: () -> Trailing = { Image(systemName: "chevron.right").foregroundStyle(.tertiary) }
    ) {
        self.title = title
        self.subtitle = subtitle
        self.systemImage = systemImage
        self.trailing = trailing()
    }

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: systemImage)
                .font(.headline)
                .foregroundStyle(PulseTheme.accent)
                .frame(width: 42, height: 42)
                .background(PulseTheme.accent.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            VStack(alignment: .leading, spacing: 3) {
                Text(localizedKey(title)).font(.headline)
                Text(localizedKey(subtitle))
                    .font(.subheadline)
                    .foregroundStyle(PulseTheme.secondaryText)
            }
            Spacer()
            trailing
        }
        .frame(minHeight: 58)
        .contentShape(Rectangle())
    }
}

struct PulseChip: View {
    let title: LocalizedStringKey
    var isSelected = false

    var body: some View {
        Text(localizedKey(title))
            .font(.subheadline.weight(.semibold))
            .lineLimit(1)
            .minimumScaleFactor(0.85)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .foregroundStyle(isSelected ? .black : .white)
            .background(isSelected ? PulseTheme.accent : PulseTheme.grouped)
            .clipShape(Capsule())
    }
}

struct PulseEmptyState: View {
    let title: LocalizedStringKey
    let message: LocalizedStringKey
    let systemImage: String

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Image(systemName: systemImage)
                .font(.largeTitle)
                .foregroundStyle(PulseTheme.accent)
                .accessibilityHidden(true)
            Text(localizedKey(title))
                .font(.title2.bold())
            Text(localizedKey(message))
                .foregroundStyle(PulseTheme.secondaryText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct PulseSkeleton: View {
    var height: CGFloat = 16
    var cornerRadius: CGFloat = PulseTheme.controlRadius

    @State private var phase: CGFloat = -1

    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(PulseTheme.grouped)
            .frame(height: height)
            .overlay {
                GeometryReader { proxy in
                    LinearGradient(
                        colors: [.clear, PulseTheme.elevated.opacity(0.9), .clear],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .frame(width: proxy.size.width * 0.6)
                    .offset(x: proxy.size.width * phase)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .onAppear {
                withAnimation(.linear(duration: 1.1).repeatForever(autoreverses: false)) {
                    phase = 1.4
                }
            }
            .accessibilityHidden(true)
    }
}

struct PulseSkeletonCard: View {
    var lines: Int = 3

    var body: some View {
        PulseCard {
            VStack(alignment: .leading, spacing: 12) {
                PulseSkeleton(height: 20)
                    .frame(maxWidth: 160)
                ForEach(0..<max(lines - 1, 0), id: \.self) { _ in
                    PulseSkeleton()
                }
            }
        }
    }
}

struct MetricCard: View {
    let title: LocalizedStringKey
    let value: String
    let subtitle: LocalizedStringKey
    let systemImage: String
    var badgeColor: Color = PulseTheme.accent

    var body: some View {
        PulseCard(minHeight: 120) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 5) {
                    Image(systemName: systemImage)
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(badgeColor)
                    Text(localizedKey(title))
                        .font(.system(size: 11, weight: .semibold))
                        .textCase(.uppercase)
                        .tracking(0.4)
                        .foregroundStyle(PulseTheme.secondaryText)
                        .lineLimit(1)
                        .minimumScaleFactor(0.82)
                }
                Text(value)
                    .font(PulseTheme.metricNumeric())
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .foregroundStyle(.white)
                Text(localizedKey(subtitle))
                    .font(.caption)
                    .lineLimit(2)
                    .foregroundStyle(PulseTheme.secondaryText)
            }
        }
    }
}

struct MuscleGlyph: View {
    let muscleGroup: String
    var size: CGFloat = 58
    var intensity: Double = 1

    var body: some View {
        MuscleGroupAnatomyThumbnail(muscleGroup: muscleGroup, size: size, intensity: intensity)
    }
}

struct VolumeSegmentBar: View {
    let completed: Int
    var target: Int = 12
    var segmentCount: Int = 12

    var body: some View {
        HStack(spacing: 7) {
            ForEach(0..<segmentCount, id: \.self) { index in
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .fill(color(for: index))
                    .frame(height: 34)
            }
        }
        .accessibilityLabel("\(completed) de \(target) series semanales")
    }

    private func color(for index: Int) -> Color {
        let zone: Color = index < 4 ? PulseTheme.ringStand
                        : index < 10 ? PulseTheme.ringExercise
                        : PulseTheme.accent
        return index < completed ? zone : zone.opacity(0.15)
    }
}

// MARK: - Exercise Media

struct ExerciseMediaThumbnail: View, Equatable {
    let exercise: Exercise
    var gender: BodyGender = .male
    var fallbackSize: Font = .title3.weight(.bold)
    var catalog: [Exercise] = []

    nonisolated static func == (lhs: ExerciseMediaThumbnail, rhs: ExerciseMediaThumbnail) -> Bool {
        let lhsExercise = ExerciseVisualResolver.resolved(lhs.exercise, catalog: lhs.catalog)
        let rhsExercise = ExerciseVisualResolver.resolved(rhs.exercise, catalog: rhs.catalog)
        return lhsExercise.id == rhsExercise.id
            && lhsExercise.name == rhsExercise.name
            && lhsExercise.muscleGroup == rhsExercise.muscleGroup
            && lhsExercise.secondaryMuscles == rhsExercise.secondaryMuscles
            && lhsExercise.tags == rhsExercise.tags
            && lhsExercise.mediaURL == rhsExercise.mediaURL
            && Self.customImageFingerprint(for: lhsExercise.customImageData) == Self.customImageFingerprint(for: rhsExercise.customImageData)
            && lhs.gender == rhs.gender
    }

    var body: some View {
        let visualExercise = ExerciseVisualResolver.resolved(exercise, catalog: catalog)
        ZStack {
            if let data = visualExercise.customImageData,
               let image = ExerciseThumbnailImageCache.shared.image(for: data, exerciseID: visualExercise.id) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else if let url = visualExercise.mediaAssetURL {
                RemoteExerciseImage(url: url) {
                    fallback(for: visualExercise)
                }
            } else {
                fallback(for: visualExercise)
            }
        }
        .background(PulseTheme.grouped)
        .clipped()
    }

    private func fallback(for exercise: Exercise) -> some View {
        GeometryReader { proxy in
            let side = max(proxy.size.width, proxy.size.height)
            ExerciseAnatomyThumbnail(exercise: exercise, gender: gender, size: max(side, 1))
                .frame(width: proxy.size.width, height: proxy.size.height)
                .clipped()
        }
    }

    nonisolated private static func customImageFingerprint(for data: Data?) -> CustomImageFingerprint? {
        data.map(CustomImageFingerprint.init)
    }
}

enum ExerciseVisualResolver {
    static func resolved(_ exercise: Exercise, catalog: [Exercise]) -> Exercise {
        var resolved = catalog.first(where: { $0.id == exercise.id }) ?? exercise
        if !hasValidCustomImage(resolved.customImageData) {
            resolved.customImageData = nil
        }

        // The catalog-wide substitute search below only exists to backfill a
        // missing image/mediaURL. When this exercise already has both, skip
        // it entirely — with hundreds of exercises in the library, this scan
        // (string normalization + image decoding across every candidate) was
        // running for every row on every render for no benefit.
        let hasOwnMediaURL = !(resolved.mediaURL?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true)
        if resolved.customImageData != nil && hasOwnMediaURL {
            return resolved
        }

        guard let catalogExercise = catalogExerciseMatch(for: resolved, in: catalog) else {
            return resolved
        }

        if resolved.customImageData == nil, hasValidCustomImage(catalogExercise.customImageData) {
            resolved.customImageData = catalogExercise.customImageData
        }

        if resolved.mediaURL?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true {
            resolved.mediaURL = catalogExercise.mediaURL
        }

        return resolved
    }

    private static func catalogExerciseMatch(for resolved: Exercise, in catalog: [Exercise]) -> Exercise? {
        let candidates = catalog.filter { candidate in
            candidate.id != resolved.id && hasVisualReference(candidate)
        }
        let resolvedName = normalized(resolved.name)
        let resolvedEquipment = normalized(resolved.equipment)
        let resolvedMuscleGroup = normalized(resolved.muscleGroup)

        return candidates.first { candidate in
            normalized(candidate.name) == resolvedName
                && normalized(candidate.equipment) == resolvedEquipment
        } ?? candidates.first { candidate in
            normalized(candidate.name) == resolvedName
                && normalized(candidate.muscleGroup) == resolvedMuscleGroup
        } ?? candidates.first { candidate in
            let candidateNames = ([candidate.name] + candidate.aliases).map(normalized)
            return candidateNames.contains(resolvedName)
                && normalized(candidate.equipment) == resolvedEquipment
        } ?? candidates.first { candidate in
            let candidateName = normalized(candidate.name)
            return candidateName.contains(resolvedName)
                && normalized(candidate.equipment) == resolvedEquipment
                && normalized(candidate.muscleGroup) == resolvedMuscleGroup
        }
    }

    private static func hasVisualReference(_ exercise: Exercise) -> Bool {
        hasValidCustomImage(exercise.customImageData)
            || !(exercise.mediaURL?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true)
    }

    static func hasValidCustomImage(_ data: Data?) -> Bool {
        guard let data else { return false }
        return UIImage(data: data) != nil
    }

    private static func normalized(_ value: String) -> String {
        value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            .lowercased()
    }
}

struct RemoteExerciseImage<Fallback: View>: View {
    let url: URL
    let fallback: Fallback

    @State private var image: UIImage?
    @State private var didFail = false

    init(url: URL, @ViewBuilder fallback: () -> Fallback) {
        self.url = url
        self.fallback = fallback()
    }

    var body: some View {
        ZStack {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .transition(.opacity)
            } else {
                fallback
                    .overlay {
                        if !didFail {
                            ProgressView()
                                .controlSize(.small)
                                .tint(PulseTheme.accent)
                        }
                    }
            }
        }
        .task(id: url) {
            await load()
        }
        .animation(.easeInOut(duration: 0.18), value: image != nil)
    }

    private func load() async {
        if let cached = RemoteExerciseImageCache.shared.image(for: url) {
            image = cached
            didFail = false
            return
        }

        do {
            let loaded = try await RemoteExerciseImageCache.shared.load(url)
            image = loaded
            didFail = false
        } catch {
            didFail = true
        }
    }
}

@MainActor
final class RemoteExerciseImageCache {
    static let shared = RemoteExerciseImageCache()

    private let cache = NSCache<NSURL, UIImage>()
    private let fileManager = FileManager.default
    private lazy var diskCacheDirectory: URL = {
        let baseURL = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
        return baseURL.appendingPathComponent("RemoteExerciseImages", isDirectory: true)
    }()

    func image(for url: URL) -> UIImage? {
        if let cached = cache.object(forKey: url as NSURL) {
            return cached
        }

        guard let data = try? Data(contentsOf: cacheFileURL(for: url)),
              let image = UIImage(data: data) else {
            return nil
        }
        cache.setObject(image, forKey: url as NSURL)
        return image
    }

    func load(_ url: URL) async throws -> UIImage {
        if let cached = cache.object(forKey: url as NSURL) {
            return cached
        }

        var request = URLRequest(url: url)
        request.cachePolicy = .returnCacheDataElseLoad
        request.timeoutInterval = 18
        request.setValue("image/avif,image/webp,image/apng,image/svg+xml,image/*,*/*;q=0.8", forHTTPHeaderField: "Accept")

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse,
              (200..<300).contains(httpResponse.statusCode),
              let image = UIImage(data: data) else {
            throw URLError(.cannotDecodeContentData)
        }

        cache.setObject(image, forKey: url as NSURL)
        persist(data, for: url)
        return image
    }

    func removeAll() {
        cache.removeAllObjects()
        try? fileManager.removeItem(at: diskCacheDirectory)
    }

    private func persist(_ data: Data, for url: URL) {
        try? fileManager.createDirectory(at: diskCacheDirectory, withIntermediateDirectories: true)
        try? data.write(to: cacheFileURL(for: url), options: [.atomic])
    }

    private func cacheFileURL(for url: URL) -> URL {
        let digest = SHA256.hash(data: Data(url.absoluteString.utf8))
        let filename = digest.map { String(format: "%02x", $0) }.joined() + ".img"
        return diskCacheDirectory.appendingPathComponent(filename, isDirectory: false)
    }
}

private struct CustomImageFingerprint: Equatable {
    let count: Int
    let firstByte: UInt8?
    let lastByte: UInt8?

    init(data: Data) {
        count = data.count
        firstByte = data.first
        lastByte = data.last
    }
}

@MainActor
private final class ExerciseThumbnailImageCache {
    static let shared = ExerciseThumbnailImageCache()

    private let cache = NSCache<NSString, UIImage>()

    func image(for data: Data, exerciseID: UUID) -> UIImage? {
        let key = "\(exerciseID.uuidString)-\(data.count)-\(data.first ?? 0)-\(data.last ?? 0)" as NSString
        if let cached = cache.object(forKey: key) {
            return cached
        }
        guard let image = UIImage(data: data) else {
            return nil
        }
        cache.setObject(image, forKey: key)
        return image
    }
}

// MARK: - View Helpers

extension View {
    func screenBackground() -> some View {
        background(PulseTheme.background.ignoresSafeArea())
    }

    func stickyHeaderTitle(_ title: String) -> some View {
        background(StickyHeaderTitleReader(title: title))
    }

    func mainTabBarHidden(_ hidden: Bool = true) -> some View {
        preference(key: MainTabBarHiddenPreferenceKey.self, value: hidden)
    }
}

// MARK: - Previews

#Preview("Design System") {
    ScrollView {
        VStack(spacing: 20) {
            RepsActivityRings(
                rings: RepsActivityRings.Ring.default(
                    moveProgress: 0.75,
                    exerciseProgress: 0.40,
                    standProgress: 1.10
                )
            )
            .frame(width: 180, height: 180)
            .padding()

            HStack(spacing: 12) {
                MetricCard(title: "Streak", value: "5", subtitle: "Days in a row", systemImage: "flame", badgeColor: PulseTheme.ringMove)
                MetricCard(title: "Volume", value: "12.4k", subtitle: "kg this week", systemImage: "dumbbell.fill", badgeColor: PulseTheme.accent)
            }

            PrimaryButton("start_workout", systemImage: "play.fill") {}
            SecondaryButton("schedule_workout", systemImage: "calendar.badge.plus") {}
            PulseListRow(title: "Exercise Library", subtitle: "Browse and add movements", systemImage: "magnifyingglass")

            HStack {
                PulseChip(title: "Gym", isSelected: true)
                PulseChip(title: "Home")
                PulseChip(title: "Strength")
            }

            PulseEmptyState(
                title: "No workout scheduled",
                message: "Create a plan or schedule a workout to keep momentum.",
                systemImage: "calendar.badge.plus"
            )
        }
        .padding()
    }
    .screenBackground()
    .preferredColorScheme(.dark)
}
