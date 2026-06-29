import SwiftUI
import PhotosUI
import UIKit

struct QuickBodyMetricEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppStore.self) private var store
    @State private var weight = ""
    @State private var height = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("top_metrics") {
                    TextField("Peso (\(store.displayedWeight.unit))", text: $weight)
                        .keyboardType(.decimalPad)
                    TextField("Altura (\(store.displayedHeight.unit))", text: $height)
                        .keyboardType(.decimalPad)
                }
            }
            .navigationTitle("edit_body")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                if store.hasBodyMetrics {
                    weight = String(format: "%.1f", store.displayedWeight.value)
                    height = String(format: "%.0f", store.displayedHeight.value)
                } else {
                    weight = ""
                    height = ""
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("cancel") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("save") { save() }
                        .disabled(decimal(weight) == nil || decimal(height) == nil)
                }
            }
        }
    }

    private func save() {
        guard let rawWeight = decimal(weight), let rawHeight = decimal(height) else { return }
        let weightKg = store.userProfile.units == .metric ? rawWeight : UnitConverter.kilograms(fromPounds: rawWeight)
        let heightCm = store.userProfile.units == .metric ? rawHeight : UnitConverter.centimeters(fromInches: rawHeight)
        store.updateLatestBodyMetrics(weightKg: weightKg, heightCm: heightCm)
        dismiss()
    }
}

struct ProgressPhotoEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppStore.self) private var store
    @State private var date = Date()
    @State private var note = ""
    @State private var photoItem: PhotosPickerItem?
    @State private var imageData: Data?
    @State private var showCamera = false
    @State private var showPermissionDenied = false
    @State private var permissionDeniedMessage = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("photo_2") {
                    VStack(spacing: 10) {
                        if CameraPicker.isAvailable {
                            Button(action: requestCameraAndOpen) {
                                ProgressPhotoSourceActionLabel(
                                    title: "take_photo",
                                    subtitle: "camera",
                                    systemImage: "camera.fill"
                                )
                            }
                            .buttonStyle(.plain)
                        } else {
                            #if targetEnvironment(simulator)
                            Button {
                                if let image = UIImage(systemName: "figure.strengthtraining.traditional"),
                                   let data = image.jpegData(compressionQuality: 0.72) {
                                    imageData = data
                                    HapticService.notification(.success)
                                }
                            } label: {
                                ProgressPhotoSourceActionLabel(
                                    title: "Simular foto",
                                    subtitle: "Vista previa del simulador",
                                    systemImage: "camera.badge.ellipsis"
                                )
                            }
                            .buttonStyle(.plain)
                            #endif
                        }

                        PhotosPicker(selection: $photoItem, matching: .images) {
                            HStack(spacing: 14) {
                                Image(systemName: "photo.on.rectangle")
                                    .font(.title3.weight(.semibold))
                                    .foregroundStyle(PulseTheme.accent)
                                    .frame(width: 42, height: 42)
                                    .background(PulseTheme.accent.opacity(0.14))
                                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                                VStack(alignment: .leading, spacing: 2) {
                                    Text("choose_from_gallery")
                                        .font(.headline)
                                        .foregroundStyle(.primary)
                                    Text("photos")
                                        .font(.subheadline)
                                        .foregroundStyle(PulseTheme.secondaryText)
                                }

                                Spacer(minLength: 12)

                                Image(systemName: "chevron.right")
                                    .font(.footnote.weight(.semibold))
                                    .foregroundStyle(PulseTheme.tertiaryText)
                            }
                            .padding(.horizontal, 14)
                            .frame(maxWidth: .infinity, minHeight: 64, alignment: .leading)
                            .background(PulseTheme.elevated)
                            .clipShape(RoundedRectangle(cornerRadius: PulseTheme.compactRadius, style: .continuous))
                            .contentShape(RoundedRectangle(cornerRadius: PulseTheme.compactRadius, style: .continuous))
                        }
                        .buttonStyle(.plain)
                    }

                    if let imageData, let image = UIImage(data: imageData) {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                            .frame(height: 220)
                            .clipped()
                            .clipShape(RoundedRectangle(cornerRadius: PulseTheme.compactRadius, style: .continuous))
                            .accessibilityLabel("selected_photo")
                    } else {
                        ProgressPhotoEmptyPreview()
                    }
                }

                Section("contexto") {
                    DatePicker("date_2", selection: $date, displayedComponents: [.date])
                    Text(store.hasBodyMetrics ? "Peso actual: \(String(format: "%.1f", store.currentWeight)) kg" : "Peso actual: sin registrar")
                    TextField("nota", text: $note, axis: .vertical)
                        .lineLimit(2...4)
                }
            }
            .navigationTitle("progress_photo")
            .navigationBarTitleDisplayMode(.inline)
            .onChange(of: photoItem) { _, item in
                Task { await loadPhoto(item) }
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("cancel") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("save") { save() }
                        .disabled(imageData == nil)
                }
            }
            .fullScreenCover(isPresented: $showCamera) {
                CameraPicker(isPresented: $showCamera) { image in
                    if let compressed = image.jpegData(compressionQuality: 0.72) {
                        imageData = compressed
                    }
                }
                .ignoresSafeArea()
            }
            .alert("permission_required", isPresented: $showPermissionDenied) {
                Button("abrir_ajustes") {
                    PermissionService.shared.openSettings()
                }
                Button("cancel", role: .cancel) {}
            } message: {
                Text(permissionDeniedMessage)
            }
        }
    }

    private func requestCameraAndOpen() {
        Task {
            let granted = await PermissionService.shared.requestCamera()
            if granted {
                showCamera = true
            } else {
                permissionDeniedMessage = PermissionService.shared.deniedMessage ?? localizedString("camera_blocked_reps_settings")
                showPermissionDenied = true
            }
        }
    }

    private func loadPhoto(_ item: PhotosPickerItem?) async {
        guard let data = try? await item?.loadTransferable(type: Data.self),
              let image = UIImage(data: data),
              let compressed = image.jpegData(compressionQuality: 0.72) else {
            return
        }
        imageData = compressed
    }

    private func save() {
        guard let imageData else { return }
        store.addProgressPhoto(ProgressPhoto(date: date, imageData: imageData, weightKg: store.hasBodyMetrics ? store.currentWeight : nil, note: note.isEmpty ? nil : note))
        dismiss()
    }
}

