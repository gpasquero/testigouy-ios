import SwiftUI

struct CameraRowView: View {
    let camera: Camera

    var body: some View {
        HStack(spacing: 12) {
            // Thumbnail placeholder
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.gray.opacity(0.15))
                .frame(width: 80, height: 50)
                .overlay {
                    Image(systemName: "video.fill")
                        .foregroundColor(.secondary)
                }

            VStack(alignment: .leading, spacing: 4) {
                Text(camera.name)
                    .font(.headline)

                Text("\(camera.host):\(camera.rtspPort)")
                    .font(.caption)
                    .foregroundColor(.secondary)

                HStack(spacing: 8) {
                    if camera.ptzCapability.supportsPTZ {
                        Label("PTZ", systemImage: "arrow.up.and.down.and.arrow.left.and.right")
                            .font(.caption2)
                            .foregroundColor(.blue)
                    }

                    Text(camera.streamProfile.displayName)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            Circle()
                .fill(camera.isEnabled ? .green : .gray)
                .frame(width: 10, height: 10)
        }
        .padding(.vertical, 4)
    }
}
