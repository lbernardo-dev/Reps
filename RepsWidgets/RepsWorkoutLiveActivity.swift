import ActivityKit
import WidgetKit
import SwiftUI

struct RepsWorkoutLiveActivity: Widget {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.isLuminanceReduced) private var isLuminanceReduced

    private var animationsEnabled: Bool {
        !reduceMotion && !isLuminanceReduced
    }

    var body: some WidgetConfiguration {
        ActivityConfiguration(for: RepsWorkoutActivityAttributes.self) { context in
            let _ = RepsLocalization.use(context.state.snapshot.preferredLanguage)
            let theme = WidgetColor.from(name: context.state.snapshot.widgetAccentColorName).theme
            liveActivityBody(context.state.snapshot, theme: theme, isStale: context.isStale)
                .activityBackgroundTint(Color.black)
                .activitySystemActionForegroundColor(theme.tint)
                .widgetURL(URL(string: "reps://workout"))
        } dynamicIsland: { context in
            let snapshot = context.state.snapshot
            let _ = RepsLocalization.use(snapshot.preferredLanguage)
            let theme = WidgetColor.from(name: snapshot.widgetAccentColorName).theme
            return DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    statusBadge(snapshot, theme: theme, isStale: context.isStale, showIcon: false)
                        .padding(.leading, 8)
                        .padding(.top, 4)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    animatedActivityIcon(snapshot)
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(theme.tint)
                        .padding(.trailing, 8)
                        .padding(.top, 4)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    islandExpandedBottom(snapshot, theme: theme, isStale: context.isStale)
                }
            } compactLeading: {
                compactLeadingView(snapshot, theme: theme)
            } compactTrailing: {
                compactTrailingView(snapshot)
                    .font(.caption2.weight(.bold).monospacedDigit())
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            } minimal: {
                compactLeadingView(snapshot, theme: theme)
            }
        }
        .contentMarginsDisabled()
    }

    @ViewBuilder
    private func liveActivityBody(_ snapshot: SharedWorkoutSnapshot, theme: WidgetTheme, isStale: Bool) -> some View {
        if snapshot.isRouteWorkout {
            routeLiveActivityBody(snapshot, theme: theme, isStale: isStale)
        } else {
            strengthLiveActivityBody(snapshot, theme: theme, isStale: isStale)
        }
    }

    private func routeLiveActivityBody(_ snapshot: SharedWorkoutSnapshot, theme: WidgetTheme, isStale: Bool) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header
            HStack(alignment: .center, spacing: 8) {
                animatedActivityIcon(snapshot)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(theme.tint)

                VStack(alignment: .leading, spacing: 2) {
                    Text(snapshot.workoutTitle)
                        .font(.system(size: 15, weight: .black, design: .rounded))
                        .foregroundStyle(theme.foreground)
                    if snapshot.isPaused {
                        Text(snapshot.isOutdoorRoute == false ? "treadmill_paused" : "route_paused")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(.orange)
                    } else {
                        Text(verbatim: routeSubtitle(snapshot))
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(theme.secondaryForeground)
                    }
                }
                Spacer()
                statusBadge(snapshot, theme: theme, isStale: isStale)
            }

            // Main Primary Stats Row
            HStack(spacing: 24) {
                // Time
                VStack(alignment: .leading, spacing: 2) {
                    Text("Time")
                        .font(.system(size: 9, weight: .black))
                        .foregroundStyle(theme.secondaryForeground)
                        .textCase(.uppercase)
                    elapsedTimerText(snapshot)
                        .font(.system(size: 26, weight: .black, design: .rounded).monospacedDigit())
                        .foregroundStyle(theme.foreground)
                }

                Rectangle()
                    .fill(Color.white.opacity(0.12))
                    .frame(width: 1, height: 32)

                // Distance
                VStack(alignment: .leading, spacing: 2) {
                    Text("Distance")
                        .font(.system(size: 9, weight: .black))
                        .foregroundStyle(theme.secondaryForeground)
                        .textCase(.uppercase)
                    Text(routeDistanceText(snapshot))
                        .font(.system(size: 26, weight: .black, design: .rounded).monospacedDigit())
                        .foregroundStyle(theme.tint)
                }
            }

            // Secondary Stats Bar (Pace, HR, Kcal)
            HStack(spacing: 16) {
                // Heart Rate
                if let hr = snapshot.heartRate {
                    HStack(spacing: 4) {
                        Image(systemName: "heart.fill")
                            .symbolEffect(
                                .pulse.wholeSymbol,
                                options: .nonRepeating,
                                value: animationsEnabled ? Int(hr / 5) : -1
                            )
                            .symbolEffectsRemoved(!animationsEnabled)
                            .transition(.symbolEffect(.appear.byLayer))
                            .foregroundStyle(.red)
                        Text(localizedFormat("heart_rate_bpm_format", Int(hr)))
                    }
                }
                
                // Pace
                HStack(spacing: 4) {
                    Image(systemName: "speedometer")
                        .foregroundStyle(theme.secondaryForeground)
                    Text(routePaceText(snapshot))
                }

                // Kcal
                if let kcal = snapshot.activeEnergyKcal {
                    let isEstimated = snapshot.heartRate == nil
                    let prefix = isEstimated ? "~" : ""
                    HStack(spacing: 4) {
                        Image(systemName: "flame.fill")
                            .foregroundStyle(.orange)
                        Text("\(prefix)\(Int(kcal)) kcal")
                    }
                }
            }
            .font(.system(size: 11, weight: .bold, design: .rounded).monospacedDigit())
            .foregroundStyle(theme.foreground)

            if snapshot.musicTitle != nil {
                musicRow(snapshot, theme: theme)
            }

            actionButtons(snapshot, theme: theme, includesCompleteSet: false)
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 12)
        .background(
            LinearGradient(
                colors: [Color.black, Color(white: 0.05)],
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }

    private func strengthLiveActivityBody(_ snapshot: SharedWorkoutSnapshot, theme: WidgetTheme, isStale: Bool) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header: Title and Status Badge
            HStack(alignment: .center, spacing: 8) {
                animatedActivityIcon(snapshot)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(theme.tint)

                VStack(alignment: .leading, spacing: 2) {
                    Text(snapshot.workoutTitle)
                        .font(.system(size: 15, weight: .black, design: .rounded))
                        .foregroundStyle(theme.foreground)
                    Text(snapshot.exerciseName ?? snapshot.summary)
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(theme.secondaryForeground)
                        .lineLimit(1)
                }
                Spacer()
                statusBadge(snapshot, theme: theme, isStale: isStale)
            }

            // Main Strength Stats Display (Ring + Target Weight info)
            HStack(spacing: 16) {
                ZStack {
                    Circle()
                        .stroke(Color.white.opacity(0.12), lineWidth: 4.5)
                    Circle()
                        .trim(from: 0, to: snapshot.progress)
                        .stroke(
                            LinearGradient(
                                colors: [theme.tint, theme.tint.opacity(0.8)],
                                startPoint: .top,
                                endPoint: .bottom
                            ),
                            style: StrokeStyle(lineWidth: 4.5, lineCap: .round)
                        )
                        .rotationEffect(.degrees(-90))
                    Text("\(Int(snapshot.progress * 100))%")
                        .font(.system(size: 10, weight: .black, design: .rounded))
                        .foregroundStyle(theme.foreground)
                }
                .frame(width: 42, height: 42)

                VStack(alignment: .leading, spacing: 3) {
                    if let currentSet = snapshot.currentSetText {
                        Text(verbatim: currentSet)
                            .font(.system(size: 15, weight: .black, design: .rounded))
                            .foregroundStyle(theme.foreground)
                    }
                    if snapshot.restEndDate != nil {
                        Text("resting_label" as LocalizedStringKey)
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(.orange)
                    } else {
                        Text("active_set_label" as LocalizedStringKey)
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(theme.tint)
                    }
                }
                Spacer()
                
                // Active rest timer countdown (high priority data!)
                if snapshot.restEndDate != nil {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("rest")
                            .font(.system(size: 8, weight: .black))
                            .foregroundStyle(.orange)
                            .textCase(.uppercase)
                        Text(snapshot.restText)
                            .font(.system(size: 14, weight: .black, design: .rounded).monospacedDigit())
                            .foregroundStyle(.orange)
                    }
                }
            }

            // Inline Secondary Stats Row (Time, Sets completed, and Volume)
            HStack(spacing: 16) {
                // Time
                HStack(spacing: 4) {
                    Image(systemName: "timer")
                        .foregroundStyle(theme.secondaryForeground)
                    elapsedTimerText(snapshot)
                }
                
                // Sets
                HStack(spacing: 4) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(theme.tint)
                        .symbolEffect(
                            .bounce.up.byLayer,
                            options: .nonRepeating,
                            value: animationTrigger(snapshot, event: "sets")
                        )
                        .symbolEffectsRemoved(!animationsEnabled)
                    Text("\(snapshot.completedSets)/\(max(snapshot.totalSets, 1))")
                }

                // Volume
                HStack(spacing: 4) {
                    Image(systemName: "chart.bar.fill")
                        .foregroundStyle(theme.secondaryForeground)
                    Text(localizedFormat("volume_kg_format", Int(snapshot.volumeKg)))
                }
            }
            .font(.system(size: 11, weight: .bold, design: .rounded).monospacedDigit())
            .foregroundStyle(theme.foreground)

            // Next exercise / rest footer banner
            if let nextExercise = snapshot.nextExerciseName ?? snapshot.exerciseName {
                HStack(spacing: 6) {
                    Image(systemName: snapshot.restEndDate == nil ? "dumbbell.fill" : "arrow.forward.circle.fill")
                        .font(.system(size: 10))
                        .foregroundStyle(theme.tint)
                    Group {
                        if snapshot.restEndDate == nil {
                            Text(verbatim: nextExercise)
                        } else {
                            Text(localizedFormat("next_value_format", nextExercise))
                        }
                    }
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(theme.secondaryForeground)
                    .lineLimit(1)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.white.opacity(0.03), in: RoundedRectangle(cornerRadius: 6))
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color.white.opacity(0.06), lineWidth: 0.8)
                )
            }

            if snapshot.musicTitle != nil {
                musicRow(snapshot, theme: theme)
            }

            actionButtons(snapshot, theme: theme, includesCompleteSet: true)
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 12)
        .background(
            LinearGradient(
                colors: [Color.black, Color(white: 0.05)],
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }

    private func healthRow(_ snapshot: SharedWorkoutSnapshot, theme: WidgetTheme) -> some View {
        HStack(spacing: 10) {
            compactMetric("pulse_label", icon: "heart.fill", theme: theme) {
                Text(snapshot.heartRate.map { localizedFormat("heart_rate_bpm_format", Int($0)) } ?? "--")
            }
            compactMetric("Kcal", icon: "flame.fill", theme: theme) {
                if let kcal = snapshot.activeEnergyKcal {
                    let isEstimated = snapshot.heartRate == nil
                    let prefix = isEstimated ? "~" : ""
                    Text("\(prefix)\(Int(kcal))")
                } else {
                    Text("--")
                }
            }
        }
    }

    @ViewBuilder
    private func musicRow(_ snapshot: SharedWorkoutSnapshot, theme: WidgetTheme) -> some View {
        HStack(spacing: 8) {
            Image(systemName: snapshot.isMusicPlaying == true ? "music.note" : "music.note.list")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(theme.tint)

            VStack(alignment: .leading, spacing: 0) {
                Text(verbatim: snapshot.musicTitle ?? "--")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(theme.foreground)
                    .lineLimit(1)
                if let artist = snapshot.musicArtist, !artist.isEmpty {
                    Text(verbatim: artist)
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(theme.secondaryForeground)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 4)

            HStack(spacing: 4) {
                Button(intent: MusicPreviousLiveActivityIntent()) {
                    Image(systemName: "backward.fill").font(.system(size: 11, weight: .bold))
                }
                .buttonStyle(.bordered)
                .buttonBorderShape(.circle)
                .tint(theme.tint)

                Button(intent: MusicToggleLiveActivityIntent()) {
                    Image(systemName: snapshot.isMusicPlaying == true ? "pause.fill" : "play.fill")
                        .font(.system(size: 11, weight: .bold))
                }
                .buttonStyle(.borderedProminent)
                .buttonBorderShape(.circle)
                .tint(theme.tint)

                Button(intent: MusicNextLiveActivityIntent()) {
                    Image(systemName: "forward.fill").font(.system(size: 11, weight: .bold))
                }
                .buttonStyle(.bordered)
                .buttonBorderShape(.circle)
                .tint(theme.tint)
            }
            .controlSize(.small)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(theme.badgeBackground, in: RoundedRectangle(cornerRadius: 10))
    }

    private func actionButtons(_ snapshot: SharedWorkoutSnapshot, theme: WidgetTheme, includesCompleteSet: Bool) -> some View {
        let pauseTitle: LocalizedStringKey = snapshot.isPaused ? "resume_label" : "pause_label"
        return HStack(spacing: 8) {
            Button(intent: ToggleWorkoutPauseLiveActivityIntent()) {
                HStack(spacing: 6) {
                    Image(systemName: snapshot.isPaused ? "play.fill" : "pause.fill")
                    Text(localizedKey(pauseTitle))
                }
                .font(.caption.weight(.bold))
                .foregroundStyle(theme.tint)
                .frame(height: 36)
                .frame(maxWidth: .infinity)
                .background(theme.tint.opacity(0.14), in: Capsule())
                .overlay(
                    Capsule()
                        .stroke(theme.tint.opacity(0.24), lineWidth: 0.8)
                )
            }
            .buttonStyle(.plain)

            if includesCompleteSet {
                Button(intent: CompleteSetLiveActivityIntent()) {
                    HStack(spacing: 6) {
                        Image(systemName: "checkmark.circle.fill")
                        Text(localizedKey("set_done"))
                    }
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Color.black)
                    .frame(height: 36)
                    .frame(maxWidth: .infinity)
                    .background(theme.tint, in: Capsule())
                }
                .buttonStyle(.plain)

                Button(intent: NextExerciseLiveActivityIntent()) {
                    Image(systemName: "forward.end.fill")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(theme.tint)
                        .frame(width: 36, height: 36)
                        .background(theme.tint.opacity(0.14), in: Circle())
                        .overlay(
                            Circle()
                                .stroke(theme.tint.opacity(0.24), lineWidth: 0.8)
                        )
                }
                .buttonStyle(.plain)
            }

            Button(intent: AddWaterLiveActivityIntent()) {
                Image(systemName: "drop.fill")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Color.blue)
                    .frame(width: 36, height: 36)
                    .background(Color.blue.opacity(0.14), in: Circle())
                    .overlay(
                        Circle()
                            .stroke(Color.blue.opacity(0.24), lineWidth: 0.8)
                    )
            }
            .buttonStyle(.plain)

            Button(intent: StopWorkoutLiveActivityIntent()) {
                Image(systemName: "stop.fill")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.red)
                    .frame(width: 36, height: 36)
                    .background(Color.red.opacity(0.14), in: Circle())
                    .overlay(
                        Circle()
                            .stroke(Color.red.opacity(0.24), lineWidth: 0.8)
                    )
            }
            .buttonStyle(.plain)
        }
    }

    private func islandExpandedBottom(_ snapshot: SharedWorkoutSnapshot, theme: WidgetTheme, isStale: Bool) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            // Header Row: Workout Title & Timer
            HStack(alignment: .center) {
                Text(snapshot.workoutTitle)
                    .font(.system(size: 16, weight: .black, design: .rounded))
                    .foregroundStyle(theme.foreground)
                    .lineLimit(1)
                Spacer()
                elapsedTimerText(snapshot)
                    .font(.system(size: 16, weight: .black, design: .rounded).monospacedDigit())
                    .foregroundStyle(theme.foreground)
            }

            // Stats Row
            HStack(spacing: 8) {
                if snapshot.isRouteWorkout {
                    islandCompactMetric(icon: "point.topleft.down.curvedto.point.bottomright.up", value: routeDistanceText(snapshot), theme: theme)
                    islandCompactMetric(icon: "speedometer", value: routePaceText(snapshot), theme: theme)
                } else {
                    islandCompactMetric(icon: "hourglass", value: snapshot.restEndDate == nil ? snapshot.remainingText : snapshot.restText, theme: theme)
                    islandCompactMetric(icon: "dumbbell.fill", value: "\(snapshot.completedSets)/\(max(snapshot.totalSets, 1))", theme: theme)
                }
            }

            // Controls Row
            HStack(spacing: 8) {
                Button(intent: ToggleWorkoutPauseLiveActivityIntent()) {
                    HStack(spacing: 4) {
                        Image(systemName: snapshot.isPaused ? "play.fill" : "pause.fill")
                        Text(snapshot.isPaused ? "Reanudar" : "Pausar")
                    }
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(theme.tint)
                    .frame(height: 28)
                    .frame(maxWidth: .infinity)
                    .background(theme.tint.opacity(0.14), in: Capsule())
                    .overlay(
                        Capsule()
                            .stroke(theme.tint.opacity(0.24), lineWidth: 0.8)
                    )
                }
                .buttonStyle(.plain)

                if !snapshot.isRouteWorkout {
                    Button(intent: CompleteSetLiveActivityIntent()) {
                        HStack(spacing: 4) {
                            Image(systemName: "checkmark.circle.fill")
                            Text("Serie")
                        }
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(Color.black)
                        .frame(height: 28)
                        .frame(maxWidth: .infinity)
                        .background(theme.tint, in: Capsule())
                    }
                    .buttonStyle(.plain)

                    Button(intent: NextExerciseLiveActivityIntent()) {
                        Image(systemName: "forward.end.fill")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(theme.tint)
                            .frame(width: 28, height: 28)
                            .background(theme.tint.opacity(0.14), in: Circle())
                            .overlay(
                                Circle()
                                    .stroke(theme.tint.opacity(0.24), lineWidth: 0.8)
                            )
                    }
                    .buttonStyle(.plain)
                }

                if snapshot.musicTitle != nil {
                    Button(intent: MusicToggleLiveActivityIntent()) {
                        Image(systemName: snapshot.isMusicPlaying == true ? "pause.fill" : "play.fill")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(theme.tint)
                            .frame(width: 28, height: 28)
                            .background(theme.tint.opacity(0.14), in: Circle())
                            .overlay(
                                Circle()
                                    .stroke(theme.tint.opacity(0.24), lineWidth: 0.8)
                            )
                    }
                    .buttonStyle(.plain)
                }

                Button(intent: StopWorkoutLiveActivityIntent()) {
                    HStack(spacing: 4) {
                        Image(systemName: "stop.fill")
                        Text("Fin")
                    }
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.red)
                    .frame(height: 28)
                    .frame(maxWidth: .infinity)
                    .background(Color.red.opacity(0.14), in: Capsule())
                    .overlay(
                        Capsule()
                            .stroke(Color.red.opacity(0.24), lineWidth: 0.8)
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 12)
        .padding(.top, 0)
        .padding(.bottom, 2)
        .frame(maxHeight: 96, alignment: .top)
    }

    private func statusBadge(_ snapshot: SharedWorkoutSnapshot, theme: WidgetTheme, isStale: Bool, showIcon: Bool = false) -> some View {
        let title: LocalizedStringKey = isStale ? "ACTUALIZANDO" : statusTitle(snapshot)
        let icon = isStale ? "arrow.triangle.2.circlepath" : compactLeadingSystemImage(snapshot)

        return Group {
            if showIcon {
                Label(localizedKey(title), systemImage: icon)
            } else {
                Text(localizedKey(title))
            }
        }
        .font(.system(size: 8, weight: .bold))
        .foregroundStyle(theme.tint)
        .lineLimit(1)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(theme.tint.opacity(0.12), in: Capsule())
        .overlay(
            Capsule()
                .stroke(theme.tint.opacity(0.24), lineWidth: 0.8)
        )
    }

    private func compactLeadingView(_ snapshot: SharedWorkoutSnapshot, theme: WidgetTheme) -> some View {
        let systemImage = compactLeadingSystemImage(snapshot)
        return Image(systemName: systemImage)
            .foregroundStyle(theme.tint)
            .contentTransition(.symbolEffect(.replace.downUp))
            .symbolEffect(
                .wiggle.forward.byLayer,
                options: .nonRepeating,
                value: animationTrigger(snapshot, event: "compact")
            )
            .symbolEffectsRemoved(!animationsEnabled)
            .transition(.symbolEffect(.appear.byLayer))
    }

    private func compactMetric<Content: View>(
        _ title: LocalizedStringKey,
        icon: String,
        theme: WidgetTheme,
        @ViewBuilder value: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Label {
                Text(localizedKey(title))
            } icon: {
                if icon == "heart.fill" {
                    Image(systemName: icon)
                        .symbolEffect(.pulse, options: .repeating)
                } else {
                    Image(systemName: icon)
                }
            }
            .font(.system(size: 8, weight: .bold))
            .foregroundStyle(theme.secondaryForeground)
            .lineLimit(1)
            .minimumScaleFactor(0.8)
            value()
                .font(.system(size: 13, weight: .black, design: .rounded).monospacedDigit())
                .foregroundStyle(theme.foreground)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 9)
        .padding(.vertical, 6)
        .background(Color.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(theme.tint.opacity(0.12), lineWidth: 0.8)
        )
    }

    private func islandMetric<Content: View>(
        _ title: LocalizedStringKey,
        icon: String,
        tint: Color,
        @ViewBuilder value: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Label(localizedKey(title), systemImage: icon)
                .font(.system(size: 9, weight: .black))
                .foregroundStyle(tint)
                .lineLimit(1)
            value()
                .font(.caption.weight(.bold).monospacedDigit())
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
    }

    private func islandCompactMetric(icon: String, value: String, theme: WidgetTheme) -> some View {
        Label(value, systemImage: icon)
            .font(.system(size: 11, weight: .bold, design: .rounded))
            .foregroundStyle(theme.foreground)
            .lineLimit(1)
            .minimumScaleFactor(0.75)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(Color.white.opacity(0.04), in: Capsule())
            .overlay(
                Capsule()
                    .stroke(theme.tint.opacity(0.12), lineWidth: 0.8)
            )
    }

    @ViewBuilder
    private func elapsedTimerText(_ snapshot: SharedWorkoutSnapshot) -> some View {
        if snapshot.isPaused {
            Text(snapshot.elapsedText)
        } else {
            Text(snapshot.elapsedStartDate, style: .timer)
        }
    }

    private func compactLeadingSystemImage(_ snapshot: SharedWorkoutSnapshot) -> String {
        let name = (snapshot.exerciseName ?? snapshot.workoutTitle).lowercased()
        if snapshot.isRouteWorkout {
            if snapshot.isPaused { return "pause.fill" }
            return snapshot.isOutdoorRoute == false ? "figure.run.treadmill" : (name.contains("run") || name.contains("carrera") ? "figure.run" : "figure.walk")
        }
        if snapshot.isPaused { return "pause.fill" }
        if snapshot.restEndDate != nil { return "hourglass" }
        return name.contains("core") || name.contains("abdom") || name.contains("abs") || name.contains("plank") ? "figure.core.training" : "figure.strengthtraining.traditional"
    }

    @ViewBuilder
    private func compactTrailingView(_ snapshot: SharedWorkoutSnapshot) -> some View {
        if snapshot.isRouteWorkout {
            Text(routeDistanceText(snapshot))
        } else {
            if let restEndDate = snapshot.restEndDate {
                Text(restEndDate, style: .timer)
            } else {
                Text("\(snapshot.completedSets)/\(max(snapshot.totalSets, 1))")
            }
        }
    }

    private func statusTitle(_ snapshot: SharedWorkoutSnapshot) -> LocalizedStringKey {
        if snapshot.isRouteWorkout {
            if snapshot.isPaused { return "PAUSA" }
            return snapshot.isOutdoorRoute == false ? "CINTA" : "RUTA"
        }
        if snapshot.restEndDate != nil {
            return "DESCANSO"
        }
        return snapshot.isPaused ? "PAUSA" : "ACTIVO"
    }

    private func routeDistanceText(_ snapshot: SharedWorkoutSnapshot) -> String {
        snapshot.routeDistanceText
    }

    private func routePaceText(_ snapshot: SharedWorkoutSnapshot) -> String {
        snapshot.routePaceText
    }

    private func routeSubtitle(_ snapshot: SharedWorkoutSnapshot) -> String {
        [routeDistanceText(snapshot), routePaceText(snapshot)]
            .filter { $0 != "--" }
            .joined(separator: " · ")
    }

    private func animatedActivityIcon(_ snapshot: SharedWorkoutSnapshot) -> some View {
        let systemImage: String
        let name = (snapshot.exerciseName ?? snapshot.workoutTitle).lowercased()
        
        if snapshot.isRouteWorkout {
            if snapshot.isOutdoorRoute == false {
                systemImage = "figure.run.treadmill"
            } else if name.contains("run") || name.contains("carrera") || name.contains("jog") {
                systemImage = "figure.run"
            } else if name.contains("hike") || name.contains("senderismo") {
                systemImage = "figure.hiking"
            } else {
                systemImage = "figure.walk"
            }
        } else {
            if name.contains("core") || name.contains("abdom") || name.contains("abs") || name.contains("plank") {
                systemImage = "figure.core.training"
            } else if name.contains("stretch") || name.contains("estiramiento") || name.contains("flex") {
                systemImage = "figure.flexibility"
            } else if name.contains("yoga") {
                systemImage = "figure.yoga"
            } else if name.contains("pilates") {
                systemImage = "figure.pilates"
            } else if name.contains("jump") || name.contains("salto") || name.contains("rope") {
                systemImage = "figure.rope.skipping"
            } else if name.contains("cycle") || name.contains("ciclismo") || name.contains("bici") {
                systemImage = name.contains("outdoor") ? "figure.outdoor.cycle" : "figure.indoor.cycle"
            } else if name.contains("swim") || name.contains("natacion") {
                systemImage = "figure.pool.swim"
            } else if name.contains("box") || name.contains("kickbox") || name.contains("hit") || name.contains("hiit") {
                systemImage = "figure.high.intensity.intervaltraining"
            } else {
                systemImage = "figure.strengthtraining.traditional"
            }
        }
        
        return Image(systemName: systemImage)
            .contentTransition(.symbolEffect(.replace.downUp))
            .symbolEffect(
                .wiggle.forward.byLayer,
                options: .nonRepeating,
                value: animationTrigger(snapshot, event: "activity")
            )
            .symbolEffectsRemoved(!animationsEnabled || snapshot.isPaused)
            .transition(.symbolEffect(.appear.byLayer))
    }

    private func animationTrigger(_ snapshot: SharedWorkoutSnapshot, event: String) -> String {
        "\(event)|\(snapshot.workoutAnimationTrigger)|illuminated:\(animationsEnabled)"
    }
}

struct RepsProgressStyle: ProgressViewStyle {
    var tintColor: Color = Color(red: 0.69, green: 0.99, blue: 0.16)  // neon green #B0FC29
    var isDarkBackground: Bool = true

    func makeBody(configuration: Configuration) -> some View {
        let fraction = configuration.fractionCompleted ?? 0.0
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(isDarkBackground ? Color.white.opacity(0.2) : Color.primary.opacity(0.12))
                    .frame(height: 6)
                Capsule()
                    .fill(tintColor)
                    .frame(width: geo.size.width * CGFloat(fraction), height: 6)
            }
        }
        .frame(height: 6)
    }
}
