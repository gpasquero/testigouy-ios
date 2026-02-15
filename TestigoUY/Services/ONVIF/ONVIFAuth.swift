import Foundation
import CryptoKit

struct ONVIFAuth {
    let username: String
    let password: String

    /// Generates WS-Security UsernameToken header with SHA-1 password digest
    func makeSecurityHeader() -> String {
        let nonce = generateNonce()
        let created = ISO8601DateFormatter().string(from: Date())
        let digest = passwordDigest(nonce: nonce, created: created, password: password)
        let nonceBase64 = Data(nonce).base64EncodedString()

        return """
        <Security s:mustUnderstand="1" xmlns="http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-wssecurity-secext-1.0.xsd">
            <UsernameToken>
                <Username>\(username)</Username>
                <Password Type="http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-username-token-profile-1.0#PasswordDigest">\(digest)</Password>
                <Nonce EncodingType="http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-soap-message-security-1.0#Base64Binary">\(nonceBase64)</Nonce>
                <Created xmlns="http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-wssecurity-utility-1.0.xsd">\(created)</Created>
            </UsernameToken>
        </Security>
        """
    }

    private func generateNonce() -> [UInt8] {
        var nonce = [UInt8](repeating: 0, count: 16)
        _ = SecRandomCopyBytes(kSecRandomDefault, nonce.count, &nonce)
        return nonce
    }

    private func passwordDigest(nonce: [UInt8], created: String, password: String) -> String {
        // digest = Base64(SHA1(nonce + created + password))
        var data = Data(nonce)
        data.append(Data(created.utf8))
        data.append(Data(password.utf8))

        let hash = Insecure.SHA1.hash(data: data)
        return Data(hash).base64EncodedString()
    }
}
