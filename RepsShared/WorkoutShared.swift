import Foundation

#if canImport(SwiftUI)
import SwiftUI
#endif

#if canImport(ActivityKit)
import ActivityKit
#endif

#if canImport(WidgetKit)
import WidgetKit
#endif

#if canImport(SwiftUI)
enum RepsLocalization {
    nonisolated(unsafe) private static var activeLanguage: String = Self.preferredSupportedLanguage()
    nonisolated(unsafe) private static var cachedBundle: Bundle? = nil

    static var language: String {
        activeLanguage
    }

    static var locale: Locale {
        Locale(identifier: activeLanguage)
    }

    @discardableResult
    static func use(_ language: String?) -> Locale {
        activeLanguage = normalizedSupportedLanguage(language)
        if let path = Bundle.main.path(forResource: activeLanguage, ofType: "lproj") {
            cachedBundle = Bundle(path: path)
        } else {
            cachedBundle = nil
        }
        return locale
    }

    static func string(_ key: String) -> String {
        if let languageBundle = cachedBundle {
            let localized = languageBundle.localizedString(forKey: key, value: nil, table: nil)
            if localized != key {
                return localized
            }
        } else if let path = Bundle.main.path(forResource: activeLanguage, ofType: "lproj"),
                  let languageBundle = Bundle(path: path) {
            cachedBundle = languageBundle
            let localized = languageBundle.localizedString(forKey: key, value: nil, table: nil)
            if localized != key {
                return localized
            }
        }
        if let fallback = localizedFallbacks[activeLanguage]?[key] ?? localizedFallbacks["en"]?[key] {
            return fallback
        }
        return String(localized: String.LocalizationValue(key), bundle: .main, locale: locale)
    }

