import SwiftUI

struct AddCameraView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var name: String
    @State private var host: String
    @State private var rtspPort: String
    @State private var rtspPath: String
    @State private var username: String
    @State private var password: String
    @State private var onvifPort: String
    @State private var ptzCapability: PTZCapability
    @State private var streamProfile: StreamProfile
    @State private var showPassword = false
    @State private var validationError: String?

    private let existingId: UUID?
    private let onSave: (Camera) -> Void

    init(camera: Camera? = nil, onSave: @escaping (Camera) -> Void) {
        self.existingId = camera?.id
        self.onSave = onSave

        _name = State(initialValue: camera?.name ?? "")
        _host = State(initialValue: camera?.host ?? "")
        _rtspPort = State(initialValue: String(camera?.rtspPort ?? 554))
        _rtspPath = State(initialValue: camera?.rtspPath ?? "/stream1")
        _username = State(initialValue: camera?.username ?? "")
        _password = State(initialValue: camera?.password ?? "")
        _onvifPort = State(initialValue: String(camera?.onvifPort ?? 80))
        _ptzCapability = State(initialValue: camera?.ptzCapability ?? .none)
        _streamProfile = State(initialValue: camera?.streamProfile ?? .main)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Camera Info") {
                    TextField("Name", text: $name)
                    TextField("Host / IP Address", text: $host)
                        #if os(iOS)
                        .keyboardType(.URL)
                        .textInputAutocapitalization(.never)
                        #endif
                        .autocorrectionDisabled()
                }

                Section("RTSP") {
                    HStack {
                        Text("Port")
                        Spacer()
                        TextField("554", text: $rtspPort)
                            #if os(iOS)
                            .keyboardType(.numberPad)
                            #endif
                            .multilineTextAlignment(.trailing)
                            .frame(width: 80)
                    }
                    TextField("Path (e.g. /stream1)", text: $rtspPath)
                        #if os(iOS)
                        .textInputAutocapitalization(.never)
                        #endif
                        .autocorrectionDisabled()

                    Picker("Stream Profile", selection: $streamProfile) {
                        ForEach(StreamProfile.allCases, id: \.self) { profile in
                            Text(profile.displayName).tag(profile)
                        }
                    }
                }

                Section("Credentials") {
                    TextField("Username", text: $username)
                        #if os(iOS)
                        .textInputAutocapitalization(.never)
                        #endif
                        .autocorrectionDisabled()

                    HStack {
                        if showPassword {
                            TextField("Password", text: $password)
                        } else {
                            SecureField("Password", text: $password)
                        }
                        Button(action: { showPassword.toggle() }) {
                            Image(systemName: showPassword ? "eye.slash" : "eye")
                                .foregroundColor(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                }

                Section("PTZ Control") {
                    Picker("PTZ Type", selection: $ptzCapability) {
                        ForEach(PTZCapability.allCases, id: \.self) { cap in
                            Text(cap.displayName).tag(cap)
                        }
                    }

                    if ptzCapability == .onvif {
                        HStack {
                            Text("ONVIF Port")
                            Spacer()
                            TextField("80", text: $onvifPort)
                                #if os(iOS)
                                .keyboardType(.numberPad)
                                #endif
                                .multilineTextAlignment(.trailing)
                                .frame(width: 80)
                        }
                    }
                }

                if let previewURL = buildPreviewURL() {
                    Section("Preview") {
                        Text(previewURL)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .textSelection(.enabled)
                    }
                }

                if let error = validationError {
                    Section {
                        Text(error)
                            .foregroundColor(.red)
                            .font(.caption)
                    }
                }
            }
            .navigationTitle(existingId == nil ? "Add Camera" : "Edit Camera")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(name.isEmpty || host.isEmpty)
                }
            }
        }
    }

    private func save() {
        guard RTSPURLValidator.isValidHost(host) else {
            validationError = "Invalid host address"
            return
        }
        guard let port = Int(rtspPort), port > 0, port <= 65535 else {
            validationError = "Invalid RTSP port"
            return
        }

        let camera = Camera(
            id: existingId ?? UUID(),
            name: name.trimmingCharacters(in: .whitespaces),
            host: host.trimmingCharacters(in: .whitespaces),
            rtspPort: port,
            rtspPath: rtspPath,
            username: username,
            password: password,
            onvifPort: Int(onvifPort) ?? 80,
            ptzCapability: ptzCapability,
            streamProfile: streamProfile,
            isEnabled: true
        )

        onSave(camera)
        dismiss()
    }

    private func buildPreviewURL() -> String? {
        guard !host.isEmpty else { return nil }
        let port = Int(rtspPort) ?? 554
        let creds = username.isEmpty ? "" : "\(username):***@"
        return "rtsp://\(creds)\(host):\(port)\(rtspPath)"
    }
}
