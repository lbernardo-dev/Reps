import Charts
import SwiftUI

// MARK: - Goals Hub

struct GoalsView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var filter: GoalFilter = .all
    @State private var activeSheet: GoalsSheet?

    enum GoalFilter: String, CaseIterable, Identifiable {
        case all, active, achieved
        var id: String { rawValue }
        var labelKey: LocalizedStringKey {
            switch self {
            case .all:      "goal_filter_all"
            case .active:   "goal_filter_active"
            case .achieved: "goal_filter_achieved"
            }
        }
    }

    private var filteredGoals: [Goal] {
        switch filter {
        case .all:      store.goals
        case .active:   store.goals.filter { !$0.isAchieved }
        case .achieved: store.goals.filter { $0.isAchieved }
        }
    }

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                summaryCard
                    .padding(.top, 4)

                filterChips

                if filteredGoals.isEmpty {
                    emptyState
                        .padding(.top, 20)
                } else {
                    ForEach(filteredGoals) { goal in
                        GoalCard(goal: goal) {
                            activeSheet = .editGoal(goal)
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 32)
        }
        .background(PulseTheme.background)
        .navigationTitle("goals_title")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    activeSheet = .newGoal
                } label: {
                    Image(systemName: "plus")
                        .fontWeight(.semibold)
                }
            }
        }
        .sheet(item: $activeSheet) { sheet in
            switch sheet {
            case .newGoal:
                GoalEditorView()
            case .editGoal(let goal):
                GoalEditorView(existingGoal: goal)
            }
        }
    }

    // MARK: Summary Card

    private var summaryCard: some View {
        PulseCard {
            HStack(spacing: 0) {
                summaryCell(
                    value: store.goals.filter { !$0.isAchieved }.count,
                    labelKey: "goal_summary_active",
                    color: PulseTheme.primary
                )
                Divider().frame(height: 40)
                summaryCell(
                    value: store.goals.filter { $0.isAchieved }.count,
                    labelKey: "goal_summary_achieved",
                    color: PulseTheme.recovery
                )
                Divider().frame(height: 40)
                summaryCell(
                    value: store.goals.count,
                    labelKey: "goal_summary_total",
                    color: PulseTheme.secondaryText
                )
            }
            .frame(maxWidth: .infinity)
        }
    }

    private func summaryCell(value: Int, labelKey: LocalizedStringKey, color: Color) -> some View {
        VStack(spacing: 4) {
            Text("\(value)")
                .font(.title2.bold())
                .foregroundStyle(color)
            Text(labelKey)
                .font(.caption)
                .foregroundStyle(PulseTheme.secondaryText)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: Filter chips

    private var filterChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(GoalFilter.allCases) { f in
                    Button { filter = f } label: {
                        PulseChip(title: f.labelKey, isSelected: filter == f)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 1)
        }
    }

    // MARK: Empty state

    private var emptyState: some View {
        PulseCard {
            PulseEmptyState(
                title: "goal_empty_title",
                message: "goal_empty_subtitle",
                systemImage: "target"
            )
            .padding(.vertical, 8)
            Button {
                activeSheet = .newGoal
            } label: {
                Label("goal_add_first", systemImage: "plus")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(PulseTheme.primary)
            }
            .buttonStyle(.plain)
            .padding(.top, 4)
        }
    }
}

// MARK: - Sheet enum

private enum GoalsSheet: Identifiable {
    case newGoal
    case editGoal(Goal)

    var id: String {
        switch self {
        case .newGoal: "new"
        case .editGoal(let g): g.id.uuidString
        }
    }
}

// MARK: - Goal Card

