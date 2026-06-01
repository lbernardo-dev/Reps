import SwiftUI
import MuscleMap

struct WorkoutReceiptView: View {
    let session: WorkoutSession
    var gender: BodyGender = .male
    
    private var isSpanish: Bool {
        Locale.current.language.languageCode?.identifier.hasPrefix("es") ?? true
    }
    
    private var dateString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd MMM yyyy"
        formatter.locale = Locale(identifier: isSpanish ? "es_ES" : "en_US")
        return formatter.string(from: session.date).uppercased()
    }
    
    private var timeString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: session.date)
    }
    
    private var completedSetsCount: Int {
        FitnessMetrics.completedSets(in: session).count
    }
    
    private var totalVolume: Int {
        Int(FitnessMetrics.totalVolumeKg(for: [session]))
    }
    
    private var completedLogs: [ExerciseLog] {
        FitnessMetrics.completedExerciseLogs(in: session)
    }

    private var exercises: [Exercise] {
        completedLogs.map(\.exercise)
    }
    
    private var musclesTrained: [Muscle] {
        Array(Set(exercises.flatMap { ExerciseAnatomyDescriptor(exercise: $0).muscles }))
    }
    
    private var heatmap: [MuscleIntensity] {
        musclesTrained.map { MuscleIntensity(muscle: $0, intensity: 0.76) }
    }
    
    var body: some View {
        VStack(spacing: 12) {
            // Header Logo
            VStack(spacing: 4) {
                Text("REPS®")
                    .font(.system(size: 32, weight: .black, design: .monospaced))
                    .tracking(6)
                    .foregroundStyle(Color.black.opacity(0.85))
                
                Text("VIRTUAL TRAINING TICKET")
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .tracking(2)
                    .foregroundStyle(Color.black.opacity(0.55))
            }
            .padding(.top, 14)
            
            // Date and serial
            HStack {
                Text(dateString)
                Spacer()
                Text(timeString)
            }
            .font(.system(size: 13, weight: .bold, design: .monospaced))
            .foregroundStyle(Color.black.opacity(0.72))
            .padding(.horizontal, 4)
            
            dividerLine
            
            // Muscle Map dual body preview
            HStack(spacing: 16) {
                Spacer()
                BodyView(gender: gender, side: .front, style: .repsReceipt)
                    .heatmap(heatmap, configuration: .repsVolumeReceipt)
                    .frame(width: 80, height: 165)
                    .scaleEffect(1.08)
                
                BodyView(gender: gender, side: .back, style: .repsReceipt)
                    .heatmap(heatmap, configuration: .repsVolumeReceipt)
                    .frame(width: 80, height: 165)
                    .scaleEffect(1.08)
                Spacer()
            }
            .frame(height: 175)
            .allowsHitTesting(false)
            .padding(.vertical, 4)
            
            dividerLine
            
            // Exercise rows in Receipt format
            VStack(alignment: .leading, spacing: 6) {
                if !completedLogs.isEmpty {
                    ForEach(completedLogs) { log in
                        let name = RepsText.exerciseName(log.exercise.name, language: isSpanish ? "es" : "en")
                        HStack(alignment: .bottom, spacing: 2) {
                            Text(receiptTrim(name, maxChars: 24))
                                .font(.system(size: 13, weight: .semibold, design: .monospaced))

                            Text(String(repeating: ".", count: max(2, 30 - name.count)))
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundStyle(Color.black.opacity(0.35))
                                .lineLimit(1)

                            Spacer(minLength: 2)

                            Text("\(log.sets.count) \(isSpanish ? "SERIES" : "SETS")")
                                .font(.system(size: 13, weight: .bold, design: .monospaced))
                        }
                        .foregroundStyle(Color.black.opacity(0.85))
                    }
                } else {
                    Text(isSpanish ? "NINGÚN EJERCICIO COMPLETADO" : "NO EXERCISES COMPLETED")
                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                        .foregroundStyle(Color.black.opacity(0.45))
                        .frame(maxWidth: .infinity, alignment: .center)
                }
            }
            .padding(.horizontal, 4)
            
            dividerLine
            
            // Stats section
            VStack(alignment: .leading, spacing: 6) {
                Text("*STATS")
                    .font(.system(size: 14, weight: .bold, design: .monospaced))
                    .foregroundStyle(Color.black.opacity(0.85))
                    .padding(.bottom, 2)
                
                statRow(title: isSpanish ? "DURACIÓN" : "DURATION", value: "\(session.durationMinutes) MIN")
                statRow(title: isSpanish ? "VOLUMEN TOTAL" : "TOTAL VOLUME", value: "\(totalVolume) KG")
                statRow(title: isSpanish ? "SERIES COMPLETADAS" : "COMPLETED SETS", value: "\(completedSetsCount) SRS")
            }
            .padding(.horizontal, 4)
            
            dividerLine
            
            // Mock Barcode
            VStack(spacing: 6) {
                HStack(spacing: 2.2) {
                    ForEach(0..<26, id: \.self) { index in
                        Rectangle()
                            .fill(Color.black.opacity(0.85))
                            .frame(width: index % 3 == 0 ? 3.5 : (index % 4 == 0 ? 1.2 : 2.2), height: 36)
                    }
                }
                
                Text("REPS-FIT-\(session.id.uuidString.prefix(8).uppercased())")
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundStyle(Color.black.opacity(0.55))
            }
            .padding(.top, 6)
            .padding(.bottom, 10)
        }
        .padding(18)
        .padding(.bottom, 6)
        .background(Color(red: 0.95, green: 0.94, blue: 0.92))
        .clipShape(SerratedCardShape(cornerRadius: 16, toothWidth: 8, toothHeight: 6))
        .overlay(
            SerratedCardShape(cornerRadius: 16, toothWidth: 8, toothHeight: 6)
                .stroke(Color.black.opacity(0.08), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.12), radius: 14, x: 0, y: 6)
    }
    
    private var dividerLine: some View {
        Text(String(repeating: "-", count: 32))
            .font(.system(size: 13, weight: .bold, design: .monospaced))
            .foregroundStyle(Color.black.opacity(0.24))
            .lineLimit(1)
            .frame(height: 12)
    }
    
    private func statRow(title: String, value: String) -> some View {
        HStack(alignment: .bottom, spacing: 2) {
            Text(title)
                .font(.system(size: 12, weight: .semibold, design: .monospaced))
            Text(String(repeating: ".", count: max(2, 28 - title.count)))
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(Color.black.opacity(0.3))
                .lineLimit(1)
            Spacer(minLength: 2)
            Text(value)
                .font(.system(size: 13, weight: .bold, design: .monospaced))
        }
        .foregroundStyle(Color.black.opacity(0.8))
    }
    
    private func receiptTrim(_ text: String, maxChars: Int) -> String {
        if text.count <= maxChars {
            return text.uppercased()
        }
        return text.prefix(maxChars - 3).uppercased() + "..."
    }
}

