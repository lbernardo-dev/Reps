import SwiftUI
import UIKit

struct WorkoutSummaryView: View {
    @Environment(AppStore.self) private var store
    let session: WorkoutSession
    let onDone: () -> Void

    @State private var isShowingShareSheet = false
    @State private var generatedImage: UIImage?
    @State private var isImageSaved = false
    @State private var prShareImage: UIImage?
    @State private var prShareTitle: String = ""
    @State private var isShowingPRShareSheet = false
    @State private var isSharingToFeed = false
    @State private var feedShared = false
    @State private var feedComposeImage: UIImage?
    @State private var isShowingFeedCompose = false

    private var completedSets: [SetLog] {
        FitnessMetrics.completedSets(in: session)
    }

    private var weeklyLoads: [MuscleLoad] {
        let weekStart = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        return MuscleLoadCalculator.loads(
            sessions: store.workoutSessions,
            plannedWorkout: .freeWorkout,
            startDate: weekStart,
            includePrediction: false
        )
    }

    private var workedMuscleCount: Int {
        let segments = FitnessMetrics.completedExerciseLogs(in: session)
            .flatMap { MuscleLoadCalculator.segments(for: $0.exercise) }
        return Set(segments).count
    }

    private var durationText: String {
        let minutes = max(session.durationMinutes, 0)
        if minutes >= 60 {
            return "\(minutes / 60)h \(minutes % 60)m"
        }
        return "\(minutes)m"
    }

    private struct PRItem {
        let exercise: Exercise
        let weightKg: Double
        let reps: Int
    }

    private var sessionPRs: [PRItem] {
        (session.exerciseLogs ?? []).compactMap { log in
            guard let prSet = log.sets.first(where: { $0.isPersonalRecord && $0.completed }) else {
                return nil
            }
            return PRItem(exercise: log.exercise, weightKg: prSet.weightKg, reps: prSet.reps)
        }
    }

    private var matchingWorkoutDay: WorkoutDay? {
        store.plans.flatMap(\.days).first { $0.title == session.workoutTitle }
    }

    private var postWorkoutRecommendations: [SmartProgressionAdvisor.Recommendation] {
        guard let day = matchingWorkoutDay else { return [] }
        return SmartProgressionAdvisor.recommendations(
            for: day,
            sessions: store.workoutSessions,
            weightIncrementKg: store.userProfile.weightIncrementKg,
            limit: 4
        )
    }

    private var activeGoalHighlights: [Goal] {
        store.goals
            .filter { !$0.isAchieved }
            .sorted { $0.progress > $1.progress }
            .prefix(3)
            .map { $0 }
    }

