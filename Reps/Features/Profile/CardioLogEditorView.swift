import SwiftUI

struct CardioLogEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppStore.self) private var store

    @State private var activityType: CardioLog.ActivityType = .treadmill
    @State private var date = Date()
    @State private var duration = "30"
    @State private var distance = ""
    @State private var averageHeartRate = ""
    @State private var maxHeartRate = ""
    @State private var calories = ""
    @State private var rpe = ""
    @State private var notes = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("activity_2") {
                    Picker("training_type", selection: $activityType) {
                        ForEach(CardioLog.ActivityType.allCases) { type in
                            Text(type.displayName).tag(type)
                        }
                    }
                    DatePicker("date_2", selection: $date)
                    TextField("duration_min_2", text: $duration)
                        .keyboardType(.numberPad)
                    TextField("Distancia (\(store.userProfile.distanceUnit.rawValue))", text: $distance)
                        .keyboardType(.decimalPad)
                }

                Section("intensidad") {
                    TextField("fc_media", text: $averageHeartRate)
                        .keyboardType(.decimalPad)
                    TextField("maximum_hr", text: $maxHeartRate)
                        .keyboardType(.decimalPad)
                    TextField("calories_2", text: $calories)
                        .keyboardType(.decimalPad)
                    TextField("rpe_1_10", text: $rpe)
                        .keyboardType(.decimalPad)
                }

                Section("notes_2") {
                    TextField("sensaciones_ritmo_molestias", text: $notes, axis: .vertical)
                        .lineLimit(3...5)
                }
            }
            .navigationTitle("registrar_cardio")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("cancel") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("save") { save() }
                        .disabled(Int(duration) == nil)
                }
            }
        }
    }

    private func save() {
        let distanceValue = decimal(distance)
        let distanceKm: Double?
        if let distanceValue {
            distanceKm = store.userProfile.distanceUnit == .kilometers ? distanceValue : distanceValue * 1.609_344
        } else {
            distanceKm = nil
        }

        store.addCardioLog(CardioLog(
            activityType: activityType,
            date: date,
            durationMinutes: Int(duration) ?? 0,
            distanceKm: distanceKm,
            averageSpeedKmh: nil,
            averagePaceSecondsPerKm: nil,
            averageHeartRate: decimal(averageHeartRate),
            maxHeartRate: decimal(maxHeartRate),
            estimatedCalories: decimal(calories),
            rpe: decimal(rpe),
            notes: notes.isEmpty ? nil : notes
        ))
        dismiss()
    }
}

private extension CardioLog.ActivityType {
    var displayName: LocalizedStringKey {
        switch self {
        case .treadmill: "treadmill"
        case .elliptical: "elliptical"
        case .stationaryBike: "stationary_bike"
        case .outdoorRun: "outdoor_run"
        case .walking: "walking"
        case .rowing: "rowing"
        case .hiit: "HIIT"
        case .other: "other"
        }
    }
}

private func decimal(_ text: String) -> Double? {
    let normalized = text.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: ",", with: ".")
    guard !normalized.isEmpty else { return nil }
    return Double(normalized)
}
