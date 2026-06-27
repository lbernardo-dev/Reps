import SwiftUI
import PhotosUI
import UIKit

struct CodePreview: View {
    let value: String
    let type: GymPass.CodeType
    var imageData: Data? = nil

    var body: some View {
        if value.isEmpty, let imageData, let uiImage = UIImage(data: imageData) {
            Image(uiImage: uiImage)
                .resizable()
                .scaledToFit()
        } else if let image = generatedImage {
            Image(uiImage: image)
                .interpolation(.none)
                .resizable()
                .scaledToFit()
                .padding(8)
        } else {
            Image(systemName: type == .qr ? "qrcode" : "barcode")
                .font(.largeTitle)
                .foregroundStyle(PulseTheme.secondaryText)
        }
    }

    private var generatedImage: UIImage? {
        let data = Data(value.utf8)
        let filterName = type == .qr ? "CIQRCodeGenerator" : "CICode128BarcodeGenerator"
        guard let filter = CIFilter(name: filterName) else { return nil }
        filter.setValue(data, forKey: "inputMessage")
        guard let output = filter.outputImage else { return nil }
        let scale = CGAffineTransform(scaleX: 8, y: 8)
        let image = output.transformed(by: scale)
        return UIImage(ciImage: image)
    }
}

struct GymPassEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppStore.self) private var store
    @StateObject private var permissions = PermissionService.shared

    private let editingID: UUID?

    // Código
    @State private var codeValue: String
    @State private var codeType: GymPass.CodeType
    @State private var cardImageData: Data?

    // Membresía
    @State private var gymName: String
    @State private var membershipID: String
    @State private var startDate: Date
    @State private var isActive: Bool
    @State private var endDate: Date

    // Plan
    @State private var planName: String
    @State private var priceText: String
    @State private var currencyCode: String
    @State private var billingCycle: BillingCycle
    @State private var hasRenewal: Bool
    @State private var nextRenewalDate: Date
    @State private var renewalReminderEnabled: Bool

    // Local
    @State private var venueAddress: String
    @State private var venuePhone: String
    @State private var venueWebsite: String
    @State private var venueHours: String

    // Facturas / notas
    @State private var invoices: [GymInvoice]
    @State private var notes: String

    // UI
    @State private var showScanner = false
    @State private var showPermissionDenied = false
    @State private var photoItem: PhotosPickerItem?
    @State private var invoiceBeingEdited: GymInvoice?

    init(pass: GymPass? = nil) {
        editingID = pass?.id
        _codeValue = State(initialValue: pass?.codeValue ?? "")
        _codeType = State(initialValue: pass?.codeType ?? .qr)
        _cardImageData = State(initialValue: pass?.imageData)
        _gymName = State(initialValue: pass?.gymName ?? "")
        _membershipID = State(initialValue: pass?.membershipID ?? "")
        _startDate = State(initialValue: pass?.startDate ?? .now)
        _isActive = State(initialValue: pass?.isActive ?? true)
        _endDate = State(initialValue: pass?.endDate ?? .now)
        _planName = State(initialValue: pass?.planName ?? "")
        _priceText = State(initialValue: pass?.price.map { String(format: "%.2f", $0) } ?? "")
        _currencyCode = State(initialValue: pass?.currencyCode ?? (Locale.current.currency?.identifier ?? "USD"))
        _billingCycle = State(initialValue: pass?.billingCycle ?? .monthly)
        _hasRenewal = State(initialValue: pass?.nextRenewalDate != nil)
        _nextRenewalDate = State(initialValue: pass?.nextRenewalDate
            ?? Calendar.current.date(byAdding: .month, value: 1, to: .now) ?? .now)
        _renewalReminderEnabled = State(initialValue: pass?.renewalReminderEnabled ?? false)
        _venueAddress = State(initialValue: pass?.venueAddress ?? "")
        _venuePhone = State(initialValue: pass?.venuePhone ?? "")
        _venueWebsite = State(initialValue: pass?.venueWebsite ?? "")
        _venueHours = State(initialValue: pass?.venueHours ?? "")
        _invoices = State(initialValue: pass?.invoices ?? [])
        _notes = State(initialValue: pass?.notes ?? "")
    }

    var body: some View {
        NavigationStack {
            Form {
                codeSection
                membershipSection
                planSection
                venueSection
                invoicesSection
                Section("notes_2") {
                    TextField("notes_2", text: $notes, axis: .vertical)
                }
            }
            .navigationTitle("gym_card")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("cancel") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("save") { save() }
                        .disabled(gymName.isEmpty || (codeValue.isEmpty && cardImageData == nil))
                }
            }
            .fullScreenCover(isPresented: $showScanner) {
                scannerCover
            }
            .sheet(item: $invoiceBeingEdited) { invoice in
                GymInvoiceEditorView(invoice: invoice, defaultCurrency: currencyCode) { saved in
                    upsertInvoice(saved)
                }
            }
            .onChange(of: photoItem) { _, newItem in
                guard let newItem else { return }
                Task { await handlePickedPhoto(newItem) }
            }
            .alert("permission_denied", isPresented: $showPermissionDenied) {
                Button("abrir_ajustes") { permissions.openSettings() }
                Button("cancel", role: .cancel) {}
            } message: {
                Text(permissions.deniedMessage ?? localizedString("perm_camera_needed"))
            }
        }
    }

    // MARK: - Sections

    private var codeSection: some View {
        Section("gym_code") {
            if !codeValue.isEmpty || cardImageData != nil {
                CodePreview(value: codeValue, type: codeType, imageData: cardImageData)
                    .frame(maxWidth: .infinity)
                    .frame(height: 150)
            }

            if CodeScannerView.isSupported {
                Button { requestScan() } label: {
                    Label("scan_code", systemImage: "camera.viewfinder")
                }
            }

            PhotosPicker(selection: $photoItem, matching: .images) {
                Label("import_code_from_photo", systemImage: "photo.on.rectangle")
            }

            Picker("code_type", selection: $codeType) {
                Text("qr").tag(GymPass.CodeType.qr)
                Text("barcode_2").tag(GymPass.CodeType.barcode)
            }
            .pickerStyle(.segmented)

            TextField("valor_qr_barcode", text: $codeValue)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()

            if cardImageData != nil {
                Button(role: .destructive) { cardImageData = nil } label: {
                    Label("remove_card_image", systemImage: "trash")
                }
            }
        }
    }

    private var membershipSection: some View {
        Section("membership") {
            TextField("gym_2", text: $gymName)
            TextField("id_socio", text: $membershipID)
            DatePicker("start_date", selection: $startDate, displayedComponents: .date)
            Toggle("membership_active", isOn: $isActive)
            if !isActive {
                DatePicker("end_date", selection: $endDate, displayedComponents: .date)
            }
        }
    }

    private var planSection: some View {
        Section("plan_details") {
            TextField("plan_name", text: $planName)
            HStack {
                TextField("price", text: $priceText)
                    .keyboardType(.decimalPad)
                TextField("currency", text: $currencyCode)
                    .textInputAutocapitalization(.characters)
                    .frame(width: 80)
            }
            Picker("billing_cycle", selection: $billingCycle) {
                ForEach(BillingCycle.allCases) { cycle in
                    Text(billingCycleLabel(cycle)).tag(cycle)
                }
            }
            Toggle("has_renewal", isOn: $hasRenewal)
            if hasRenewal {
                DatePicker("next_renewal", selection: $nextRenewalDate, displayedComponents: .date)
                Toggle("payment_reminder", isOn: $renewalReminderEnabled)
            }
        }
    }

    private var venueSection: some View {
        Section("venue_details") {
            AddressSearchField(title: localizedString("address"), text: $venueAddress, axis: .vertical) { place in
                if gymName.trimmingCharacters(in: .whitespaces).isEmpty { gymName = place.name }
                venueAddress = place.address ?? place.name
                if let phone = place.phone, venuePhone.isEmpty { venuePhone = phone }
                if let website = place.website, venueWebsite.isEmpty { venueWebsite = website }
            }
            TextField("phone", text: $venuePhone)
                .keyboardType(.phonePad)
            TextField("website", text: $venueWebsite)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
            TextField("opening_hours", text: $venueHours, axis: .vertical)
        }
    }

    private var invoicesSection: some View {
        Section("invoices") {
            ForEach(invoices.sorted { $0.date > $1.date }) { invoice in
                Button {
                    invoiceBeingEdited = invoice
                } label: {
                    GymInvoiceRow(invoice: invoice)
                }
                .buttonStyle(.plain)
            }
            .onDelete { offsets in
                let sorted = invoices.sorted { $0.date > $1.date }
                let ids = offsets.map { sorted[$0].id }
                invoices.removeAll { ids.contains($0.id) }
            }

            Button {
                invoiceBeingEdited = GymInvoice(amount: 0, currencyCode: currencyCode)
            } label: {
                Label("add_invoice", systemImage: "plus.circle")
            }
        }
    }

    private var scannerCover: some View {
        ZStack(alignment: .topTrailing) {
            CodeScannerView(
                onScan: { code in
                    codeValue = code.value
                    codeType = code.type
                    cardImageData = nil
                    showScanner = false
                },
                onCancel: { showScanner = false }
            )
            .ignoresSafeArea()

            Button { showScanner = false } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.largeTitle)
                    .foregroundStyle(.white, .black.opacity(0.4))
                    .padding()
            }
        }
    }

    // MARK: - Actions

    private func requestScan() {
        Task {
            if await permissions.requestCamera() {
                showScanner = true
            } else {
                showPermissionDenied = true
            }
        }
    }

    private func handlePickedPhoto(_ item: PhotosPickerItem) async {
        guard let data = try? await item.loadTransferable(type: Data.self),
              let image = UIImage(data: data) else { return }
        if let scanned = BarcodeImageDetector.detect(in: image) {
            await MainActor.run {
                codeValue = scanned.value
                codeType = scanned.type
                cardImageData = nil
            }
        } else {
            let stored = image.jpegData(compressionQuality: 0.7) ?? data
            await MainActor.run {
                cardImageData = stored
                codeValue = ""
            }
        }
    }

    private func upsertInvoice(_ invoice: GymInvoice) {
        if let index = invoices.firstIndex(where: { $0.id == invoice.id }) {
            invoices[index] = invoice
        } else {
            invoices.append(invoice)
        }
    }

    private func billingCycleLabel(_ cycle: BillingCycle) -> String {
        switch cycle {
        case .weekly: localizedString("billing_weekly")
        case .monthly: localizedString("billing_monthly")
        case .quarterly: localizedString("billing_quarterly")
        case .annual: localizedString("billing_annual")
        case .oneTime: localizedString("billing_one_time")
        }
    }

    private func save() {
        let pass = GymPass(
            id: editingID ?? UUID(),
            gymName: gymName,
            membershipID: membershipID.isEmpty ? codeValue : membershipID,
            codeValue: codeValue,
            codeType: codeType,
            notes: notes.isEmpty ? nil : notes,
            imageData: cardImageData,
            isActive: isActive,
            startDate: startDate,
            endDate: isActive ? nil : endDate,
            planName: planName.isEmpty ? nil : planName,
            price: Double(priceText.replacingOccurrences(of: ",", with: ".")),
            currencyCode: currencyCode.isEmpty ? nil : currencyCode,
            billingCycle: billingCycle,
            nextRenewalDate: hasRenewal ? nextRenewalDate : nil,
            renewalReminderEnabled: hasRenewal && renewalReminderEnabled,
            venueAddress: venueAddress.isEmpty ? nil : venueAddress,
            venuePhone: venuePhone.isEmpty ? nil : venuePhone,
            venueWebsite: venueWebsite.isEmpty ? nil : venueWebsite,
            venueHours: venueHours.isEmpty ? nil : venueHours,
            invoices: invoices
        )

        if editingID == nil {
            store.addGymPass(pass)
        } else {
            store.updateGymPass(pass)
        }
        dismiss()
    }
}

