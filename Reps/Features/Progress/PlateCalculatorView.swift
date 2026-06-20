import SwiftUI

struct PlateCalculatorView: View {
    @Environment(AppStore.self) private var store
    @State private var targetWeightInput: String = "60"
    @AppStorage("plateCalc.barWeight") private var barbellWeight: Double = 20.0
    @AppStorage("plateCalc.disabledPlates") private var disabledPlatesRaw: String = ""

    // Full universe of plates the calculator knows about (kg).
    private let allPlates: [Double] = [25.0, 20.0, 15.0, 10.0, 5.0, 2.5, 2.0, 1.5, 1.25, 1.0, 0.5]

    private struct BarOption: Identifiable {
        var id: Double { weight }
        let name: String
        let weight: Double
    }

    private let barOptions: [BarOption] = [
        BarOption(name: "olympic_bar", weight: 20.0),
        BarOption(name: "women_bar", weight: 15.0),
        BarOption(name: "technique_bar", weight: 7.0),
        BarOption(name: "z_bar", weight: 10.0)
    ]

    private var disabledPlates: Set<Double> {
        Set(disabledPlatesRaw.split(separator: ",").compactMap { Double($0) })
    }

    // Plates the user actually owns, largest first (used for the load math).
    private var availablePlates: [Double] {
        allPlates.filter { !disabledPlates.contains($0) }
    }

    private func togglePlate(_ plate: Double) {
        var set = disabledPlates
        if set.contains(plate) { set.remove(plate) } else { set.insert(plate) }
        disabledPlatesRaw = set.sorted().map { String($0) }.joined(separator: ",")
    }

    private var unit: String {
        store.userProfile.units == .metric ? "kg" : "lb"
    }
    
    private var targetWeight: Double {
        Double(targetWeightInput.replacingOccurrences(of: ",", with: ".")) ?? 0.0
    }
    
    private var smallestAvailablePlate: Double {
        availablePlates.min() ?? 0.0
    }

    private struct PlateStackItem: Identifiable {
        let id = UUID()
        let weight: Double
        let count: Int
        
        var color: Color {
            switch weight {
            case 25.0: return .red
            case 20.0: return .blue
            case 15.0: return .yellow
            case 10.0: return .green
            case 5.0: return .white
            case 2.5: return .red.opacity(0.8)
            case 1.25: return .blue.opacity(0.8)
            default: return .gray
            }
        }
        
        var heightFactor: CGFloat {
            switch weight {
            case 25.0: return 1.0
            case 20.0: return 0.92
            case 15.0: return 0.84
            case 10.0: return 0.76
            case 5.0: return 0.65
            case 2.5: return 0.55
            case 1.25: return 0.45
            default: return 0.35
            }
        }
        
        var width: CGFloat {
            switch weight {
            case 25.0, 20.0, 15.0, 10.0: return 24
            case 5.0: return 18
            case 2.5: return 14
            case 1.25: return 12
            default: return 10
            }
        }
    }
    
    private var calculatedPlatesPerSide: [PlateStackItem] {
        let weightNeeded = targetWeight - barbellWeight
        guard weightNeeded > 0 else { return [] }
        
        var remainingWeight = weightNeeded / 2.0
        var stack: [PlateStackItem] = []
        
        for plate in availablePlates {
            let count = Int(remainingWeight / plate)
            if count > 0 {
                stack.append(PlateStackItem(weight: plate, count: count))
                remainingWeight -= Double(count) * plate
            }
        }
        
        return stack
    }
    
