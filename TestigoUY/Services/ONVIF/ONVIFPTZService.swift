import Foundation

final class ONVIFPTZService {
    private let host: String
    private let port: Int
    private let auth: ONVIFAuth
    private let session = URLSession.shared
    private var profileToken: String = "Profile_1"

    init(host: String, port: Int, username: String, password: String) {
        self.host = host
        self.port = port
        self.auth = ONVIFAuth(username: username, password: password)
    }

    // MARK: - PTZ Commands

    /// Continuous move in pan/tilt/zoom directions
    /// - Parameters:
    ///   - panSpeed: -1.0 to 1.0 (left to right)
    ///   - tiltSpeed: -1.0 to 1.0 (down to up)
    ///   - zoomSpeed: -1.0 to 1.0 (out to in)
    func continuousMove(pan: Float, tilt: Float, zoom: Float) async throws {
        let body = """
        <ContinuousMove xmlns="http://www.onvif.org/ver20/ptz/wsdl">
            <ProfileToken>\(profileToken)</ProfileToken>
            <Velocity>
                <PanTilt x="\(pan)" y="\(tilt)" xmlns="http://www.onvif.org/ver10/schema"/>
                <Zoom x="\(zoom)" xmlns="http://www.onvif.org/ver10/schema"/>
            </Velocity>
        </ContinuousMove>
        """
        try await sendCommand(body: body, action: "http://www.onvif.org/ver20/ptz/wsdl/ContinuousMove")
    }

    /// Stop all PTZ movement
    func stop() async throws {
        let body = """
        <Stop xmlns="http://www.onvif.org/ver20/ptz/wsdl">
            <ProfileToken>\(profileToken)</ProfileToken>
            <PanTilt>true</PanTilt>
            <Zoom>true</Zoom>
        </Stop>
        """
        try await sendCommand(body: body, action: "http://www.onvif.org/ver20/ptz/wsdl/Stop")
    }

    /// Go to a named preset
    func gotoPreset(presetToken: String) async throws {
        let body = """
        <GotoPreset xmlns="http://www.onvif.org/ver20/ptz/wsdl">
            <ProfileToken>\(profileToken)</ProfileToken>
            <PresetToken>\(presetToken)</PresetToken>
        </GotoPreset>
        """
        try await sendCommand(body: body, action: "http://www.onvif.org/ver20/ptz/wsdl/GotoPreset")
    }

    // MARK: - SOAP Transport

    private func sendCommand(body: String, action: String) async throws {
        let envelope = buildEnvelope(body: body)
        let url = URL(string: "http://\(host):\(port)/onvif/PTZ")!

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/soap+xml; charset=utf-8; action=\"\(action)\"", forHTTPHeaderField: "Content-Type")
        request.httpBody = envelope.data(using: .utf8)
        request.timeoutInterval = 5

        let (_, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw ONVIFError.commandFailed
        }
    }

    private func buildEnvelope(body: String) -> String {
        """
        <?xml version="1.0" encoding="UTF-8"?>
        <s:Envelope xmlns:s="http://www.w3.org/2003/05/soap-envelope">
            <s:Header>
                \(auth.makeSecurityHeader())
            </s:Header>
            <s:Body>
                \(body)
            </s:Body>
        </s:Envelope>
        """
    }
}

enum ONVIFError: Error, LocalizedError {
    case commandFailed
    case timeout
    case authenticationFailed

    var errorDescription: String? {
        switch self {
        case .commandFailed: return "PTZ command failed"
        case .timeout: return "Connection timed out"
        case .authenticationFailed: return "Authentication failed"
        }
    }
}
