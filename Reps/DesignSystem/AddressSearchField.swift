import SwiftUI
import MapKit
import CoreLocation

struct PickedPlace {
    var name: String
    var address: String?
    var coordinate: CLLocationCoordinate2D
    var phone: String? = nil
    var website: String? = nil

    init(name: String, address: String?, coordinate: CLLocationCoordinate2D,
         phone: String? = nil, website: String? = nil) {
        self.name = name
        self.address = address
        self.coordinate = coordinate
        self.phone = phone
        self.website = website
    }

    /// Builds a place from a MapKit point-of-interest, extracting every datum
    /// the public API exposes (name, full address, coordinate, phone, website).
    init(from item: MKMapItem, fallbackName: String? = nil) {
        self.name = item.name ?? fallbackName ?? ""
        self.address = GymLocationPickerView.formatAddress(item)
        self.coordinate = item.location.coordinate
        self.phone = item.phoneNumber
        self.website = item.url?.absoluteString
    }
}

// MARK: - Gym location picker (search + tap on map)

struct GymLocationPickerView: View {
    @Environment(\.dismiss) private var dismiss
    let onSelect: (PickedPlace) -> Void

    @State private var query = ""
    @StateObject private var completer = AddressSearchCompleter()
    @State private var cameraPosition: MapCameraPosition = .automatic
    @State private var pinCoordinate: CLLocationCoordinate2D?
    @State private var pinName: String = ""
    @State private var pinAddress: String?
    @State private var pinPhone: String?
    @State private var pinWebsite: String?
    @State private var isResolving = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                MapReader { proxy in
                    Map(position: $cameraPosition) {
                        if let pinCoordinate {
                            Marker(pinName.isEmpty ? localizedString("selected_location") : pinName, coordinate: pinCoordinate)
                                .tint(PulseTheme.accent)
                        }
                        UserAnnotation()
                    }
                    .mapControls {
                        MapUserLocationButton()
                    }
                    .onTapGesture { location in
                        if let coordinate = proxy.convert(location, from: .local) {
                            select(coordinate: coordinate, name: nil, address: nil, recenter: false)
                            reverseGeocode(coordinate)
                        }
                    }
                }
                .frame(maxHeight: .infinity)

                if !completer.results.isEmpty && !query.isEmpty {
                    List(completer.results, id: \.self) { result in
                        Button {
                            resolve(completion: result)
                        } label: {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(result.title)
                                    .foregroundStyle(Color.primary)
                                if !result.subtitle.isEmpty {
                                    Text(result.subtitle)
                                        .font(.caption)
                                        .foregroundStyle(PulseTheme.secondaryText)
                                }
                            }
                        }
                    }
                    .listStyle(.plain)
                    .frame(maxHeight: 240)
                }

                if let pinCoordinate {
                    selectionBar(coordinate: pinCoordinate)
                }
            }
            .searchable(text: $query, prompt: Text("search_address"))
            .onChange(of: query) { _, newValue in
                completer.update(query: newValue)
            }
            .navigationTitle("choose_location")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("cancel") { dismiss() }
                }
            }
        }
    }

    @ViewBuilder
    private func selectionBar(coordinate: CLLocationCoordinate2D) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "mappin.circle.fill")
                    .foregroundStyle(PulseTheme.accent)
                VStack(alignment: .leading, spacing: 2) {
                    Text(pinName.isEmpty ? localizedString("selected_location") : pinName)
                        .font(.subheadline.weight(.semibold))
                    if let pinAddress, !pinAddress.isEmpty {
                        Text(pinAddress)
                            .font(.caption)
                            .foregroundStyle(PulseTheme.secondaryText)
                    }
                }
                Spacer()
                if isResolving {
                    ProgressView()
                }
            }
            Button {
                onSelect(PickedPlace(
                    name: pinName.isEmpty ? (pinAddress ?? localizedString("selected_location")) : pinName,
                    address: pinAddress,
                    coordinate: coordinate,
                    phone: pinPhone,
                    website: pinWebsite
                ))
                dismiss()
            } label: {
                Text("use_this_location")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(PulseTheme.accent)
        }
        .padding()
        .background(.ultraThinMaterial)
    }

    private func select(coordinate: CLLocationCoordinate2D, name: String?, address: String?, recenter: Bool) {
        pinCoordinate = coordinate
        if let name { pinName = name }
        if let address { pinAddress = address }
        if recenter {
            cameraPosition = .region(MKCoordinateRegion(
                center: coordinate,
                span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
            ))
        }
    }

    private func resolve(completion: MKLocalSearchCompletion) {
        query = ""
        completer.results = []
        isResolving = true
        let request = MKLocalSearch.Request(completion: completion)
        MKLocalSearch(request: request).start { response, _ in
            Task { @MainActor in
                isResolving = false
                guard let item = response?.mapItems.first else { return }
                let coordinate = item.location.coordinate
                pinName = item.name ?? completion.title
                pinAddress = Self.formatAddress(item)
                pinPhone = item.phoneNumber
                pinWebsite = item.url?.absoluteString
                select(coordinate: coordinate, name: pinName, address: pinAddress, recenter: true)
            }
        }
    }

    private func reverseGeocode(_ coordinate: CLLocationCoordinate2D) {
        isResolving = true
        let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        guard let request = MKReverseGeocodingRequest(location: location) else {
            isResolving = false
            return
        }
        Task { @MainActor in
            defer { isResolving = false }
            guard let item = try? await request.mapItems.first else { return }
            pinName = item.name ?? localizedString("selected_location")
            pinAddress = Self.formatAddress(item)
            // A raw map tap has no business listing — clear POI-only details.
            pinPhone = nil
            pinWebsite = nil
        }
    }

    nonisolated static func formatAddress(_ item: MKMapItem) -> String? {
        item.addressRepresentations?.fullAddress(includingRegion: false, singleLine: true)
    }
}

