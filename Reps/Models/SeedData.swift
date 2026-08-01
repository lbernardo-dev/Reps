import Foundation

struct ExerciseVideoCatalog {
    static let validMap: [String: Set<String>] = [
        "0051.mp4": ["pecdeckmachinefly", "pecdeckfly", "pecdeck", "butterflymachine", "seatedchestflymachine"],
        "0052.mp4": ["svendpresschest", "svendpress"],
        "0053.mp4": ["airbikesprint", "airbike", "assaultbike"],
        "0054.mp4": ["barbellbacksquat", "barbellsquat", "backsquat", "squat"],
        "0055.mp4": ["barbellbulgariansplitsquat"],
        "0056.mp4": ["barbellfrontsquat", "frontsquat"],
        "0057.mp4": ["barbellhipthrust", "hipthrust"],
        "0058.mp4": ["barbellmarch"],
        "0059.mp4": ["barbellreverselunges", "barbellreverselunge", "reverselunge"],
        "0060.mp4": ["barbellromaniandeadlift", "romaniandeadlift"],
        "0061.mp4": ["cablelegkickback", "cableglutekickback"],
        "0062.mp4": ["cycling", "stationarybike"],
        "0063.mp4": ["dumbbellbulgariansplitsquat"],
        "0064.mp4": ["dumbbellgobletsquat", "gobletsquat"],
        "0065.mp4": ["dumbbellhiphinge"],
        "0066.mp4": ["dumbbelljumpsquat", "jumpsquat"],
        "0067.mp4": ["ellipticalhiitmachine", "elliptical", "ellipticalmachine"],
        "0068.mp4": ["hacksquatmachine", "hacksquat"],
        "0069.mp4": ["hipabductionmachine", "hipabduction", "seatedhipabduction"],
        "0070.mp4": ["kettlebellholdmarch", "kettlebellmarch"],
        "0071.mp4": ["kettlebellliftup", "kettlebelldeadlift"],
        "0072.mp4": ["kettlebellswing"],
        "0073.mp4": ["legextensionmachine", "legextension"],
        "0074.mp4": ["legpressmachine", "legpress"],
        "0075.mp4": ["lyinglegcurlmachine", "lyinglegcurl"],
        "0076.mp4": ["ropewave", "battleropes"],
        "0077.mp4": ["rowingmachine", "rower"],
        "0078.mp4": ["runontreadmill", "treadmillrunning", "treadmillrun"],
        "0079.mp4": ["seatedlegcurlmachine", "seatedlegcurl"],
        "0080.mp4": ["seatedoverheadpress", "seateddumbbellpress"],
        "0081.mp4": ["stepupsweighted", "stepup", "dumbbellstepup", "weightedstepup"],
        "0082.mp4": ["stepmillmachineversion1", "stairmaster"],
        "0083.mp4": ["stepmillmachine", "stepmill"],
        "0084.mp4": ["stiffleggeddeadliftmachine", "stiffleggeddeadlift"],
        "0085.mp4": ["tricepspushdowncablerope", "cabletricepspushdown", "ropepushdown"],
        "0086.mp4": ["walkontreadmill", "treadmillwalking", "treadmillwalk"],
        "0087.mp4": ["arnoldpressdumbbell", "arnoldpress", "dumbbellarnoldpress"],
        "0088.mp4": ["barbelloverheadpressstanding", "overheadpress", "strictpress"],
        "0089.mp4": ["barbelluprightrow", "uprightrow"],
        "0090.mp4": ["dumbbelloverheadstandard", "dumbbelloverheadpress"],
        "0091.mp4": ["dumbbelluprightrow"],
        "0092.mp4": ["frontraisedumbbell", "frontraise", "dumbbellfrontraise"],
        "0093.mp4": ["frontraiseweightedplate", "platefrontraise"],
        "0094.mp4": ["kettlebelloverheadpress"],
        "0095.mp4": ["cablecrosslateralraise", "cablelateralraise"],
        "0096.mp4": ["lateralraisesdumbbell", "lateralraise", "dumbbelllateralraise"],
        "0097.mp4": ["lateralraisemachine", "machinelateralraise"],
        "0098.mp4": ["militarypressseatedsmithmachine", "smithmachineoverheadpress"],
        "0099.mp4": ["reardeltflyreversepecdeck", "reversepecdeck", "reversefly", "reardeltfly"],
        "0100.mp4": ["reardeltcablefly", "cablereardeltfly"]
    ]

    static func normKey(_ text: String) -> String {
        text.lowercased()
            .folding(options: .diacriticInsensitive, locale: .current)
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .joined()
    }

    static func isMatch(videoFile: String?, exerciseName: String, aliases: [String]) -> Bool {
        guard let videoFile, !videoFile.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return false }
        let fileName = (videoFile as NSString).lastPathComponent.lowercased()
        guard let allowedKeys = validMap[fileName] else {
            return videoFile.lowercased().hasPrefix("http://") || videoFile.lowercased().hasPrefix("https://")
        }

        let candidateKeys = ([exerciseName] + aliases).map(normKey)
        for key in candidateKeys {
            if allowedKeys.contains(key) {
                return true
            }
        }
        return false
    }
}

enum SeedData {
    private struct BundledCatalogItem: Decodable {
        let id: String?
        let name: String?
        let aliases: [String]?
        let category: String?
        let body_part: String?
        let bodyPart: String?
        let muscle_group: String?
        let muscleGroup: String?
        let target: String?
        let primary_muscles: [String]?
        let secondary_muscles: [String]?
        let secondaryMuscles: [String]?
        let equipment: String?
        let instructions: [String]?
        let instructions_text: String?
        let description: String?
        let video_file: String?
        let video_name: String?
        let video_url: String?
        let videoURL: String?
        let image_url: String?

        enum CodingKeys: String, CodingKey {
            case id, name, aliases, category, equipment, target, description
            case body_part = "body_part"
            case bodyPart = "bodyPart"
            case muscle_group = "muscle_group"
            case muscleGroup = "muscleGroup"
            case primary_muscles = "primary_muscles"
            case secondary_muscles = "secondary_muscles"
            case secondaryMuscles = "secondaryMuscles"
            case instructions
            case instructions_text = "instructions_text"
            case video_file = "video_file"
            case video_name = "video_name"
            case video_url = "video_url"
            case videoURL = "videoURL"
            case image_url = "image_url"
        }
    }

    static var bundledCatalog: [Exercise] {
        guard let url = Bundle.main.url(forResource: "exercises", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let items = try? JSONDecoder().decode([BundledCatalogItem].self, from: data) else {
            return SeedData.exercises
        }
        let bundled = items.compactMap { item -> Exercise? in
            guard let name = item.name, !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }

            let rawMuscle = item.bodyPart ?? item.target ?? item.body_part ?? item.muscle_group ?? item.muscleGroup ?? item.primary_muscles?.first ?? "General"
            let muscle = rawMuscle.capitalized
            let secondaries = (item.secondaryMuscles ?? item.secondary_muscles ?? []).map(\.capitalized)

            let derivedAliases: [String] = {
                var list = item.aliases ?? []
                let lower = name.lowercased()
                if lower.contains("pec deck") {
                    list.append(contentsOf: ["Pec Deck Fly", "Pec Deck", "Butterfly Machine", "Seated Chest Fly Machine"])
                }
                if lower.contains("bulgarian split squat") {
                    list.append(contentsOf: ["Bulgarian Split Squat", "Split Squat"])
                }
                if lower.contains("barbell back squat") || lower.contains("barbell squat") {
                    list.append(contentsOf: ["Barbell Squat", "Back Squat", "Squat"])
                }
                return Array(Set(list))
            }()

            let rawVideo = item.video_file ?? item.video_name ?? item.video_url ?? item.videoURL ?? item.id.map { "\($0).mp4" }
            let video: String? = {
                guard let rawVideo, ExerciseVideoCatalog.isMatch(videoFile: rawVideo, exerciseName: name, aliases: derivedAliases) else {
                    return nil
                }
                return rawVideo
            }()

            let mergedInstructions: String? = {
                if let arr = item.instructions, !arr.isEmpty {
                    return arr.enumerated().map { "\($0 + 1). \($1)" }.joined(separator: "\n")
                }
                return item.instructions_text ?? item.description
            }()

            return Exercise(
                id: UUID(),
                name: name,
                aliases: derivedAliases,
                muscleGroup: muscle,
                secondaryMuscles: secondaries,
                equipment: (item.equipment?.capitalized) ?? "Ninguno",
                mediaURL: item.image_url ?? FreeExerciseDBIndex.lookupImageURL(name: name, aliases: derivedAliases),
                videoURL: video,
                instructions: mergedInstructions ?? FreeExerciseDBIndex.lookupInstructions(name: name, aliases: item.aliases ?? [], language: RepsLocalization.language),
                notes: item.description,
                sourceName: "exercises-dataset"
            )
        }
        return uniqueExercises(SeedData.exercises + bundled)
    }
    static let bench = Exercise(name: "Barbell Bench Press", muscleGroup: "Chest", equipment: "Barbell")
    static let incline = Exercise(name: "Incline Dumbbell Press", muscleGroup: "Chest", equipment: "Dumbbells")
    static let overhead = Exercise(name: "Overhead Press", muscleGroup: "Shoulders", equipment: "Barbell")
    static let deadlift = Exercise(name: "Barbell Deadlift", muscleGroup: "Back", equipment: "Barbell")
    static let squat = Exercise(name: "Barbell Squat", muscleGroup: "Legs", equipment: "Barbell")
    static let row = Exercise(name: "Dumbbell Row", muscleGroup: "Back", equipment: "Dumbbells")
    static let pushup = Exercise(name: "Push-up", muscleGroup: "Chest", equipment: "Bodyweight", trackingType: .repsOnly)
    static let plank = Exercise(name: "Plank", muscleGroup: "Core", equipment: "Bodyweight", trackingType: .duration)
    static let lunge = Exercise(name: "Walking Lunge", muscleGroup: "Legs", equipment: "Dumbbells")
    static let pullup = Exercise(name: "Pull-up", muscleGroup: "Back", equipment: "Bodyweight", trackingType: .repsOnly)
    static let invertedRow = Exercise(name: "Inverted Row", muscleGroup: "Back", equipment: "Bodyweight", trackingType: .repsOnly)
    static let gobletSquat = Exercise(name: "Goblet Squat", muscleGroup: "Legs", equipment: "Dumbbells")
    static let romanianDeadlift = Exercise(name: "Romanian Deadlift", muscleGroup: "Legs", equipment: "Dumbbells")
    static let hipThrust = Exercise(name: "Hip Thrust", muscleGroup: "Glutes", equipment: "Bodyweight", trackingType: .repsOnly)
    static let bandRow = Exercise(name: "Band Row", muscleGroup: "Back", equipment: "Resistance Band")
    static let bandFacePull = Exercise(name: "Band Face Pull", muscleGroup: "Shoulders", equipment: "Resistance Band")
    static let floorPress = Exercise(name: "Dumbbell Floor Press", muscleGroup: "Chest", equipment: "Dumbbells")
    static let lateralRaise = Exercise(name: "Lateral Raise", muscleGroup: "Shoulders", equipment: "Dumbbells")
    static let curl = Exercise(name: "Dumbbell Curl", muscleGroup: "Arms", equipment: "Dumbbells")
    static let tricepsExtension = Exercise(name: "Overhead Triceps Extension", muscleGroup: "Arms", equipment: "Dumbbells")
    static let splitSquat = Exercise(
        name: "Bulgarian Split Squat",
        aliases: ["Split Squat with Dumbbells", "Split Squats"],
        muscleGroup: "Legs",
        equipment: "Dumbbells"
    )
    static let calfRaise = Exercise(name: "Standing Calf Raise", muscleGroup: "Legs", equipment: "Bodyweight", trackingType: .repsOnly)
    static let mountainClimber = Exercise(name: "Mountain Climber", muscleGroup: "Core", equipment: "Bodyweight", trackingType: .duration)
    static let kettlebellSwing = Exercise(name: "Kettlebell Swing", muscleGroup: "Full Body", equipment: "Kettlebell")
    static let bike = Exercise(name: "Stationary Bike", muscleGroup: "Cardio", equipment: "Cardio Machine", trackingType: .duration)
    static let treadmill = Exercise(name: "Treadmill Run", muscleGroup: "Cardio", equipment: "Cardio Machine", trackingType: .duration)
    static let rower = Exercise(name: "Rowing Machine", muscleGroup: "Cardio", equipment: "Cardio Machine", trackingType: .duration)