private struct GymInvoiceRow: View {
    let invoice: GymInvoice

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: invoice.attachmentIsPDF ? "doc.fill" : (invoice.attachmentData != nil ? "photo.fill" : "doc.text"))
                .foregroundStyle(PulseTheme.accent)
            VStack(alignment: .leading, spacing: 2) {
                Text(invoice.amount.formatted(.currency(code: invoice.currencyCode)))
                    .font(.subheadline.weight(.semibold))
                Text(invoice.date.formatted(date: .abbreviated, time: .omitted))
                    .font(.caption)
                    .foregroundStyle(PulseTheme.secondaryText)
                if let note = invoice.note, !note.isEmpty {
                    Text(note)
                        .font(.caption)
                        .foregroundStyle(PulseTheme.secondaryText)
                        .lineLimit(1)
                }
            }
            Spacer()
        }
    }
}

struct GymInvoiceEditorView: View {
    @Environment(\.dismiss) private var dismiss

    private let invoiceID: UUID
    let onSave: (GymInvoice) -> Void

    @State private var date: Date
    @State private var amountText: String
    @State private var currencyCode: String
    @State private var hasPeriod: Bool
    @State private var periodStart: Date
    @State private var periodEnd: Date
    @State private var note: String
    @State private var attachmentData: Data?
    @State private var attachmentIsPDF: Bool
    @State private var photoItem: PhotosPickerItem?
    @State private var showFileImporter = false

