import MuscleMap
import SwiftUI

/// Rehab exercise "Form Guide" — mirrors the tab pattern of
/// `ExerciseDetailView` (segmented Guía/Historial bar, numbered instruction
/// steps) but swaps the strength-oriented info/progress tabs for a target
/// area diagram, dosage card, and 0–10 pain scale relevant to rehab work.
struct RehabExerciseDetailView: View {
    @Environment(AppStore.self) private var store
    let exercise: RehabExercise

    @State private var selectedTab: RehabTab = .guide
    @State private var showLogSheet = false

    private var language: String { store.userProfile.preferredLanguage }

    private enum RehabTab: String, CaseIterable, Identifiable {
        case guide
        case history
        var id: String { rawValue }

        var localizedTitle: String {
            switch self {
            case .guide: localizedString("rehab_tab_guide")
            case .history: localizedString("history")
            }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 0) {
                HStack(spacing: 0) {
                    ForEach(RehabTab.allCases) { tab in
                        Button {
                            withAnimation(.spring(response: 0.28, dampingFraction: 0.72)) {
                                selectedTab = tab
                            }
                        } label: {
                            VStack(spacing: 12) {
                                Text(tab.localizedTitle)
                                    .font(.system(size: 15, weight: .bold))
                                    .foregroundStyle(selectedTab == tab ? PulseTheme.ringStand : PulseTheme.secondaryText)
                                    .frame(maxWidth: .infinity)

                                Rectangle()
                                    .fill(selectedTab == tab ? PulseTheme.ringStand : Color.clear)
                                    .frame(height: 3.5)
                                    .clipShape(.rect(cornerRadius: PulseTheme.smallRadius))
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.top, 12)
                .background(PulseTheme.card)

                Divider().overlay(PulseTheme.separator)
            }

            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 20) {
                    switch selectedTab {
                    case .guide:
                        guideTabContent
                    case .history:
                        historyTabContent
                    }
                }
                .padding(.horizontal, PulseTheme.screenHorizontalPadding)
                .padding(.vertical, 20)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .scrollBounceBehavior(.basedOnSize, axes: .vertical)
        }
        .screenBackground()
        .navigationTitle(exercise.name.resolved(language: language))
        .navigationBarTitleDisplayMode(.inline)
        .mainTabBarHidden()
        .sheet(isPresented: $showLogSheet) {
            RehabLogSessionSheet(exercise: exercise) { setsCompleted, painLevel, notes in
                store.logRehabSession(exerciseID: exercise.id, setsCompleted: setsCompleted, painLevel: painLevel, notes: notes)
            }
        }
    }

    // MARK: Guide tab

    private var guideTabContent: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                Spacer()
                VStack(spacing: 10) {
                    MuscleGroupAnatomyThumbnail(
                        muscleGroup: exercise.bodyRegion.anatomyMuscleGroupKeyword,
                        gender: store.userProfile.muscleMapGender,
                        size: 140
                    )
                    HStack(spacing: 8) {
                        rehabPill(exercise.bodyRegion.title.resolved(language: language), systemImage: exercise.bodyRegion.systemImage)
                        rehabPill(exercise.structureFocus.title.resolved(language: language), systemImage: exercise.structureFocus.systemImage)
                    }
                }
                Spacer()
            }

            RehabDisclaimerBanner(text: RehabSeedData.disclaimer.resolved(language: language))

            dosageCard

            VStack(alignment: .leading, spacing: 10) {
                Text(localizedString("instructions"))
                    .font(.headline)
                ForEach(Array(exercise.instructions.enumerated()), id: \.offset) { index, step in
                    RehabInstructionStepRow(index: index + 1, text: step.resolved(language: language))
                }
            }

            RehabPainScaleCard(guidance: exercise.painGuidance.resolved(language: language))

            if !exercise.cautions.isEmpty {
                cautionsCard
            }

