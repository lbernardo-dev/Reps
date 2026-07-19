import SwiftUI

/// Standalone Timers screen — a library of general-purpose timers (Stopwatch, Timer, Tabata,
/// EMOM, AMRAP, Boxing/MMA, Metronome, Yoga) usable without a workout plan, reachable from the
/// Quick Menu. Mirrors the competitive audit's "a timer for every metcon" list.
struct TimersView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var configVersion = 0

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 10) {
                ForEach(TimerKind.allCases) { kind in
                    NavigationLink {
                        destination(for: kind)
                    } label: {
                        TimerKindRow(kind: kind, summary: TimerConfigStore.config(for: kind).summary(for: kind))
                    }
                    .buttonStyle(.plain)
                }
            }
            .id(configVersion)
            .padding(.horizontal, PulseTheme.screenHorizontalPadding)
            .padding(.top, 12)
            .padding(.bottom, 60)
        }
        .scrollBounceBehavior(.basedOnSize, axes: .vertical)
        .screenBackground()
        .navigationTitle("timers")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button {
                    HapticService.selection()
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.subheadline.weight(.bold))
                }
            }
        }
        .onAppear { configVersion += 1 }
    }

    @ViewBuilder
    private func destination(for kind: TimerKind) -> some View {
        switch kind {
        case .stopwatch:
            StopwatchView()
        case .metronome:
            MetronomeView()
        default:
            IntervalTimerRunView(kind: kind)
        }
    }
}

private struct TimerKindRow: View {
    let kind: TimerKind
    let summary: String

    var body: some View {
        PulseCard(contentPadding: 14) {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(kind.tint.opacity(0.14))
                        .frame(width: 44, height: 44)
                    Image(systemName: kind.systemImage)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(kind.tint)
                }

                Text(localizedKey(kind.title))
                    .font(.headline)
                    .foregroundStyle(.primary)

                Spacer(minLength: 8)

                Text(summary)
                    .font(.subheadline.weight(.semibold).monospacedDigit())
                    .foregroundStyle(PulseTheme.secondaryText)

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(PulseTheme.tertiaryText)
            }
        }
    }
}

#Preview {
    NavigationStack { TimersView() }
        .preferredColorScheme(.dark)
}
