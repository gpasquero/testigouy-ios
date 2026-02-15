import SwiftUI

struct SingleCameraView: View {
    let camera: Camera
    @StateObject private var viewModel: LiveStreamViewModel
    @State private var showOverlay = true
    @State private var showPTZ = false
    @State private var overlayTimer: Task<Void, Never>?
    @Environment(\.dismiss) private var dismiss

    init(camera: Camera) {
        self.camera = camera
        _viewModel = StateObject(wrappedValue: LiveStreamViewModel(camera: camera))
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VLCPlayerView(engine: viewModel.streamEngine)
                .ignoresSafeArea()
                .onTapGesture {
                    withAnimation {
                        showOverlay.toggle()
                    }
                    resetOverlayTimer()
                }

            if showOverlay {
                StreamOverlayView(
                    viewModel: viewModel,
                    showPTZ: $showPTZ,
                    onDismiss: { dismiss() }
                )
                .transition(.opacity)
            }

            if showPTZ && camera.ptzCapability.supportsPTZ {
                PTZControlView(camera: camera)
                    .frame(width: 200, height: 200)
                    .transition(.scale)
            }

            if viewModel.snapshotSaved {
                snapshotBanner
            }
        }
        #if os(iOS)
        .toolbar(.hidden, for: .navigationBar)
        .statusBarHidden(true)
        #endif
        .onAppear {
            viewModel.startStream()
            resetOverlayTimer()
        }
        .onDisappear {
            viewModel.stopStream()
            overlayTimer?.cancel()
        }
    }

    private var snapshotBanner: some View {
        VStack {
            Spacer()
            Text("Snapshot saved to Photos")
                .font(.callout)
                .foregroundColor(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Capsule().fill(.black.opacity(0.7)))
                .padding(.bottom, 100)
        }
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }

    private func resetOverlayTimer() {
        overlayTimer?.cancel()
        overlayTimer = Task {
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            guard !Task.isCancelled else { return }
            withAnimation {
                showOverlay = false
            }
        }
    }
}