    private static let coreExercises = [
        bench, incline, overhead, deadlift, squat, row, pushup, plank, lunge,
        pullup, invertedRow, gobletSquat, romanianDeadlift, hipThrust, bandRow,
        bandFacePull, floorPress, lateralRaise, curl, tricepsExtension, splitSquat,
        calfRaise, mountainClimber, kettlebellSwing, bike, treadmill, rower
    ]

    static let exercises = uniqueExercises(coreExercises + expandedCatalogExercises)

    static let pushDay = WorkoutDay(
        title: "Push Day",
        subtitle: "Upper Body & Core",
        durationMinutes: 45,
        exercises: [
            WorkoutExercise(exercise: bench, targetSets: 4, repRange: "8-10", previous: "60kg x 10"),
            WorkoutExercise(exercise: incline, targetSets: 3, repRange: "10-12", previous: "24kg x 12"),
            WorkoutExercise(exercise: overhead, targetSets: 3, repRange: "8-12", previous: "42.5kg x 8")
        ]
    )

    static let pullDay = WorkoutDay(
        title: "Pull Day",
        subtitle: "Back & Biceps",
        durationMinutes: 50,
        exercises: [
            WorkoutExercise(exercise: deadlift, targetSets: 3, repRange: "5-8", previous: "110kg x 5"),
            WorkoutExercise(exercise: row, targetSets: 3, repRange: "8-12", previous: "34kg x 10"),
            WorkoutExercise(exercise: pullup, targetSets: 3, repRange: "6-10", previous: "Bodyweight x 8"),
            WorkoutExercise(exercise: curl, targetSets: 2, repRange: "10-15", previous: "14kg x 12")
        ]
    )

    static let legDay = WorkoutDay(
        title: "Leg Day",
        subtitle: "Lower Body",
        durationMinutes: 55,
        exercises: [
            WorkoutExercise(exercise: squat, targetSets: 4, repRange: "8-10", previous: "95kg x 8"),
            WorkoutExercise(exercise: romanianDeadlift, targetSets: 3, repRange: "8-10", previous: "70kg x 8"),
            WorkoutExercise(exercise: lunge, targetSets: 3, repRange: "10-12", previous: "20kg x 10"),
            WorkoutExercise(exercise: calfRaise, targetSets: 2, repRange: "12-20", previous: "Bodyweight x 18")
        ]
    )

    static let homeA = WorkoutDay(
        title: "Home Full Body A",
        subtitle: "Dumbbells, bands & bodyweight",
        durationMinutes: 38,
        exercises: [
            WorkoutExercise(exercise: floorPress, targetSets: 3, repRange: "8-12", previous: "22kg x 10"),
            WorkoutExercise(exercise: gobletSquat, targetSets: 3, repRange: "10-15", previous: "28kg x 12"),
            WorkoutExercise(exercise: bandRow, targetSets: 3, repRange: "12-15", previous: "Band x 15"),
            WorkoutExercise(exercise: plank, targetSets: 3, repRange: "30-45 sec", previous: "40 sec")
        ]
    )

    static let homeB = WorkoutDay(
        title: "Home Full Body B",
        subtitle: "Limited equipment strength",
        durationMinutes: 42,
        exercises: [
            WorkoutExercise(exercise: splitSquat, targetSets: 3, repRange: "8-12", previous: "18kg x 10"),
            WorkoutExercise(exercise: pushup, targetSets: 3, repRange: "8-15", previous: "Bodyweight x 12"),
            WorkoutExercise(exercise: bandFacePull, targetSets: 3, repRange: "12-20", previous: "Band x 18"),
            WorkoutExercise(exercise: mountainClimber, targetSets: 3, repRange: "30-45 sec", previous: "35 sec")
        ]
    )

    static let pushPullLegsPlan = WorkoutPlan(
        name: "Push Pull Legs",
        location: .gym,
        daysPerWeek: 4,
        currentWeek: 3,
        totalWeeks: 8,
        completion: 0.45,
        days: [pushDay, pullDay, legDay]
    )

    static let homeStrengthPlan = WorkoutPlan(
        name: "Home Strength",
        location: .home,
        daysPerWeek: 4,
        currentWeek: 1,
        totalWeeks: 6,
        completion: 0.12,
        days: [homeA, homeB]
    )

    static let beginnerFullBodyPlan = WorkoutPlan(
        name: "Beginner Full Body",
        location: .both,
        daysPerWeek: 3,
        currentWeek: 1,
        totalWeeks: 8,
        completion: 0.08,
        days: [homeA, legDay]
    )

    static let fullBodyBeginner3DayPlan = WorkoutPlan(
        name: "Full Body Beginner 3-Day",
        location: .both,
        daysPerWeek: 3,
        currentWeek: 1,
        totalWeeks: 8,
        completion: 0,
        days: [
            programDay("Full Body A", subtitle: "Squat, push and pull basics", durationMinutes: 45, [
                item("Goblet Squat", sets: 3, reps: "8-12", rest: 90, priority: .primary, progression: .doubleProgression),
                item("Dumbbell Bench Press", sets: 3, reps: "8-12", rest: 90, priority: .primary, progression: .doubleProgression),
                item("Seated Cable Row", sets: 3, reps: "10-12", rest: 90, progression: .doubleProgression),
                item("Dumbbell Romanian Deadlift", sets: 2, reps: "10-12", rest: 90, progression: .doubleProgression),
                item("Plank", sets: 3, reps: "30-45 sec", rest: 45)
            ]),
            programDay("Full Body B", subtitle: "Hinge, vertical push and legs", durationMinutes: 45, [
                item("Barbell Squat", sets: 3, reps: "6-10", rest: 120, priority: .primary, progression: .doubleProgression),
                item("Lat Pulldown", sets: 3, reps: "8-12", rest: 90, priority: .primary, progression: .doubleProgression),
                item("Dumbbell Shoulder Press", sets: 3, reps: "8-12", rest: 90, progression: .doubleProgression),
                item("Reverse Lunge", sets: 2, reps: "10-12", rest: 75, progression: .doubleProgression),
                item("Dead Bug", sets: 3, reps: "8-12", rest: 45)
            ]),
            programDay("Full Body C", subtitle: "Practice, volume and balance", durationMinutes: 42, [
                item("Leg Press", sets: 3, reps: "10-15", rest: 90, priority: .primary, progression: .doubleProgression),
                item("Push-up", sets: 3, reps: "8-15", rest: 75, progression: .doubleProgression),
                item("Chest Supported Dumbbell Row", sets: 3, reps: "10-12", rest: 90, progression: .doubleProgression),
                item("Hip Thrust", sets: 3, reps: "10-15", rest: 90, progression: .doubleProgression),
                item("Side Plank", sets: 2, reps: "30-45 sec", rest: 45)
            ])
        ]
    )

