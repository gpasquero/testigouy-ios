import SwiftUI
import AVKit

struct RecordingPlayerView: View {
    let recording: Recording
    @State private var player: AVPlayer?

    var body: some View {
        VStack {
            if let player {
                VideoPlayer(player: player)
                    .ignoresSafeArea(edges: .horizontal)
            } else {
                VStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.largeTitle)
                        .foregroundColor(.secondary)
                    Text("File not found")
                        .foregroundColor(.secondary)
                }
            }
        }
        .navigationTitle(recording.cameraName)
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .onAppear {
            let url = recording.fileURL
            if FileManager.default.fileExists(atPath: url.path) {
                player = AVPlayer(url: url)
                player?.play()
            }
        }
        .onDisappear {
            player?.pause()
            player = nil
        }
    }
}
