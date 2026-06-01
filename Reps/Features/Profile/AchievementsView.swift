import SwiftUI
import PhotosUI

struct AchievementBadge: Identifiable {
    let id = UUID()
    let titleEN: String
    let titleES: String
    let descEN: String
    let descES: String
    let systemImage: String
    let color: Color
    let isCompleted: Bool
    let progressValue: Double? // e.g. 2.0 for 2/3
    let progressTarget: Double? // e.g. 3.0
    
    func title(isSpanish: Bool) -> String {
        isSpanish ? titleES : titleEN
    }
    
    func description(isSpanish: Bool) -> String {
        isSpanish ? descES : descEN
    }
}

struct AchievementsView: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.dismiss) private var dismiss
    
    @State private var selectedReceiptForPreview: SavedShareCard? = nil
    
    private var isSpanish: Bool {
        store.userProfile.preferredLanguage.hasPrefix("es")
    }
    
    // MARK: - Automated Health & Exercise Achievements Calculation
    private var achievements: [AchievementBadge] {
        let sessions = store.workoutSessions
        let healthMetrics = store.health.latestDailyMetrics
        let cardioLogs = store.cardioLogs
        
        // 1. Apple Watch connected
        let watchConnected = sessions.contains { $0.isImportedFromHealth || $0.healthKitUUIDString != nil }
        
        // 2. Ring Closer (10k steps or 600 kcal active energy)
        let maxSteps = healthMetrics.map(\.steps).max() ?? 0.0
        let maxEnergy = healthMetrics.map(\.activeEnergyKcal).max() ?? 0.0
        let ringCloser = maxSteps >= 10000.0 || maxEnergy >= 600.0
        let stepsProgress = min(maxSteps, 10000.0)
        let energyProgress = min(maxEnergy, 600.0)
        
        // 3. Endurance Hero (cardio session > 45 minutes or cardio count >= 3)
        let hasLongCardio = cardioLogs.contains { $0.durationMinutes >= 45 } || sessions.contains { $0.workoutTitle.lowercased().contains("cardio") && $0.durationMinutes >= 45 }
        let cardioCount = cardioLogs.count + sessions.filter { $0.workoutTitle.lowercased().contains("cardio") }.count
        let enduranceHero = hasLongCardio || cardioCount >= 3
        
        // 4. Iron Consistency (streak >= 3 days)
        let streak = store.streakDays
        let ironConsistency = streak >= 3
        
        // 5. Titan Lifter (total volume > 5,000 kg or PR > 80 kg)
        let totalVol = store.totalVolumeKg
        let maxPR = FitnessMetrics.personalRecordWeightKg(for: sessions) ?? 0.0
        let titanLifter = totalVol >= 5000.0 || maxPR >= 80.0
        
        return [
            AchievementBadge(
                titleEN: "Apple Watch Link",
                titleES: "Enlace Apple Watch",
                descEN: "Automatically sync and import your first workout from Apple Health or Apple Watch.",
                descES: "Sincroniza e importa automáticamente tu primer entreno de Apple Health o Apple Watch.",
                systemImage: "applewatch",
                color: PulseTheme.primary,
                isCompleted: watchConnected,
                progressValue: watchConnected ? 1.0 : 0.0,
                progressTarget: 1.0
            ),
            AchievementBadge(
                titleEN: "Ring Closer",
                titleES: "Cerrador de Anillos",
                descEN: "Reach 10,000 steps or 600 active kcal in a single day registered in Apple Health.",
                descES: "Supera 10,000 pasos o 600 kcal activas en un solo día registrados en Apple Health.",
                systemImage: "circle.circle.fill",
                color: PulseTheme.destructive,
                isCompleted: ringCloser,
                progressValue: ringCloser ? 10000.0 : max(stepsProgress, energyProgress * 16.6), // Normalized progress
                progressTarget: 10000.0
            ),
            AchievementBadge(
                titleEN: "Endurance Hero",
                titleES: "Héroe de Resistencia",
                descEN: "Log a cardiovascular session longer than 45 minutes or sync 3 cardio workouts.",
                descES: "Registra una sesión cardiovascular de más de 45 min o sincroniza 3 entrenos de cardio.",
                systemImage: "figure.run",
                color: .cyan,
                isCompleted: enduranceHero,
                progressValue: Double(min(cardioCount, 3)),
                progressTarget: 3.0
            ),
            AchievementBadge(
                titleEN: "Iron Consistency",
                titleES: "Consistencia de Hierro",
                descEN: "Achieve a workout streak of 3 consecutive days.",
                descES: "Alcanza una racha de entrenamiento de 3 días consecutivos.",
                systemImage: "flame.fill",
                color: PulseTheme.accent,
                isCompleted: ironConsistency,
                progressValue: Double(min(streak, 3)),
                progressTarget: 3.0
            ),
            AchievementBadge(
                titleEN: "Titan Lifter",
                titleES: "Levantador Titán",
                descEN: "Hit a total cumulative volume of 5,000 kg or lift a heavy PR of 80 kg or more.",
                descES: "Supera un volumen total acumulado de 5,000 kg o levanta un récord (PR) de 80 kg o más.",
                systemImage: "figure.strengthtraining.traditional",
                color: PulseTheme.primaryBright,
                isCompleted: titanLifter,
                progressValue: min(totalVol, 5000.0),
                progressTarget: 5000.0
            )
        ]
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Header navigation bar
                customNavBar
                
                // Achievements badges card
                achievementsGridSection
                
                // Saved share receipt cards
                receiptTicketsSection
                
                Spacer(minLength: 40)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 60)
        }
        .screenBackground()
        .toolbar(.hidden, for: .navigationBar)
        .sheet(item: $selectedReceiptForPreview) { card in
            LocalReceiptPreviewSheet(card: card, isSpanish: isSpanish)
        }
    }
    
    // MARK: - Navigation Bar
    private var customNavBar: some View {
        HStack {
            Button {
                HapticService.selection()
                dismiss()
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 18, weight: .bold))
                    Text(isSpanish ? "Perfil" : "Profile")
                        .font(.headline)
                }
                .foregroundStyle(PulseTheme.primary)
            }
            .buttonStyle(.plain)
            
            Spacer()
            
            Text(isSpanish ? "Logros y Recibos" : "Achievements & Tickets")
                .font(.system(size: 19, weight: .bold, design: .rounded))
            
            Spacer()
            
            // Empty placeholder for symmetry
            Image(systemName: "chevron.left")
                .font(.system(size: 18, weight: .bold))
                .opacity(0)
        }
        .padding(.vertical, 14)
    }
    
    // MARK: - Achievements Grid Section
    private var achievementsGridSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 6) {
                Image(systemName: "trophy.fill")
                    .font(.headline)
                    .foregroundStyle(PulseTheme.accent)
                Text(isSpanish ? "Logros Automáticos" : "Automatic Milestones")
                    .font(.headline)
            }
            .padding(.horizontal, 4)
            
            Text(isSpanish 
                 ? "Hitos enlazados y calculados automáticamente con tus entrenamientos y datos de Apple Health."
                 : "Milestones tracked and calculated automatically using your workouts and Apple Health data.")
                .font(.caption)
                .foregroundStyle(PulseTheme.secondaryText)
                .padding(.horizontal, 4)
                .padding(.bottom, 2)
            
            VStack(spacing: 12) {
                ForEach(achievements) { badge in
                    AchievementTile(badge: badge, isSpanish: isSpanish)
                }
            }
        }
    }
    
    // MARK: - Receipts Tickets Section
    private var receiptTicketsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 6) {
                Image(systemName: "doc.text.image.fill")
                    .font(.headline)
                    .foregroundStyle(PulseTheme.primary)
                Text(isSpanish ? "Galería de Recibos" : "Virtual Ticket Gallery")
                    .font(.headline)
            }
            .padding(.horizontal, 4)
            
            Text(isSpanish 
                 ? "Tus recibos de entrenamiento se generan y guardan aquí automáticamente al completar entrenamientos."
                 : "Your virtual training tickets are rendered and saved here automatically when you complete workouts.")
                .font(.caption)
                .foregroundStyle(PulseTheme.secondaryText)
                .padding(.horizontal, 4)
                .padding(.bottom, 2)
            
            if store.savedShareCards.isEmpty {
                PulseCard {
                    PulseEmptyState(
                        title: isSpanish ? "Sin recibos aún" : "No receipts yet",
                        message: isSpanish 
                            ? "Completa y registra una sesión de entrenamiento para generar tu primer recibo virtual con corte de sierra."
                            : "Complete and log a training session to generate your first virtual saw-tooth ticket here.",
                        systemImage: "doc.text.image"
                    )
                    .padding(.vertical, 8)
                }
            } else {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                    ForEach(store.savedShareCards.sorted { $0.date > $1.date }) { card in
                        Button {
                            selectedReceiptForPreview = card
                        } label: {
                            VStack(alignment: .leading, spacing: 8) {
                                if let uiImage = UIImage(data: card.imageData) {
                                    Image(uiImage: uiImage)
                                        .resizable()
                                        .aspectRatio(contentMode: .fit)
                                        .frame(maxWidth: .infinity)
                                        .clipShape(SerratedThumbnailShape()) // Clip the bottom serrated style in grid too!
                                        .overlay(
                                            SerratedThumbnailShape()
                                                .stroke(Color.white.opacity(0.12), lineWidth: 1)
                                        )
                                        .shadow(color: .black.opacity(0.15), radius: 6, y: 3)
                                } else {
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .fill(PulseTheme.grouped)
                                        .frame(height: 220)
                                }
                                
                                Text(card.workoutTitle)
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(.primary)
                                    .lineLimit(1)
                                
                                Text(receiptDateString(card.date))
                                    .font(.system(size: 9, weight: .bold))
                                    .foregroundStyle(PulseTheme.secondaryText)
                                    .lineLimit(1)
                            }
                            .padding(8)
                            .background(PulseTheme.card)
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .stroke(PulseTheme.separator, lineWidth: 1)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }
    
    private func receiptDateString(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd MMM yyyy"
        formatter.locale = Locale(identifier: store.userProfile.preferredLanguage)
        return formatter.string(from: date).uppercased()
    }
}

// MARK: - Individual Achievement Row Tile
private struct AchievementTile: View {
    let badge: AchievementBadge
    let isSpanish: Bool
    
    var body: some View {
        HStack(spacing: 16) {
            // Neon glowing/locked icon
            ZStack {
                Circle()
                    .fill(badge.isCompleted ? badge.color.opacity(0.12) : PulseTheme.grouped)
                    .frame(width: 48, height: 48)
                
                Image(systemName: badge.isCompleted ? badge.systemImage : "lock.fill")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(badge.isCompleted ? badge.color : PulseTheme.secondaryText.opacity(0.5))
                
                if badge.isCompleted {
                    Circle()
                        .stroke(badge.color, lineWidth: 1.5)
                        .frame(width: 48, height: 48)
                        .shadow(color: badge.color.opacity(0.4), radius: 4)
                }
            }
            
            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .firstTextBaseline) {
                    Text(badge.title(isSpanish: isSpanish))
                        .font(.headline)
                        .foregroundStyle(badge.isCompleted ? .primary : PulseTheme.secondaryText)
                    
                    Spacer()
                    
                    if badge.isCompleted {
                        Text(isSpanish ? "COMPLETADO" : "UNLOCKED")
                            .font(.system(size: 8, weight: .bold, design: .rounded))
                            .foregroundStyle(badge.color)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(badge.color.opacity(0.12))
                            .clipShape(Capsule())
                    }
                }
                
                Text(badge.description(isSpanish: isSpanish))
                    .font(.caption)
                    .foregroundStyle(PulseTheme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
                
                // Simple Progress Bar if not completed
                if !badge.isCompleted, let progressValue = badge.progressValue, let progressTarget = badge.progressTarget, progressTarget > 0 {
                    GeometryReader { geo in
                        let pct = progressValue / progressTarget
                        ZStack(alignment: .leading) {
                            Capsule().fill(PulseTheme.separator).frame(height: 5)
                            Capsule().fill(badge.color.opacity(0.5))
                                .frame(width: geo.size.width * CGFloat(pct), height: 5)
                        }
                    }
                    .frame(height: 5)
                    .padding(.top, 4)
                }
            }
        }
        .padding(14)
        .background(PulseTheme.card)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(badge.isCompleted ? badge.color.opacity(0.2) : PulseTheme.separator, lineWidth: 1)
        )
        .opacity(badge.isCompleted ? 1.0 : 0.72)
    }
}