    var body: some View {
        Group {
            if session.isRouteSession {
                RouteWorkoutSummaryView(session: session, shareAction: shareSession)
            } else {
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 20) {
                        WorkoutReceiptView(session: session)
                            .padding(.horizontal, 4)

                        if !sessionPRs.isEmpty {
                            PulseCard {
                                VStack(alignment: .leading, spacing: 12) {
                                    HStack(spacing: 10) {
                                        Image(systemName: "trophy.fill")
                                            .font(.headline.weight(.bold))
                                            .foregroundStyle(.black)
                                            .frame(width: 38, height: 38)
                                            .background(PulseTheme.accent)
                                            .clipShape(Circle())
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(localizedString("new_personal_records"))
                                                .font(.headline)
                                            Text(localizedFormat("you_set_pr_count_records_today", sessionPRs.count))
                                                .font(.caption)
                                                .foregroundStyle(PulseTheme.secondaryText)
                                        }
                                    }
                                    Divider()
                                    ForEach(sessionPRs, id: \.exercise.id) { pr in
                                        HStack {
                                            VStack(alignment: .leading, spacing: 2) {
                                                Text(RepsText.exerciseName(pr.exercise.name, language: store.userProfile.preferredLanguage))
                                                    .font(.subheadline.weight(.semibold))
                                                    .lineLimit(1)
                                                let w = pr.weightKg.truncatingRemainder(dividingBy: 1) == 0
                                                    ? "\(Int(pr.weightKg)) kg"
                                                    : String(format: "%.1f kg", pr.weightKg)
                                                Text("\(w) × \(pr.reps) reps")
                                                    .font(.caption.weight(.bold))
                                                    .foregroundStyle(PulseTheme.accent)
                                            }
                                            Spacer()
                                            Button {
                                                guard store.requireFeature(.shareCards, source: .shareCards) else { return }
                                                prShareImage = WorkoutShareImageRenderer.renderPR(
                                                    exerciseName: pr.exercise.name,
                                                    weightKg: pr.weightKg,
                                                    reps: pr.reps,
                                                    date: session.date
                                                )
                                                prShareTitle = localizedFormat(
                                                    "share_pr_title_format",
                                                    RepsText.exerciseName(pr.exercise.name, language: store.userProfile.preferredLanguage)
                                                )
                                                isShowingPRShareSheet = true
                                            } label: {
                                                Image(systemName: "square.and.arrow.up")
                                                    .font(.subheadline.weight(.semibold))
                                                    .foregroundStyle(PulseTheme.secondaryText)
                                                    .padding(8)
                                                    .background(PulseTheme.grouped)
                                                    .clipShape(Circle())
                                            }
                                            .buttonStyle(.plain)
                                        }
                                    }
                                }
                            }
                            .padding(.horizontal, 4)
                        }

                        if workedMuscleCount > 0 {
                            SessionMuscleSummaryCard(
                                loads: weeklyLoads,
                                gender: store.userProfile.muscleMapGender,
                                workedMuscleCount: workedMuscleCount,
                                durationText: durationText
                            )
                            .padding(.horizontal, 4)
                        }

                        if !activeGoalHighlights.isEmpty {
                            PostWorkoutGoalProgressCard(goals: activeGoalHighlights)
                                .padding(.horizontal, 4)
                        }

                        if !postWorkoutRecommendations.isEmpty {
                            ProgressionRecommendationCard(
                                recommendations: postWorkoutRecommendations,
                                language: store.userProfile.preferredLanguage,
                                title: "progression_plan"
                            )
                            .padding(.horizontal, 4)
                        }

                        HStack(spacing: 12) {
                            Button(action: shareSession) {
                                HStack {
                                    Image(systemName: "square.and.arrow.up")
                                    Text("share")
                                }
                                .font(.system(size: 15, weight: .bold))
                                .foregroundStyle(.black)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(PulseTheme.accent)
                                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                            }
                            .buttonStyle(.plain)

                            Button {
                                guard store.requireFeature(.shareCards, source: .shareCards) else {
                                    return
                                }
                                let img = WorkoutShareImageRenderer.render(session: session)
                                UIImageWriteToSavedPhotosAlbum(img, nil, nil, nil)
                                withAnimation {
                                    isImageSaved = true
                                }
                                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                                    isImageSaved = false
                                }
                            } label: {
                                HStack {
                                    Image(systemName: isImageSaved ? "checkmark" : "square.and.arrow.down")
                                    Text(isImageSaved ? localizedString("saved") : localizedString("save_photo"))
                                }
                                .font(.system(size: 15, weight: .bold))
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(Color.white.opacity(0.10))
                                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.horizontal, 4)

                        if store.userProfile.socialEnabled, store.userProfile.socialUsername != nil {
                            Button {
                                composeFeedPost()
                            } label: {
                                HStack(spacing: 8) {
                                    if isSharingToFeed {
                                        ProgressView().tint(.white).scaleEffect(0.8)
                                    } else {
                                        Image(systemName: feedShared ? "checkmark.circle.fill" : "square.and.pencil")
                                    }
                                    Text(feedShared ? localizedString("share_feed_done") : localizedString("feed_post_compose_button"))
                                }
                                .font(.system(size: 15, weight: .bold))
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(
                                    feedShared
                                        ? PulseTheme.ringExercise.opacity(0.20)
                                        : PulseTheme.accent.opacity(0.18)
                                )
                                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .stroke(PulseTheme.accent.opacity(0.35), lineWidth: 1)
                                )
                            }
                            .buttonStyle(.plain)
                            .disabled(isSharingToFeed || feedShared)
                            .padding(.horizontal, 4)
                        }

                        PulseCard {
                            VStack(alignment: .leading, spacing: 12) {
                                CardTitle("detalles_adicionales")
                                if !session.mediaAttachments.isEmpty {
                                    AttachmentPreviewStrip(attachments: session.mediaAttachments)
                                }
                                if let notes = session.notes, !notes.isEmpty {
                                    Divider()
                                    Text(notes)
                                        .foregroundStyle(PulseTheme.secondaryText)
                                } else {
                                    Text("no_additional_training_notes")
                                        .font(.subheadline)
                                        .foregroundStyle(PulseTheme.tertiaryText)
                                }
                            }
                        }
                    }
                    .padding(.horizontal, PulseTheme.screenHorizontalPadding)
                    .padding(.vertical, 16)
                    .padding(.bottom, 24)
                }
                .scrollBounceBehavior(.basedOnSize, axes: .vertical)
                .screenBackground()
                .overlay(alignment: .topTrailing) {
                    Button {
                        onDone()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.white)
                            .frame(width: 32, height: 32)
                            .destructiveGlassCircle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 14)
                    .padding(.trailing, 16)
                    .accessibilityLabel("close_summary")
                }
            }
        }
        .sheet(isPresented: $isShowingShareSheet) {
            if let image = generatedImage {
                ActivityViewController(activityItems: [
                    ShareImageItemSource(image: image, title: shareTitle)
                ])
            }
        }
        .sheet(isPresented: $isShowingPRShareSheet) {
            if let image = prShareImage {
                ActivityViewController(activityItems: [
                    ShareImageItemSource(image: image, title: prShareTitle)
                ])
            }
        }
        .sheet(isPresented: $isShowingFeedCompose) {
            if let image = feedComposeImage {
                CreatePostView(
                    prefilledImage: image,
                    prefilledCaption: defaultFeedCaption,
                    onPosted: { withAnimation { feedShared = true } }
                )
            }
        }
    }

    private var shareTitle: String {
        localizedFormat("share_workout_title_format", session.workoutTitle)
    }

    private var totalVolumeKg: Int {
        Int(FitnessMetrics.totalVolumeKg(for: [session]))
    }

    private var defaultFeedCaption: String {
        var caption = localizedFormat(
            "feed_default_caption_format",
            session.workoutTitle,
            durationText,
            totalVolumeKg,
            completedSets.count
        )
        if !sessionPRs.isEmpty {
            caption += localizedFormat("feed_default_caption_pr_format", sessionPRs.count)
        }
        return caption
    }

    private func shareSession() {
        guard store.requireFeature(.shareCards, source: .shareCards) else {
            return
        }
        generatedImage = WorkoutShareImageRenderer.render(session: session)
        isShowingShareSheet = true
    }

    private func composeFeedPost() {
        isSharingToFeed = true
        Task {
            let img = await WorkoutShareImageRenderer.renderForFeed(session: session)
            await MainActor.run {
                feedComposeImage = img
                isSharingToFeed = false
                isShowingFeedCompose = true
            }
        }
    }
}

