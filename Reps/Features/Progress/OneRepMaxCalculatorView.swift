import SwiftUI

struct OneRepMaxCalculatorView: View {
  @Environment(AppStore.self) private var store
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
    ScrollView(.vertical, showsIndicators: false) {
      VStack(spacing: 20) {
        // Calculator Card
        PulseCard {
          VStack(spacing: 20) {
            Text("value_1rm_calculator_epley_formula")
              .font(.headline)
              .foregroundStyle(PulseTheme.accent)
              .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: 16) {
              // Weight input field
              VStack(alignment: .leading, spacing: 6) {
                Text(localizedFormat("weight_lifted_unit_format", unit))
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
                Text("repeticiones")
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
                Text("estimated_maximum_1rm")
                  .font(.caption.weight(.semibold))
                  .foregroundStyle(PulseTheme.accent)

                Text("\(estimated1RM, specifier: "%.1f") \(unit)")
                  .font(.system(size: 42, weight: .bold, design: .rounded))
                  .foregroundStyle(PulseTheme.ringStand)
              }
              .frame(maxWidth: .infinity)
              .padding(.vertical, 8)
            }
          }
        }
        .padding(.horizontal, PulseTheme.screenHorizontalPadding)

        // Percentage Breakdown List
        if !percentageBreakdown.isEmpty {
          VStack(alignment: .leading, spacing: 10) {
            Text("intensity_percentage_table")
              .font(.headline)
              .padding(.horizontal, PulseTheme.screenHorizontalPadding)

            PulseCard {
              VStack(spacing: 0) {
                HStack {
                  Text("porcentaje").fontWeight(.bold)
                  Spacer()
                  Text("reps_aprox").fontWeight(.bold)
                  Spacer()
                  Text("weight_2").fontWeight(.bold)
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
                      .foregroundStyle(PulseTheme.accent)
                  }
                  .padding(.vertical, 10)
                }
              }
            }
            .padding(.horizontal, PulseTheme.screenHorizontalPadding)
          }
        }
      }
      .padding(.vertical, 10)
    }
    .scrollBounceBehavior(.basedOnSize, axes: .vertical)
    .screenBackground()
    .navigationTitle("calculadora_1rm")
    .navigationBarTitleDisplayMode(.inline)
    .mainTabBarHidden()
  }
}
