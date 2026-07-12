import AVFoundation
import Combine
import CoreImage
import CoreMotion
import WebKit
import CoreLocation
import MapKit
import MediaPlayer
import MuscleMap
import MusicKit
import PhotosUI
import SwiftUI

struct SwipeToDeleteView<Content: View>: View {
    let onDelete: () -> Void
    let content: Content

    @State private var offset: CGFloat = 0
    @State private var isPresented = false
    @State private var showDeleteButton = false

    init(onDelete: @escaping () -> Void, @ViewBuilder content: () -> Content) {
        self.onDelete = onDelete
        self.content = content()
    }

    var body: some View {
        ZStack(alignment: .trailing) {
            // Delete button in background
            Button(role: .destructive) {
                HapticService.notification(.warning)
                isPresented = true
            } label: {
                ZStack {
                    Color.red
                    Image(systemName: "trash.fill")
                        .font(.title3)
                        .foregroundStyle(.white)
                }
                .frame(width: 60)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
            .opacity(offset < 0 ? 1 : 0)

            // Content in front
            content
                .background(PulseTheme.card)
                .offset(x: offset)
                .gesture(
                    DragGesture(minimumDistance: 15)
                        .onChanged { gesture in
                            let translation = gesture.translation.width
                            if translation < 0 {
                                offset = translation
                            }
                        }
                        .onEnded { gesture in
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                if gesture.translation.width < -50 {
                                    offset = -70
                                    showDeleteButton = true
                                } else {
                                    offset = 0
                                    showDeleteButton = false
                                }
                            }
                        }
                )
                .onTapGesture {
                    if showDeleteButton {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            offset = 0
                            showDeleteButton = false
                        }
                    }
                }
        }
        .alert(localizedString("delete_set_title"), isPresented: $isPresented) {
            Button(localizedString("cancel"), role: .cancel) {
                withAnimation(.spring()) {
                    offset = 0
                    showDeleteButton = false
                }
            }
            Button(localizedString("delete"), role: .destructive) {
                onDelete()
                withAnimation(.spring()) {
                    offset = 0
                    showDeleteButton = false
                }
            }
        } message: {
            Text("delete_set_message")
        }
    }
}

struct ActiveSetRowsList: View {
    let sets: [SetLog]
    let trackingType: Exercise.TrackingType
    let isSessionStarted: Bool
    let setBinding: (SetLog.ID) -> Binding<SetLog>
    let onCompletionChanged: (SetLog.ID, Bool) -> Void
    let onDeleteSet: (SetLog.ID) -> Void

    var body: some View {
        ForEach(sets) { set in
            SwipeToDeleteView(onDelete: {
                onDeleteSet(set.id)
            }) {
                SetRow(set: setBinding(set.id), trackingType: trackingType) { completed in
                    onCompletionChanged(set.id, completed)
                }
            }
            .disabled(!isSessionStarted)
        }
    }
}


struct ActiveAdvancedSetFieldsList: View {
    let sets: [SetLog]
    let showSetType: Bool
    let showRPE: Bool
    let showRIR: Bool
    let showTempo: Bool
    let setBinding: (SetLog.ID) -> Binding<SetLog>

    var body: some View {
        VStack(spacing: 10) {
            ForEach(sets) { set in
                AdvancedSetFields(
                    set: setBinding(set.id),
                    showSetType: showSetType,
                    showRPE: showRPE,
                    showRIR: showRIR,
                    showTempo: showTempo
                )
            }
        }
        .padding(.top, 8)
    }
}
