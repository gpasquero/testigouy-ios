import Foundation
import os
#if os(iOS)
import ffmpegkit
#endif

final class StreamRecorder: ObservableObject {
    @Published var isRecording = false
    @Published var recordingDuration: TimeInterval = 0

    #if os(iOS)
    private var session: FFmpegSession?
    #endif
    private var outputPath: String?
    private var startTime: Date?
    private var timer: Timer?
    private var currentRecordingId: UUID?

    var currentOutputPath: String? { outputPath }

    func startRecording(url: URL, cameraId: UUID, cameraName: String) -> Recording? {
        guard !isRecording else {
            Log.recording.warning("[Recorder] Already recording, ignoring start request")
            return nil
        }

        let documentsDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let recordingsDir = documentsDir.appendingPathComponent("Recordings", isDirectory: true)
        try? FileManager.default.createDirectory(at: recordingsDir, withIntermediateDirectories: true)

        let fileName = "\(cameraName)_\(Self.dateFormatter.string(from: Date())).mp4"
        let sanitizedFileName = fileName.replacingOccurrences(of: " ", with: "_")
        let filePath = recordingsDir.appendingPathComponent(sanitizedFileName).path

        Log.recording.info("[Recorder] Starting recording for '\(cameraName, privacy: .public)'")
        Log.recording.debug("[Recorder] RTSP URL: \(url.absoluteString, privacy: .public)")
        Log.recording.debug("[Recorder] Output: \(sanitizedFileName, privacy: .public)")

        let recordingId = UUID()
        currentRecordingId = recordingId
        outputPath = filePath
        startTime = Date()

        #if os(iOS)
        let command = "-rtsp_transport tcp -i \(url.absoluteString) -c:v copy -c:a copy -movflags +faststart -y \(filePath)"
        Log.recording.debug("[Recorder] FFmpeg command: \(command, privacy: .public)")
        session = FFmpegKit.executeAsync(command) { [weak self] session in
            DispatchQueue.main.async {
                self?.handleSessionComplete(session)
            }
        }
        #endif

        isRecording = true
        recordingDuration = 0
        startDurationTimer()

        return Recording(
            id: recordingId,
            cameraId: cameraId,
            cameraName: cameraName,
            filePath: filePath,
            startDate: Date()
        )
    }

    func stopRecording() -> (endDate: Date, fileSize: Int64)? {
        guard isRecording else { return nil }

        Log.recording.info("[Recorder] Stopping recording...")
        timer?.invalidate()
        timer = nil

        #if os(iOS)
        session?.cancel()
        session = nil
        #endif

        isRecording = false
        let endDate = Date()

        var fileSize: Int64 = 0
        if let path = outputPath,
           let attrs = try? FileManager.default.attributesOfItem(atPath: path) {
            fileSize = attrs[.size] as? Int64 ?? 0
        }

        let duration = startTime.map { endDate.timeIntervalSince($0) } ?? 0
        Log.recording.info("[Recorder] Recording stopped. Duration: \(Int(duration))s, Size: \(fileSize) bytes")

        outputPath = nil
        startTime = nil
        currentRecordingId = nil

        return (endDate, fileSize)
    }

    private func startDurationTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self, let startTime = self.startTime else { return }
            DispatchQueue.main.async {
                self.recordingDuration = Date().timeIntervalSince(startTime)
            }
        }
    }

    #if os(iOS)
    private func handleSessionComplete(_ session: FFmpegSession?) {
        guard let session else { return }
        let returnCode = session.getReturnCode()
        if ReturnCode.isSuccess(returnCode) {
            Log.recording.info("[Recorder] FFmpeg session completed successfully")
        } else if ReturnCode.isCancel(returnCode) {
            Log.recording.debug("[Recorder] FFmpeg session cancelled (user stopped recording)")
        } else {
            Log.recording.error("[Recorder] FFmpeg recording failed: \(session.getOutput() ?? "unknown error", privacy: .public)")
        }
    }
    #endif

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd_HHmmss"
        return formatter
    }()
}