            referenceNoteView
        }
    }

    private func rehabPill(_ title: String, systemImage: String) -> some View {
        Label(title, systemImage: systemImage)
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .foregroundStyle(PulseTheme.accent)
            .background(PulseTheme.accent.opacity(0.10), in: Capsule())
    }

    private var dosageCard: some View {
        PulseCard {
            VStack(alignment: .leading, spacing: 12) {
                Text(exercise.protocolType.title.resolved(language: language))
                    .font(.headline)
                HStack(spacing: 24) {
                    dosageStat(value: "\(exercise.sets)", label: localizedString("rehab_sets"))
                    if let holdSeconds = exercise.holdSeconds {
                        dosageStat(value: "\(holdSeconds)s", label: localizedString("rehab_hold"))
                    } else if let reps = exercise.reps {
                        dosageStat(value: "\(reps)", label: localizedString("rehab_reps"))
                    }
                    dosageStat(value: "\(exercise.restSeconds)s", label: localizedString("rehab_rest"))
                }
                Text(exercise.stage.title.resolved(language: language))
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(PulseTheme.secondaryText)
            }
        }
    }

    private func dosageStat(value: String, label: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(.title3.monospacedDigit().weight(.bold))
            Text(label)
                .font(.caption)
                .foregroundStyle(PulseTheme.secondaryText)
        }
    }

    private var cautionsCard: some View {
        PulseCard {
            VStack(alignment: .leading, spacing: 10) {
                Label(localizedString("rehab_cautions"), systemImage: "exclamationmark.triangle.fill")
                    .font(.headline)
                    .foregroundStyle(PulseTheme.destructive)
                ForEach(Array(exercise.cautions.enumerated()), id: \.offset) { _, caution in
                    HStack(alignment: .top, spacing: 8) {
                        Circle()
                            .fill(PulseTheme.destructive)
                            .frame(width: 5, height: 5)
                            .padding(.top, 6)
                        Text(caution.resolved(language: language))
                            .font(.subheadline)
                            .foregroundStyle(PulseTheme.secondaryText)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
    }

    private var referenceNoteView: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "book.closed")
                .font(.caption)
                .foregroundStyle(PulseTheme.tertiaryText)
            Text(exercise.referenceNote.resolved(language: language))
                .font(.caption)
                .foregroundStyle(PulseTheme.tertiaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: History tab

    private var historyTabContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            Button {
                showLogSheet = true
            } label: {
                Label(localizedString("rehab_log_session"), systemImage: "plus.circle.fill")
                    .font(.subheadline.weight(.bold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .foregroundStyle(PulseTheme.onColor(PulseTheme.accent))
                    .background(PulseTheme.accent, in: RoundedRectangle(cornerRadius: PulseTheme.mediumRadius, style: .continuous))
            }
            .buttonStyle(.plain)

            let logs = store.rehabLogs(forExerciseID: exercise.id)
            if logs.isEmpty {
                PulseEmptyState(
                    title: "rehab_no_history_title",
                    message: "rehab_no_history_message",
                    systemImage: "clock.arrow.circlepath"
                )
            } else {
                ForEach(logs) { log in
                    RehabSessionLogRow(log: log)
                }
            }
        }
    }
}

private struct RehabInstructionStepRow: View {
    let index: Int
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text("\(index)")
                .font(.caption.weight(.bold))
                .foregroundStyle(PulseTheme.onColor(PulseTheme.accent))
                .frame(width: 26, height: 26)
                .background(PulseTheme.accent)
                .clipShape(Circle())
            Text(text)
                .font(.body)
                .foregroundStyle(PulseTheme.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(12)
        .background(PulseTheme.grouped)
        .clipShape(RoundedRectangle(cornerRadius: PulseTheme.compactRadius, style: .continuous))
    }
}

/// A 0–10 pain-scale reference (green → amber → red) with the exercise's
/// specific guidance text, in the spirit of `FatigueRatingCard` but scaled
/// for pain rather than fatigue.
private struct RehabPainScaleCard: View {
    let guidance: String

    var body: some View {
        PulseCard {
            VStack(alignment: .leading, spacing: 14) {
                Text(localizedString("rehab_pain_scale_title"))
                    .font(.headline)

                GeometryReader { proxy in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: PulseTheme.smallRadius, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [PulseTheme.ringStand, PulseTheme.warning, PulseTheme.destructive],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(height: 14)

                        Rectangle()
                            .fill(PulseTheme.textPrimary.opacity(0.55))
                            .frame(width: 2, height: 20)
                            .offset(x: proxy.size.width * 0.4 - 1)
                    }
                }
                .frame(height: 20)

                HStack {
                    Text("0")
                    Spacer()
                    Text(localizedString("rehab_pain_alert_threshold"))
                        .fontWeight(.semibold)
                    Spacer()
                    Text("10")
                }
                .font(.caption2.monospacedDigit())
                .foregroundStyle(PulseTheme.tertiaryText)

                Text(guidance)
                    .font(.subheadline)
                    .foregroundStyle(PulseTheme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

private struct RehabSessionLogRow: View {
    let log: RehabSessionLog

    private var painColor: Color {
        switch log.painLevel {
        case 0...3: PulseTheme.ringStand
        case 4: PulseTheme.warning
        default: PulseTheme.destructive
        }
    }

    var body: some View {
        PulseCard {
            HStack(alignment: .top, spacing: 14) {
                VStack(spacing: 2) {
                    Text("\(log.painLevel)")
                        .font(.title3.monospacedDigit().weight(.bold))
                        .foregroundStyle(painColor)
                    Text(localizedString("rehab_pain_short"))
                        .font(.caption2)
                        .foregroundStyle(PulseTheme.tertiaryText)
                }
                .frame(width: 44)

                VStack(alignment: .leading, spacing: 4) {
                    Text(log.date.formatted(date: .abbreviated, time: .shortened))
                        .font(.subheadline.weight(.semibold))
                    Text(String(format: localizedString("rehab_sets_completed_format"), log.setsCompleted))
                        .font(.caption)
                        .foregroundStyle(PulseTheme.secondaryText)
                    if let notes = log.notes, !notes.isEmpty {
                        Text(notes)
                            .font(.caption)
                            .foregroundStyle(PulseTheme.tertiaryText)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
    }
}

private struct RehabLogSessionSheet: View {
    @Environment(\.dismiss) private var dismiss
    let exercise: RehabExercise
    let onSave: (_ setsCompleted: Int, _ painLevel: Int, _ notes: String?) -> Void

    @State private var setsCompleted: Double
    @State private var painLevel: Double = 3
    @State private var notes = ""

    init(exercise: RehabExercise, onSave: @escaping (Int, Int, String?) -> Void) {
        self.exercise = exercise
        self.onSave = onSave
        _setsCompleted = State(initialValue: Double(exercise.sets))
    }

    var body: some View {
        NavigationStack {
            Form {
                Section(localizedString("rehab_sets_completed")) {
                    InlineStepper(value: $setsCompleted, range: 0...20, step: 1) { "\(Int($0))" }
                }
                Section(localizedString("rehab_pain_scale_title")) {
                    InlineStepper(value: $painLevel, range: 0...10, step: 1) { "\(Int($0))" }
                }
                Section(localizedString("rehab_notes_section")) {
                    TextField(localizedString("rehab_notes_placeholder"), text: $notes, axis: .vertical)
                        .lineLimit(3...6)
                }
            }
            .navigationTitle(localizedString("rehab_log_session"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(localizedString("cancel")) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(localizedString("save")) {
                        onSave(Int(setsCompleted), Int(painLevel), notes.isEmpty ? nil : notes)
                        dismiss()
                    }
                    .fontWeight(.bold)
                }
            }
        }
    }
}
