import MuscleMap
import SwiftUI

struct ProfileSetupView: View {
    @Environment(AppStore.self) private var store
    @State private var profile = UserProfile()
    @State private var step: OnboardingStep = .presentation
    @FocusState private var isEventNameFocused: Bool
    @State private var selectedSex: OnboardingSex?
    @State private var age = 32
    @State private var heightCm = 178.0
    @State private var weightKg = 78.0
    @State private var sessionLengthMinutes: Int? = 60
    @State private var focusMuscles: Set<String> = []
    @State private var generationPulse = false
    @State private var selectedConsistencyIndex = 0
    @State private var generationProgress: Double = 0.0
    @State private var generationStatusText: String = "Analizando métricas base..."
    @State private var isGenerationComplete = false
    @State private var hasTargetEvent = false
    @State private var targetEventName = ""
    @State private var targetEventDate = Calendar.current.date(byAdding: .weekOfYear, value: 8, to: .now) ?? .now

    var onFinish: (OnboardingResult) -> Void
    var onSkip: () -> Void = {}

    private let steps = OnboardingStep.allCases

    private var bodyMetric: BodyMetric {
        BodyMetric(date: .now, weightKg: weightKg, heightCm: heightCm, source: .manual)
    }

    private var generatedPlan: WorkoutPlan {
        var configured = profile
        configured.sex = selectedSex?.profileValue
        configured.dateOfBirth = Calendar.current.date(byAdding: .year, value: -age, to: .now)
        configured.availableEquipment = configuredEquipment
        
        if hasTargetEvent {
            configured.targetEventName = targetEventName.isEmpty ? "Evento" : targetEventName
            configured.targetEventDate = targetEventDate
        } else {
            configured.targetEventName = nil
            configured.targetEventDate = nil
        }

        return OnboardingPlanBuilder.makePlan(
            profile: configured,
            bodyMetric: bodyMetric,
            sessionLengthMinutes: sessionLengthMinutes,
            focusMuscles: Array(focusMuscles)
        )
    }

    private var configuredEquipment: [String] {
        profile.availableEquipment.isEmpty ? defaultEquipment(for: profile.trainingLocation) : profile.availableEquipment
    }

    private var selectedGender: BodyGender {
        selectedSex == .female ? .female : .male
    }

