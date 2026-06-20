import CryptoKit
import MuscleMap
import SwiftUI

enum PulseTheme {
    static let primary = Color(red: 0.14, green: 0.35, blue: 0.88)
    static let primaryBright = Color(red: 0.00, green: 0.68, blue: 0.82)
    static let accent = Color(red: 1.00, green: 0.39, blue: 0.18)
    static let fitOrange = Color(red: 0.99, green: 0.52, blue: 0.30)
    static let recovery = Color(red: 0.18, green: 0.72, blue: 0.38)
    static let accentMuted = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .light
            ? UIColor(red: 1.00, green: 0.90, blue: 0.84, alpha: 1.0)
            : UIColor(red: 0.26, green: 0.10, blue: 0.05, alpha: 1.0)
    })
    static let destructive = Color(red: 0.93, green: 0.24, blue: 0.22)
    static let warning = Color(red: 1.0, green: 0.60, blue: 0.14)

    // Unified weekly-volume zone semantics: blue (maintaining) -> green (growing) -> yellow (focus).
    static let growth = Color(red: 0.20, green: 0.78, blue: 0.45)

    static let background = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .light ? UIColor(red: 0.95, green: 0.96, blue: 0.98, alpha: 1.0) : .black
    })
    
    static let card = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .light ? .white : UIColor(red: 0.08, green: 0.08, blue: 0.09, alpha: 1.0)
    })
    
    static let grouped = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .light ? UIColor(red: 0.91, green: 0.91, blue: 0.94, alpha: 1.0) : UIColor(red: 0.15, green: 0.15, blue: 0.17, alpha: 1.0)
    })
    
    static let elevated = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .light ? UIColor(red: 0.86, green: 0.86, blue: 0.89, alpha: 1.0) : UIColor(red: 0.19, green: 0.19, blue: 0.21, alpha: 1.0)
    })
    
    static let secondaryText = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .light ? UIColor(red: 0.40, green: 0.40, blue: 0.45, alpha: 1.0) : UIColor(red: 0.60, green: 0.60, blue: 0.65, alpha: 1.0)
    })
    
    static let tertiaryText = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .light ? UIColor(red: 0.60, green: 0.60, blue: 0.65, alpha: 1.0) : UIColor(red: 0.38, green: 0.38, blue: 0.42, alpha: 1.0)
    })
    
    static let separator = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .light ? UIColor.black.withAlphaComponent(0.06) : UIColor.white.withAlphaComponent(0.08)
    })

    static let controlRadius: CGFloat = 10
    static let compactRadius: CGFloat = 14
    static let cardRadius: CGFloat = 26
    static let screenHorizontalPadding: CGFloat = 12

    static let minTapTarget: CGFloat = 44

    static let appleMusic = Color(red: 0.98, green: 0.24, blue: 0.34)

    static let heroGradientColors: [Color] = [primary, primaryBright]
    static var fitActionGradient: LinearGradient {
        LinearGradient(
            colors: [fitOrange, primary],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

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
            .overlay(
                RoundedRectangle(cornerRadius: PulseTheme.cardRadius, style: .continuous)
                    .stroke(PulseTheme.separator, lineWidth: 1)
            )
    }
}

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
            .font(.headline)
            .frame(maxWidth: .infinity)
            .frame(height: 58)
        }
        .buttonStyle(.plain)
        .foregroundStyle(.black)
        .background(PulseTheme.accent)
        .clipShape(Capsule())
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
            .font(.headline)
            .frame(maxWidth: .infinity)
            .frame(height: 52)
        }
        .buttonStyle(.plain)
        .foregroundStyle(.primary)
        .background(PulseTheme.grouped)
        .clipShape(Capsule())
        .accessibilityAddTraits(.isButton)
    }
}

struct SectionHeader: View {
    let title: String

    var body: some View {
        Text(verbatim: localizedString(title).capitalizingFirstLetter())
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(PulseTheme.secondaryText)
            .accessibilityAddTraits(.isHeader)
    }
}

/// Standard card-section title: resolves the localization key, enforces sentence-case, and
/// renders with `.headline` weight. Use instead of `Text("key").font(.headline)` inside cards.
struct CardTitle: View {
    private let text: String

    init(_ key: String) {
        self.text = localizedString(key).capitalizingFirstLetter()
    }

    init(verbatim string: String) {
        self.text = string.capitalizingFirstLetter()
    }

    var body: some View {
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

struct StickyHeaderScaffold<Accessory: View, Content: View>: View {
    let title: String
    let subtitle: String?
    let topContentPadding: CGFloat
    let backAction: (() -> Void)?
    let accessory: Accessory
    let content: Content

    @State private var activeTitle: String

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
        _activeTitle = State(initialValue: localizedString(title))
    }

    var body: some View {
        ZStack(alignment: .top) {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 18) {
                    content
                }
                .padding(.horizontal, PulseTheme.screenHorizontalPadding)
                .safeAreaPadding(.top, topContentPadding)
                .padding(.bottom, 120)
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
        }
        .screenBackground()
    }