    static let upperLower4DayPlan = WorkoutPlan(
        name: "Upper Lower 4-Day",
        location: .gym,
        daysPerWeek: 4,
        currentWeek: 1,
        totalWeeks: 8,
        completion: 0,
        days: [
            programDay("Upper Strength", subtitle: "Heavy press and row", durationMinutes: 55, [
                item("Barbell Bench Press", sets: 4, reps: "5-8", rest: 150, priority: .primary, progression: .linear),
                item("Barbell Row", sets: 4, reps: "6-8", rest: 120, priority: .primary, progression: .linear),
                item("Overhead Press", sets: 3, reps: "6-8", rest: 120, progression: .linear),
                item("Lat Pulldown", sets: 3, reps: "8-10", rest: 90, progression: .doubleProgression),
                item("Triceps Pushdown", sets: 2, reps: "10-15", rest: 60),
                item("Cable Curl", sets: 2, reps: "10-15", rest: 60)
            ]),
            programDay("Lower Strength", subtitle: "Squat and hinge focus", durationMinutes: 60, [
                item("Barbell Squat", sets: 4, reps: "5-8", rest: 180, priority: .primary, progression: .linear),
                item("Romanian Deadlift", sets: 3, reps: "6-10", rest: 150, priority: .primary, progression: .doubleProgression),
                item("Leg Press", sets: 3, reps: "10-12", rest: 120, progression: .doubleProgression),
                item("Seated Leg Curl", sets: 3, reps: "10-15", rest: 75),
                item("Standing Calf Raise Machine", sets: 3, reps: "12-20", rest: 60)
            ]),
            programDay("Upper Hypertrophy", subtitle: "Volume for chest, back and delts", durationMinutes: 55, [
                item("Incline Dumbbell Press", sets: 3, reps: "8-12", rest: 90, progression: .doubleProgression),
                item("Seated Cable Row", sets: 3, reps: "10-12", rest: 90, progression: .doubleProgression),
                item("Cable Lateral Raise", sets: 3, reps: "12-20", rest: 60),
                item("Cable Chest Fly", sets: 3, reps: "12-15", rest: 60),
                item("Face Pull", sets: 3, reps: "12-20", rest: 60),
                item("Hammer Curl", sets: 2, reps: "10-15", rest: 60)
            ]),
            programDay("Lower Hypertrophy", subtitle: "Leg volume and glutes", durationMinutes: 55, [
                item("Hack Squat", sets: 3, reps: "8-12", rest: 120, progression: .doubleProgression),
                item("Barbell Hip Thrust", sets: 4, reps: "8-12", rest: 120, priority: .primary, progression: .doubleProgression),
                item("Leg Extension", sets: 3, reps: "12-15", rest: 60),
                item("Lying Leg Curl", sets: 3, reps: "12-15", rest: 60),
                item("Hip Abduction Machine", sets: 3, reps: "15-20", rest: 45),
                item("Cable Crunch", sets: 3, reps: "10-15", rest: 60)
            ])
        ]
    )

    static let ppl3DayPlan = WorkoutPlan(
        name: "Push Pull Legs 3-Day",
        location: .gym,
        daysPerWeek: 3,
        currentWeek: 1,
        totalWeeks: 8,
        completion: 0,
        days: [programPushDay(name: "Push 3-Day"), programPullDay(name: "Pull 3-Day"), programLegDay(name: "Legs 3-Day")]
    )

    static let ppl6DayPlan = WorkoutPlan(
        name: "Push Pull Legs 6-Day",
        location: .gym,
        daysPerWeek: 6,
        currentWeek: 1,
        totalWeeks: 10,
        completion: 0,
        days: [
            programPushDay(name: "Push A"),
            programPullDay(name: "Pull A"),
            programLegDay(name: "Legs A"),
            programDay("Push B", subtitle: "Hypertrophy push volume", durationMinutes: 55, [
                item("Incline Dumbbell Press", sets: 4, reps: "8-12", rest: 90, progression: .doubleProgression),
                item("Machine Chest Press", sets: 3, reps: "10-12", rest: 90),
                item("Arnold Press", sets: 3, reps: "8-12", rest: 90),
                item("Cable Lateral Raise", sets: 4, reps: "12-20", rest: 45),
                item("Overhead Cable Triceps Extension", sets: 3, reps: "10-15", rest: 60)
            ]),
            programDay("Pull B", subtitle: "Back width and arms", durationMinutes: 55, [
                item("Wide Grip Lat Pulldown", sets: 4, reps: "8-12", rest: 90),
                item("Chest Supported Dumbbell Row", sets: 3, reps: "10-12", rest: 90),
                item("Straight Arm Pulldown", sets: 3, reps: "12-15", rest: 60),
                item("Cable Rear Delt Fly", sets: 3, reps: "12-20", rest: 45),
                item("Incline Dumbbell Curl", sets: 3, reps: "10-15", rest: 60)
            ]),
            programDay("Legs B", subtitle: "Quad and glute volume", durationMinutes: 60, [
                item("Leg Press", sets: 4, reps: "10-15", rest: 120),
                item("Dumbbell Romanian Deadlift", sets: 3, reps: "8-12", rest: 120),
                item("Bulgarian Split Squat", sets: 3, reps: "8-12", rest: 90),
                item("Leg Extension", sets: 3, reps: "12-15", rest: 60),
                item("Seated Calf Raise", sets: 4, reps: "12-20", rest: 45)
            ])
        ]
    )

    static let dumbbellHomePlan = WorkoutPlan(
        name: "Home Dumbbell 4-Day",
        location: .home,
        daysPerWeek: 4,
        currentWeek: 1,
        totalWeeks: 8,
        completion: 0,
        days: [
            programDay("Home Upper A", subtitle: "Dumbbell push and pull", durationMinutes: 42, [
                item("Dumbbell Floor Press", sets: 4, reps: "8-12", rest: 90),
                item("Single Arm Dumbbell Row", sets: 4, reps: "8-12", rest: 90),
                item("Dumbbell Shoulder Press", sets: 3, reps: "8-12", rest: 90),
                item("Lateral Raise", sets: 3, reps: "12-20", rest: 45),
                item("Hammer Curl", sets: 2, reps: "10-15", rest: 60)
            ]),
            programDay("Home Lower A", subtitle: "Squat and hinge with dumbbells", durationMinutes: 42, [
                item("Goblet Squat", sets: 4, reps: "10-15", rest: 90),
                item("Dumbbell Romanian Deadlift", sets: 4, reps: "8-12", rest: 90),
                item("Reverse Lunge", sets: 3, reps: "10-12", rest: 75),
                item("Dumbbell Calf Raise", sets: 3, reps: "12-20", rest: 45),
                item("Dead Bug", sets: 3, reps: "8-12", rest: 45)
            ]),
            programDay("Home Upper B", subtitle: "Incline, rows and arms", durationMinutes: 42, [
                item("Incline Dumbbell Press", sets: 3, reps: "8-12", rest: 90),
                item("Chest Supported Dumbbell Row", sets: 3, reps: "10-12", rest: 90),
                item("Dumbbell Pullover", sets: 3, reps: "10-12", rest: 75),
                item("Rear Delt Fly", sets: 3, reps: "12-20", rest: 45),
                item("Overhead Triceps Extension", sets: 2, reps: "10-15", rest: 60)
            ]),
            programDay("Home Lower B", subtitle: "Unilateral lower body", durationMinutes: 40, [
                item("Bulgarian Split Squat", sets: 4, reps: "8-12", rest: 90),
                item("Dumbbell Hip Thrust", sets: 4, reps: "10-15", rest: 90),
                item("Dumbbell Step-up", sets: 3, reps: "10-12", rest: 75),
                item("Dumbbell Sumo Squat", sets: 3, reps: "10-15", rest: 75),
                item("Side Plank", sets: 2, reps: "30-45 sec", rest: 45)
            ])
        ]
    )

    static let noEquipmentHomePlan = WorkoutPlan(
        name: "Home No Equipment 3-Day",
        location: .home,
        daysPerWeek: 3,
        currentWeek: 1,
        totalWeeks: 6,
        completion: 0,
        days: [
            programDay("Bodyweight Strength A", subtitle: "Push, legs and core", durationMinutes: 32, [
                item("Push-up", sets: 4, reps: "8-15", rest: 75),
                item("Bodyweight Reverse Lunge", sets: 3, reps: "10-15", rest: 60),
                item("Glute Bridge", sets: 3, reps: "12-20", rest: 60),
                item("Plank", sets: 3, reps: "30-60 sec", rest: 45),
                item("Scapular Push-up", sets: 2, reps: "10-15", rest: 45)
            ]),
            programDay("Bodyweight Strength B", subtitle: "Legs and trunk", durationMinutes: 34, [
                item("Wall Sit", sets: 3, reps: "30-60 sec", rest: 60),
                item("Single Leg Glute Bridge", sets: 3, reps: "8-12", rest: 60),
                item("Decline Push-up", sets: 3, reps: "6-12", rest: 75),
                item("Mountain Climber", sets: 3, reps: "30-45 sec", rest: 45),
                item("Bird Dog", sets: 3, reps: "8-12", rest: 45)
            ]),
            programDay("Bodyweight Conditioning", subtitle: "Low equipment cardio and mobility", durationMinutes: 30, [
                item("Burpee", sets: 4, reps: "30 sec", rest: 45),
                item("Jump Squat", sets: 3, reps: "10-15", rest: 45),
                item("High Knees", sets: 4, reps: "30 sec", rest: 30),
                item("World's Greatest Stretch", sets: 2, reps: "45 sec", rest: 30),
                item("Side Plank", sets: 2, reps: "30 sec", rest: 30)
            ], sessionType: .mixedRoute)
        ]
    )

