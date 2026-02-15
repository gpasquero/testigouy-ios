import SwiftUI

struct PTZControlView: View {
    @StateObject private var viewModel: PTZControlViewModel

    init(camera: Camera) {
        _viewModel = StateObject(wrappedValue: PTZControlViewModel(camera: camera))
    }

    var body: some View {
        VStack(spacing: 16) {
            // D-Pad
            dPad

            // Zoom controls
            HStack(spacing: 20) {
                Button(action: {}) {
                    Image(systemName: "minus.magnifyingglass")
                        .font(.title3)
                        .foregroundColor(.white)
                }
                .simultaneousGesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { _ in viewModel.zoomOut() }
                        .onEnded { _ in viewModel.stopMovement() }
                )

                Text("Zoom")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.7))

                Button(action: {}) {
                    Image(systemName: "plus.magnifyingglass")
                        .font(.title3)
                        .foregroundColor(.white)
                }
                .simultaneousGesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { _ in viewModel.zoomIn() }
                        .onEnded { _ in viewModel.stopMovement() }
                )
            }

            if let error = viewModel.errorMessage {
                Text(error)
                    .font(.caption2)
                    .foregroundColor(.red)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
        )
    }

    private var dPad: some View {
        ZStack {
            Circle()
                .fill(Color.white.opacity(0.1))
                .frame(width: 150, height: 150)

            // Proportional drag gesture
            Circle()
                .fill(Color.clear)
                .frame(width: 150, height: 150)
                .contentShape(Circle())
                .gesture(
                    DragGesture(minimumDistance: 5)
                        .onChanged { value in
                            let centerX: CGFloat = 75
                            let centerY: CGFloat = 75
                            let dx = Float((value.location.x - centerX) / centerX)
                            let dy = Float(-(value.location.y - centerY) / centerY)
                            viewModel.move(panSpeed: dx, tiltSpeed: dy)
                        }
                        .onEnded { _ in
                            viewModel.stopMovement()
                        }
                )

            // Direction arrows
            VStack {
                arrowButton(systemName: "chevron.up")
                Spacer()
                arrowButton(systemName: "chevron.down")
            }
            .frame(height: 130)

            HStack {
                arrowButton(systemName: "chevron.left")
                Spacer()
                arrowButton(systemName: "chevron.right")
            }
            .frame(width: 130)

            // Center dot
            Circle()
                .fill(Color.white.opacity(0.3))
                .frame(width: 20, height: 20)
        }
    }

    private func arrowButton(systemName: String) -> some View {
        Image(systemName: systemName)
            .font(.caption)
            .foregroundColor(.white.opacity(0.5))
    }
}