    private var stickyHeader: some View {
        VStack(spacing: 0) {
            HStack(alignment: .center, spacing: 12) {
                if let backAction {
                    Button {
                        HapticService.selection()
                        backAction()
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(PulseTheme.primary)
                            .frame(width: 42, height: 42)
                            .background(PulseTheme.primary.opacity(0.10))
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("back_2")
                }

                VStack(alignment: .leading, spacing: 3) {
                    if let subtitle {
                        Text(localizedKey(subtitle))
                            .font(.caption.weight(.bold))
                            .textCase(.uppercase)
                            .foregroundStyle(PulseTheme.primary)
                            .lineLimit(1)
                    }

                    Text(verbatim: activeTitle.capitalizingFirstLetter())
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .lineLimit(1)
                        .minimumScaleFactor(0.76)
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
                colors: [PulseTheme.background.opacity(0.72), PulseTheme.background.opacity(0)],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 16)
            .allowsHitTesting(false)
        }
    }

    private func titleForVisibleSection(_ markers: [StickyHeaderTitleMarker]) -> String {
        let threshold: CGFloat = 116
        return markers
            .filter { $0.minY <= threshold }
            .max { $0.minY < $1.minY }?
            .title ?? localizedString(title)
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
                        .fill(PulseTheme.primary.opacity(0.12))
                    Image(systemName: "person.crop.circle.fill")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(PulseTheme.primary)
                }
            }
            .frame(width: PulseTheme.minTapTarget, height: PulseTheme.minTapTarget)
            .clipShape(Circle())
            .overlay(Circle().stroke(.white.opacity(0.9), lineWidth: 2))
            .shadow(color: .black.opacity(0.16), radius: 5, y: 2)
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
                .foregroundStyle(PulseTheme.primary)
                .frame(width: 42, height: 42)
            .background(PulseTheme.grouped)
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
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .foregroundStyle(isSelected ? .black : PulseTheme.secondaryText)
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
                .foregroundStyle(PulseTheme.primary)
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
    var badgeColor: Color = PulseTheme.primary

    var body: some View {
        PulseCard(minHeight: 136) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 8) {
                    ZStack {
                        Circle()
                            .fill(badgeColor.opacity(0.12))
                            .frame(width: 28, height: 28)
                        
                        Image(systemName: systemImage)
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(badgeColor)
                    }
                    Text(localizedKey(title))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(PulseTheme.secondaryText)
                        .lineLimit(2)
                        .minimumScaleFactor(0.82)
                }
                Text(value)
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .foregroundStyle(badgeColor)
                Text(localizedKey(subtitle))
                    .font(.subheadline)
                    .lineLimit(2)
                    .minimumScaleFactor(0.82)
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
        let zoneColor: Color
        if index < 4 {
            zoneColor = PulseTheme.primary
        } else if index < 10 {
            zoneColor = PulseTheme.primaryBright
        } else {
            zoneColor = PulseTheme.accent
        }

        if index < completed {
            return zoneColor
        }
        return zoneColor.opacity(0.16)
    }
}

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
                                .tint(PulseTheme.primary)
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

#Preview("Design System - English") {
    VStack(spacing: 16) {
        SectionHeader(title: "Today")
        MetricCard(title: "Streak", value: "5", subtitle: "Days in a row", systemImage: "flame")
        PrimaryButton("start_workout", systemImage: "play.fill") {}
        SecondaryButton("schedule_workout", systemImage: "calendar.badge.plus") {}
        PulseListRow(title: "Exercise Library", subtitle: "Browse and add movements", systemImage: "magnifyingglass")
        HStack {
            PulseChip(title: "Gym", isSelected: true)
            PulseChip(title: "Home")
        }
        PulseEmptyState(title: "No workout scheduled", message: "Create a plan or schedule a workout to keep momentum.", systemImage: "calendar.badge.plus")
    }
    .padding()
    .screenBackground()
    .environment(\.locale, Locale(identifier: "en"))
}

#Preview("Design System - Spanish") {
    VStack(spacing: 16) {
        SectionHeader(title: "Today")
        MetricCard(title: "Streak", value: "5", subtitle: "Days in a row", systemImage: "flame")
        PrimaryButton("start_workout", systemImage: "play.fill") {}
        SecondaryButton("schedule_workout", systemImage: "calendar.badge.plus") {}
        PulseListRow(title: "Exercise Library", subtitle: "Browse and add movements", systemImage: "magnifyingglass")
        HStack {
            PulseChip(title: "Gym", isSelected: true)
            PulseChip(title: "Home")
        }
        PulseEmptyState(title: "No workout scheduled", message: "Create a plan or schedule a workout to keep momentum.", systemImage: "calendar.badge.plus")
    }
    .padding()
    .screenBackground()
    .environment(\.locale, Locale(identifier: "es"))
}
