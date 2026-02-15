import SwiftUI

struct GridCellView: View {
    let camera: Camera
    let engine: VLCStreamEngine?

    var body: some View {
        ZStack {
            Color.black

            if let engine {
                VLCPlayerView(engine: engine)

                VStack {
                    Spacer()
                    HStack {
                        Text(camera.name)
                            .font(.caption2)
                            .foregroundColor(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.black.opacity(0.5))
                            .cornerRadius(4)

                        Spacer()

                        Circle()
                            .fill(statusColor(for: engine.state))
                            .frame(width: 6, height: 6)
                            .padding(.trailing, 4)
                    }
                    .padding(4)
                }
            } else {
                VStack(spacing: 8) {
                    ProgressView()
                        .tint(.white)
                    Text(camera.name)
                        .font(.caption2)
                        .foregroundColor(.white)
                }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 4))
    }

    private func statusColor(for state: StreamState) -> Color {
        switch state {
        case .playing: return .green
        case .connecting: return .yellow
        case .error: return .red
        default: return .gray
        }
    }
}
