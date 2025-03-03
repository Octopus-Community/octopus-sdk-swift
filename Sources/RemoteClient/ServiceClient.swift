//
//  Copyright © 2024 Octopus Community. All rights reserved.
//

import Foundation
import GRPC

class ServiceClient {
    private let apiKey: String
    private let sdkVersion: String

    init(apiKey: String, sdkVersion: String) {
        self.apiKey = apiKey
        self.sdkVersion = sdkVersion
    }

    func callRemote<T>(_ authenticationMethod: AuthenticationMethod, _ block: () async throws -> T) async throws(RemoteClientError) -> T {
        do {
            return try await block()
        } catch {
            if case let .authenticated(_, authFailed) = authenticationMethod,
               let grpcStatus = error as? GRPCStatus, grpcStatus.code == .unauthenticated {
                authFailed()
            }
            throw RemoteClientError(error: error)
        }
    }

    func getCallOptions(authenticationMethod: AuthenticationMethod) -> CallOptions {
        var metadata = [
            ("ApiKey", apiKey),
            ("Accept-Language", Bundle.main.preferredLocalizations[0]),
            ("platform", "iOS"),
            ("sdkVersion", sdkVersion)]
        if let bundleIdentifier = Bundle.main.bundleIdentifier {
            metadata.append(("app", bundleIdentifier))
        }
        if let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String {
            metadata.append(("appVersion", appVersion))
        }
        switch authenticationMethod {
        case .authenticated(token: let userToken, _):
            metadata.append(("Authorization", "Bearer \(userToken)"))
        case .notAuthenticated: break
        }
        return CallOptions(customMetadata: .init(metadata))
    }
}