struct GoalCard: View {
    let goal: Goal
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            PulseCard(contentPadding: 0) {
                VStack(spacing: 0) {
                    HStack(alignment: .top, spacing: 14) {
                        kindIcon
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(goal.title)
                                    .font(.headline)
                                    .lineLimit(1)
                                Spacer()
                                statusBadge
                            }
                            if let deadline = goal.deadline {
                                Text(localizedFormat("goal_deadline_fmt", deadline.formatted(date: .abbreviated, time: .omitted)))
                                    .font(.caption)
                                    .foregroundStyle(goal.isOverdue ? PulseTheme.destructive : PulseTheme.secondaryText)
                            }
                            HStack(spacing: 4) {
                                Text(goal.current.formatted(.number.precision(.fractionLength(0...1))))
                                    .font(.subheadline.bold())
                                    .foregroundStyle(PulseTheme.primary)
                                Text("/ \(goal.target.formatted(.number.precision(.fractionLength(0...1)))) \(goal.unit)")
                                    .font(.subheadline)
                                    .foregroundStyle(PulseTheme.secondaryText)
                            }
                        }
                        Image(systemName: "chevron.right")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.tertiary)
                            .padding(.top, 4)
                    }
                    .padding(16)

                    progressBar
                }
            }
        }
        .buttonStyle(.plain)
    }

    private var kindIcon: some View {
        Image(systemName: goal.kind.systemImage)
            .font(.title3)
            .foregroundStyle(goal.kind.tint)
            .frame(width: 42, height: 42)
            .background(goal.kind.tint.opacity(0.12))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private var statusBadge: some View {
        Group {
            switch goal.status {
            case .achieved:
                Text("goal_badge_achieved")
                    .foregroundStyle(PulseTheme.recovery)
                    .background(PulseTheme.recovery.opacity(0.12))
            case .overdue:
                Text("goal_badge_overdue")
                    .foregroundStyle(PulseTheme.destructive)
                    .background(PulseTheme.destructive.opacity(0.12))
            case .active:
                Text("goal_badge_active")
                    .foregroundStyle(PulseTheme.primary)
                    .background(PulseTheme.primary.opacity(0.10))
            }
        }
        .font(.caption2.weight(.semibold))
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .clipShape(Capsule())
    }

    private var progressBar: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Rectangle()
                    .fill(PulseTheme.grouped)
                Rectangle()
                    .fill(progressColor)
                    .frame(width: proxy.size.width * goal.progress)
                    .animation(.spring(duration: 0.5), value: goal.progress)
            }
        }
        .frame(height: 4)
        .clipShape(Rectangle())
    }

    private var progressColor: Color {
        switch goal.status {
        case .achieved: PulseTheme.recovery
        case .overdue:  PulseTheme.destructive
        case .active:   PulseTheme.primary
        }
    }
}

// MARK: - Goal Editor

