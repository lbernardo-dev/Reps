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
                    ActiveWorkoutView(workout: .freeOutdoorWalk, origin: .free)
                } label: {
                    FreeWorkoutStartRow(
                        title: isSpanish ? "Caminata exterior" : "Outdoor Walk",
                        subtitle: isSpanish ? "GPS, ruta, pasos, distancia y vitales." : "GPS, route, steps, distance, and vitals.",
                        systemImage: "figure.walk"
                    )
                }

                NavigationLink {
                    ActiveWorkoutView(workout: .freeTreadmillWalk, origin: .free)
                } label: {
                    FreeWorkoutStartRow(
                        title: isSpanish ? "Caminata en cinta" : "Treadmill Walk",
                        subtitle: isSpanish ? "Sin mapa: tiempo, pasos, pulso, kcal y distancia si la cinta/Watch la aporta." : "No map: time, steps, heart rate, kcal, and distance when available.",
                        systemImage: "figure.walk.motion"
                    )
                }

                NavigationLink {
                    ActiveWorkoutView(workout: .freeOutdoorRun, origin: .free)
                } label: {
                    FreeWorkoutStartRow(
                        title: isSpanish ? "Carrera exterior" : "Outdoor Run",
                        subtitle: isSpanish ? "Ritmo, mapa, pulso y resumen final." : "Pace, map, heart rate, and final summary.",
                        systemImage: "figure.run"
                    )
                }

                NavigationLink {
                    ActiveWorkoutView(workout: .freeTreadmillRun, origin: .free)
                } label: {
                    FreeWorkoutStartRow(
                        title: isSpanish ? "Carrera en cinta" : "Treadmill Run",
                        subtitle: isSpanish ? "Sin GPS: tiempo, ritmo, pulso y kcal desde sensores." : "No GPS: time, pace, heart rate, and kcal from sensors.",
                        systemImage: "figure.run.treadmill"
                    )
                }
            } header: {
                Text(isSpanish ? "Entrenamiento libre" : "Free Workout")
            } footer: {
                Text(isSpanish ? "Exterior usa GPS y mapa. Cinta no pide ruta ni muestra mapa; guarda sensores y distancia cuando esté disponible." : "Outdoor uses GPS and map. Treadmill skips route tracking and saves sensors plus distance when available.")
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
    static var freeOutdoorWalk: WorkoutDay {
        WorkoutDay(
            title: "Caminata exterior",
            subtitle: "GPS, ruta y sensores",
            durationMinutes: 30,
            exercises: [],
            sessionType: .cardioWalk,
            cardioEnvironment: .outdoor
        )
    }

    static var freeTreadmillWalk: WorkoutDay {
        WorkoutDay(
            title: "Caminata en cinta",
            subtitle: "Sin GPS, con sensores",
            durationMinutes: 30,
            exercises: [],
            sessionType: .cardioWalk,
            cardioEnvironment: .treadmill
        )
    }

    static var freeOutdoorRun: WorkoutDay {
        WorkoutDay(
            title: "Carrera exterior",
            subtitle: "Ritmo, ruta y sensores",
            durationMinutes: 30,
            exercises: [],
            sessionType: .cardioRun,
            cardioEnvironment: .outdoor
        )
    }

    static var freeTreadmillRun: WorkoutDay {
        WorkoutDay(
            title: "Carrera en cinta",
            subtitle: "Sin GPS, con sensores",
            durationMinutes: 30,
            exercises: [],
            sessionType: .cardioRun,
            cardioEnvironment: .treadmill
        )
    }
}
