//
//  SocialReportSheetView.swift
//  Reps
//

import SwiftUI

struct SocialReportSheetView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppStore.self) private var store

    let targetType: String // "user", "post", "comment"
    let targetProfile: SocialProfile?
    let targetPostID: String?
    let targetUsername: String
    var onSubmitted: (() -> Void)? = nil

    @State private var selectedCategory: String = "spam"
    @State private var notesText: String = ""
    @State private var isSubmitting: Bool = false
    @State private var errorMessage: String? = nil

    private let categories: [(id: String, icon: String, titleKey: String, descKey: String)] = [
        ("spam", "exclamationmark.triangle.fill", "social_report_category_spam", "social_report_category_spam_desc"),
        ("harassment", "hand.raised.fill", "social_report_category_harassment", "social_report_category_harassment_desc"),
        ("inappropriate", "eye.slash.fill", "social_report_category_inappropriate", "social_report_category_inappropriate_desc"),
        ("other", "ellipsis.circle.fill", "social_report_category_other", "social_report_category_other_desc")
    ]

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack(spacing: 12) {
                        Image(systemName: targetType == "user" ? "person.crop.circle.badge.exclamationmark" : "flag.fill")
                            .font(.title2)
                            .foregroundStyle(PulseTheme.accent)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(headerTitle)
                                .font(.headline)
                            Text("@\(targetUsername)")
                                .font(.subheadline)
                                .foregroundStyle(PulseTheme.secondaryText)
                        }
                    }
                    .padding(.vertical, 4)
                }

                Section(header: Text("social_report_select_reason")) {
                    ForEach(categories, id: \.id) { cat in
                        Button {
                            selectedCategory = cat.id
                            HapticService.selection()
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: cat.icon)
                                    .foregroundStyle(selectedCategory == cat.id ? PulseTheme.accent : PulseTheme.secondaryText)
                                    .frame(width: 24)

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(LocalizedStringKey(cat.titleKey))
                                        .font(.body.weight(.medium))
                                        .foregroundStyle(.primary)
                                    Text(LocalizedStringKey(cat.descKey))
                                        .font(.caption)
                                        .foregroundStyle(PulseTheme.secondaryText)
                                }

                                Spacer()

                                if selectedCategory == cat.id {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(PulseTheme.accent)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }

                Section(header: Text("social_report_notes_header"), footer: Text("social_report_notes_footer")) {
                    TextField(
                        String(localized: "social_report_notes_placeholder"),
                        text: $notesText,
                        axis: .vertical
                    )
                    .lineLimit(3...5)
                    .onChange(of: notesText) { _, newValue in
                        if newValue.count > 280 {
                            notesText = String(newValue.prefix(280))
                        }
                    }
                }

                if let err = errorMessage {
                    Section {
                        Text(err)
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle(Text("social_report_title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("cancel_action") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        submitReport()
                    } label: {
                        if isSubmitting {
                            ProgressView()
                        } else {
                            Text("social_report_submit_btn")
                                .bold()
                        }
                    }
                    .disabled(isSubmitting)
                }
            }
        }
    }

    private var headerTitle: String {
        switch targetType {
        case "user": return String(localized: "social_report_header_user")
        case "post": return String(localized: "social_report_header_post")
        default: return String(localized: "social_report_header_comment")
        }
    }

    private func submitReport() {
        guard !isSubmitting else { return }
        isSubmitting = true
        errorMessage = nil

        let reporterUname = store.userProfile.socialUsername ?? "anonymous"
        let ownerID = targetProfile?.ownerRecordName ?? ""

        Task {
            do {
                try await SocialService.shared.submitReport(
                    targetType: targetType,
                    targetOwnerRecordName: ownerID,
                    targetUsername: targetUsername,
                    targetID: targetPostID ?? "",
                    reasonCategory: selectedCategory,
                    reasonNotes: notesText,
                    reporterUsername: reporterUname
                )
                await MainActor.run {
                    HapticService.notification(.success)
                    isSubmitting = false
                    onSubmitted?()
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    HapticService.notification(.error)
                    isSubmitting = false
                    errorMessage = error.localizedDescription
                }
            }
        }
    }
}
