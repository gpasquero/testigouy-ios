import Foundation

enum StreamProfile: String, CaseIterable, Codable {
    case main
    case sub

    var displayName: String {
        switch self {
        case .main: return "Main Stream"
        case .sub: return "Sub Stream"
        }
    }
}

enum StreamState: Equatable {
    case idle
    case connecting
    case playing
    case error(String)
    case recording

    var isActive: Bool {
        switch self {
        case .playing, .recording: return true
        default: return false
        }
    }

    var statusText: String {
        switch self {
        case .idle: return "Idle"
        case .connecting: return "Connecting..."
        case .playing: return "Playing"
        case .error(let msg): return "Error: \(msg)"
        case .recording: return "Recording"
        }
    }
}
