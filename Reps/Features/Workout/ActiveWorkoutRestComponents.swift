import SwiftUI

struct ActiveRestPanel: View {
    let isRestActive: Bool
    let currentRestSeconds: Int
    let restStartedAt: Date?
    let restDuration: Int
    let onDecrease: () -> Void
    let onIncrease: () -> Void
    let onSkipOrRestart: () -> Void

    var body: some View {
        PulseCard {
            if isRestActive {
                activeRestContent
            } else {
                inactiveRestContent
            }
        }
    }

    private var inactiveRestContent: some View {
        HStack(spacing: 14) {
            Image(systemName: "hourglass")
                .font(.title3.weight(.semibold))
                .foregroundStyle(PulseTheme.tertiaryText)
                .frame(width: 44, height: 44)
                .background(PulseTheme.grouped)
                .clipShape(Circle())
            VStack(alignment: .leading, spacing: 2) {
                Text("Descanso")
                    .font(.headline.weight(.bold))
                Text("Completa una serie para activar")
                    .font(.caption)
                    .foregroundStyle(PulseTheme.secondaryText)
            }
            Spacer()
        }
    }

    private var activeRestContent: some View {
        HStack(spacing: 18) {
            RestCountdownRing(
                restStartedAt: restStartedAt,
                restDuration: restDuration,
                fallbackRestSeconds: currentRestSeconds
            )
            .frame(width: 78, height: 78)

            VStack(alignment: .leading, spacing: 10) {
                Text(currentRestSeconds == 0 ? "Listo para continuar" : "Descansando")
                    .font(.headline.weight(.bold))
                Text(currentRestSeconds == 0 ? "La batería deja de recargar cuando saltas el descanso." : "Completar el descanso reduce la fatiga de la siguiente serie.")
                    .font(.caption)
                    .foregroundStyle(PulseTheme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: 8) {
                    restAdjustmentButton(title: "-15s", action: onDecrease)
                        .accessibilityLabel("Reducir descanso 15 segundos")
                    restAdjustmentButton(title: "+15s", action: onIncrease)
                        .accessibilityLabel("Ampliar descanso 15 segundos")

                    Button(currentRestSeconds == 0 ? "Reiniciar" : "Saltar", action: onSkipOrRestart)
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .frame(height: 38)
                        .background(PulseTheme.grouped)
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        .accessibilityLabel(currentRestSeconds == 0 ? "Reiniciar descanso" : "Saltar descanso")
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func restAdjustmentButton(title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline.weight(.bold))
                .frame(maxWidth: .infinity)
                .frame(height: 38)
                .foregroundStyle(PulseTheme.primary)
                .background(PulseTheme.primary.opacity(0.10))
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
    }
}

private struct RestCountdownRing: View, Equatable {
    let restStartedAt: Date?
    let restDuration: Int
    let fallbackRestSeconds: Int

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { timeline in
            let seconds = remainingSeconds(at: timeline.date)
            let progress = restDuration > 0 ? Double(seconds) / Double(restDuration) : 0
            let ringColor: Color = seconds > 30 ? PulseTheme.primaryBright : (seconds > 0 ? PulseTheme.warning : Color.red)

            ZStack {
                Circle()
                    .stroke(PulseTheme.grouped, lineWidth: 7)
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(ringColor, style: StrokeStyle(lineWidth: 7, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(.linear(duration: 1), value: seconds)
                VStack(spacing: 1) {
                    Text(timeString(seconds))
                        .font(.system(size: 18, weight: .black, design: .rounded).monospacedDigit())
                        .foregroundStyle(ringColor)
                        .animation(.none, value: seconds)
                    Text(seconds == 0 ? "¡Listo!" : "desc.")
                        .font(.system(size: 9, weight: .bold, design: .rounded))
                        .foregroundStyle(PulseTheme.secondaryText)
                }
            }
        }
    }

    private func remainingSeconds(at date: Date) -> Int {
        guard let restStartedAt else {
            return fallbackRestSeconds
        }
        return max(restDuration - Int(date.timeIntervalSince(restStartedAt)), 0)
    }

    private func timeString(_ seconds: Int) -> String {
        let minutes = seconds / 60
        let secs = seconds % 60
        return String(format: "%02d:%02d", minutes, secs)
    }
}