    static let strength5x5Plan = WorkoutPlan(
        name: "Strength 5x5",
        location: .gym,
        daysPerWeek: 3,
        currentWeek: 1,
        totalWeeks: 12,
        completion: 0,
        days: [
            programDay("5x5 A", subtitle: "Squat, bench and row", durationMinutes: 60, [
                item("Barbell Squat", sets: 5, reps: "5", rest: 180, priority: .primary, progression: .linear),
                item("Barbell Bench Press", sets: 5, reps: "5", rest: 180, priority: .primary, progression: .linear),
                item("Barbell Row", sets: 5, reps: "5", rest: 150, priority: .primary, progression: .linear),
                item("Plank", sets: 3, reps: "45 sec", rest: 60)
            ]),
            programDay("5x5 B", subtitle: "Squat, press and deadlift", durationMinutes: 60, [
                item("Barbell Squat", sets: 5, reps: "5", rest: 180, priority: .primary, progression: .linear),
                item("Overhead Press", sets: 5, reps: "5", rest: 150, priority: .primary, progression: .linear),
                item("Barbell Deadlift", sets: 1, reps: "5", rest: 180, priority: .primary, progression: .linear),
                item("Chin-up", sets: 3, reps: "6-10", rest: 90)
            ])
        ]
    )

    static let hypertrophy8WeekPlan = WorkoutPlan(
        name: "Hypertrophy 8-Week",
        location: .gym,
        daysPerWeek: 5,
        currentWeek: 1,
        totalWeeks: 8,
        completion: 0,
        days: [
            programPushDay(name: "Chest and Delts"),
            programPullDay(name: "Back and Biceps"),
            programLegDay(name: "Legs and Glutes"),
            programDay("Upper Pump", subtitle: "Higher rep upper body volume", durationMinutes: 50, [
                item("Machine Chest Press", sets: 3, reps: "10-15", rest: 75),
                item("Lat Pulldown", sets: 3, reps: "10-15", rest: 75),
                item("Pec Deck Fly", sets: 3, reps: "12-20", rest: 60),
                item("Cable Rear Delt Fly", sets: 3, reps: "12-20", rest: 45),
                item("Rope Hammer Curl", sets: 3, reps: "12-15", rest: 45),
                item("Rope Triceps Pushdown", sets: 3, reps: "12-15", rest: 45)
            ]),
            programDay("Lower Pump", subtitle: "Machines and high-quality reps", durationMinutes: 50, [
                item("Leg Press", sets: 4, reps: "12-15", rest: 90),
                item("Seated Leg Curl", sets: 3, reps: "12-20", rest: 60),
                item("Leg Extension", sets: 3, reps: "12-20", rest: 60),
                item("Hip Abduction Machine", sets: 3, reps: "15-25", rest: 45),
                item("Seated Calf Raise", sets: 4, reps: "12-20", rest: 45)
            ])
        ]
    )

    static let glutesLegsPlan = WorkoutPlan(
        name: "Glutes & Legs Focus",
        location: .both,
        daysPerWeek: 4,
        currentWeek: 1,
        totalWeeks: 8,
        completion: 0,
        days: [
            programDay("Glute Strength", subtitle: "Hip thrust and hinge", durationMinutes: 55, [
                item("Barbell Hip Thrust", sets: 5, reps: "6-10", rest: 150, priority: .primary, progression: .doubleProgression),
                item("Romanian Deadlift", sets: 4, reps: "8-10", rest: 120),
                item("Bulgarian Split Squat", sets: 3, reps: "8-12", rest: 90),
                item("Hip Abduction Machine", sets: 3, reps: "15-25", rest: 45)
            ]),
            programDay("Quad Strength", subtitle: "Squat and press", durationMinutes: 55, [
                item("Barbell Squat", sets: 4, reps: "5-8", rest: 150, priority: .primary, progression: .linear),
                item("Leg Press", sets: 4, reps: "10-12", rest: 120),
                item("Leg Extension", sets: 3, reps: "12-15", rest: 60),
                item("Standing Calf Raise Machine", sets: 4, reps: "12-20", rest: 45)
            ]),
            programDay("Glute Volume", subtitle: "Unilateral and pump work", durationMinutes: 48, [
                item("Dumbbell Hip Thrust", sets: 4, reps: "10-15", rest: 90),
                item("Walking Lunge", sets: 3, reps: "10-12", rest: 75),
                item("Glute Kickback Machine", sets: 3, reps: "12-20", rest: 60),
                item("Frog Pump", sets: 3, reps: "20-30", rest: 45)
            ]),
            programDay("Lower Conditioning", subtitle: "Legs, core and mobility", durationMinutes: 38, [
                item("Goblet Squat", sets: 3, reps: "12-15", rest: 75),
                item("Step Touch", sets: 4, reps: "45 sec", rest: 30),
                item("Wall Sit", sets: 3, reps: "45 sec", rest: 45),
                item("Pigeon Stretch", sets: 2, reps: "45 sec", rest: 30),
                item("Couch Stretch", sets: 2, reps: "45 sec", rest: 30)
            ])
        ]
    )

    static let express30Plan = WorkoutPlan(
        name: "Express 30-Minute Strength",
        location: .both,
        daysPerWeek: 4,
        currentWeek: 1,
        totalWeeks: 6,
        completion: 0,
        days: [
            programDay("Express Push", subtitle: "Fast upper push", durationMinutes: 30, [
                item("Dumbbell Bench Press", sets: 3, reps: "8-12", rest: 60),
                item("Dumbbell Shoulder Press", sets: 3, reps: "8-12", rest: 60),
                item("Lateral Raise", sets: 2, reps: "12-20", rest: 45),
                item("Triceps Pushdown", sets: 2, reps: "10-15", rest: 45)
            ]),
            programDay("Express Pull", subtitle: "Fast back and biceps", durationMinutes: 30, [
                item("Lat Pulldown", sets: 3, reps: "8-12", rest: 60),
                item("Dumbbell Row", sets: 3, reps: "8-12", rest: 60),
                item("Face Pull", sets: 2, reps: "12-20", rest: 45),
                item("Hammer Curl", sets: 2, reps: "10-15", rest: 45)
            ]),
            programDay("Express Legs", subtitle: "Fast lower body", durationMinutes: 30, [
                item("Goblet Squat", sets: 3, reps: "10-15", rest: 60),
                item("Dumbbell Romanian Deadlift", sets: 3, reps: "8-12", rest: 60),
                item("Reverse Lunge", sets: 2, reps: "10-12", rest: 45),
                item("Plank", sets: 2, reps: "45 sec", rest: 30)
            ]),
            programDay("Express Conditioning", subtitle: "Strength and cardio blend", durationMinutes: 30, [
                item("Kettlebell Swing", sets: 4, reps: "12-20", rest: 45),
                item("Push-up", sets: 3, reps: "8-15", rest: 45),
                item("Mountain Climber", sets: 4, reps: "30 sec", rest: 30),
                item("Dead Bug", sets: 2, reps: "10-12", rest: 30)
            ], sessionType: .mixedRoute)
        ]
    )

    static let defaultPlans = [
        pushPullLegsPlan,
        homeStrengthPlan,
        beginnerFullBodyPlan,
        fullBodyBeginner3DayPlan,
        upperLower4DayPlan,
        ppl3DayPlan,
        ppl6DayPlan,
        dumbbellHomePlan,
        noEquipmentHomePlan,
        strength5x5Plan,
        hypertrophy8WeekPlan,
        glutesLegsPlan,
        express30Plan
    ]

    static let workoutTemplates = [
        pushDay, pullDay, legDay, homeA, homeB,
        fullBodyBeginner3DayPlan.days[0],
        upperLower4DayPlan.days[0],
        strength5x5Plan.days[0],
        express30Plan.days[0]
    ] + hyroxTemplates

    // MARK: - HYROX templates
    //
    // HYROX is a fixed-format fitness race: 8 × 1 km runs, each followed by a
    // functional station (SkiErg 1000 m, Sled Push 50 m, Sled Pull 50 m,
    // Burpee Broad Jump 80 m, Row 1000 m, Farmers Carry 200 m, Sandbag Lunges
    // 100 m, Wall Balls 100 reps). The block below mirrors how coaches program
    // for it: a polarized aerobic base, two functional-strength days, a
    // "compromised running" session (running on fatigued legs), a race
    // simulation, and a taper session for race week.
    static let hyroxTemplates: [WorkoutDay] = [
        hyroxBaseRun, hyroxRunIntervals, hyroxStrengthA, hyroxStrengthB,
        hyroxCompromisedRunning, hyroxRaceSimulation, hyroxTaper
    ]

    private static let hyroxBaseRun = programDay(
        localizedString("hyrox_base_run_title"),
        subtitle: localizedString("hyrox_base_run_subtitle"),
        durationMinutes: 45,
        [
            station("Running", sets: 1, reps: "45 min", rest: 0, priority: .primary)
        ],
        sessionType: .cardioRun
    )

