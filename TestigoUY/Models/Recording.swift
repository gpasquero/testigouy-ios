import Foundation

struct Recording: Identifiable, Equatable {
    let id: UUID
    var cameraId: UUID
    var cameraName: String
    var filePath: String
    var startDate: Date
    var endDate: Date?
    var fileSize: Int64
    var thumbnailPath: String?

    var duration: TimeInterval? {
        guard let endDate else { return nil }
        return endDate.timeIntervalSince(startDate)
    }

    var formattedDuration: String {
        guard let duration else { return "Recording..." }
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    var formattedFileSize: String {
        ByteCountFormatter.string(fromByteCount: fileSize, countStyle: .file)
    }

    var fileURL: URL {
        URL(fileURLWithPath: filePath)
    }

    init(
        id: UUID = UUID(),
        cameraId: UUID,
        cameraName: String,
        filePath: String,
        startDate: Date = Date(),
        endDate: Date? = nil,
        fileSize: Int64 = 0,
        thumbnailPath: String? = nil
    ) {
        self.id = id
        self.cameraId = cameraId
        self.cameraName = cameraName
        self.filePath = filePath
        self.startDate = startDate
        self.endDate = endDate
        self.fileSize = fileSize
        self.thumbnailPath = thumbnailPath
    }
}