private struct PostWorkoutGoalProgressCard: View {
    let goals: [Goal]

    var body: some View {
        PulseCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 10) {
                    Image(systemName: "target")
                        .font(.headline.weight(.bold))
                        .foregroundStyle(PulseTheme.onColor(PulseTheme.accent))
                        .frame(width: 38, height: 38)
                        .background(PulseTheme.accent, in: Circle())
                    VStack(alignment: .leading, spacing: 2) {
                        Text("post_workout_goals_title")
                            .font(.headline)
                        Text("post_workout_goals_subtitle")
                            .font(.caption)
                            .foregroundStyle(PulseTheme.secondaryText)
                    }
                }

                ForEach(goals) { goal in
                    VStack(alignment: .leading, spacing: 7) {
                        HStack {
                            Text(goal.title)
                                .font(.subheadline.weight(.bold))
                                .lineLimit(1)
                            Spacer()
                            Text("\(Int((goal.progress * 100).rounded()))%")
                                .font(.caption.weight(.black))
                                .foregroundStyle(PulseTheme.accent)
                        }
                        GeometryReader { proxy in
                            ZStack(alignment: .leading) {
                                Capsule().fill(PulseTheme.grouped)
                                Capsule()
                                    .fill(goal.isOverdue ? PulseTheme.destructive : PulseTheme.accent)
                                    .frame(width: proxy.size.width * goal.progress)
                            }
                        }
                        .frame(height: 6)
                        Text("\(goal.current.formatted(.number.precision(.fractionLength(0...1)))) / \(goal.target.formatted(.number.precision(.fractionLength(0...1)))) \(goal.unit)")
                            .font(.caption)
                            .foregroundStyle(PulseTheme.secondaryText)
                    }
                    if goal.id != goals.last?.id {
                        Divider().opacity(0.12)
                    }
                }
            }
        }
    }
}