    private static let hyroxRunIntervals = programDay(
        localizedString("hyrox_run_intervals_title"),
        subtitle: localizedString("hyrox_run_intervals_subtitle"),
        durationMinutes: 45,
        [
            station("Running", sets: 6, reps: "1000 m", rest: 90, priority: .primary)
        ],
        sessionType: .cardioRun
    )

    private static let hyroxStrengthA = programDay(
        localizedString("hyrox_strength_a_title"),
        subtitle: localizedString("hyrox_strength_a_subtitle"),
        durationMinutes: 60,
        [
            item("Barbell Squat", sets: 4, reps: "6-10", rest: 150, priority: .primary, progression: .doubleProgression),
            station("Sled Push", sets: 5, reps: "50 m", rest: 120, priority: .primary),
            station("Wall Ball", sets: 4, reps: "25 reps", rest: 60),
            station("SkiErg", sets: 4, reps: "250 m", rest: 60),
            station("Walking Lunge", sets: 3, reps: "20 m", rest: 75),
            station("Plank", sets: 3, reps: "45 s", rest: 45)
        ]
    )

    private static let hyroxStrengthB = programDay(
        localizedString("hyrox_strength_b_title"),
        subtitle: localizedString("hyrox_strength_b_subtitle"),
        durationMinutes: 60,
        [
            item("Romanian Deadlift", sets: 4, reps: "6-10", rest: 150, priority: .primary, progression: .doubleProgression),
            station("Sled Pull", sets: 5, reps: "50 m", rest: 120, priority: .primary),
            item("Pull Up", sets: 4, reps: "6-10", rest: 90, priority: .primary, progression: .doubleProgression),
            station("Farmer Carry", sets: 4, reps: "100 m", rest: 75),
            station("Rowing Machine", sets: 4, reps: "500 m", rest: 60),
            station("Sandbag Lunge", sets: 3, reps: "50 m", rest: 75)
        ]
    )

    private static let hyroxCompromisedRunning = programDay(
        localizedString("hyrox_compromised_running_title"),
        subtitle: localizedString("hyrox_compromised_running_subtitle"),
        durationMinutes: 50,
        [
            station("Running", sets: 8, reps: "400 m", rest: 30, priority: .primary),
            station("Wall Ball", sets: 4, reps: "25 reps", rest: 30),
            station("Burpee Broad Jump", sets: 4, reps: "40 m", rest: 30),
            station("Sled Push", sets: 4, reps: "25 m", rest: 30)
        ],
        sessionType: .mixedRoute
    )

    private static let hyroxRaceSimulation = programDay(
        localizedString("hyrox_race_simulation_title"),
        subtitle: localizedString("hyrox_race_simulation_subtitle"),
        durationMinutes: 75,
        [
            station("Running", sets: 8, reps: "1000 m", rest: 0, priority: .primary),
            station("SkiErg", sets: 1, reps: "1000 m", rest: 0),
            station("Sled Push", sets: 1, reps: "50 m", rest: 0),
            station("Sled Pull", sets: 1, reps: "50 m", rest: 0),
            station("Burpee Broad Jump", sets: 1, reps: "80 m", rest: 0),
            station("Rowing Machine", sets: 1, reps: "1000 m", rest: 0),
            station("Farmer Carry", sets: 1, reps: "200 m", rest: 0),
            station("Sandbag Lunge", sets: 1, reps: "100 m", rest: 0),
            station("Wall Ball", sets: 1, reps: "100 reps", rest: 0)
        ],
        sessionType: .mixedRoute
    )

    private static let hyroxTaper = programDay(
        localizedString("hyrox_taper_title"),
        subtitle: localizedString("hyrox_taper_subtitle"),
        durationMinutes: 35,
        [
            station("Running", sets: 3, reps: "1000 m", rest: 120, priority: .primary),
            station("Wall Ball", sets: 2, reps: "20 reps", rest: 60),
            station("Sled Push", sets: 2, reps: "25 m", rest: 90),
            station("Plank", sets: 2, reps: "30 s", rest: 45)
        ],
        sessionType: .mixedRoute
    )

    /// Station/interval item: distance- or time-based, no load progression.
    private static func station(
        _ name: String,
        sets: Int,
        reps: String,
        rest: Int,
        priority: WorkoutExercise.Priority = .secondary
    ) -> WorkoutExercise {
        WorkoutExercise(
            exercise: exercise(named: name),
            targetSets: sets,
            repRange: reps,
            previous: "-",
            restSeconds: rest,
            priority: priority,
            progressionType: .none,
            incrementKg: 0
        )
    }

    private static func programPushDay(name: String) -> WorkoutDay {
        programDay(name, subtitle: "Chest, shoulders and triceps", durationMinutes: 55, [
            item("Barbell Bench Press", sets: 4, reps: "6-10", rest: 150, priority: .primary, progression: .doubleProgression),
            item("Incline Dumbbell Press", sets: 3, reps: "8-12", rest: 90, progression: .doubleProgression),
            item("Overhead Press", sets: 3, reps: "6-10", rest: 120, priority: .primary, progression: .linear),
            item("Cable Lateral Raise", sets: 3, reps: "12-20", rest: 45),
            item("Triceps Pushdown", sets: 3, reps: "10-15", rest: 60),
            item("Cable Chest Fly", sets: 2, reps: "12-15", rest: 60)
        ])
    }

    private static func programPullDay(name: String) -> WorkoutDay {
        programDay(name, subtitle: "Back, rear delts and biceps", durationMinutes: 55, [
            item("Barbell Deadlift", sets: 3, reps: "3-6", rest: 180, priority: .primary, progression: .linear),
            item("Lat Pulldown", sets: 4, reps: "8-12", rest: 90, progression: .doubleProgression),
            item("Seated Cable Row", sets: 3, reps: "8-12", rest: 90, progression: .doubleProgression),
            item("Face Pull", sets: 3, reps: "12-20", rest: 45),
            item("Dumbbell Curl", sets: 3, reps: "10-15", rest: 60)
        ])
    }

    private static func programLegDay(name: String) -> WorkoutDay {
        programDay(name, subtitle: "Squat, hinge and calves", durationMinutes: 60, [
            item("Barbell Squat", sets: 4, reps: "6-10", rest: 150, priority: .primary, progression: .doubleProgression),
            item("Romanian Deadlift", sets: 3, reps: "8-10", rest: 120, priority: .primary, progression: .doubleProgression),
            item("Leg Press", sets: 3, reps: "10-15", rest: 120),
            item("Seated Leg Curl", sets: 3, reps: "10-15", rest: 75),
            item("Standing Calf Raise Machine", sets: 4, reps: "12-20", rest: 45),
            item("Cable Crunch", sets: 3, reps: "10-15", rest: 60)
        ])
    }

    private static func programDay(
        _ title: String,
        subtitle: String,
        durationMinutes: Int,
        _ exercises: [WorkoutExercise],
        sessionType: WorkoutDay.SessionType = .strength
    ) -> WorkoutDay {
        WorkoutDay(
            title: title,
            subtitle: subtitle,
            durationMinutes: durationMinutes,
            exercises: exercises,
            sessionType: sessionType
        )
    }

    private static func item(
        _ exerciseName: String,
        sets: Int,
        reps: String,
        rest: Int,
        priority: WorkoutExercise.Priority = .secondary,
        progression: WorkoutExercise.ProgressionType = .doubleProgression
    ) -> WorkoutExercise {
        WorkoutExercise(
            exercise: exercise(named: exerciseName),
            targetSets: sets,
            repRange: reps,
            previous: "-",
            restSeconds: rest,
            priority: priority,
            progressionType: progression,
            targetRPE: priority == .primary ? 8 : nil,
            targetRIR: priority == .primary ? 2 : nil,
            incrementKg: 2.5
        )
    }

    private static func exercise(named name: String) -> Exercise {
        exercises.first { $0.name.caseInsensitiveCompare(name) == .orderedSame }
            ?? Exercise(
                name: name,
                muscleGroup: inferredMuscleGroup(for: name),
                equipment: inferredEquipment(for: name),
                requiredEquipment: [inferredEquipment(for: name)],
                exerciseType: inferredExerciseType(for: name),
                sourceName: "StreakReps seed catalog",
                sourceLicense: "Internal generated catalog"
            )
    }

    private static func inferredMuscleGroup(for name: String) -> String {
        let lower = name.lowercased()
        // HYROX-specific patterns first (avoid "sled push" mapping to chest, etc.)
        if lower.contains("sled") || lower.contains("wall ball") || lower.contains("wall-ball") { return "Legs" }
        if lower.contains("ski") { return "Back" }
        if lower.contains("run") || lower.contains("burpee") || lower.contains("carry") || lower.contains("farmer") { return "Full Body" }
        if lower.contains("squat") || lower.contains("lunge") || lower.contains("leg") || lower.contains("calf") { return "Legs" }
        if lower.contains("hip") || lower.contains("glute") { return "Glutes" }
        if lower.contains("row") || lower.contains("pull") || lower.contains("deadlift") || lower.contains("pulldown") { return "Back" }
        if lower.contains("press") || lower.contains("fly") || lower.contains("push") { return "Chest" }
        if lower.contains("curl") || lower.contains("triceps") { return "Arms" }
        if lower.contains("plank") || lower.contains("crunch") || lower.contains("dead bug") { return "Core" }
        return "Full Body"
    }

