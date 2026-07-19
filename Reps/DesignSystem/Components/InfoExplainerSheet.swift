import SwiftUI

/// A single explanation block inside an `InfoExplainerSheet` (a heading + body of prose).
struct InfoExplainerSection: Identifiable {
    let id = UUID()
    let heading: String
    let body: String
}

/// Modal "tap ? to learn more" sheet used across the app to explain the science/formula
/// behind a metric — mirrors the competitive audit's "About hydration" / "About sleep" pattern.
struct InfoExplainerSheet: View {
    @Environment(\.dismiss) private var dismiss
    let title: String
    var icon: String = "sparkles"
    let sections: [InfoExplainerSection]

    var body: some View {
        NavigationStack {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 18) {
                    HStack(spacing: 12) {
                        Image(systemName: icon)
                            .font(.title2.weight(.bold))
                            .frame(width: 44, height: 44)
                            .foregroundStyle(PulseTheme.onColor(PulseTheme.accent))
                            .background(PulseTheme.accent)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                        Text(localizedKey(title))
                            .font(.system(size: 22, weight: .bold, design: .rounded))
                            .fixedSize(horizontal: false, vertical: true)

                        Spacer(minLength: 0)
                    }

                    ForEach(sections) { section in
                        VStack(alignment: .leading, spacing: 6) {
                            Text(localizedKey(section.heading))
                                .font(.subheadline.weight(.bold))
                            Text(localizedKey(section.body))
                                .font(.subheadline)
                                .foregroundStyle(PulseTheme.secondaryText)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(14)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(PulseTheme.grouped)
                        .clipShape(RoundedRectangle(cornerRadius: PulseTheme.compactRadius, style: .continuous))
                    }
                }
                .padding(.horizontal, PulseTheme.screenHorizontalPadding)
                .padding(.top, 8)
                .padding(.bottom, 40)
            }
            .screenBackground()
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        HapticService.selection()
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(PulseTheme.textPrimary)
                            .frame(width: 30, height: 30)
                            .background(PulseTheme.grouped)
                            .clipShape(Circle())
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }
}

/// Small "?" affordance that owns its own presentation state — drop next to any metric
/// to give it a tap-to-explain popup without call sites managing a `@State` flag themselves.
struct InfoButton: View {
    private let title: String
    private let icon: String
    private let sheetIcon: String
    private let sections: [InfoExplainerSection]
    @State private var isPresented = false

    init(
        _ title: String,
        icon: String = "questionmark.circle.fill",
        sheetIcon: String = "sparkles",
        sections: [InfoExplainerSection]
    ) {
        self.title = title
        self.icon = icon
        self.sheetIcon = sheetIcon
        self.sections = sections
    }

    var body: some View {
        Button {
            HapticService.selection()
            isPresented = true
        } label: {
            Image(systemName: icon)
                .font(.subheadline)
                .foregroundStyle(PulseTheme.secondaryText)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(localizedKey(title))
        .sheet(isPresented: $isPresented) {
            InfoExplainerSheet(title: title, icon: sheetIcon, sections: sections)
        }
    }
}

#Preview("Info Explainer") {
    Color.clear
        .screenBackground()
        .sheet(isPresented: .constant(true)) {
            InfoExplainerSheet(
                title: "recovery_factor_title",
                sections: [
                    InfoExplainerSection(heading: "how_it_s_calculated", body: "recovery_factor_explanation"),
                ]
            )
        }
        .preferredColorScheme(.dark)
}
