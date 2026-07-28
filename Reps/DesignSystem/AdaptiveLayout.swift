import SwiftUI

// MARK: - Adaptive width tokens
//
// iPad support was re-enabled after Apple rejected the app for a layout that
// shipped as a stretched iPhone screen (Guideline 4). These primitives are
// the shared foundation every tab adapts through: gate on `horizontalSizeClass`,
// never on `UIDevice.userInterfaceIdiom` — idiom still reports `.phone` when
// this app runs via the iPhone compatibility window on iPad, and iPadOS 26's
// resizable/Stage Manager windows make width a continuum, not two fixed
// orientations. See PulseTheme.mainTabFooterClearance for the idiom pitfall
// this already burned once.
extension PulseTheme {
    /// Max width for single-column reading content (cards, forms, lists)
    /// centered on regular-width canvases so it doesn't stretch edge-to-edge.
    static let maxContentWidth: CGFloat = 700
    /// Max width for multi-column/grid content on regular-width canvases.
    static let maxContentWidthWide: CGFloat = 960
}

private struct AdaptiveContentWidthModifier: ViewModifier {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    let maxWidth: CGFloat

    func body(content: Content) -> some View {
        if horizontalSizeClass == .regular {
            content
                .frame(maxWidth: maxWidth)
                .frame(maxWidth: .infinity, alignment: .top)
        } else {
            content
        }
    }
}

extension View {
    /// Caps and centers content at `maxWidth` on regular-width canvases
    /// (iPad, or an iPhone-only app's compat window resized wide under
    /// Stage Manager); a no-op on compact width. Apply at a tab root's
    /// outermost scrollable container to stop full-bleed card stretching.
    func adaptiveContentWidth(_ maxWidth: CGFloat = PulseTheme.maxContentWidth) -> some View {
        modifier(AdaptiveContentWidthModifier(maxWidth: maxWidth))
    }
}

// MARK: - Size class convenience

private struct IsRegularWidthKey: EnvironmentKey {
    static let defaultValue = false
}

extension EnvironmentValues {
    /// True when `horizontalSizeClass == .regular`. Prefer this over reading
    /// `horizontalSizeClass` directly so call sites read naturally and stay
    /// consistent with the idiom-vs-size-class distinction documented above.
    var isRegularWidth: Bool {
        get { self[IsRegularWidthKey.self] }
        set { self[IsRegularWidthKey.self] = newValue }
    }
}

private struct PropagateRegularWidthModifier: ViewModifier {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    func body(content: Content) -> some View {
        content.environment(\.isRegularWidth, horizontalSizeClass == .regular)
    }
}

extension View {
    /// Populates `\.isRegularWidth` from the current `horizontalSizeClass`.
    /// Apply once near a tab root; descendants can then read
    /// `@Environment(\.isRegularWidth)` without their own size-class plumbing.
    func propagatingRegularWidth() -> some View {
        modifier(PropagateRegularWidthModifier())
    }
}

// MARK: - Adaptive card grid

/// A grid that lays out as a single column on compact width and as an
/// adaptive multi-column grid on regular width. Intended for naturally
/// grid-shaped content (Progress summary/trend cards, the exercise library
/// grid) — not a general replacement for single-column stacks.
struct AdaptiveCardGrid<Content: View>: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    let minColumnWidth: CGFloat
    let spacing: CGFloat
    @ViewBuilder let content: Content

    init(
        minColumnWidth: CGFloat = 300,
        spacing: CGFloat = PulseTheme.spacingM,
        @ViewBuilder content: () -> Content
    ) {
        self.minColumnWidth = minColumnWidth
        self.spacing = spacing
        self.content = content()
    }

    var body: some View {
        if horizontalSizeClass == .regular {
            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: minColumnWidth), spacing: spacing)],
                spacing: spacing
            ) {
                content
            }
        } else {
            LazyVStack(spacing: spacing) {
                content
            }
        }
    }
}

// MARK: - Sheet presentation

extension View {
    /// Standard sheet presentation for the whole app: explicit detents plus
    /// `.presentationCompactAdaptation(.sheet)` so a sheet never silently
    /// becomes a popover on a regular-width canvas — the app has zero
    /// popover-based interactions today, and introducing one implicitly via
    /// the default iPad sheet adaptation would be a bigger, uncoordinated
    /// interaction change than this pass is meant to make.
    func repsSheetPresentation(detents: Set<PresentationDetent> = [.large]) -> some View {
        presentationDetents(detents)
            .presentationCompactAdaptation(.sheet)
            .presentationDragIndicator(detents.contains(.large) ? .hidden : .visible)
    }
}
