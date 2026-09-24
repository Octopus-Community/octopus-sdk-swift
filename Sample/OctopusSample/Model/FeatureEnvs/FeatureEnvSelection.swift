//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import Foundation
import Octopus

/// The feature env + community the Sample currently targets. Persisted inside `SDKConfig`.
///
/// `expiresAt` is stored so the launch-time guard needs no network call: an expired selection is
/// dropped before the SDK is created.
struct FeatureEnvSelection: Codable, Equatable {
    let envName: String
    let ticket: String?
    /// Bare host, ready for `OctopusSDK.Configuration.ApiServer`.
    let apiHost: String
    let expiresAt: Date
    let communityId: String
    let communityName: String
    let apiKey: String

    var displayName: String { ticket ?? envName }

    func isExpired(now: Date = Date()) -> Bool { expiresAt <= now }
}

/// Why a feature env could not be applied. `LocalizedError` so the view model's
/// `error.localizedDescription` carries the explanation instead of a type name.
enum FeatureEnvApplyError: LocalizedError {
    case expired(FeatureEnvSelection)

    var errorDescription: String? {
        switch self {
        case let .expired(selection):
            let expiry = DateFormatter.localizedString(from: selection.expiresAt,
                                                       dateStyle: .short, timeStyle: .short)
            return "\(selection.displayName) expired on \(expiry). Reload the list and pick a live env."
        }
    }
}

extension FeatureEnvSelection {
    init(env: FeatureEnv, community: FeatureEnv.Community) {
        self.init(envName: env.name,
                  ticket: env.ticket,
                  apiHost: env.endpoints.api,
                  expiresAt: env.expiresAt,
                  communityId: community.communityId,
                  communityName: community.communityName,
                  apiKey: community.apiKey)
    }

    /// Picks the env matching `ticket` (or `name`, so an env whose ticket is null stays reachable) and one
    /// of its communities: the one whose id or name contains `communityHint`, the first one otherwise.
    ///
    /// Used by the launch-argument path (`-featureEnvTicket`), so QA tooling can target an env without
    /// walking the UI. Returns `nil` when nothing matches, and the caller keeps the default community.
    static func resolve(ticket: String, communityHint: String?, in envs: [FeatureEnv])
    -> FeatureEnvSelection? {
        let wanted = ticket.lowercased()
        guard let env = envs.first(where: { $0.ticket?.lowercased() == wanted })
                ?? envs.first(where: { $0.name.lowercased() == wanted }) else { return nil }
        // `usableCommunities`: one without an API key would switch the SDK to a community every call then
        // fails to authenticate against, with nothing naming the cause.
        let candidates = env.usableCommunities
        let community: FeatureEnv.Community? = if let hint = communityHint?.lowercased(), !hint.isEmpty {
            candidates.first {
                $0.communityId.lowercased() == hint || $0.communityName.lowercased().contains(hint)
            }
        } else {
            candidates.first
        }
        guard let community else { return nil }
        return FeatureEnvSelection(env: env, community: community)
    }

    /// The SDK endpoint for this selection, or `nil` when the stored host is not usable.
    ///
    /// `ApiServer.init(host:port:)` throws a `ValidationError` on an empty host, whitespace, a scheme,
    /// or a path — the directory should never send such a host, but the launch path must not trap on it.
    func apiServer() -> OctopusSDK.Configuration.ApiServer? {
        do {
            return try OctopusSDK.Configuration.ApiServer(host: apiHost, port: 443)
        } catch {
            print("Feature env \(displayName): unusable host '\(apiHost)' (\(error))")
            return nil
        }
    }
}
