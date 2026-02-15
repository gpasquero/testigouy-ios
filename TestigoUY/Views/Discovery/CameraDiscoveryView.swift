import SwiftUI

struct CameraDiscoveryView: View {
    @StateObject private var scanner = NetworkScanner()
    @StateObject private var prober = RTSPProber()
    @Environment(\.dismiss) private var dismiss
    let onCameraSelected: (Camera) -> Void

    @State private var probingCamera: NetworkScanner.DiscoveredCamera?
    @State private var probeUsername = ""
    @State private var probePassword = ""

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                statusHeader

                if let camera = probingCamera {
                    probeView(camera: camera)
                } else if scanner.discoveredHosts.isEmpty && !scanner.isScanning {
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
                    if probingCamera != nil {
                        // no scan button while probing
                    } else if scanner.isScanning {
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
                prober.stop()
            }
        }
    }

    // MARK: - Status Header

    private var statusHeader: some View {
        VStack(spacing: 8) {
            if scanner.isScanning {
                ProgressView(value: scanner.progress)
                    .tint(Color("AccentColor"))
                    .padding(.horizontal)
            } else if prober.isProbing {
                ProgressView(value: prober.progress)
                    .tint(Color("AccentColor"))
                    .padding(.horizontal)
            }

            Text(prober.isProbing ? prober.statusMessage : scanner.statusMessage)
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.bottom, 8)
        }
        .padding(.top, 8)
        .background(Color("BrandBackground"))
    }

    // MARK: - Empty State

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

    // MARK: - Camera List

    private var cameraList: some View {
        List {
            Section {
                ForEach(scanner.discoveredHosts) { camera in
                    Button(action: { startProbing(camera) }) {
                        discoveredRow(camera)
                    }
                }
            } header: {
                Text("Found \(scanner.discoveredHosts.count) device(s)")
            } footer: {
                Text("Tap a camera to auto-detect its RTSP stream")
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

            Image(systemName: "antenna.radiowaves.left.and.right")
                .font(.title3)
                .foregroundStyle(Color("AccentColor"))
        }
        .padding(.vertical, 4)
    }

    // MARK: - Probe View

    private func probeView(camera: NetworkScanner.DiscoveredCamera) -> some View {
        VStack(spacing: 0) {
            // Camera info
            VStack(spacing: 8) {
                HStack {
                    Button(action: {
                        prober.stop()
                        probingCamera = nil
                    }) {
                        Image(systemName: "chevron.left")
                        Text("Back")
                    }
                    .foregroundStyle(Color("AccentColor"))

                    Spacer()

                    Text(camera.host)
                        .font(.headline)
                }
                .padding(.horizontal)
                .padding(.top, 8)

                // Credentials
                VStack(spacing: 8) {
                    HStack(spacing: 12) {
                        TextField("Username", text: $probeUsername)
                            #if os(iOS)
                            .textInputAutocapitalization(.never)
                            #endif
                            .autocorrectionDisabled()
                            .textFieldStyle(.roundedBorder)

                        SecureField("Password", text: $probePassword)
                            .textFieldStyle(.roundedBorder)
                    }

                    HStack(spacing: 12) {
                        Button(action: {
                            prober.probe(host: camera.host, port: camera.port,
                                         username: probeUsername, password: probePassword)
                        }) {
                            HStack {
                                Image(systemName: "antenna.radiowaves.left.and.right")
                                Text(prober.isProbing ? "Probing..." : "Probe with Credentials")
                            }
                            .fontWeight(.medium)
                            .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(Color("AccentColor"))
                        .disabled(prober.isProbing)

                        if !prober.isProbing && prober.triedPaths.isEmpty {
                            Button(action: {
                                prober.probe(host: camera.host, port: camera.port)
                            }) {
                                Text("Without")
                                    .fontWeight(.medium)
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 8)
            }
            .background(Color("BrandBackground"))

            // Results
            if let foundPath = prober.foundPath {
                // Success!
                VStack(spacing: 16) {
                    Spacer()

                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 60))
                        .foregroundStyle(.green)

                    Text("Stream Found!")
                        .font(.title2)
                        .fontWeight(.semibold)

                    Text("Path: \(foundPath)")
                        .font(.callout)
                        .monospaced()
                        .foregroundColor(.secondary)

                    if let user = prober.foundUsername {
                        HStack(spacing: 4) {
                            Image(systemName: "key.fill")
                                .foregroundStyle(Color("AccentColor"))
                            Text("Credentials: \(user)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }

                    Button(action: { addCamera(camera, path: foundPath) }) {
                        Label("Add Camera", systemImage: "plus.circle.fill")
                            .fontWeight(.semibold)
                            .padding(.horizontal, 32)
                            .padding(.vertical, 12)
                            .background(Color("AccentColor"))
                            .foregroundColor(.black)
                            .cornerRadius(12)
                    }

                    Spacer()
                }
            } else {
                // Probe results list
                List {
                    Section {
                        ForEach(Array(prober.triedPaths.enumerated()), id: \.offset) { _, item in
                            HStack {
                                Image(systemName: item.success ? "checkmark.circle.fill" : "xmark.circle")
                                    .foregroundColor(item.success ? .green : .red.opacity(0.4))
                                    .font(.caption)

                                Text(item.path)
                                    .font(.caption)
                                    .monospaced()
                                    .foregroundColor(item.success ? .primary : .secondary)
                            }
                        }
                    } header: {
                        if prober.isProbing {
                            Text("Testing RTSP paths...")
                        } else if !prober.triedPaths.isEmpty {
                            Text("No working path found — try different credentials")
                        } else {
                            Text("Enter camera credentials above, then tap Probe")
                        }
                    }
                }
            }
        }
    }

    // MARK: - Actions

    private func startProbing(_ camera: NetworkScanner.DiscoveredCamera) {
        probingCamera = camera
        probeUsername = ""
        probePassword = ""
        // Don't auto-probe — let user enter credentials first
    }

    private func addCamera(_ discovered: NetworkScanner.DiscoveredCamera, path: String) {
        // Use auto-detected credentials if available, otherwise use manual input
        let username = prober.foundUsername ?? probeUsername
        let password = prober.foundPassword ?? probePassword
        let camera = Camera(
            name: discovered.displayName,
            host: discovered.host,
            rtspPort: discovered.port,
            rtspPath: path,
            username: username,
            password: password,
            onvifPort: 80,
            ptzCapability: discovered.source == .onvif ? .onvif : .none
        )
        onCameraSelected(camera)
        dismiss()
    }
}
