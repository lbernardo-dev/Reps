import MuscleMap
import SwiftUI

struct ProfileSetupView: View {
    @State private var profile = UserProfile()
    @State private var step: OnboardingStep = .presentation
    @State private var selectedSex: OnboardingSex?
    @State private var age = 32
    @State private var heightCm = 178.0
    @State private var weightKg = 78.0
    @State private var sessionLengthMinutes: Int? = 60
    @State private var focusMuscles: Set<String> = []
    @State private var generationPulse = false

    var onFinish: (OnboardingResult) -> Void

    private let steps = OnboardingStep.allCases

    private var bodyMetric: BodyMetric {
        BodyMetric(date: .now, weightKg: weightKg, heightCm: heightCm, source: .manual)
    }

    private var generatedPlan: WorkoutPlan {
        var configured = profile
        configured.sex = selectedSex?.profileValue
        configured.dateOfBirth = Calendar.current.date(byAdding: .year, value: -age, to: .now)
        configured.availableEquipment = configuredEquipment

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
                .padding(.bottom, 116)
            }
        }
        .screenBackground()
        .safeAreaInset(edge: .bottom) {
            bottomBar
        }
        .animation(.snappy(duration: 0.25), value: step)
        .onChange(of: step) { _, newStep in
            if newStep == .generating {
                generationPulse = false
                withAnimation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true)) {
                    generationPulse = true
                }
            }
        }
    }

    private var progressHeader: some View {
        VStack(spacing: 12) {
            HStack {
                Text("Reps")
                    .font(.title2.bold())
                Spacer()
                Text("\(stepIndex + 1)/\(steps.count)")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(PulseTheme.secondaryText)
            }

            ProgressView(value: Double(stepIndex + 1), total: Double(steps.count))
                .tint(step == .paywall ? PulseTheme.accent : PulseTheme.primary)
        }
        .padding(.horizontal, 20)
        .padding(.top, 16)
        .padding(.bottom, 12)
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
                Text("Reps combina tus metricas, objetivo, equipo y recuperacion para crear una rutina base y convertir cada sesion en datos utiles.")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(PulseTheme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }

            PulseCard {
                VStack(spacing: 18) {
                    HStack {
                        OnboardingSignal(title: "Plan", value: "8 semanas", color: PulseTheme.primary)
                        OnboardingSignal(title: "Progreso", value: "por musculo", color: PulseTheme.primaryBright)
                        OnboardingSignal(title: "Prediccion", value: "visual", color: PulseTheme.accent)
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
                OnboardingBenefit(icon: "figure.strengthtraining.traditional", title: "Rutinas listas", subtitle: "Dias, ejercicios, series y descansos.")
                OnboardingBenefit(icon: "chart.line.uptrend.xyaxis", title: "Pronosticos", subtitle: "Evolucion muscular esperada.")
            }
        }
    }

    private var sexStep: some View {
        VStack(alignment: .leading, spacing: 18) {
            OnboardingTitle(
                title: "Elige el cuerpo que usara la app",
                subtitle: "A partir de aqui, los mapas musculares y graficos se muestran solo con este sexo."
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
                        .background(selectedSex == sex ? PulseTheme.elevated : PulseTheme.card)
                        .clipShape(RoundedRectangle(cornerRadius: PulseTheme.cardRadius, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: PulseTheme.cardRadius, style: .continuous)
                                .stroke(selectedSex == sex ? PulseTheme.primaryBright : PulseTheme.separator, lineWidth: 1.2)
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
                title: "Tus metricas base",
                subtitle: "Se usan para estimar cargas iniciales, volumen tolerable y pronosticos."
            )

            PulseCard {
                VStack(spacing: 20) {
                    MetricStepper(title: "Edad", value: $age, range: 14...85, unit: "anos")
                    Divider()
                    DoubleMetricStepper(title: "Altura", value: $heightCm, range: 130...220, step: 1, unit: "cm")
                    Divider()
                    DoubleMetricStepper(title: "Peso", value: $weightKg, range: 35...180, step: 0.5, unit: "kg")
                }
            }
        }
    }

    private var goalStep: some View {
        optionStep(
            title: "Cual es tu objetivo principal?",
            subtitle: "Esto cambia repeticiones, descansos y foco del plan generado.",
            options: UserProfile.MainGoal.allCases,
            selection: $profile.mainGoal,
            titleForOption: \.rawValue,
            iconForOption: icon(for:)
        )
    }

    private var trainingStep: some View {
        VStack(alignment: .leading, spacing: 18) {
            optionStep(
                title: "Donde y con que frecuencia entrenas?",
                subtitle: "Escoge el escenario mas realista. Luego afinamos equipo y duracion.",
                options: UserProfile.TrainingLocation.allCases,
                selection: $profile.trainingLocation,
                titleForOption: \.rawValue,
                iconForOption: icon(for:)
            )

            PulseCard {
                VStack(alignment: .leading, spacing: 18) {
                    Text("\(profile.weeklyTrainingDays) dias por semana")
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
                                    .background(profile.weeklyTrainingDays == day ? .white : PulseTheme.grouped)
                                    .clipShape(RoundedRectangle(cornerRadius: PulseTheme.compactRadius, style: .continuous))
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    Text("Duracion por sesion")
                        .font(.headline)
                    HStack(spacing: 8) {
                        ForEach([30, 45, 60, 75], id: \.self) { minutes in
                            Button {
                                sessionLengthMinutes = minutes
                            } label: {
                                Text("\(minutes)m")
                                    .font(.headline)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 46)
                                    .foregroundStyle(sessionLengthMinutes == minutes ? .black : PulseTheme.secondaryText)
                                    .background(sessionLengthMinutes == minutes ? .white : PulseTheme.grouped)
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

    private var equipmentStep: some View {
        PulseCard {
            VStack(alignment: .leading, spacing: 14) {
                Text("Equipo disponible")
                    .font(.headline)
                ForEach(equipmentOptions, id: \.self) { equipment in
                    Button {
                        toggleEquipment(equipment)
                    } label: {
                        HStack {
                            Text(equipment)
                                .font(.headline)
                            Spacer()
                            Image(systemName: configuredEquipment.contains(equipment) ? "checkmark.circle.fill" : "circle")
                                .foregroundStyle(configuredEquipment.contains(equipment) ? PulseTheme.primaryBright : PulseTheme.secondaryText)
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)

                    if equipment != equipmentOptions.last {
                        Divider()
                    }
                }
            }
        }
    }

    private var focusStep: some View {
        VStack(alignment: .leading, spacing: 18) {
            OnboardingTitle(
                title: "Quieres priorizar algun musculo?",
                subtitle: "Escoge hasta dos zonas. El cuerpo seleccionado guia la decision."
            )

            OnboardingBodyPair(gender: selectedGender, selectedMuscles: selectedFocusMuscles) { muscle in
                if let focus = focusKey(for: muscle) {
                    toggleFocus(focus)
                }
            }
            .frame(height: 390)

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 120), spacing: 10)], spacing: 10) {
                ForEach(focusOptions, id: \.key) { option in
                    Button {
                        toggleFocus(option.key)
                    } label: {
                        Text(option.title)
                            .font(.caption.weight(.bold))
                            .frame(maxWidth: .infinity)
                            .frame(height: 34)
                            .foregroundStyle(focusMuscles.contains(option.key) ? .black : PulseTheme.secondaryText)
                            .background(focusMuscles.contains(option.key) ? PulseTheme.primaryBright : PulseTheme.grouped)
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var generatingStep: some View {
        VStack(alignment: .center, spacing: 24) {
            OnboardingTitle(
                title: "Generando tu plan base",
                subtitle: "El mapa muestra la distribucion muscular prevista."
            )

            ZStack {
                OnboardingBodyPair(gender: selectedGender, heatmap: generationHeatmap)
                    .frame(height: 440)
                    .scaleEffect(generationPulse ? 1.03 : 0.98)
                    .opacity(generationPulse ? 1 : 0.78)
                VStack {
                    Spacer()
                    Text("\(generatedPlan.days.count) dias listos")
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
        }
    }

    private var planStep: some View {
        VStack(alignment: .leading, spacing: 18) {
            OnboardingTitle(
                title: "Tu plan esta listo",
                subtitle: "Incluye dias, ejercicios, descansos entre ejercicios y descansos entre series."
            )

            ForEach(generatedPlan.days) { day in
                PulseCard {
                    VStack(alignment: .leading, spacing: 14) {
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

                        ForEach(day.exercises) { item in
                            HStack(alignment: .top, spacing: 12) {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(item.priority == .primary ? PulseTheme.primaryBright : PulseTheme.primary)
                                    .padding(.top, 2)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(item.exercise.name)
                                        .font(.headline)
                                    Text("\(item.targetSets) series x \(item.repRange) - \(item.restSeconds)s entre series")
                                        .font(.subheadline)
                                        .foregroundStyle(PulseTheme.secondaryText)
                                }
                                Spacer()
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
                Text("Estimacion basada en el volumen semanal del plan generado.")
                    .font(.subheadline)
                    .foregroundStyle(PulseTheme.secondaryText)

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
            }
        }
    }

    private var paywallStep: some View {
        VStack(alignment: .leading, spacing: 22) {
            Text("Reps Pro")
                .font(.system(size: 46, weight: .bold, design: .rounded))
            Text("Mantén el plan adaptandose a tu progreso real.")
                .font(.title3.weight(.semibold))
                .foregroundStyle(PulseTheme.secondaryText)

            PulseCard {
                VStack(spacing: 18) {
                    PaywallBenefit(icon: "sparkles", title: "Ajustes automaticos", subtitle: "Series, repeticiones y descansos cambian segun rendimiento.")
                    Divider()
                    PaywallBenefit(icon: "figure.strengthtraining.traditional", title: "Mapa muscular avanzado", subtitle: "Predicciones por zona y alertas de desequilibrio.")
                    Divider()
                    PaywallBenefit(icon: "chart.line.uptrend.xyaxis", title: "Pronosticos y reportes", subtitle: "Evolucion semanal, volumen, adherencia y exportacion.")
                }
            }

            PulseCard {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Pro anual")
                            .font(.headline)
                        Text("7 dias gratis, cancela cuando quieras")
                            .font(.subheadline)
                            .foregroundStyle(PulseTheme.secondaryText)
                    }
                    Spacer()
                    Text("Mejor opcion")
                        .font(.caption.weight(.bold))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .foregroundStyle(.black)
                        .background(PulseTheme.accent)
                        .clipShape(Capsule())
                }
            }
        }
    }

    private func optionStep<Option: Identifiable & Hashable>(
        title: LocalizedStringKey,
        subtitle: LocalizedStringKey,
        options: [Option],
        selection: Binding<Option>,
        titleForOption: KeyPath<Option, String>,
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

                            Text(option[keyPath: titleForOption])
                                .font(.headline)
                            Spacer()
                            Image(systemName: selection.wrappedValue == option ? "checkmark.circle.fill" : "circle")
                                .font(.title3)
                                .foregroundStyle(selection.wrappedValue == option ? PulseTheme.primaryBright : PulseTheme.secondaryText.opacity(0.5))
                        }
                        .padding(14)
                        .foregroundStyle(.primary)
                        .background(selection.wrappedValue == option ? PulseTheme.elevated : PulseTheme.card)
                        .clipShape(RoundedRectangle(cornerRadius: PulseTheme.cardRadius, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: PulseTheme.cardRadius, style: .continuous)
                                .stroke(selection.wrappedValue == option ? PulseTheme.primary : PulseTheme.separator, lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var bottomBar: some View {
        HStack(spacing: 12) {
            if stepIndex > 0 {
                Button {
                    moveBackward()
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.headline)
                        .frame(width: 52, height: 52)
                        .foregroundStyle(.primary)
                        .background(PulseTheme.grouped)
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
            }

            Button {
                moveForward()
            } label: {
                Text(primaryButtonTitle)
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .frame(height: 58)
                    .foregroundStyle(.black)
                    .background(canMoveForward ? .white : PulseTheme.elevated)
                    .clipShape(Capsule())
            }
            .buttonStyle(.plain)
            .disabled(!canMoveForward)
        }
        .padding(20)
        .background(.ultraThinMaterial)
    }

    private var stepIndex: Int {
        steps.firstIndex(of: step) ?? 0
    }

    private var canMoveForward: Bool {
        step != .sex || selectedSex != nil
    }

    private var primaryButtonTitle: String {
        switch step {
        case .presentation: "Empezar"
        case .sex, .metrics, .goal, .training, .focus: "Continuar"
        case .generating: "Ver plan generado"
        case .plan: "Ver Pro"
        case .paywall: "Empezar con mi plan"
        }
    }

    private func moveForward() {
        guard step != .paywall else {
            onFinish(makeResult())
            return
        }
        step = steps[min(stepIndex + 1, steps.count - 1)]
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
        } else if focusMuscles.count < 2 {
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

    private var forecastPoints: [Double] {
        let base = Double(max(weeklySetTotal, 1))
        return (0..<8).map { week in
            let multiplier = 1 + (Double(week) * 0.08)
            return min(100, base * multiplier)
        }
    }

    private var forecastRows: [(name: String, detail: String, color: Color)] {
        let total = weeklySetTotal
        return [
            ("Semana 1", "\(total) series productivas", PulseTheme.primary),
            ("Semana 4", "+\(max(2, total / 6)) series ajustadas", PulseTheme.primaryBright),
            ("Semana 8", "deload o nuevo bloque", PulseTheme.accent)
        ]
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

    private var equipmentOptions: [String] {
        ["Barbell", "Dumbbells", "Resistance Band", "Bodyweight", "Kettlebell", "Cardio Machine"]
    }

    private var focusOptions: [(key: String, title: String)] {
        [
            ("Chest", "Pecho"),
            ("Back", "Espalda"),
            ("Shoulders", "Hombros"),
            ("Arms", "Brazos"),
            ("Legs", "Piernas"),
            ("Glutes", "Gluteos"),
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

    var profileValue: String {
        switch self {
        case .male: "male"
        case .female: "female"
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
            HStack(spacing: -36) {
                bodyView(side: .front)
                    .frame(width: proxy.size.width * 0.60, height: proxy.size.height)
                bodyView(side: .back)
                    .frame(width: proxy.size.width * 0.60, height: proxy.size.height)
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
