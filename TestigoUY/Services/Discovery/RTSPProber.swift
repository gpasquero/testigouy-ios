import Foundation
import CommonCrypto
import os

/// Probes an IP camera to find the correct RTSP path by trying common paths
/// and auto-detecting credentials with proper RTSP Digest/Basic authentication
final class RTSPProber: ObservableObject {
    @Published var isProbing = false
    @Published var foundPath: String?
    @Published var foundUsername: String?
    @Published var foundPassword: String?
    @Published var progress: Double = 0
    @Published var statusMessage = ""
    @Published var triedPaths: [(path: String, success: Bool)] = []

    private var probeTask: Task<Void, Never>?

    /// Common default credentials for Chinese/generic IP cameras
    static let commonCredentials: [(user: String, pass: String)] = [
        ("admin", "admin"),
        ("admin", ""),
        ("admin", "12345"),
        ("admin", "888888"),
        ("admin", "123456"),
        ("admin", "password"),
        ("admin", "1234"),
        ("root", "root"),
        ("root", ""),
    ]

    /// Common RTSP paths for Chinese/generic IP cameras, ordered by likelihood
    static let commonPaths: [String] = [
        "/live/ch00_0",
        "/live/ch00_1",
        "/live/ch0",
        "/live/ch1",
        "/ch0_0.h264",
        "/ch0_1.h264",
        "/11",
        "/12",
        "/stream0",
        "/stream1",
        "/h264_stream",
        "/live0.264",
        "/live1.264",
        "/onvif1",
        "/onvif2",
        "/MediaInput/h264",
        "/MediaInput/mpeg4",
        "/ONVIF/MediaInput",
        "/",
        "/live",
        "/live.sdp",
        "/video",
        "/video1",
        "/h264",
        "/mpeg4",
        "/cam/realmonitor?channel=1&subtype=0",
        "/cam/realmonitor?channel=1&subtype=1",
        "/h264/ch1/main/av_stream",
        "/h264/ch1/sub/av_stream",
        "/Streaming/Channels/101",
        "/Streaming/Channels/102",
        "/ISAPI/Streaming/channels/101",
        "/cam/realmonitor?channel=1&subtype=00",
        "/videoMain",
        "/videoSub",
        "/1",
        "/1/stream1",
        "/ch1-s1",
        "/stream",
        "/media.amp",
        "/video.mp4",
        "/ipcam.sdp",
        "/mpeg4cif",
        "/1/cif",
        "/ucast/11",
        "/ROH/channel/11",
    ]

    func probe(host: String, port: Int, username: String = "", password: String = "") {
        guard !isProbing else { return }
        isProbing = true
        foundPath = nil
        foundUsername = nil
        foundPassword = nil
        progress = 0
        triedPaths = []
        statusMessage = "Probing RTSP paths..."

        let hasAuth = !username.isEmpty
        NSLog("[Probe] Starting probe on %@:%d (credentials: %@)", host, port, hasAuth ? username : "none")

        probeTask = Task { [weak self] in
            guard let self else { return }
            let paths = Self.commonPaths
            let total = paths.count

            for (index, path) in paths.enumerated() {
                if Task.isCancelled { break }

                await MainActor.run {
                    self.statusMessage = "Trying \(path)..."
                    self.progress = Double(index) / Double(total)
                }

                NSLog("[Probe] [%d/%d] Testing: %@", index + 1, total, path)

                // Test with provided credentials
                let result = await self.testPath(host: host, port: port, path: path,
                                                  username: username, password: password)

                switch result {
                case .ok:
                    NSLog("[Probe] ✓ Path works: %@ (with provided credentials)", path)
                    await self.reportSuccess(path: path, username: username, password: password)
                    return

                case .authRequired where !hasAuth:
                    // Path exists but needs auth — try common credentials
                    NSLog("[Probe] Path %@ needs auth, trying %d common credentials...",
                          path, Self.commonCredentials.count)
                    await MainActor.run {
                        self.triedPaths.append((path: "\(path) (needs auth)", success: false))
                        self.statusMessage = "Trying credentials for \(path)..."
                    }

                    var credFound = false
                    for cred in Self.commonCredentials {
                        if Task.isCancelled { break }
                        NSLog("[Probe]   Trying %@:%@", cred.user, cred.pass.isEmpty ? "(empty)" : "***")
                        let authResult = await self.testPath(host: host, port: port, path: path,
                                                             username: cred.user, password: cred.pass)
                        if authResult == .ok {
                            NSLog("[Probe] ✓ Credentials work! %@:%@", cred.user, cred.pass.isEmpty ? "(empty)" : "***")
                            await self.reportSuccess(path: path, username: cred.user, password: cred.pass)
                            credFound = true
                            break
                        }
                    }
                    if credFound { return }
                    NSLog("[Probe] ✗ No common credentials worked for %@", path)

                case .authRequired:
                    // Has auth but it didn't work
                    NSLog("[Probe] ✗ %@ — auth rejected with provided credentials", path)
                    await MainActor.run {
                        self.triedPaths.append((path: "\(path) (wrong credentials)", success: false))
                    }

                default:
                    await MainActor.run {
                        self.triedPaths.append((path: path, success: false))
                    }
                }
            }

            NSLog("[Probe] No working RTSP path found after testing %d paths", total)
            await MainActor.run {
                self.isProbing = false
                self.progress = 1.0
                self.statusMessage = "No working path found"
            }
        }
    }

