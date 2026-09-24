//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import Foundation
import Octopus

/// One backend feature environment, as published by the infra directory.
struct FeatureEnv: Decodable, Identifiable {

    struct Endpoints: Decodable {
        /// Bare host (no scheme, no trailing slash): what `OctopusSDK.Configuration.ApiServer` expects.
        let api: String
        let backoffice: String?

        /// Declared explicitly: a custom `init(from:)` on a `Decodable`-only type gets no synthesized
        /// `CodingKeys` (the synthesis that used to provide them came from `Encodable`, dropped here
        /// since nothing ever encodes these types).
        private enum CodingKeys: String, CodingKey {
            case api, backoffice
        }

        init(api: String, backoffice: String?) {
            self.api = api
            self.backoffice = backoffice
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            let rawApi = try container.decodeIfPresent(String.self, forKey: .api) ?? ""
            api = rawApi.isEmpty ? "" : FeatureEnvsDirectory.bareHost(from: rawApi)
            backoffice = try container.decodeIfPresent(String.self, forKey: .backoffice)
        }
    }

    struct Community: Decodable, Identifiable {
        var id: String { communityId }
        let communityId: String
        let communityName: String
        let apiKey: String
        let description: String?
    }

    var id: String { name }
    let name: String
    let status: String
    let owner: String
    let branch: String
    /// Declarative on the backend side: null on several envs, so never assume it is there.
    let ticket: String?
    let expiresAt: Date
    let endpoints: Endpoints
    let communities: [Community]

    private enum CodingKeys: String, CodingKey {
        case name, status, owner, branch, ticket, expiresAt, endpoints, communities
    }

    /// Only `name`, `expiresAt`, `endpoints` and `communities` are required: those four are what the
    /// Sample actually needs to target an env. The descriptive fields default to empty so one env missing
    /// a cosmetic key cannot take the whole list down with it.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        name = try container.decode(String.self, forKey: .name)
        expiresAt = try container.decode(Date.self, forKey: .expiresAt)
        endpoints = try container.decodeIfPresent(Endpoints.self, forKey: .endpoints)
            ?? Endpoints(api: "", backoffice: nil)
        communities = try container.decodeIfPresent([Community].self, forKey: .communities) ?? []
        status = try container.decodeIfPresent(String.self, forKey: .status) ?? ""
        owner = try container.decodeIfPresent(String.self, forKey: .owner) ?? ""
        branch = try container.decodeIfPresent(String.self, forKey: .branch) ?? ""
        ticket = try container.decodeIfPresent(String.self, forKey: .ticket)
    }

    /// What the picker shows first: the ticket when the backend filled it, the env name otherwise.
    var displayName: String { ticket ?? name }

    var isActive: Bool { status == "active" }

    func isExpired(now: Date = Date()) -> Bool { expiresAt <= now }

    /// Derived from `expiresAt`, not read from the payload: the directory computes its own
    /// `expiresInDays` when it generates the answer, so it goes stale as soon as the day rolls over.
    func expiresInDays(now: Date = Date()) -> Int {
        max(0, Calendar.current.dateComponents([.day], from: now, to: expiresAt).day ?? 0)
    }

    /// Whether the Sample can actually target this env: an endpoint the SDK accepts, and at least one
    /// community with a key to authenticate with.
    ///
    /// The host goes through `ApiServer`'s own validation rather than a non-emptiness test — it rejects a
    /// port, a path, whitespace or a leftover scheme, and an env failing it later would be listed,
    /// selectable, and then silently unusable.
    func isUsable(now: Date = Date()) -> Bool {
        !isExpired(now: now) && FeatureEnvsDirectory.isValidApiHost(endpoints.api) && !usableCommunities.isEmpty
    }

    /// Communities with a key, deduplicated by id.
    ///
    /// An empty `apiKey` reaches `OctopusSDK` unvalidated and turns every gRPC call into an
    /// unauthenticated failure with nothing pointing at the cause; duplicate ids would make the
    /// `ForEach` rendering them undefined.
    var usableCommunities: [Community] {
        var seen = Set<String>()
        return communities.filter { !$0.apiKey.isEmpty && seen.insert($0.id).inserted }
    }
}