    private static let localizedFallbacks: [String: [String: String]] = [
        "en": [
            "support": "Support",
            "support_subtitle": "Help center and contact",
            "faq": "FAQ",
            "faq_subtitle": "Frequently asked questions",
            "subscription_terms": "Subscription terms",
            "subscription_terms_subtitle": "Billing, renewal, and Pro conditions",
            "active_days": "active days",
            "apple_music_ready": "Apple Music ready",
            "apple_music_playing": "Playing with Apple Music",
            "apple_music_paused": "Paused",
            "apple_music_playlist_failed": "Apple Music could not start this playlist",
            "apple_music_playlist_not_found": "I could not resolve the playlist",
            "activity": "Activity",
            "best_time": "Best time",
            "better_indoors": "Better indoors",
            "controlled_outdoor_plan": "Controlled outdoor plan",
            "controlled_outdoor_plan_message": "If you go out, prioritize shade and lower the pace as temperature rises.",
            "controlled_uv": "Controlled UV",
            "controlled_uv_message": "Good margin for an easy walk or run outdoors.",
            "daily_distribution": "Daily distribution",
            "day_singular": "1 day",
            "days_count_format": "%@ days",
            "complete_session_for_real_progress": "Complete a session to see real progress",
            "fatigue": "fatigue",
            "fatigue_score_format": "%@ fatigue",
            "fatigue_7_days_format": "%@ fatigue · 7 days",
            "fitness_insights": "Fitness insights",
            "good_day_to_go_out": "Good day to go out",
            "good_day_to_go_out_message_format": "Rain is low and wind should not get in the way. Best window: %@.",
            "health_training": "Health + training",
            "humidity": "Humidity",
            "indoor_alternative": "Indoor alternative",
            "indoor_strength_recovery_message_format": "With recovery at %@%%, an indoor strength session keeps progress moving without extra heat stress.",
            "kcal_active": "Active kcal",
            "light_rain_wind_window_subtitle_format": "%@ · %@%% rain · %@",
            "max_temperature": "High",
            "moderate_clouds": "Partly cloudy",
            "moderate_clouds_message": "Comfortable conditions for an easy outdoor session or a long walk.",
            "no_resting_hr": "no resting HR",
            "now": "Now",
            "high_load_prioritize_recovery": "High load: prioritize recovery and technique",
            "missing_real_stimulus_weekly_target": "Real stimulus is behind the weekly target",
            "plan_execution_on_track": "Execution is aligned with the plan",
            "rain": "Rain",
            "rain_probability": "probability",
            "rain_uv": "Rain and UV",
            "recorded_load": "Recorded load",
            "resting_hr": "resting HR",
            "social_age_gate_declined_message": "To use community features, share an age range that confirms social features are appropriate for your account.",
            "social_age_gate_message": "Community features require an age range check before posts, likes, comments, follows, challenges, and discovery are enabled.",
            "social_age_gate_title": "Age check required",
            "social_age_gate_under_13_message": "Community features are disabled for users under 13.",
            "social_age_gate_unavailable_message": "The age range check is unavailable right now. Community features remain disabled until it succeeds.",
            "social_age_gate_verify": "Verify",
            "social_report_post": "Report post",
            "social_report_comment": "Report comment",
            "social_block_user": "Block user",
            "social_moderation_actions": "Moderation actions",
            "social_moderator_delete_post": "Delete post (moderator)",
            "social_moderator_delete_comment": "Delete comment (moderator)",
            "social_moderator_ban_user": "Ban user (moderator)",
            "sin_tiempo_definido": "No time target",
            "strong_sun_midday": "Strong sun at midday",
            "strong_sun_midday_message_format": "UV %@: use protection and avoid hard intervals between 12:00 and 17:00.",
            "sunny_hot": "Sunny and hot",
            "sunny_hot_message": "Good light for moving early; from midday lower intensity, hydrate and avoid direct sun.",
            "sun_protection": "Sun protection",
            "sun_protection_message": "Avoid the strongest midday blocks or reduce volume if you train outside.",
            "tomorrow_window": "Tomorrow also has a window",
            "tomorrow_window_message_format": "%@ looks stable: %@.",
            "training_days": "training days",
            "vs_previous_week": "vs previous week",
            "volume_vs_last_week_format": "Volume %+.0f%% vs last week",
            "weekly_health": "Weekly Health",
            "weekly_range_format": "Range evaluated: %@",
            "weekly_rhythm": "Weekly rhythm",
            "weekly_summary": "Weekly summary",
            "weekly_target": "weekly target",
            "weekly_target_2": "weekly target",
            "week_monday_sunday": "Mon-Sun",
            "weeks_short_count_format": "%@ wk",
            "real_execution": "Real execution",
            "real_plan_execution": "Real plan execution",
            "wind": "Wind",
            "wind_gusts": "gusts",
            "workout_days": "Workout days",
            "your_area": "Your area"
        ],
        "es": [
            "support": "Soporte",
            "support_subtitle": "Centro de ayuda y contacto",
            "faq": "Preguntas frecuentes",
            "faq_subtitle": "Preguntas frecuentes y respuestas rápidas",
            "subscription_terms": "Condiciones de suscripción",
            "subscription_terms_subtitle": "Facturación, renovación y condiciones Pro",
            "active_days": "días activos",
            "apple_music_ready": "Apple Music listo",
            "apple_music_playing": "Reproduciendo con Apple Music",
            "apple_music_paused": "Pausado",
            "apple_music_playlist_failed": "Apple Music no pudo iniciar esta playlist",
            "apple_music_playlist_not_found": "No pude resolver la playlist",
            "activity": "Actividad",
            "best_time": "Mejor momento",
            "better_indoors": "Mejor bajo techo",
            "controlled_outdoor_plan": "Plan exterior con control",
            "controlled_outdoor_plan_message": "Si sales, prioriza zonas de sombra y baja el ritmo cuando suba la temperatura.",
            "controlled_uv": "UV controlado",
            "controlled_uv_message": "Buen margen para caminar o correr suave al aire libre.",
            "daily_distribution": "Distribución diaria",
            "day_singular": "1 día",
            "days_count_format": "%@ días",
            "complete_session_for_real_progress": "Completa una sesión para ver evolución real",
            "fatigue": "fatiga",
            "fatigue_score_format": "%@ fatiga",
            "fatigue_7_days_format": "%@ fatiga · 7 días",
            "fitness_insights": "Insights fitness",
            "good_day_to_go_out": "Buen día para salir",
            "good_day_to_go_out_message_format": "La lluvia es baja y el viento no debería molestar. Mejor ventana: %@.",
            "health_training": "Health + entrenamiento",
            "humidity": "Humedad",
            "indoor_alternative": "Alternativa bajo techo",
            "indoor_strength_recovery_message_format": "Con recuperación al %@%%, una sesión de fuerza bajo techo mantiene el progreso sin sumar calor externo.",
            "kcal_active": "Kcal activas",
            "light_rain_wind_window_subtitle_format": "%@ · %@%% lluvia · %@",
            "max_temperature": "Máxima",
            "moderate_clouds": "Parcialmente nublado",
            "moderate_clouds_message": "Condiciones cómodas para una sesión exterior suave o una caminata larga.",
            "no_resting_hr": "sin FC reposo",
            "now": "Ahora",
            "high_load_prioritize_recovery": "Carga alta: prioriza recuperación y técnica",
            "missing_real_stimulus_weekly_target": "Falta estímulo real frente al objetivo semanal",
            "plan_execution_on_track": "Ejecución en línea con el plan",
            "rain": "Lluvia",
            "rain_probability": "probabilidad",
            "rain_uv": "Lluvia y UV",
            "recorded_load": "Carga registrada",
            "resting_hr": "lpm reposo",
            "social_age_gate_declined_message": "Para usar la comunidad, comparte un rango de edad que confirme que las funciones sociales son adecuadas para tu cuenta.",
            "social_age_gate_message": "La comunidad requiere comprobar el rango de edad antes de habilitar posts, likes, comentarios, seguidores, retos y descubrimiento.",
            "social_age_gate_title": "Comprobación de edad requerida",
            "social_age_gate_under_13_message": "La comunidad está desactivada para usuarios menores de 13 años.",
            "social_age_gate_unavailable_message": "La comprobación de edad no está disponible ahora. La comunidad seguirá desactivada hasta que se complete.",
            "social_age_gate_verify": "Verificar",
            "social_report_post": "Denunciar publicación",
            "social_report_comment": "Denunciar comentario",
            "social_block_user": "Bloquear usuario",
            "social_moderation_actions": "Acciones de moderación",
            "social_moderator_delete_post": "Eliminar publicación (moderador)",
            "social_moderator_delete_comment": "Eliminar comentario (moderador)",
            "social_moderator_ban_user": "Banear usuario (moderador)",
            "sin_tiempo_definido": "Sin tiempo",
            "strong_sun_midday": "Sol fuerte a mediodía",
            "strong_sun_midday_message_format": "UV %@: usa protección y evita intervalos duros entre 12:00 y 17:00.",
            "sunny_hot": "Soleado y caluroso",
            "sunny_hot_message": "Buena luz para moverte temprano; desde mediodía conviene bajar intensidad, hidratarte y evitar el sol directo.",
            "sun_protection": "Protección solar",
            "sun_protection_message": "Evita los bloques más intensos a mediodía o reduce el volumen si entrenas fuera.",
            "tomorrow_window": "Mañana también hay ventana",
            "tomorrow_window_message_format": "%@ pinta estable: %@.",
            "training_days": "días con entreno",
            "vs_previous_week": "vs semana previa",
            "volume_vs_last_week_format": "Volumen %+.0f%% vs semana pasada",
            "weekly_health": "Health semanal",
            "weekly_range_format": "Rango evaluado: %@",
            "weekly_rhythm": "Ritmo semanal",
            "weekly_summary": "Resumen semanal",
            "weekly_target": "objetivo semanal",
            "weekly_target_2": "objetivo semanal",
            "week_monday_sunday": "Lun-Dom",
            "weeks_short_count_format": "%@ sem",
            "real_execution": "Ejecución real",
            "real_plan_execution": "Ejecución real del plan",
            "wind": "Viento",
            "wind_gusts": "rachas",
            "workout_days": "Días con entreno",
            "your_area": "Tu zona"
        ]
    ]

