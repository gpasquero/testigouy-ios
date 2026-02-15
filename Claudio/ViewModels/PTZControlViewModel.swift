import Foundation
import SwiftUI

@MainActor
final class PTZControlViewModel: ObservableObject {
    @Published var isMoving = false
    @Published var errorMessage: String?

    private var ptzService: ONVIFPTZService?
    private let camera: Camera

    init(camera: Camera) {
        self.camera = camera
        if camera.ptzCapability == .onvif {
            ptzService = ONVIFPTZService(
                host: camera.host,
                port: camera.onvifPort,
                username: camera.username,
                password: camera.password
            )
        }
    }

    var isPTZAvailable: Bool {
        camera.ptzCapability.supportsPTZ
    }

    // MARK: - Directional Movement

    func moveUp(speed: Float = 0.5) {
        continuousMove(pan: 0, tilt: speed, zoom: 0)
    }

    func moveDown(speed: Float = 0.5) {
        continuousMove(pan: 0, tilt: -speed, zoom: 0)
    }

    func moveLeft(speed: Float = 0.5) {
        continuousMove(pan: -speed, tilt: 0, zoom: 0)
    }

    func moveRight(speed: Float = 0.5) {
        continuousMove(pan: speed, tilt: 0, zoom: 0)
    }

    func zoomIn(speed: Float = 0.3) {
        continuousMove(pan: 0, tilt: 0, zoom: speed)
    }

    func zoomOut(speed: Float = 0.3) {
        continuousMove(pan: 0, tilt: 0, zoom: -speed)
    }

    /// Proportional move based on drag gesture offset
    func move(panSpeed: Float, tiltSpeed: Float) {
        let clampedPan = max(-1, min(1, panSpeed))
        let clampedTilt = max(-1, min(1, tiltSpeed))
        continuousMove(pan: clampedPan, tilt: clampedTilt, zoom: 0)
    }

    func stopMovement() {
        guard let service = ptzService else { return }
        isMoving = false
        Task {
            do {
                try await service.stop()
                errorMessage = nil
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    func gotoPreset(_ presetToken: String) {
        guard let service = ptzService else { return }
        Task {
            do {
                try await service.gotoPreset(presetToken: presetToken)
                errorMessage = nil
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    // MARK: - Private

    private func continuousMove(pan: Float, tilt: Float, zoom: Float) {
        guard let service = ptzService else { return }
        isMoving = true
        Task {
            do {
                try await service.continuousMove(pan: pan, tilt: tilt, zoom: zoom)
                errorMessage = nil
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
}
