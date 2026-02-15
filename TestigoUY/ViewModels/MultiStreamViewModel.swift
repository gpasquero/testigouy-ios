import Foundation
import SwiftUI

@MainActor
final class MultiStreamViewModel: ObservableObject {
    @Published var layout: GridLayout = .twoByTwo
    @Published var cameras: [Camera] = []
    @Published var engines: [UUID: VLCStreamEngine] = [:]

    private let persistence = PersistenceController.shared

    func loadCameras() {
        cameras = persistence.fetchCameras().filter { $0.isEnabled }
    }

    func startStreams() {
        let visibleCameras = Array(cameras.prefix(layout.maxCameras))
        for camera in visibleCameras {
            if engines[camera.id] == nil {
                let engine = VLCStreamEngine()
                engines[camera.id] = engine
                if let url = camera.rtspURL {
                    engine.play(url: url)
                }
            }
        }
    }

    func stopAllStreams() {
        for (_, engine) in engines {
            engine.stop()
        }
        engines.removeAll()
    }

    func stopStream(for cameraId: UUID) {
        engines[cameraId]?.stop()
        engines.removeValue(forKey: cameraId)
    }

    func restartStream(for camera: Camera) {
        stopStream(for: camera.id)
        let engine = VLCStreamEngine()
        engines[camera.id] = engine
        if let url = camera.rtspURL {
            engine.play(url: url)
        }
    }

    func updateLayout(_ newLayout: GridLayout) {
        let oldMax = layout.maxCameras
        layout = newLayout

        if newLayout.maxCameras < oldMax {
            // Stop streams beyond new limit
            let visibleIds = Set(cameras.prefix(newLayout.maxCameras).map(\.id))
            for (id, engine) in engines where !visibleIds.contains(id) {
                engine.stop()
                engines.removeValue(forKey: id)
            }
        } else {
            startStreams()
        }
    }

    var visibleCameras: [Camera] {
        Array(cameras.prefix(layout.maxCameras))
    }
}
