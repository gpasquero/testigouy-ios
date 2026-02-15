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
    @Published var isMuted: Bool = false
    private var mediaPlayer: VLCMediaPlayer?
    private var drawable: UIView?

    var isPlaying: Bool {
        mediaPlayer?.isPlaying ?? false
    }

    func toggleMute() {
        guard let player = mediaPlayer else { return }
        if isMuted {
            player.audio?.volume = 100
            isMuted = false
            NSLog("[VLC] Audio unmuted")
        } else {
            player.audio?.volume = 0
            isMuted = true
            NSLog("[VLC] Audio muted")
        }
    }

    private var pendingURL: URL?
    private var connectionTimer: Task<Void, Never>?

    func attach(to view: UIView) {
        NSLog("[VLC] attach() drawable frame: %@", view.frame.debugDescription)
        drawable = view
        mediaPlayer?.drawable = view

        // If play was called before attach, start now
        if let url = pendingURL {
            NSLog("[VLC] Drawable ready, starting deferred playback")
            pendingURL = nil
            startPlayback(url: url)
        }
    }

    func play(url: URL) {
        stop()
        if drawable == nil {
            NSLog("[VLC] No drawable yet, deferring playback for: %@", url.absoluteString)
            pendingURL = url
            state = .connecting
            return
        }
        startPlayback(url: url)
    }

    private func startPlayback(url: URL) {
        NSLog("[VLC] Connecting to: %@", url.absoluteString)

        // Keep credentials in URL for VLC's internal auth handling
        let media = VLCMedia(url: url)
        // VLCKit media options use ":" prefix (not "--")
        // Force RTSP over TCP — required on iOS because live555
        // can't determine local IP for UDP RTP sockets
        media.addOption(":rtsp-tcp")
        media.addOption(":network-caching=1500")
        media.addOption(":live-caching=1500")
        media.addOption(":rtsp-frame-buffer-size=500000")

        NSLog("[VLC] Options: rtsp-tcp, caching=1500, frame-buffer=500000")

        let player = VLCMediaPlayer()
        player.media = media
        player.delegate = self
        player.drawable = drawable
        // Enable VLC verbose logging
        player.libraryInstance.debugLogging = true
        player.libraryInstance.debugLoggingLevel = 3
        self.mediaPlayer = player

        NSLog("[VLC] Drawable: %@, frame: %@", drawable == nil ? "nil" : "set", drawable?.frame.debugDescription ?? "nil")
        state = .connecting
        NSLog("[VLC] Calling player.play()...")
        player.play()
        NSLog("[VLC] player.play() returned, isPlaying=%d", player.isPlaying ? 1 : 0)

        // Start connection timeout
        connectionTimer?.cancel()
        connectionTimer = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 30_000_000_000) // 30 seconds
            guard !Task.isCancelled else { return }
            guard let self, self.state == .connecting else { return }
            NSLog("[VLC] Connection timeout after 30s — check credentials or network")
            self.state = .error("Connection timeout — check credentials")
            self.mediaPlayer?.stop()
            self.mediaPlayer?.delegate = nil
            self.mediaPlayer = nil
        }
    }

    func stop() {
        connectionTimer?.cancel()
        connectionTimer = nil
        guard mediaPlayer != nil else { return }
        NSLog("[VLC] Stopping playback")
        mediaPlayer?.stop()
        mediaPlayer?.delegate = nil
        mediaPlayer = nil
        state = .idle
    }

    func takeSnapshot() {
        guard let player = mediaPlayer, player.isPlaying else {
            Log.stream.warning("[VLC] Snapshot failed: player not playing")
            return
        }

        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let snapshotPath = documentsPath.appendingPathComponent("snapshot_\(UUID().uuidString).png")

        let size = player.videoSize
        let width = size.width > 0 ? Int(size.width) : 1920
        let height = size.height > 0 ? Int(size.height) : 1080
        Log.stream.info("[VLC] Taking snapshot \(width)x\(height) → \(snapshotPath.lastPathComponent)")

        player.saveVideoSnapshot(at: snapshotPath.path, withWidth: Int32(width), andHeight: Int32(height))

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            if let data = try? Data(contentsOf: snapshotPath),
               let image = UIImage(data: data) {
                self?.snapshot = image
                UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil)
                Log.stream.info("[VLC] Snapshot saved to Photos")
            } else {
                Log.stream.error("[VLC] Snapshot file not found or invalid")
            }
            try? FileManager.default.removeItem(at: snapshotPath)
        }
    }
    #else
    var isPlaying: Bool { false }
    var isMuted: Bool = false
    func play(url: URL) {
        Log.stream.error("[VLC] Not supported on macOS")
        state = .error("Not supported on macOS")
    }
    func stop() { state = .idle }
    func takeSnapshot() { }
    func toggleMute() { }
    #endif
}

#if os(iOS)
extension VLCStreamEngine: VLCMediaPlayerDelegate {
    nonisolated func mediaPlayerBuffering(_ newCache: Float) {
        Task { @MainActor in
            let pct = Int(newCache)
            // Only update to buffering if we haven't reached playing yet
            guard state != .playing && state != .recording else { return }
            if pct < 100 {
                state = .buffering(pct)
            }
        }
    }

    nonisolated func mediaPlayerStateChanged(_ aNotification: Notification) {
        Task { @MainActor in
            guard let player = mediaPlayer else {
                NSLog("[VLC] State changed but mediaPlayer is nil!")
                return
            }
            let rawState = player.state.rawValue
            NSLog("[VLC] State changed → rawValue=%d, isPlaying=%d, videoSize=%@",
                  rawState, player.isPlaying ? 1 : 0,
                  NSCoder.string(for: player.videoSize))
            switch player.state {
            case .opening:
                NSLog("[VLC] State → Opening")
                state = .connecting
            case .buffering:
                NSLog("[VLC] State → Buffering")
                // Don't override playing/recording state with buffering
                if state != .playing && state != .recording {
                    if case .buffering = state {
                        // keep existing percentage
                    } else {
                        state = .buffering(0)
                    }
                }
            case .playing:
                connectionTimer?.cancel()
                connectionTimer = nil
                NSLog("[VLC] State → Playing ✓ videoSize=%@", NSCoder.string(for: player.videoSize))
                state = .playing
            case .error:
                NSLog("[VLC] State → ERROR")
                state = .error("Playback error")
            case .stopped:
                NSLog("[VLC] State → Stopped")
                state = .idle
            case .ended:
                NSLog("[VLC] State → Ended")
                state = .idle
            default:
                NSLog("[VLC] State → Unknown (%d)", rawState)
            }
        }
    }
}
#endif
