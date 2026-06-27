import SwiftUI

struct BodyWellnessEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppStore.self) private var store
    @StateObject private var healthKit = HealthKitService.shared

    @State private var date = Date()
    @State private var weight = ""
    @State private var height = ""
    @State private var bodyFat = ""
    @State private var waist = ""
    @State private var chest = ""
    @State private var arm = ""
    @State private var thigh = ""
    @State private var hip = ""
    @State private var sleep = ""
    @State private var sleepQuality = 3
    @State private var fatigue = 3
    @State private var stress = 3
    @State private var water = ""
    @State private var dietaryEnergy = ""
    @State private var soreness = ""
    @State private var healthDefaults: BodyWellnessDefaults?
    @State private var showMeasurements = false

    init(initialWeightKg: Double, initialHeightCm: Double) {
        _weight = State(initialValue: String(format: "%.1f", initialWeightKg))
        _height = State(initialValue: String(format: "%.0f", initialHeightCm))
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("essential") {
                    DatePicker("date_2", selection: $date)
                    TextField("weight_kg_2", text: $weight)
                        .keyboardType(.decimalPad)
                    TextField("height_cm_2", text: $height)
                        .keyboardType(.decimalPad)
                    TextField("body_fat", text: $bodyFat)
                        .keyboardType(.decimalPad)
                }

                if healthDefaults != nil {
                    Section("apple_health") {
                        if let summary = healthAutoSummary {
                            Text(summary)
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                            if let context = healthSignalContext {
                                Text(context)
                                    .font(.caption)
                                    .foregroundStyle(.tertiary)
                            }
                            Button(localizedString("health_confirm_today")) { save() }
                                .foregroundStyle(PulseTheme.primary)
                        } else {
                            Text(localizedString("health_suggested_values"))
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                Section {
                    DisclosureGroup(isExpanded: $showMeasurements) {
                        TextField("cintura_cm", text: $waist)
                            .keyboardType(.decimalPad)
                        TextField("pecho_cm", text: $chest)
                            .keyboardType(.decimalPad)
                        TextField("brazo_cm", text: $arm)
                            .keyboardType(.decimalPad)
                        TextField("muslo_cm", text: $thigh)
                            .keyboardType(.decimalPad)
                        TextField("cadera_cm", text: $hip)
                            .keyboardType(.decimalPad)
                    } label: {
                        Text("measurements")
                            .foregroundStyle(.primary)
                    }
                }

                Section("wellness") {
                    TextField("sleep_hours_2", text: $sleep)
                        .keyboardType(.decimalPad)
                    TextField("water_l", text: $water)
                        .keyboardType(.decimalPad)
                    TextField("energy_ingested_kcal", text: $dietaryEnergy)
                        .keyboardType(.decimalPad)
                    RatingSelector(labelKey: "sleep_quality_label", value: $sleepQuality, higherIsBetter: true)
                    RatingSelector(labelKey: "fatigue_label", value: $fatigue, higherIsBetter: false)
                    RatingSelector(labelKey: "stress_label", value: $stress, higherIsBetter: false)
                    TextField("discomfort_or_injuries", text: $soreness, axis: .vertical)
                        .lineLimit(3...5)
                }
            }
            .navigationTitle("body_and_wellness")
            .navigationBarTitleDisplayMode(.inline)
            .task {
                await loadHealthDefaults()
            }
            .onChange(of: date) { _, _ in
                Task { await loadHealthDefaults() }
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("cancel") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("save") { save() }
                        .disabled(decimal(weight) == nil || decimal(height) == nil)
                }
            }
        }
    }

    private var healthAutoSummary: String? {
        guard let d = healthDefaults else { return nil }
        var parts: [String] = []
        if let h = d.sleepHours { parts.append(String(format: localizedString("health_sleep_format"), h)) }
        if let w = d.waterLiters { parts.append(String(format: localizedString("health_water_format"), w)) }
        if let e = d.dietaryEnergyKcal { parts.append(String(format: "%.0f kcal", e)) }
        if let q = d.sleepQuality { parts.append(String(format: localizedString("sleep_quality_value_format"), q)) }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    private var healthSignalContext: String? {
        guard let d = healthDefaults else { return nil }
        var parts: [String] = []
        if let hrv = d.heartRateVariabilityMS { parts.append(String(format: "HRV: %.0fms", hrv)) }
        if let rhr = d.restingHeartRate { parts.append(String(format: localizedString("health_resting_hr_format"), rhr)) }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    private func loadHealthDefaults() async {
        guard healthKit.isAvailable, store.health.isAuthorized else { return }
        do {
            let defaults = try await healthKit.fetchBodyWellnessDefaults(for: date)
            healthDefaults = defaults
            applyHealthDefaults(defaults)
        } catch {
            // Health data is supplementary; failures are silent
        }
    }

    private func applyHealthDefaults(_ defaults: BodyWellnessDefaults) {
        fill(&bodyFat, with: defaults.bodyFatPercentage, format: "%.1f")
        fill(&waist, with: defaults.waistCm, format: "%.1f")
        fill(&sleep, with: defaults.sleepHours, format: "%.1f")
        fill(&water, with: defaults.waterLiters, format: "%.2f")
        fill(&dietaryEnergy, with: defaults.dietaryEnergyKcal, format: "%.0f")
        if !waist.isEmpty { showMeasurements = true }

        if sleepQuality == 3, let suggested = defaults.sleepQuality {
            sleepQuality = suggested
        }
        if fatigue == 3, let suggested = defaults.fatigue {
            fatigue = suggested
        }
        if stress == 3, let suggested = defaults.stress {
            stress = suggested
        }
    }

    private func fill(_ text: inout String, with value: Double?, format: String) {
        guard text.isEmpty, let value, value > 0 else { return }
        text = String(format: format, value)
    }

    private func save() {
        guard let weightKg = decimal(weight), let heightCm = decimal(height) else { return }
        store.saveBodyMetric(BodyMetric(
            date: date,
            weightKg: weightKg,
            heightCm: heightCm,
            bodyFatPercentage: decimal(bodyFat),
            waistCm: decimal(waist),
            chestCm: decimal(chest),
            armCm: decimal(arm),
            thighCm: decimal(thigh),
            hipCm: decimal(hip),
            calfCm: nil,
            neckCm: nil,
            sleepHours: decimal(sleep),
            sleepQuality: sleepQuality,
            fatigue: fatigue,
            stress: stress,
            waterLiters: decimal(water),
            dietaryEnergyKcal: decimal(dietaryEnergy),
            sorenessNotes: soreness.isEmpty ? nil : soreness,
            source: .manual
        ))
        dismiss()
    }
}

private struct RatingSelector: View {
    let labelKey: LocalizedStringKey
    @Binding var value: Int
    var higherIsBetter: Bool = true

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(labelKey)
                .font(.subheadline)
                .foregroundStyle(.primary)
            HStack(spacing: 10) {
                ForEach(1...5, id: \.self) { n in
                    Button {
                        value = n
                    } label: {
                        ZStack {
                            Circle()
                                .fill(n == value ? dotColor(n) : Color(.systemFill))
                                .frame(width: 36, height: 36)
                            Text("\(n)")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(n == value ? .white : .secondary)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(.vertical, 4)
    }

    private func dotColor(_ n: Int) -> Color {
        let effective = higherIsBetter ? n : (6 - n)
        switch effective {
        case 5: return .green
        case 4: return Color(hue: 0.28, saturation: 0.75, brightness: 0.75)
        case 3: return .orange
        case 2: return Color(hue: 0.07, saturation: 0.85, brightness: 0.85)
        default: return .red
        }
    }
}

private func decimal(_ text: String) -> Double? {
    let normalized = text.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: ",", with: ".")
    guard !normalized.isEmpty else { return nil }
    return Double(normalized)
}
