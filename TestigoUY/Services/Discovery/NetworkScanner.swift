import Foundation
import Network

/// Discovers IP cameras on the local network via ONVIF WS-Discovery and RTSP port scanning
final class NetworkScanner: ObservableObject {
    @Published var discoveredHosts: [DiscoveredCamera] = []
    @Published var isScanning = false
    @Published var progress: Double = 0
    @Published var statusMessage = ""

    private var scanTask: Task<Void, Never>?

    struct DiscoveredCamera: Identifiable, Equatable {
        let id = UUID()
        let host: String
        let port: Int
        var source: DiscoverySource
        var onvifPath: String?
        var name: String?

        enum DiscoverySource: String {
            case onvif = "ONVIF"
            case rtspScan = "RTSP Scan"
        }

        var displayName: String {
            name ?? host
        }
    }

    // MARK: - Public

    func startScan() {
        guard !isScanning else { return }
        isScanning = true
        discoveredHosts = []
        progress = 0
        statusMessage = "Starting scan..."

        scanTask = Task { [weak self] in
            guard let self else { return }

            // Phase 1: ONVIF WS-Discovery (fast, multicast)
            await MainActor.run { self.statusMessage = "ONVIF Discovery..." }
            await self.onvifDiscovery()

            // Phase 2: RTSP port scan on local subnet
            await MainActor.run { self.statusMessage = "Scanning RTSP ports..." }
            await self.rtspPortScan()

            await MainActor.run {
                self.isScanning = false
                self.progress = 1.0
                self.statusMessage = self.discoveredHosts.isEmpty
                    ? "No cameras found"
                    : "Found \(self.discoveredHosts.count) camera(s)"
            }
        }
    }

    func stopScan() {
        scanTask?.cancel()
        scanTask = nil
        isScanning = false
        statusMessage = "Scan cancelled"
    }

    // MARK: - ONVIF WS-Discovery

    private func onvifDiscovery() async {
        let probeMessage = """
        <?xml version="1.0" encoding="UTF-8"?>
        <e:Envelope xmlns:e="http://www.w3.org/2003/05/soap-envelope"
                    xmlns:w="http://schemas.xmlsoap.org/ws/2004/08/addressing"
                    xmlns:d="http://schemas.xmlsoap.org/ws/2005/04/discovery"
                    xmlns:dn="http://www.onvif.org/ver10/network/wsdl">
            <e:Header>
                <w:MessageID>uuid:\(UUID().uuidString)</w:MessageID>
                <w:To>urn:schemas-xmlsoap-org:ws:2005:04:discovery</w:To>
                <w:Action>http://schemas.xmlsoap.org/ws/2005/04/discovery/Probe</w:Action>
            </e:Header>
            <e:Body>
                <d:Probe>
                    <d:Types>dn:NetworkVideoTransmitter</d:Types>
                </d:Probe>
            </e:Body>
        </e:Envelope>
        """

        guard let data = probeMessage.data(using: .utf8) else { return }

        // Create UDP socket for multicast
        let fd = socket(AF_INET, SOCK_DGRAM, IPPROTO_UDP)
        guard fd >= 0 else { return }
        defer { close(fd) }

        // Set socket timeout
        var timeout = timeval(tv_sec: 3, tv_usec: 0)
        setsockopt(fd, SOL_SOCKET, SO_RCVTIMEO, &timeout, socklen_t(MemoryLayout<timeval>.size))

        // Enable broadcast/multicast
        var yes: Int32 = 1
        setsockopt(fd, SOL_SOCKET, SO_BROADCAST, &yes, socklen_t(MemoryLayout<Int32>.size))

        // Send to ONVIF multicast address 239.255.255.250:3702
        var addr = sockaddr_in()
        addr.sin_family = sa_family_t(AF_INET)
        addr.sin_port = UInt16(3702).bigEndian
        inet_pton(AF_INET, "239.255.255.250", &addr.sin_addr)

        let sent = data.withUnsafeBytes { ptr in
            withUnsafePointer(to: &addr) { addrPtr in
                addrPtr.withMemoryRebound(to: sockaddr.self, capacity: 1) { sa in
                    sendto(fd, ptr.baseAddress, data.count, 0, sa, socklen_t(MemoryLayout<sockaddr_in>.size))
                }
            }
        }
        guard sent > 0 else { return }

        // Receive responses
        var buffer = [UInt8](repeating: 0, count: 65536)
        let deadline = Date().addingTimeInterval(3)

        while Date() < deadline {
            if Task.isCancelled { break }

            var senderAddr = sockaddr_in()
            var senderLen = socklen_t(MemoryLayout<sockaddr_in>.size)

            let received = withUnsafeMutablePointer(to: &senderAddr) { addrPtr in
                addrPtr.withMemoryRebound(to: sockaddr.self, capacity: 1) { sa in
                    recvfrom(fd, &buffer, buffer.count, 0, sa, &senderLen)
                }
            }

            guard received > 0 else { break }

            let responseData = Data(buffer[0..<received])
            if let response = String(data: responseData, encoding: .utf8) {
                let host = extractHostFromResponse(response, addr: senderAddr)
                if let host, !host.isEmpty {
                    await addDiscoveredCamera(host: host, port: 554, source: .onvif)
                }
            }
        }

        await MainActor.run { self.progress = 0.3 }
    }

