//
//  Copyright © 2025 Octopus Community. All rights reserved.
//

import Foundation
import CryptoKit

/// ⚠️ the content of this class is for the sample uniquely, in order to create a token easilly without
/// depending on a backend.
/// In your app, you should probably call a backend route that provides you this token.
class TokenProvider {
    private struct Header: Encodable {
        let alg = "HS256"
        let typ = "JWT"
    }

    private struct ClientUserTokenPayload: Encodable {
        let sub: String
        let exp: Int
    }

    private struct BridgePostPayload: Encodable {
        let exp: Int
    }

    func getClientUserToken(userId: String) async throws -> String {
        // ⚠️ the content of this function is for the sample uniquely, in order to create a token easilly without
        // depending on a backend.
        // In your app, you should proably call a backend route that provides you this token.
        guard let secret = Bundle.main.infoDictionary!["CLIENT_USER_TOKEN_SECRET"] as? String else {
            print("This example won't work because you need to sign the token")
            return ""
        }
        let privateKey = SymmetricKey(data: Data(secret.utf8))

        let headerJSONData = try JSONEncoder().encode(Header())
        let headerBase64String = headerJSONData.urlSafeBase64EncodedString()

        let payloadJSONData = try JSONEncoder().encode(
            ClientUserTokenPayload(sub: userId, exp: Int(Date().addingTimeInterval(60 * 60).timeIntervalSince1970))
        )
        let payloadBase64String = payloadJSONData.urlSafeBase64EncodedString()

        let toSign = Data((headerBase64String + "." + payloadBase64String).utf8)

        let signature = HMAC<SHA256>.authenticationCode(for: toSign, using: privateKey)
        let signatureBase64String = Data(signature).urlSafeBase64EncodedString()

        let token = [headerBase64String, payloadBase64String, signatureBase64String].joined(separator: ".")
        print("Generating token for user \(userId)")
        return token
    }

    func getBridgeSignature() throws -> String {
        // ⚠️ the content of this function is for the sample uniquely, in order to create a token easilly without
        // depending on a backend.
        // In your app, you should proably call a backend route that provides you this token.
        guard let secret = Bundle.main.infoDictionary!["CLIENT_USER_TOKEN_SECRET"] as? String else {
            print("This example won't work because you need to sign the token")
            return ""
        }
        let privateKey = SymmetricKey(data: Data(secret.utf8))

        let headerJSONData = try JSONEncoder().encode(Header())
        let headerBase64String = headerJSONData.urlSafeBase64EncodedString()

        let payloadJSONData = try JSONEncoder().encode(
            BridgePostPayload(exp: Int(Date().addingTimeInterval(60 * 60).timeIntervalSince1970))
        )
        let payloadBase64String = payloadJSONData.urlSafeBase64EncodedString()

        let toSign = Data((headerBase64String + "." + payloadBase64String).utf8)

        let signature = HMAC<SHA256>.authenticationCode(for: toSign, using: privateKey)
        let signatureBase64String = Data(signature).urlSafeBase64EncodedString()

        let token = [headerBase64String, payloadBase64String, signatureBase64String].joined(separator: ".")
        print("Generating bridge post signature")
        return token
    }
}

private extension Data {
    func urlSafeBase64EncodedString() -> String {
        return base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}
