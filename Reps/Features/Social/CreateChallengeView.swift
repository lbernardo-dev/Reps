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

    private var lang: String { store.userProfile.preferredLanguage }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField(localizedString("challenge_title_placeholder"), text: $title)
                    TextField(localizedString("challenge_description_placeholder"), text: $description, axis: .vertical)
                        .lineLimit(2...5)
                }

                Section(header: Text(localizedString("challenge_metric"))) {
                    Picker(localizedString("challenge_metric"), selection: $metric) {
                        ForEach(SocialChallenge.Metric.allCases) { m in
                            Text(localizedString("challenge_metric_\(m.rawValue)")).tag(m)
                        }
                    }
                    .pickerStyle(.inline)
                    .labelsHidden()
                }

                Section(header: Text(localizedString("challenge_duration"))) {
                    DatePicker(localizedString("challenge_start"), selection: $startDate, displayedComponents: .date)
                    DatePicker(localizedString("challenge_end"), selection: $endDate, in: startDate..., displayedComponents: .date)
                }

                if let error {
                    Section {
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle(Text(localizedString("challenge_create")))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(localizedString("cancel")) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(localizedString("challenge_publish")) {
                        Task { await createChallenge() }
                    }
                    .disabled(!store.userProfile.socialCapabilitiesAllowed || title.trimmingCharacters(in: .whitespaces).isEmpty || isCreating)
                    .overlay {
                        if isCreating { ProgressView().scaleEffect(0.8) }
                    }
                }
            }
        }
    }

    private func createChallenge() async {
        guard store.userProfile.socialCapabilitiesAllowed else { return }
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
            // Insert immediately so the list shows even if join fails.
            if !store.activeChallenges.contains(where: { $0.id == ch.id }) {
                store.activeChallenges.insert(ch, at: 0)
            }
            // Auto-join creator — non-fatal.
            try? await SocialService.shared.joinChallenge(ch.id, username: uname, displayName: dname)
            dismiss()
        } catch {
            self.error = error.localizedDescription
        }
        isCreating = false
    }
}
