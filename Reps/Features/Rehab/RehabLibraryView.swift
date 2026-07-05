import SwiftUI

/// Catalog of rehabilitation exercises (tendons, joints, muscles), reached
/// from a card at the top of the Ejercicios tab. Entirely offline: the
/// catalog is bundled Swift data (`RehabSeedData`), no network fetch, no
/// downloaded images.
struct RehabLibraryView: View {
    @Environment(AppStore.self) private var store

    @State private var searchText = ""
    @State private var selectedStructure: RehabExercise.StructureFocus?

    private var language: String { store.userProfile.preferredLanguage }

    private var filteredExercises: [RehabExercise] {
        store.rehabCatalog.filter { exercise in
            guard selectedStructure == nil || exercise.structureFocus == selectedStructure else { return false }
            guard !searchText.isEmpty else { return true }
            let searchable = [
                exercise.name.resolved(language: language),
                exercise.bodyRegion.title.resolved(language: language),
                exercise.structureFocus.title.resolved(language: language)
            ].joined(separator: " ")
            return searchable.localizedStandardContains(searchText)
        }
    }

    private var groupedExercises: [(RehabExercise.BodyRegion, [RehabExercise])] {
        let grouped = Dictionary(grouping: filteredExercises, by: \.bodyRegion)
        return RehabExercise.BodyRegion.allCases.compactMap { region in
            guard let items = grouped[region], !items.isEmpty else { return nil }
            return (region, items.sorted { $0.name.resolved(language: language) < $1.name.resolved(language: language) })
        }
    }

    var body: some View {
        List {
            Section {
                RehabDisclaimerBanner(text: RehabSeedData.disclaimer.resolved(language: language))

                HStack(spacing: 10) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(PulseTheme.secondaryText)
                    TextField(localizedString("Search exercises"), text: $searchText)
                        .textFieldStyle(.plain)
                    if !searchText.isEmpty {
                        Button {
                            searchText = ""
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(PulseTheme.tertiaryText)
                        }
                        .buttonStyle(.plain)
                    }
                }

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        structureFilterPill(nil, title: localizedString("All"), systemImage: "square.grid.2x2")
                        ForEach(RehabExercise.StructureFocus.allCases) { structure in
                            structureFilterPill(structure, title: structure.title.resolved(language: language), systemImage: structure.systemImage)
                        }
                    }
                    .padding(.vertical, 2)
                }
            }

            if filteredExercises.isEmpty {
                Section {
                    PulseEmptyState(
                        title: "no_exercises_found",
                        message: "try_removing_a_filter_or_searching_by_muscle_equipment_or_exercise_name",
                        systemImage: "line.3.horizontal.decrease.circle"
                    )
                }
            } else {
                ForEach(groupedExercises, id: \.0) { region, exercises in
                    Section(region.title.resolved(language: language)) {
                        ForEach(exercises) { exercise in
                            NavigationLink {
                                RehabExerciseDetailView(exercise: exercise)
                            } label: {
                                RehabExerciseRow(exercise: exercise, language: language)
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle(localizedString("rehab_section_title"))
        .navigationBarTitleDisplayMode(.inline)
        .mainTabBarHidden()
    }

    @ViewBuilder
    private func structureFilterPill(_ structure: RehabExercise.StructureFocus?, title: String, systemImage: String) -> some View {
        let isSelected = selectedStructure == structure
        Button {
            selectedStructure = structure
        } label: {
            Label(title, systemImage: systemImage)
                .font(.caption.weight(.semibold))
                .lineLimit(1)
                .padding(.horizontal, 12)
                .padding(.vertical, 9)
                .foregroundStyle(isSelected ? PulseTheme.onColor(PulseTheme.accent) : PulseTheme.accent)
                .background(isSelected ? PulseTheme.accent : PulseTheme.accent.opacity(0.10))
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}

/// Entry point into the rehab catalog, shown at the top of the Ejercicios
/// tab list (`ExerciseLibraryView`) rather than as a 6th tab — the app's tab
/// bar is a deliberately fixed 5-tab IA (see `RootView.AppTab`).
struct RehabEntryCard: View {
    var body: some View {
        HStack(spacing: 14) {
            PulseIconBadge(systemImage: "figure.walk.motion", tint: PulseTheme.ringStand, size: 48, isFilled: true)
            VStack(alignment: .leading, spacing: 3) {
                Text(localizedString("rehab_section_title"))
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)
                Text(localizedString("rehab_entry_card_subtitle"))
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(PulseTheme.secondaryText)
                    .lineLimit(2)
            }
            Spacer(minLength: 8)
            Image(systemName: "chevron.right")
                .font(.caption.weight(.bold))
                .foregroundStyle(PulseTheme.tertiaryText)
        }
        .padding(12)
        .background(PulseTheme.ringStand.opacity(0.08), in: RoundedRectangle(cornerRadius: PulseTheme.cardRadius, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: PulseTheme.cardRadius, style: .continuous)
                .stroke(PulseTheme.ringStand.opacity(0.22), lineWidth: 0.8)
        }
        .contentShape(RoundedRectangle(cornerRadius: PulseTheme.cardRadius, style: .continuous))
    }
}

private struct RehabExerciseRow: View {
    let exercise: RehabExercise
    let language: String

    private var dosageSummary: String {
        var parts: [String] = ["\(exercise.sets)×"]
        if let holdSeconds = exercise.holdSeconds {
            parts[0] += String(format: localizedString("rehab_hold_seconds_format"), holdSeconds)
        } else if let reps = exercise.reps {
            parts[0] += "\(reps)"
        }
        return parts.joined()
    }

    var body: some View {
        HStack(spacing: 14) {
            PulseIconBadge(systemImage: exercise.bodyRegion.systemImage, tint: PulseTheme.ringStand, size: 48)
            VStack(alignment: .leading, spacing: 4) {
                Text(exercise.name.resolved(language: language))
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)
                    .lineLimit(2)
                    .minimumScaleFactor(0.82)
                Text("\(exercise.structureFocus.title.resolved(language: language)) · \(exercise.protocolType.title.resolved(language: language)) · \(dosageSummary)")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(PulseTheme.secondaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)
            }
            .layoutPriority(1)
            Spacer(minLength: 8)
        }
        .padding(.vertical, 8)
        .contentShape(Rectangle())
    }
}

/// Educational-content disclaimer shown at the top of the rehab library and
/// on every exercise detail — see plan §"Diseño de datos" for rationale.
struct RehabDisclaimerBanner: View {
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "cross.case.fill")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(PulseTheme.warning)
            Text(text)
                .font(.footnote)
                .foregroundStyle(PulseTheme.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(12)
        .background(PulseTheme.warning.opacity(0.10), in: RoundedRectangle(cornerRadius: PulseTheme.compactRadius, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: PulseTheme.compactRadius, style: .continuous)
                .stroke(PulseTheme.warning.opacity(0.28), lineWidth: 0.8)
        }
    }
}