struct GoalEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppStore.self) private var store

    var existingGoal: Goal?

    @State private var kind: Goal.Kind = .strength
    @State private var title = ""
    @State private var current = ""
    @State private var target = ""
    @State private var unit = "kg"
    @State private var hasDeadline = false
    @State private var deadline = Date.now.addingTimeInterval(60 * 60 * 24 * 90)
    @State private var showDeleteConfirm = false

    private var isEditing: Bool { existingGoal != nil }
    private var canSave: Bool {
        !title.trimmingCharacters(in: .whitespaces).isEmpty
            && Double(target.replacingOccurrences(of: ",", with: ".")) != nil
    }

    var body: some View {
        NavigationStack {
            Form {
                kindSection
                detailsSection
                valuesSection
                deadlineSection
                if isEditing {
                    deleteSection
                }
            }
            .navigationTitle(isEditing ? "goal_edit_title" : "goal_new_title")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("cancel") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("save") { save() }
                        .fontWeight(.semibold)
                        .disabled(!canSave)
                }
            }
            .onAppear { loadExisting() }
            .confirmationDialog("goal_delete_confirm_title", isPresented: $showDeleteConfirm, titleVisibility: .visible) {
                Button("goal_delete_action", role: .destructive) { deleteGoal() }
                Button("cancel", role: .cancel) {}
            } message: {
                Text("goal_delete_confirm_message")
            }
        }
    }

    // MARK: Kind picker section

    private var kindSection: some View {
        Section {
            ForEach(Goal.Kind.allCases) { k in
                Button {
                    withAnimation(.spring(duration: 0.25)) {
                        kind = k
                        applyKindDefaults(k)
                    }
                } label: {
                    HStack(spacing: 14) {
                        Image(systemName: k.systemImage)
                            .font(.headline)
                            .foregroundStyle(k.tint)
                            .frame(width: 36, height: 36)
                            .background(k.tint.opacity(0.12))
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        VStack(alignment: .leading, spacing: 2) {
                            Text(k.localizedDisplayName)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.primary)
                            Text(k.hintKey)
                                .font(.caption)
                                .foregroundStyle(PulseTheme.secondaryText)
                        }
                        Spacer()
                        if kind == k {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(PulseTheme.primary)
                        }
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        } header: {
            Text("goal_kind_label")
        }
    }

    // MARK: Details section

    private var detailsSection: some View {
        Section {
            TextField("goal_title_placeholder", text: $title)
        } header: {
            Text("goal_title_label")
        }
    }

    // MARK: Values section

    private var valuesSection: some View {
        Section {
            HStack {
                Text("goal_current_label")
                    .foregroundStyle(PulseTheme.secondaryText)
                Spacer()
                TextField("0", text: $current)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                    .frame(width: 100)
                Text(unit)
                    .foregroundStyle(PulseTheme.secondaryText)
                    .frame(width: 40, alignment: .leading)
            }
            HStack {
                Text("goal_target_label")
                    .foregroundStyle(PulseTheme.secondaryText)
                Spacer()
                TextField("0", text: $target)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                    .frame(width: 100)
                Text(unit)
                    .foregroundStyle(PulseTheme.secondaryText)
                    .frame(width: 40, alignment: .leading)
            }
            HStack {
                Text("goal_unit_label")
                    .foregroundStyle(PulseTheme.secondaryText)
                Spacer()
                TextField("kg", text: $unit)
                    .multilineTextAlignment(.trailing)
                    .frame(width: 140)
            }
        } header: {
            Text("goal_values_label")
        }
    }

    // MARK: Deadline section

    private var deadlineSection: some View {
        Section {
            Toggle(isOn: $hasDeadline.animation()) {
                Text("goal_set_deadline")
            }
            if hasDeadline {
                DatePicker(
                    "goal_deadline_label",
                    selection: $deadline,
                    in: Date.now...,
                    displayedComponents: .date
                )
            }
        }
    }

    // MARK: Delete section

    private var deleteSection: some View {
        Section {
            Button(role: .destructive) {
                showDeleteConfirm = true
            } label: {
                HStack {
                    Spacer()
                    Text("goal_delete_action")
                    Spacer()
                }
            }
        }
    }

    // MARK: Logic

    private func loadExisting() {
        guard let g = existingGoal else { return }
        kind = g.kind
        title = g.title
        current = g.current > 0 ? String(format: "%g", g.current) : ""
        target = g.target > 0 ? String(format: "%g", g.target) : ""
        unit = g.unit
        if let d = g.deadline {
            hasDeadline = true
            deadline = d
        }
    }

    private func applyKindDefaults(_ k: Goal.Kind) {
        guard !isEditing else { return }
        unit = k.defaultUnit(weightUnit: store.displayedWeight.unit)
        if current.isEmpty {
            switch k {
            case .bodyWeight:
                let w = store.displayedWeight.value
                if w > 0 { current = String(format: "%g", w) }
            case .strength:
                let orm = store.bestEstimatedOneRepMaxKg
                if orm > 0 {
                    let v = store.userProfile.units == .imperial
                        ? UnitConverter.pounds(fromKilograms: orm)
                        : orm
                    current = String(format: "%.0f", v)
                }
            default: break
            }
        }
    }

    private func save() {
        let currentVal = Double(current.replacingOccurrences(of: ",", with: ".")) ?? 0
        let targetVal = Double(target.replacingOccurrences(of: ",", with: ".")) ?? 0
        let dl: Date? = hasDeadline ? deadline : nil

        if var g = existingGoal {
            g.kind = kind
            g.title = title.trimmingCharacters(in: .whitespaces)
            g.current = currentVal
            g.target = targetVal
            g.unit = unit.trimmingCharacters(in: .whitespaces)
            g.deadline = dl
            store.updateGoal(g)
        } else {
            store.addGoal(Goal(
                kind: kind,
                title: title.trimmingCharacters(in: .whitespaces),
                current: currentVal,
                target: targetVal,
                unit: unit.trimmingCharacters(in: .whitespaces),
                deadline: dl
            ))
        }
        dismiss()
    }

    private func deleteGoal() {
        if let g = existingGoal {
            store.deleteGoal(id: g.id)
        }
        dismiss()
    }
}

// MARK: - Goal.Kind display helpers

extension Goal.Kind {
    var systemImage: String {
        switch self {
        case .strength:    "dumbbell.fill"
        case .consistency: "calendar.badge.checkmark"
        case .bodyWeight:  "scalemass.fill"
        case .custom:      "star.fill"
        }
    }

    var tint: Color {
        switch self {
        case .strength:    PulseTheme.primary
        case .consistency: PulseTheme.recovery
        case .bodyWeight:  PulseTheme.accent
        case .custom:      PulseTheme.primaryBright
        }
    }

    var localizedDisplayName: String {
        switch self {
        case .strength:    localizedString("goal_kind_strength")
        case .consistency: localizedString("goal_kind_consistency")
        case .bodyWeight:  localizedString("goal_kind_bodyweight")
        case .custom:      localizedString("goal_kind_custom")
        }
    }

    var hintKey: LocalizedStringKey {
        switch self {
        case .strength:    "goal_kind_strength_hint"
        case .consistency: "goal_kind_consistency_hint"
        case .bodyWeight:  "goal_kind_bodyweight_hint"
        case .custom:      "goal_kind_custom_hint"
        }
    }

    func defaultUnit(weightUnit: String) -> String {
        switch self {
        case .strength:    weightUnit
        case .consistency: localizedString("goal_unit_sessions")
        case .bodyWeight:  weightUnit
        case .custom:      ""
        }
    }
}
