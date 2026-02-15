import Foundation

enum GridLayout: String, CaseIterable, Identifiable {
    case single = "1x1"
    case twoByTwo = "2x2"
    case threeByThree = "3x3"

    var id: String { rawValue }

    var columns: Int {
        switch self {
        case .single: return 1
        case .twoByTwo: return 2
        case .threeByThree: return 3
        }
    }

    var maxCameras: Int {
        columns * columns
    }

    var displayName: String { rawValue }

    var systemImage: String {
        switch self {
        case .single: return "square"
        case .twoByTwo: return "square.grid.2x2"
        case .threeByThree: return "square.grid.3x3"
        }
    }
}
