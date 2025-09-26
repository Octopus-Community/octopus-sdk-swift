//
//  Copyright © 2024 Octopus Community. All rights reserved.
//

import Foundation
import GRPC
import UIKit

class ServiceClient {
    private let apiKey: String
    private let sdkVersion: String
    private let installId: String

    var appSessionId: String?
    var octopusUISessionId: String?
    var hasAccessToCommunity: Bool?

    /// OSVersion container that can be accessed by a non isolated call
    private let sendableOSVersion = SendableOSVersion()
    // OS Version. Set on the main thread because UIDevice.current.systemVersion is main actor
    var osVersion: String? { sendableOSVersion.value }

    init(apiKey: String, sdkVersion: String, installId: String) {
        self.apiKey = apiKey
        self.sdkVersion = sdkVersion
        self.installId = installId

        let osVersionBox = sendableOSVersion

        Task { @MainActor in
            let version = UIDevice.current.systemVersion
            osVersionBox.value = version
        }
    }

    func callRemote<T>(_ authenticationMethod: AuthenticationMethod, _ block: () async throws -> T) async throws(RemoteClientError) -> T {
        do {
            return try await block()
        } catch {
            if case let .authenticated(_, authFailed) = authenticationMethod,
               let grpcStatus = error as? GRPCStatus, grpcStatus.code == .unauthenticated,
               // do not call authFailed in case of user banned
               !(grpcStatus.message?.contains("Your account has been blocked") ?? false) {
                authFailed()
            }
            throw RemoteClientError(error: error)
        }
    }

    func getCallOptions(authenticationMethod: AuthenticationMethod) -> CallOptions {
        let hasAccessToCommunityValue = switch hasAccessToCommunity {
        case .some(true): "true"
        case .some(false): "false"
        case .none: "not_provided"
        }
        var metadata = [
            ("ApiKey", apiKey),
            ("Accept-Language", Bundle.main.preferredLocalizations[0]),
            ("platform", "iOS"),
            ("sdkVersion", sdkVersion),
            ("installId", installId),
            ("hascommunityaccess", hasAccessToCommunityValue)]
        if let osVersion {
            metadata.append(("osversion", osVersion))
        }
        if let bundleIdentifier = Bundle.main.bundleIdentifier {
            metadata.append(("app", bundleIdentifier))
        }
        if let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String {
            metadata.append(("appVersion", appVersion))
        }
        if let appSessionId {
            metadata.append(("appSessionId", appSessionId))
        }
        if let octopusUISessionId {
            metadata.append(("octoSessionId", octopusUISessionId))
        }
        switch authenticationMethod {
        case .authenticated(token: let userToken, _):
            metadata.append(("Authorization", "Bearer \(userToken)"))
        case .notAuthenticated: break
        }
        return CallOptions(customMetadata: .init(metadata))
    }
}

// Helper class with no self-capture — just a way to pass around the value
private final class SendableOSVersion: @unchecked Sendable {
    var value: String?
}
