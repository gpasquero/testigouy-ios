import Foundation
import SwiftUI

@MainActor
final class CameraListViewModel: ObservableObject {
    @Published var cameras: [Camera] = []
    @Published var showingAddCamera = false
    @Published var editingCamera: Camera?

    private let persistence = PersistenceController.shared

    func loadCameras() {
        cameras = persistence.fetchCameras()
    }

    func saveCamera(_ camera: Camera) {
        persistence.saveCamera(camera)
        loadCameras()
    }

    func deleteCamera(_ camera: Camera) {
        persistence.deleteCamera(id: camera.id)
        loadCameras()
    }

    func deleteCameras(at offsets: IndexSet) {
        for index in offsets {
            persistence.deleteCamera(id: cameras[index].id)
        }
        loadCameras()
    }

    func toggleCamera(_ camera: Camera) {
        var updated = camera
        updated.isEnabled.toggle()
        persistence.saveCamera(updated)
        loadCameras()
    }
}
