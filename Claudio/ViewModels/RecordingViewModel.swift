import Foundation
import SwiftUI

@MainActor
final class RecordingViewModel: ObservableObject {
    @Published var recordings: [Recording] = []
    @Published var groupedRecordings: [String: [Recording]] = [:]

    private let persistence = PersistenceController.shared

    func loadRecordings() {
        recordings = persistence.fetchRecordings()
        groupByDate()
    }

    func deleteRecording(_ recording: Recording) {
        persistence.deleteRecording(id: recording.id)
        loadRecordings()
    }

    func deleteRecordings(at offsets: IndexSet, in section: String) {
        guard let sectionRecordings = groupedRecordings[section] else { return }
        for index in offsets {
            persistence.deleteRecording(id: sectionRecordings[index].id)
        }
        loadRecordings()
    }

    func deleteAllRecordings() {
        for recording in recordings {
            persistence.deleteRecording(id: recording.id)
        }
        loadRecordings()
    }

    var totalSize: String {
        let total = recordings.reduce(Int64(0)) { $0 + $1.fileSize }
        return ByteCountFormatter.string(fromByteCount: total, countStyle: .file)
    }

    var sortedSectionKeys: [String] {
        groupedRecordings.keys.sorted().reversed()
    }

    private func groupByDate() {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none

        groupedRecordings = Dictionary(grouping: recordings) { recording in
            formatter.string(from: recording.startDate)
        }
    }
}