    private static func normalizedSupportedLanguage(_ language: String?) -> String {
        guard let identifier = language?.split(separator: "-").first?.lowercased(),
              ["en", "es"].contains(identifier) else {
            return preferredSupportedLanguage()
        }
        return identifier
    }

    private static func preferredSupportedLanguage() -> String {
        Locale.preferredLanguages
            .compactMap { $0.split(separator: "-").first?.lowercased() }
            .first { ["en", "es"].contains($0) } ?? "en"
    }
}

struct RepsLegalUrls {
    static var privacyPolicy: String {
        RepsLocalization.language == "es"
            ? "https://lbernardo-dev.github.io/apps/es/casos/reps/privacidad/"
            : "https://lbernardo-dev.github.io/apps/en/case-studies/reps/privacy/"
    }

    static var termsOfService: String {
        RepsLocalization.language == "es"
            ? "https://lbernardo-dev.github.io/apps/es/casos/reps/terminos/"
            : "https://lbernardo-dev.github.io/apps/en/case-studies/reps/terms/"
    }

    static var subscriptionTerms: String {
        RepsLocalization.language == "es"
            ? "https://lbernardo-dev.github.io/apps/es/casos/reps/suscripciones/"
            : "https://lbernardo-dev.github.io/apps/en/case-studies/reps/subscriptions/"
    }

