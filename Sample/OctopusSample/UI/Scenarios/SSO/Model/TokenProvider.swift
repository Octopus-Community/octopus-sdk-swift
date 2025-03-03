//
//  Copyright © 2025 Octopus Community. All rights reserved.
//

import Foundation
import CryptoKit

/// ⚠️ the content of this class is for the sample uniquely, in order to create a token easilly without
/// depending on a backend.
/// In your app, you should probably call a backend route that provides you this token.
class TokenProvider {
    struct Header: Encodable {
        let alg = "HS256"
        let typ = "JWT"
    }

    struct Payload: Encodable {
        let sub: String
        let exp: Int
    }

    func getToken(userId: String) async throws -> String {
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

        let payloadJSONData = try JSONEncoder().encode(Payload(sub: userId,
                                                               exp: Int(Date.distantFuture.timeIntervalSince1970)))
        let payloadBase64String = payloadJSONData.urlSafeBase64EncodedString()

        let toSign = Data((headerBase64String + "." + payloadBase64String).utf8)

        let signature = HMAC<SHA256>.authenticationCode(for: toSign, using: privateKey)
        let signatureBase64String = Data(signature).urlSafeBase64EncodedString()

        let token = [headerBase64String, payloadBase64String, signatureBase64String].joined(separator: ".")
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