    func stop() {
        probeTask?.cancel()
        probeTask = nil
        isProbing = false
    }

    // MARK: - Private

    private func reportSuccess(path: String, username: String, password: String) async {
        await MainActor.run {
            self.foundPath = path
            self.foundUsername = username.isEmpty ? nil : username
            self.foundPassword = password.isEmpty ? nil : password
            self.isProbing = false
            self.progress = 1.0
            if !username.isEmpty {
                self.statusMessage = "Found: \(path) (user: \(username))"
            } else {
                self.statusMessage = "Found: \(path)"
            }
            self.triedPaths.append((path: path, success: true))
        }
    }

    // MARK: - RTSP Auth Handshake

    enum ProbeResult: Equatable {
        case ok
        case authRequired
        case failed
    }

    /// Full RTSP probe with proper Digest/Basic authentication
    private func testPath(host: String, port: Int, path: String,
                          username: String, password: String) async -> ProbeResult {
        let fd = socket(AF_INET, SOCK_STREAM, IPPROTO_TCP)
        guard fd >= 0 else { return .failed }
        defer { close(fd) }

        var timeout = timeval(tv_sec: 3, tv_usec: 0)
        setsockopt(fd, SOL_SOCKET, SO_RCVTIMEO, &timeout, socklen_t(MemoryLayout<timeval>.size))
        setsockopt(fd, SOL_SOCKET, SO_SNDTIMEO, &timeout, socklen_t(MemoryLayout<timeval>.size))

        var addr = sockaddr_in()
        addr.sin_family = sa_family_t(AF_INET)
        addr.sin_port = UInt16(port).bigEndian
        inet_pton(AF_INET, host, &addr.sin_addr)

        let connectResult = withUnsafePointer(to: &addr) { addrPtr in
            addrPtr.withMemoryRebound(to: sockaddr.self, capacity: 1) { sa in
                connect(fd, sa, socklen_t(MemoryLayout<sockaddr_in>.size))
            }
        }
        guard connectResult == 0 else { return .failed }

        let rtspPath = path.hasPrefix("/") ? path : "/\(path)"
        let uri = "rtsp://\(host):\(port)\(rtspPath)"

        // Step 1: Send DESCRIBE without auth
        let descReq = "DESCRIBE \(uri) RTSP/1.0\r\nCSeq: 1\r\nUser-Agent: TestigoUY\r\nAccept: application/sdp\r\n\r\n"
        guard let response1 = sendAndReceive(fd: fd, request: descReq) else { return .failed }

        // Check response
        if response1.contains("RTSP/1.0 200") {
            return .ok
        }

        if response1.contains("RTSP/1.0 404") || response1.contains("RTSP/1.0 400") {
            return .failed
        }

        guard response1.contains("RTSP/1.0 401") else { return .failed }

        // Need auth — if no credentials provided, report that
        if username.isEmpty { return .authRequired }

        // Step 2: Parse WWW-Authenticate header and respond
        if let authHeader = Self.extractHeader(from: response1, name: "WWW-Authenticate") {
            let authResponse: String?

            if authHeader.lowercased().hasPrefix("digest") {
                // Digest authentication
                authResponse = Self.buildDigestAuth(
                    header: authHeader, username: username, password: password,
                    method: "DESCRIBE", uri: rtspPath
                )
            } else if authHeader.lowercased().hasPrefix("basic") {
                // Basic authentication
                let credentials = Data("\(username):\(password)".utf8).base64EncodedString()
                authResponse = "Basic \(credentials)"
            } else {
                return .authRequired
            }

            guard let auth = authResponse else { return .authRequired }

            // Step 3: Re-send DESCRIBE with Authorization header
            // Need new socket since some cameras close after 401
            close(fd)
            let fd2 = socket(AF_INET, SOCK_STREAM, IPPROTO_TCP)
            guard fd2 >= 0 else { return .failed }

            setsockopt(fd2, SOL_SOCKET, SO_RCVTIMEO, &timeout, socklen_t(MemoryLayout<timeval>.size))
            setsockopt(fd2, SOL_SOCKET, SO_SNDTIMEO, &timeout, socklen_t(MemoryLayout<timeval>.size))

            let connectResult2 = withUnsafePointer(to: &addr) { addrPtr in
                addrPtr.withMemoryRebound(to: sockaddr.self, capacity: 1) { sa in
                    connect(fd2, sa, socklen_t(MemoryLayout<sockaddr_in>.size))
                }
            }
            guard connectResult2 == 0 else {
                close(fd2)
                return .failed
            }

            let authReq = "DESCRIBE \(uri) RTSP/1.0\r\nCSeq: 2\r\nUser-Agent: TestigoUY\r\nAccept: application/sdp\r\nAuthorization: \(auth)\r\n\r\n"
            let response2 = sendAndReceive(fd: fd2, request: authReq)
            close(fd2)

            if let resp = response2, resp.contains("RTSP/1.0 200") {
                return .ok
            }
            // 401 again = wrong credentials
            return .authRequired
        }

        return .authRequired
    }

