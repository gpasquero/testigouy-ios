import Foundation

enum RTSPURLValidator {
    static func isValidHost(_ host: String) -> Bool {
        let trimmed = host.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return false }
        // Accept IP addresses (v4) or hostnames
        return isValidIPv4(trimmed) || isValidHostname(trimmed)
    }

    static func isValidPort(_ port: Int) -> Bool {
        (1...65535).contains(port)
    }

    static func isValidRTSPURL(_ urlString: String) -> Bool {
        guard let url = URL(string: urlString),
              let scheme = url.scheme?.lowercased(),
              scheme == "rtsp" || scheme == "rtsps",
              url.host != nil else {
            return false
        }
        return true
    }

    static func buildRTSPURL(host: String, port: Int, path: String, username: String, password: String) -> URL? {
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

    // MARK: - Private

    private static func isValidIPv4(_ string: String) -> Bool {
        let parts = string.split(separator: ".")
        guard parts.count == 4 else { return false }
        return parts.allSatisfy { part in
            guard let num = Int(part) else { return false }
            return (0...255).contains(num)
        }
    }

    private static func isValidHostname(_ string: String) -> Bool {
        let pattern = "^[a-zA-Z0-9]([a-zA-Z0-9\\-]*[a-zA-Z0-9])?(\\.[a-zA-Z0-9]([a-zA-Z0-9\\-]*[a-zA-Z0-9])?)*$"
        return string.range(of: pattern, options: .regularExpression) != nil
    }
}
