import SwiftUI
import PhotosUI

struct ProfileDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var store: AppStore
    
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
                                    .overlay(Circle().stroke(PulseTheme.separator, lineWidth: 2))
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
            
            Section("Datos personales") {
                TextField("Nombre", text: $displayName)
                    .textInputAutocapitalization(.words)
                    .disableAutocorrection(true)
                
                TextField("Email", text: $email)
                    .keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .disableAutocorrection(true)
                
                Picker("Sexo", selection: $sex) {
                    Text("Masculino").tag(UserProfile.Sex.male)
                    Text("Femenino").tag(UserProfile.Sex.female)
                    Text("Otro").tag(UserProfile.Sex.other)
                }
                
                DatePicker("Fecha de nacimiento", selection: $dateOfBirth, displayedComponents: [.date])
            }
            
            Section("Ajustes de entrenamiento") {
                Picker("Objetivo principal", selection: $mainGoal) {
                    Text("Ganar músculo").tag(UserProfile.MainGoal.buildMuscle)
                    Text("Perder grasa").tag(UserProfile.MainGoal.loseFat)
                    Text("Más fuerza").tag(UserProfile.MainGoal.getStronger)
                    Text("Mantener actividad").tag(UserProfile.MainGoal.stayActive)
                }
                
                Picker("Experiencia", selection: $experience) {
                    Text("Principiante").tag(UserProfile.Experience.beginner)
                    Text("Intermedio").tag(UserProfile.Experience.intermediate)
                    Text("Avanzado").tag(UserProfile.Experience.advanced)
                }
                
                Picker("Ubicación", selection: $trainingLocation) {
                    Text("Gimnasio").tag(UserProfile.TrainingLocation.gym)
                    Text("Casa").tag(UserProfile.TrainingLocation.home)
                    Text("Mixto").tag(UserProfile.TrainingLocation.both)
                }
                
                Stepper("Entrenamientos: \(weeklyTrainingDays) días/semana", value: $weeklyTrainingDays, in: 1...7)
            }
            
            Section {
                Spacer()
                    .frame(height: 24)
                    .listRowBackground(Color.clear)
            }
        }
        .navigationTitle("Detalles del Perfil")
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
                Button("Guardar") {
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
