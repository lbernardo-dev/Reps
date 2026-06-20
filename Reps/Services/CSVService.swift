import Foundation

struct CSVExporter {
    let snapshot: AppSnapshot

    func makeCSV() -> String {
        [
            section("exercises", rows: exerciseRows),
            section("workout_sessions", rows: sessionRows),
            section("sets", rows: setRows),
            section("cardio_logs", rows: cardioRows),
            section("body_metrics", rows: bodyRows),
            section("progress_photos", rows: progressPhotoRows),
            section("gym_passes", rows: gymPassRows),
            section("gym_visits", rows: gymVisitRows),
            section("goals", rows: goalRows)
        ]
        .joined(separator: "\n\n")
    }

    private var exerciseRows: [[String]] {
        [["id", "name", "muscle_group", "equipment", "type", "difficulty", "environment", "source"]] +
        snapshot.exercises.map {
            [
                $0.id.uuidString,
                $0.name,
                $0.muscleGroup,
                $0.equipment,
                $0.exerciseType.rawValue,
                $0.difficulty.rawValue,
                $0.environment.rawValue,
                $0.sourceName ?? "manual"
            ]
        }
    }

    private var sessionRows: [[String]] {
        [["id", "title", "date", "duration_min", "location", "context", "session_rpe", "volume_kg", "notes"]] +
        snapshot.workoutSessions.map {
            [
                $0.id.uuidString,
                $0.workoutTitle,
                Self.format($0.date),
                "\($0.durationMinutes)",
                $0.location.rawValue,
                $0.contextTag.rawValue,
                Self.value($0.sessionRPE),
                Self.value(FitnessMetrics.totalVolumeKg(for: [$0])),
                $0.notes ?? ""
            ]
        }
    }

    private var setRows: [[String]] {
        let header = [["session_id", "exercise", "set_number", "type", "weight_kg", "reps", "rpe", "rir", "tempo", "rest_seconds", "pr", "notes"]]
        let rows = snapshot.workoutSessions.flatMap { session in
            (session.exerciseLogs ?? [ExerciseLog(exercise: SeedData.bench, notes: session.notes ?? "", sets: session.sets)]).flatMap { log in
                log.sets.map { set in
                    let rir = set.rir.map(String.init) ?? ""
                    let rest = set.previousRestSeconds.map(String.init) ?? ""
                    let pr = set.isPersonalRecord ? "true" : "false"
                    let notes = set.notes ?? ""
                    return [
                        session.id.uuidString,
                        log.exercise.name,
                        String(set.setNumber),
                        set.setType.rawValue,
                        Self.value(set.weightKg),
                        String(set.reps),
                        Self.value(set.rpe),
                        rir,
                        set.tempo ?? "",
                        rest,
                        pr,
                        notes
                    ] as [String]
                }
            }
        }
        return header + rows
    }

    private var cardioRows: [[String]] {
        [["id", "activity", "date", "duration_min", "distance_km", "avg_hr", "max_hr", "calories", "steps", "active_energy_kcal", "hr_before", "hr_after", "rpe", "notes"]] +
        snapshot.cardioLogs.map {
            [
                $0.id.uuidString,
                $0.activityType.rawValue,
                Self.format($0.date),
                "\($0.durationMinutes)",
                Self.value($0.distanceKm),
                Self.value($0.averageHeartRate),
                Self.value($0.maxHeartRate),
                Self.value($0.estimatedCalories),
                Self.value($0.steps),
                Self.value($0.activeEnergyKcal),
                Self.value($0.heartRateBefore),
                Self.value($0.heartRateAfter),
                Self.value($0.rpe),
                $0.notes ?? ""
            ]
        }
    }

    private var bodyRows: [[String]] {
        [["id", "date", "weight_kg", "height_cm", "body_fat", "waist_cm", "sleep_hours", "sleep_quality", "fatigue", "stress", "soreness", "source", "water_liters", "dietary_energy_kcal"]] +
        snapshot.bodyMetrics.map {
            [
                $0.id.uuidString,
                Self.format($0.date),
                Self.value($0.weightKg),
                Self.value($0.heightCm),
                Self.value($0.bodyFatPercentage),
                Self.value($0.waistCm),
                Self.value($0.sleepHours),
                $0.sleepQuality.map(String.init) ?? "",
                $0.fatigue.map(String.init) ?? "",
                $0.stress.map(String.init) ?? "",
                $0.sorenessNotes ?? "",
                $0.source.rawValue,
                Self.value($0.waterLiters),
                Self.value($0.dietaryEnergyKcal)
            ]
        }
    }

