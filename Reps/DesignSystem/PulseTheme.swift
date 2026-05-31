import MuscleMap
import SwiftUI

enum PulseTheme {
    static let primary = Color(red: 0.23, green: 0.52, blue: 0.96)
    static let primaryBright = Color(red: 0.33, green: 0.86, blue: 0.32)
    static let accent = Color(red: 1.0, green: 0.80, blue: 0.14)
    static let destructive = Color(red: 0.93, green: 0.24, blue: 0.22)
    static let warning = Color(red: 1.0, green: 0.60, blue: 0.14)

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

    static let compactRadius: CGFloat = 14
    static let cardRadius: CGFloat = 26
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
        case "cardio": "Cardio"
        case "chest": "Pecho"
        case "core", "abdominals": "Core"
        case "full body": "Cuerpo completo"
        case "glutes": "Glúteos"
        case "legs": "Piernas"
        case "neck": "Cuello"
        case "shoulders": "Hombros"
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

    init(minHeight: CGFloat? = nil, @ViewBuilder content: () -> Content) {
        self.content = content()
        self.minHeight = minHeight
    }

    var body: some View {
        content
            .frame(maxWidth: .infinity, maxHeight: minHeight != nil ? .infinity : nil, alignment: .leading)
            .padding(16)
            .frame(minHeight: minHeight, alignment: .leading)
            .background(PulseTheme.card)
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
                Text(title)
            }
            .font(.headline)
            .frame(maxWidth: .infinity)
            .frame(height: 58)
        }
        .buttonStyle(.plain)
        .foregroundStyle(.black)
        .background(.white)
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
                Text(title)
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
    let title: LocalizedStringKey

    var body: some View {
        Text(title)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(PulseTheme.secondaryText)
            .accessibilityAddTraits(.isHeader)
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
                Text(title).font(.headline)
                Text(subtitle)
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
        Text(title)
            .font(.subheadline.weight(.semibold))
            .lineLimit(1)
            .minimumScaleFactor(0.85)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .foregroundStyle(isSelected ? .black : PulseTheme.secondaryText)
            .background(isSelected ? .white : PulseTheme.grouped)
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
            Text(title)
                .font(.title2.bold())
            Text(message)
                .foregroundStyle(PulseTheme.secondaryText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
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
                    Text(title)
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
                Text(subtitle)
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

    nonisolated static func == (lhs: ExerciseMediaThumbnail, rhs: ExerciseMediaThumbnail) -> Bool {
        lhs.exercise.id == rhs.exercise.id
            && lhs.exercise.name == rhs.exercise.name
            && lhs.exercise.muscleGroup == rhs.exercise.muscleGroup
            && lhs.exercise.secondaryMuscles == rhs.exercise.secondaryMuscles
            && lhs.exercise.tags == rhs.exercise.tags
            && lhs.exercise.mediaURL == rhs.exercise.mediaURL
            && lhs.exercise.customImageData == rhs.exercise.customImageData
            && lhs.gender == rhs.gender
    }

    var body: some View {
        ZStack {
            if let data = exercise.customImageData,
               let image = UIImage(data: data) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else if let url = exercise.mediaAssetURL {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                    case .failure, .empty:
                        fallback
                    @unknown default:
                        fallback
                    }
                }
            } else {
                fallback
            }
        }
        .background(PulseTheme.grouped)
        .clipped()
    }

    private var fallback: some View {
        GeometryReader { proxy in
            ExerciseAnatomyThumbnail(
                exercise: exercise,
                gender: gender,
                size: max(44, min(proxy.size.width, proxy.size.height))
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

extension View {
    func screenBackground() -> some View {
        background(PulseTheme.background.ignoresSafeArea())
    }

    func mainTabBarHidden(_ hidden: Bool = true) -> some View {
        preference(key: MainTabBarHiddenPreferenceKey.self, value: hidden)
    }
}

#Preview("Design System - English") {
    VStack(spacing: 16) {
        SectionHeader(title: "Today")
        MetricCard(title: "Streak", value: "5", subtitle: "Days in a row", systemImage: "flame")
        PrimaryButton("Start Workout", systemImage: "play.fill") {}
        SecondaryButton("Schedule Workout", systemImage: "calendar.badge.plus") {}
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
        PrimaryButton("Start Workout", systemImage: "play.fill") {}
        SecondaryButton("Schedule Workout", systemImage: "calendar.badge.plus") {}
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
