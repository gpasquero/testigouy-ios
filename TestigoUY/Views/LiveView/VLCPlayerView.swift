import SwiftUI
#if os(iOS)
import VLCKitSPM

struct VLCPlayerView: UIViewRepresentable {
    let engine: VLCStreamEngine

    class Coordinator {
        var isAttached = false
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.backgroundColor = .black
        view.clipsToBounds = true
        view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.contentMode = .scaleAspectFit
        Log.stream.debug("[VLCPlayerView] makeUIView frame: \(view.frame.debugDescription, privacy: .public)")
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        if !context.coordinator.isAttached {
            Log.stream.debug("[VLCPlayerView] Attaching drawable, frame: \(uiView.frame.debugDescription, privacy: .public)")
            engine.attach(to: uiView)
            context.coordinator.isAttached = true
        }
    }
}
#else
struct VLCPlayerView: View {
    let engine: VLCStreamEngine

    var body: some View {
        Color.black
            .overlay {
                Text("VLC Player (iOS only)")
                    .foregroundColor(.gray)
            }
    }
}
#endif
