import SwiftUI
import PhotosUI

struct AchievementBadge: Identifiable {
    let id = UUID()
    let titleKey: String
    let descKey: String
    let systemImage: String
    let color: Color
    let isCompleted: Bool
    let progressValue: Double?
    let progressTarget: Double?

    var title: String { localizedString(titleKey) }
    var description: String { localizedString(descKey) }
}

struct AchievementsView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    @State private var selectedReceiptForPreview: SavedShareCard? = nil
    @State private var localPaywall: PaywallPresentation?

    // MARK: - Player Level
    private var playerLevel: PlayerLevel {
        let xp = GamificationEngine.totalXP(
            sessions: store.workoutSessions,
            cardioLogs: store.combinedCardioLogs,
            bodyMetrics: store.bodyMetrics,
            progressPhotos: store.progressPhotos,
            streakDays: store.streakDays,
            totalVolumeKg: store.totalVolumeKg
        )
        return GamificationEngine.playerLevel(for: xp)
    }

    // MARK: - Achievements Calculation
    private var achievements: [AchievementBadge] {
        let sessions = store.workoutSessions
        let healthMetrics = store.health.latestDailyMetrics
        let cardioLogs = store.combinedCardioLogs
        let streak = store.streakDays
        let totalVol = store.totalVolumeKg
        let maxPR = FitnessMetrics.personalRecordWeightKg(for: sessions) ?? 0.0
        let sessionCount = sessions.count
        let cardioCount = cardioLogs.count
        let photoCount = store.progressPhotos.count
        let watchConnected = sessions.contains { $0.isImportedFromHealth || $0.healthKitUUIDString != nil }
        let maxSteps = healthMetrics.map(\.steps).max() ?? 0.0
        let maxEnergy = healthMetrics.map(\.activeEnergyKcal).max() ?? 0.0
        let ringCloser = maxSteps >= 10000.0 || maxEnergy >= 600.0
        let stepsProgress = min(maxSteps, 10000.0)
        let energyProgress = min(maxEnergy, 600.0)
        let hasLongCardio = cardioLogs.contains { $0.durationMinutes >= 45 }
        let enduranceHero = hasLongCardio || cardioCount >= 3
        let ironConsistency = streak >= 3
        let habitBuilder = streak >= 7
        let unstoppable = streak >= 21
        let titanLifter = totalVol >= 5000.0 || maxPR >= 80.0
        let ironGiant = totalVol >= 50_000.0
        let cardioDevotee = cardioCount >= 10
        let prCount = sessions
            .flatMap { $0.exerciseLogs ?? [] }
            .flatMap { $0.sets }
            .filter { $0.isPersonalRecord && $0.completed }
            .count
        let recordBreaker = prCount >= 1
        let prMachine = prCount >= 10
        let muscleGroups = Set(sessions.flatMap { $0.exerciseLogs ?? [] }.map { $0.exercise.muscleGroup })
        let fullBody = muscleGroups.count >= 5
        let evidenceKeeper = photoCount >= 3

        return [
            // ── Consistency
            AchievementBadge(
                titleKey: "achievement_first_step_title",
                descKey: "achievement_first_step_desc",
                systemImage: "figure.walk",
                color: .orange,
                isCompleted: sessionCount >= 1,
                progressValue: Double(min(sessionCount, 1)),
                progressTarget: 1.0
            ),
            AchievementBadge(
                titleKey: "achievement_iron_consistency_title",
                descKey: "achievement_iron_consistency_desc",
                systemImage: "flame.fill",
                color: PulseTheme.accent,
                isCompleted: ironConsistency,
                progressValue: Double(min(streak, 3)),
                progressTarget: 3.0
            ),
            AchievementBadge(
                titleKey: "achievement_habit_builder_title",
                descKey: "achievement_habit_builder_desc",
                systemImage: "flame.circle.fill",
                color: .orange,
                isCompleted: habitBuilder,
                progressValue: Double(min(streak, 7)),
                progressTarget: 7.0
            ),
            AchievementBadge(
                titleKey: "achievement_unstoppable_title",
                descKey: "achievement_unstoppable_desc",
                systemImage: "bolt.circle.fill",
                color: .yellow,
                isCompleted: unstoppable,
                progressValue: Double(min(streak, 21)),
                progressTarget: 21.0
            ),
            // ── Volume / Sessions
            AchievementBadge(
                titleKey: "achievement_getting_started_title",
                descKey: "achievement_getting_started_desc",
                systemImage: "dumbbell",
                color: PulseTheme.primary,
                isCompleted: sessionCount >= 5,
                progressValue: Double(min(sessionCount, 5)),
                progressTarget: 5.0
            ),
            AchievementBadge(
                titleKey: "achievement_dedicated_title",
                descKey: "achievement_dedicated_desc",
                systemImage: "dumbbell.fill",
                color: PulseTheme.primaryBright,
                isCompleted: sessionCount >= 25,
                progressValue: Double(min(sessionCount, 25)),
                progressTarget: 25.0
            ),
            AchievementBadge(
                titleKey: "achievement_veteran_title",
                descKey: "achievement_veteran_desc",
                systemImage: "medal.fill",
                color: .yellow,
                isCompleted: sessionCount >= 100,
                progressValue: Double(min(sessionCount, 100)),
                progressTarget: 100.0
            ),
            // ── Strength / Volume
            AchievementBadge(
                titleKey: "achievement_titan_lifter_title",
                descKey: "achievement_titan_lifter_desc",
                systemImage: "figure.strengthtraining.traditional",
                color: PulseTheme.primaryBright,
                isCompleted: titanLifter,
                progressValue: min(totalVol, 5000.0),
                progressTarget: 5000.0
            ),
            AchievementBadge(
                titleKey: "achievement_iron_giant_title",
                descKey: "achievement_iron_giant_desc",
                systemImage: "bolt.fill",
                color: .yellow,
                isCompleted: ironGiant,
                progressValue: min(totalVol, 50_000.0),
                progressTarget: 50_000.0
            ),
            // ── Personal Records
            AchievementBadge(
                titleKey: "achievement_record_breaker_title",
                descKey: "achievement_record_breaker_desc",
                systemImage: "trophy",
                color: PulseTheme.accent,
                isCompleted: recordBreaker,
                progressValue: Double(min(prCount, 1)),
                progressTarget: 1.0
            ),
            AchievementBadge(
                titleKey: "achievement_pr_machine_title",
                descKey: "achievement_pr_machine_desc",
                systemImage: "trophy.fill",
                color: .yellow,
                isCompleted: prMachine,
                progressValue: Double(min(prCount, 10)),
                progressTarget: 10.0
            ),
            // ── Cardio / Health
            AchievementBadge(
                titleKey: "achievement_endurance_hero_title",
                descKey: "achievement_endurance_hero_desc",
                systemImage: "figure.run",
                color: PulseTheme.primaryBright,
                isCompleted: enduranceHero,
                progressValue: Double(min(cardioCount, 3)),
                progressTarget: 3.0
            ),
            AchievementBadge(
                titleKey: "achievement_cardio_devotee_title",
                descKey: "achievement_cardio_devotee_desc",
                systemImage: "heart.circle.fill",
                color: PulseTheme.destructive,
                isCompleted: cardioDevotee,
                progressValue: Double(min(cardioCount, 10)),
                progressTarget: 10.0
            ),
            // ── Apple Integration
            AchievementBadge(
                titleKey: "achievement_apple_watch_link_title",
                descKey: "achievement_apple_watch_link_desc",
                systemImage: "applewatch",
                color: PulseTheme.primary,
                isCompleted: watchConnected,
                progressValue: watchConnected ? 1.0 : 0.0,
                progressTarget: 1.0
            ),
            AchievementBadge(
                titleKey: "achievement_ring_closer_title",
                descKey: "achievement_ring_closer_desc",
                systemImage: "circle.circle.fill",
                color: PulseTheme.destructive,
                isCompleted: ringCloser,
                progressValue: ringCloser ? 10000.0 : max(stepsProgress, energyProgress * 16.6),
                progressTarget: 10000.0
            ),
            // ── Variety
            AchievementBadge(
                titleKey: "achievement_full_body_title",
                descKey: "achievement_full_body_desc",
                systemImage: "figure.mixed.cardio",
                color: PulseTheme.primaryBright,
                isCompleted: fullBody,
                progressValue: Double(min(muscleGroups.count, 5)),
                progressTarget: 5.0
            ),
            AchievementBadge(
                titleKey: "achievement_evidence_keeper_title",
                descKey: "achievement_evidence_keeper_desc",
                systemImage: "camera.fill",
                color: .purple,
                isCompleted: evidenceKeeper,
                progressValue: Double(min(photoCount, 3)),
                progressTarget: 3.0
            ),
        ]
    }
    
    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 24) {
                customNavBar
                levelBannerSection
                achievementsGridSection
                receiptTicketsSection
                Spacer(minLength: 40)
            }
            .padding(.horizontal, PulseTheme.screenHorizontalPadding)
            .padding(.bottom, 60)
        }
        .scrollBounceBehavior(.basedOnSize, axes: .vertical)
        .screenBackground()
        .toolbar(.hidden, for: .navigationBar)
        .sheet(item: $selectedReceiptForPreview) { card in
            LocalReceiptPreviewSheet(card: card)
        }
        .fullScreenCover(item: $localPaywall) { presentation in
            PaywallView(presentation: presentation) { reason in
                store.trackPaywallDismissal(presentation, reason: reason)
                localPaywall = nil
            }
            .environment(store)
        }
    }
    
    // MARK: - Level Banner
    private var levelBannerSection: some View {
        let lvl = playerLevel
        return VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(PulseTheme.primary.opacity(0.12))
                        .frame(width: 56, height: 56)
                    Text("\(lvl.level)")
                        .font(.system(size: 22, weight: .black, design: .rounded))
                        .foregroundStyle(PulseTheme.primary)
                }

                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text(lvl.title)
                            .font(.system(size: 18, weight: .bold, design: .rounded))
                        Text(localizedFormat("player_level_abbr_format", "\(lvl.level)"))
                            .font(.system(size: 10, weight: .bold, design: .rounded))
                            .foregroundStyle(PulseTheme.primary)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(PulseTheme.primary.opacity(0.12))
                            .clipShape(Capsule())
                    }
                    if lvl.isMaxLevel {
                        Text(localizedString("player_level_max_label"))
                            .font(.caption)
                            .foregroundStyle(PulseTheme.accent)
                    } else {
                        Text("\(lvl.totalXP) XP · \(lvl.xpToNextLevel) XP para el siguiente nivel")
                            .font(.caption)
                            .foregroundStyle(PulseTheme.secondaryText)
                    }
                }
                Spacer()
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(PulseTheme.separator)
                        .frame(height: 7)
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [PulseTheme.primary, PulseTheme.primaryBright],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: geo.size.width * CGFloat(lvl.progress), height: 7)
                }
            }
            .frame(height: 7)
        }
        .padding(16)
        .background(PulseTheme.card)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(PulseTheme.primary.opacity(0.15), lineWidth: 1)
        )
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
                    Text(localizedString("profile"))
                        .font(.headline)
                }
                .foregroundStyle(PulseTheme.primary)
            }
            .buttonStyle(.plain)
            
            Spacer()
            
            Text(localizedString("achievements_and_tickets"))
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
                Text(localizedString("automatic_milestones"))
                    .font(.headline)
            }
            .padding(.horizontal, 4)
            
            Text(localizedString("milestones_tracked_and_calculated_automatically_using_your_workouts_and_apple_he"))
                .font(.caption)
                .foregroundStyle(PulseTheme.secondaryText)
                .padding(.horizontal, 4)
                .padding(.bottom, 2)
            
            VStack(spacing: 12) {
                ForEach(achievements) { badge in
                    AchievementTile(badge: badge)
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
                Text(localizedString("virtual_ticket_gallery"))
                    .font(.headline)
            }
            .padding(.horizontal, 4)
            
            Text(localizedString("your_virtual_training_tickets_are_rendered_and_saved_here_automatically_when_you"))
                .font(.caption)
                .foregroundStyle(PulseTheme.secondaryText)
                .padding(.horizontal, 4)
                .padding(.bottom, 2)
            
            if !store.hasFeatureAccess(.shareCards) {
                PaywallLockedCard(
                    title: "pro_receipts",
                    message: "receipt_gallery_and_shareable_cards_unlock_with_reps_pro",
                    buttonTitle: localizedString("see_reps_pro")
                ) {
                    localPaywall = store.makePaywallPresentation(source: .receiptGallery, feature: .shareCards)
                }
            } else if store.savedShareCards.isEmpty {
                PulseCard {
                    PulseEmptyState(
                        title: "no_receipts_yet",
                        message: "complete_and_log_a_training_session_to_generate_your_first_virtual_saw_tooth_tic",
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
                    Text(badge.title)
                        .font(.headline)
                        .foregroundStyle(badge.isCompleted ? .primary : PulseTheme.secondaryText)
                    
                    Spacer()
                    
                    if badge.isCompleted {
                        Text(localizedString("unlocked"))
                            .font(.system(size: 8, weight: .bold, design: .rounded))
                            .foregroundStyle(badge.color)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(badge.color.opacity(0.12))
                            .clipShape(Capsule())
                    }
                }
                
                Text(badge.description)
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
    @Environment(\.dismiss) private var dismiss
    @State private var uiImage: UIImage? = nil

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if let img = uiImage {
                    Image(uiImage: img)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxWidth: .infinity)
                        .shadow(color: Color.black.opacity(0.3), radius: 15, x: 0, y: 8)
                        .padding(.horizontal, 16)
                        .padding(.top, 12)
                } else {
                    Spacer()
                    ProgressView()
                    Spacer()
                }

                Spacer(minLength: 12)

                if let img = uiImage {
                    ShareLink(item: Image(uiImage: img), preview: SharePreview(card.workoutTitle, image: Image(uiImage: img))) {
                        HStack(spacing: 8) {
                            Image(systemName: "square.and.arrow.up")
                            Text(localizedString("share_ticket"))
                        }
                        .font(.headline)
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(PulseTheme.accent)
                        .clipShape(Capsule())
                        .padding(.horizontal, 24)
                    }
                    .buttonStyle(.plain)
                    .padding(.bottom, 24)
                }
            }
            .frame(maxHeight: .infinity)
            .screenBackground()
            .navigationTitle(card.workoutTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(localizedString("close")) {
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
        .environment(AppStore())
}
