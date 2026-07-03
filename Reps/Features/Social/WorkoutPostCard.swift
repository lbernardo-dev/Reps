import SwiftUI

// MARK: - WorkoutPostCard
//
// Instagram-style post card: when the post carries photos, the media leads
// (full width, right under the header) and the workout stats/caption follow
// underneath — the reverse of a stats-first layout. Auto-generated workout
// posts without photos keep the stat-forward layout since there's no media
// to lead with. Shared between the feed list and the profile detail grid's
// single-post sheet.

struct WorkoutPostCard: View {
    @Environment(AppStore.self) private var store

    let post: WorkoutPost
    let isLiked: Bool
    let isLiking: Bool
    let commentSummary: CommentSummary?
    var onProfileTap: () -> Void
    var onLike: () -> Void
    var onComment: () -> Void

    @State private var showLikeBurst = false

    private var isRecent: Bool { post.createdAt.timeIntervalSinceNow > -7200 }

    var body: some View {
        PulseCard(contentPadding: 0) {
            VStack(alignment: .leading, spacing: 0) {
                header

                if !post.photoDataList.isEmpty {
                    photoSection
                }

                if !post.isCustomPost {
                    Text(post.workoutTitle)
                        .font(.headline.weight(.bold))
                        .padding(.horizontal, 14)
                        .padding(.top, post.photoDataList.isEmpty ? 14 : 10)

                    statChipsRow
                }

                if let cap = post.caption, !cap.isEmpty, cap != post.workoutTitle {
                    captionText(cap)
                }

                if !post.exerciseNames.isEmpty {
                    exerciseChipsRow
                }

                Divider()
                actionBar
                commentsPreview
            }
        }
    }

    // MARK: Header

