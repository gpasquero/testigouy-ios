import Foundation

enum Constants {
    enum Stream {
        static let defaultRTSPPort = 554
        static let defaultONVIFPort = 80
        static let defaultNetworkCaching = 300
        static let maxSimultaneousStreams = 9
        static let reconnectDelay: TimeInterval = 3.0
        static let overlayAutoHideDelay: TimeInterval = 3.0
    }

    enum Recording {
        static let defaultStorageLimitMB = 1000
        static let recordingsDirectory = "Recordings"
        static let fileExtension = "mp4"
    }

    enum PTZ {
        static let defaultPanSpeed: Float = 0.5
        static let defaultTiltSpeed: Float = 0.5
        static let defaultZoomSpeed: Float = 0.3
        static let maxSpeed: Float = 1.0
    }
}