    init(invoice: GymInvoice, defaultCurrency: String, onSave: @escaping (GymInvoice) -> Void) {
        invoiceID = invoice.id
        self.onSave = onSave
        _date = State(initialValue: invoice.date)
        _amountText = State(initialValue: invoice.amount > 0 ? String(format: "%.2f", invoice.amount) : "")
        _currencyCode = State(initialValue: invoice.currencyCode.isEmpty ? defaultCurrency : invoice.currencyCode)
        _hasPeriod = State(initialValue: invoice.periodStart != nil)
        _periodStart = State(initialValue: invoice.periodStart ?? invoice.date)
        _periodEnd = State(initialValue: invoice.periodEnd
            ?? Calendar.current.date(byAdding: .month, value: 1, to: invoice.date) ?? invoice.date)
        _note = State(initialValue: invoice.note ?? "")
        _attachmentData = State(initialValue: invoice.attachmentData)
        _attachmentIsPDF = State(initialValue: invoice.attachmentIsPDF)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("invoice") {
                    DatePicker("date_2", selection: $date, displayedComponents: .date)
                    HStack {
                        TextField("amount", text: $amountText)
                            .keyboardType(.decimalPad)
                        TextField("currency", text: $currencyCode)
                            .textInputAutocapitalization(.characters)
                            .frame(width: 80)
                    }
                    Toggle("billing_period", isOn: $hasPeriod)
                    if hasPeriod {
                        DatePicker("period_start", selection: $periodStart, displayedComponents: .date)
                        DatePicker("period_end", selection: $periodEnd, displayedComponents: .date)
                    }
                    TextField("notes_2", text: $note, axis: .vertical)
                }

                Section("attachment") {
                    if let attachmentData {
                        if !attachmentIsPDF, let uiImage = UIImage(data: attachmentData) {
                            Image(uiImage: uiImage)
                                .resizable()
                                .scaledToFit()
                                .frame(maxHeight: 180)
                        } else {
                            Label("pdf_attached", systemImage: "doc.fill")
                        }
                        Button(role: .destructive) {
                            self.attachmentData = nil
                            attachmentIsPDF = false
                        } label: {
                            Label("remove_attachment", systemImage: "trash")
                        }
                    } else {
                        PhotosPicker(selection: $photoItem, matching: .images) {
                            Label("attach_photo", systemImage: "photo")
                        }
                        Button { showFileImporter = true } label: {
                            Label("attach_pdf", systemImage: "doc")
                        }
                    }
                }
            }
            .navigationTitle("invoice")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("cancel") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("save") { save() }
                        .disabled(amount == nil)
                }
            }
            .onChange(of: photoItem) { _, newItem in
                guard let newItem else { return }
                Task {
                    if let data = try? await newItem.loadTransferable(type: Data.self) {
                        await MainActor.run {
                            attachmentData = data
                            attachmentIsPDF = false
                        }
                    }
                }
            }
            .fileImporter(isPresented: $showFileImporter, allowedContentTypes: [.pdf]) { result in
                if case let .success(url) = result {
                    let needsScope = url.startAccessingSecurityScopedResource()
                    defer { if needsScope { url.stopAccessingSecurityScopedResource() } }
                    if let data = try? Data(contentsOf: url) {
                        attachmentData = data
                        attachmentIsPDF = true
                    }
                }
            }
        }
    }

    private var amount: Double? {
        Double(amountText.replacingOccurrences(of: ",", with: "."))
    }

    private func save() {
        guard let amount else { return }
        onSave(GymInvoice(
            id: invoiceID,
            date: date,
            amount: amount,
            currencyCode: currencyCode.isEmpty ? "USD" : currencyCode,
            periodStart: hasPeriod ? periodStart : nil,
            periodEnd: hasPeriod ? periodEnd : nil,
            note: note.isEmpty ? nil : note,
            attachmentData: attachmentData,
            attachmentIsPDF: attachmentIsPDF
        ))
        dismiss()
    }
}
