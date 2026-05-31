import WidgetKit
import SwiftUI

struct RepsWorkoutEntry: TimelineEntry {
    let date: Date
    let snapshot: SharedWorkoutSnapshot
}

struct RepsWorkoutProvider: TimelineProvider {
    func placeholder(in context: Context) -> RepsWorkoutEntry {
        RepsWorkoutEntry(date: .now, snapshot: .empty)
    }

    func getSnapshot(in context: Context, completion: @escaping (RepsWorkoutEntry) -> Void) {
        completion(RepsWorkoutEntry(date: .now, snapshot: SharedWorkoutStore.load()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<RepsWorkoutEntry>) -> Void) {
        let entry = RepsWorkoutEntry(date: .now, snapshot: SharedWorkoutStore.load())
        let next = Calendar.current.date(byAdding: .minute, value: 15, to: .now) ?? .now.addingTimeInterval(900)
        completion(Timeline(entries: [entry], policy: .after(next)))
    }
}

struct RepsWorkoutWidget: Widget {
    let kind = "RepsWorkoutWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: RepsWorkoutProvider()) { entry in
            RepsWorkoutWidgetView(entry: entry)
        }
        .configurationDisplayName("Reps Training")
        .description("Entreno activo, progreso, calorias y pulso.")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryCircular, .accessoryRectangular, .accessoryInline])
    }
}

private struct RepsWorkoutWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: RepsWorkoutEntry

    var body: some View {
        switch family {
        case .accessoryCircular:
            Gauge(value: entry.snapshot.progress) {
                Image(systemName: entry.snapshot.hasActiveWorkout ? "figure.strengthtraining.traditional" : "dumbbell")
            } currentValueLabel: {
                Text("\(entry.snapshot.completedSets)")
            }
            .gaugeStyle(.accessoryCircular)
            .widgetURL(URL(string: "reps://workout"))
        case .accessoryRectangular:
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.snapshot.exerciseName ?? (entry.snapshot.hasActiveWorkout ? entry.snapshot.workoutTitle : "Reps"))
                    .font(.headline)
                Text(entry.snapshot.hasActiveWorkout ? "\(entry.snapshot.completedSets)/\(entry.snapshot.totalSets) · \(entry.snapshot.elapsedText) · resta \(entry.snapshot.remainingText)" : entry.snapshot.summary)
                    .font(.caption)
            }
            .widgetURL(URL(string: "reps://workout"))
        case .accessoryInline:
            Text(entry.snapshot.hasActiveWorkout ? "\(entry.snapshot.workoutTitle) \(entry.snapshot.elapsedText)" : "Reps listo")
                .widgetURL(URL(string: "reps://workout"))
        default:
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: entry.snapshot.hasActiveWorkout ? "figure.strengthtraining.traditional" : "dumbbell.fill")
                        .font(.title3.weight(.bold))
                        .foregroundStyle(.green)
                    Spacer()
                    Text(entry.snapshot.isPaused ? "PAUSA" : (entry.snapshot.hasActiveWorkout ? "ACTIVO" : "LISTO"))
                        .font(.caption2.weight(.black))
                        .foregroundStyle(.secondary)
                }

                Text(entry.snapshot.hasActiveWorkout ? entry.snapshot.workoutTitle : "Reps")
                    .font(.headline)
                    .lineLimit(2)

                if let exercise = entry.snapshot.exerciseName {
                    Label(exercise, systemImage: "dumbbell.fill")
                        .font(.caption.weight(.semibold))
                        .lineLimit(1)
                        .foregroundStyle(.secondary)
                }

                ProgressView(value: entry.snapshot.progress)
                    .progressViewStyle(RepsProgressStyle(tintColor: .green))

                HStack {
                    Label(entry.snapshot.elapsedText, systemImage: "timer")
                    Spacer()
                    Label(entry.snapshot.remainingText, systemImage: "hourglass")
                }
                .font(.caption.weight(.semibold))

                if family == .systemMedium {
                    HStack {
                        Label("\(entry.snapshot.volumeKg) kg", systemImage: "scalemass")
                        Spacer()
                        Label(String(format: "%.1f L", entry.snapshot.waterLiters ?? 0), systemImage: "waterbottle.fill")
                        Spacer()
                        Label("\(Int(entry.snapshot.activeEnergyKcal ?? 0)) kcal", systemImage: "flame.fill")
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
            }
            .containerBackground(.background, for: .widget)
            .widgetURL(URL(string: "reps://workout"))
        }
    }
}
