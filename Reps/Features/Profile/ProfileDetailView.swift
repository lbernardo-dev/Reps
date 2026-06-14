import SwiftUI
import PhotosUI

struct ProfileDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppStore.self) private var store
    
    @State private var displayName = ""
    @State private var email = ""
    @State private var sex: UserProfile.Sex = .male
    @State private var dateOfBirth = Date()
    @State private var mainGoal: UserProfile.MainGoal = .buildMuscle
    @State private var experience: UserProfile.Experience = .intermediate
    @State private var weeklyTrainingDays = 4
    @State private var trainingLocation: UserProfile.TrainingLocation = .gym
    
    @State private var avatarPickerItem: PhotosPickerItem?
    @State private var avatarData: Data?
    
    var body: some View {
        let currentAvatarData = avatarData
        Form {
            Section {
                HStack {
                    Spacer()
                    PhotosPicker(selection: $avatarPickerItem, matching: .images) {
                        ZStack(alignment: .bottomTrailing) {
                            if let currentAvatarData, let uiImage = UIImage(data: currentAvatarData) {
                                Image(uiImage: uiImage)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 100, height: 100)
                                    .clipShape(Circle())
                                    .overlay(Circle().stroke(.white, lineWidth: 2.2))
                                    .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
                            } else {
                                ZStack {
                                    Circle()
                                        .fill(PulseTheme.primary.opacity(0.12))
                                        .frame(width: 100, height: 100)
                                    Image(systemName: "person.crop.circle.fill")
                                        .font(.system(size: 80))
                                        .foregroundStyle(PulseTheme.primary)
                                }
                            }
                            
                            Image(systemName: "camera.fill")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(.white)
                                .frame(width: 28, height: 28)
                                .background(PulseTheme.accent)
                                .clipShape(Circle())
                                .overlay(Circle().stroke(.black.opacity(0.12), lineWidth: 1))
                                .offset(x: 2, y: 2)
                        }
                    }
                    .buttonStyle(.plain)
                    Spacer()
                }
                .padding(.vertical, 8)
                .listRowBackground(Color.clear)
            }
            
            Section("datos_personales") {
                TextField("name_2", text: $displayName)
                    .textInputAutocapitalization(.words)
                    .disableAutocorrection(true)
                
                TextField("email", text: $email)
                    .keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .disableAutocorrection(true)
                
                Picker("sexo", selection: $sex) {
                    Text("masculino").tag(UserProfile.Sex.male)
                    Text("femenino").tag(UserProfile.Sex.female)
                    Text("otro").tag(UserProfile.Sex.other)
                }
                
                DatePicker("birthdate", selection: $dateOfBirth, displayedComponents: [.date])
            }
            
            Section("training_settings") {
                Picker("main_objective", selection: $mainGoal) {
                    Text("gain_muscle").tag(UserProfile.MainGoal.buildMuscle)
                    Text("perder_grasa").tag(UserProfile.MainGoal.loseFat)
                    Text("more_strength").tag(UserProfile.MainGoal.getStronger)
                    Text("mantener_actividad").tag(UserProfile.MainGoal.stayActive)
                }
                
                Picker("experiencia", selection: $experience) {
                    Text("principiante").tag(UserProfile.Experience.beginner)
                    Text("intermedio").tag(UserProfile.Experience.intermediate)
                    Text("avanzado").tag(UserProfile.Experience.advanced)
                }
                
                Picker("location_2", selection: $trainingLocation) {
                    Text("gym_2").tag(UserProfile.TrainingLocation.gym)
                    Text("casa_2").tag(UserProfile.TrainingLocation.home)
                    Text("mixto_2").tag(UserProfile.TrainingLocation.both)
                }
                
                Stepper("Entrenamientos: \(weeklyTrainingDays) días/semana", value: $weeklyTrainingDays, in: 1...7)
            }
            
            Section {
                Spacer()
                    .frame(height: 24)
                    .listRowBackground(Color.clear)
            }
        }
        .navigationTitle("profile_details")
        .navigationBarTitleDisplayMode(.inline)
        .mainTabBarHidden()
        .onAppear {
            displayName = store.userProfile.displayName ?? ""
            email = store.userProfile.email ?? ""
            sex = store.userProfile.sex ?? .male
            dateOfBirth = store.userProfile.dateOfBirth ?? Calendar.current.date(byAdding: .year, value: -30, to: .now) ?? .now
            mainGoal = store.userProfile.mainGoal
            experience = store.userProfile.experience
            weeklyTrainingDays = store.userProfile.weeklyTrainingDays
            trainingLocation = store.userProfile.trainingLocation
            avatarData = store.userProfile.avatarImageData
        }
        .onChange(of: avatarPickerItem) { _, item in
            Task {
                if let item,
                   let data = try? await item.loadTransferable(type: Data.self),
                   let image = UIImage(data: data),
                   let compressed = image.jpegData(compressionQuality: 0.72) {
                    avatarData = compressed
                    store.updateAvatarImageData(compressed)
                }
            }
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("save") {
                    saveProfile()
                    dismiss()
                }
                .font(.headline.weight(.semibold))
                .foregroundStyle(PulseTheme.primary)
            }
        }
    }
    
    private func saveProfile() {
        store.userProfile.displayName = displayName.isEmpty ? nil : displayName
        store.userProfile.email = email.isEmpty ? nil : email
        store.userProfile.sex = sex
        store.userProfile.dateOfBirth = dateOfBirth
        store.userProfile.mainGoal = mainGoal
        store.userProfile.experience = experience
        store.userProfile.weeklyTrainingDays = weeklyTrainingDays
        store.userProfile.trainingLocation = trainingLocation
        store.userProfile.avatarImageData = avatarData
    }
}