    static var support: String {
        RepsLocalization.language == "es"
            ? "https://lbernardo-dev.github.io/apps/es/casos/reps/soporte/"
            : "https://lbernardo-dev.github.io/apps/en/case-studies/reps/support/"
    }

    static var faq: String {
        RepsLocalization.language == "es"
            ? "https://lbernardo-dev.github.io/apps/es/casos/reps/preguntas-frecuentes/"
            : "https://lbernardo-dev.github.io/apps/en/case-studies/reps/faq/"
    }
}

func localizedKey(_ key: String) -> String {
    RepsLocalization.string(key)
}

func localizedKey(_ key: LocalizedStringKey) -> LocalizedStringKey {
    key
}
#endif

func localizedString(_ key: String) -> String {
    #if canImport(SwiftUI)
    RepsLocalization.string(key)
    #else
    String(localized: String.LocalizationValue(key), bundle: .main)
    #endif
}

extension String {
    func firstWordInitialUppercased(locale: Locale = .current) -> String {
        guard let firstIndex = firstIndex(where: { !$0.isWhitespace }) else {
            return self
        }
        let prefix = self[..<firstIndex]
        let first = String(self[firstIndex]).uppercased(with: locale)
        let rest = self[index(after: firstIndex)...]
        return String(prefix) + first + rest
    }
}

func localizedTitle(_ key: String) -> String {
    #if canImport(SwiftUI)
    localizedString(key).firstWordInitialUppercased(locale: RepsLocalization.locale)
    #else
    localizedString(key).firstWordInitialUppercased()
    #endif
}

func localizedTitleText(_ text: String) -> String {
    #if canImport(SwiftUI)
    text.firstWordInitialUppercased(locale: RepsLocalization.locale)
    #else
    text.firstWordInitialUppercased()
    #endif
}

func localizedFormat(_ key: String, _ arguments: CVarArg...) -> String {
    #if canImport(SwiftUI)
    String(
        format: RepsLocalization.string(key),
        locale: RepsLocalization.locale,
        arguments: arguments
    )
    #else
    String(format: String(localized: String.LocalizationValue(key)), locale: .current, arguments: arguments)
    #endif
}

enum RepsAppGroup {
    static let identifier = "group.com.romerodev.repsfitness"

    static var isAvailable: Bool {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: identifier) != nil
    }
}

enum WatchCommand: String, Sendable {
    case pause
    case resume
    case stop
    case musicToggle
    case musicNext
    case musicPrevious
    case completeSet
    case nextExercise
    case previousExercise
    case addWater
    case voiceNote

    var notificationName: Notification.Name {
        Notification.Name("WatchCommand.\(rawValue)")
    }
}

enum WatchRouteWorkoutActivity: String, Codable, Hashable, Sendable {
    case walking
    case running

    var title: String {
        switch self {
        case .walking:
            return localizedString("route_activity_walking")
        case .running:
            return localizedString("route_activity_running")
        }
    }
}

struct SharedRoutePoint: Codable, Hashable, Sendable {
    var latitude: Double
    var longitude: Double
    var altitude: Double?
    var horizontalAccuracy: Double?
    var timestamp: Date
    var heartRate: Double? = nil
    var cadenceSpm: Double? = nil
}

struct WatchRouteWorkoutSummary: Codable, Hashable, Sendable {
    var id: UUID
    var activity: WatchRouteWorkoutActivity
    var startedAt: Date
    var endedAt: Date
    var durationSeconds: Int
    var pausedSeconds: Int
    var distanceKm: Double?
    var averagePaceSecondsPerKm: Double?
    var averageSpeedKmh: Double?
    var steps: Double?
    var activeEnergyKcal: Double?
    var averageHeartRate: Double?
    var maxHeartRate: Double?
    var routePoints: [SharedRoutePoint]

    var durationMinutes: Int {
        max(durationSeconds / 60, 1)
    }
}

/// One logged/planned set as it travels between iPhone and Watch.
/// `setType` is the raw value of `SetLog.SetType`; `trackingType` (on the
/// owning exercise) the raw value of `Exercise.TrackingType`.
struct SharedPlannedSet: Codable, Hashable, Sendable {
    var weightKg: Double
    var reps: Int
    var completed: Bool
    var setType: String
    var rpe: Double? = nil
}

