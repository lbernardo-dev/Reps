import SwiftUI
import MapKit
import CoreLocation

struct GymVisitEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppStore.self) private var store
    @State private var gymName = ""
    @State private var date = Date()
    @State private var locationNote = ""
    @State private var address: String?
    @State private var coordinate: CLLocationCoordinate2D?
    @State private var selectedWorkoutIDs: [UUID] = []
    @State private var showingPlacePicker = false
    @State private var showingWorkoutPicker = false

    private var gymWorkouts: [WorkoutSession] {
        store.workoutSessions
            .filter { $0.location == .gym }
            .sorted { $0.date > $1.date }
    }

    private var selectedWorkouts: [WorkoutSession] {
        selectedWorkoutIDs.compactMap { id in
            store.workoutSessions.first { $0.id == id }
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("place") {
                    Button {
                        showingPlacePicker = true
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: "mappin.and.ellipse")
                                .foregroundStyle(PulseTheme.accent)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(gymName.isEmpty ? localizedString("search_or_pick_on_map") : gymName)
                                    .foregroundStyle(gymName.isEmpty ? PulseTheme.secondaryText : Color.primary)
                                if let address, !address.isEmpty {
                                    Text(address)
                                        .font(.caption)
                                        .foregroundStyle(PulseTheme.secondaryText)
                                }
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundStyle(PulseTheme.secondaryText)
                        }
                    }

                    if let coordinate {
                        GymVisitMapPreview(coordinate: coordinate)
                            .frame(height: 130)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                    }

                    DatePicker("date_2", selection: $date)
                    TextField("location_or_room", text: $locationNote)
                }

                Section("training_done") {
                    Button {
                        showingWorkoutPicker = true
                    } label: {
                        HStack {
                            Image(systemName: "dumbbell.fill")
                                .foregroundStyle(PulseTheme.accent)
                            Text(selectedWorkoutIDs.isEmpty ? localizedString("select_trainings") : localizedFormat("count_trainings_selected", selectedWorkoutIDs.count))
                                .foregroundStyle(selectedWorkoutIDs.isEmpty ? PulseTheme.secondaryText : Color.primary)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundStyle(PulseTheme.secondaryText)
                        }
                    }

                    ForEach(selectedWorkouts) { session in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(session.workoutTitle)
                                .font(.subheadline)
                            Text(session.date.formatted(date: .abbreviated, time: .shortened))
                                .font(.caption)
                                .foregroundStyle(PulseTheme.secondaryText)
                        }
                    }
                }

                if !store.gymPasses.isEmpty {
                    Section("fast") {
                        ForEach(store.gymPasses) { pass in
                            Button(pass.gymName) {
                                gymName = pass.gymName
                            }
                        }
                    }
                }
            }
            .navigationTitle("registrar_visita")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("cancel") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("save") { save() }
                        .disabled(gymName.isEmpty)
                }
            }
            .sheet(isPresented: $showingPlacePicker) {
                GymLocationPickerView { place in
                    gymName = place.name
                    address = place.address
                    coordinate = place.coordinate
                }
            }
            .sheet(isPresented: $showingWorkoutPicker) {
                GymVisitWorkoutPickerView(
                    workouts: gymWorkouts,
                    selectedIDs: $selectedWorkoutIDs
                )
            }
        }
    }

    private func save() {
        let titles = selectedWorkouts.map(\.workoutTitle)
        store.addGymVisit(GymVisit(
            gymName: gymName,
            date: date,
            locationNote: locationNote.isEmpty ? nil : locationNote,
            workoutTitle: titles.isEmpty ? nil : titles.joined(separator: ", "),
            address: address,
            latitude: coordinate?.latitude,
            longitude: coordinate?.longitude,
            workoutSessionIDs: selectedWorkoutIDs
        ))
        dismiss()
    }
}

// MARK: - Gym visit map preview

private struct GymVisitMapPreview: View {
    let coordinate: CLLocationCoordinate2D

    var body: some View {
        Map(initialPosition: .region(MKCoordinateRegion(
            center: coordinate,
            span: MKCoordinateSpan(latitudeDelta: 0.005, longitudeDelta: 0.005)
        ))) {
            Marker("", coordinate: coordinate)
                .tint(PulseTheme.accent)
        }
        .allowsHitTesting(false)
    }
}

struct GymVisitWorkoutPickerView: View {
    @Environment(\.dismiss) private var dismiss
    let workouts: [WorkoutSession]
    @Binding var selectedIDs: [UUID]

    var body: some View {
        NavigationStack {
            Group {
                if workouts.isEmpty {
                    ContentUnavailableView(
                        localizedString("no_gym_workouts"),
                        systemImage: "dumbbell",
                        description: Text("no_gym_workouts_description")
                    )
                } else {
                    List(workouts) { session in
                        Button {
                            toggle(session.id)
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(session.workoutTitle)
                                        .foregroundStyle(Color.primary)
                                    Text(session.date.formatted(date: .abbreviated, time: .shortened))
                                        .font(.caption)
                                        .foregroundStyle(PulseTheme.secondaryText)
                                }
                                Spacer()
                                if selectedIDs.contains(session.id) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(PulseTheme.accent)
                                } else {
                                    Image(systemName: "circle")
                                        .foregroundStyle(PulseTheme.secondaryText)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("select_trainings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("done") { dismiss() }
                }
            }
        }
    }

    private func toggle(_ id: UUID) {
        if let index = selectedIDs.firstIndex(of: id) {
            selectedIDs.remove(at: index)
        } else {
            selectedIDs.append(id)
        }
    }
}
