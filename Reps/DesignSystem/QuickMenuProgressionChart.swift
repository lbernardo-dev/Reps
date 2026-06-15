import SwiftUI
import Charts

struct ProgressionPoint: Identifiable, Hashable {
    let weekIndex: Int // 1 to 12
    let value: Double
    let type: LineType

    var id: String {
        "\(type.rawValue)-\(weekIndex)"
    }
}

enum LineType: String, CaseIterable, Identifiable {
    case expected = "expected"
    case planned = "planned"
    case real = "real"
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .expected:
            return localizedString("expected_2")
        case .planned:
            return localizedString("planned_2")
        case .real:
            return localizedString("real_2")
        }
    }
    
    var color: Color {
        switch self {
        case .expected:
            return PulseTheme.primaryBright
        case .planned:
            return PulseTheme.accent
        case .real:
            return Color(red: 0.62, green: 1.0, blue: 0.42)
        }
    }
}

enum ProgressionMetricType: String, CaseIterable, Identifiable {
    case exercises = "exercises"
    case weight = "weight"
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .exercises:
            return localizedString("exercise_progress")
        case .weight:
            return localizedString("body_weight")
        }
    }
}

struct QuickMenuProgressionChart: View {
    @Environment(AppStore.self) private var store
    @Namespace private var tabNamespace
    
    @State private var selectedMetric: ProgressionMetricType = .exercises
    @State private var activeWeek: Int? = nil // Drag gesture active week selection
    
    // MARK: - Weekly Data
    private func generateChartData() -> [ProgressionPoint] {
        switch selectedMetric {
        case .exercises:
            return exerciseChartData()
        case .weight:
            return weightChartData()
        }
    }

    private func exerciseChartData() -> [ProgressionPoint] {
        var points: [ProgressionPoint] = []

        let realWeeklyVolume = valuesByWeek(store.workoutSessions) { sessions in
            sessions.reduce(0.0) { sessionTotal, session in
                sessionTotal + FitnessMetrics.totalVolumeKg(for: [session])
            }
        }

        points += realWeeklyVolume.map { weekIndex, value in
            ProgressionPoint(weekIndex: weekIndex, value: value, type: .real)
        }

        return points.sorted { lhs, rhs in
            lhs.type.rawValue == rhs.type.rawValue ? lhs.weekIndex < rhs.weekIndex : lhs.type.rawValue < rhs.type.rawValue
        }
    }

    private func weightChartData() -> [ProgressionPoint] {
        var points: [ProgressionPoint] = []
        let metrics = store.bodyMetrics.sorted { $0.date < $1.date }

        let realWeeklyWeight = valuesByWeek(metrics) { metricsInWeek in
            metricsInWeek.sorted { $0.date < $1.date }.last?.weightKg ?? 0
        }

        points += realWeeklyWeight.map { weekIndex, value in
            ProgressionPoint(weekIndex: weekIndex, value: displayWeightValue(value), type: .real)
        }

        if let goal = store.goals.first(where: { $0.kind == .bodyWeight }),
           let start = metrics.first?.weightKg {
            let startWeek = weekIndex(for: metrics.first?.date ?? .now) ?? 1
            let endWeek = min(max(weekIndex(for: goal.deadline ?? .now) ?? 12, startWeek), 12)
            let span = max(Double(endWeek - startWeek), 1)

            points += (startWeek...endWeek).map { weekIndex in
                let progress = Double(weekIndex - startWeek) / span
                let value = start + ((goal.target - start) * progress)
                return ProgressionPoint(weekIndex: weekIndex, value: displayWeightValue(value), type: .planned)
            }
        }

        return points.sorted { lhs, rhs in
            lhs.type.rawValue == rhs.type.rawValue ? lhs.weekIndex < rhs.weekIndex : lhs.type.rawValue < rhs.type.rawValue
        }
    }

    private func valuesByWeek<T>(_ items: [T], value: ([T]) -> Double) -> [(weekIndex: Int, value: Double)] where T: DatedChartItem {
        Dictionary(grouping: items.compactMap { item -> (Int, T)? in
            guard let weekIndex = weekIndex(for: item.chartDate) else { return nil }
            return (weekIndex, item)
        }, by: \.0)
        .compactMap { weekIndex, groupedItems in
            let weekValue = value(groupedItems.map(\.1))
            return weekValue > 0 ? (weekIndex, weekValue) : nil
        }
        .sorted { $0.weekIndex < $1.weekIndex }
    }

    private func weekIndex(for date: Date) -> Int? {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)
        guard let currentWeekStart = calendar.dateInterval(of: .weekOfYear, for: today)?.start,
              let itemWeekStart = calendar.dateInterval(of: .weekOfYear, for: date)?.start else {
            return nil
        }

