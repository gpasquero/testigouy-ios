import Foundation
import SwiftUI

@MainActor
final class LiveStreamViewModel: ObservableObject {
    @Published var streamState: StreamState = .idle
    @Published var isRecording = false
    @Published var recordingDuration: TimeInterval = 0
    @Published var snapshotSaved = false

    let camera: Camera
    let streamEngine = VLCStreamEngine()
    let recorder = StreamRecorder()

    private var currentRecording: Recording?

    init(camera: Camera) {
        self.camera = camera
    }

    func startStream() {
        guard let url = camera.rtspURL else {
            streamState = .error("Invalid RTSP URL")
            return
        }
        streamEngine.play(url: url)
    }

    func stopStream() {
        if isRecording {
            stopRecording()
        }
        streamEngine.stop()
    }

    func startRecording() {
        guard let url = camera.rtspURL else { return }
        currentRecording = recorder.startRecording(url: url, cameraId: camera.id, cameraName: camera.name)
        isRecording = true

        // Observe recording duration
        Task {
            while recorder.isRecording {
                recordingDuration = recorder.recordingDuration
                try? await Task.sleep(nanoseconds: 500_000_000)
            }
        }
    }

    func stopRecording() {
        guard var recording = currentRecording,
              let result = recorder.stopRecording() else { return }

        recording.endDate = result.endDate
        recording.fileSize = result.fileSize

        PersistenceController.shared.saveRecording(recording)

        isRecording = false
        recordingDuration = 0
        currentRecording = nil
    }

    func takeSnapshot() {
        streamEngine.takeSnapshot()
        snapshotSaved = true
        Task {
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            snapshotSaved = false
        }
    }

    var formattedDuration: String {
        let minutes = Int(recordingDuration) / 60
        let seconds = Int(recordingDuration) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}
