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
    static let splitSquat = Exercise(name: "Bulgarian Split Squat", muscleGroup: "Legs", equipment: "Dumbbells")
    static let calfRaise = Exercise(name: "Standing Calf Raise", muscleGroup: "Legs", equipment: "Bodyweight", trackingType: .repsOnly)
    static let mountainClimber = Exercise(name: "Mountain Climber", muscleGroup: "Core", equipment: "Bodyweight", trackingType: .duration)
    static let kettlebellSwing = Exercise(name: "Kettlebell Swing", muscleGroup: "Full Body", equipment: "Kettlebell")
    static let bike = Exercise(name: "Stationary Bike", muscleGroup: "Cardio", equipment: "Cardio Machine", trackingType: .duration)
    static let treadmill = Exercise(name: "Treadmill Run", muscleGroup: "Cardio", equipment: "Cardio Machine", trackingType: .duration)
    static let rower = Exercise(name: "Rowing Machine", muscleGroup: "Cardio", equipment: "Cardio Machine", trackingType: .duration)

    static let exercises = [
        bench, incline, overhead, deadlift, squat, row, pushup, plank, lunge,
        pullup, invertedRow, gobletSquat, romanianDeadlift, hipThrust, bandRow,
        bandFacePull, floorPress, lateralRaise, curl, tricepsExtension, splitSquat,
        calfRaise, mountainClimber, kettlebellSwing, bike, treadmill, rower
    ]

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

    static let defaultPlans = [pushPullLegsPlan, homeStrengthPlan, beginnerFullBodyPlan]
    static let workoutTemplates = [pushDay, pullDay, legDay, homeA, homeB]

    static let sessions: [WorkoutSession] = []
    static let goals: [Goal] = []
    static let scheduledWorkouts: [ScheduledWorkout] = []
    static let bodyMetrics: [BodyMetric] = []
}