    private var progressPhotoRows: [[String]] {
        [["id", "date", "weight_kg", "note", "image_bytes"]] +
        snapshot.progressPhotos.map {
            [
                $0.id.uuidString,
                Self.format($0.date),
                Self.value($0.weightKg),
                $0.note ?? "",
                "\($0.imageData.count)"
            ]
        }
    }

    private var gymPassRows: [[String]] {
        [["id", "gym", "membership_id", "code_value", "code_type", "notes"]] +
        snapshot.gymPasses.map {
            [$0.id.uuidString, $0.gymName, $0.membershipID, $0.codeValue, $0.codeType.rawValue, $0.notes ?? ""]
        }
    }

    private var gymVisitRows: [[String]] {
        [["id", "gym", "date", "location_note", "workout"]] +
        snapshot.gymVisits.map {
            [$0.id.uuidString, $0.gymName, Self.format($0.date), $0.locationNote ?? "", $0.workoutTitle ?? ""]
        }
    }

    private var goalRows: [[String]] {
        [["id", "kind", "title", "current", "target", "unit", "deadline"]] +
        snapshot.goals.map {
            [
                $0.id.uuidString,
                $0.kind.rawValue,
                $0.title,
                Self.value($0.current),
                Self.value($0.target),
                $0.unit,
                $0.deadline.map(Self.format) ?? ""
            ]
        }
    }

    private func section(_ name: String, rows: [[String]]) -> String {
        (["# \(name)"] + rows.map { $0.map(Self.escape).joined(separator: ",") }).joined(separator: "\n")
    }

    private static func escape(_ value: String) -> String {
        let escaped = value.replacingOccurrences(of: "\"", with: "\"\"")
        if escaped.contains(",") || escaped.contains("\n") || escaped.contains("\"") {
            return "\"\(escaped)\""
        }
        return escaped
    }

    private static func format(_ date: Date) -> String {
        ISO8601DateFormatter().string(from: date)
    }

    private static func value(_ value: Double?) -> String {
        value.map { String(format: "%.2f", $0) } ?? ""
    }
}

struct CSVImporter {
    let csv: String

    func cardioLogs() -> [CardioLog] {
        rows(in: "cardio_logs").compactMap { row in
            guard row.count >= 10,
                  let activity = CardioLog.ActivityType(rawValue: row[1]),
                  let date = Self.date(row[2]),
                  let duration = Int(row[3]) else {
                return nil
            }
            let isExpanded = row.count >= 14
            return CardioLog(
                activityType: activity,
                date: date,
                durationMinutes: duration,
                distanceKm: Self.double(row[4]),
                averageHeartRate: Self.double(row[5]),
                maxHeartRate: Self.double(row[6]),
                estimatedCalories: Self.double(row[7]),
                steps: isExpanded ? Self.double(row[8]) : nil,
                activeEnergyKcal: isExpanded ? Self.double(row[9]) : nil,
                heartRateBefore: isExpanded ? Self.double(row[10]) : nil,
                heartRateAfter: isExpanded ? Self.double(row[11]) : nil,
                rpe: Self.double(isExpanded ? row[12] : row[8]),
                notes: (isExpanded ? row[13] : row[9]).isEmpty ? nil : (isExpanded ? row[13] : row[9])
            )
        }
    }

    func bodyMetrics() -> [BodyMetric] {
        rows(in: "body_metrics").compactMap { row in
            guard row.count >= 12,
                  let date = Self.date(row[1]),
                  let weight = Self.double(row[2]),
                  let height = Self.double(row[3]) else {
                return nil
            }
            return BodyMetric(
                date: date,
                weightKg: weight,
                heightCm: height,
                bodyFatPercentage: Self.double(row[4]),
                waistCm: Self.double(row[5]),
                sleepHours: Self.double(row[6]),
                sleepQuality: Int(row[7]),
                fatigue: Int(row[8]),
                stress: Int(row[9]),
                waterLiters: row.count > 12 ? Self.double(row[12]) : nil,
                dietaryEnergyKcal: row.count > 13 ? Self.double(row[13]) : nil,
                sorenessNotes: row[10].isEmpty ? nil : row[10],
                source: BodyMetric.Source(rawValue: row[11]) ?? .manual
            )
        }
    }

