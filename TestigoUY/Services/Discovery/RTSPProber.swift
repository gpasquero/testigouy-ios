import Foundation

/// Probes an IP camera to find the correct RTSP path by trying common paths
final class RTSPProber: ObservableObject {
    @Published var isProbing = false
    @Published var foundPath: String?
    @Published var progress: Double = 0
    @Published var statusMessage = ""
    @Published var triedPaths: [(path: String, success: Bool)] = []

    private var probeTask: Task<Void, Never>?

    /// Common RTSP paths for Chinese/generic IP cameras, ordered by likelihood
    static let commonPaths: [String] = [
        // Most common for Chinese cameras (Anboqi, V380, 超级看看, etc.)
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
        // ONVIF standard paths
        "/onvif1",
        "/onvif2",
        "/MediaInput/h264",
        "/MediaInput/mpeg4",
        "/ONVIF/MediaInput",
        // Generic common paths
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
        // Hikvision-style
        "/ISAPI/Streaming/channels/101",
        // Dahua-style
        "/cam/realmonitor?channel=1&subtype=00",
        // Other Chinese camera formats
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
        progress = 0
        triedPaths = []
        statusMessage = "Probing RTSP paths..."

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

                let url = Self.buildURL(host: host, port: port, path: path,
                                        username: username, password: password)
                let success = await self.testRTSPPath(url: url)

                await MainActor.run {
                    self.triedPaths.append((path: path, success: success))
                }

                if success {
                    await MainActor.run {
                        self.foundPath = path
                        self.isProbing = false
                        self.progress = 1.0
                        self.statusMessage = "Found: \(path)"
                    }
                    return
                }
            }

            await MainActor.run {
                self.isProbing = false
                self.progress = 1.0
                self.statusMessage = "No working RTSP path found"
            }
        }
    }

    func stop() {
        probeTask?.cancel()
        probeTask = nil
        isProbing = false
    }

    // MARK: - Private

    private static func buildURL(host: String, port: Int, path: String,
                                 username: String, password: String) -> URL? {
        var components = URLComponents()
        components.scheme = "rtsp"
        components.host = host
        components.port = port
        components.path = path.hasPrefix("/") ? path : "/\(path)"
        if !username.isEmpty {
            components.user = username
            components.password = password
        }
        return components.url
    }

    /// Test if an RTSP path responds with a valid DESCRIBE
    private func testRTSPPath(url: URL?) async -> Bool {
        guard let url else { return false }

        // Try TCP connection and send RTSP OPTIONS to check if path exists
        let host = url.host ?? ""
        let port = url.port ?? 554

        let fd = socket(AF_INET, SOCK_STREAM, IPPROTO_TCP)
        guard fd >= 0 else { return false }
        defer { close(fd) }

        // Set timeout
        var timeout = timeval(tv_sec: 2, tv_usec: 0)
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

        guard connectResult == 0 else { return false }

        // Send RTSP OPTIONS request
        let request = "OPTIONS \(url.absoluteString) RTSP/1.0\r\nCSeq: 1\r\nUser-Agent: TestigoUY\r\n\r\n"
        guard let requestData = request.data(using: .ascii) else { return false }

        let sent = requestData.withUnsafeBytes { ptr in
            send(fd, ptr.baseAddress, requestData.count, 0)
        }
        guard sent > 0 else { return false }

        // Read response
        var buffer = [UInt8](repeating: 0, count: 4096)
        let received = recv(fd, &buffer, buffer.count, 0)
        guard received > 0 else { return false }

        let response = String(bytes: buffer[0..<received], encoding: .ascii) ?? ""

        // Now try DESCRIBE to verify the path is valid
        let describeRequest = "DESCRIBE \(url.absoluteString) RTSP/1.0\r\nCSeq: 2\r\nUser-Agent: TestigoUY\r\nAccept: application/sdp\r\n\r\n"
        guard let descData = describeRequest.data(using: .ascii) else {
            // If OPTIONS returned 200, that's good enough
            return response.contains("RTSP/1.0 200")
        }

        let sent2 = descData.withUnsafeBytes { ptr in
            send(fd, ptr.baseAddress, descData.count, 0)
        }
        guard sent2 > 0 else { return response.contains("RTSP/1.0 200") }

        var buffer2 = [UInt8](repeating: 0, count: 4096)
        let received2 = recv(fd, &buffer2, buffer2.count, 0)
        guard received2 > 0 else { return false }

        let descResponse = String(bytes: buffer2[0..<received2], encoding: .ascii) ?? ""

        // 200 OK = path exists and is streamable
        // 401 = path exists but needs auth (still valid!)
        return descResponse.contains("RTSP/1.0 200") || descResponse.contains("RTSP/1.0 401")
    }
}
