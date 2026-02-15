import SwiftUI

struct RecordingListView: View {
    @StateObject private var viewModel = RecordingViewModel()

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.recordings.isEmpty {
                    emptyState
                } else {
                    recordingsList
                }
            }
            .navigationTitle("Recordings")
            .toolbar {
                if !viewModel.recordings.isEmpty {
                    ToolbarItem(placement: .primaryAction) {
                        Menu {
                            Text("Total: \(viewModel.totalSize)")
                            Button(role: .destructive) {
                                viewModel.deleteAllRecordings()
                            } label: {
                                Label("Delete All", systemImage: "trash")
                            }
                        } label: {
                            Image(systemName: "ellipsis.circle")
                        }
                    }
                }
            }
            .onAppear {
                viewModel.loadRecordings()
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "film.stack")
                .font(.system(size: 60))
                .foregroundColor(.secondary)
            Text("No Recordings")
                .font(.title2)
                .fontWeight(.semibold)
            Text("Record from a live camera view to save clips here")
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
    }

    private var recordingsList: some View {
        List {
            ForEach(viewModel.sortedSectionKeys, id: \.self) { section in
                Section(section) {
                    if let recordings = viewModel.groupedRecordings[section] {
                        ForEach(recordings) { recording in
                            NavigationLink(destination: RecordingPlayerView(recording: recording)) {
                                recordingRow(recording)
                            }
                        }
                        .onDelete { offsets in
                            viewModel.deleteRecordings(at: offsets, in: section)
                        }
                    }
                }
            }
        }
    }

    private func recordingRow(_ recording: Recording) -> some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 6)
                .fill(Color.gray.opacity(0.15))
                .frame(width: 60, height: 40)
                .overlay {
                    Image(systemName: "play.fill")
                        .foregroundColor(.secondary)
                        .font(.caption)
                }

            VStack(alignment: .leading, spacing: 2) {
                Text(recording.cameraName)
                    .font(.subheadline)
                    .fontWeight(.medium)

                HStack {
                    Text(recording.formattedDuration)
                    Text("·")
                    Text(recording.formattedFileSize)
                }
                .font(.caption)
                .foregroundColor(.secondary)

                Text(recording.startDate, style: .time)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 2)
    }
}
