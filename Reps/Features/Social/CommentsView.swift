import SwiftUI

struct CommentsView: View {
    let post: WorkoutPost
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var comments: [WorkoutComment] = []
    @State private var isLoading = true
    @State private var draftText = ""
    @State private var isSending = false
    @FocusState private var inputFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()

            ZStack {
                if isLoading {
                    ProgressView().tint(PulseTheme.accent)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if comments.isEmpty {
                    PulseEmptyState(
                        title: "comments_empty_title",
                        message: "comments_empty_message",
                        systemImage: "bubble.left"
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 0) {
                            ForEach(comments) { comment in
                                commentRow(comment)
                            }
                        }
                        .padding(.vertical, 6)
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            Divider()
            if store.userProfile.socialCapabilitiesAllowed {
                inputBar
            }
        }
        .screenBackground()
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .task { await loadComments() }
    }

    // MARK: - Header

    private var header: some View {
        Text(LocalizedStringKey("comments"))
            .font(.headline)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .overlay(alignment: .trailing) {
                Button { dismiss() } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 26))
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(PulseTheme.tertiaryText)
                }
                .buttonStyle(.plain)
                .padding(.trailing, 14)
            }
    }

    // MARK: - Row

    private func commentRow(_ comment: WorkoutComment) -> some View {
        HStack(alignment: .top, spacing: 10) {
            avatar(data: comment.ownerAvatarData, username: comment.ownerUsername, size: 36)
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text("@\(comment.ownerUsername)")
                        .font(.caption.weight(.bold))
                    if comment.isPending {
                        Label(LocalizedStringKey("comment_sending"), systemImage: "clock")
                            .font(.caption2)
                            .labelStyle(.titleAndIcon)
                            .foregroundStyle(PulseTheme.tertiaryText)
                    } else {
                        Text(comment.createdAt, style: .relative)
                            .font(.caption2)
                            .foregroundStyle(PulseTheme.tertiaryText)
                    }
                }
                Text(comment.text)
                    .font(.subheadline)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)

            Menu {
                Button {
                    Task {
                        guard let reporter = store.userProfile.socialUsername else { return }
                        try? await SocialService.shared.reportContent(
                            contentID: comment.id,
                            contentType: "comment",
                            ownerUsername: comment.ownerUsername,
                            reason: "user_report",
                            reporterUsername: reporter
                        )
                    }
                } label: {
                    Label(localizedString("social_report_comment"), systemImage: "flag")
                }
                Button(role: .destructive) {
                    Task { _ = await store.blockSocialUser(comment.ownerUsername) }
                } label: {
                    Label(localizedString("social_block_user"), systemImage: "person.crop.circle.badge.xmark")
                }
            } label: {
                Image(systemName: "ellipsis.circle")
                    .font(.subheadline)
                    .foregroundStyle(PulseTheme.tertiaryText)
                    .frame(width: 32, height: 32)
            }
            .accessibilityLabel(localizedString("social_moderation_actions"))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    // MARK: - Input

    private var inputBar: some View {
        HStack(spacing: 10) {
            avatar(data: store.userProfile.avatarImageData,
                   username: store.userProfile.socialUsername ?? "?",
                   size: 32)

            TextField(LocalizedStringKey("comments_placeholder"), text: $draftText, axis: .vertical)
                .textFieldStyle(.plain)
                .font(.subheadline)
                .lineLimit(1...4)
                .focused($inputFocused)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(PulseTheme.grouped)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))

            Button {
                let text = draftText
                Task { await sendComment(text) }
            } label: {
                if isSending {
                    ProgressView().tint(PulseTheme.accent).scaleEffect(0.8)
                        .frame(width: 30)
                } else {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 30))
                        .foregroundStyle(canSend ? PulseTheme.accent : PulseTheme.secondaryText)
                }
            }
            .buttonStyle(.plain)
            .disabled(!canSend || isSending)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial)
    }

    private var canSend: Bool {
        !draftText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    // MARK: - Avatar

    private func avatar(data: Data?, username: String, size: CGFloat) -> some View {
        ZStack {
            if let d = data, let img = UIImage(data: d) {
                Image(uiImage: img)
                    .resizable().scaledToFill()
                    .frame(width: size, height: size)
                    .clipShape(Circle())
            } else {
                Circle()
                    .fill(PulseTheme.accent.opacity(0.10))
                    .frame(width: size, height: size)
                Text(String(username.prefix(1)).uppercased())
                    .font(.system(size: size * 0.4, weight: .black, design: .rounded))
                    .foregroundStyle(PulseTheme.accent)
            }
        }
    }

    // MARK: - Async actions

    private func loadComments() async {
        guard store.userProfile.socialCapabilitiesAllowed else {
            comments = []
            isLoading = false
            return
        }
        // Instant first paint from the local cache (works fully offline)…
        let cached = await SocialService.shared.cachedComments(postID: post.id)
        comments = cached
        isLoading = cached.isEmpty
        // …then reconcile with CloudKit when online (no-op otherwise).
        comments = await SocialService.shared.fetchComments(postID: post.id)
        isLoading = false
    }

    private func sendComment(_ text: String) async {
        guard store.userProfile.socialCapabilitiesAllowed else { return }
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let uname = store.userProfile.socialUsername else { return }
        isSending = true
        draftText = ""
        let dname = store.userProfile.displayName ?? uname
        // Optimistic + deferred: returns immediately, syncs (or queues) in the
        // background. Never throws.
        _ = await SocialService.shared.addComment(
            postID: post.id,
            postOwnerUsername: post.ownerUsername,
            text: trimmed,
            ownerUsername: uname,
            ownerDisplayName: dname,
            ownerAvatarData: store.userProfile.avatarImageData
        )
        comments = await SocialService.shared.cachedComments(postID: post.id)
        await store.refreshCommentSummary(postID: post.id)
        HapticService.selection()
        isSending = false
    }
}