/// A full exercise (with its sets) shared so the Watch can render and log a
/// strength workout — both the planned list pushed from the iPhone and the
/// log dumped back from the Watch reuse this shape.
struct SharedPlannedExercise: Codable, Hashable, Sendable {
    var name: String
    var trackingType: String
    var targetSets: Int
    var repRange: String
    var restSeconds: Int
    var previous: String?
    var sets: [SharedPlannedSet]
}

/// Strength workout logged on the Watch and dumped to the iPhone when it
/// reconnects. Mirrors the route summary path so the phone can import a
/// complete `WorkoutSession` with `exerciseLogs`.
struct WatchStrengthWorkoutSummary: Codable, Hashable, Sendable {
    var id: UUID
    var title: String
    var startedAt: Date
    var endedAt: Date
    var durationSeconds: Int
    var pausedSeconds: Int
    var exercises: [SharedPlannedExercise]
    var activeEnergyKcal: Double?
    var averageHeartRate: Double?
    var maxHeartRate: Double?

    var durationMinutes: Int { max(durationSeconds / 60, 1) }
}

/// Interval / HIIT workout authored and run on the Watch, dumped to the iPhone
/// as a HIIT cardio log.
struct WatchIntervalWorkoutSummary: Codable, Hashable, Sendable {
    var id: UUID
    var name: String
    var rounds: Int
    var workSeconds: Int
    var restSeconds: Int
    var startedAt: Date
    var endedAt: Date
    var durationSeconds: Int
    var pausedSeconds: Int
    var activeEnergyKcal: Double?
    var averageHeartRate: Double?
    var maxHeartRate: Double?
    /// Seconds spent in each HR zone (Z1…Z5), when available.
    var timeInZoneSeconds: [Int]? = nil

    var durationMinutes: Int { max(durationSeconds / 60, 1) }
}

struct SharedWorkoutSnapshot: Codable, Hashable {
    var hasActiveWorkout: Bool
    var planTitle: String?
    var workoutTitle: String
    var sessionTitle: String?
    var elapsedSeconds: Int
    var pausedSeconds: Int
    var completedSets: Int
    var totalSets: Int
    var volumeKg: Int
    var isPaused: Bool
    var exerciseName: String?
    var exerciseIndex: Int?
    var totalExercises: Int?
    var currentExerciseCompletedSets: Int?
    var currentExerciseTotalSets: Int?
    var currentSetWeightKg: Double?
    var currentSetReps: Int?
    var restSeconds: Int?
    var restDurationSeconds: Int?
    var estimatedRemainingSeconds: Int?
    var waterLiters: Double?
    var musicTitle: String?
    var musicArtist: String?
    var isMusicPlaying: Bool?
    var nextExerciseName: String?
    var exerciseHistorySummary: String?
    var gymPassName: String?
    var gymMembershipID: String?
    var gymCodeValue: String?
    var gymCodeType: String?
    var heartRate: Double?
    var activeEnergyKcal: Double?
    var isRouteWorkout: Bool
    var isOutdoorRoute: Bool? = nil
    var routeDistanceKm: Double?
    var routePaceSecondsPerKm: Double?
    var routeSpeedKmh: Double?
    var routePointCount: Int?
    var routeSteps: Double?
    var summary: String
    var updatedAt: Date

    // New properties for enhanced widgets
    var streakDays: Int
    var weeklyCompletion: Double
    var trainingBatteryLevel: Int
    var trainingBatteryState: String
    var trainingBatteryTitle: String
    var trainingBatterySuggestion: String
    var trainingBatterySystemImage: String
    var nextWorkoutDayName: String?
    var nextWorkoutDayDescription: String?
    /// Raw WidgetColor name — drives the widget background color
    var widgetAccentColorName: String
    var preferredLanguage: String? = nil
    /// JSON-encoded `[SharedPlannedExercise]` for the active strength workout,
    /// letting the Watch render the full exercise list and log sets live.
    var exercisesData: Data? = nil
    /// Estimated max heart rate (≈ 220 − age) for HR-zone coloring on the Watch.
    var estimatedMaxHeartRate: Double? = nil
    /// Whether the user holds an active Pro entitlement — synced from iOS so the Watch can gate Pro-only features.
    var hasWatchAccess: Bool = true

    /// Decoded planned exercises from `exercisesData`, if present.
    var plannedExercises: [SharedPlannedExercise] {
        guard let exercisesData,
              let decoded = try? JSONDecoder().decode([SharedPlannedExercise].self, from: exercisesData) else {
            return []
        }
        return decoded
    }