    private func extractHostFromResponse(_ response: String, addr: sockaddr_in) -> String? {
        // Try to extract from XAddrs in ONVIF response
        if let range = response.range(of: "http://([0-9]+\\.[0-9]+\\.[0-9]+\\.[0-9]+)", options: .regularExpression) {
            let url = String(response[range])
            if let components = URLComponents(string: url) {
                return components.host
            }
        }
        // Fallback: use sender IP
        var ipStr = [CChar](repeating: 0, count: Int(INET_ADDRSTRLEN))
        var addrCopy = addr.sin_addr
        inet_ntop(AF_INET, &addrCopy, &ipStr, socklen_t(INET_ADDRSTRLEN))
        return String(cString: ipStr)
    }

    // MARK: - RTSP Port Scan

    private func rtspPortScan() async {
        guard let subnet = getLocalSubnet() else {
            await MainActor.run { self.statusMessage = "Could not determine local network" }
            return
        }

        let baseIP = subnet.base
        let total = 254
        let concurrency = 30

        await withTaskGroup(of: (String, Bool).self) { group in
            var launched = 0
            var completed = 0

            for i in 1...total {
                if Task.isCancelled { break }

                let ip = "\(baseIP).\(i)"

                // Skip already discovered hosts
                let alreadyFound = await MainActor.run {
                    self.discoveredHosts.contains { $0.host == ip }
                }
                if alreadyFound {
                    completed += 1
                    continue
                }

                group.addTask {
                    let open = await self.isPortOpen(host: ip, port: 554, timeout: 1.0)
                    return (ip, open)
                }
                launched += 1

                if launched >= concurrency {
                    if let result = await group.next() {
                        completed += 1
                        if result.1 {
                            await self.addDiscoveredCamera(host: result.0, port: 554, source: .rtspScan)
                        }
                        let pct = completed
                        await MainActor.run {
                            self.progress = 0.3 + 0.7 * Double(pct) / Double(total)
                        }
                        launched -= 1
                    }
                }
            }

            for await result in group {
                completed += 1
                if result.1 {
                    await self.addDiscoveredCamera(host: result.0, port: 554, source: .rtspScan)
                }
                let pct = completed
                await MainActor.run {
                    self.progress = 0.3 + 0.7 * Double(pct) / Double(total)
                }
            }
        }
    }

    private func isPortOpen(host: String, port: Int, timeout: TimeInterval) async -> Bool {
        let fd = socket(AF_INET, SOCK_STREAM, IPPROTO_TCP)
        guard fd >= 0 else { return false }
        defer { close(fd) }

        // Set non-blocking
        let flags = fcntl(fd, F_GETFL, 0)
        _ = fcntl(fd, F_SETFL, flags | O_NONBLOCK)

        var addr = sockaddr_in()
        addr.sin_family = sa_family_t(AF_INET)
        addr.sin_port = UInt16(port).bigEndian
        inet_pton(AF_INET, host, &addr.sin_addr)

        let connectResult = withUnsafePointer(to: &addr) { addrPtr in
            addrPtr.withMemoryRebound(to: sockaddr.self, capacity: 1) { sa in
                connect(fd, sa, socklen_t(MemoryLayout<sockaddr_in>.size))
            }
        }

        if connectResult == 0 { return true }
        guard errno == EINPROGRESS else { return false }

        // Wait for connection with timeout using poll
        var pfd = pollfd(fd: fd, events: Int16(POLLOUT), revents: 0)
        let timeoutMs = Int32(timeout * 1000)
        let pollResult = poll(&pfd, 1, timeoutMs)

        if pollResult > 0 && (pfd.revents & Int16(POLLOUT)) != 0 {
            var error: Int32 = 0
            var len = socklen_t(MemoryLayout<Int32>.size)
            getsockopt(fd, SOL_SOCKET, SO_ERROR, &error, &len)
            return error == 0
        }

        return false
    }

    // MARK: - Helpers

    private func addDiscoveredCamera(host: String, port: Int, source: DiscoveredCamera.DiscoverySource) async {
        await MainActor.run {
            guard !discoveredHosts.contains(where: { $0.host == host }) else { return }
            discoveredHosts.append(DiscoveredCamera(host: host, port: port, source: source))
        }
    }

    private struct SubnetInfo {
        let base: String  // e.g. "192.168.1"
        let localIP: String
    }

    private func getLocalSubnet() -> SubnetInfo? {
        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddr) == 0, let firstAddr = ifaddr else { return nil }
        defer { freeifaddrs(ifaddr) }

        for ptr in sequence(first: firstAddr, next: { $0.pointee.ifa_next }) {
            let addr = ptr.pointee
            guard addr.ifa_addr.pointee.sa_family == UInt8(AF_INET) else { continue }

            let name = String(cString: addr.ifa_name)
            // Look for WiFi interface (en0) or hotspot (bridge)
            guard name == "en0" || name.hasPrefix("bridge") else { continue }

            var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
            getnameinfo(addr.ifa_addr, socklen_t(addr.ifa_addr.pointee.sa_len),
                       &hostname, socklen_t(hostname.count),
                       nil, 0, NI_NUMERICHOST)

            let ip = String(cString: hostname)
            guard ip.hasPrefix("192.168.") || ip.hasPrefix("10.") || ip.hasPrefix("172.") else { continue }

            let parts = ip.split(separator: ".")
            guard parts.count == 4 else { continue }
            let base = "\(parts[0]).\(parts[1]).\(parts[2])"
            return SubnetInfo(base: base, localIP: ip)
        }

        return nil
    }
}
