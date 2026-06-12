import SwiftUI

struct PersonalRecordsView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    
    struct PersonalRecordItem: Identifiable {
        let id = UUID()
        let exercise: Exercise
        let maxWeight: Double
        let maxReps: Int
        let oneRepMax: Double
        let date: Date
    }
    
    private var personalRecords: [PersonalRecordItem] {
        var records: [UUID: PersonalRecordItem] = [:]
        
        for session in store.workoutSessions {
            let logs = session.exerciseLogs ?? []
            for log in logs {
                let exercise = log.exercise
                for set in log.sets where set.completed {
                    let oneRM = FitnessMetrics.estimatedOneRepMax(weightKg: set.weightKg, reps: set.reps)
                    
                    if let currentBest = records[exercise.id] {
                        // Update if this is a heavier lift, or same weight with more reps
                        if set.weightKg > currentBest.maxWeight || (set.weightKg == currentBest.maxWeight && set.reps > currentBest.maxReps) {
                            records[exercise.id] = PersonalRecordItem(
                                exercise: exercise,
                                maxWeight: set.weightKg,
                                maxReps: set.reps,
                                oneRepMax: oneRM,
                                date: session.date
                            )
                        }
                    } else {
                        records[exercise.id] = PersonalRecordItem(
                            exercise: exercise,
                            maxWeight: set.weightKg,
                            maxReps: set.reps,
                            oneRepMax: oneRM,
                            date: session.date
                        )
                    }
                }
            }
        }
        
        return Array(records.values).sorted { $0.maxWeight > $1.maxWeight }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 22) {
                // PR Hero Section
                VStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(PulseTheme.accent.opacity(0.12))
                            .frame(width: 86, height: 86)
                        Image(systemName: "trophy.fill")
                            .font(.system(size: 38, weight: .bold))
                            .foregroundStyle(PulseTheme.accent)
                    }
                    .padding(.top, 10)
                    
                    Text("\(personalRecords.count) Récords Personales")
                        .font(.system(size: 26, weight: .bold, design: .rounded))
                    
                    Text("Tus mejores marcas registradas en cada ejercicio")
                        .font(.subheadline)
                        .foregroundStyle(PulseTheme.secondaryText)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                
                if personalRecords.isEmpty {
                    PulseCard {
                        PulseEmptyState(
                            title: "Sin récords aún",
                            message: "Completa entrenamientos y registra series efectivas para empezar a acumular trofeos de récord personal.",
                            systemImage: "trophy"
                        )
                    }
                    .padding(.horizontal, 20)
                } else {
                    LazyVStack(spacing: 14) {
                        ForEach(personalRecords) { item in
                            PRCardView(item: item)
                        }
                    }
                    .padding(.horizontal, 20)
                }
            }
            .padding(.bottom, 30)
        }
        .screenBackground()
        .navigationTitle("Muro de Récords")
        .navigationBarTitleDisplayMode(.inline)
        .mainTabBarHidden()
    }
}

struct PRCardView: View {
    @Environment(AppStore.self) private var store
    let item: PersonalRecordsView.PersonalRecordItem
    @State private var isShowingShareSheet = false
    @State private var shareImage: UIImage?
    
    var body: some View {
        PulseCard {
            HStack(spacing: 16) {
                ExerciseMediaThumbnail(exercise: item.exercise, gender: store.userProfile.muscleMapGender)
                    .frame(width: 58, height: 58)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(item.exercise.name)
                        .font(.headline)
                        .lineLimit(1)
                    
                    Text("Establecido el \(item.date.formatted(date: .abbreviated, time: .omitted))")
                        .font(.caption)
                        .foregroundStyle(PulseTheme.tertiaryText)
                    
                    HStack(spacing: 8) {
                        // PR Badge
                        HStack(spacing: 3) {
                            Image(systemName: "trophy.fill")
                                .font(.system(size: 10))
                            Text("PR")
                                .font(.system(size: 10, weight: .black))
                        }
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(PulseTheme.accent.opacity(0.16))
                        .foregroundStyle(PulseTheme.accent)
                        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                        
                        Text("1RM Est: \(Int(item.oneRepMax)) kg")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(PulseTheme.primaryBright)
                    }
                    .padding(.top, 2)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text("\(item.maxWeight, specifier: "%.1f") kg")
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundStyle(PulseTheme.primary)
                    
                    Text("x \(item.maxReps) rep\(item.maxReps == 1 ? "" : "s")")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(PulseTheme.secondaryText)
                }
                
                Button {
                    guard store.requireFeature(.shareCards, source: .shareCards) else {
                        return
                    }
                    // Generate a share image for this PR
                    shareImage = WorkoutShareImageRenderer.render(
                        title: "Récord Personal: \(item.exercise.name)",
                        duration: 0,
                        volume: Int(item.oneRepMax),
                        sets: item.maxReps
                    )
                    isShowingShareSheet = true
                } label: {
                    Image(systemName: "square.and.arrow.up")
                        .font(.body)
                        .foregroundStyle(PulseTheme.secondaryText)
                        .padding(8)
                        .background(PulseTheme.grouped)
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
            }
        }
        .sheet(isPresented: $isShowingShareSheet) {
            if let image = shareImage {
                ActivityViewController(activityItems: [image])
            }
        }
    }
}

struct ActivityViewController: UIViewControllerRepresentable {
    let activityItems: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
