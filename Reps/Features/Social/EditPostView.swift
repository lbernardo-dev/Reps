import SwiftUI

/// Text-only editor shared by post owners and the moderation team. Workout
/// metrics and attached photos remain immutable so an edit cannot falsify a
/// completed workout.
struct EditPostView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    let post: WorkoutPost
    var onSaved: (WorkoutPost) -> Void

    @State private var title: String
    @State private var caption: String
    @State private var isSaving = false
    @State private var errorMessage: String?

    init(post: WorkoutPost, onSaved: @escaping (WorkoutPost) -> Void) {
        self.post = post
        self.onSaved = onSaved
        _title = State(initialValue: post.workoutTitle)
        _caption = State(initialValue: post.caption ?? "")
    }

    private var canSave: Bool {
        !isSaving && !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Post") {
                    TextField("Title", text: $title)
                    TextField("Caption", text: $caption, axis: .vertical)
                        .lineLimit(3...8)
                }
            }
            .navigationTitle("Edit post")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(localizedString("cancel")) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(!canSave)
                }
            }
            .alert(localizedString("ok"), isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )) {
                Button(localizedString("ok")) { errorMessage = nil }
            } message: {
                Text(errorMessage ?? "")
            }
        }
    }

    private func save() {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedCaption = caption.trimmingCharacters(in: .whitespacesAndNewlines)
        isSaving = true
        Task {
            do {
                let updated = try await SocialService.shared.updatePost(
                    post,
                    title: trimmedTitle,
                    caption: trimmedCaption.isEmpty ? nil : trimmedCaption
                )
                await MainActor.run {
                    onSaved(updated)
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    isSaving = false
                    errorMessage = error.localizedDescription
                }
            }
        }
    }
}
