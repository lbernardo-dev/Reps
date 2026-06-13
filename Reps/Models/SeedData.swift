import Foundation

enum SeedData {
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
        "HYROX · Carrera Base Z2",
        subtitle: "Base aeróbica conversacional (Z2)",
        durationMinutes: 45,
        [
            station("Running", sets: 1, reps: "45 min", rest: 0, priority: .primary)
        ],
        sessionType: .cardioRun
    )

    private static let hyroxRunIntervals = programDay(
        "HYROX · Intervalos de Carrera",
        subtitle: "Ritmo umbral / ritmo de carrera",
        durationMinutes: 45,
        [
            station("Running", sets: 6, reps: "1000 m", rest: 90, priority: .primary)
        ],
        sessionType: .cardioRun
    )

    private static let hyroxStrengthA = programDay(
        "HYROX · Fuerza Funcional A",
        subtitle: "Piernas, empuje y estaciones",
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
        "HYROX · Fuerza Funcional B",
        subtitle: "Cadena posterior, tracción y acarreos",
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
        "HYROX · Compromised Running",
        subtitle: "Correr fatigado tras cada estación",
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
        "HYROX · Simulación de Carrera",
        subtitle: "Las 8 estaciones, 1 km de carrera antes de cada una",
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
        "HYROX · Afinamiento (Taper)",
        subtitle: "Semana de carrera: agudeza, bajo volumen",
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
                sourceName: "StreakRep seed catalog",
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
                    sourceName: "StreakRep seed catalog",
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
        "Set up with control, brace before each rep, move through a comfortable range of motion, and keep tension on \(muscleGroup.lowercased()) throughout \(name.lowercased())."
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
}