// MARK: - Local Receipt Preview Sheet
private struct LocalReceiptPreviewSheet: View {
    let card: SavedShareCard
    let isSpanish: Bool
    @Environment(\.dismiss) private var dismiss
    @State private var uiImage: UIImage? = nil
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Spacer()
                
                if let img = uiImage {
                    Image(uiImage: img)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxWidth: .infinity, maxHeight: 480)
                        .shadow(color: Color.black.opacity(0.3), radius: 15, x: 0, y: 8)
                } else {
                    ProgressView()
                        .frame(height: 300)
                }
                
                Spacer()
                
                if let img = uiImage {
                    ShareLink(item: Image(uiImage: img), preview: SharePreview(card.workoutTitle, image: Image(uiImage: img))) {
                        HStack(spacing: 8) {
                            Image(systemName: "square.and.arrow.up")
                            Text(isSpanish ? "Compartir recibo" : "Share Ticket")
                        }
                        .font(.headline)
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(.white)
                        .clipShape(Capsule())
                        .padding(.horizontal, 24)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.vertical, 20)
            .screenBackground()
            .navigationTitle(card.workoutTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(isSpanish ? "Cerrar" : "Close") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                uiImage = UIImage(data: card.imageData)
            }
        }
    }
}

// MARK: - Mini Serrated Shape for Grid Thumbnails
struct SerratedThumbnailShape: Shape {
    var toothWidth: CGFloat = 5
    var toothHeight: CGFloat = 4
    
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let w = rect.width
        let h = rect.height
        let cornerRadius: CGFloat = 12
        
