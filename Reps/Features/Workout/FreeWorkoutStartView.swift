import SwiftUI

struct FreeWorkoutStartView: View {
    @EnvironmentObject private var store: AppStore

    private var isSpanish: Bool {
        store.userProfile.preferredLanguage.hasPrefix("es")
    }

    var body: some View {
        List {
            Section {
                NavigationLink {
                    ActiveWorkoutView(workout: .freeWorkout, origin: .free)
                } label: {
                    FreeWorkoutStartRow(
                        title: isSpanish ? "Fuerza libre" : "Free Strength",
                        subtitle: isSpanish ? "Añade ejercicios y registra series." : "Add exercises and log sets.",
                        systemImage: "dumbbell.fill"
                    )
                }

                NavigationLink {
                    ActiveWorkoutView(workout: .freeWalk, origin: .free)
                } label: {
                    FreeWorkoutStartRow(
                        title: isSpanish ? "Caminata" : "Walk",
                        subtitle: isSpanish ? "GPS, ruta, pasos, distancia y vitales." : "GPS, route, steps, distance, and vitals.",
                        systemImage: "figure.walk"
                    )
                }

                NavigationLink {
                    ActiveWorkoutView(workout: .freeRun, origin: .free)
                } label: {
                    FreeWorkoutStartRow(
                        title: isSpanish ? "Carrera" : "Run",
                        subtitle: isSpanish ? "Ritmo, mapa, pulso y resumen final." : "Pace, map, heart rate, and final summary.",
                        systemImage: "figure.run"
                    )
                }
            } header: {
                Text(isSpanish ? "Entrenamiento libre" : "Free Workout")
            } footer: {
                Text(isSpanish ? "Caminata y carrera guardan también un registro de cardio y tributan a tus estadísticas." : "Walks and runs also save a cardio log and count toward your stats.")
            }
        }
        .navigationTitle(isSpanish ? "Empezar" : "Start")
        .navigationBarTitleDisplayMode(.inline)
        .screenBackground()
    }
}

private struct FreeWorkoutStartRow: View {
    let title: String
    let subtitle: String
    let systemImage: String

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: systemImage)
                .font(.headline.weight(.bold))
                .foregroundStyle(PulseTheme.primary)
                .frame(width: 42, height: 42)
                .background(PulseTheme.primary.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: PulseTheme.compactRadius, style: .continuous))

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.headline)
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(PulseTheme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.vertical, 4)
    }
}

extension WorkoutDay {
    static var freeWalk: WorkoutDay {
        WorkoutDay(
            title: "Caminata libre",
            subtitle: "GPS, ruta y sensores",
            durationMinutes: 30,
            exercises: [],
            sessionType: .cardioWalk
        )
    }

    static var freeRun: WorkoutDay {
        WorkoutDay(
            title: "Carrera libre",
            subtitle: "Ritmo, ruta y sensores",
            durationMinutes: 30,
            exercises: [],
            sessionType: .cardioRun
        )
    }
}
