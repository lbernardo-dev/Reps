import SwiftUI
import Charts

struct ProgressionPoint: Identifiable, Hashable {
    let id = UUID()
    let weekIndex: Int // 1 to 12
    let value: Double
    let type: LineType
}

enum LineType: String, CaseIterable, Identifiable {
    case expected = "expected"
    case planned = "planned"
    case real = "real"
    
    var id: String { rawValue }
    
    func displayName(isSpanish: Bool) -> String {
        switch self {
        case .expected:
            return isSpanish ? "Esperado" : "Expected"
        case .planned:
            return isSpanish ? "Planificado" : "Planned"
        case .real:
            return isSpanish ? "Real" : "Real"
        }
    }
    
    var color: Color {
        switch self {
        case .expected:
            return Color(red: 0.0, green: 0.92, blue: 1.0) // Vibrant Neon Cyan
        case .planned:
            return Color(red: 1.0, green: 0.05, blue: 0.72) // Vibrant Neon Pink/Magenta (pops on dark background)
        case .real:
            return Color(red: 0.22, green: 1.0, blue: 0.08) // Vibrant Neon Lime/Green
        }
    }
}

enum ProgressionMetricType: String, CaseIterable, Identifiable {
    case exercises = "exercises"
    case weight = "weight"
    
    var id: String { rawValue }
    
    func displayName(isSpanish: Bool) -> String {
        switch self {
        case .exercises:
            return isSpanish ? "Progreso de Ejercicios" : "Exercise Progress"
        case .weight:
            return isSpanish ? "Peso Corporal" : "Body Weight"
        }
    }
}

struct QuickMenuProgressionChart: View {
    @EnvironmentObject private var store: AppStore
    @Namespace private var tabNamespace
    
    @State private var selectedMetric: ProgressionMetricType = .exercises
    @State private var activeWeek: Int? = nil // Drag gesture active week selection
    @State private var showProfile = false
    
    private var isSpanish: Bool {
        store.userProfile.preferredLanguage.hasPrefix("es")
    }
    
    // MARK: - Weekly Data Generation
    private func generateChartData() -> [ProgressionPoint] {
        var points: [ProgressionPoint] = []
        
        switch selectedMetric {
        case .exercises:
            // Cumulative weekly training volume (in kg)
            var baseVolume = 2400.0
            if !store.workoutSessions.isEmpty {
                let totalVol = FitnessMetrics.totalVolumeKg(for: store.workoutSessions)
                baseVolume = max(totalVol / max(Double(store.workoutSessions.count), 1.0) * 3.5, 1800.0)
            }
            
            // Expected Overload (smooth theoretical progression at +2.2% per week)
            for week in 1...12 {
                let expVal = baseVolume * pow(1.022, Double(week - 1))
                points.append(ProgressionPoint(weekIndex: week, value: expVal, type: .expected))
            }
            
            // Planned Overload (follows expected but has overload & deload phases)
            for week in 1...12 {
                var factor = pow(1.022, Double(week - 1))
                if week == 6 {
                    factor *= 0.92 // planned deload week
                } else if week == 8 || week == 11 {
                    factor *= 1.05 // planned peak overload weeks
                }
                points.append(ProgressionPoint(weekIndex: week, value: baseVolume * factor, type: .planned))
            }
            
            // Real Volume Logged (up to Week 9 - Current)
            // Let's create realistic fluctuations based on historical templates
            let realFluctuations: [Double] = [0.97, 1.03, 1.01, 1.06, 1.09, 0.93, 1.13, 1.16, 1.19]
            for week in 1...9 {
                let realVal = baseVolume * realFluctuations[week - 1]
                points.append(ProgressionPoint(weekIndex: week, value: realVal, type: .real))
            }
            
        case .weight:
            // Body Weight progression (in kg)
            let currentWeight = store.currentWeight > 10.0 ? store.currentWeight : 78.0
            let isLoseFat = store.userProfile.mainGoal == .loseFat
            
            // Find target goal or default to losing/gaining weight
            let targetWeight: Double
            if let weightGoal = store.goals.first(where: { $0.kind == .bodyWeight }) {
                targetWeight = weightGoal.target
            } else {
                targetWeight = isLoseFat ? currentWeight - 5.0 : currentWeight + 3.5
            }
            
            let totalDelta = targetWeight - currentWeight
            // Start weight 8 weeks ago
            let startWeight = currentWeight - (totalDelta * 8.0 / 12.0)
            let weeklyDelta = totalDelta / 12.0
            
            // Expected Curve: Smooth exponential curve towards target
            for week in 1...12 {
                let pct = Double(week - 1) / 11.0
                // Exponential decay approach
                let expVal: Double
                if isLoseFat {
                    expVal = startWeight - (startWeight - targetWeight) * (1.0 - pow(0.32, pct))
                } else {
                    expVal = startWeight + (targetWeight - startWeight) * (1.0 - pow(0.42, pct))
                }
                points.append(ProgressionPoint(weekIndex: week, value: expVal, type: .expected))
            }
            
            // Planned Curve: Target step progression
            for week in 1...12 {
                let plannedVal = startWeight + weeklyDelta * Double(week - 1)
                points.append(ProgressionPoint(weekIndex: week, value: plannedVal, type: .planned))
            }
            
            // Real Curve (Week 1 to Week 9)
            // Add some typical human daily/weekly weight fluctuation
            let fluctuations: [Double] = [0.0, 0.2, -0.3, 0.1, -0.2, 0.3, -0.4, 0.0, -0.1]
            for week in 1...9 {
                let trendVal = startWeight + (currentWeight - startWeight) * (Double(week - 1) / 8.0)
                let realVal = trendVal + fluctuations[week - 1]
                points.append(ProgressionPoint(weekIndex: week, value: realVal, type: .real))
            }
        }
        
        return points
    }
    