        path.move(to: CGPoint(x: cornerRadius, y: 0))
        path.addLine(to: CGPoint(x: w - cornerRadius, y: 0))
        path.addArc(tangent1End: CGPoint(x: w, y: 0), tangent2End: CGPoint(x: w, y: cornerRadius), radius: cornerRadius)
        path.addLine(to: CGPoint(x: w, y: h - toothHeight))
        
        let numberOfTeeth = max(2, Int(w / toothWidth))
        let actualToothWidth = w / CGFloat(numberOfTeeth)
        
        for i in 0..<numberOfTeeth {
            let currentX = w - CGFloat(i) * actualToothWidth
            let nextX = w - CGFloat(i + 1) * actualToothWidth
            let midX = (currentX + nextX) / 2
            
            path.addLine(to: CGPoint(x: midX, y: h))
            path.addLine(to: CGPoint(x: nextX, y: h - toothHeight))
        }
        
        path.addLine(to: CGPoint(x: 0, y: cornerRadius))
        path.addArc(tangent1End: CGPoint(x: 0, y: 0), tangent2End: CGPoint(x: cornerRadius, y: 0), radius: cornerRadius)
        path.closeSubpath()
        return path
    }
}

#Preview {
    AchievementsView()
        .environmentObject(AppStore())
}
