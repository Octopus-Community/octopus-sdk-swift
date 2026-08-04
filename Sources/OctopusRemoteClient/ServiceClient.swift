//
//  Copyright © 2024 Octopus Community. All rights reserved.
//

import Foundation
#if canImport(GRPC)
import GRPC
#else
import GRPCSwift
#endif
import UIKit

class ServiceClient {
    private let apiKey: String
    private let sdkVersion: String
    private let installId: String

    var appSessionId: String?
    var octopusUISessionId: String?
    var hasAccessToCommunity: Bool?
    var localeIdentifier: String

    /// Maximum number of retries for transient gRPC `.unavailable` errors (e.g. "Transport became inactive").
    private static let maxUnavailableRetries = 2

    /// OSVersion container that can be accessed by a non isolated call
    private let sendableOSVersion = SendableOSVersion()
    // OS Version. Set on the main thread because UIDevice.current.systemVersion is main actor
    var osVersion: String? { sendableOSVersion.value }

    init(apiKey: String, sdkVersion: String, installId: String, localeIdentifier: String) {
        self.apiKey = apiKey
        self.sdkVersion = sdkVersion
        self.installId = installId
        self.localeIdentifier = localeIdentifier

        let osVersionBox = sendableOSVersion

        Task { @MainActor in
            let version = UIDevice.current.systemVersion
            osVersionBox.value = version
        }
    }

    func callRemote<T>(_ authenticationMethod: AuthenticationMethod, _ block: () async throws -> T) async throws(RemoteClientError) -> T {
        var lastError: Error?
        for attempt in 0...Self.maxUnavailableRetries {
            do {
                return try await block()
            } catch {
                lastError = error
                if let grpcStatus = error as? GRPCStatus, grpcStatus.code == .unavailable,
                   attempt < Self.maxUnavailableRetries {
                    continue
                }
                break
            }
        }
        let error = lastError!
        if case let .authenticated(token, authFailed) = authenticationMethod,
           let grpcStatus = error as? GRPCStatus, grpcStatus.code == .unauthenticated,
           // `unauthenticated` covers two opposite situations: the token is expired (the session must be
           // renewed) and the server refuses the action for a business reason — a banned user, mainly —
           // where the session must be kept so that the UI can display the server message.
           // Only an expired token justifies dropping the session, so ask the token itself instead of
           // matching the ban wording: that used to be the English sentence only, which logged banned
           // users out in every other locale. When the token carries no readable expiration, keep the
           // previous behaviour and renew the session.
           Jwt.isExpired(token) ?? true {
            authFailed()
        }
        throw RemoteClientError(error: error)
    }

    func getCallOptions(authenticationMethod: AuthenticationMethod) -> CallOptions {
        let hasAccessToCommunityValue = switch hasAccessToCommunity {
        case .some(true): "true"
        case .some(false): "false"
        case .none: "not_provided"
        }
        var metadata = [
            ("ApiKey", apiKey),
            ("Accept-Language", localeIdentifier),
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
