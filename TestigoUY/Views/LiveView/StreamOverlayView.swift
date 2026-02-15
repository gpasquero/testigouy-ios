import SwiftUI

struct StreamOverlayView: View {
    @ObservedObject var viewModel: LiveStreamViewModel
    @Binding var showPTZ: Bool
    let onDismiss: () -> Void

    var body: some View {
        VStack {
            // Top bar
            HStack {
                Button(action: onDismiss) {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                            .font(.title3)
                            .fontWeight(.semibold)
                        Text("Back")
                            .font(.body)
                            .fontWeight(.medium)
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Capsule().fill(.black.opacity(0.4)))
                }

                Spacer()

                Text(viewModel.camera.name)
                    .font(.headline)
                    .foregroundColor(.white)

                Spacer()

                statusIndicator
            }
            .padding()
            .background(
                LinearGradient(colors: [.black.opacity(0.6), .clear], startPoint: .top, endPoint: .bottom)
            )

            Spacer()

            // Bottom controls
            HStack(spacing: 30) {
                // Mute button
                Button(action: { viewModel.toggleMute() }) {
                    VStack(spacing: 4) {
                        Image(systemName: viewModel.isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill")
                            .font(.title2)
                        Text(viewModel.isMuted ? "Unmute" : "Mute")
                            .font(.caption2)
                    }
                    .foregroundColor(viewModel.isMuted ? Color("AccentColor") : .white)
                }

                // Snapshot button
                Button(action: { viewModel.takeSnapshot() }) {
                    VStack(spacing: 4) {
                        Image(systemName: "camera.fill")
                            .font(.title2)
                        Text("Snap")
                            .font(.caption2)
                    }
                    .foregroundColor(.white)
                }

                // Record button
                Button(action: {
                    if viewModel.isRecording {
                        viewModel.stopRecording()
                    } else {
                        viewModel.startRecording()
                    }
                }) {
                    VStack(spacing: 4) {
                        ZStack {
                            Circle()
                                .strokeBorder(.white, lineWidth: 2)
                                .frame(width: 50, height: 50)

                            if viewModel.isRecording {
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(.red)
                                    .frame(width: 20, height: 20)
                            } else {
                                Circle()
                                    .fill(.red)
                                    .frame(width: 40, height: 40)
                            }
                        }

                        if viewModel.isRecording {
                            Text(viewModel.formattedDuration)
                                .font(.caption2)
                                .foregroundColor(.red)
                                .monospacedDigit()
                        } else {
                            Text("Record")
                                .font(.caption2)
                                .foregroundColor(.white)
                        }
                    }
                }

                // PTZ button
                if viewModel.camera.ptzCapability.supportsPTZ {
                    Button(action: { showPTZ.toggle() }) {
                        VStack(spacing: 4) {
                            Image(systemName: "arrow.up.and.down.and.arrow.left.and.right")
                                .font(.title2)
                            Text("PTZ")
                                .font(.caption2)
                        }
                        .foregroundColor(showPTZ ? Color("AccentColor") : .white)
                    }
                }
            }
            .padding(.vertical, 20)
            .frame(maxWidth: .infinity)
            .background(
                LinearGradient(colors: [.clear, .black.opacity(0.6)], startPoint: .top, endPoint: .bottom)
            )
        }
    }

    @ViewBuilder
    private var statusIndicator: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(statusColor)
                .frame(width: 8, height: 8)
            Text(viewModel.streamState.statusText)
                .font(.caption)
                .foregroundColor(.white)
        }
    }

    private var statusColor: Color {
        switch viewModel.streamState {
        case .playing: return .green
        case .connecting: return .yellow
        case .buffering: return .orange
        case .recording: return .red
        case .error: return .red
        case .idle: return .gray
        }
    }
}
