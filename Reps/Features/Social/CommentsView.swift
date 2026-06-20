import SwiftUI

struct CommentsView: View {
    let post: WorkoutPost
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var comments: [WorkoutComment] = []
    @State private var isLoading = true
    @State private var draftText = ""
    @State private var isSending = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ZStack {
                    if isLoading {
                        ProgressView().tint(PulseTheme.primary)
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
                            LazyVStack(spacing: 0) {
                                ForEach(Array(comments.enumerated()), id: \.element.id) { idx, comment in
                                    commentRow(comment)
                                    if idx < comments.count - 1 {
                                        Divider().padding(.leading, 54)
                                    }
                                }
                            }
                            .padding(.vertical, 8)
                        }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                Divider()
                inputBar
            }
            .screenBackground()
            .navigationTitle(Text(LocalizedStringKey("comments")))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(localizedString("close")) { dismiss() }
                }
            }
        }
        .task { await loadComments() }
    }

    // MARK: - Row

    private func commentRow(_ comment: WorkoutComment) -> some View {
        HStack(alignment: .top, spacing: 10) {
            ZStack {
                Circle()
                    .fill(PulseTheme.primary.opacity(0.10))
                    .frame(width: 36, height: 36)
                Text(String(comment.ownerUsername.prefix(1)).uppercased())
                    .font(.system(size: 14, weight: .black, design: .rounded))
                    .foregroundStyle(PulseTheme.primary)
            }
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text("@\(comment.ownerUsername)")
                        .font(.caption.weight(.bold))
                    Text(comment.createdAt, style: .relative)
                        .font(.caption2)
                        .foregroundStyle(PulseTheme.tertiaryText)
                }
                Text(comment.text)
                    .font(.subheadline)
            }
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    // MARK: - Input

    private var inputBar: some View {
        HStack(spacing: 10) {
            TextField(LocalizedStringKey("comments_placeholder"), text: $draftText, axis: .vertical)
                .textFieldStyle(.plain)
                .font(.subheadline)
                .lineLimit(1...4)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(PulseTheme.grouped)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

            Button {
                let text = draftText
                Task { await sendComment(text) }
            } label: {
                if isSending {
                    ProgressView().tint(PulseTheme.primary).scaleEffect(0.8)
                        .frame(width: 30)
                } else {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 30))
                        .foregroundStyle(
                            draftText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                                ? PulseTheme.secondaryText
                                : PulseTheme.primary
                        )
                }
            }
            .buttonStyle(.plain)
            .disabled(draftText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSending)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial)
    }

    // MARK: - Async actions

    private func loadComments() async {
        isLoading = true
        comments = (try? await SocialService.shared.fetchComments(postID: post.id)) ?? []
        isLoading = false
    }

    private func sendComment(_ text: String) async {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let uname = store.userProfile.socialUsername else { return }
        isSending = true
        draftText = ""
        let dname = store.userProfile.displayName ?? uname
        if let comment = try? await SocialService.shared.addComment(
            postID: post.id,
            text: trimmed,
            ownerUsername: uname,
            ownerDisplayName: dname
        ) {
            comments.append(comment)
        }
        isSending = false
    }
}
