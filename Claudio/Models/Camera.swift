import Foundation

struct Camera: Identifiable, Equatable {
    let id: UUID
    var name: String
    var host: String
    var rtspPort: Int
    var rtspPath: String
    var username: String
    var password: String
    var onvifPort: Int
    var ptzCapability: PTZCapability
    var streamProfile: StreamProfile
    var isEnabled: Bool

    var rtspURL: URL? {
        var components = URLComponents()
        components.scheme = "rtsp"
        components.host = host
        components.port = rtspPort
        let path = rtspPath.hasPrefix("/") ? rtspPath : "/\(rtspPath)"
        components.path = path
        if !username.isEmpty {
            components.user = username
            components.password = password
        }
        return components.url
    }

    var subStreamURL: URL? {
        // Common sub-stream paths for popular camera brands
        guard let mainURL = rtspURL else { return nil }
        let mainPath = mainURL.path
        // Try appending /sub or changing channel
        var components = URLComponents(url: mainURL, resolvingAgainstBaseURL: false)
        if mainPath.contains("channel=1") {
            components?.path = mainPath.replacingOccurrences(of: "channel=1", with: "channel=2")
        } else {
            components?.path = mainPath + "&subtype=1"
        }
        return components?.url ?? mainURL
    }

    init(
        id: UUID = UUID(),
        name: String = "",
        host: String = "",
        rtspPort: Int = 554,
        rtspPath: String = "/stream1",
        username: String = "",
        password: String = "",
        onvifPort: Int = 80,
        ptzCapability: PTZCapability = .none,
        streamProfile: StreamProfile = .main,
        isEnabled: Bool = true
    ) {
        self.id = id
        self.name = name
        self.host = host
        self.rtspPort = rtspPort
        self.rtspPath = rtspPath
        self.username = username
        self.password = password
        self.onvifPort = onvifPort
        self.ptzCapability = ptzCapability
        self.streamProfile = streamProfile
        self.isEnabled = isEnabled
    }
}
