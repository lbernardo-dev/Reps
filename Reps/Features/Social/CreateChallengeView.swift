import SwiftUI

struct CreateChallengeView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    @State private var title = ""
    @State private var description = ""
    @State private var metric: SocialChallenge.Metric = .volumeKg
    @State private var startDate = Date.now
    @State private var endDate = Calendar.current.date(byAdding: .day, value: 7, to: .now) ?? .now
    @State private var isCreating = false
    @State private var error: String?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField(LocalizedStringKey("challenge_title_placeholder"), text: $title)
                    TextField(LocalizedStringKey("challenge_description_placeholder"), text: $description, axis: .vertical)
                        .lineLimit(2...5)
                }

                Section(header: Text("challenge_metric")) {
                    Picker("challenge_metric", selection: $metric) {
                        ForEach(SocialChallenge.Metric.allCases) { m in
                            Text(LocalizedStringKey("challenge_metric_\(m.rawValue)")).tag(m)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                Section(header: Text("challenge_duration")) {
                    DatePicker(LocalizedStringKey("challenge_start"), selection: $startDate, displayedComponents: .date)
                    DatePicker(LocalizedStringKey("challenge_end"), selection: $endDate, in: startDate..., displayedComponents: .date)
                }

                if let error {
                    Section {
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle(Text("challenge_create"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("challenge_publish") {
                        Task { await createChallenge() }
                    }
                    .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty || isCreating)
                    .overlay {
                        if isCreating { ProgressView().scaleEffect(0.8) }
                    }
                }
            }
        }
    }

    private func createChallenge() async {
        guard let uname = store.userProfile.socialUsername else { return }
        let dname = store.userProfile.displayName ?? uname
        isCreating = true
        error = nil
        do {
            let ch = try await SocialService.shared.createChallenge(
                title: title.trimmingCharacters(in: .whitespaces),
                description: description.trimmingCharacters(in: .whitespaces),
                metric: metric,
                startDate: startDate,
                endDate: endDate,
                creatorUsername: uname,
                creatorDisplayName: dname
            )
            // Auto-join the creator.
            try await SocialService.shared.joinChallenge(ch.id, username: uname, displayName: dname)
            await store.loadChallenges()
            dismiss()
        } catch {
            self.error = error.localizedDescription
        }
        isCreating = false
    }
}
