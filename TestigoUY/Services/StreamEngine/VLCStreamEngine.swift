import Foundation
#if os(iOS)
import VLCKitSPM
import UIKit
#endif

@MainActor
final class VLCStreamEngine: NSObject, ObservableObject {
    @Published var state: StreamState = .idle

    #if os(iOS)
    @Published var snapshot: UIImage?
    private var mediaPlayer: VLCMediaPlayer?
    private var drawable: UIView?

    var isPlaying: Bool {
        mediaPlayer?.isPlaying ?? false
    }

    func attach(to view: UIView) {
        drawable = view
        mediaPlayer?.drawable = view
    }

    func play(url: URL) {
        stop()

        let media = VLCMedia(url: url)
        media.addOptions([
            "network-caching": 300,
            "rtsp-tcp": true,
            "avcodec-hw": "any",
            "no-audio": true,
            "drop-late-frames": true,
            "skip-frames": true,
            "clock-jitter": 0,
            "file-caching": 0,
            "live-caching": 300
        ])

        let player = VLCMediaPlayer()
        player.media = media
        player.delegate = self
        player.drawable = drawable
        self.mediaPlayer = player

        state = .connecting
        player.play()
    }

    func stop() {
        mediaPlayer?.stop()
        mediaPlayer?.delegate = nil
        mediaPlayer = nil
        state = .idle
    }

    func takeSnapshot() {
        guard let player = mediaPlayer, player.isPlaying else { return }

        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let snapshotPath = documentsPath.appendingPathComponent("snapshot_\(UUID().uuidString).png")

        let size = player.videoSize
        let width = size.width > 0 ? Int(size.width) : 1920
        let height = size.height > 0 ? Int(size.height) : 1080

        player.saveVideoSnapshot(at: snapshotPath.path, withWidth: Int32(width), andHeight: Int32(height))

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            if let data = try? Data(contentsOf: snapshotPath),
               let image = UIImage(data: data) {
                self?.snapshot = image
                UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil)
            }
            try? FileManager.default.removeItem(at: snapshotPath)
        }
    }
    #else
    var isPlaying: Bool { false }
    func play(url: URL) { state = .error("Not supported on macOS") }
    func stop() { state = .idle }
    func takeSnapshot() { }
    #endif
}

#if os(iOS)
extension VLCStreamEngine: VLCMediaPlayerDelegate {
    nonisolated func mediaPlayerStateChanged(_ aNotification: Notification) {
        Task { @MainActor in
            guard let player = mediaPlayer else { return }
            switch player.state {
            case .opening, .buffering:
                state = .connecting
            case .playing:
                state = .playing
            case .error:
                state = .error("Playback error")
            case .stopped, .ended:
                state = .idle
            default:
                break
            }
        }
    }
}
#endif