    static let empty = SharedWorkoutSnapshot(
        hasActiveWorkout: false,
        planTitle: nil,
        workoutTitle: "StreakRep",
        sessionTitle: nil,
        elapsedSeconds: 0,
        pausedSeconds: 0,
        completedSets: 0,
        totalSets: 0,
        volumeKg: 0,
        isPaused: false,
        exerciseName: nil,
        exerciseIndex: nil,
        totalExercises: nil,
        currentExerciseCompletedSets: nil,
        currentExerciseTotalSets: nil,
        currentSetWeightKg: nil,
        currentSetReps: nil,
        restSeconds: nil,
        restDurationSeconds: nil,
        estimatedRemainingSeconds: nil,
        waterLiters: nil,
        musicTitle: nil,
        musicArtist: nil,
        isMusicPlaying: nil,
        nextExerciseName: nil,
        exerciseHistorySummary: nil,
        gymPassName: nil,
        gymMembershipID: nil,
        gymCodeValue: nil,
        gymCodeType: nil,
        heartRate: nil,
        activeEnergyKcal: nil,
        isRouteWorkout: false,
        isOutdoorRoute: nil,
        routeDistanceKm: nil,
        routePaceSecondsPerKm: nil,
        routeSpeedKmh: nil,
        routePointCount: nil,
        routeSteps: nil,
        summary: localizedString("widget_no_active_workout"),
        updatedAt: .now,
        streakDays: 0,
        weeklyCompletion: 0.0,
        trainingBatteryLevel: 100,
        trainingBatteryState: "charged",
        trainingBatteryTitle: localizedString("battery_state_charged"),
        trainingBatterySuggestion: localizedString("battery_suggestion_good"),
        trainingBatterySystemImage: "battery.100percent",
        nextWorkoutDayName: nil,
        nextWorkoutDayDescription: nil,
        widgetAccentColorName: "system",
        preferredLanguage: "es"
    )

    #if DEBUG || targetEnvironment(simulator)
    static func watchASODemo(language: String) -> SharedWorkoutSnapshot {
        RepsLocalization.use(language)
        let isSpanish = RepsLocalization.language == "es"
        let exercises = [
            SharedPlannedExercise(
                name: isSpanish ? "Press banca" : "Bench Press",
                trackingType: "weightReps",
                targetSets: 4,
                repRange: "6-8",
                restSeconds: 120,
                previous: isSpanish ? "92.5 kg x 6" : "92.5 kg x 6",
                sets: [
                    SharedPlannedSet(weightKg: 92.5, reps: 6, completed: true, setType: WatchSetTypeRaw.work),
                    SharedPlannedSet(weightKg: 92.5, reps: 6, completed: true, setType: WatchSetTypeRaw.work),
                    SharedPlannedSet(weightKg: 90, reps: 7, completed: false, setType: WatchSetTypeRaw.work),
                    SharedPlannedSet(weightKg: 87.5, reps: 8, completed: false, setType: WatchSetTypeRaw.work)
                ]
            ),
            SharedPlannedExercise(
                name: isSpanish ? "Remo con barra" : "Barbell Row",
                trackingType: "weightReps",
                targetSets: 4,
                repRange: "8-10",
                restSeconds: 105,
                previous: isSpanish ? "82.5 kg x 8" : "82.5 kg x 8",
                sets: [
                    SharedPlannedSet(weightKg: 82.5, reps: 8, completed: false, setType: WatchSetTypeRaw.work),
                    SharedPlannedSet(weightKg: 82.5, reps: 8, completed: false, setType: WatchSetTypeRaw.work),
                    SharedPlannedSet(weightKg: 80, reps: 10, completed: false, setType: WatchSetTypeRaw.work)
                ]
            )
        ]
        let exercisesData = try? JSONEncoder().encode(exercises)

        return SharedWorkoutSnapshot(
            hasActiveWorkout: false,
            planTitle: isSpanish ? "Upper Lower 4 dias" : "Upper Lower 4-Day",
            workoutTitle: isSpanish ? "Fuerza torso" : "Upper Strength",
            sessionTitle: nil,
            elapsedSeconds: 0,
            pausedSeconds: 0,
            completedSets: 0,
            totalSets: 7,
            volumeKg: 32385,
            isPaused: false,
            exerciseName: isSpanish ? "Press banca" : "Bench Press",
            exerciseIndex: 1,
            totalExercises: 6,
            currentExerciseCompletedSets: 2,
            currentExerciseTotalSets: 4,
            currentSetWeightKg: 90,
            currentSetReps: 7,
            restSeconds: nil,
            restDurationSeconds: 120,
            estimatedRemainingSeconds: 2700,
            waterLiters: 1.2,
            musicTitle: "Heavy sets / clean reps",
            musicArtist: "StreakRep Mix",
            isMusicPlaying: true,
            nextExerciseName: isSpanish ? "Remo con barra" : "Barbell Row",
            exerciseHistorySummary: isSpanish ? "Mejor reciente: 92.5 kg x 6" : "Recent best: 92.5 kg x 6",
            gymPassName: isSpanish ? "Gimnasio Central" : "Downtown Gym",
            gymMembershipID: "SR-2048",
            gymCodeValue: "SR-2048",
            gymCodeType: "barcode",
            heartRate: 132,
            activeEnergyKcal: 286,
            isRouteWorkout: false,
            isOutdoorRoute: nil,
            routeDistanceKm: nil,
            routePaceSecondsPerKm: nil,
            routeSpeedKmh: nil,
            routePointCount: nil,
            routeSteps: nil,
            summary: isSpanish ? "4/4 sesiones esta semana" : "4/4 sessions this week",
            updatedAt: .now,
            streakDays: 18,
            weeklyCompletion: 1.0,
            trainingBatteryLevel: 72,
            trainingBatteryState: "steady",
            trainingBatteryTitle: isSpanish ? "Lista para entrenar" : "Ready to train",
            trainingBatterySuggestion: isSpanish ? "Buen margen para fuerza; controla el RPE." : "Good margin for strength; keep RPE controlled.",
            trainingBatterySystemImage: "battery.75percent",
            nextWorkoutDayName: isSpanish ? "Fuerza torso" : "Upper Strength",
            nextWorkoutDayDescription: isSpanish ? "6 ejercicios · 55 min · gimnasio" : "6 exercises · 55 min · gym",
            widgetAccentColorName: "green",
            preferredLanguage: RepsLocalization.language,
            exercisesData: exercisesData,
            estimatedMaxHeartRate: 188,
            hasWatchAccess: true
        )
    }