// MARK: - Address search completer

@MainActor
final class AddressSearchCompleter: NSObject, ObservableObject, MKLocalSearchCompleterDelegate {
    @Published var results: [MKLocalSearchCompletion] = []
    private let completer = MKLocalSearchCompleter()

    override init() {
        super.init()
        completer.delegate = self
        completer.resultTypes = [.address, .pointOfInterest]
    }

    func update(query: String) {
        guard !query.trimmingCharacters(in: .whitespaces).isEmpty else {
            results = []
            return
        }
        completer.queryFragment = query
    }

    nonisolated func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        // MKLocalSearchCompleter delivers delegate callbacks on the main thread.
        MainActor.assumeIsolated {
            results = self.completer.results
        }
    }

    nonisolated func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: Error) {
        MainActor.assumeIsolated {
            results = []
        }
    }
}

// MARK: - Reusable address field (type-ahead + map picker)
//
// Drop-in replacement for a plain address/location TextField. As the user types
// it shows MapKit autocomplete suggestions inline; a map button opens the full
// search-and-tap picker. When `onPlace` is provided the caller receives the full
// resolved place (address, phone, website, coordinate) so several fields can be
// filled from one selection (e.g. a gym card). Works in Forms and plain stacks.
struct AddressSearchField: View {
    let title: String
    @Binding var text: String
    var axis: Axis = .horizontal
    var onPlace: ((PickedPlace) -> Void)? = nil

    @StateObject private var completer = AddressSearchCompleter()
    @FocusState private var focused: Bool
    @State private var showMap = false
    /// Suppresses the next `onChange` so applying a selection doesn't re-trigger search.
    @State private var suppressSearch = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                TextField(title, text: $text, axis: axis)
                    .focused($focused)
                    .autocorrectionDisabled()
                Button {
                    focused = false
                    showMap = true
                } label: {
                    Image(systemName: "mappin.and.ellipse")
                        .foregroundStyle(PulseTheme.accent)
                }
                .buttonStyle(.borderless)
            }

            if focused, !completer.results.isEmpty {
                let items = Array(completer.results.prefix(4))
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(items.enumerated()), id: \.offset) { idx, r in
                        Button { choose(r) } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "mappin.circle")
                                    .foregroundStyle(PulseTheme.secondaryText)
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(r.title)
                                        .font(.subheadline)
                                        .foregroundStyle(Color.primary)
                                    if !r.subtitle.isEmpty {
                                        Text(r.subtitle)
                                            .font(.caption)
                                            .foregroundStyle(PulseTheme.secondaryText)
                                    }
                                }
                                Spacer(minLength: 0)
                            }
                            .contentShape(Rectangle())
                            .padding(.vertical, 7)
                        }
                        .buttonStyle(.plain)
                        if idx < items.count - 1 { Divider() }
                    }
                }
                .padding(.horizontal, 10)
                .background(PulseTheme.grouped, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
        }
        .onChange(of: text) { _, newValue in
            if suppressSearch { suppressSearch = false; return }
            completer.update(query: newValue)
        }
        .onChange(of: focused) { _, isFocused in
            if !isFocused { completer.results = [] }
        }
        .sheet(isPresented: $showMap) {
            GymLocationPickerView { place in apply(place) }
        }
    }

    private func choose(_ completion: MKLocalSearchCompletion) {
        completer.results = []
        let request = MKLocalSearch.Request(completion: completion)
        MKLocalSearch(request: request).start { response, _ in
            Task { @MainActor in
                if let item = response?.mapItems.first {
                    apply(PickedPlace(from: item, fallbackName: completion.title))
                } else {
                    // Couldn't resolve a map item — keep the typed text.
                    suppressSearch = true
                    text = [completion.title, completion.subtitle]
                        .filter { !$0.isEmpty }
                        .joined(separator: ", ")
                    focused = false
                }
            }
        }
    }

    private func apply(_ place: PickedPlace) {
        suppressSearch = true
        if let onPlace {
            onPlace(place)
        } else {
            text = place.address ?? place.name
        }
        completer.results = []
        focused = false
    }
}
