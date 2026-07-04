import MuscleMap
import SwiftUI

struct ProgramLibraryView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppStore.self) private var store
    @State private var selectedCategory: SeedData.ProgramMetadata.Category? = nil

    private var filteredPlans: [WorkoutPlan] {
        SeedData.defaultPlans.filter { plan in
            guard let category = selectedCategory else { return true }
            return SeedData.programMetadata[plan.name]?.category == category
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 20) {
                    ProgramLibraryHero(
                        programCount: filteredPlans.count,
                        totalPrograms: SeedData.defaultPlans.count,
                        selectedCategory: selectedCategory
                    )
                    categoryFilter
                    programList
                }
                .padding(.horizontal, PulseTheme.screenHorizontalPadding)
                .padding(.top, 8)
                .padding(.bottom, 96)
            }
            .scrollBounceBehavior(.basedOnSize, axes: .vertical)
            .navigationTitle(localizedString("program_library_title"))
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(PulseTheme.textPrimary)
                            .frame(width: 32, height: 32)
                            .destructiveGlassCircle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .screenBackground()
        }
    }

    private var categoryFilter: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ProgramCategoryChip(
                    title: localizedString("all_programs_filter"),
                    systemImage: "square.grid.2x2.fill",
                    isSelected: selectedCategory == nil
                ) {
                    withAnimation(.snappy(duration: 0.18)) { selectedCategory = nil }
                }
                ForEach(SeedData.ProgramMetadata.Category.allCases) { cat in
                    ProgramCategoryChip(
                        title: cat.displayName,
                        systemImage: cat.systemImage,
                        isSelected: selectedCategory == cat
                    ) {
                        withAnimation(.snappy(duration: 0.18)) {
                            selectedCategory = selectedCategory == cat ? nil : cat
                        }
                    }
                }
            }
            .padding(.horizontal, 2)
        }
        .scrollBounceBehavior(.basedOnSize, axes: .horizontal)
    }

    private var programList: some View {
        LazyVStack(spacing: 14) {
            ForEach(filteredPlans) { plan in
                NavigationLink {
                    ProgramDetailView(plan: plan) { dismiss() }
                } label: {
                    ProgramCard(plan: plan)
                }
                .buttonStyle(.plain)
            }
        }
    }
}

// MARK: - Detail

struct ProgramDetailView: View {
    @Environment(AppStore.self) private var store
    let plan: WorkoutPlan
    let onActivated: () -> Void

    private var planExercises: [Exercise] {
        plan.days.flatMap { $0.exercises.map(\.exercise) }
    }

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 16) {
                headerCard

                if !planExercises.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        SectionHeader(title: "muscles_worked")
                        WorkoutMusclePreview(exercises: planExercises, gender: store.userProfile.muscleMapGender)
                            .frame(maxWidth: .infinity)
                            .frame(height: 300)
                    }
                }

                SectionHeader(title: "training_days_section")
                ForEach(plan.days) { day in
                    NavigationLink {
                        WorkoutDetailView(workout: day)
                    } label: {
                        ProgramDayCard(day: day, gender: store.userProfile.muscleMapGender, catalog: store.exercises)
                    }
                    .buttonStyle(.plain)
                }
                activateButton
            }
            .padding(.horizontal, PulseTheme.screenHorizontalPadding)
            .padding(.top, 8)
            .padding(.bottom, 96)
        }
        .scrollBounceBehavior(.basedOnSize, axes: .vertical)
        .navigationTitle(plan.name)
        .navigationBarTitleDisplayMode(.inline)
        .screenBackground()
    }

    private var headerCard: some View {
        PulseCard(contentPadding: 18) {
            VStack(alignment: .leading, spacing: 16) {
                if let meta = SeedData.programMetadata[plan.name] {
                    HStack(spacing: 8) {
                        ProgramCategoryBadge(category: meta.category)
                        ProgramLevelBadge(level: meta.level)
                    }
                    Text(plan.name)
                        .font(.system(size: 30, weight: .black, design: .rounded))
                        .lineLimit(2)
                        .minimumScaleFactor(0.72)
                    Text(meta.tagline)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(PulseTheme.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                } else {
                    Text(plan.name)
                        .font(.system(size: 30, weight: .black, design: .rounded))
                        .lineLimit(2)
                        .minimumScaleFactor(0.72)
                }

                HStack(spacing: 8) {
                    ProgramStatCell(
                        value: "\(plan.daysPerWeek)",
                        label: localizedString("days_per_week_short"),
                        icon: "calendar"
                    )
                    ProgramStatCell(
                        value: "\(plan.totalWeeks)w",
                        label: localizedString("duration_label"),
                        icon: "clock"
                    )
                    ProgramStatCell(
                        value: plan.location.rawValue,
                        label: localizedString("location_label"),
                        icon: "mappin"
                    )
                }
            }
        }
    }

    private var activateButton: some View {
        Button {
            guard store.monetization.hasProAccess else {
                HapticService.selection()
                store.presentPaywall(source: .planActivation, feature: nil, trigger: .featureGate)
                return
            }
            HapticService.impact(.medium)
            var fresh = plan
            fresh.id = UUID()
            fresh.currentWeek = 1
            fresh.completion = 0
            store.addPlan(fresh, activate: true, fromCatalog: true)
            onActivated()
        } label: {
            HStack(spacing: 8) {
                if !store.monetization.hasProAccess {
                    Image(systemName: "lock.fill")
                }
                Text(localizedString(store.monetization.hasProAccess ? "activate_program_button" : "unlock_with_pro_button"))
            }
            .font(.headline)
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .foregroundStyle(PulseTheme.onColor(PulseTheme.accent))
            .background(PulseTheme.fitActionGradient)
            .clipShape(RoundedRectangle(cornerRadius: PulseTheme.compactRadius, style: .continuous))
        }
        .buttonStyle(.plain)
        .padding(.top, 4)
    }
}

