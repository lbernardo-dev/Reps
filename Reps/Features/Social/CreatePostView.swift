import SwiftUI
import PhotosUI

struct CreatePostView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    /// Called when a post is successfully published. Useful for callers that
    /// pre-fill the composer (e.g. the post-workout summary) and want to update
    /// their own UI state once the post lands in the feed.
    var onPosted: (() -> Void)? = nil

    @State private var caption: String
    @State private var selectedItems: [PhotosPickerItem] = []
    @State private var selectedImages: [UIImage]
    @State private var isPosting = false
    @State private var errorMessage: String?

    init(
        prefilledImage: UIImage? = nil,
        prefilledCaption: String? = nil,
        onPosted: (() -> Void)? = nil
    ) {
        self.onPosted = onPosted
        _caption = State(initialValue: prefilledCaption ?? "")
        _selectedImages = State(initialValue: prefilledImage.map { [$0] } ?? [])
    }

    private var canPost: Bool {
        !isPosting && (!caption.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !selectedImages.isEmpty)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Avatar + caption input
                    HStack(alignment: .top, spacing: 12) {
                        authorAvatar
                        VStack(alignment: .leading, spacing: 8) {
                            Text("@\(store.userProfile.socialUsername ?? "")")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(PulseTheme.accent)
                            TextField(localizedString("post_caption_placeholder"), text: $caption, axis: .vertical)
                                .font(.body)
                                .lineLimit(4...10)
                        }
                    }

                    // Photo strip
                    if !selectedImages.isEmpty {
                        photoStrip
                    }

                    // Add photo button
                    if selectedImages.count < 3 {
                        PhotosPicker(
                            selection: $selectedItems,
                            maxSelectionCount: 3 - selectedImages.count,
                            matching: .images,
                            photoLibrary: .shared()
                        ) {
                            Label(localizedString("post_add_photo"), systemImage: "photo.badge.plus")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(PulseTheme.accent)
                                .padding(.horizontal, 14).padding(.vertical, 10)
                                .background(PulseTheme.accent.opacity(0.08))
                                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        }
                        .onChange(of: selectedItems) { _, newItems in
                            loadImages(from: newItems)
                        }
                    }

                    Spacer(minLength: 40)
                }
                .padding(.horizontal, PulseTheme.screenHorizontalPadding)
                .padding(.top, 16)
            }
            .screenBackground()
            .navigationBarTitleDisplayMode(.inline)
            .alert(localizedString("ok"), isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )) {
                Button(localizedString("ok")) { errorMessage = nil }
            } message: {
                Text(errorMessage ?? "")
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(localizedString("cancel")) { dismiss() }
                        .foregroundStyle(PulseTheme.secondaryText)
                }
                ToolbarItem(placement: .principal) {
                    Text(localizedString("post_new"))
                        .font(.headline)
                }
                ToolbarItem(placement: .confirmationAction) {
                    if isPosting {
                        ProgressView().tint(PulseTheme.accent)
                    } else {
                        Button(localizedString("post_share")) {
                            publish()
                        }
                        .font(.headline)
                        .foregroundStyle(canPost ? PulseTheme.accent : PulseTheme.secondaryText)
                        .disabled(!canPost)
                    }
                }
            }
        }
    }

    // MARK: - Subviews

    private var authorAvatar: some View {
        ZStack {
            Circle()
                .fill(PulseTheme.accent.opacity(0.12))
                .frame(width: 44, height: 44)
            if let data = store.userProfile.avatarImageData,
               let img = UIImage(data: data) {
                Image(uiImage: img)
                    .resizable().scaledToFill()
                    .frame(width: 44, height: 44)
                    .clipShape(Circle())
            } else {
                let uname = store.userProfile.socialUsername ?? "?"
                Text(String(uname.prefix(1)).uppercased())
                    .font(.system(size: 18, weight: .black, design: .rounded))
                    .foregroundStyle(PulseTheme.accent)
            }
        }
    }

    private var photoStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(Array(selectedImages.enumerated()), id: \.offset) { idx, img in
                    ZStack(alignment: .topTrailing) {
                        Image(uiImage: img)
                            .resizable().scaledToFill()
                            .frame(width: 100, height: 100)
                            .clipped()
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

                        Button {
                            selectedImages.remove(at: idx)
                            if idx < selectedItems.count {
                                selectedItems.remove(at: idx)
                            }
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 20))
                                .foregroundStyle(.white)
                                .shadow(radius: 2)
                        }
                        .buttonStyle(.plain)
                        .padding(4)
                    }
                }
            }
        }
    }

    // MARK: - Logic

    private func loadImages(from items: [PhotosPickerItem]) {
        Task {
            var loaded: [UIImage] = []
            for item in items {
                if let data = try? await item.loadTransferable(type: Data.self),
                   let img = UIImage(data: data) {
                    loaded.append(img)
                }
            }
            await MainActor.run {
                selectedImages.append(contentsOf: loaded)
                selectedItems = []
            }
        }
    }

    private func publish() {
        guard let uname = store.userProfile.socialUsername else { return }
        let dname = store.userProfile.displayName ?? uname
        let text = caption.trimmingCharacters(in: .whitespacesAndNewlines)
        let photos = selectedImages.compactMap { $0.jpegData(compressionQuality: 0.7) }
        isPosting = true
        Task {
            do {
                if let post = try await SocialService.shared.publishCustomPost(
                    username: uname,
                    displayName: dname,
                    caption: text.isEmpty ? localizedString("post_shared_a_moment") : text,
                    photoDataList: photos
                ) {
                    await MainActor.run {
                        store.feedPosts.insert(post, at: 0)
                        isPosting = false
                        onPosted?()
                        dismiss()
                    }
                } else {
                    await MainActor.run {
                        isPosting = false
                        errorMessage = localizedString("post_publish_error")
                    }
                }
            } catch {
                await MainActor.run {
                    isPosting = false
                    errorMessage = error.localizedDescription
                }
            }
        }
    }
}