    var body: some View {
        VStack(spacing: 0) {
            progressHeader

            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    stepContent
                }
                .padding(20)
                .padding(.bottom, bottomContentPadding)
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .screenBackground()
        .safeAreaInset(edge: .bottom) {
            bottomBar
        }
        .animation(.snappy(duration: 0.25), value: step)
        .onChange(of: step) { _, newStep in
            isEventNameFocused = false
            if newStep == .generating {
                generationPulse = false
                withAnimation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true)) {
                    generationPulse = true
                }
                startPlanGenerationSimulation()
            }
        }
    }

    private var progressHeader: some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                if stepIndex > 0 {
                    Button {
                        moveBackward()
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.subheadline.weight(.bold))
                            .frame(width: 34, height: 34)
                            .foregroundStyle(.primary)
                            .background(PulseTheme.grouped)
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Retroceder")
                }

                Text("Reps")
                    .font(.headline.weight(.bold))

                Spacer(minLength: 8)

                Text("\(stepIndex + 1)/\(steps.count)")
                    .font(.caption.weight(.bold).monospacedDigit())
                    .foregroundStyle(PulseTheme.secondaryText)

                Button {
                    onSkip()
                } label: {
                    Text("Saltar")
                        .font(.caption.weight(.bold))
                        .padding(.horizontal, 12)
                        .frame(height: 32)
                        .foregroundStyle(PulseTheme.primary)
                        .background(PulseTheme.grouped)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Saltar onboarding")
            }

            ProgressView(value: Double(stepIndex + 1), total: Double(steps.count))
                .tint(PulseTheme.accent)
        }
        .padding(.horizontal, 20)
        .padding(.top, 10)
        .padding(.bottom, 8)
    }

    @ViewBuilder
    private var stepContent: some View {
        switch step {
        case .presentation:
            presentationStep
        case .sex:
            sexStep
        case .metrics:
            metricsStep
        case .goal:
            goalStep
        case .training:
            trainingStep
        case .focus:
            focusStep
        case .generating:
            generatingStep
        case .plan:
            planStep
        case .paywall:
            paywallStep
        }
    }

    private var presentationStep: some View {
        VStack(alignment: .leading, spacing: 22) {
            VStack(alignment: .leading, spacing: 18) {
                Text("Entrena con un plan que se adapta a ti.")
                    .font(.system(size: 44, weight: .bold, design: .rounded))
                    .lineLimit(4)
                    .minimumScaleFactor(0.75)
                Text("Reps combina tus métricas, objetivo, equipo y recuperación para crear una rutina base y convertir cada sesión en datos útiles.")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(PulseTheme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }

            PulseCard {
                VStack(spacing: 18) {
                    HStack {
                        OnboardingSignal(title: "Plan", value: "8 semanas", color: PulseTheme.primary)
                        OnboardingSignal(title: "Progreso", value: "por músculo", color: PulseTheme.primaryBright)
                        OnboardingSignal(title: "Predicción", value: "visual", color: PulseTheme.accent)
                    }

                    HStack(spacing: 8) {
                        ForEach(0..<12, id: \.self) { index in
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .fill(progressColor(for: index, filled: index < 8))
                                .frame(height: 38)
                        }
                    }
                }
            }

            HStack(spacing: 12) {
                OnboardingBenefit(icon: "figure.strengthtraining.traditional", title: "Rutinas listas", subtitle: "Días, ejercicios, series y descansos.")
                OnboardingBenefit(icon: "chart.line.uptrend.xyaxis", title: "Pronósticos", subtitle: "Evolución muscular esperada.")
            }
        }
    }

    private var sexStep: some View {
        VStack(alignment: .leading, spacing: 18) {
            OnboardingTitle(
                title: "Elige el cuerpo que usará la app",
                subtitle: "A partir de aquí, los mapas musculares y gráficos se muestran solo con este sexo."
            )

            HStack(spacing: 14) {
                ForEach(OnboardingSex.allCases) { sex in
                    Button {
                        selectedSex = sex
                    } label: {
                        VStack(spacing: 14) {
                            BodyView(gender: sex.bodyGender, side: .front, style: .onboardingDark)
                                .frame(width: 74, height: 100)
                                .allowsHitTesting(false)
                                .accessibilityHidden(true)
                            Text(sex.title)
                                .font(.headline)
                            Image(systemName: selectedSex == sex ? "checkmark.circle.fill" : "circle")
                                .font(.title2)
                                .foregroundStyle(selectedSex == sex ? PulseTheme.primaryBright : PulseTheme.secondaryText)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 18)
                        .foregroundStyle(.primary)
                                .background(selectedSex == sex ? PulseTheme.accentMuted : PulseTheme.card)
                        .clipShape(RoundedRectangle(cornerRadius: PulseTheme.cardRadius, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: PulseTheme.cardRadius, style: .continuous)
                                .stroke(selectedSex == sex ? PulseTheme.accent : PulseTheme.separator, lineWidth: 1.2)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var metricsStep: some View {
        VStack(alignment: .leading, spacing: 18) {
            OnboardingTitle(
                title: "Ajusta tu punto de partida",
                subtitle: "Usaremos estos datos para estimar cargas iniciales, volumen tolerable y progresión."
            )

            VStack(spacing: 14) {
                OnboardingRulerMetric(
                    title: "Edad",
                    valueText: "\(age)",
                    unit: "años",
                    caption: "Experiencia, recuperación y volumen inicial.",
                    icon: "calendar",
                    value: Binding(
                        get: { Double(age) },
                        set: { age = Int($0.rounded()) }
                    ),
                    range: 14...85,
                    step: 1
                )

                OnboardingRulerMetric(
                    title: "Altura",
                    valueText: String(format: "%.0f", heightCm),
                    unit: "cm",
                    caption: "Ayuda a contextualizar peso y composición.",
                    icon: "ruler",
                    value: $heightCm,
                    range: 130...220,
                    step: 1
                )

                OnboardingRulerMetric(
                    title: "Peso",
                    valueText: String(format: "%.1f", weightKg),
                    unit: "kg",
                    caption: "Base para tu objetivo y estimaciones de progreso.",
                    icon: "scalemass.fill",
                    value: $weightKg,
                    range: 35...180,
                    step: 0.5
                )
            }

            metricsRecommendationView
        }
    }

    private var metricsRecommendationView: some View {
        let bmi = weightKg / ((heightCm / 100) * (heightCm / 100))
        let title: String
        let description: String
        let tag: String
        let iconName: String
        let iconColor: Color

        if bmi < 18.5 {
            title = "Foco sugerido: Ganar Masa Muscular"
            description = "Tu peso actual es bajo para tu altura. Te sugerimos priorizar entrenamientos de fuerza orientados a hipertrofia muscular (tanto en casa con mancuernas como en gimnasio) acompañados de una buena alimentación."
            tag = "Hipertrofia"
            iconName = "scalemass.fill"
            iconColor = PulseTheme.primary
        } else if bmi < 25.0 {
            title = "Foco sugerido: Tonificación y Fuerza"
            description = "Te encuentras en un rango de peso saludable. Tu plan se centrará en la recomposición corporal, mejorando tu fuerza y definición muscular en casa o en el gimnasio."
            tag = "Recomposición"
            iconName = "figure.strengthtraining.traditional"
            iconColor = PulseTheme.primaryBright
        } else if bmi < 30.0 {
            title = "Foco sugerido: Pérdida de Grasa"
            description = "Tu peso actual indica sobrepeso. Te sugerimos rutinas que combinen entrenamientos de fuerza de intensidad moderada-alta para mantener el músculo mientras pierdes grasa."
            tag = "Déficit Calórico"
            iconName = "flame.fill"
            iconColor = PulseTheme.warning
        } else {
            title = "Foco sugerido: Salud y Resistencia"
            description = "Te sugerimos rutinas con ejercicios de bajo impacto (peso corporal o máquinas de cardio en el gimnasio) para cuidar tus articulaciones mientras mejoras tu salud metabólica."
            tag = "Bajo Impacto"
            iconName = "heart.text.square.fill"
            iconColor = PulseTheme.destructive
        }

        return PulseCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 8) {
                    Image(systemName: iconName)
                        .foregroundStyle(iconColor)
                        .font(.title3.bold())
                    Text("Análisis de Composición")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(PulseTheme.secondaryText)
                    Spacer()
                    Text("IMC: \(bmi, specifier: "%.1f")")
                        .font(.caption.bold())
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(iconColor.opacity(0.12))
                        .foregroundStyle(iconColor)
                        .clipShape(Capsule())
                }

                Text(title)
                    .font(.headline)

                Text(description)
                    .font(.subheadline)
                    .foregroundStyle(PulseTheme.secondaryText)
                    .lineLimit(nil)
                    .fixedSize(horizontal: false, vertical: true)

                HStack {
                    Text("Recomendación:")
                        .font(.caption.bold())
                        .foregroundStyle(PulseTheme.secondaryText)
                    Text(tag)
                        .font(.caption.bold())
                        .foregroundStyle(.black)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(PulseTheme.accent)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                }
                .padding(.top, 4)
            }
        }
    }

    private var goalStep: some View {
        VStack(alignment: .leading, spacing: 20) {
            optionStep(
                title: "¿Cuál es tu objetivo principal?",
                subtitle: "Esto cambia repeticiones, descansos y foco del plan generado.",
                options: UserProfile.MainGoal.allCases,
                selection: $profile.mainGoal,
                titleForOption: goalTitle,
                iconForOption: icon(for:)
            )
            
            targetEventCard
        }
    }

    private var trainingStep: some View {
        VStack(alignment: .leading, spacing: 18) {
            optionStep(
                title: "¿Dónde y con qué frecuencia entrenas?",
                subtitle: "Escoge el escenario más realista. Luego afinamos equipo y duración.",
                options: UserProfile.TrainingLocation.allCases,
                selection: $profile.trainingLocation,
                titleForOption: locationTitle,
                iconForOption: icon(for:)
            )

            PulseCard {
                VStack(alignment: .leading, spacing: 18) {
                    Text("\(profile.weeklyTrainingDays) días por semana")
                        .font(.title2.weight(.bold))
                    HStack(spacing: 8) {
                        ForEach(2...6, id: \.self) { day in
                            Button {
                                profile.weeklyTrainingDays = day
                            } label: {
                                Text("\(day)")
                                    .font(.headline.monospacedDigit())
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 48)
                                    .foregroundStyle(profile.weeklyTrainingDays == day ? .black : PulseTheme.secondaryText)
                                    .background(profile.weeklyTrainingDays == day ? PulseTheme.accent : PulseTheme.grouped)
                                    .clipShape(RoundedRectangle(cornerRadius: PulseTheme.compactRadius, style: .continuous))
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    Text("Duración por sesión")
                        .font(.headline)
                    HStack(spacing: 8) {
                        ForEach([30, 45, 60, 75, 90], id: \.self) { minutes in
                            Button {
                                sessionLengthMinutes = minutes
                            } label: {
                                Text(minutes == 90 ? "90m+" : "\(minutes)m")
                                    .font(.headline)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 46)
                                    .foregroundStyle(sessionLengthMinutes == minutes ? .black : PulseTheme.secondaryText)
                                    .background(sessionLengthMinutes == minutes ? PulseTheme.accent : PulseTheme.grouped)
                                    .clipShape(RoundedRectangle(cornerRadius: PulseTheme.compactRadius, style: .continuous))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }

            equipmentStep
        }
    }

    private var areAllEquipmentSelected: Bool {
        let current = configuredEquipment
        return equipmentOptions.allSatisfy { current.contains($0) }
    }

    private func toggleAllEquipment() {
        if areAllEquipmentSelected {
            profile.availableEquipment = []
        } else {
            profile.availableEquipment = equipmentOptions
        }
    }

    private var equipmentStep: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Equipo disponible")
                        .font(.title3.weight(.bold))
                    Text("Marca todo lo que puedes usar con comodidad. Cuanto más preciso sea, mejor ajustaremos ejercicios, variantes y progresión.")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(PulseTheme.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 12)
                Button {
                    toggleAllEquipment()
                } label: {
                    Text(areAllEquipmentSelected ? "Desmarcar" : "Marcar todo")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(PulseTheme.primary)
                        .lineLimit(1)
                }
                .buttonStyle(.plain)
            }

            equipmentSummary

            ForEach(EquipmentCategory.allCases) { category in
                EquipmentCategorySection(
                    category: category,
                    options: equipmentCatalog.filter { $0.category == category },
                    selectedValues: Set(configuredEquipment),
                    onToggle: toggleEquipment,
                    onToggleCategory: { toggleEquipmentCategory(category) }
                )
            }
        }
    }

    private var equipmentSummary: some View {
        let selected = configuredEquipment.count
        let total = equipmentOptions.count

        return HStack(spacing: 10) {
            Label("\(selected)/\(total)", systemImage: "checklist.checked")
            Divider()
                .frame(height: 18)
            Label(equipmentCoverageLabel, systemImage: equipmentCoverageIcon)
            Spacer(minLength: 0)
        }
        .font(.caption.weight(.bold))
        .foregroundStyle(.primary)
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(PulseTheme.grouped)
        .clipShape(RoundedRectangle(cornerRadius: PulseTheme.compactRadius, style: .continuous))
        .accessibilityLabel("Equipamiento seleccionado: \(selected) de \(total). \(equipmentCoverageLabel)")
    }

    private var equipmentCoverageLabel: String {
        let selected = Set(configuredEquipment)
        if selected.contains("Barbell") && selected.contains("Cable") && selected.contains("Machine") {
            return "Gimnasio completo"
        }
        if selected.contains("Dumbbells") && selected.contains("Resistance Band") && selected.contains("Bodyweight") {
            return "Casa bien equipada"
        }
        if selected.contains("Bodyweight") && selected.count <= 2 {
            return "Minimalista"
        }
        return "Mixto"
    }

    private var equipmentCoverageIcon: String {
        switch equipmentCoverageLabel {
        case "Gimnasio completo": "building.2.fill"
        case "Casa bien equipada": "house.fill"
        case "Minimalista": "figure.strengthtraining.functional"
        default: "arrow.triangle.2.circlepath"
        }
    }

    private func toggleEquipmentCategory(_ category: EquipmentCategory) {
        if profile.availableEquipment.isEmpty {
            profile.availableEquipment = configuredEquipment
        }

        let categoryValues = equipmentCatalog
            .filter { $0.category == category }
            .map(\.value)
        let selected = Set(profile.availableEquipment)

        if categoryValues.allSatisfy(selected.contains) {
            profile.availableEquipment.removeAll { categoryValues.contains($0) }
        } else {
            for value in categoryValues where !profile.availableEquipment.contains(value) {
                profile.availableEquipment.append(value)
            }
        }
    }

    private var equipmentCatalog: [EquipmentOption] {
        [
            EquipmentOption(value: "Barbell", category: .freeWeights, title: "Barra olímpica", subtitle: "Sentadilla, press, peso muerto y básicos pesados.", icon: "figure.strengthtraining.traditional", tint: PulseTheme.primary),
            EquipmentOption(value: "EZ Bar", category: .freeWeights, title: "Barra Z", subtitle: "Curl, extensiones y trabajo de brazos con agarre cómodo.", icon: "waveform.path.ecg", tint: PulseTheme.primary),
            EquipmentOption(value: "Dumbbells", category: .freeWeights, title: "Mancuernas", subtitle: "Press, remos, zancadas y accesorios unilaterales.", icon: "dumbbell.fill", tint: PulseTheme.primaryBright),
            EquipmentOption(value: "Kettlebell", category: .freeWeights, title: "Kettlebell", subtitle: "Swings, goblet squat, carries y potencia de cadera.", icon: "kettlebell.fill", tint: PulseTheme.warning),
            EquipmentOption(value: "Bodyweight", category: .bodyweight, title: "Peso corporal", subtitle: "Flexiones, core, movilidad y progresiones sin material.", icon: "figure.strengthtraining.functional", tint: PulseTheme.primaryBright),
            EquipmentOption(value: "Resistance Band", category: .bodyweight, title: "Bandas elásticas", subtitle: "Activación, tirones, face pulls y asistencia.", icon: "point.3.connected.trianglepath.dotted", tint: PulseTheme.accent),
            EquipmentOption(value: "Suspension Trainer", category: .bodyweight, title: "TRX / suspensión", subtitle: "Remos, press, bisagras y core con ángulo ajustable.", icon: "figure.core.training", tint: PulseTheme.accent),
            EquipmentOption(value: "Bench", category: .bodyweight, title: "Banco", subtitle: "Press inclinado, step-ups, hip thrust y apoyo técnico.", icon: "table.furniture", tint: PulseTheme.primary),
            EquipmentOption(value: "Pullup Bar", category: .bodyweight, title: "Barra de dominadas", subtitle: "Dominadas, hangs, elevaciones de piernas y tirones.", icon: "figure.pull.ups", tint: PulseTheme.primaryBright),
            EquipmentOption(value: "Cable", category: .machines, title: "Poleas", subtitle: "Jalones, remos, cruces, tríceps y tensión constante.", icon: "point.3.connected.trianglepath.dotted", tint: PulseTheme.primary),
            EquipmentOption(value: "Machine", category: .machines, title: "Máquinas guiadas", subtitle: "Press, extensión, curl femoral y patrones estables.", icon: "rectangle.3.group.bubble.left", tint: PulseTheme.primary),
            EquipmentOption(value: "Smith Machine", category: .machines, title: "Multipower / Smith", subtitle: "Sentadillas, presses y gemelos con trayectoria guiada.", icon: "square.grid.3x3.middle.filled", tint: PulseTheme.warning),
            EquipmentOption(value: "Leg Press", category: .machines, title: "Prensa de piernas", subtitle: "Volumen pesado de pierna con menor demanda técnica.", icon: "figure.strengthtraining.traditional", tint: PulseTheme.warning),
            EquipmentOption(value: "Rack", category: .machines, title: "Rack / jaula", subtitle: "Soportes, barras de seguridad, dominadas y básicos pesados.", icon: "square.split.3x3", tint: PulseTheme.primary),
            EquipmentOption(value: "Cardio Machine", category: .conditioning, title: "Cardio", subtitle: "Cinta, bici, remo, elíptica o bicicleta de aire.", icon: "figure.run", tint: PulseTheme.destructive),
            EquipmentOption(value: "Medicine Ball", category: .conditioning, title: "Balón medicinal", subtitle: "Lanzamientos, rotaciones, potencia y acondicionamiento.", icon: "circle.hexagongrid.fill", tint: PulseTheme.accent)
        ]
    }

    private var equipmentOptions: [String] {
        equipmentCatalog.map(\.value)
    }

    private enum EquipmentCategory: String, CaseIterable, Identifiable {
        case freeWeights
        case bodyweight
        case machines
        case conditioning

        var id: String { rawValue }

        var title: String {
            switch self {
            case .freeWeights: "Fuerza libre"
            case .bodyweight: "Casa y accesorios"
            case .machines: "Gimnasio avanzado"
            case .conditioning: "Cardio y potencia"
            }
        }

        var subtitle: String {
            switch self {
            case .freeWeights: "Carga progresiva, básicos y accesorios."
            case .bodyweight: "Material portátil, soporte y calistenia."
            case .machines: "Poleas, estaciones guiadas y estructuras."
            case .conditioning: "Trabajo energético, intervalos y explosividad."
            }
        }
    }

    private struct EquipmentOption: Identifiable {
        var id: String { value }
        let value: String
        let category: EquipmentCategory
        let title: String
        let subtitle: String
        let icon: String
        let tint: Color
    }

    private struct EquipmentCategorySection: View {
        let category: EquipmentCategory
        let options: [EquipmentOption]
        let selectedValues: Set<String>
        let onToggle: (String) -> Void
        let onToggleCategory: () -> Void

        private var selectedCount: Int {
            options.filter { selectedValues.contains($0.value) }.count
        }

        private var isFullySelected: Bool {
            selectedCount == options.count
        }

        private var columns: [GridItem] {
            [GridItem(.adaptive(minimum: 152), spacing: 10, alignment: .top)]
        }

        var body: some View {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .firstTextBaseline, spacing: 12) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(category.title)
                            .font(.headline)
                        Text(category.subtitle)
                            .font(.caption.weight(.medium))
                            .foregroundStyle(PulseTheme.secondaryText)
                    }
                    Spacer()
                    Button {
                        onToggleCategory()
                    } label: {
                        Text(isFullySelected ? "Quitar" : "Todo")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(PulseTheme.primary)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 7)
                            .background(PulseTheme.grouped)
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }

                LazyVGrid(columns: columns, alignment: .leading, spacing: 10) {
                    ForEach(options) { option in
                        EquipmentOptionCard(
                            option: option,
                            isSelected: selectedValues.contains(option.value),
                            action: { onToggle(option.value) }
                        )
                    }
                }
            }
            .padding(14)
            .background(PulseTheme.card)
            .clipShape(RoundedRectangle(cornerRadius: PulseTheme.cardRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: PulseTheme.cardRadius, style: .continuous)
                    .stroke(PulseTheme.separator, lineWidth: 1)
            )
        }
    }

    private struct EquipmentOptionCard: View {
        let option: EquipmentOption
        let isSelected: Bool
        let action: () -> Void

        var body: some View {
            Button(action: action) {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(alignment: .top) {
                        Image(systemName: option.icon)
                            .font(.headline.weight(.bold))
                            .foregroundStyle(isSelected ? .black : option.tint)
                            .frame(width: 34, height: 34)
                            .background(isSelected ? option.tint : option.tint.opacity(0.16))
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        Spacer()
                        Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(isSelected ? PulseTheme.primaryBright : PulseTheme.tertiaryText)
                    }

                    VStack(alignment: .leading, spacing: 5) {
                        Text(option.title)
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(.primary)
                            .fixedSize(horizontal: false, vertical: true)
                        Text(option.subtitle)
                            .font(.caption)
                            .foregroundStyle(PulseTheme.secondaryText)
                            .lineLimit(3)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer(minLength: 0)
                }
                .frame(maxWidth: .infinity, minHeight: 156, alignment: .topLeading)
                .padding(12)
                .background(isSelected ? PulseTheme.elevated : PulseTheme.grouped)
                .clipShape(RoundedRectangle(cornerRadius: PulseTheme.compactRadius, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: PulseTheme.compactRadius, style: .continuous)
                        .stroke(isSelected ? option.tint.opacity(0.7) : PulseTheme.separator, lineWidth: isSelected ? 1.5 : 1)
                )
                .contentShape(RoundedRectangle(cornerRadius: PulseTheme.compactRadius, style: .continuous))
            }
            .buttonStyle(.plain)
            .accessibilityLabel(option.title)
            .accessibilityValue(isSelected ? "Seleccionado" : "No seleccionado")
        }
    }

    private var areAllMusclesSelected: Bool {
        focusMuscles.count == focusOptions.count
    }

    private func toggleAllMuscles() {
        if areAllMusclesSelected {
            focusMuscles.removeAll()
        } else {
            focusMuscles = Set(focusOptions.map { $0.key })
        }
    }

    private var focusStep: some View {
        VStack(alignment: .leading, spacing: 18) {
            OnboardingTitle(
                title: "¿Quieres priorizar algún músculo?",
                subtitle: "Escoge las zonas que quieras priorizar o selecciona todas."
            )

            OnboardingBodyPair(gender: selectedGender, selectedMuscles: selectedFocusMuscles) { muscle in
                if let focus = focusKey(for: muscle) {
                    toggleFocus(focus)
                }
            }
            .frame(height: 520)

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 100), spacing: 10)], spacing: 10) {
                Button {
                    toggleAllMuscles()
                } label: {
                    Text("Todos")
                        .font(.caption.weight(.bold))
                        .frame(maxWidth: .infinity)
                        .frame(height: 34)
                        .foregroundStyle(areAllMusclesSelected ? .black : PulseTheme.secondaryText)
                        .background(areAllMusclesSelected ? PulseTheme.accent : PulseTheme.grouped)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)

                ForEach(focusOptions, id: \.key) { option in
                    Button {
                        toggleFocus(option.key)
                    } label: {
                        Text(option.title)
                            .font(.caption.weight(.bold))
                            .frame(maxWidth: .infinity)
                            .frame(height: 34)
                            .foregroundStyle(focusMuscles.contains(option.key) ? .black : PulseTheme.secondaryText)
                            .background(focusMuscles.contains(option.key) ? PulseTheme.accent : PulseTheme.grouped)
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func startPlanGenerationSimulation() {
        generationProgress = 0.0
        isGenerationComplete = false
        generationStatusText = "Analizando tus métricas corporales..."
        
        let steps: [(delay: Double, progress: Double, text: String)] = [
            (0.8, 0.3, "Evaluando equipamiento disponible..."),
            (1.6, 0.6, "Priorizando grupos musculares seleccionados..."),
            (2.4, 0.85, "Calculando volumen y series óptimas..."),
            (3.2, 1.0, "¡Plan personalizado construido!")
        ]
        
        for step in steps {
            DispatchQueue.main.asyncAfter(deadline: .now() + step.delay) {
                withAnimation(.easeInOut(duration: 0.4)) {
                    self.generationProgress = step.progress
                    self.generationStatusText = step.text
                    if step.progress >= 1.0 {
                        self.isGenerationComplete = true
                    }
                }
            }
        }
    }

    private var generatingStep: some View {
        VStack(alignment: .center, spacing: 28) {
            if !isGenerationComplete {
                RepsLoadingView(
                    messages: [generationStatusText],
                    progress: generationProgress,
                    layout: .panel
                )
                .padding(.top, 44)
                .frame(maxWidth: .infinity, minHeight: 450)
            } else {
                VStack(alignment: .center, spacing: 24) {
                    OnboardingTitle(
                        title: "¡Tu plan base está listo!",
                        subtitle: "El mapa muestra la distribución muscular prevista según tu foco."
                    )

                    ZStack {
                        OnboardingBodyPair(gender: selectedGender, heatmap: generationHeatmap)
                            .frame(height: 480)
                            .scaleEffect(generationPulse ? 1.03 : 0.98)
                            .opacity(generationPulse ? 1 : 0.78)
                        VStack {
                            Spacer()
                            Text("\(generatedPlan.days.count) días listos")
                                .font(.caption.weight(.bold))
                                .padding(.horizontal, 12)
                                .padding(.vertical, 7)
                                .background(.ultraThinMaterial)
                                .clipShape(Capsule())
                        }
                    }
                    .frame(maxWidth: .infinity)

                    HStack(spacing: 8) {
                        GenerationPill(title: "Series", value: "\(weeklySetTotal)")
                        GenerationPill(title: "Descanso", value: "\(generatedPlan.days.first?.restBetweenExercisesSeconds ?? 120)s")
                        GenerationPill(title: "Semanas", value: "\(generatedPlan.totalWeeks)")
                    }

                    suggestedPlanSummary
                    forecastStep
                }
                .transition(.opacity.combined(with: .scale))
            }
        }
    }

    private var suggestedPlanSummary: some View {
        PulseCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Plan sugerido")
                            .font(.headline)
                        Text("\(generatedPlan.daysPerWeek) días/semana durante \(generatedPlan.totalWeeks) semanas")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(PulseTheme.secondaryText)
                    }
                    Spacer()
                    Image(systemName: "sparkles")
                        .font(.headline)
                        .foregroundStyle(.black)
                        .frame(width: 34, height: 34)
                        .background(PulseTheme.accent)
                        .clipShape(Circle())
                }

                ForEach(generatedPlan.days.prefix(3)) { day in
                    HStack(spacing: 10) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(PulseTheme.primaryBright)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(day.title)
                                .font(.subheadline.weight(.bold))
                            Text("\(day.exercises.count) ejercicios - \(day.durationMinutes) min")
                                .font(.caption)
                                .foregroundStyle(PulseTheme.secondaryText)
                        }
                        Spacer()
                    }
                }

                if generatedPlan.days.count > 3 {
                    Text("+\(generatedPlan.days.count - 3) dias adicionales incluidos")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(PulseTheme.primary)
                }
            }
        }
    }

    private var planStep: some View {
        VStack(alignment: .leading, spacing: 18) {
            OnboardingTitle(
                title: "Tu plan está listo",
                subtitle: "Incluye días, ejercicios, descansos entre ejercicios y descansos entre series."
            )

            ForEach(generatedPlan.days) { day in
                PulseCard {
                    VStack(alignment: .leading, spacing: 16) {
                        HStack(alignment: .firstTextBaseline) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(day.title)
                                    .font(.title3.weight(.bold))
                                Text("\(day.durationMinutes) min - \(day.restBetweenExercisesSeconds)s entre ejercicios")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(PulseTheme.secondaryText)
                            }
                            Spacer()
                        }
                        
                        Divider()
                            .background(PulseTheme.separator)
                            .padding(.vertical, 2)

                        VStack(spacing: 16) {
                            ForEach(Array(day.exercises.enumerated()), id: \.offset) { index, item in
                                if index > 0 {
                                    Divider()
                                        .background(PulseTheme.separator)
                                        .padding(.vertical, 2)
                                }
                                
                                HStack(spacing: 16) {
                                    // Left: Image or Anatomy Map Thumbnail
                                    ExerciseMediaThumbnail(exercise: item.exercise, gender: selectedGender)
                                        .frame(width: 76, height: 76)
                                        .clipShape(RoundedRectangle(cornerRadius: PulseTheme.compactRadius, style: .continuous))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: PulseTheme.compactRadius, style: .continuous)
                                                .stroke(PulseTheme.separator, lineWidth: 1)
                                        )
                                        .shadow(color: Color.black.opacity(0.12), radius: 3, x: 0, y: 1.5)

                                    // Right: Info & stats
                                    VStack(alignment: .leading, spacing: 6) {
                                        // Name & Priority
                                        HStack(alignment: .center, spacing: 8) {
                                            Text(RepsText.exerciseName(item.exercise.name, language: profile.preferredLanguage))
                                                .font(.headline)
                                                .foregroundStyle(.white)
                                                .lineLimit(1)
                                            
                                            if item.priority == .primary {
                                                Text("Foco")
                                                    .font(.system(size: 10, weight: .bold))
                                                    .padding(.horizontal, 6)
                                                    .padding(.vertical, 2)
                                                    .background(PulseTheme.accent.opacity(0.16))
                                                    .foregroundStyle(PulseTheme.accent)
                                                    .clipShape(Capsule())
                                            }
                                        }

                                        // Badges for muscles
                                        HStack(spacing: 6) {
                                            Text(RepsText.muscle(item.exercise.muscleGroup, language: profile.preferredLanguage))
                                                .font(.system(size: 11, weight: .bold))
                                                .padding(.horizontal, 8)
                                                .padding(.vertical, 3)
                                                .background(PulseTheme.primary.opacity(0.14))
                                                .foregroundStyle(PulseTheme.primaryBright)
                                                .clipShape(Capsule())

                                            ForEach(item.exercise.secondaryMuscles.prefix(2), id: \.self) { secondary in
                                                Text(RepsText.muscle(secondary, language: profile.preferredLanguage))
                                                    .font(.system(size: 10, weight: .medium))
                                                    .padding(.horizontal, 6)
                                                    .padding(.vertical, 2)
                                                    .background(PulseTheme.grouped)
                                                    .foregroundStyle(PulseTheme.secondaryText)
                                                    .clipShape(Capsule())
                                            }
                                        }

                                        // Technical metrics row
                                        HStack(spacing: 12) {
                                            Label {
                                                Text("\(item.targetSets) series")
                                                    .font(.caption.weight(.semibold))
                                            } icon: {
                                                Image(systemName: "square.stack.3d.up.fill")
                                                    .font(.caption)
                                            }
                                            .foregroundStyle(PulseTheme.secondaryText)

                                            Label {
                                                Text(item.repRange)
                                                    .font(.caption.weight(.semibold))
                                            } icon: {
                                                Image(systemName: item.exercise.trackingType == .duration ? "clock.fill" : "repeat")
                                                    .font(.caption)
                                            }
                                            .foregroundStyle(PulseTheme.secondaryText)

                                            Label {
                                                Text("\(item.restSeconds)s")
                                                    .font(.caption.weight(.semibold))
                                            } icon: {
                                                Image(systemName: "timer")
                                                    .font(.caption)
                                            }
                                            .foregroundStyle(PulseTheme.secondaryText)
                                        }
                                        .padding(.top, 2)
                                    }

                                    Spacer()
                                }
                            }
                        }
                    }
                }
            }

            forecastStep
        }
    }

    private var forecastStep: some View {
        PulseCard {
            VStack(alignment: .leading, spacing: 16) {
                Text("Pronostico de evolucion muscular")
                    .font(.headline)
                Text("Estimacion basada en el volumen semanal del plan generado y tu constancia.")
                    .font(.subheadline)
                    .foregroundStyle(PulseTheme.secondaryText)

                Text("Nivel de constancia estimado:")
                    .font(.subheadline.bold())
                
                HStack(spacing: 8) {
                    ForEach(0..<3) { index in
                        let title: String = switch index {
                        case 0: "Alta (90-100%)"
                        case 1: "Media (70-90%)"
                        default: "Baja (<70%)"
                        }
                        
                        Button {
                            selectedConsistencyIndex = index
                        } label: {
                            Text(title)
                                .font(.caption.weight(.bold))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 8)
                                .foregroundStyle(selectedConsistencyIndex == index ? .black : PulseTheme.secondaryText)
                                .background(selectedConsistencyIndex == index ? PulseTheme.accent : PulseTheme.grouped)
                                .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.bottom, 4)

                OnboardingForecastChart(points: forecastPoints)
                    .frame(height: 160)

                ForEach(forecastRows, id: \.name) { row in
                    HStack {
                        Text(row.name)
                            .font(.subheadline.weight(.bold))
                        Spacer()
                        Text(row.detail)
                            .font(.subheadline)
                            .foregroundStyle(row.color)
                    }
                }

                Divider()
                    .padding(.vertical, 4)

                // Disclaimer box
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(PulseTheme.warning)
                        .font(.body)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Nota Importante (Alimentación)")
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(.white)
                        Text("Este pronóstico estima el estímulo del entrenamiento. Recuerda que los resultados reales de ganancia de masa muscular o pérdida de grasa dependen críticamente de tu alimentación y descanso.")
                            .font(.caption)
                            .foregroundStyle(PulseTheme.secondaryText)
                            .lineLimit(nil)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding(14)
                .background(PulseTheme.warning.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(PulseTheme.warning.opacity(0.24), lineWidth: 1)
                )
            }
        }
    }

    private var paywallStep: some View {
        VStack(alignment: .leading, spacing: 22) {
            OnboardingTitle(
                title: "Tu plan ya está listo",
                subtitle: "Activa Reps Pro para mantenerlo adaptándose a tu progreso real desde la primera semana."
            )

            PulseCard {
                VStack(alignment: .leading, spacing: 18) {
                    TrialTimelineItem(icon: "checkmark", title: "Hoy", subtitle: "Desbloqueas tu plan, analítica avanzada y progresión automática.")
                    TrialTimelineItem(icon: "bell.fill", title: "Día 5", subtitle: "Te recordaremos que la prueba termina en 2 días.")
                    TrialTimelineItem(icon: "chart.line.uptrend.xyaxis", title: "Semana 2", subtitle: "Ya tendrás datos reales para ajustar volumen, fatiga y evolución.")
                }
            }

            PulseCard {
                VStack(spacing: 18) {
                    PaywallBenefit(icon: "sparkles", title: "Ajustes inteligentes", subtitle: "Series, repeticiones y cargas se ajustan según tu fatiga y progreso.")
                    Divider()
                    PaywallBenefit(icon: "figure.strengthtraining.traditional", title: "Mapa muscular vivo", subtitle: "Visualiza desequilibrios, foco y fatiga acumulada por zona.")
                    Divider()
                    PaywallBenefit(icon: "chart.line.uptrend.xyaxis", title: "Progreso accionable", subtitle: "Historial, 1RM estimado, exportación y tarjetas para compartir.")
                }
            }
        }
    }

    private func optionStep<Option: Identifiable & Hashable>(
        title: LocalizedStringKey,
        subtitle: LocalizedStringKey,
        options: [Option],
        selection: Binding<Option>,
        titleForOption: @escaping (Option) -> String,
        iconForOption: @escaping (Option) -> String
    ) -> some View {
        VStack(alignment: .leading, spacing: 18) {
            OnboardingTitle(title: title, subtitle: subtitle)

            VStack(spacing: 12) {
                ForEach(options) { option in
                    Button {
                        selection.wrappedValue = option
                    } label: {
                        HStack(spacing: 14) {
                            Image(systemName: iconForOption(option))
                                .font(.title3.weight(.semibold))
                                .frame(width: 44, height: 44)
                                .foregroundStyle(selection.wrappedValue == option ? .black : PulseTheme.primary)
                                .background(selection.wrappedValue == option ? .white : PulseTheme.grouped)
                                .clipShape(RoundedRectangle(cornerRadius: PulseTheme.compactRadius, style: .continuous))

                            Text(titleForOption(option))
                                .font(.headline)
                            Spacer()
                            Image(systemName: selection.wrappedValue == option ? "checkmark.circle.fill" : "circle")
                                .font(.title3)
                                .foregroundStyle(selection.wrappedValue == option ? PulseTheme.accent : PulseTheme.secondaryText.opacity(0.5))
                        }
                        .padding(14)
                        .foregroundStyle(.primary)
                        .background(selection.wrappedValue == option ? PulseTheme.accentMuted : PulseTheme.card)
                        .clipShape(RoundedRectangle(cornerRadius: PulseTheme.cardRadius, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: PulseTheme.cardRadius, style: .continuous)
                                .stroke(selection.wrappedValue == option ? PulseTheme.accent : PulseTheme.separator, lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var bottomBar: some View {
        Group {
            if step == .generating && isGenerationComplete {
                HStack(spacing: 10) {
                    Button {
                        restartPlanningFromScratch()
                    } label: {
                        Text("Rehacer")
                            .font(.subheadline.weight(.bold))
                            .frame(maxWidth: .infinity)
                            .frame(height: 46)
                            .foregroundStyle(.primary)
                            .background(PulseTheme.grouped)
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)

                    Button {
                        moveForward()
                    } label: {
                        Text("Aceptar plan")
                            .font(.subheadline.weight(.bold))
                            .frame(maxWidth: .infinity)
                            .frame(height: 46)
                            .foregroundStyle(.black)
                            .background(PulseTheme.accent)
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            } else if step == .plan {
                HStack(spacing: 10) {
                    Button {
                        store.presentPaywall(source: .onboarding, feature: nil, trigger: .onboarding)
                    } label: {
                        Text("Ver beneficios Pro")
                            .font(.subheadline.weight(.bold))
                            .frame(maxWidth: .infinity)
                            .frame(height: 46)
                            .foregroundStyle(PulseTheme.primary)
                            .background(PulseTheme.grouped)
                            .clipShape(Capsule())
                            .lineLimit(1)
                            .minimumScaleFactor(0.75)
                    }
                    .buttonStyle(.plain)

                    Button {
                        finishOnboarding()
                    } label: {
                        Text("Empezar con mi plan")
                            .font(.subheadline.weight(.bold))
                            .frame(maxWidth: .infinity)
                            .frame(height: 46)
                            .foregroundStyle(.black)
                            .background(PulseTheme.accent)
                            .clipShape(Capsule())
                            .lineLimit(1)
                            .minimumScaleFactor(0.75)
                    }
                    .buttonStyle(.plain)
                }
            } else {
                HStack(spacing: 10) {
                    Button {
                        moveForward()
                    } label: {
                        Text(primaryButtonTitle)
                            .font(.subheadline.weight(.bold))
                            .frame(maxWidth: .infinity)
                            .frame(height: 48)
                            .foregroundStyle(.black)
                            .background(canMoveForward ? PulseTheme.accent : PulseTheme.elevated)
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    .disabled(!canMoveForward)
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
        .padding(.bottom, 8)
        .background(.clear)
    }

    private var bottomContentPadding: CGFloat {
        switch step {
        case .generating where isGenerationComplete, .plan:
            return 76
        default:
            return 70
        }
    }

    private func restartPlanningFromScratch() {
        withAnimation(.snappy(duration: 0.25)) {
            profile = UserProfile()
            selectedSex = nil
            age = 32
            heightCm = 178.0
            weightKg = 78.0
            sessionLengthMinutes = 60
            focusMuscles = []
            selectedConsistencyIndex = 0
            generationProgress = 0.0
            generationStatusText = "Analizando métricas base..."
            isGenerationComplete = false
            hasTargetEvent = false
            targetEventName = ""
            targetEventDate = Calendar.current.date(byAdding: .weekOfYear, value: 8, to: .now) ?? .now
            step = .sex
        }
    }

    private var stepIndex: Int {
        steps.firstIndex(of: step) ?? 0
    }

    private var canMoveForward: Bool {
        if step == .sex {
            return selectedSex != nil
        }
        if step == .generating {
            return isGenerationComplete
        }
        return true
    }

    private var primaryButtonTitle: String {
        switch step {
        case .presentation: "Empezar"
        case .sex, .metrics, .goal, .training, .focus: "Continuar"
        case .generating: "Ver plan generado"
        case .plan: "Ver beneficios Pro"
        case .paywall: "Empezar con mi plan"
        }
    }

    private func moveForward() {
        guard step != .paywall else {
            finishOnboarding()
            return
        }
        step = steps[min(stepIndex + 1, steps.count - 1)]
    }

    private func finishOnboarding() {
        onFinish(makeResult())
    }

    private func moveBackward() {
        step = steps[max(stepIndex - 1, 0)]
    }

    private func makeResult() -> OnboardingResult {
        var configured = profile
        configured.sex = selectedSex?.profileValue
        configured.dateOfBirth = Calendar.current.date(byAdding: .year, value: -age, to: .now)
        configured.availableEquipment = configuredEquipment
        configured.onboardingCompleted = true
        
        if hasTargetEvent {
            configured.targetEventName = targetEventName.isEmpty ? "Evento" : targetEventName
            configured.targetEventDate = targetEventDate
        } else {
            configured.targetEventName = nil
            configured.targetEventDate = nil
        }

        let metric = bodyMetric
        let plan = OnboardingPlanBuilder.makePlan(
            profile: configured,
            bodyMetric: metric,
            sessionLengthMinutes: sessionLengthMinutes,
            focusMuscles: Array(focusMuscles)
        )

        return OnboardingResult(profile: configured, bodyMetric: metric, plan: plan)
    }

    private func toggleEquipment(_ equipment: String) {
        if profile.availableEquipment.isEmpty {
            profile.availableEquipment = configuredEquipment
        }

        if profile.availableEquipment.contains(equipment) {
            profile.availableEquipment.removeAll { $0 == equipment }
        } else {
            profile.availableEquipment.append(equipment)
        }
    }

    private func toggleFocus(_ muscle: String) {
        if focusMuscles.contains(muscle) {
            focusMuscles.remove(muscle)
        } else {
            focusMuscles.insert(muscle)
        }
    }

    private var selectedFocusMuscles: Set<Muscle> {
        Set(focusMuscles.flatMap(muscles(for:)))
    }

    private var generationHeatmap: [MuscleIntensity] {
        let planGroups = generatedPlan.days.flatMap(\.exercises).flatMap { muscles(for: $0.exercise.muscleGroup) }
        return Set(planGroups).map { MuscleIntensity(muscle: $0, intensity: generationPulse ? 0.95 : 0.45) }
    }

    private var weeklySetTotal: Int {
        generatedPlan.days.flatMap(\.exercises).reduce(0) { $0 + $1.targetSets }
    }

    private var consistencyFactor: Double {
        switch selectedConsistencyIndex {
        case 0: return 1.0  // Alta
        case 1: return 0.7  // Media
        default: return 0.4 // Baja
        }
    }

    private var forecastPoints: [Double] {
        let base = Double(max(weeklySetTotal, 1))
        let factor = consistencyFactor
        return (0..<8).map { week in
            let multiplier = 1 + (Double(week) * 0.08 * factor)
            return min(100, base * multiplier)
        }
    }

    private var forecastRows: [(name: String, detail: String, color: Color)] {
        let total = weeklySetTotal
        let factor = consistencyFactor
        let week1Sets = Int(Double(total) * factor)
        let week4Diff = Int(Double(max(2, total / 6)) * factor)
        return [
            ("Semana 1", "\(week1Sets) series productivas estimadas", PulseTheme.primary),
            ("Semana 4", "+\(week4Diff) series ajustadas", PulseTheme.primaryBright),
            ("Semana 8", factor > 0.6 ? "Evolución óptima (deload o nuevo bloque)" : "Evolución moderada (continuar bloque)", PulseTheme.accent)
        ]
    }

    private var targetEventCard: some View {
        PulseCard {
            VStack(alignment: .leading, spacing: 14) {
                Toggle(isOn: $hasTargetEvent) {
                    HStack(spacing: 8) {
                        Image(systemName: "calendar.badge.clock")
                            .foregroundStyle(PulseTheme.primary)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("¿Tienes un evento objetivo?")
                                .font(.headline)
                            Text("Ponerte en forma para una fecha específica.")
                                .font(.caption)
                                .foregroundStyle(PulseTheme.secondaryText)
                        }
                    }
                }
                
                if hasTargetEvent {
                    Divider()
                    
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Nombre del evento")
                            .font(.caption.bold())
                            .foregroundStyle(PulseTheme.secondaryText)
                        TextField("Ej. Boda, Vacaciones, Maratón", text: $targetEventName)
                            .textFieldStyle(.roundedBorder)
                            .focused($isEventNameFocused)
                            .submitLabel(.done)
                            .autocorrectionDisabled()
                            .onSubmit { isEventNameFocused = false }
                        
                        DatePicker(
                            "Fecha del evento",
                            selection: $targetEventDate,
                            in: Date.now...,
                            displayedComponents: .date
                        )
                        .font(.subheadline.weight(.semibold))
                        
                        if let advice = targetEventAdvice {
                            Text(advice.text)
                                .font(.caption)
                                .foregroundStyle(advice.color)
                                .padding(10)
                                .background(advice.color.opacity(0.08))
                                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                                .padding(.top, 4)
                        }
                    }
                    .transition(.opacity)
                }
            }
        }
    }

    private struct EventAdvice {
        let text: String
        let color: Color
        let weeks: Int
    }

    private var targetEventAdvice: EventAdvice? {
        guard hasTargetEvent else { return nil }
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: Date.now)
        let end = calendar.startOfDay(for: targetEventDate)
        let components = calendar.dateComponents([.day], from: start, to: end)
        let days = components.day ?? 0
        let weeks = max(1, days / 7)
        
        if weeks < 6 {
            return EventAdvice(
                text: "Faltan \(weeks) semanas. Un ciclo óptimo suele requerir 8-12 semanas para ver adaptaciones importantes de fuerza o masa muscular, pero adaptaremos tu plan a corto plazo para maximizar resultados antes de tu evento.",
                color: PulseTheme.warning,
                weeks: weeks
            )
        } else if weeks <= 12 {
            return EventAdvice(
                text: "Faltan \(weeks) semanas. ¡Excelente! Tienes el tiempo perfecto para completar un ciclo completo de entrenamiento progresivo con adaptaciones notables.",
                color: PulseTheme.primaryBright,
                weeks: weeks
            )
        } else {
            return EventAdvice(
                text: "Faltan \(weeks) semanas. Dado que el plazo es largo (\(weeks) semanas), te sugerimos hacer un bloque de fuerza/hipertrofia de 8 a 12 semanas y luego un plan de mantenimiento o definición secundario para llegar en tu mejor forma.",
                color: PulseTheme.primary,
                weeks: weeks
            )
        }
    }

    private func muscles(for group: String) -> [Muscle] {
        let lower = group.lowercased()
        if lower.contains("chest") { return [.chest, .upperChest, .lowerChest] }
        if lower.contains("back") { return [.upperBack, .rhomboids, .trapezius, .lowerBack] }
        if lower.contains("shoulder") { return [.deltoids, .frontDeltoid, .rearDeltoid] }
        if lower.contains("arm") { return [.biceps, .triceps, .forearm] }
        if lower.contains("leg") { return [.quadriceps, .hamstring, .calves, .adductors] }
        if lower.contains("glute") { return [.gluteal, .hamstring] }
        if lower.contains("core") { return [.abs, .upperAbs, .lowerAbs, .obliques] }
        return []
    }

    private func focusKey(for muscle: Muscle) -> String? {
        if [.chest, .upperChest, .lowerChest].contains(muscle) { return "Chest" }
        if [.upperBack, .rhomboids, .trapezius, .upperTrapezius, .lowerTrapezius, .lowerBack].contains(muscle) { return "Back" }
        if [.deltoids, .frontDeltoid, .rearDeltoid, .rotatorCuff].contains(muscle) { return "Shoulders" }
        if [.biceps, .triceps, .forearm].contains(muscle) { return "Arms" }
        if [.quadriceps, .innerQuad, .outerQuad, .hamstring, .calves, .tibialis, .adductors].contains(muscle) { return "Legs" }
        if [.gluteal].contains(muscle) { return "Glutes" }
        if [.abs, .upperAbs, .lowerAbs, .obliques, .serratus].contains(muscle) { return "Core" }
        return nil
    }

    private func defaultEquipment(for location: UserProfile.TrainingLocation) -> [String] {
        switch location {
        case .gym: ["Barbell", "Dumbbells", "Bodyweight", "Cardio Machine"]
        case .home: ["Dumbbells", "Resistance Band", "Bodyweight"]
        case .both: ["Barbell", "Dumbbells", "Resistance Band", "Bodyweight"]
        }
    }

    private var focusOptions: [(key: String, title: String)] {
        [
            ("Chest", "Pecho"),
            ("Back", "Espalda"),
            ("Shoulders", "Hombros"),
            ("Arms", "Brazos"),
            ("Legs", "Piernas"),
            ("Glutes", "Glúteos"),
            ("Core", "Core")
        ]
    }

    private func icon(for goal: UserProfile.MainGoal) -> String {
        switch goal {
        case .buildMuscle: "dumbbell.fill"
        case .loseFat: "flame.fill"
        case .getStronger: "bolt.fill"
        case .stayActive: "figure.walk"
        }
    }

    private func goalTitle(_ goal: UserProfile.MainGoal) -> String {
        switch goal {
        case .buildMuscle: "Ganar músculo"
        case .loseFat: "Perder grasa"
        case .getStronger: "Ganar fuerza"
        case .stayActive: "Mantenerme activo"
        }
    }

    private func locationTitle(_ location: UserProfile.TrainingLocation) -> String {
        switch location {
        case .gym: "Gimnasio"
        case .home: "Casa"
        case .both: "Casa y gimnasio"
        }
    }

    private func icon(for location: UserProfile.TrainingLocation) -> String {
        switch location {
        case .gym: "figure.strengthtraining.traditional"
        case .home: "house.fill"
        case .both: "arrow.triangle.2.circlepath"
        }
    }

    private func progressColor(for index: Int, filled: Bool) -> Color {
        let color: Color
        switch index {
        case 0..<4: color = PulseTheme.primary
        case 4..<10: color = PulseTheme.primaryBright
        default: color = PulseTheme.accent
        }
        return filled ? color : color.opacity(0.16)
    }
}

private enum OnboardingStep: CaseIterable {
    case presentation
    case sex
    case metrics
    case goal
    case training
    case focus
    case generating
    case plan
    case paywall
}

private enum OnboardingSex: String, CaseIterable, Identifiable {
    case male
    case female

    var id: String { rawValue }

    var title: String {
        switch self {
        case .male: "Masculino"
        case .female: "Femenino"
        }
    }

    var bodyGender: BodyGender {
        switch self {
        case .male: .male
        case .female: .female
        }
    }

    var profileValue: UserProfile.Sex {
        switch self {
        case .male: .male
        case .female: .female
        }
    }
}

private struct OnboardingTitle: View {
    let title: LocalizedStringKey
    let subtitle: LocalizedStringKey

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 34, weight: .bold, design: .rounded))
                .lineLimit(4)
                .minimumScaleFactor(0.75)
            Text(subtitle)
                .font(.headline)
                .foregroundStyle(PulseTheme.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

private struct OnboardingBenefit: View {
    let icon: String
    let title: LocalizedStringKey
    let subtitle: LocalizedStringKey

    var body: some View {
        PulseCard {
            VStack(alignment: .leading, spacing: 8) {
                Image(systemName: icon)
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(PulseTheme.primary)
                Text(title)
                    .font(.headline)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(PulseTheme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

private struct OnboardingSignal: View {
    let title: String
    let value: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(PulseTheme.secondaryText)
            Text(value)
                .font(.headline)
                .foregroundStyle(color)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct OnboardingRulerMetric: View {
    let title: String
    let valueText: String
    let unit: String
    let caption: String
    let icon: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    let step: Double

    private var progress: Double {
        (value - range.lowerBound) / (range.upperBound - range.lowerBound)
    }

    var body: some View {
        PulseCard(contentPadding: 18) {
            VStack(alignment: .leading, spacing: 18) {
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: icon)
                        .font(.headline.weight(.bold))
                        .foregroundStyle(.black)
                        .frame(width: 40, height: 40)
                        .background(PulseTheme.accent)
                        .clipShape(RoundedRectangle(cornerRadius: PulseTheme.controlRadius, style: .continuous))

                    VStack(alignment: .leading, spacing: 4) {
                        Text(title)
                            .font(.headline)
                        Text(caption)
                            .font(.caption.weight(.medium))
                            .foregroundStyle(PulseTheme.secondaryText)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Spacer(minLength: 8)
                }

                HStack(alignment: .lastTextBaseline, spacing: 6) {
                    Text(valueText)
                        .font(.system(size: 54, weight: .black, design: .rounded))
                        .foregroundStyle(PulseTheme.accent)
                        .lineLimit(1)
                        .minimumScaleFactor(0.65)
                        .contentTransition(.numericText(value: value))
                    Text(unit)
                        .font(.title2.weight(.black))
                        .foregroundStyle(PulseTheme.accent)
                }
                .frame(maxWidth: .infinity, alignment: .center)

                VStack(spacing: 10) {
                    Slider(value: $value, in: range, step: step)
                        .tint(PulseTheme.accent)

                    TickRail(progress: progress)
                        .frame(height: 38)
                }
            }
        }
        .sensoryFeedback(.selection, trigger: value)
    }
}

private struct TickRail: View {
    let progress: Double

    var body: some View {
        GeometryReader { proxy in
            let clampedProgress = min(max(progress, 0), 1)
            let activeX = proxy.size.width * clampedProgress

            ZStack(alignment: .topLeading) {
                HStack(alignment: .bottom, spacing: 0) {
                    ForEach(0..<31, id: \.self) { index in
                        Rectangle()
                            .fill(index % 5 == 0 ? PulseTheme.secondaryText.opacity(0.55) : PulseTheme.separator.opacity(0.9))
                            .frame(width: 1.4, height: index % 5 == 0 ? 30 : 18)
                            .frame(maxWidth: .infinity)
                    }
                }

                Rectangle()
                    .fill(PulseTheme.accent)
                    .frame(width: 3, height: 38)
                    .offset(x: activeX - 1.5)
                    .shadow(color: PulseTheme.accent.opacity(0.45), radius: 8)
            }
        }
        .accessibilityHidden(true)
    }
}

private struct MetricStepper: View {
    let title: String
    @Binding var value: Int
    let range: ClosedRange<Int>
    let unit: String

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                Text("\(value) \(unit)")
                    .font(.title2.weight(.bold))
            }
            Spacer()
            Stepper(title, value: $value, in: range)
                .labelsHidden()
        }
    }
}

private struct DoubleMetricStepper: View {
    let title: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    let step: Double
    let unit: String

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                Text("\(value, specifier: step < 1 ? "%.1f" : "%.0f") \(unit)")
                    .font(.title2.weight(.bold))
            }
            Spacer()
            Stepper(title, value: $value, in: range, step: step)
                .labelsHidden()
        }
    }
}

private struct GenerationPill: View {
    let title: String
    let value: String

    var body: some View {
        VStack(spacing: 4) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(PulseTheme.secondaryText)
            Text(value)
                .font(.headline.monospacedDigit())
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(PulseTheme.card)
        .clipShape(Capsule())
    }
}

private struct OnboardingBodyPair: View {
    let gender: BodyGender
    var selectedMuscles: Set<Muscle> = []
    var heatmap: [MuscleIntensity] = []
    var onMuscleTap: ((Muscle) -> Void)?

    var body: some View {
        GeometryReader { proxy in
            HStack(spacing: -28) {
                Spacer()
                bodyView(side: .front)
                    .frame(width: proxy.size.width * 0.52, height: proxy.size.height)
                bodyView(side: .back)
                    .frame(width: proxy.size.width * 0.52, height: proxy.size.height)
                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .accessibilityLabel("Mapa muscular del sexo seleccionado")
    }

    private func bodyView(side: BodySide) -> some View {
        BodyView(gender: gender, side: side, style: .onboardingDark)
            .heatmap(heatmap, configuration: .onboardingHeatmap)
            .selected(selectedMuscles)
            .pulseSelected(speed: 1.2)
            .onMuscleSelected { muscle, _ in
                onMuscleTap?(muscle)
            }
            .allowsHitTesting(onMuscleTap != nil)
    }
}

private struct OnboardingForecastChart: View {
    let points: [Double]

    var body: some View {
        GeometryReader { proxy in
            let maxValue = max(points.max() ?? 1, 1)
            HStack(alignment: .bottom, spacing: 8) {
                ForEach(Array(points.enumerated()), id: \.offset) { index, point in
                    VStack(spacing: 8) {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(index < 3 ? PulseTheme.primary : index < 6 ? PulseTheme.primaryBright : PulseTheme.accent)
                            .frame(height: max(14, proxy.size.height * 0.72 * point / maxValue))
                        Text("S\(index + 1)")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(PulseTheme.tertiaryText)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
    }
}

private struct PaywallBenefit: View {
    let icon: String
    let title: String
    let subtitle: String

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: icon)
                .font(.headline)
                .foregroundStyle(.black)
                .frame(width: 38, height: 38)
                .background(PulseTheme.accent)
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(PulseTheme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
            
            Spacer()
        }
    }
}

private struct TrialTimelineItem: View {
    let icon: String
    let title: String
    let subtitle: String

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: icon)
                .font(.subheadline.weight(.black))
                .foregroundStyle(.black)
                .frame(width: 38, height: 38)
                .background(PulseTheme.accent)
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(PulseTheme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
    }
}

private extension BodyViewStyle {
    static let onboardingDark = BodyViewStyle(
        defaultFillColor: Color.white.opacity(0.16),
        strokeColor: Color.black.opacity(0.55),
        strokeWidth: 0.65,
        selectionColor: PulseTheme.primary,
        selectionStrokeColor: .white,
        selectionStrokeWidth: 1.6,
        headColor: Color.white.opacity(0.22),
        hairColor: Color.white.opacity(0.10)
    )
}

private extension HeatmapConfiguration {
    static let onboardingHeatmap = HeatmapConfiguration(
        colorScale: .repsVolume,
        interpolation: .linear,
        threshold: 0.01,
        isGradientFillEnabled: true,
        gradientDirection: .topToBottom,
        gradientLowIntensityFactor: 0.55
    )
}

private extension HeatmapColorScale {
    static let repsVolume = HeatmapColorScale(colors: [
        PulseTheme.primary,
        PulseTheme.primaryBright,
        PulseTheme.accent
    ])
}