// MARK: - Subcomponents

private struct ProgramLibraryHero: View {
    let programCount: Int
    let totalPrograms: Int
    let selectedCategory: SeedData.ProgramMetadata.Category?

    var body: some View {
        PulseCard(contentPadding: 18) {
            VStack(alignment: .leading, spacing: 15) {
                HStack(alignment: .top, spacing: 14) {
                    Image(systemName: selectedCategory?.systemImage ?? "sparkles")
                        .font(.title2.weight(.black))
                        .foregroundStyle(PulseTheme.onColor(PulseTheme.accent))
                        .frame(width: 56, height: 56)
                        .background(PulseTheme.fitActionGradient, in: RoundedRectangle(cornerRadius: PulseTheme.compactRadius, style: .continuous))

                    VStack(alignment: .leading, spacing: 5) {
                        Text(localizedString("program_library_title"))
                            .font(.system(size: 28, weight: .black, design: .rounded))
                            .lineLimit(2)
                            .minimumScaleFactor(0.75)
                        Text(selectedCategory?.displayName ?? "Choose a proven block for your current goal.")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(PulseTheme.secondaryText)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                HStack(spacing: 8) {
                    ProgramHeroMetric(value: "\(programCount)", label: "Shown", systemImage: "square.grid.2x2")
                    ProgramHeroMetric(value: "\(totalPrograms)", label: "Total", systemImage: "rectangle.stack")
                    ProgramHeroMetric(value: "\(SeedData.ProgramMetadata.Category.allCases.count)", label: "Goals", systemImage: "scope")
                }
            }
        }
    }
}

private struct ProgramHeroMetric: View {
    let value: String
    let label: String
    let systemImage: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: systemImage)
                .font(.caption.weight(.black))
                .foregroundStyle(PulseTheme.accent)
            VStack(alignment: .leading, spacing: 1) {
                Text(value)
                    .font(.headline.weight(.black))
                Text(label)
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(PulseTheme.secondaryText)
            }
            Spacer(minLength: 0)
        }
        .padding(10)
        .frame(maxWidth: .infinity)
        .background(PulseTheme.grouped, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

private struct ProgramCard: View {
    @Environment(AppStore.self) private var store
    let plan: WorkoutPlan
    private var meta: SeedData.ProgramMetadata? { SeedData.programMetadata[plan.name] }

    private var heroExercise: Exercise? {
        plan.days.first?.exercises.first?.exercise
    }

    var body: some View {
        PulseCard(contentPadding: 16) {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top, spacing: 14) {
                ZStack(alignment: .bottomTrailing) {
                    Group {
                        if let heroExercise {
                            ExerciseMediaThumbnail(exercise: heroExercise, gender: store.userProfile.muscleMapGender, catalog: store.exercises)
                        } else {
                            Image(systemName: meta?.category.systemImage ?? "dumbbell.fill")
                                .font(.system(size: 20, weight: .black))
                                .foregroundStyle(PulseTheme.onColor(PulseTheme.accent))
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                                .background(PulseTheme.fitActionGradient)
                        }
                    }
                    .frame(width: 52, height: 52)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay(alignment: .topLeading) {
                        Image(systemName: meta?.category.systemImage ?? "dumbbell.fill")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundStyle(PulseTheme.onColor(PulseTheme.accent))
                            .frame(width: 16, height: 16)
                            .background(PulseTheme.fitActionGradient, in: Circle())
                            .offset(x: -4, y: -4)
                    }

                    if !store.monetization.hasProAccess {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(width: 17, height: 17)
                            .background(.ultraThinMaterial, in: Circle())
                            .overlay(Circle().stroke(Color.white.opacity(0.15), lineWidth: 0.8))
                            .shadow(color: .black.opacity(0.2), radius: 2)
                            .offset(x: 4, y: 4)
                    }
                }

                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        if let meta { ProgramLevelBadge(level: meta.level) }
                        Spacer()
                        HStack(spacing: 4) {
                            Image(systemName: "calendar")
                                .font(.caption2)
                            Text("\(plan.daysPerWeek)d · \(plan.totalWeeks)w")
                                .font(.caption)
                        }
                        .foregroundStyle(PulseTheme.secondaryText)
                    }
                    Text(plan.name)
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundStyle(.primary)
                    if let tagline = meta?.tagline {
                        Text(tagline)
                            .font(.caption)
                        .foregroundStyle(PulseTheme.secondaryText)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                    }
                }
                }

                HStack(spacing: 8) {
                    ProgramCardMetric(value: "\(plan.daysPerWeek)d", label: localizedString("days_per_week_short"), systemImage: "calendar")
                    ProgramCardMetric(value: "\(plan.totalWeeks)w", label: localizedString("duration_label"), systemImage: "clock")
                    ProgramCardMetric(value: "\(plan.days.reduce(0) { $0 + $1.exercises.count })", label: localizedString("exercises_2"), systemImage: "dumbbell.fill")
                }
            }
        }
    }
}