    private enum WatchSetTypeRaw {
        static let work = "work"
    }
    #endif

    var progress: Double {
        guard totalSets > 0 else { return 0 }
        return min(max(Double(completedSets) / Double(totalSets), 0), 1)
    }

    var elapsedText: String {
        Self.durationText(elapsedSeconds)
    }

    var elapsedStartDate: Date {
        updatedAt.addingTimeInterval(-TimeInterval(elapsedSeconds))
    }

    var remainingText: String {
        Self.durationText(estimatedRemainingSeconds ?? 0)
    }

    var restText: String {
        Self.durationText(restSeconds ?? 0)
    }

    var restEndDate: Date? {
        guard let restSeconds, restSeconds > 0 else {
            return nil
        }
        return updatedAt.addingTimeInterval(TimeInterval(restSeconds))
    }

    var restProgress: Double {
        guard let restSeconds,
              let restDurationSeconds,
              restDurationSeconds > 0 else {
            return 0
        }
        let completed = Double(restDurationSeconds - restSeconds) / Double(restDurationSeconds)
        return min(max(completed, 0), 1)
    }

    static func durationText(_ value: Int) -> String {
        let seconds = max(value, 0)
        let hours = seconds / 3_600
        let minutes = (seconds % 3_600) / 60
        let remainingSeconds = seconds % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, remainingSeconds)
        }
        return String(format: "%02d:%02d", minutes, remainingSeconds)
    }

    static func validPositive(_ value: Double?) -> Double? {
        guard let value, value.isFinite, value > 0 else {
            return nil
        }
        return value
    }

    static func routeDistanceText(_ distanceKm: Double?, compact: Bool = false) -> String {
        guard let distance = validPositive(distanceKm) else {
            return compact ? "0.0" : "0.00 km"
        }
        return compact ? String(format: "%.1f", distance) : String(format: "%.2f km", distance)
    }

    static func routePaceText(_ secondsPerKm: Double?) -> String {
        guard let secondsPerKm = validPositive(secondsPerKm) else {
            return "--"
        }
        let seconds = Int(secondsPerKm)
        return "\(seconds / 60):\(String(format: "%02d", seconds % 60))/km"
    }

    static func routeSpeedText(_ speedKmh: Double?) -> String {
        guard let speedKmh = validPositive(speedKmh) else {
            return "--"
        }
        return String(format: "%.1f km/h", speedKmh)
    }

    static func integerMetricText(_ value: Double?) -> String {
        guard let value = validPositive(value) else {
            return "--"
        }
        return "\(Int(value))"
    }

    static func heartRateText(_ value: Double?) -> String {
        guard let value = validPositive(value) else {
            return "--"
        }
        return "\(Int(value)) lpm"
    }

    var routeDistanceText: String {
        Self.routeDistanceText(routeDistanceKm)
    }

    var compactRouteDistanceText: String {
        Self.routeDistanceText(routeDistanceKm, compact: true)
    }

    var routePaceText: String {
        Self.routePaceText(routePaceSecondsPerKm)
    }

    var routeSpeedText: String {
        Self.routeSpeedText(routeSpeedKmh)
    }

    var routeSubtitleText: String {
        [routeDistanceText, routePaceText]
            .filter { $0 != "--" }
            .joined(separator: " · ")
    }
}

