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
        if let fallback = fallbackStrings[activeLanguage]?[key] {
            return fallback
        }
        if let fallback = socialFallbackStrings[activeLanguage]?[key] {
            return fallback
        }
        if let fallback = timerFallbackStrings[activeLanguage]?[key] {
            return fallback
        }
        if let fallback = planFallbackStrings[activeLanguage]?[key] {
            return fallback
        }
        if let fallback = workoutFallbackStrings[activeLanguage]?[key] {
            return fallback
        }
        if let fallback = settingsFallbackStrings[activeLanguage]?[key] {
            return fallback
        }
        if let fallback = batteryFallbackStrings[activeLanguage]?[key] {
            return fallback
        }
        if let fallback = calculatorFallbackStrings[activeLanguage]?[key] {
            return fallback
        }
        if let fallback = progressFallbackStrings[activeLanguage]?[key] {
            return fallback
        }
        if let fallback = widgetFallbackStrings[activeLanguage]?[key] {
            return fallback
        }
        if let fallback = todayFallbackStrings[activeLanguage]?[key] {
            return fallback
        }
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
        let systemValue = String(localized: String.LocalizationValue(key), bundle: .main, locale: locale)
        if systemValue != key {
            return systemValue
        }
        return fallbackStrings[activeLanguage]?[key] ?? key
    }

    /// Safety net for dynamic keys that may not yet be present in a compiled
    /// String Catalog. It prevents technical keys from reaching the UI while
    /// preserving the catalog as the source of truth when a translation exists.
    private static let fallbackStrings: [String: [String: String]] = [
        "en": [
            "filter_by_goal_place_and_material": "Filter by goal, place and equipment",
            "combine_type_muscle_group_equipment_and_difficulty_to_narrow_the_catalog": "Combine type, muscle group, equipment and difficulty to narrow the catalog",
            "search_exercises": "Search exercises",
            "goal_hub_subtitle": "Define and track what matters to you",
            "compatible_with_you": "A routine that fits your equipment",
            "onboarding_reconfigure_title": "Reconfigure your plan",
            "onboarding_reconfigure_subtitle": "Update your goals, schedule and equipment",
            "data_and_privacy": "Data and privacy",
            "exports_backups_cloud_sync_and_data_privacy": "Exports, backups, cloud sync and data privacy",
            "units_language_theme_widgets_reminders_and_pro_preferences": "Units, language, theme, widgets, reminders and Pro preferences",
            "tour_replay_title": "Replay the tour",
            "tour_replay_subtitle": "Review the main features of StreakReps",
            "support_and_product": "Support and product",
            "help_feedback_privacy_subscription_whats_new_and_version": "Help, feedback, privacy, subscription, what's new and version",
            "train_and_build": "Train and build",
            "library": "Exercise library",
            "route_heart_rate_and_rpe": "Route, heart rate and RPE",
            "action_center": "Action center",
            "summary": "Summary",
            "metric_2": "Metric",
            "general_label": "General",
            "month_label": "Month",
            "year_label": "Year",
            "all_time_label": "All time",
            "kg_total": "Total kg",
            "sleep_target": "Sleep target",
            "workouts_per_week": "Workouts per week",
            "daily_calories": "Daily calories",
            "share_progress": "Share progress",
            "resting": "Resting",
            "feedback": "Feedback",
            "add_periodic_photos_to_compare_progress": "Add periodic photos to compare your progress",
            "import_csv": "Import CSV", "import_json": "Import JSON", "delete_social_profile_subtitle": "Remove your social profile and activity",
            "goal_new_title": "New goal", "goal_edit_title": "Edit goal", "goal_kind_label": "Type",
            "goal_kind_strength": "Strength", "goal_kind_strength_hint": "Set a strength target",
            "goal_kind_consistency": "Consistency", "goal_kind_consistency_hint": "Build a consistent routine",
            "goal_kind_bodyweight": "Body weight", "goal_kind_bodyweight_hint": "Reach a body-weight target",
            "goal_kind_custom": "Custom", "goal_kind_custom_hint": "Track a goal that matters to you",
            "goal_summary_active": "Active", "goal_summary_achieved": "Achieved", "goal_summary_total": "Total",
            "goal_filter_all": "All", "goal_filter_active": "Active", "goal_filter_achieved": "Achieved",
            "goal_empty_title": "No goals yet", "goal_empty_subtitle": "Create a goal to track your progress", "goal_add_first": "Add your first goal",
            "goal_badge_achieved": "Achieved", "goal_badge_overdue": "Overdue", "goal_badge_active": "Active",
            "goal_title_label": "Name", "goal_title_placeholder": "e.g. Bench press 100 kg", "goal_values_label": "Values", "goal_current_label": "Current", "goal_target_label": "Target", "goal_unit_label": "Unit",
            "goal_set_deadline": "Set a deadline", "goal_deadline_label": "Deadline", "goal_reason_label": "Why this goal?", "goal_reason_placeholder": "Your motivation", "goal_delete_action": "Delete goal", "goal_delete_confirm_title": "Delete goal?", "goal_delete_confirm_message": "This action cannot be undone.",
            "calorie_goal_fat_loss": "Lose fat", "calorie_goal_recomposition": "Recomposition", "calorie_goal_strength": "Build strength", "calorie_goal_build_muscle": "Build muscle",
            "elliptical": "Elliptical", "stationary_bike": "Stationary bike", "outdoor_run": "Outdoor run",
            "social_xp_boost": "XP Boost", "social_delete_post_title": "Delete post?", "social_delete_post_message": "This action cannot be undone.", "social_delete_post_action": "Delete", "social_edit_post": "Edit post"
            ,"all_6a720856": "All", "con_video": "With video", "con_foto": "With photo", "con_instrucciones": "With instructions", "home_70f8bb9a": "Home", "gym_bc435923": "Gym", "bodyweight_4aa2dcf8": "Bodyweight", "free_weights": "Free weights", "machines": "Machines",
            "training_type_0105f54e": "Training type", "muscle_group": "Muscle group", "equipment": "Equipment", "environment": "Environment", "difficulty": "Difficulty", "only_my_equipment": "Only my equipment", "choose_at_least_one_characteristic": "Choose at least one characteristic", "search_pick_a_category_or_adjust_any_filter_to_load_a_focused_exercise_list": "Search, pick a category or adjust a filter to load a focused exercise list", "any_environment_0db63b25": "Any environment", "any_difficulty_324bac01": "Any difficulty", "exercises": "Exercises", "muscle_arms": "Arms", "water": "Water", "muscles_label": "Muscles", "no_data_for_this_range": "No data for this range", "avg_hr_2": "Avg HR", "detalles_adicionales": "Additional details", "next_adjustment": "Next adjustment", "session_control_center": "Session control center", "remaining_time": "Remaining time", "sync_watch_label": "Sync Watch", "continue_plan": "Continue plan", "plan_save_cta": "Save plan", "app_training_and_permissions": "App, training and permissions", "app_preferences": "App preferences", "measurement": "Measurement", "workout_session": "Workout session", "widgets": "Widgets", "connected_to_apple_health": "Connected to Apple Health", "not_connected_to_apple_health": "Not connected to Apple Health", "language_theme_and_interface": "Language, theme and interface", "units_distance_and_training_defaults": "Units, distance and training defaults", "confirmations_advanced_logging_and_equipment": "Confirmations, advanced logging and equipment", "home_screen_watch_and_live_activity_style": "Home screen, Watch and Live Activity style", "alerts_for_scheduled_sessions_and_consistency": "Alerts for scheduled sessions and consistency"
        ],
        "es": [
            "filter_by_goal_place_and_material": "Filtra por objetivo, lugar y equipamiento",
            "combine_type_muscle_group_equipment_and_difficulty_to_narrow_the_catalog": "Combina tipo, grupo muscular, equipamiento y dificultad para filtrar",
            "search_exercises": "Buscar ejercicios",
            "goal_hub_subtitle": "Define y sigue lo que importa para ti",
            "compatible_with_you": "Una rutina adaptada a tu equipamiento",
            "onboarding_reconfigure_title": "Reconfigura tu plan",
            "onboarding_reconfigure_subtitle": "Actualiza tus objetivos, horario y equipamiento",
            "data_and_privacy": "Datos y privacidad",
            "exports_backups_cloud_sync_and_data_privacy": "Exportaciones, copias, sincronización y privacidad",
            "units_language_theme_widgets_reminders_and_pro_preferences": "Unidades, idioma, tema, widgets, recordatorios y preferencias Pro",
            "tour_replay_title": "Repetir guía",
            "tour_replay_subtitle": "Repasa las funciones principales de StreakReps",
            "support_and_product": "Soporte y producto",
            "help_feedback_privacy_subscription_whats_new_and_version": "Ayuda, opinión, privacidad, suscripción, novedades y versión",
            "train_and_build": "Entrena y crea",
            "library": "Biblioteca de ejercicios",
            "route_heart_rate_and_rpe": "Ruta, frecuencia cardíaca y RPE",
            "action_center": "Centro de acciones",
            "summary": "Resumen",
            "metric_2": "Métrica",
            "general_label": "General",
            "month_label": "Mes",
            "year_label": "Año",
            "all_time_label": "Todo el tiempo",
            "kg_total": "kg totales",
            "sleep_target": "Objetivo de sueño",
            "workouts_per_week": "Entrenamientos por semana",
            "daily_calories": "Calorías diarias",
            "share_progress": "Compartir progreso",
            "resting": "Reposo",
            "feedback": "Opinión",
            "add_periodic_photos_to_compare_progress": "Añade fotos periódicas para comparar tu progreso",
            "import_csv": "Importar CSV", "import_json": "Importar JSON", "delete_social_profile_subtitle": "Elimina tu perfil social y su actividad",
            "goal_new_title": "Nuevo objetivo", "goal_edit_title": "Editar objetivo", "goal_kind_label": "Tipo",
            "goal_kind_strength": "Fuerza", "goal_kind_strength_hint": "Define un objetivo de fuerza",
            "goal_kind_consistency": "Constancia", "goal_kind_consistency_hint": "Crea una rutina constante",
            "goal_kind_bodyweight": "Peso corporal", "goal_kind_bodyweight_hint": "Alcanza un objetivo de peso corporal",
            "goal_kind_custom": "Personalizado", "goal_kind_custom_hint": "Sigue un objetivo importante para ti",
            "goal_summary_active": "Activos", "goal_summary_achieved": "Logrados", "goal_summary_total": "Total",
            "goal_filter_all": "Todos", "goal_filter_active": "Activos", "goal_filter_achieved": "Logrados",
            "goal_empty_title": "Aún no tienes objetivos", "goal_empty_subtitle": "Crea un objetivo para seguir tu progreso", "goal_add_first": "Añade tu primer objetivo",
            "goal_badge_achieved": "Logrado", "goal_badge_overdue": "Vencido", "goal_badge_active": "Activo",
            "goal_title_label": "Nombre", "goal_title_placeholder": "p. ej., Press de banca 100 kg", "goal_values_label": "Valores", "goal_current_label": "Actual", "goal_target_label": "Objetivo", "goal_unit_label": "Unidad",
            "goal_set_deadline": "Establecer una fecha límite", "goal_deadline_label": "Fecha límite", "goal_reason_label": "¿Por qué este objetivo?", "goal_reason_placeholder": "Tu motivación", "goal_delete_action": "Eliminar objetivo", "goal_delete_confirm_title": "¿Eliminar objetivo?", "goal_delete_confirm_message": "Esta acción no se puede deshacer.",
            "calorie_goal_fat_loss": "Perder grasa", "calorie_goal_recomposition": "Recomposición", "calorie_goal_strength": "Ganar fuerza", "calorie_goal_build_muscle": "Ganar músculo",
            "elliptical": "Elíptica", "stationary_bike": "Bicicleta estática", "outdoor_run": "Carrera al aire libre",
            "social_xp_boost": "Impulso de XP", "social_delete_post_title": "¿Eliminar publicación?", "social_delete_post_message": "Esta acción no se puede deshacer.", "social_delete_post_action": "Eliminar", "social_edit_post": "Editar publicación"
            ,"all_6a720856": "Todos", "con_video": "Con vídeo", "con_foto": "Con foto", "con_instrucciones": "Con instrucciones", "home_70f8bb9a": "Casa", "gym_bc435923": "Gimnasio", "bodyweight_4aa2dcf8": "Peso corporal", "free_weights": "Pesos libres", "machines": "Máquinas",
            "training_type_0105f54e": "Tipo de entrenamiento", "muscle_group": "Grupo muscular", "equipment": "Equipamiento", "environment": "Entorno", "difficulty": "Dificultad", "only_my_equipment": "Solo mi equipamiento", "choose_at_least_one_characteristic": "Elige al menos una característica", "search_pick_a_category_or_adjust_any_filter_to_load_a_focused_exercise_list": "Busca, elige una categoría o ajusta un filtro para cargar una lista de ejercicios", "any_environment_0db63b25": "Cualquier entorno", "any_difficulty_324bac01": "Cualquier dificultad", "exercises": "Ejercicios", "muscle_arms": "Brazos", "water": "Agua", "muscles_label": "Músculos", "no_data_for_this_range": "No hay datos para este periodo", "avg_hr_2": "FC media", "detalles_adicionales": "Detalles adicionales", "next_adjustment": "Siguiente ajuste", "session_control_center": "Centro de control de la sesión", "remaining_time": "Tiempo restante", "sync_watch_label": "Sincronizar Watch", "continue_plan": "Continuar plan", "plan_save_cta": "Guardar plan", "app_training_and_permissions": "App, entrenamiento y permisos", "app_preferences": "Preferencias de la app", "measurement": "Medición", "workout_session": "Sesión de entrenamiento", "widgets": "Widgets", "connected_to_apple_health": "Conectado a Apple Health", "not_connected_to_apple_health": "No conectado a Apple Health", "language_theme_and_interface": "Idioma, tema e interfaz", "units_distance_and_training_defaults": "Unidades, distancia y valores de entrenamiento", "confirmations_advanced_logging_and_equipment": "Confirmaciones, registro avanzado y equipamiento", "home_screen_watch_and_live_activity_style": "Estilo para pantalla de inicio, Watch y Live Activity", "alerts_for_scheduled_sessions_and_consistency": "Alertas para sesiones programadas y constancia"
        ]
    ]

    private static let socialFallbackStrings: [String: [String: String]] = [
        "en": [
            "social_feed_empty_title": "Your feed is empty",
            "social_feed_empty_message": "Follow friends to see their workouts here.",
            "social_no_friends_yet": "No friends yet",
            "social_no_friends_message": "Add friends to compare progress and stay motivated.",
            "social_find_friends": "Find friends",
            "social_find_friends_message": "Search by username to connect with friends.",
            "social_no_results": "No results",
            "social_no_results_message": "No profiles match your search.",
            "challenge_empty_title": "No challenges yet",
            "challenge_empty_message": "Create a challenge and invite your friends.",
            "streak": "Streak"
        ],
        "es": [
            "social_feed_empty_title": "Tu feed está vacío",
            "social_feed_empty_message": "Sigue a tus amigos para ver aquí sus entrenamientos.",
            "social_no_friends_yet": "Aún no tienes amigos",
            "social_no_friends_message": "Añade amigos para comparar progresos y mantener la motivación.",
            "social_find_friends": "Buscar amigos",
            "social_find_friends_message": "Busca por nombre de usuario para conectar con amigos.",
            "social_no_results": "Sin resultados",
            "social_no_results_message": "No hay perfiles que coincidan con tu búsqueda.",
            "challenge_empty_title": "Aún no hay retos",
            "challenge_empty_message": "Crea un reto e invita a tus amigos.",
            "streak": "Racha"
        ]
    ]

    private static let timerFallbackStrings: [String: [String: String]] = [
        "en": [
            "timer_kind_stopwatch": "Stopwatch", "timer_kind_countdown": "Countdown", "timer_kind_tabata": "Tabata", "timer_kind_emom": "EMOM", "timer_kind_amrap": "AMRAP", "timer_kind_boxing": "Boxing", "timer_kind_metronome": "Metronome", "timer_kind_yoga": "Yoga", "duration": "Duration", "sleep_quality_label": "Sleep quality", "stress_label": "Stress"
        ],
        "es": [
            "timer_kind_stopwatch": "Cronómetro", "timer_kind_countdown": "Cuenta atrás", "timer_kind_tabata": "Tabata", "timer_kind_emom": "EMOM", "timer_kind_amrap": "AMRAP", "timer_kind_boxing": "Boxeo", "timer_kind_metronome": "Metrónomo", "timer_kind_yoga": "Yoga", "duration": "Duración", "sleep_quality_label": "Calidad del sueño", "stress_label": "Estrés"
        ]
    ]

    private static let planFallbackStrings: [String: [String: String]] = [
        "en": [
            "between_exercises": "Between exercises", "superset_create": "Create superset", "plan_smart_defaults_title": "Smart defaults", "plan_smart_defaults_body": "Recommended values are already applied.", "activate_on_save_loss_hint": "This plan will become active when saved.", "do_you_have_a_target_event": "Do you have a target event?", "adapt_duration_according_to_deadline": "Adapt the plan duration to your deadline.", "event_name": "Event name", "weeks": "Weeks", "days_per_week_short": "Days/week"
        ],
        "es": [
            "between_exercises": "Entre ejercicios", "superset_create": "Crear superserie", "plan_smart_defaults_title": "Valores inteligentes", "plan_smart_defaults_body": "Los valores recomendados ya están aplicados.", "activate_on_save_loss_hint": "Este plan se activará al guardarlo.", "do_you_have_a_target_event": "¿Tienes un evento objetivo?", "adapt_duration_according_to_deadline": "Adapta la duración del plan a tu fecha límite.", "event_name": "Nombre del evento", "weeks": "Semanas", "days_per_week_short": "Días/sem"
        ]
    ]

    private static let workoutFallbackStrings: [String: [String: String]] = [
        "en": ["target": "Target", "details": "Details", "hide": "Hide", "edit_playlist": "Edit playlist"],
        "es": ["target": "Objetivo", "details": "Detalles", "hide": "Ocultar", "edit_playlist": "Editar lista"]
    ]

    private static let settingsFallbackStrings: [String: [String: String]] = [
        "en": ["included_improvements": "Included improvements", "terms_of_service_subtitle": "Terms of service subtitle", "reads_steps_heart_rate_sleep_and_body_metrics_from_apple_health": "Reads steps, heart rate, sleep and body metrics from Apple Health", "writes_completed_workouts_and_body_metrics_when_you_sync": "Writes completed workouts and body metrics when you sync", "smart_shortcuts": "Smart shortcuts", "smart_shortcuts_subtitle": "Quick access to what you use most", "what_to_progress_today": "What to progress today", "plan_identity": "Plan identity", "free_training_starts_empty_so_you_record_only_what_you_do_today": "Free training starts empty so you record only what you do today", "reps_stores_workouts_routines_metrics_photos_and_cards_locally": "Reps stores workouts, routines, metrics, photos and cards locally", "apple_health_only_used_if_connected": "Apple Health is used only if you connect it", "photos_camera_music_notifications_and_location_requested_when_used": "Photos, camera, music, notifications and location are requested only when used", "widgets_read_minimum_summary_from_app_group": "Widgets read a minimum summary from the app group", "app_records_minimum_product_events_for_stability": "The app records only minimum product events for stability", "no_workout_names_notes_photos_or_health_data_sent_to_analytics": "No workout names, notes, photos or health data are sent to analytics", "ready_routines_with_days_exercises_sets_rests_and_progression": "Ready-made routines with days, exercises, sets, rests and progression", "free_log_with_notes_photos_water_rpe_rir_tempo_and_rests": "Free logging with notes, photos, water, RPE, RIR, tempo and rests", "final_summary_with_volume_records_and_visual_receipts": "Final summary with volume records and visual receipts", "apple_health_imports_metrics_and_saves_workouts_with_permission": "Apple Health imports metrics and saves workouts with permission", "widgets_watch_and_live_activities_follow_session_outside_app": "Widgets, Watch and Live Activities let you follow your session outside the app", "apple_music_plays_playlists_during_workouts": "Apple Music plays playlists during workouts", "today_s_load": "Today's load", "weekly_load": "Weekly load", "points_computed": "Points", "volume_intensity": "Volume intensity", "real_rest": "Actual rest", "since_last_session": "Since last session", "hrv_average": "Average HRV", "autonomic_system_state": "Autonomic system state"],
        "es": ["included_improvements": "Mejoras incluidas", "terms_of_service_subtitle": "Condiciones del servicio", "reads_steps_heart_rate_sleep_and_body_metrics_from_apple_health": "Lee pasos, frecuencia cardíaca, sueño y métricas corporales de Apple Health", "writes_completed_workouts_and_body_metrics_when_you_sync": "Guarda entrenamientos completados y métricas corporales al sincronizar", "smart_shortcuts": "Atajos inteligentes", "smart_shortcuts_subtitle": "Accede rápido a lo que más usas", "what_to_progress_today": "Qué mejorar hoy", "plan_identity": "Identidad del plan", "free_training_starts_empty_so_you_record_only_what_you_do_today": "El entrenamiento libre empieza vacío para registrar solo lo que hagas hoy", "reps_stores_workouts_routines_metrics_photos_and_cards_locally": "Reps guarda localmente tus entrenamientos, rutinas, métricas, fotos y tarjetas", "apple_health_only_used_if_connected": "Apple Health solo se usa si lo conectas", "photos_camera_music_notifications_and_location_requested_when_used": "Las fotos, cámara, música, notificaciones y ubicación se solicitan solo al usarlas", "widgets_read_minimum_summary_from_app_group": "Los widgets leen un resumen mínimo del grupo de la app", "app_records_minimum_product_events_for_stability": "La app registra solo los eventos mínimos del producto para garantizar la estabilidad", "no_workout_names_notes_photos_or_health_data_sent_to_analytics": "No se envían nombres de entrenamientos, notas, fotos ni datos de salud a analítica", "ready_routines_with_days_exercises_sets_rests_and_progression": "Rutinas preparadas con días, ejercicios, series, descansos y progresión", "free_log_with_notes_photos_water_rpe_rir_tempo_and_rests": "Registro libre con notas, fotos, agua, RPE, RIR, tempo y descansos", "final_summary_with_volume_records_and_visual_receipts": "Resumen final con volumen, récords y recibos visuales", "apple_health_imports_metrics_and_saves_workouts_with_permission": "Apple Health importa métricas y guarda entrenamientos con permiso", "widgets_watch_and_live_activities_follow_session_outside_app": "Widgets, Watch y Actividades en directo para seguir tu sesión fuera de la app", "apple_music_plays_playlists_during_workouts": "Apple Music reproduce listas durante los entrenamientos", "today_s_load": "Carga de hoy", "weekly_load": "Carga semanal", "points_computed": "Puntos calculados", "volume_intensity": "Intensidad del volumen", "real_rest": "Descanso real", "since_last_session": "Desde la última sesión", "hrv_average": "VFC media", "autonomic_system_state": "Estado del sistema autónomo"]
    ]

    private static let batteryFallbackStrings: [String: [String: String]] = [
        "en": ["today_s_load": "Today's load", "weekly_load": "Weekly load", "points_computed": "Points", "volume_intensity": "Volume intensity", "real_rest": "Actual rest", "since_last_session": "Since last session", "hrv_average": "Average HRV", "autonomic_system_state": "Autonomic system state", "day_singular_count_format": "%d day"],
        "es": ["today_s_load": "Carga de hoy", "weekly_load": "Carga semanal", "points_computed": "Puntos calculados", "volume_intensity": "Intensidad del volumen", "real_rest": "Descanso real", "since_last_session": "Desde la última sesión", "hrv_average": "VFC media", "autonomic_system_state": "Estado del sistema autónomo", "day_singular_count_format": "%d día"]
    ]

    private static let calculatorFallbackStrings: [String: [String: String]] = [
        "en": ["olympic_bar": "Olympic bar", "women_bar": "Women's bar", "technique_bar": "Technique bar", "z_bar": "EZ bar"],
        "es": ["olympic_bar": "Barra olímpica", "women_bar": "Barra femenina", "technique_bar": "Barra técnica", "z_bar": "Barra Z"]
    ]

    private static let progressFallbackStrings: [String: [String: String]] = [
        "en": [
            "load_metric": "Load",
            "effective_sets": "Effective sets",
            "7_days": "7 days",
            "acute_chronic": "Acute / chronic",
            "fatigue_score": "Fatigue score",
            "last_day": "Last day",
            "health_trends": "Health trends",
            "sleep_metric": "Sleep",
            "fatigue_rating": "Fatigue rating",
            "stress_metric": "Stress",
            "recovery": "Recovery",
            "this_year": "This year",
            "THIS_YEAR": "This year",
            "all_time": "All time",
            "ALL_TIME": "All time",
            "insights_actionable": "Actionable insights",
            "plan_and_review_load": "Plan and review load",
            "last_7_days": "Last 7 days", "predict": "Prediction", "all_muscles": "All muscles", "upper_body": "Upper body", "arms_label": "Arms", "back_label": "Back", "legs_label": "Legs", "alerts_label": "Alerts", "muscle_map_actual_subtitle": "Weekly volume by muscle group", "muscle_map_predict_subtitle": "Predicted volume by muscle group", "weekly": "Weekly", "of_12_weekly_sets": "of 12 weekly sets",
            "Insights_accionables": "Actionable insights"
        ],
        "es": [
            "load_metric": "Carga",
            "effective_sets": "Series efectivas",
            "7_days": "7 días",
            "acute_chronic": "Agudo / crónico",
            "fatigue_score": "Puntuación de fatiga",
            "last_day": "Último día",
            "health_trends": "Tendencias de salud",
            "sleep_metric": "Sueño",
            "fatigue_rating": "Valoración de fatiga",
            "stress_metric": "Estrés",
            "recovery": "Recuperación",
            "this_year": "Este año",
            "THIS_YEAR": "Este año",
            "all_time": "Todo el tiempo",
            "ALL_TIME": "Todo el tiempo",
            "insights_actionable": "Claves accionables",
            "plan_and_review_load": "Planifica y revisa la carga",
            "last_7_days": "Últimos 7 días", "predict": "Previsión", "all_muscles": "Todos", "upper_body": "Tren superior", "arms_label": "Brazos", "back_label": "Espalda", "legs_label": "Piernas", "alerts_label": "Alertas", "muscle_map_actual_subtitle": "Volumen semanal por grupo muscular", "muscle_map_predict_subtitle": "Volumen previsto por grupo muscular", "weekly": "Semanal", "of_12_weekly_sets": "de 12 series semanales",
            "Insights_accionables": "Claves accionables"
        ]
    ]

    private static let widgetFallbackStrings: [String: [String: String]] = [
        "en": [
            "weight_widget_name": "Weight",
            "weight_widget_description": "Track body weight evolution",
            "streak_and_consistency_widget_name": "Streak & consistency",
            "streak_and_consistency_widget_description": "Track your training streak",
            "recovery_battery_widget_name": "Recovery battery",
            "recovery_battery_widget_description": "Check your recovery level",
            "reps_workout_widget_name": "Workout",
            "reps_workout_widget_description": "See your next workout",
            "days_plural": "days",
            "day_singular": "day",
            "streak_completed_label": "workouts completed",
            "streak_no_plan_label": "No active plan",
            "excellent_consistency": "Excellent consistency"
            ,"weight_evolution": "WEIGHT EVOLUTION", "weight": "WEIGHT", "body_weight": "BODY WEIGHT", "body_weight_evolution": "BODY WEIGHT EVOLUTION", "progress_and_trend": "Progress & trend", "target": "Target", "current": "CURRENT", "tap_to_open": "Tap to open"
        ],
        "es": [
            "weight_widget_name": "Peso",
            "weight_widget_description": "Evolución del peso corporal",
            "streak_and_consistency_widget_name": "Racha y constancia",
            "streak_and_consistency_widget_description": "Sigue tu racha de entrenamientos",
            "recovery_battery_widget_name": "Batería de recuperación",
            "recovery_battery_widget_description": "Consulta tu nivel de recuperación",
            "reps_workout_widget_name": "Entrenamiento",
            "reps_workout_widget_description": "Consulta tu próxima sesión",
            "days_plural": "días",
            "day_singular": "día",
            "streak_completed_label": "entrenamientos completados",
            "streak_no_plan_label": "Sin plan activo",
            "excellent_consistency": "Constancia excelente"
            ,"weight_evolution": "EVOLUCIÓN DEL PESO", "weight": "PESO", "body_weight": "PESO CORPORAL", "body_weight_evolution": "EVOLUCIÓN DEL PESO CORPORAL", "progress_and_trend": "Progreso y tendencia", "target": "Objetivo", "current": "ACTUAL", "tap_to_open": "Toca para abrir"
        ]
    ]

    private static let todayFallbackStrings: [String: [String: String]] = [
        "en": ["verdict_excellent": "Excellent", "verdict_good": "Good", "verdict_fair": "Fair", "verdict_worth_a_look": "Worth a look", "verdict_poor": "Needs attention", "heart_rate_short": "Heart rate", "edit_action": "Edit action", "in_progress": "In progress", "paused": "Paused", "started_from_apple_watch": "Apple Watch · started from Apple Watch", "fatigue": "Fatigue", "resume_workout": "Resume workout", "pause_workout": "Pause workout"],
        "es": ["verdict_excellent": "Excelente", "verdict_good": "Buena", "verdict_fair": "Aceptable", "verdict_worth_a_look": "Para revisar", "verdict_poor": "Necesita atención", "heart_rate_short": "Frecuencia cardíaca", "edit_action": "Editar acción", "in_progress": "En progreso", "paused": "Pausado", "started_from_apple_watch": "Apple Watch · iniciado desde el Watch", "fatigue": "Fatiga", "resume_workout": "Reanudar entrenamiento", "pause_workout": "Pausar entrenamiento"]
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
    /// Body weight evolution tracking properties
    var currentWeightKg: Double? = nil
    var startingWeightKg: Double? = nil
    var targetWeightKg: Double? = nil
    var weeklyWeightDeltaKg: Double? = nil
    var weightHistoryValues: [Double]? = nil

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
        workoutTitle: "StreakReps",
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

    static var samplePlaceholder: SharedWorkoutSnapshot {
        let isSpanish = RepsLocalization.language == "es"
        return SharedWorkoutSnapshot(
            hasActiveWorkout: false,
            planTitle: isSpanish ? "Fuerza e Hipertrofia" : "Strength & Hypertrophy",
            workoutTitle: "StreakReps",
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
            waterLiters: 1.8,
            musicTitle: nil,
            musicArtist: nil,
            isMusicPlaying: nil,
            nextExerciseName: nil,
            exerciseHistorySummary: nil,
            gymPassName: nil,
            gymMembershipID: nil,
            gymCodeValue: nil,
            gymCodeType: nil,
            heartRate: 68,
            activeEnergyKcal: 450,
            isRouteWorkout: false,
            isOutdoorRoute: nil,
            routeDistanceKm: nil,
            routePaceSecondsPerKm: nil,
            routeSpeedKmh: nil,
            routePointCount: nil,
            routeSteps: nil,
            summary: isSpanish ? "Sin entrenamiento activo" : "No active workout",
            updatedAt: .now,
            streakDays: 7,
            weeklyCompletion: 0.8,
            trainingBatteryLevel: 88,
            trainingBatteryState: "charged",
            trainingBatteryTitle: isSpanish ? "Óptima disposición" : "Optimal Readiness",
            trainingBatterySuggestion: isSpanish ? "Recuperación alta" : "High Recovery",
            trainingBatterySystemImage: "battery.100percent",
            nextWorkoutDayName: isSpanish ? "Empuje & Torso A" : "Push & Core Power",
            nextWorkoutDayDescription: isSpanish ? "5 ejercicios · ~45 min" : "5 exercises · ~45 min",
            widgetAccentColorName: "system",
            preferredLanguage: RepsLocalization.language,
            exercisesData: nil,
            estimatedMaxHeartRate: 190,
            hasWatchAccess: true,
            currentWeightKg: 78.5,
            startingWeightKg: 82.0,
            targetWeightKg: 75.0,
            weeklyWeightDeltaKg: -0.4,
            weightHistoryValues: [79.2, 79.0, 78.8, 78.9, 78.6, 78.5]
        )
    }

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
            musicArtist: "StreakReps Mix",
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
        return "\(Int(value)) \(localizedString("lpm"))"
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

    var workoutIconName: String {
        let name = (exerciseName ?? workoutTitle).lowercased()
        if isRouteWorkout {
            if isOutdoorRoute == false {
                return "figure.run.treadmill"
            } else if name.contains("run") || name.contains("carrera") || name.contains("jog") {
                return "figure.run"
            } else if name.contains("hike") || name.contains("senderismo") {
                return "figure.hiking"
            } else {
                return "figure.walk"
            }
        } else {
            if name.contains("core") || name.contains("abdom") || name.contains("abs") || name.contains("plank") {
                return "figure.core.training"
            } else if name.contains("stretch") || name.contains("estiramiento") || name.contains("flex") {
                return "figure.flexibility"
            } else if name.contains("yoga") {
                return "figure.yoga"
            } else if name.contains("pilates") {
                return "figure.pilates"
            } else if name.contains("jump") || name.contains("salto") || name.contains("rope") {
                return "figure.rope.skipping"
            } else if name.contains("cycle") || name.contains("ciclismo") || name.contains("bici") {
                return name.contains("outdoor") ? "figure.outdoor.cycle" : "figure.indoor.cycle"
            } else if name.contains("swim") || name.contains("natacion") {
                return "figure.pool.swim"
            } else if name.contains("box") || name.contains("kickbox") || name.contains("hit") || name.contains("hiit") {
                return "figure.high.intensity.intervaltraining"
            } else {
                return "figure.strengthtraining.traditional"
            }
        }
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

/// A tiny hand-off channel between an App Intent and the main app process.
///
/// App Shortcuts may execute while Reps is not running. Persisting the requested
/// destination in the App Group lets `openAppWhenRun` launch Reps without routing
/// through a custom URL scheme, which can be unavailable in an older installed
/// build while the system is refreshing its shortcut metadata.
enum RepsAppShortcutRoute: String {
    case freeWorkout
    case recommendedWorkout
    case progress

    private static let pendingRouteKey = "appShortcut.pendingRoute"

    static func enqueue(_ route: Self) {
        guard RepsAppGroup.isAvailable,
              let defaults = UserDefaults(suiteName: RepsAppGroup.identifier) else {
            return
        }
        defaults.set(route.rawValue, forKey: pendingRouteKey)
    }

    static func dequeue() -> Self? {
        guard RepsAppGroup.isAvailable,
              let defaults = UserDefaults(suiteName: RepsAppGroup.identifier),
              let rawValue = defaults.string(forKey: pendingRouteKey) else {
            return nil
        }
        defaults.removeObject(forKey: pendingRouteKey)
        return Self(rawValue: rawValue)
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

    static var samplePlaceholder: [SharedLeaderboardEntry] {
        [
            SharedLeaderboardEntry(rank: 1, username: "Alex Rivera", xp: 14500, isMe: false),
            SharedLeaderboardEntry(rank: 2, username: "You", xp: 12800, isMe: true),
            SharedLeaderboardEntry(rank: 3, username: "Sarah Chen", xp: 11200, isMe: false)
        ]
    }

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
              let entries = try? JSONDecoder().decode([SharedLeaderboardEntry].self, from: data),
              !entries.isEmpty else {
            return samplePlaceholder
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