private struct ProgramCardMetric: View {
    let value: String
    let label: String
    let systemImage: String

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: systemImage)
                .font(.caption2.weight(.black))
                .foregroundStyle(PulseTheme.accent)
            VStack(alignment: .leading, spacing: 1) {
                Text(value)
                    .font(.caption.weight(.black))
                Text(label)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(PulseTheme.secondaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            Spacer(minLength: 0)
        }
        .padding(8)
        .frame(maxWidth: .infinity)
        .background(PulseTheme.grouped, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}

private struct ProgramDayCard: View {
    let day: WorkoutDay
    let gender: BodyGender
    let catalog: [Exercise]

    var body: some View {
        PulseCard {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(day.title)
                            .font(.headline)
                        Text(day.subtitle)
                            .font(.caption)
                            .foregroundStyle(PulseTheme.secondaryText)
                    }
                    Spacer()
                    Text("\(day.durationMinutes) min")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(PulseTheme.secondaryText)
                }

                if !day.exercises.isEmpty {
                    Divider()
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(day.exercises.prefix(3)) { ex in
                            HStack(spacing: 8) {
                                ExerciseMediaThumbnail(exercise: ex.exercise, gender: gender, catalog: catalog)
                                    .frame(width: 30, height: 30)
                                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                                Text(ex.exercise.name)
                                    .font(.caption)
                                Spacer()
                                Text("\(ex.targetSets)×\(ex.repRange)")
                                    .font(.caption)
                                    .foregroundStyle(PulseTheme.secondaryText)
                            }
                        }
                        if day.exercises.count > 3 {
                            Text("+ \(day.exercises.count - 3) " + localizedString("more_exercises_suffix"))
                                .font(.caption)
                                .foregroundStyle(PulseTheme.secondaryText)
                                .padding(.leading, 38)
                        }
                    }
                }
            }
        }
    }
}

struct ProgramCategoryChip: View {
    let title: String
    let systemImage: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Image(systemName: systemImage)
                    .font(.caption.weight(.semibold))
                Text(title)
                    .font(.caption.weight(.semibold))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .foregroundStyle(isSelected ? .white : .primary)
            .background(isSelected ? PulseTheme.accent : PulseTheme.card)
            .clipShape(Capsule())
            .overlay(Capsule().stroke(isSelected ? Color.clear : PulseTheme.separator, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
}

struct ProgramLevelBadge: View {
    let level: SeedData.ProgramMetadata.Level

    var body: some View {
        Text(level.displayName)
            .font(.caption2.weight(.bold))
            .tracking(0.5)
            .textCase(.uppercase)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .foregroundStyle(levelColor)
            .background(levelColor.opacity(0.12))
            .clipShape(Capsule())
    }

    private var levelColor: Color {
        switch level {
        case .beginner:     return PulseTheme.recovery
        case .intermediate: return PulseTheme.warning
        case .advanced:     return PulseTheme.destructive
        }
    }
}

struct ProgramCategoryBadge: View {
    let category: SeedData.ProgramMetadata.Category

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: category.systemImage)
                .font(.caption2.weight(.semibold))
            Text(category.displayName)
                .font(.caption.weight(.semibold))
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .foregroundStyle(PulseTheme.accent)
        .background(PulseTheme.accent.opacity(0.12))
        .clipShape(Capsule())
    }
}

private struct ProgramStatCell: View {
    let value: String
    let label: String
    let icon: String

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(PulseTheme.secondaryText)
            Text(value)
                .font(.system(size: 15, weight: .bold, design: .rounded))
            Text(label)
                .font(.caption2)
                .foregroundStyle(PulseTheme.secondaryText)
        }
        .frame(maxWidth: .infinity)
    }
}
