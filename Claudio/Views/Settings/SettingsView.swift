import SwiftUI

struct SettingsView: View {
    @AppStorage("defaultStreamProfile") private var defaultStreamProfile = StreamProfile.main.rawValue
    @AppStorage("defaultGridLayout") private var defaultGridLayout = GridLayout.twoByTwo.rawValue
    @AppStorage("storageLimitMB") private var storageLimitMB = 1000
    @State private var showClearConfirmation = false
    @State private var storageUsed: String = "Calculating..."

    var body: some View {
        NavigationStack {
            Form {
                Section("Streaming") {
                    Picker("Default Stream Profile", selection: $defaultStreamProfile) {
                        ForEach(StreamProfile.allCases, id: \.rawValue) { profile in
                            Text(profile.displayName).tag(profile.rawValue)
                        }
                    }

                    Picker("Default Grid Layout", selection: $defaultGridLayout) {
                        ForEach(GridLayout.allCases, id: \.rawValue) { layout in
                            Text(layout.displayName).tag(layout.rawValue)
                        }
                    }
                }

                Section("Storage") {
                    HStack {
                        Text("Storage Limit")
                        Spacer()
                        Text("\(storageLimitMB) MB")
                            .foregroundColor(.secondary)
                    }

                    Slider(
                        value: Binding(
                            get: { Double(storageLimitMB) },
                            set: { storageLimitMB = Int($0) }
                        ),
                        in: 100...5000,
                        step: 100
                    )

                    HStack {
                        Text("Used")
                        Spacer()
                        Text(storageUsed)
                            .foregroundColor(.secondary)
                    }

                    Button(role: .destructive) {
                        showClearConfirmation = true
                    } label: {
                        Label("Clear All Recordings", systemImage: "trash")
                    }
                }

                Section("About") {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text("1.0.0")
                            .foregroundColor(.secondary)
                    }
                    HStack {
                        Text("App")
                        Spacer()
                        Text("Claudio")
                            .foregroundColor(.secondary)
                    }
                }
            }
            .navigationTitle("Settings")
            .confirmationDialog("Clear Recordings", isPresented: $showClearConfirmation) {
                Button("Delete All Recordings", role: .destructive) {
                    clearRecordings()
                }
            } message: {
                Text("This will permanently delete all recorded videos.")
            }
            .onAppear {
                calculateStorageUsed()
            }
        }
    }

    private func calculateStorageUsed() {
        let documentsDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let recordingsDir = documentsDir.appendingPathComponent("Recordings")
        guard let files = try? FileManager.default.contentsOfDirectory(atPath: recordingsDir.path) else {
            storageUsed = "0 bytes"
            return
        }
        var total: Int64 = 0
        for file in files {
            let path = recordingsDir.appendingPathComponent(file).path
            if let attrs = try? FileManager.default.attributesOfItem(atPath: path) {
                total += attrs[.size] as? Int64 ?? 0
            }
        }
        storageUsed = ByteCountFormatter.string(fromByteCount: total, countStyle: .file)
    }

    private func clearRecordings() {
        let vm = RecordingViewModel()
        vm.loadRecordings()
        vm.deleteAllRecordings()
        calculateStorageUsed()
    }
}
