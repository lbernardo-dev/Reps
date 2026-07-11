import SwiftUI

struct PersonalRecordsView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    
    struct PersonalRecordItem: Identifiable {
        let exercise: Exercise
        let maxWeight: Double
        let maxReps: Int
        let oneRepMax: Double
        let date: Date
        var id: UUID { exercise.id }
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
        ScrollView(.vertical, showsIndicators: false) {
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
                    
                    Text(localizedFormat("personal_records_count_format", personalRecords.count))
                        .font(.system(size: 26, weight: .bold, design: .rounded))
                    
                    Text("your_best_trademarks_in_each_exercise")
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
                            title: "no_records_yet",
                            message: "no_records_message",
                            systemImage: "trophy"
                        )
                    }
                    .padding(.horizontal, PulseTheme.screenHorizontalPadding)
                } else {
                    LazyVStack(spacing: 14) {
                        ForEach(personalRecords) { item in
                            NavigationLink {
                                ExerciseDetailView(exercise: item.exercise)
                            } label: {
                                PRCardView(item: item)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, PulseTheme.screenHorizontalPadding)
                }
            }
            .padding(.bottom, 30)
        }
        .scrollBounceBehavior(.basedOnSize, axes: .vertical)
        .screenBackground()
        .navigationTitle("wall_of_records")
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
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 16) {
                    ExerciseMediaThumbnail(exercise: item.exercise, gender: store.userProfile.muscleMapGender, catalog: store.exercises)
                        .frame(width: 52, height: 52)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                    VStack(alignment: .leading, spacing: 4) {
                        Text(item.exercise.name)
                            .font(.headline)
                            .lineLimit(2)
                            .fixedSize(horizontal: false, vertical: true)

                        Text(localizedFormat("set_on_date_format", item.date.formatted(date: .abbreviated, time: .omitted)))
                            .font(.caption)
                            .foregroundStyle(PulseTheme.tertiaryText)
                    }

                    Spacer(minLength: 8)

                    Button {
                        guard store.requireFeature(.shareCards, source: .shareCards) else {
                            return
                        }
                        shareImage = WorkoutShareImageRenderer.renderPR(
                            exerciseName: item.exercise.name,
                            weightKg: item.maxWeight,
                            reps: item.maxReps,
                            date: item.date
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

                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(PulseTheme.tertiaryText)
                }

                HStack(alignment: .center, spacing: 8) {
                    // PR Badge
                    HStack(spacing: 3) {
                        Image(systemName: "trophy.fill")
                            .font(.system(size: 10))
                        Text("pr_2")
                            .font(.system(size: 10, weight: .black))
                    }
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(PulseTheme.accent.opacity(0.16))
                    .foregroundStyle(PulseTheme.accent)
                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))

                    Text("1RM Est: \(Int(item.oneRepMax)) kg")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(PulseTheme.ringStand)
                        .lineLimit(1)

                    Spacer(minLength: 8)

                    Text("\(item.maxWeight, specifier: "%.1f") kg")
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundStyle(PulseTheme.accent)

                    Text("x \(item.maxReps) rep\(item.maxReps == 1 ? "" : "s")")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(PulseTheme.secondaryText)
                }
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
