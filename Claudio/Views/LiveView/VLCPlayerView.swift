import SwiftUI
#if os(iOS)
import VLCKitSPM

struct VLCPlayerView: UIViewRepresentable {
    let engine: VLCStreamEngine

    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.backgroundColor = .black
        view.clipsToBounds = true
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        engine.attach(to: uiView)
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
