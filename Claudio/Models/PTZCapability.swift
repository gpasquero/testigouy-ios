import Foundation

enum PTZCapability: String, CaseIterable, Codable {
    case none
    case onvif

    var displayName: String {
        switch self {
        case .none: return "None"
        case .onvif: return "ONVIF"
        }
    }

    var supportsPTZ: Bool {
        self != .none
    }
}