    private static func inferredEquipment(for name: String) -> String {
        let lower = name.lowercased()
        if lower.contains("sled") { return "Sled" }
        if lower.contains("ski") { return "Machine" }
        if lower.contains("wall ball") || lower.contains("medicine") { return "Medicine Ball" }
        if lower.contains("sandbag") { return "Sandbag" }
        if lower.contains("carry") || lower.contains("farmer") { return "Kettlebell" }
        if lower.contains("run") || lower.contains("burpee") || lower.contains("broad jump") { return "Bodyweight" }
        if lower.contains("barbell") { return "Barbell" }
        if lower.contains("dumbbell") { return "Dumbbells" }
        if lower.contains("cable") || lower.contains("pulldown") { return "Cable" }
        if lower.contains("machine") || lower.contains("leg press") || lower.contains("hack squat") { return "Machine" }
        if lower.contains("kettlebell") { return "Kettlebell" }
        return "Bodyweight"
    }

    private static func inferredExerciseType(for name: String) -> Exercise.ExerciseType {
        let lower = name.lowercased()
        if lower.contains("run") || lower.contains("ski") || lower.contains("erg")
            || lower.contains("rowing") || lower.contains("row machine") { return .cardio }
        if lower.contains("burpee") || lower.contains("broad jump") { return .hiit }
        return .strength
    }

    static let sessions: [WorkoutSession] = []
    static let goals: [Goal] = []
    static let scheduledWorkouts: [ScheduledWorkout] = []
    static let bodyMetrics: [BodyMetric] = []

    private struct ExerciseFamily {
        let muscleGroup: String
        let equipment: String
        let requiredEquipment: [String]
        let difficulty: Exercise.Difficulty
        let environment: Exercise.Environment
        let exerciseType: Exercise.ExerciseType
        let tags: [String]
        let names: [String]
    }

    private static var expandedCatalogExercises: [Exercise] {
        exerciseFamilies.flatMap { family in
            family.names.map { name in
                Exercise(
                    name: name,
                    aliases: aliases(for: name),
                    muscleGroup: family.muscleGroup,
                    secondaryMuscles: secondaryMuscles(for: family.muscleGroup),
                    equipment: family.equipment,
                    requiredEquipment: family.requiredEquipment,
                    trackingType: trackingType(for: family.exerciseType),
                    exerciseType: family.exerciseType,
                    difficulty: family.difficulty,
                    environment: family.environment,
                    tags: family.tags + patternTags(for: name),
                    instructions: instructions(for: name, muscleGroup: family.muscleGroup),
                    commonMistakes: commonMistakes(for: family.exerciseType),
                    sourceName: "StreakReps seed catalog",
                    sourceLicense: "Internal generated catalog"
                )
            }
        }
    }

