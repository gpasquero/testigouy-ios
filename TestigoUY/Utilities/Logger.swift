import Foundation
import os

/// Centralized debug logging for TestigoUY
enum Log {
    private static let subsystem = "com.testigouy.app"

    static let stream = Logger(subsystem: subsystem, category: "Stream")
    static let discovery = Logger(subsystem: subsystem, category: "Discovery")
    static let rtspProbe = Logger(subsystem: subsystem, category: "RTSPProbe")
    static let ptz = Logger(subsystem: subsystem, category: "PTZ")
    static let recording = Logger(subsystem: subsystem, category: "Recording")
    static let persistence = Logger(subsystem: subsystem, category: "Persistence")
}