    func gymPasses() -> [GymPass] {
        rows(in: "gym_passes").compactMap { row in
            guard row.count >= 5 else {
                return nil
            }

            let hasCodeValueColumn = row.count >= 6
            let codeValue = hasCodeValueColumn ? row[3] : row[2]
            let typeIndex = hasCodeValueColumn ? 4 : 3
            let notesIndex = hasCodeValueColumn ? 5 : 4

            guard let type = GymPass.CodeType(rawValue: row[typeIndex]) else {
                return nil
            }
            return GymPass(
                gymName: row[1],
                membershipID: row[2],
                codeValue: codeValue,
                codeType: type,
                colorHex: "#FFCC24",
                notes: row[notesIndex].isEmpty ? nil : row[notesIndex]
            )
        }
    }

    func gymVisits() -> [GymVisit] {
        rows(in: "gym_visits").compactMap { row in
            guard row.count >= 5,
                  let date = Self.date(row[2]) else {
                return nil
            }
            return GymVisit(
                gymName: row[1],
                date: date,
                locationNote: row[3].isEmpty ? nil : row[3],
                workoutTitle: row[4].isEmpty ? nil : row[4]
            )
        }
    }

    func goals() -> [Goal] {
        rows(in: "goals").compactMap { row in
            guard row.count >= 7,
                  let kind = Goal.Kind(rawValue: row[1]),
                  let current = Self.double(row[3]),
                  let target = Self.double(row[4]) else {
                return nil
            }
            return Goal(
                kind: kind,
                title: row[2],
                current: current,
                target: target,
                unit: row[5],
                deadline: row[6].isEmpty ? nil : Self.date(row[6])
            )
        }
    }

    private func rows(in sectionName: String) -> [[String]] {
        let lines = csv.components(separatedBy: .newlines)
        guard let start = lines.firstIndex(where: { $0 == "# \(sectionName)" }) else {
            return []
        }

        return lines.dropFirst(start + 2)
            .prefix { !$0.hasPrefix("# ") && !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            .map(Self.parseLine)
    }

    private static func parseLine(_ line: String) -> [String] {
        var values: [String] = []
        var current = ""
        var quoted = false
        for character in line {
            if character == "\"" {
                quoted.toggle()
            } else if character == "," && !quoted {
                values.append(current)
                current = ""
            } else {
                current.append(character)
            }
        }
        values.append(current)
        return values.map { $0.replacingOccurrences(of: "\"\"", with: "\"") }
    }

    private static func date(_ value: String) -> Date? {
        ISO8601DateFormatter().date(from: value)
    }

    private static func double(_ value: String) -> Double? {
        Double(value.replacingOccurrences(of: ",", with: "."))
    }
}

// MARK: - Strong CSV Import

// Strong app exports a flat CSV with one row per set:
// Date, Workout Name, Exercise Name, Set Order, Weight, Reps,
// Distance, Seconds, Notes, Workout Notes, RPE
struct StrongCSVImporter {
    let csv: String

    func workoutSessions(knownExercises: [Exercise]) -> [WorkoutSession] {
        let rawLines = csv.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        guard rawLines.count > 1 else { return [] }

        let rows = rawLines.dropFirst().compactMap { StrongRow(line: $0) }
        guard !rows.isEmpty else { return [] }

        // Preserve insertion order while grouping by (day + workout name)
        var keyOrder: [String] = []
        var grouped: [String: [StrongRow]] = [:]
        for row in rows {
            if grouped[row.sessionKey] == nil {
                keyOrder.append(row.sessionKey)
                grouped[row.sessionKey] = []
            }
            grouped[row.sessionKey]?.append(row)
        }

        return keyOrder.compactMap { key in
            guard let sessionRows = grouped[key], let first = sessionRows.first else { return nil }
            return buildSession(title: first.workoutName, date: first.date, rows: sessionRows, catalog: knownExercises)
        }
    }