    private static let exerciseFamilies: [ExerciseFamily] = [
        ExerciseFamily(muscleGroup: "Chest", equipment: "Barbell", requiredEquipment: ["Barbell", "Bench"], difficulty: .medium, environment: .gym, exerciseType: .strength, tags: ["push", "horizontal press"], names: [
            "Barbell Bench Press", "Close Grip Bench Press", "Paused Bench Press", "Wide Grip Bench Press", "Decline Barbell Bench Press", "Incline Barbell Bench Press", "Spoto Press", "Floor Press", "Pin Press", "Board Press"
        ]),
        ExerciseFamily(muscleGroup: "Chest", equipment: "Dumbbells", requiredEquipment: ["Dumbbells", "Bench"], difficulty: .medium, environment: .both, exerciseType: .strength, tags: ["push", "unilateral"], names: [
            "Dumbbell Bench Press", "Incline Dumbbell Press", "Decline Dumbbell Press", "Dumbbell Fly", "Incline Dumbbell Fly", "Dumbbell Pullover", "Neutral Grip Dumbbell Press", "Single Arm Dumbbell Bench Press", "Dumbbell Squeeze Press", "Dumbbell Floor Press", "Alternating Dumbbell Press", "Low Incline Dumbbell Press"
        ]),
        ExerciseFamily(muscleGroup: "Chest", equipment: "Cable", requiredEquipment: ["Cable"], difficulty: .medium, environment: .gym, exerciseType: .strength, tags: ["push", "isolation"], names: [
            "Cable Chest Fly", "Low Cable Fly", "High Cable Fly", "Single Arm Cable Press", "Cable Crossover", "Cable Incline Press", "Cable Decline Press", "Standing Cable Chest Press", "Cable Squeeze Press", "Cable Around The World"
        ]),
        ExerciseFamily(muscleGroup: "Chest", equipment: "Machine", requiredEquipment: ["Machine"], difficulty: .low, environment: .gym, exerciseType: .strength, tags: ["push", "machine"], names: [
            "Machine Chest Press", "Incline Machine Press", "Decline Machine Press", "Pec Deck Fly", "Seated Chest Fly Machine", "Hammer Strength Chest Press", "Smith Machine Bench Press", "Smith Machine Incline Press", "Assisted Chest Dip", "Machine Pullover"
        ]),
        ExerciseFamily(muscleGroup: "Chest", equipment: "Bodyweight", requiredEquipment: ["Bodyweight"], difficulty: .low, environment: .both, exerciseType: .strength, tags: ["push", "calisthenics"], names: [
            "Push-up", "Incline Push-up", "Decline Push-up", "Diamond Push-up", "Wide Push-up", "Archer Push-up", "Pike Push-up", "Deficit Push-up", "Ring Push-up", "Chest Dip"
        ]),
        ExerciseFamily(muscleGroup: "Back", equipment: "Barbell", requiredEquipment: ["Barbell"], difficulty: .medium, environment: .gym, exerciseType: .strength, tags: ["pull", "hinge"], names: [
            "Barbell Deadlift", "Romanian Deadlift", "Barbell Row", "Pendlay Row", "T-Bar Row", "Meadows Row", "Snatch Grip Deadlift", "Rack Pull", "Good Morning", "Seal Row", "Barbell Pullover", "Yates Row"
        ]),
        ExerciseFamily(muscleGroup: "Back", equipment: "Dumbbells", requiredEquipment: ["Dumbbells"], difficulty: .medium, environment: .both, exerciseType: .strength, tags: ["pull", "unilateral"], names: [
            "Dumbbell Row", "Chest Supported Dumbbell Row", "Single Arm Dumbbell Row", "Dumbbell Pullover", "Incline Dumbbell Row", "Renegade Row", "Dumbbell Romanian Deadlift", "Dumbbell Shrug", "Dumbbell Reverse Fly", "Prone Dumbbell Y Raise"
        ]),
        ExerciseFamily(muscleGroup: "Back", equipment: "Cable", requiredEquipment: ["Cable"], difficulty: .low, environment: .gym, exerciseType: .strength, tags: ["pull", "cable"], names: [
            "Lat Pulldown", "Close Grip Lat Pulldown", "Wide Grip Lat Pulldown", "Single Arm Lat Pulldown", "Straight Arm Pulldown", "Seated Cable Row", "Low Cable Row", "High Cable Row", "Face Pull", "Cable Pullover", "Cable Rear Delt Row", "Kneeling Cable Pulldown"
        ]),
        ExerciseFamily(muscleGroup: "Back", equipment: "Bodyweight", requiredEquipment: ["Bodyweight", "Pullup Bar"], difficulty: .medium, environment: .both, exerciseType: .strength, tags: ["pull", "calisthenics"], names: [
            "Pull-up", "Chin-up", "Neutral Grip Pull-up", "Wide Grip Pull-up", "Negative Pull-up", "Assisted Pull-up", "Inverted Row", "Ring Row", "Scapular Pull-up", "Dead Hang"
        ]),
        ExerciseFamily(muscleGroup: "Legs", equipment: "Barbell", requiredEquipment: ["Barbell", "Rack"], difficulty: .medium, environment: .gym, exerciseType: .strength, tags: ["squat", "hinge"], names: [
            "Barbell Squat", "Front Squat", "Paused Squat", "Box Squat", "Zercher Squat", "Barbell Lunge", "Barbell Reverse Lunge", "Barbell Hip Thrust", "Barbell Glute Bridge", "Barbell Calf Raise", "Barbell Split Squat", "Safety Bar Squat"
        ]),
        ExerciseFamily(muscleGroup: "Legs", equipment: "Dumbbells", requiredEquipment: ["Dumbbells"], difficulty: .medium, environment: .both, exerciseType: .strength, tags: ["squat", "unilateral"], names: [
            "Goblet Squat", "Dumbbell Squat", "Dumbbell Romanian Deadlift", "Walking Lunge", "Reverse Lunge", "Dumbbell Step-up", "Bulgarian Split Squat", "Dumbbell Calf Raise", "Dumbbell Hip Thrust", "Dumbbell Sumo Squat", "Dumbbell Cossack Squat", "Dumbbell Hamstring Curl"
        ]),
        ExerciseFamily(muscleGroup: "Legs", equipment: "Machine", requiredEquipment: ["Machine"], difficulty: .low, environment: .gym, exerciseType: .strength, tags: ["machine", "lower body"], names: [
            "Leg Press", "Hack Squat", "Leg Extension", "Seated Leg Curl", "Lying Leg Curl", "Standing Leg Curl", "Hip Abduction Machine", "Hip Adduction Machine", "Seated Calf Raise", "Standing Calf Raise Machine", "Smith Machine Squat", "Glute Kickback Machine"
        ]),
        ExerciseFamily(muscleGroup: "Glutes", equipment: "Bodyweight", requiredEquipment: ["Bodyweight"], difficulty: .low, environment: .home, exerciseType: .strength, tags: ["glutes", "home"], names: [
            "Glute Bridge", "Single Leg Glute Bridge", "Frog Pump", "Hip Thrust", "Donkey Kick", "Fire Hydrant", "Bodyweight Reverse Lunge", "Bodyweight Step-up", "Curtsy Lunge", "Wall Sit"
        ]),
        ExerciseFamily(muscleGroup: "Shoulders", equipment: "Barbell", requiredEquipment: ["Barbell"], difficulty: .medium, environment: .gym, exerciseType: .strength, tags: ["push", "overhead"], names: [
            "Overhead Press", "Push Press", "Behind The Neck Press", "Seated Barbell Press", "Bradford Press", "Landmine Press", "Barbell Front Raise", "Upright Row", "Barbell Shrug", "Z Press"
        ]),
        ExerciseFamily(muscleGroup: "Shoulders", equipment: "Dumbbells", requiredEquipment: ["Dumbbells"], difficulty: .low, environment: .both, exerciseType: .strength, tags: ["push", "delts"], names: [
            "Dumbbell Shoulder Press", "Arnold Press", "Seated Dumbbell Press", "Lateral Raise", "Front Raise", "Rear Delt Fly", "Lean Away Lateral Raise", "Dumbbell Upright Row", "Dumbbell Shrug", "Cuban Press", "Y Raise", "Scaption Raise"
        ]),
        ExerciseFamily(muscleGroup: "Shoulders", equipment: "Cable", requiredEquipment: ["Cable"], difficulty: .low, environment: .gym, exerciseType: .strength, tags: ["delts", "cable"], names: [
            "Cable Lateral Raise", "Cable Front Raise", "Cable Rear Delt Fly", "Face Pull", "Cable Upright Row", "Single Arm Cable Press", "Cable Y Raise", "Cable External Rotation", "Cable Internal Rotation", "Cable Shrug"
        ]),
        ExerciseFamily(muscleGroup: "Arms", equipment: "Barbell", requiredEquipment: ["Barbell"], difficulty: .low, environment: .gym, exerciseType: .strength, tags: ["biceps", "triceps"], names: [
            "Barbell Curl", "EZ Bar Curl", "Close Grip Bench Press", "Skull Crusher", "JM Press", "Reverse Curl", "Preacher Curl", "Drag Curl", "Barbell Wrist Curl", "Barbell Reverse Wrist Curl"
        ]),
        ExerciseFamily(muscleGroup: "Arms", equipment: "Dumbbells", requiredEquipment: ["Dumbbells"], difficulty: .low, environment: .both, exerciseType: .strength, tags: ["biceps", "triceps"], names: [
            "Dumbbell Curl", "Hammer Curl", "Incline Dumbbell Curl", "Concentration Curl", "Zottman Curl", "Dumbbell Preacher Curl", "Overhead Triceps Extension", "Dumbbell Kickback", "Lying Dumbbell Triceps Extension", "Tate Press", "Cross Body Hammer Curl", "Dumbbell Wrist Curl"
        ]),
        ExerciseFamily(muscleGroup: "Arms", equipment: "Cable", requiredEquipment: ["Cable"], difficulty: .low, environment: .gym, exerciseType: .strength, tags: ["biceps", "triceps", "cable"], names: [
            "Cable Curl", "Rope Hammer Curl", "Bayesian Cable Curl", "Cable Preacher Curl", "Triceps Pushdown", "Rope Triceps Pushdown", "Overhead Cable Triceps Extension", "Single Arm Cable Triceps Extension", "Cable Kickback", "Reverse Grip Triceps Pushdown"
        ]),
        ExerciseFamily(muscleGroup: "Core", equipment: "Bodyweight", requiredEquipment: ["Bodyweight"], difficulty: .low, environment: .both, exerciseType: .strength, tags: ["abs", "core"], names: [
            "Plank", "Side Plank", "Crunch", "Reverse Crunch", "Dead Bug", "Hollow Body Hold", "Mountain Climber", "Bicycle Crunch", "Leg Raise", "Flutter Kick", "Bird Dog", "Superman Hold"
        ]),
        ExerciseFamily(muscleGroup: "Core", equipment: "Cable", requiredEquipment: ["Cable"], difficulty: .medium, environment: .gym, exerciseType: .strength, tags: ["abs", "anti rotation"], names: [
            "Cable Crunch", "Pallof Press", "Cable Woodchop", "High To Low Cable Chop", "Low To High Cable Chop", "Cable Lift", "Cable Russian Twist", "Cable Side Bend"
        ]),
        ExerciseFamily(muscleGroup: "Full Body", equipment: "Kettlebell", requiredEquipment: ["Kettlebell"], difficulty: .medium, environment: .both, exerciseType: .strength, tags: ["conditioning", "power"], names: [
            "Kettlebell Swing", "Kettlebell Goblet Squat", "Kettlebell Clean", "Kettlebell Snatch", "Kettlebell Turkish Get-up", "Kettlebell Press", "Kettlebell Row", "Kettlebell Deadlift", "Kettlebell Halo", "Kettlebell Windmill"
        ]),
        ExerciseFamily(muscleGroup: "Full Body", equipment: "Resistance Band", requiredEquipment: ["Resistance Band"], difficulty: .low, environment: .home, exerciseType: .strength, tags: ["home", "band"], names: [
            "Band Row", "Band Face Pull", "Band Chest Press", "Band Pull Apart", "Band Squat", "Band Good Morning", "Band Lateral Walk", "Band Curl", "Band Triceps Pressdown", "Band Pallof Press", "Band Deadlift", "Band Overhead Press"
        ]),
        ExerciseFamily(muscleGroup: "Cardio", equipment: "Cardio Machine", requiredEquipment: ["Cardio Machine"], difficulty: .low, environment: .gym, exerciseType: .cardio, tags: ["cardio", "conditioning"], names: [
            "Treadmill Run", "Treadmill Walk", "Incline Treadmill Walk", "Stationary Bike", "Air Bike", "Rowing Machine", "Elliptical", "Stair Climber", "Ski Erg", "Spin Bike"
        ]),
        ExerciseFamily(muscleGroup: "Cardio", equipment: "Bodyweight", requiredEquipment: ["Bodyweight"], difficulty: .medium, environment: .both, exerciseType: .hiit, tags: ["hiit", "conditioning"], names: [
            "Burpee", "Jumping Jack", "High Knees", "Skater Hop", "Jump Squat", "Bear Crawl", "Inchworm", "Lateral Shuffle", "Mountain Climber Sprint", "Squat Thrust"
        ]),
        ExerciseFamily(muscleGroup: "Full Body", equipment: "Bodyweight", requiredEquipment: ["Bodyweight"], difficulty: .low, environment: .home, exerciseType: .mobility, tags: ["mobility", "warmup"], names: [
            "World's Greatest Stretch", "Cat Cow", "Thoracic Rotation", "Hip 90/90 Switch", "Deep Squat Hold", "Couch Stretch", "Shoulder CAR", "Hip CAR", "Ankle Rocker", "Scapular Push-up", "Wall Slide", "Prone Swimmer"
        ]),
        ExerciseFamily(muscleGroup: "Full Body", equipment: "Bodyweight", requiredEquipment: ["Bodyweight"], difficulty: .low, environment: .both, exerciseType: .stretching, tags: ["stretching", "recovery"], names: [
            "Hamstring Stretch", "Quad Stretch", "Calf Stretch", "Pigeon Stretch", "Child's Pose", "Thread The Needle", "Doorway Chest Stretch", "Lat Stretch", "Wrist Flexor Stretch", "Wrist Extensor Stretch", "Neck Side Stretch", "Seated Forward Fold"
        ]),
        ExerciseFamily(muscleGroup: "Arms", equipment: "Dumbbells", requiredEquipment: ["Dumbbells"], difficulty: .low, environment: .both, exerciseType: .strength, tags: ["forearms", "grip"], names: [
            "Farmer Carry", "Suitcase Carry", "Dumbbell Reverse Curl", "Dumbbell Wrist Extension", "Dumbbell Pronation", "Dumbbell Supination", "Pinch Grip Hold", "Towel Grip Curl", "Wrist Roller", "Dumbbell Finger Curl"
        ]),
        ExerciseFamily(muscleGroup: "Core", equipment: "Medicine Ball", requiredEquipment: ["Medicine Ball"], difficulty: .medium, environment: .both, exerciseType: .strength, tags: ["core", "power"], names: [
            "Medicine Ball Slam", "Medicine Ball Russian Twist", "Medicine Ball Sit-up", "Medicine Ball V-up", "Medicine Ball Plank Tap", "Medicine Ball Dead Bug", "Medicine Ball Woodchop", "Medicine Ball Overhead Throw", "Medicine Ball Chest Pass", "Medicine Ball Lunge Twist"
        ]),
        ExerciseFamily(muscleGroup: "Full Body", equipment: "TRX", requiredEquipment: ["Suspension Trainer"], difficulty: .medium, environment: .both, exerciseType: .strength, tags: ["suspension", "home"], names: [
            "Suspension Row", "Suspension Chest Press", "Suspension Push-up", "Suspension Squat", "Suspension Lunge", "Suspension Hamstring Curl", "Suspension Pike", "Suspension Fallout", "Suspension Y Fly", "Suspension Biceps Curl", "Suspension Triceps Extension", "Suspension Mountain Climber"
        ]),
        ExerciseFamily(muscleGroup: "Cardio", equipment: "Bodyweight", requiredEquipment: ["Bodyweight"], difficulty: .low, environment: .home, exerciseType: .cardio, tags: ["low impact", "conditioning"], names: [
            "March In Place", "Step Touch", "Shadow Boxing", "Low Impact High Knees", "Standing Mountain Climber", "Fast Feet", "Side Step Jack", "Standing Knee Drive", "Toe Tap", "Lateral Step Over"
        ])
    ]

