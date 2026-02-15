import Foundation
import SwiftUI
import Combine
import os

@MainActor
final class LiveStreamViewModel: ObservableObject {
    @Published var streamState: StreamState = .idle
    @Published var isRecording = false
    @Published var recordingDuration: TimeInterval = 0
    @Published var snapshotSaved = false
    @Published var isMuted = false

    let camera: Camera
    let streamEngine = VLCStreamEngine()
    let recorder = StreamRecorder()

    private var currentRecording: Recording?
    private var stateSink: AnyCancellable?

    init(camera: Camera) {
        self.camera = camera
        Log.stream.debug("[LiveVM] Initialized for camera '\(camera.name, privacy: .public)' at \(camera.host, privacy: .public)")

        // Forward streamEngine state changes so SwiftUI re-renders
        stateSink = streamEngine.$state
            .receive(on: RunLoop.main)
            .sink { [weak self] newState in
                self?.streamState = newState
            }
    }

    func startStream() {
        guard let url = camera.rtspURL else {
            Log.stream.error("[LiveVM] Invalid RTSP URL for camera '\(self.camera.name, privacy: .public)'")
            streamState = .error("Invalid RTSP URL")
            return
        }
        Log.stream.info("[LiveVM] Starting stream for '\(self.camera.name, privacy: .public)' → \(url.absoluteString, privacy: .public)")
        streamEngine.play(url: url)
    }

    func stopStream() {
        Log.stream.info("[LiveVM] Stopping stream for '\(self.camera.name, privacy: .public)'")
        if isRecording {
            stopRecording()
        }
        streamEngine.stop()
    }

    func startRecording() {
        guard let url = camera.rtspURL else {
            Log.recording.error("[LiveVM] Cannot record: invalid RTSP URL")
            return
        }
        Log.recording.info("[LiveVM] Starting recording for '\(self.camera.name, privacy: .public)'")
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

        Log.recording.info("[LiveVM] Recording saved. Duration: \(Int(result.endDate.timeIntervalSince(recording.startDate)))s")
        PersistenceController.shared.saveRecording(recording)

        isRecording = false
        recordingDuration = 0
        currentRecording = nil
    }

    func toggleMute() {
        streamEngine.toggleMute()
        isMuted = streamEngine.isMuted
    }

    func takeSnapshot() {
        Log.stream.info("[LiveVM] Taking snapshot for '\(self.camera.name, privacy: .public)'")
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