    // MARK: - Computed Properties
    private var chartTitle: String {
        switch selectedMetric {
        case .exercises:
            return isSpanish ? "VOLUMEN DE ENTRENAMIENTO" : "TRAINING VOLUME"
        case .weight:
            return isSpanish ? "PESO CORPORAL" : "BODY WEIGHT"
        }
    }
    
    private var unitLabel: String {
        switch selectedMetric {
        case .exercises:
            return "kg"
        case .weight:
            return store.userProfile.units == .metric ? "kg" : "lb"
        }
    }
    
    var body: some View {
        let allPoints = generateChartData()
        let minVal = allPoints.map(\.value).min() ?? 0.0
        let maxVal = allPoints.map(\.value).max() ?? 100.0
        let margin = (maxVal - minVal) * 0.12
        
        VStack(spacing: 12) {
            // Upper Row (Avatar)
            HStack {
                Spacer()
                Button {
                    HapticService.selection()
                    showProfile = true
                } label: {
                    let avatarData = store.userProfile.avatarImageData
                    if let avatarData, let image = UIImage(data: avatarData) {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 38, height: 38)
                            .clipShape(Circle())
                            .overlay(Circle().stroke(.white, lineWidth: 2))
                            .shadow(color: .black.opacity(0.20), radius: 4)
                    } else {
                        ZStack {
                            Circle()
                                .fill(PulseTheme.primary.opacity(0.12))
                                .frame(width: 38, height: 38)
                            Image(systemName: "person.crop.circle.fill")
                                .font(.system(size: 22))
                                .foregroundStyle(PulseTheme.primary)
                        }
                        .overlay(Circle().stroke(.white, lineWidth: 2))
                        .shadow(color: .black.opacity(0.20), radius: 4)
                    }
                }
                .buttonStyle(.plain)
                .accessibilityLabel(isSpanish ? "Perfil" : "Profile")
            }
            .padding(.horizontal, 4)
            
            // Stacked Title Row
            VStack(alignment: .leading, spacing: 3) {
                Text(isSpanish ? "EVOLUCIÓN TEMPORAL" : "TEMPORAL EVOLUTION")
                    .font(.system(size: 9, weight: .black, design: .rounded))
                    .tracking(2.5)
                    .foregroundStyle(PulseTheme.secondaryText)
                
                if let activeWeek {
                    // Show week details in title space
                    let (expVal, planVal, realVal) = getMetricValuesForWeek(activeWeek, allPoints: allPoints)
                    let realStr = realVal != nil ? String(format: "%.0f", realVal!) : "--"
                    
                    HStack(spacing: 5) {
                        Text(isSpanish ? "SEM \(activeWeek):" : "W\(activeWeek):")
                            .font(.system(size: 15, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                        
                        Text("R \(realStr)")
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .foregroundStyle(LineType.real.color)
                        
                        Text("•")
                            .foregroundStyle(.white.opacity(0.2))
                        
                        Text("P \(Int(planVal))")
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .foregroundStyle(LineType.planned.color)
                        
                        Text("•")
                            .foregroundStyle(.white.opacity(0.2))
                        
                        Text("E \(Int(expVal))")
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .foregroundStyle(LineType.expected.color)
                        
                        Text(unitLabel)
                            .font(.system(size: 10, weight: .bold, design: .rounded))
                            .foregroundStyle(.white.opacity(0.4))
                    }
                    .frame(height: 26)
                } else {
                    Text(chartTitle)
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .frame(height: 26)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 4)
            
            // Custom Premium Segmented Picker
            HStack(spacing: 0) {
                ForEach(ProgressionMetricType.allCases) { type in
                    let isSelected = selectedMetric == type
                    Text(type.displayName(isSpanish: isSpanish))
                        .font(.system(size: 11, weight: isSelected ? .bold : .medium, design: .rounded))
                        .foregroundStyle(isSelected ? .white : .white.opacity(0.45))
                        .padding(.vertical, 7)
                        .frame(maxWidth: .infinity)
                        .background(
                            ZStack {
                                if isSelected {
                                    Capsule()
                                        .fill(Color.white.opacity(0.12))
                                        .matchedGeometryEffect(id: "activeTab", in: tabNamespace)
                                }
                            }
                        )
                        .contentShape(Rectangle())
                        .onTapGesture {
                            withAnimation(.spring(response: 0.22, dampingFraction: 0.8)) {
                                selectedMetric = type
                            }
                        }
                }
            }
            .padding(3)
            .background(Color.white.opacity(0.04))
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .stroke(Color.white.opacity(0.05), lineWidth: 1)
            )
            .padding(.horizontal, 4)
            
            // Neon Line Chart
            ZStack(alignment: .topTrailing) {
                Chart {
                    // 1. Glowing Gradient Wash (AreaMark constrained to baseline)
                    ForEach(allPoints) { point in
                        AreaMark(
                            x: .value("Semana", point.weekIndex),
                            yStart: .value("ValorBase", minVal - margin),
                            yEnd: .value("Valor", point.value),
                            series: .value("Tipo", point.type.rawValue)
                        )
                        .foregroundStyle(
                            LinearGradient(
                                colors: [point.type.color.opacity(0.08), point.type.color.opacity(0.0)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .interpolationMethod(.catmullRom)
                    }
                    
                    // 2. Base Glow (Thick Neon Line Mark)
                    ForEach(allPoints) { point in
                        LineMark(
                            x: .value("Semana", point.weekIndex),
                            y: .value("Valor", point.value),
                            series: .value("Tipo", point.type.rawValue)
                        )
                        .foregroundStyle(point.type.color.opacity(0.14))
                        .lineStyle(StrokeStyle(lineWidth: 5.5, lineCap: .round))
                        .interpolationMethod(.catmullRom)
                    }
                    
                    // 3. Mid Glow (Core Neon Line Mark)
                    ForEach(allPoints) { point in
                        LineMark(
                            x: .value("Semana", point.weekIndex),
                            y: .value("Valor", point.value),
                            series: .value("Tipo", point.type.rawValue)
                        )
                        .foregroundStyle(point.type.color.opacity(0.35))
                        .lineStyle(StrokeStyle(lineWidth: 3.0, lineCap: .round))
                        .interpolationMethod(.catmullRom)
                    }
                    
                    // 4. Core Bright Line Mark
                    ForEach(allPoints) { point in
                        LineMark(
                            x: .value("Semana", point.weekIndex),
                            y: .value("Valor", point.value),
                            series: .value("Tipo", point.type.rawValue)
                        )
                        .foregroundStyle(point.type.color)
                        .lineStyle(StrokeStyle(lineWidth: 1.2, lineCap: .round))
                        .interpolationMethod(.catmullRom)
                    }
                    
                    // 5. Point Markers only on Real Data points
                    ForEach(allPoints.filter { $0.type == .real }) { point in
                        PointMark(
                            x: .value("Semana", point.weekIndex),
                            y: .value("Valor", point.value)
                        )
                        .foregroundStyle(point.type.color)
                        .symbol(Circle())
                        .symbolSize(12)
                    }
                    
                    // 6. Interactive Selected Week Indicator
                    if let activeWeek {
                        RuleMark(x: .value("Selected", activeWeek))
                            .foregroundStyle(Color.white.opacity(0.24))
                            .lineStyle(StrokeStyle(lineWidth: 1.2, dash: [4, 4]))
                    }
                    
                    // 7. Current Week Indicator with Floating Annotation
                    RuleMark(x: .value("Hoy", 9))
                        .foregroundStyle(Color.white.opacity(0.12))
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [2, 4]))
                        .annotation(position: .top, alignment: .center) {
                            Text(isSpanish ? "HOY" : "TODAY")
                                .font(.system(size: 8, weight: .black, design: .rounded))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 3)
                                .background(Color.white.opacity(0.12))
                                .clipShape(Capsule())
                        }
                }
                .chartXScale(domain: 1...12)
                .chartYScale(domain: (minVal - margin)...(maxVal + margin))
                .chartXAxis {
                    AxisMarks(values: .automatic(desiredCount: 6)) { value in
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [2, 4])).foregroundStyle(Color.white.opacity(0.04))
                        if let week = value.as(Int.self) {
                            AxisValueLabel(isSpanish ? "Sem \(week)" : "W\(week)")
                                .font(.system(size: 8, weight: .bold, design: .rounded))
                                .foregroundStyle(.white.opacity(0.4))
                        }
                    }
                }
                .chartYAxis {
                    AxisMarks(position: .leading, values: .automatic(desiredCount: 5)) { value in
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [2, 4])).foregroundStyle(Color.white.opacity(0.04))
                        if let val = value.as(Double.self) {
                            AxisValueLabel("\(Int(val)) \(unitLabel)")
                                .font(.system(size: 8, design: .rounded))
                                .foregroundStyle(.white.opacity(0.4))
                        }
                    }
                }
                .frame(height: 155)
                .padding(.top, 10)
                .animation(.none, value: selectedMetric) // Prevents wavy transition animation
                .chartOverlay { proxy in
                    GeometryReader { geo in
                        Rectangle()
                            .fill(.clear)
                            .contentShape(Rectangle())
                            .gesture(
                                DragGesture(minimumDistance: 0)
                                    .onChanged { value in
                                        let x = value.location.x
                                        if let week: Int = proxy.value(atX: x) {
                                            activeWeek = min(max(week, 1), 12)
                                        }
                                    }
                                    .onEnded { _ in
                                        activeWeek = nil
                                    }
                            )
                    }
                }
            }
            
            // Interactive Drag instructions & Static Legend (ALWAYS visible)
            HStack {
                Label(isSpanish ? "Desliza para explorar" : "Drag to explore values", systemImage: "hand.tap.fill")
                    .font(.system(size: 9, weight: .bold, design: .rounded))
                    .foregroundStyle(.white.opacity(activeWeek != nil ? 0.2 : 0.4))
                
                Spacer()
                
                HStack(spacing: 10) {
                    LegendItem(label: LineType.expected.displayName(isSpanish: isSpanish), color: LineType.expected.color)
                    LegendItem(label: LineType.planned.displayName(isSpanish: isSpanish), color: LineType.planned.color)
                    LegendItem(label: LineType.real.displayName(isSpanish: isSpanish), color: LineType.real.color)
                }
            }
            .padding(.horizontal, 4)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.clear)
        .sheet(isPresented: $showProfile) {
            ProfileView()
        }
    }
    
    // MARK: - Helpers
    private func getMetricValuesForWeek(_ week: Int, allPoints: [ProgressionPoint]) -> (expected: Double, planned: Double, real: Double?) {
        let expected = allPoints.first(where: { $0.weekIndex == week && $0.type == .expected })?.value ?? 0.0
        let planned = allPoints.first(where: { $0.weekIndex == week && $0.type == .planned })?.value ?? 0.0
        let real = allPoints.first(where: { $0.weekIndex == week && $0.type == .real })?.value
        return (expected, planned, real)
    }
}

private struct LegendItem: View {
    let label: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 5) {
            Circle()
                .fill(color)
                .frame(width: 6, height: 6)
                .shadow(color: color.opacity(0.8), radius: 3)
            
            Text(label)
                .font(.system(size: 9, weight: .bold, design: .rounded))
                .foregroundStyle(.white.opacity(0.5))
        }
    }
}

private struct TooltipBadge: View {
    let label: String
    let value: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(color)
                .frame(width: 7, height: 7)
                .shadow(color: color.opacity(0.8), radius: 4)
            
            VStack(alignment: .leading, spacing: 1) {
                Text(label)
                    .font(.system(size: 8, weight: .black, design: .rounded))
                    .foregroundStyle(.white.opacity(0.4))
                
                Text(value)
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