    private func buildSession(title: String, date: Date, rows: [StrongRow], catalog: [Exercise]) -> WorkoutSession {
        var exOrder: [String] = []
        var exGroups: [String: [StrongRow]] = [:]
        for row in rows {
            if exGroups[row.exerciseName] == nil {
                exOrder.append(row.exerciseName)
                exGroups[row.exerciseName] = []
            }
            exGroups[row.exerciseName]?.append(row)
        }

        let logs: [ExerciseLog] = exOrder.compactMap { name in
            guard let exRows = exGroups[name] else { return nil }
            let exercise = resolve(name: name, in: catalog)
            let sets = exRows.enumerated().map { i, row in
                SetLog(
                    setNumber: row.setOrder ?? (i + 1),
                    weightKg: row.weightKg ?? 0,
                    reps: row.reps ?? 0,
                    completed: true,
                    rpe: row.rpe
                )
            }
            let note = exRows.compactMap(\.notes).first { !$0.isEmpty } ?? ""
            return ExerciseLog(exercise: exercise, notes: note, sets: sets)
        }

        let workoutNote = rows.compactMap(\.workoutNotes).first { !$0.isEmpty }
        let duration = estimatedDuration(from: rows)

        return WorkoutSession(
            workoutTitle: title,
            date: date,
            origin: .routine,
            location: .gym,
            durationMinutes: duration,
            sets: logs.flatMap(\.sets),
            notes: workoutNote,
            exerciseLogs: logs
        )
    }

    private func resolve(name: String, in catalog: [Exercise]) -> Exercise {
        let key = normalized(name)
        if let hit = catalog.first(where: { normalized($0.name) == key }) { return hit }
        if let hit = catalog.first(where: { $0.aliases.contains(where: { normalized($0) == key }) }) { return hit }
        return Exercise(name: name, muscleGroup: "Other", equipment: "Other")
    }

    private func normalized(_ s: String) -> String {
        s.trimmingCharacters(in: .whitespacesAndNewlines)
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            .replacingOccurrences(of: "-", with: " ")
    }

    private func estimatedDuration(from rows: [StrongRow]) -> Int {
        let dates = rows.map(\.date)
        guard let earliest = dates.min(), let latest = dates.max() else { return 45 }
        let minutes = Int(latest.timeIntervalSince(earliest) / 60)
        return minutes > 5 ? min(minutes + 10, 180) : 45
    }
}

private struct StrongRow {
    let date: Date
    let workoutName: String
    let exerciseName: String
    let setOrder: Int?
    let weightKg: Double?
    let reps: Int?
    let notes: String?
    let workoutNotes: String?
    let rpe: Double?

    // Groups rows into the same session: day + workout name
    var sessionKey: String {
        let day = Calendar.current.startOfDay(for: date)
        return "\(day.timeIntervalSince1970)|\(workoutName)"
    }

    init?(line: String) {
        let fields = Self.parseLine(line)
        guard fields.count >= 6 else { return nil }
        guard let parsedDate = Self.parseStrongDate(fields[0]) else { return nil }

        date = parsedDate
        workoutName = fields[1]
        exerciseName = fields[2]
        setOrder = Int(fields[3])
        weightKg = fields[4].isEmpty ? nil : Double(fields[4].replacingOccurrences(of: ",", with: "."))
        reps = fields[5].isEmpty ? nil : Int(fields[5])
        // Index 6 = distance, 7 = seconds, 8 = notes, 9 = workout notes, 10 = rpe
        notes = fields.count > 8 && !fields[8].isEmpty ? fields[8] : nil
        workoutNotes = fields.count > 9 && !fields[9].isEmpty ? fields[9] : nil
        rpe = fields.count > 10 ? Double(fields[10]) : nil
    }

    // Strong uses "yyyy-MM-dd HH:mm:ss" (space separator, no timezone)
    private static let strongDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd HH:mm:ss"
        f.locale = Locale(identifier: "en_US_POSIX")
        return f
    }()

    private static func parseStrongDate(_ value: String) -> Date? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if let d = strongDateFormatter.date(from: trimmed) { return d }
        if let d = ISO8601DateFormatter().date(from: trimmed) { return d }
        // Try date-only "yyyy-MM-dd"
        let shortFormatter = DateFormatter()
        shortFormatter.dateFormat = "yyyy-MM-dd"
        shortFormatter.locale = Locale(identifier: "en_US_POSIX")
        return shortFormatter.date(from: trimmed)
    }

    private static func parseLine(_ line: String) -> [String] {
        var values: [String] = []
        var current = ""
        var quoted = false
        for ch in line {
            if ch == "\"" { quoted.toggle() }
            else if ch == "," && !quoted { values.append(current); current = "" }
            else { current.append(ch) }
        }
        values.append(current)
        return values.map { $0.replacingOccurrences(of: "\"\"", with: "\"") }
    }
}