        let weekOffset = calendar.dateComponents([.weekOfYear], from: itemWeekStart, to: currentWeekStart).weekOfYear ?? 0
        guard (0...11).contains(weekOffset) else { return nil }
        return 12 - weekOffset
    }

    private func displayWeightValue(_ kilograms: Double) -> Double {
        switch store.userProfile.units {
        case .metric:
            kilograms
        case .imperial:
            UnitConverter.pounds(fromKilograms: kilograms)
        }
    }
    
    // MARK: - Computed Properties
    private var chartTitle: String {
        switch selectedMetric {
        case .exercises:
            return localizedString("training_volume")
        case .weight:
            return localizedString("body_weight_2")
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
        let margin = max((maxVal - minVal) * 0.12, 1.0)
        let visibleTypes = LineType.allCases.filter { type in
            allPoints.contains { $0.type == type }
        }
        
        VStack(spacing: 12) {
            // Upper Row (Avatar)
            HStack {
                Spacer()
                Button {
                    HapticService.selection()
                    selectedMetric = .weight
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
                .accessibilityLabel(localizedString("show_body_weight"))
            }
            .padding(.horizontal, 4)
            
            // Stacked Title Row
            VStack(alignment: .leading, spacing: 3) {
                Text(localizedString("temporal_evolution"))
                    .font(.system(size: 9, weight: .black, design: .rounded))
                    .tracking(2.5)
                    .foregroundStyle(PulseTheme.secondaryText)
                
                if let activeWeek {
                    // Show week details in title space
                    let (expVal, planVal, realVal) = getMetricValuesForWeek(activeWeek, allPoints: allPoints)
                    let realStr = realVal != nil ? String(format: "%.0f", realVal!) : "--"
                    
                    HStack(spacing: 5) {
                        Text(localizedFormat("week_label_colon_format", activeWeek))
                            .font(.system(size: 15, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                        
                        Text("R \(realStr)")
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .foregroundStyle(LineType.real.color)
                        
                        if let planVal {
                            Text("•")
                                .foregroundStyle(.white.opacity(0.2))

                            Text("P \(Int(planVal))")
                                .font(.system(size: 12, weight: .bold, design: .rounded))
                                .foregroundStyle(LineType.planned.color)
                        }

                        if let expVal {
                            Text("•")
                                .foregroundStyle(.white.opacity(0.2))

                            Text("E \(Int(expVal))")
                                .font(.system(size: 12, weight: .bold, design: .rounded))
                                .foregroundStyle(LineType.expected.color)
                        }
                        
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
                    Text(type.displayName)
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
                    RuleMark(x: .value("Hoy", 12))
                        .foregroundStyle(Color.white.opacity(0.12))
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [2, 4]))
                        .annotation(position: .top, alignment: .center) {
                            Text(localizedString("today_2"))
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
                            AxisValueLabel(localizedFormat("week_label_format", week))
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
                if allPoints.isEmpty {
                    VStack(spacing: 6) {
                        Image(systemName: selectedMetric == .exercises ? "chart.bar.doc.horizontal" : "scalemass")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.35))
                        Text(emptyStateText)
                            .font(.system(size: 10, weight: .bold, design: .rounded))
                            .multilineTextAlignment(.center)
                            .foregroundStyle(.white.opacity(0.45))
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(.horizontal, 24)
                    .offset(y: -24)
                }
            }
            
            // Interactive Drag instructions & Static Legend (ALWAYS visible)
            HStack {
                Label(allPoints.isEmpty ? dataSourceText : (localizedString("drag_to_explore_values")), systemImage: allPoints.isEmpty ? "lock.shield" : "hand.tap.fill")
                    .font(.system(size: 9, weight: .bold, design: .rounded))
                    .foregroundStyle(.white.opacity(activeWeek != nil ? 0.2 : 0.4))
                
                Spacer()
                
                HStack(spacing: 10) {
                    ForEach(visibleTypes) { type in
                        LegendItem(label: type.displayName, color: type.color)
                    }
                }
            }
            .padding(.horizontal, 4)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.clear)
    }
    
    // MARK: - Helpers
    private func getMetricValuesForWeek(_ week: Int, allPoints: [ProgressionPoint]) -> (expected: Double?, planned: Double?, real: Double?) {
        let expected = allPoints.first(where: { $0.weekIndex == week && $0.type == .expected })?.value
        let planned = allPoints.first(where: { $0.weekIndex == week && $0.type == .planned })?.value
        let real = allPoints.first(where: { $0.weekIndex == week && $0.type == .real })?.value
        return (expected, planned, real)
    }

    private var emptyStateText: String {
        switch selectedMetric {
        case .exercises:
            return localizedString("no_logged_sessions_in_the_last_12_weeks")
        case .weight:
            return localizedString("no_body_weights_logged_in_the_last_12_weeks")
        }
    }

    private var dataSourceText: String {
        localizedString("logged_data_only")
    }
}

private protocol DatedChartItem {
    var chartDate: Date { get }
}

extension WorkoutSession: DatedChartItem {
    var chartDate: Date { date }
}

extension BodyMetric: DatedChartItem {
    var chartDate: Date { date }
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
            
            Text(localizedKey(label))
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
                Text(localizedKey(label))
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