    private var header: some View {
        HStack(spacing: 10) {
            Button(action: onProfileTap) {
                HStack(spacing: 10) {
                    ZStack {
                        Circle().fill(PulseTheme.accent.opacity(0.10)).frame(width: 42, height: 42)
                        Text(String(post.ownerUsername.prefix(1)).uppercased())
                            .font(.system(size: 18, weight: .black, design: .rounded))
                            .foregroundStyle(PulseTheme.accent)
                    }
                    VStack(alignment: .leading, spacing: 1) {
                        Text("@\(post.ownerUsername)")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.primary)
                        Text(post.createdAt, style: .relative)
                            .font(.caption)
                            .foregroundStyle(PulseTheme.secondaryText)
                    }
                }
            }
            .buttonStyle(.plain)

            Spacer()

            if isRecent {
                Text("LIVE")
                    .font(.system(size: 9, weight: .black, design: .rounded))
                    .tracking(1)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(.red, in: Capsule())
            }
        }
        .padding(.horizontal, 14)
        .padding(.top, 14)
        .padding(.bottom, 10)
    }

    // MARK: Photo (leads the card, double-tap to like)

    private var photoSection: some View {
        ZStack {
            feedPhotoGrid(post.photoDataList)
        }
        .contentShape(Rectangle())
        .onTapGesture(count: 2) {
            if !isLiked { onLike() }
            HapticService.impact(.light)
            withAnimation(.spring(response: 0.28, dampingFraction: 0.55)) { showLikeBurst = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.55) {
                withAnimation(.easeOut(duration: 0.2)) { showLikeBurst = false }
            }
        }
        .overlay {
            Image(systemName: "heart.fill")
                .font(.system(size: 84))
                .foregroundStyle(.white)
                .shadow(color: .black.opacity(0.25), radius: 10)
                .scaleEffect(showLikeBurst ? 1 : 0.6)
                .opacity(showLikeBurst ? 1 : 0)
        }
    }

    // MARK: Stat chips / exercise chips

    private var statChipsRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                if post.durationSeconds > 0 {
                    feedStatChip(icon: "clock.fill", value: durationLabel(post.durationSeconds), color: PulseTheme.accent)
                }
                if post.volumeKg > 0 {
                    feedStatChip(icon: "scalemass.fill", value: volumeLabel(post.volumeKg), color: PulseTheme.ringStand)
                }
                if !post.exerciseNames.isEmpty {
                    feedStatChip(icon: "dumbbell.fill", value: "\(post.exerciseNames.count) ex", color: PulseTheme.accent)
                }
            }
            .padding(.horizontal, 14)
        }
        .padding(.vertical, 8)
    }

    private func captionText(_ cap: String) -> some View {
        Text(cap)
            .font(.subheadline)
            .foregroundStyle(.primary.opacity(0.9))
            .padding(.horizontal, 14)
            .padding(.top, post.isCustomPost && post.photoDataList.isEmpty ? 14 : 0)
            .padding(.bottom, 6)
    }

    private var exerciseChipsRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(post.exerciseNames.prefix(5), id: \.self) { name in
                    Text(name)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(PulseTheme.accent)
                        .padding(.horizontal, 8).padding(.vertical, 4)
                        .background(PulseTheme.accent.opacity(0.08))
                        .clipShape(Capsule())
                }
                if post.exerciseNames.count > 5 {
                    Text("+\(post.exerciseNames.count - 5)")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(PulseTheme.secondaryText)
                        .padding(.horizontal, 8).padding(.vertical, 4)
                        .background(PulseTheme.grouped)
                        .clipShape(Capsule())
                }
            }
            .padding(.horizontal, 14)
        }
        .padding(.bottom, 6)
    }

    // MARK: Action bar

    private var actionBar: some View {
        HStack(spacing: 0) {
            Button(action: onLike) {
                HStack(spacing: 6) {
                    Image(systemName: isLiked ? "heart.fill" : "heart")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(isLiked ? PulseTheme.destructive : PulseTheme.secondaryText)
                    if post.likeCount > 0 {
                        Text("\(post.likeCount)")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(PulseTheme.secondaryText)
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 44)
            }
            .buttonStyle(.plain)
            .opacity(isLiking ? 0.5 : 1)
            .disabled(isLiking)

            Divider().frame(height: 20)

            Button(action: onComment) {
                HStack(spacing: 6) {
                    Image(systemName: "bubble.left")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(PulseTheme.secondaryText)
                    if let commentSummary, commentSummary.count > 0 {
                        Text("\(commentSummary.count)")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(PulseTheme.secondaryText)
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 44)
            }
            .buttonStyle(.plain)
        }
    }

    @ViewBuilder
    private var commentsPreview: some View {
        if let commentSummary, commentSummary.count > 0 {
            VStack(alignment: .leading, spacing: 3) {
                if commentSummary.count > 1 {
                    Text(localizedFormat("comments_view_all", commentSummary.count))
                        .font(.subheadline)
                        .foregroundStyle(PulseTheme.secondaryText)
                }
                if let last = commentSummary.lastComment {
                    Text("@\(last.ownerUsername) \(last.text)")
                        .font(.subheadline)
                        .foregroundStyle(.primary)
                        .lineLimit(2)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
            .onTapGesture(perform: onComment)
            .padding(.horizontal, 14)
            .padding(.top, 2)
            .padding(.bottom, 12)
        }
    }

    // MARK: Photo layout

    private func feedPhotoGrid(_ photoList: [Data]) -> some View {
        let count = photoList.count
        let images = photoList.compactMap { UIImage(data: $0) }
        return Group {
            if count == 1, let img = images.first {
                Image(uiImage: img)
                    .resizable().scaledToFill()
                    .frame(maxWidth: .infinity)
                    .frame(height: 320)
                    .clipped()
            } else {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 2), count: min(count, 2)), spacing: 2) {
                    ForEach(Array(images.enumerated()), id: \.offset) { _, img in
                        Image(uiImage: img)
                            .resizable().scaledToFill()
                            .frame(maxWidth: .infinity)
                            .frame(height: count == 2 ? 200 : 140)
                            .clipped()
                    }
                }
            }
        }
    }

    private func feedStatChip(icon: String, value: String, color: Color) -> some View {
        HStack(spacing: 5) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .bold))
            Text(value)
                .font(.system(size: 12, weight: .bold, design: .rounded))
        }
        .foregroundStyle(color)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(color.opacity(0.10))
        .clipShape(Capsule())
    }

    private func durationLabel(_ seconds: Int) -> String {
        let m = seconds / 60
        return m > 0 ? "\(m) min" : "—"
    }

    private func volumeLabel(_ kg: Double) -> String {
        let isImperial = store.userProfile.units == .imperial
        let val = isImperial ? kg * 2.20462 : kg
        let suffix = isImperial ? " lb" : " kg"
        return String(format: "%.0f\(suffix)", val)
    }
}
