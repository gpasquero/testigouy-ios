import SwiftUI

struct CameraDiscoveryView: View {
    @StateObject private var scanner = NetworkScanner()
    @Environment(\.dismiss) private var dismiss
    let onCameraSelected: (Camera) -> Void

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Status header
                statusHeader

                if scanner.discoveredHosts.isEmpty && !scanner.isScanning {
                    emptyState
                } else {
                    cameraList
                }
            }
            .navigationTitle("Discover Cameras")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    if scanner.isScanning {
                        Button("Stop") { scanner.stopScan() }
                            .foregroundStyle(.red)
                    } else {
                        Button("Scan") { scanner.startScan() }
                    }
                }
            }
            .onAppear {
                scanner.startScan()
            }
            .onDisappear {
                scanner.stopScan()
            }
        }
    }

    // MARK: - Subviews

    private var statusHeader: some View {
        VStack(spacing: 8) {
            if scanner.isScanning {
                ProgressView(value: scanner.progress)
                    .tint(Color("AccentColor"))
                    .padding(.horizontal)
            }

            Text(scanner.statusMessage)
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.bottom, 8)
        }
        .padding(.top, 8)
        .background(Color("BrandBackground"))
    }

    private var emptyState: some View {
        VStack(spacing: 20) {
            Spacer()

            Image(systemName: "wifi.exclamationmark")
                .font(.system(size: 50))
                .foregroundStyle(Color("AccentColor"))

            Text("No Cameras Found")
                .font(.title3)
                .fontWeight(.semibold)

            VStack(spacing: 8) {
                Text("Make sure your cameras are:")
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                VStack(alignment: .leading, spacing: 4) {
                    Label("Connected to the same WiFi network", systemImage: "wifi")
                    Label("Powered on and online", systemImage: "bolt.fill")
                    Label("Accessible on port 554 (RTSP)", systemImage: "network")
                }
                .font(.caption)
                .foregroundColor(.secondary)
            }

            Button(action: { scanner.startScan() }) {
                Label("Scan Again", systemImage: "arrow.clockwise")
                    .fontWeight(.medium)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 10)
                    .background(Color("AccentColor"))
                    .foregroundColor(.black)
                    .cornerRadius(10)
            }

            Spacer()
        }
        .padding()
    }

    private var cameraList: some View {
        List {
            Section {
                ForEach(scanner.discoveredHosts) { camera in
                    Button(action: { selectCamera(camera) }) {
                        discoveredRow(camera)
                    }
                }
            } header: {
                Text("Found \(scanner.discoveredHosts.count) device(s)")
            } footer: {
                Text("Tap a camera to add it to your list")
            }
        }
    }

    private func discoveredRow(_ camera: NetworkScanner.DiscoveredCamera) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "video.fill")
                .font(.title3)
                .foregroundStyle(Color("AccentColor"))
                .frame(width: 40)

            VStack(alignment: .leading, spacing: 2) {
                Text(camera.displayName)
                    .font(.headline)
                    .foregroundColor(.primary)

                Text("\(camera.host):\(camera.port)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            Text(camera.source.rawValue)
                .font(.caption2)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(
                    Capsule().fill(
                        camera.source == .onvif
                            ? Color("AccentColor").opacity(0.2)
                            : Color.gray.opacity(0.2)
                    )
                )
                .foregroundColor(camera.source == .onvif ? Color("AccentColor") : .secondary)

            Image(systemName: "plus.circle.fill")
                .font(.title3)
                .foregroundStyle(Color("AccentColor"))
        }
        .padding(.vertical, 4)
    }

    // MARK: - Actions

    private func selectCamera(_ discovered: NetworkScanner.DiscoveredCamera) {
        let camera = Camera(
            name: discovered.displayName,
            host: discovered.host,
            rtspPort: discovered.port,
            rtspPath: "/stream1",
            onvifPort: 80,
            ptzCapability: discovered.source == .onvif ? .onvif : .none
        )
        onCameraSelected(camera)
        dismiss()
    }
}