enum SharedWorkoutStore {
    private static let key = "activeWorkoutSnapshot"
    private static let lastTimelineReloadKey = "activeWorkoutSnapshot.lastTimelineReload"
    private static let widgetKinds = [
        "RepsWorkoutWidget",
        "RepsBatteryWidget",
        "RepsStreakWidget",
        "RepsFriendsWidget"
    ]
    private static let minimumTimelineReloadInterval: TimeInterval = 3

    static func load() -> SharedWorkoutSnapshot {
        guard RepsAppGroup.isAvailable else {
            return .empty
        }
        guard let defaults = UserDefaults(suiteName: RepsAppGroup.identifier),
              let data = defaults.data(forKey: key),
              let snapshot = try? JSONDecoder().decode(SharedWorkoutSnapshot.self, from: data) else {
            return .empty
        }
        return snapshot
    }

    static func save(_ snapshot: SharedWorkoutSnapshot, reloadTimelines: Bool = true, forceReload: Bool = false) {
        guard RepsAppGroup.isAvailable else {
            return
        }
        guard let defaults = UserDefaults(suiteName: RepsAppGroup.identifier),
              let data = try? JSONEncoder().encode(snapshot) else {
            return
        }
        defaults.set(data, forKey: key)
        guard reloadTimelines else {
            return
        }
        #if canImport(WidgetKit)
        #if !os(watchOS)
        let now = Date()
        let lastReload = Date(timeIntervalSince1970: defaults.double(forKey: lastTimelineReloadKey))
        guard forceReload || now.timeIntervalSince(lastReload) >= minimumTimelineReloadInterval else {
            return
        }
        defaults.set(now.timeIntervalSince1970, forKey: lastTimelineReloadKey)
        widgetKinds.forEach { kind in
            WidgetCenter.shared.reloadTimelines(ofKind: kind)
        }
        #endif
        #endif
    }

}

// MARK: - Shared Leaderboard (Friends Widget)

struct SharedLeaderboardEntry: Codable, Hashable, Identifiable {
    var id: String { username }
    var rank: Int
    var username: String
    var xp: Int
    var isMe: Bool
}

enum SharedLeaderboardStore {
    private static let key = "friendsLeaderboardSnapshot"
    private static let widgetKind = "RepsFriendsWidget"

    static func save(_ entries: [SharedLeaderboardEntry]) {
        guard RepsAppGroup.isAvailable,
              let defaults = UserDefaults(suiteName: RepsAppGroup.identifier),
              let data = try? JSONEncoder().encode(entries) else { return }
        defaults.set(data, forKey: key)
        #if canImport(WidgetKit)
        #if !os(watchOS)
        WidgetCenter.shared.reloadTimelines(ofKind: widgetKind)
        #endif
        #endif
    }

    static func load() -> [SharedLeaderboardEntry] {
        guard RepsAppGroup.isAvailable,
              let defaults = UserDefaults(suiteName: RepsAppGroup.identifier),
              let data = defaults.data(forKey: key),
              let entries = try? JSONDecoder().decode([SharedLeaderboardEntry].self, from: data) else {
            return []
        }
        return entries
    }
}

#if canImport(ActivityKit)
struct RepsWorkoutActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        var snapshot: SharedWorkoutSnapshot
    }

    var workoutTitle: String
}
#endif