// Receipt specific styling helpers
extension BodyViewStyle {
    static let repsReceipt = BodyViewStyle(
        defaultFillColor: Color.black.opacity(0.10),
        strokeColor: Color(red: 0.95, green: 0.94, blue: 0.92),
        strokeWidth: 0.55,
        selectionColor: Color(red: 0.05, green: 0.42, blue: 0.94),
        selectionStrokeColor: Color(red: 0.95, green: 0.94, blue: 0.92),
        selectionStrokeWidth: 0.8,
        headColor: Color.black.opacity(0.15),
        hairColor: Color.black.opacity(0.08)
    )
}

extension HeatmapConfiguration {
    static let repsVolumeReceipt = HeatmapConfiguration(
        colorScale: .repsReceiptVolume,
        interpolation: .linear,
        threshold: 0.01,
        isGradientFillEnabled: true,
        gradientDirection: .topToBottom,
        gradientLowIntensityFactor: 0.6
    )
}

extension HeatmapColorScale {
    static let repsReceiptVolume = HeatmapColorScale(colors: [
        Color(red: 0.05, green: 0.42, blue: 0.94),
        Color(red: 0.05, green: 0.42, blue: 0.94),
        Color(red: 0.05, green: 0.42, blue: 0.94)
    ])
}

// MARK: - Serrated saw-tooth card shape
struct SerratedCardShape: Shape {
    var cornerRadius: CGFloat = 16
    var toothWidth: CGFloat = 8
    var toothHeight: CGFloat = 6
    
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let w = rect.width
        let h = rect.height
        
        // Start at top left corner (after the radius)
        path.move(to: CGPoint(x: cornerRadius, y: 0))
        
        // Top edge
        path.addLine(to: CGPoint(x: w - cornerRadius, y: 0))
        
        // Top right corner
        path.addArc(tangent1End: CGPoint(x: w, y: 0),
                    tangent2End: CGPoint(x: w, y: cornerRadius),
                    radius: cornerRadius)
        
        // Right edge down to bottom right (excluding the tooth depth)
        path.addLine(to: CGPoint(x: w, y: h - toothHeight))
        
        // Bottom edge - Serrated teeth going from right (w) to left (0)
        let numberOfTeeth = max(2, Int(w / toothWidth))
        let actualToothWidth = w / CGFloat(numberOfTeeth)
        
        for i in 0..<numberOfTeeth {
            let currentX = w - CGFloat(i) * actualToothWidth
            let nextX = w - CGFloat(i + 1) * actualToothWidth
            let midX = (currentX + nextX) / 2
            
            // Draw tooth peak
            path.addLine(to: CGPoint(x: midX, y: h))
            // Draw tooth base
            path.addLine(to: CGPoint(x: nextX, y: h - toothHeight))
        }
        
        // Left edge up to top left corner
        path.addLine(to: CGPoint(x: 0, y: cornerRadius))
        
        // Top left corner
        path.addArc(tangent1End: CGPoint(x: 0, y: 0),
                    tangent2End: CGPoint(x: cornerRadius, y: 0),
                    radius: cornerRadius)
        
        path.closeSubpath()
        return path
    }
}