struct FeatureEnvsResponse: Decodable {
    /// Never used by the Sample, so its absence must not fail the payload.
    let generatedAt: Date?
    let featureEnvs: [FeatureEnv]

    private enum CodingKeys: String, CodingKey {
        case generatedAt, featureEnvs
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        generatedAt = try? container.decodeIfPresent(Date.self, forKey: .generatedAt)
        // Element-wise failable decoding: one malformed env (an unreadable date, a missing `name`) drops
        // itself instead of failing the whole list with a generic "cannot read".
        featureEnvs = (try container.decodeIfPresent([FailableDecodable<FeatureEnv>].self, forKey: .featureEnvs) ?? [])
            .compactMap(\.value)
    }
}

/// Decodes `T`, or nothing, without propagating the failure to the enclosing container.
private struct FailableDecodable<T: Decodable>: Decodable {
    let value: T?

    init(from decoder: Decoder) throws {
        value = try? T(from: decoder)
    }
}

/// Decoding and ordering of the feature-env directory. No networking here so it stays testable.
enum FeatureEnvsDirectory {

    /// Decodes the directory payload, drops envs the Sample cannot use, and orders them for display.
    ///
    /// Unusable means: expired, no endpoint `ApiServer` accepts, or no community carrying a key. Expired
    /// envs are dropped rather than merely sorted last — the directory does serve them, and one that
    /// reaches the picker gets persisted, then dropped at launch, leaving the developer on the default
    /// community believing they are on the env.
    ///
    /// `now` is injected so the expiry rule is testable against a fixed date instead of drifting with the
    /// calendar.
    static func decode(_ data: Data, now: Date = Date()) throws -> [FeatureEnv] {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let raw = try decoder.singleValueContainer().decode(String.self)
            guard let date = iso8601WithFraction.date(from: raw) ?? iso8601.date(from: raw) else {
                throw DecodingError.dataCorrupted(
                    .init(codingPath: decoder.codingPath, debugDescription: "Unreadable date: \(raw)"))
            }
            return date
        }
        let response = try decoder.decode(FeatureEnvsResponse.self, from: data)
        let usable = response.featureEnvs.filter { env in
            guard env.isUsable(now: now) else {
                // Logged, not silent: an env missing from the picker is otherwise indistinguishable from
                // an env the directory never sent.
                print("Feature env \(env.name) skipped: expired, unusable host '\(env.endpoints.api)', "
                      + "or no community with a key")
                return false
            }
            return true
        }
        // `Identifiable` ids come from the payload (`name`, `communityId`); duplicates would make
        // `ForEach` behaviour undefined, so the first occurrence wins.
        return deduplicated(usable)
            .sorted {
                if $0.isActive != $1.isActive { return $0.isActive }
                return $0.expiresAt < $1.expiresAt
            }
    }

    /// Strips the scheme and any trailing slash: `https://api-x.example.com` → `api-x.example.com`.
    /// The gRPC channel is built with `.host(_, port:)`, and `OCTOPUS_REMOTE_BASE_URL` is a bare host too.
    ///
    /// The scheme test is case-insensitive: `HTTPS://host` is a valid URL, and leaving the prefix in place
    /// would produce a host `ApiServer` rejects.
    static func bareHost(from urlString: String) -> String {
        var host = urlString
        for scheme in ["https://", "http://"] where host.lowercased().hasPrefix(scheme) {
            host = String(host.dropFirst(scheme.count))
        }
        while host.hasSuffix("/") { host = String(host.dropLast()) }
        return host
    }

    /// Whether `host` is one `OctopusSDK.Configuration.ApiServer` accepts.
    ///
    /// Delegates to the SDK's own throwing initializer instead of re-implementing its rules, which would
    /// drift from them.
    static func isValidApiHost(_ host: String) -> Bool {
        (try? OctopusSDK.Configuration.ApiServer(host: host, port: 443)) != nil
    }

    private static func deduplicated(_ envs: [FeatureEnv]) -> [FeatureEnv] {
        var seen = Set<String>()
        return envs.filter { seen.insert($0.id).inserted }
    }

    private static let iso8601WithFraction: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    private static let iso8601 = ISO8601DateFormatter()
}
