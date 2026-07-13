import SwiftUI

// MARK: - Customizable Section

/// Conformed to by the per-screen "layout section" enums (Today, Train, Progress,
/// exercise filter chips/tiles) that back the Apple-Fitness-style Edit Layout sheet.
protocol CustomizableSection: CaseIterable, Identifiable where ID == String {
    var title: String { get }
    var systemImage: String { get }
}

// MARK: - Layout Resolver

/// Turns a screen's default section order plus the user's persisted order/hidden
/// preferences into the final render list, without ever offering an "add back" for
/// a section that isn't currently available given app state (no active plan, no
/// trend data yet, etc).
enum SectionLayoutResolver {
    /// `allCases` defaults to the full `S.allCases` set; pass a filtered array to
    /// keep some cases (e.g. a mandatory "All" filter chip) out of the
    /// reorder/hide system entirely — the caller renders those separately, pinned.
    static func resolve<S: CustomizableSection>(
        allCases: [S] = Array(S.allCases),
        storedOrder: [String],
        storedHidden: [String],
        available: (S) -> Bool = { _ in true }
    ) -> (visible: [S], hiddenAvailable: [S]) {
        let byID = Dictionary(uniqueKeysWithValues: allCases.map { ($0.id, $0) })
        let defaultOrderIDs = allCases.map(\.id)

        let baseOrderIDs = storedOrder.isEmpty ? defaultOrderIDs : storedOrder
        let knownBaseIDs = baseOrderIDs.filter { byID[$0] != nil }
        let missingIDs = defaultOrderIDs.filter { !knownBaseIDs.contains($0) }
        let orderedSections = (knownBaseIDs + missingIDs).compactMap { byID[$0] }

        let hiddenSet = Set(storedHidden)
        let visible = orderedSections.filter { available($0) && !hiddenSet.contains($0.id) }
        let hiddenAvailable = orderedSections.filter { available($0) && hiddenSet.contains($0.id) }
        return (visible, hiddenAvailable)
    }
}

// MARK: - Editor Sheet

/// A single reorderable/hideable list, mirroring Apple Fitness's "Edit Summary":
/// native drag handles + red "−" delete on the visible rows, a "More" section below
/// for hidden-but-available items with a tap-to-restore green "+".
struct SectionLayoutEditorSheet<S: CustomizableSection>: View {
    let title: String
    let onSave: (_ order: [String], _ hiddenIDs: [String]) -> Void

    @State private var visible: [S]
    @State private var hidden: [S]
    // A real `@State` binding, not `.constant(.active)` — a truly immutable
    // binding leaves List's row-tap gesture wiring half-broken for rows outside
    // the onMove/onDelete ForEach (the "More" restore rows stopped responding
    // to taps entirely when this was `.constant`).
    @State private var editMode: EditMode = .active
    @Environment(\.dismiss) private var dismiss

    init(title: String, visible: [S], hidden: [S], onSave: @escaping (_ order: [String], _ hiddenIDs: [String]) -> Void) {
        self.title = title
        self.onSave = onSave
        self._visible = State(initialValue: visible)
        self._hidden = State(initialValue: hidden)
    }

    var body: some View {
        NavigationStack {
            List {
                Section(localizedString("on_this_page")) {
                    ForEach(visible) { section in
                        SectionLayoutRow(title: section.title, systemImage: section.systemImage)
                    }
                    .onMove { indices, newOffset in
                        visible.move(fromOffsets: indices, toOffset: newOffset)
                    }
                    .onDelete { indices in
                        let removed = indices.map { visible[$0] }
                        visible.remove(atOffsets: indices)
                        hidden.append(contentsOf: removed)
                    }
                }
            }
            .environment(\.editMode, $editMode)
            // "More" is deliberately its own scroll region below the List, not a
            // second List Section — a List in active editMode disables normal
            // tap interaction on row content outside the onMove/onDelete ForEach,
            // so a tap-to-restore row placed there never receives its tap no
            // matter what gesture it uses (confirmed: Button, .onTapGesture, and
            // multiple axe tap styles all silently no-op there).
            .safeAreaInset(edge: .bottom) {
                if !hidden.isEmpty {
                    MoreSectionPanel(hidden: hidden) { section in
                        HapticService.selection()
                        hidden.removeAll { $0.id == section.id }
                        visible.append(section)
                    }
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(localizedString("done")) {
                        onSave(visible.map(\.id), hidden.map(\.id))
                        dismiss()
                    }
                    .fontWeight(.bold)
                }
            }
        }
    }
}

private struct SectionLayoutRow: View {
    let title: String
    let systemImage: String

    var body: some View {
        Label {
            Text(title)
                .font(.system(size: 15, weight: .semibold, design: .rounded))
        } icon: {
            Image(systemName: systemImage)
                .foregroundStyle(PulseTheme.accent)
                .frame(width: 24)
        }
    }
}

/// The "More" restore panel, shared by every layout editor sheet. Lives outside
/// any editing `List` (see the note above) so its rows stay tappable.
struct MoreSectionPanel<S: CustomizableSection>: View {
    let hidden: [S]
    let onRestore: (S) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(localizedString("more"))
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundStyle(PulseTheme.secondaryText)
                .textCase(.uppercase)
                .padding(.horizontal, 4)

            ScrollView {
                VStack(spacing: 0) {
                    ForEach(hidden) { section in
                        Button {
                            onRestore(section)
                        } label: {
                            HStack(spacing: 10) {
                                Image(systemName: "plus.circle.fill")
                                    .foregroundStyle(PulseTheme.recovery)
                                SectionLayoutRow(title: section.title, systemImage: section.systemImage)
                                Spacer(minLength: 0)
                            }
                            .padding(.vertical, 11)
                            .padding(.horizontal, 14)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)

                        if section.id != hidden.last?.id {
                            Divider().padding(.leading, 44)
                        }
                    }
                }
            }
            .frame(maxHeight: 220)
            .background(PulseTheme.grouped, in: RoundedRectangle(cornerRadius: PulseTheme.compactRadius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: PulseTheme.compactRadius, style: .continuous)
                    .stroke(PulseTheme.cardStroke, lineWidth: 0.8)
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 10)
        .padding(.bottom, 4)
        .background(.bar)
    }
}