private struct ProgressPhotoSourceActionLabel: View {
    let title: LocalizedStringKey
    let subtitle: LocalizedStringKey
    let systemImage: String

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: systemImage)
                .font(.title3.weight(.semibold))
                .foregroundStyle(PulseTheme.accent)
                .frame(width: 42, height: 42)
                .background(PulseTheme.accent.opacity(0.14))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

            VStack(alignment: .leading, spacing: 2) {
                Text(localizedKey(title))
                    .font(.headline)
                    .foregroundStyle(.primary)
                Text(localizedKey(subtitle))
                    .font(.subheadline)
                    .foregroundStyle(PulseTheme.secondaryText)
            }

            Spacer(minLength: 12)

            Image(systemName: "chevron.right")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(PulseTheme.tertiaryText)
        }
        .padding(.horizontal, 14)
        .frame(maxWidth: .infinity, minHeight: 64, alignment: .leading)
        .background(PulseTheme.elevated)
        .clipShape(RoundedRectangle(cornerRadius: PulseTheme.compactRadius, style: .continuous))
        .contentShape(RoundedRectangle(cornerRadius: PulseTheme.compactRadius, style: .continuous))
    }
}

private struct ProgressPhotoEmptyPreview: View {
    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: "photo.badge.plus")
                .font(.system(size: 34, weight: .semibold))
                .foregroundStyle(PulseTheme.accent)
            Text("no_photo_selected")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.primary)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 168)
        .background(PulseTheme.grouped)
        .clipShape(RoundedRectangle(cornerRadius: PulseTheme.compactRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: PulseTheme.compactRadius, style: .continuous)
                .stroke(PulseTheme.separator, lineWidth: 1)
        )
        .accessibilityElement(children: .combine)
    }
}

private func decimal(_ text: String) -> Double? {
    let normalized = text.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: ",", with: ".")
    guard !normalized.isEmpty else { return nil }
    return Double(normalized)
}