    private var totalCalculatedWeight: Double {
        let platesWeight = calculatedPlatesPerSide.reduce(0.0) { $0 + ($1.weight * Double($1.count)) }
        return barbellWeight + (platesWeight * 2.0)
    }
    
    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 24) {
                // Inputs Card
                PulseCard {
                    VStack(spacing: 20) {
                        Text("plate_calculator")
                            .font(.headline)
                            .foregroundStyle(PulseTheme.primary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        
                        // Target Weight input
                        VStack(alignment: .leading, spacing: 6) {
                            Text("target_weight")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(PulseTheme.secondaryText)
                                .frame(maxWidth: .infinity, alignment: .leading)

                            HStack {
                                TextField("60", text: $targetWeightInput)
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

                        // Barbell type selector
                        VStack(alignment: .leading, spacing: 8) {
                            Text("barra_2")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(PulseTheme.secondaryText)
                                .frame(maxWidth: .infinity, alignment: .leading)

                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 8) {
                                    ForEach(barOptions) { bar in
                                        let selected = barbellWeight == bar.weight
                                        Button {
                                            barbellWeight = bar.weight
                                        } label: {
                                            Text("\(localizedString(bar.name)) \(bar.weight.formatted()) \(unit)")
                                                .font(.subheadline.weight(.semibold))
                                                .foregroundStyle(selected ? .white : PulseTheme.secondaryText)
                                                .padding(.horizontal, 14)
                                                .padding(.vertical, 8)
                                                .background(selected ? PulseTheme.primaryBright : PulseTheme.grouped)
                                                .clipShape(Capsule())
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                            }
                        }

                        // Available plates (which plates you own)
                        VStack(alignment: .leading, spacing: 8) {
                            Text("discos_disponibles")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(PulseTheme.secondaryText)
                                .frame(maxWidth: .infinity, alignment: .leading)

                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 8) {
                                    ForEach(allPlates, id: \.self) { plate in
                                        let enabled = !disabledPlates.contains(plate)
                                        Button {
                                            togglePlate(plate)
                                        } label: {
                                            Text(plate.formatted())
                                                .font(.subheadline.weight(.bold).monospacedDigit())
                                                .foregroundStyle(enabled ? .white : PulseTheme.secondaryText)
                                                .frame(minWidth: 40)
                                                .padding(.vertical, 8)
                                                .background(enabled ? PulseTheme.primary.opacity(0.85) : PulseTheme.grouped)
                                                .clipShape(Capsule())
                                                .overlay(
                                                    Capsule()
                                                        .strokeBorder(enabled ? Color.clear : PulseTheme.secondaryText.opacity(0.3), lineWidth: 1)
                                                )
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, PulseTheme.screenHorizontalPadding)
                
                if targetWeight > 0 {
                    // Barbell Visual Stack Card
                    PulseCard {
                        VStack(spacing: 22) {
                            Text("plates_per_side_loaded_on_each_end")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(PulseTheme.secondaryText)
                            
                            // Barbell Graphic
                            ZStack {
                                // Barbell bar
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(Color.gray.opacity(0.4))
                                    .frame(width: 280, height: 10)
                                
                                // Sleeve stopper
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(Color.gray.opacity(0.8))
                                    .frame(width: 14, height: 38)
                                    .offset(x: -80)
                                
                                // Sleeves
                                RoundedRectangle(cornerRadius: 2)
                                    .fill(Color.gray.opacity(0.6))
                                    .frame(width: 140, height: 20)
                                    .offset(x: 20)
                                
                                // Stack of plates loaded on sleeve
                                HStack(spacing: 3) {
                                    ForEach(calculatedPlatesPerSide) { item in
                                        ForEach(0..<item.count, id: \.self) { _ in
                                            RoundedRectangle(cornerRadius: 4, style: .continuous)
                                                .fill(item.color)
                                                .frame(width: item.width, height: 110 * item.heightFactor)
                                                .overlay(
                                                    RoundedRectangle(cornerRadius: 4)
                                                        .stroke(Color.black.opacity(0.4), lineWidth: 1)
                                                )
                                                .overlay(
                                                    Text(item.weight.formatted())
                                                        .font(.system(size: 8, weight: .bold))
                                                        .foregroundStyle(item.color == .white ? .black : .white)
                                                        .rotationEffect(.degrees(-90))
                                                )
                                        }
                                    }
                                }
                                .offset(x: 20)
                            }
                            .frame(height: 140)
                            .padding(.vertical, 8)
                            
                            Divider()
                            
                            // Plate Math Breakdown
                            VStack(spacing: 12) {
                                ForEach(calculatedPlatesPerSide) { item in
                                    HStack {
                                        Circle()
                                            .fill(item.color)
                                            .frame(width: 12, height: 12)
                                        Text(localizedFormat("plates_count_weight_format", item.count, item.weight.formatted(), unit))
                                            .font(.subheadline)
                                        Spacer()
                                        Text("\(Double(item.count) * item.weight, specifier: "%.1f") \(unit)")
                                            .font(.subheadline.monospacedDigit().weight(.semibold))
                                            .foregroundStyle(PulseTheme.secondaryText)
                                    }
                                }
                                
                                if calculatedPlatesPerSide.isEmpty && targetWeight > barbellWeight {
                                    Text(localizedFormat("remaining_weight_below_smallest_plate_format", smallestAvailablePlate.formatted(), unit))
                                        .font(.caption)
                                        .foregroundStyle(PulseTheme.warning)
                                        .multilineTextAlignment(.center)
                                }
                            }
                            
                            Divider()
                            
                            // Totals summary
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("total_loaded_weight")
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(PulseTheme.secondaryText)
                                    Text("\(totalCalculatedWeight, specifier: "%.1f") \(unit)")
                                        .font(.title2.weight(.bold))
                                        .foregroundStyle(PulseTheme.primaryBright)
                                }
                                
                                Spacer()
                                
                                if totalCalculatedWeight != targetWeight {
                                    VStack(alignment: .trailing, spacing: 4) {
                                        Text("diferencia")
                                            .font(.caption.weight(.semibold))
                                            .foregroundStyle(PulseTheme.secondaryText)
                                        Text(String(format: "%+.1f %@", totalCalculatedWeight - targetWeight, unit))
                                            .font(.title3.weight(.bold))
                                            .foregroundStyle(PulseTheme.warning)
                                    }
                                }
                            }
                        }
                    }
                    .padding(.horizontal, PulseTheme.screenHorizontalPadding)
                }
            }
            .padding(.vertical, 10)
        }
        .scrollBounceBehavior(.basedOnSize, axes: .vertical)
        .screenBackground()
        .navigationTitle("plate_calculator")
        .navigationBarTitleDisplayMode(.inline)
        .mainTabBarHidden()
    }
}