    private func sendAndReceive(fd: Int32, request: String) -> String? {
        guard let data = request.data(using: .ascii) else { return nil }
        let sent = data.withUnsafeBytes { ptr in
            send(fd, ptr.baseAddress, data.count, 0)
        }
        guard sent > 0 else { return nil }

        var buffer = [UInt8](repeating: 0, count: 4096)
        let received = recv(fd, &buffer, buffer.count, 0)
        guard received > 0 else { return nil }

        return String(bytes: buffer[0..<received], encoding: .ascii)
    }

    // MARK: - Auth Helpers

    private static func extractHeader(from response: String, name: String) -> String? {
        let lines = response.components(separatedBy: "\r\n")
        let prefix = "\(name): "
        for line in lines {
            if line.hasPrefix(prefix) || line.lowercased().hasPrefix(prefix.lowercased()) {
                return String(line.dropFirst(prefix.count))
            }
        }
        return nil
    }

    /// Build Digest Authorization header value
    private static func buildDigestAuth(header: String, username: String, password: String,
                                         method: String, uri: String) -> String? {
        // Parse: Digest realm="...", nonce="...", ...
        guard let realm = extractQuotedValue(from: header, key: "realm"),
              let nonce = extractQuotedValue(from: header, key: "nonce") else {
            return nil
        }

        // HA1 = MD5(username:realm:password)
        let ha1 = md5("\(username):\(realm):\(password)")
        // HA2 = MD5(method:uri)
        let ha2 = md5("\(method):\(uri)")
        // response = MD5(HA1:nonce:HA2)
        let response = md5("\(ha1):\(nonce):\(ha2)")

        return "Digest username=\"\(username)\", realm=\"\(realm)\", nonce=\"\(nonce)\", uri=\"\(uri)\", response=\"\(response)\""
    }

    private static func extractQuotedValue(from header: String, key: String) -> String? {
        // Match key="value" pattern
        let patterns = [
            "\(key)=\"",    // standard
            "\(key) = \"",  // with spaces
        ]
        for pattern in patterns {
            if let range = header.range(of: pattern, options: .caseInsensitive) {
                let start = range.upperBound
                if let end = header[start...].firstIndex(of: "\"") {
                    return String(header[start..<end])
                }
            }
        }
        return nil
    }

    private static func md5(_ string: String) -> String {
        let data = Data(string.utf8)
        var digest = [UInt8](repeating: 0, count: Int(CC_MD5_DIGEST_LENGTH))
        data.withUnsafeBytes { ptr in
            _ = CC_MD5(ptr.baseAddress, CC_LONG(data.count), &digest)
        }
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}
