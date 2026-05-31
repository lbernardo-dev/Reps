import SwiftUI

struct OneRepMaxCalculatorView: View {
  @EnvironmentObject private var store: AppStore
  @State private var weightInput: String = ""
  @State private var repsInput: Int = 5

  private var unit: String {
    store.userProfile.units == .metric ? "kg" : "lb"
  }

  private var weight: Double {
    Double(weightInput.replacingOccurrences(of: ",", with: ".")) ?? 0.0
  }

  private var estimated1RM: Double {
    guard repsInput > 0, weight > 0 else { return 0 }
    if repsInput == 1 { return weight }
    // Epley Formula
    return weight * (1.0 + Double(repsInput) / 30.0)
  }

  private struct RepPercentage: Identifiable {
    let id = UUID()
    let percentage: Int
    let reps: Int
    let weight: Double
  }

  private var percentageBreakdown: [RepPercentage] {
    let oneRM = estimated1RM
    guard oneRM > 0 else { return [] }

    // standard percentage-to-rep approximations (e.g. Brzycki/Epley based)
    let percentages = [
      (100, 1), (95, 2), (90, 3), (88, 4), (85, 5), (82, 6),
      (80, 7), (77, 8), (75, 9), (72, 10), (70, 11), (67, 12),
    ]

    return percentages.map { pct, reps in
      RepPercentage(
        percentage: pct,
        reps: reps,
        weight: oneRM * (Double(pct) / 100.0)
      )
    }
  }

  var body: some View {
    ScrollView {
      VStack(spacing: 20) {
        // Calculator Card
        PulseCard {
          VStack(spacing: 20) {
            Text("Calculadora de 1RM (Fórmula Epley)")
              .font(.headline)
              .foregroundStyle(PulseTheme.primary)
              .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: 16) {
              // Weight input field
              VStack(alignment: .leading, spacing: 6) {
                Text("Peso levantado (\(unit))")
                  .font(.caption.weight(.semibold))
                  .foregroundStyle(PulseTheme.secondaryText)

                HStack {
                  TextField("0.0", text: $weightInput)
                    .keyboardType(.decimalPad)
                    .font(.title3.monospacedDigit().weight(.bold))

                  Text(unit)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(PulseTheme.secondaryText)
                }
                .padding()
                .background(PulseTheme.grouped)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
              }

              // Reps input field
              VStack(alignment: .leading, spacing: 6) {
                Text("Repeticiones")
                  .font(.caption.weight(.semibold))
                  .foregroundStyle(PulseTheme.secondaryText)

                HStack {
                  Stepper {
                    Text("\(repsInput)")
                      .font(.title3.monospacedDigit().weight(.bold))
                  } onIncrement: {
                    if repsInput < 30 { repsInput += 1 }
                  } onDecrement: {
                    if repsInput > 1 { repsInput -= 1 }
                  }
                }
                .padding(.vertical, 8)
                .padding(.horizontal, 12)
                .background(PulseTheme.grouped)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
              }
            }

            if estimated1RM > 0 {
              Divider()

              // Hero result
              VStack(spacing: 4) {
                Text("Máximo Estimado (1RM)")
                  .font(.caption.weight(.semibold))
                  .foregroundStyle(PulseTheme.accent)

                Text("\(estimated1RM, specifier: "%.1f") \(unit)")
                  .font(.system(size: 42, weight: .bold, design: .rounded))
                  .foregroundStyle(PulseTheme.primaryBright)
              }
              .frame(maxWidth: .infinity)
              .padding(.vertical, 8)
            }
          }
        }
        .padding(.horizontal, 20)

        // Percentage Breakdown List
        if !percentageBreakdown.isEmpty {
          VStack(alignment: .leading, spacing: 10) {
            Text("Tabla de porcentajes de intensidad")
              .font(.headline)
              .padding(.horizontal, 22)

            PulseCard {
              VStack(spacing: 0) {
                HStack {
                  Text("Porcentaje").fontWeight(.bold)
                  Spacer()
                  Text("Reps aprox.").fontWeight(.bold)
                  Spacer()
                  Text("Peso").fontWeight(.bold)
                }
                .font(.caption)
                .foregroundStyle(PulseTheme.secondaryText)
                .padding(.bottom, 12)

                ForEach(percentageBreakdown) { item in
                  Divider()

                  HStack {
                    Text("\(item.percentage)%")
                      .font(.subheadline.monospacedDigit().weight(.bold))
                      .foregroundStyle(item.percentage >= 90 ? PulseTheme.accent : .white)

                    Spacer()

                    Text("\(item.reps) rep\(item.reps == 1 ? "" : "s")")
                      .font(.subheadline)
                      .foregroundStyle(PulseTheme.secondaryText)

                    Spacer()

                    Text("\(item.weight, specifier: "%.1f") \(unit)")
                      .font(.subheadline.monospacedDigit().weight(.bold))
                      .foregroundStyle(PulseTheme.primary)
                  }
                  .padding(.vertical, 10)
                }
              }
            }
            .padding(.horizontal, 20)
          }
        }
      }
      .padding(.vertical, 10)
    }
    .screenBackground()
    .navigationTitle("Calculadora 1RM")
    .navigationBarTitleDisplayMode(.inline)
    .mainTabBarHidden()
  }
}