    private static func uniqueExercises(_ exercises: [Exercise]) -> [Exercise] {
        var seen = Set<String>()
        return exercises.filter { exercise in
            seen.insert(exercise.name.lowercased()).inserted
        }
    }

    private static func trackingType(for type: Exercise.ExerciseType) -> Exercise.TrackingType {
        switch type {
        case .cardio, .mobility, .stretching, .hiit:
            return .duration
        case .strength:
            return .weightReps
        }
    }

    private static func secondaryMuscles(for muscleGroup: String) -> [String] {
        switch muscleGroup {
        case "Chest": return ["Shoulders", "Arms"]
        case "Back": return ["Arms", "Shoulders"]
        case "Legs": return ["Glutes", "Core"]
        case "Glutes": return ["Legs", "Core"]
        case "Shoulders": return ["Arms", "Upper Back"]
        case "Arms": return ["Forearms"]
        case "Core": return ["Hip Flexors"]
        case "Full Body": return ["Core", "Legs"]
        default: return []
        }
    }

    private static func aliases(for name: String) -> [String] {
        var aliases: [String] = []
        let lower = name.lowercased()
        if lower.contains("dumbbell") { aliases.append(name.replacingOccurrences(of: "Dumbbell", with: "DB")) }
        if lower.contains("barbell") { aliases.append(name.replacingOccurrences(of: "Barbell", with: "BB")) }
        if lower.contains("machine") { aliases.append(name.replacingOccurrences(of: "Machine", with: "Máquina")) }
        if lower.contains("cable") { aliases.append(name.replacingOccurrences(of: "Cable", with: "Polea")) }
        if lower.contains("push-up") { aliases.append(name.replacingOccurrences(of: "Push-up", with: "Pushup")) }
        return aliases
    }

    private static func patternTags(for name: String) -> [String] {
        let lower = name.lowercased()
        var tags: [String] = []
        if lower.contains("single arm") || lower.contains("single leg") { tags.append("unilateral") }
        if lower.contains("incline") { tags.append("incline") }
        if lower.contains("decline") { tags.append("decline") }
        if lower.contains("paused") { tags.append("tempo") }
        if lower.contains("assisted") { tags.append("beginner") }
        return tags
    }

    private static func instructions(for name: String, muscleGroup: String) -> String {
        let lower = name.lowercased()
        if lower.contains("bench press") {
            return "1. Lie flat on the bench with feet planted on the floor. Grip the bar slightly wider than shoulder-width.\n2. Unrack the bar and lower it under control to your mid-chest while inhaling.\n3. Keep your elbows angled at ~45° and press explosively up until arms are extended."
        } else if lower.contains("squat") {
            return "1. Position the bar across your upper back or hold weights firmly at chest level. Stand with feet shoulder-width apart.\n2. Inhale, brace your core, and lower your hips down and back until thighs are parallel to the floor.\n3. Drive through your heels to return to standing while exhaling."
        } else if lower.contains("deadlift") {
            return "1. Stand with feet hip-width apart and the bar over your mid-foot. Hinge at hips to grip the bar.\n2. Pull your chest up, flatten your back, and engage your lats.\n3. Drive through your legs to stand up tall without arching your lower back."
        } else if lower.contains("row") {
            return "1. Hinge forward at the hips with a flat back and core engaged.\n2. Pull the weight towards your lower ribs/navel, driving your elbows back.\n3. Pause briefly at full contraction, then lower with control."
        } else if lower.contains("pull-up") || lower.contains("chin-up") || lower.contains("pulldown") {
            return "1. Grip the bar or handles and hang with arms fully extended.\n2. Depress your shoulder blades and pull your chest up towards the bar.\n3. Squeeze your lats at the top, then lower smoothly back down."
        } else if lower.contains("press") {
            return "1. Set up in a stable stance or bench position with weights at shoulder level.\n2. Brace your core and press upward smoothly until arms are fully extended.\n3. Lower the weight under control back to the starting position."
        } else if lower.contains("curl") {
            return "1. Stand or sit upright holding the weight with palms facing forward.\n2. Keep your upper arms tucked at your sides and curl the weight upward by flexing your biceps.\n3. Squeeze at the peak, then lower slowly."
        } else if lower.contains("extension") || lower.contains("pushdown") || lower.contains("dip") {
            return "1. Position your body or grip the handles with your core braced.\n2. Extend your elbows smoothly, concentrating the tension on your triceps.\n3. Return to the starting position under control."
        } else if lower.contains("raise") {
            return "1. Hold the weights at your sides with knees slightly bent.\n2. Raise the weights smoothly in a wide arc until parallel with your shoulders.\n3. Pause briefly, then lower slowly."
        } else if lower.contains("lunge") || lower.contains("step-up") || lower.contains("split squat") {
            return "1. Stand upright with core braced. Step forward/backward or onto a raised platform.\n2. Lower your hips until both knees form roughly 90-degree angles.\n3. Push through the front heel to return to the starting position."
        } else if lower.contains("plank") {
            return "1. Place forearms on the floor with elbows under shoulders and toes grounded.\n2. Maintain a straight line from head to heels by squeezing glutes and abdominal muscles.\n3. Hold the position while breathing steadily."
        }
        return "1. Position yourself with proper spinal alignment and a braced core.\n2. Execute the movement smoothly through a full range of motion, keeping tension on your \(muscleGroup.lowercased()).\n3. Return to the starting position under control."
    }

    private static func commonMistakes(for type: Exercise.ExerciseType) -> [String] {
        switch type {
        case .cardio, .hiit:
            return ["Starting too fast", "Letting technique collapse when tired", "Ignoring breathing rhythm"]
        case .mobility, .stretching:
            return ["Forcing painful range", "Rushing the position", "Holding breath"]
        case .strength:
            return ["Losing brace", "Using momentum", "Cutting the range of motion short"]
        }
    }

    // MARK: - Program metadata

    struct ProgramMetadata {
        enum Category: String, CaseIterable, Identifiable {
            case strength
            case hypertrophy
            case home
            case beginner
            var id: String { rawValue }
            var displayName: String {
                switch self {
                case .strength:    return localizedString("program_category_strength")
                case .hypertrophy: return localizedString("program_category_hypertrophy")
                case .home:        return localizedString("program_category_home")
                case .beginner:    return localizedString("program_category_beginner")
                }
            }
            var systemImage: String {
                switch self {
                case .strength:    return "figure.strengthtraining.traditional"
                case .hypertrophy: return "chart.bar.fill"
                case .home:        return "house.fill"
                case .beginner:    return "star.fill"
                }
            }
        }

        enum Level: String {
            case beginner, intermediate, advanced
            var displayName: String {
                switch self {
                case .beginner:     return localizedString("program_level_beginner")
                case .intermediate: return localizedString("program_level_intermediate")
                case .advanced:     return localizedString("program_level_advanced")
                }
            }
            var color: String {
                switch self {
                case .beginner:     return "green"
                case .intermediate: return "orange"
                case .advanced:     return "red"
                }
            }
        }

        let tagline: String
        let category: Category
        let level: Level
    }

    static let programMetadata: [String: ProgramMetadata] = [
        "Push Pull Legs": .init(
            tagline: localizedString("program_ppl_tagline"),
            category: .hypertrophy, level: .intermediate
        ),
        "Home Strength": .init(
            tagline: localizedString("program_home_strength_tagline"),
            category: .home, level: .beginner
        ),
        "Beginner Full Body": .init(
            tagline: localizedString("program_beginner_full_body_tagline"),
            category: .beginner, level: .beginner
        ),
        "Full Body Beginner 3-Day": .init(
            tagline: localizedString("program_full_body_3day_tagline"),
            category: .beginner, level: .beginner
        ),
        "Upper Lower 4-Day": .init(
            tagline: localizedString("program_upper_lower_tagline"),
            category: .strength, level: .intermediate
        ),
        "Push Pull Legs 3-Day": .init(
            tagline: localizedString("program_ppl_3day_tagline"),
            category: .hypertrophy, level: .beginner
        ),
        "Push Pull Legs 6-Day": .init(
            tagline: localizedString("program_ppl_6day_tagline"),
            category: .hypertrophy, level: .advanced
        ),
        "Home Dumbbell 4-Day": .init(
            tagline: localizedString("program_home_dumbbell_tagline"),
            category: .home, level: .intermediate
        ),
        "Home No Equipment 3-Day": .init(
            tagline: localizedString("program_home_no_equipment_tagline"),
            category: .home, level: .beginner
        ),
        "Strength 5x5": .init(
            tagline: localizedString("program_5x5_tagline"),
            category: .strength, level: .intermediate
        ),
        "Hypertrophy 8-Week": .init(
            tagline: localizedString("program_hypertrophy_8week_tagline"),
            category: .hypertrophy, level: .advanced
        ),
        "Glutes & Legs Focus": .init(
            tagline: localizedString("program_glutes_legs_tagline"),
            category: .hypertrophy, level: .intermediate
        ),
        "Express 30-Minute Strength": .init(
            tagline: localizedString("program_express_tagline"),
            category: .strength, level: .beginner
        )
    ]
}
