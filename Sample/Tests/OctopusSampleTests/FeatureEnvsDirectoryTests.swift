//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import XCTest
@testable import OctopusSample

final class FeatureEnvsDirectoryTests: XCTestCase {

    /// Pinned so the expiry filter is tested against a fixed date: the fixture's live envs expire on
    /// 2026-08-10 and 2026-08-14, and its deliberately-expired one on 2026-07-15.
    private let now = ISO8601DateFormatter().date(from: "2026-08-05T00:00:00Z")!

    private func decodedFixture() throws -> [FeatureEnv] {
        try FeatureEnvsDirectory.decode(try fixture(), now: now)
    }

    private func fixture() throws -> Data {
        let url = try XCTUnwrap(Bundle(for: Self.self).url(forResource: "feature-envs-sample",
                                                           withExtension: "json"))
        return try Data(contentsOf: url)
    }

    func testStripsSchemeFromApiEndpoint() throws {
        let envs = try decodedFixture()
        let beta = try XCTUnwrap(envs.first { $0.name == "feat-beta" })
        XCTAssertEqual(beta.endpoints.api, "api-feat-beta.example.com")
    }

    func testBareHostHandlesEveryShape() {
        XCTAssertEqual(FeatureEnvsDirectory.bareHost(from: "https://api-x.example.com"), "api-x.example.com")
        XCTAssertEqual(FeatureEnvsDirectory.bareHost(from: "http://api-x.example.com"), "api-x.example.com")
        XCTAssertEqual(FeatureEnvsDirectory.bareHost(from: "api-x.example.com"), "api-x.example.com")
        XCTAssertEqual(FeatureEnvsDirectory.bareHost(from: "https://api-x.example.com/"), "api-x.example.com")
    }

    func testDropsEnvWithoutApiEndpointOrCommunities() throws {
        let names = try decodedFixture().map(\.name)
        XCTAssertFalse(names.contains("feat-no-endpoint"))
        XCTAssertFalse(names.contains("feat-no-community"))
        XCTAssertEqual(names.count, 2)
    }

    func testSortsActiveFirstThenSoonestExpiry() throws {
        let names = try decodedFixture().map(\.name)
        XCTAssertEqual(names, ["feat-beta", "feat-alpha"])
    }

    func testDisplayNameFallsBackToEnvNameWhenTicketIsNull() throws {
        let envs = try decodedFixture()
        let alpha = try XCTUnwrap(envs.first { $0.name == "feat-alpha" })
        XCTAssertNil(alpha.ticket)
        XCTAssertEqual(alpha.displayName, "feat-alpha")
        let beta = try XCTUnwrap(envs.first { $0.name == "feat-beta" })
        XCTAssertEqual(beta.displayName, "OCT-1000")
    }

    func testDecodesDatesAndOptionalCommunityDescription() throws {
        let envs = try decodedFixture()
        let beta = try XCTUnwrap(envs.first { $0.name == "feat-beta" })
        // The directory sends fractional seconds ("2026-08-10T22:55:19.366Z"), which the default
        // ISO8601 formatter rejects — hence the two formatters in the decoder.
        let expected = try XCTUnwrap(ISO8601DateFormatter().date(from: "2026-08-10T22:55:19Z"))
        XCTAssertEqual(beta.expiresAt.timeIntervalSince1970, expected.timeIntervalSince1970,
                       accuracy: 1)
        XCTAssertEqual(beta.communities.count, 2)
        XCTAssertEqual(beta.communities[0].description, "client key")
        XCTAssertNil(beta.communities[1].description)
    }

    func testMalformedPayloadThrows() {
        XCTAssertThrowsError(try FeatureEnvsDirectory.decode(Data("not json".utf8)))
    }

    // MARK: What the picker is allowed to show

    /// The directory does serve `status: "expired"` entries. One reaching the picker gets persisted on
    /// tap, dropped at launch as expired, and the switch to the *default* community then succeeds — so
    /// the developer sees no error and believes they are on the env.
    func testDropsExpiredEnvs() throws {
        let names = try decodedFixture().map(\.name)
        XCTAssertFalse(names.contains("feat-expired"))
    }

    /// A host `ApiServer` refuses (here: one carrying a path) would be listed and selectable, then fail
    /// to build an endpoint — leaving the SDK on the default backend with this env's API key.
    func testDropsEnvsWhoseHostApiServerRefuses() throws {
        let names = try decodedFixture().map(\.name)
        XCTAssertFalse(names.contains("feat-bad-host"))
    }

    /// An empty key reaches `OctopusSDK` unvalidated, so every call fails unauthenticated with nothing
    /// naming the cause.
    func testDropsEnvsWhoseOnlyCommunityHasNoApiKey() throws {
        let names = try decodedFixture().map(\.name)
        XCTAssertFalse(names.contains("feat-keyless"))
    }

    /// One unreadable env must not take the list down with it: the fixture carries a date-only
    /// `expiresAt`, which no ISO8601 form accepts.
    func testAMalformedEnvDropsItselfRatherThanTheWholeList() throws {
        let names = try decodedFixture().map(\.name)
        XCTAssertFalse(names.contains("feat-broken-date"))
        XCTAssertEqual(names, ["feat-beta", "feat-alpha"])
    }

    /// `id` comes from the payload, so duplicates would make `ForEach` behaviour undefined.
    func testDuplicateEnvIdsAreCollapsed() throws {
        let names = try decodedFixture().map(\.name)
        XCTAssertEqual(names.filter { $0 == "feat-alpha" }.count, 1)
    }

    /// The payload's own `expiresInDays` is computed when the directory generates its answer, so it goes
    /// stale; the countdown is derived from `expiresAt` instead.
    func testExpiresInDaysIsDerivedFromTheExpiryDate() throws {
        let beta = try XCTUnwrap(try decodedFixture().first { $0.name == "feat-beta" })
        // 2026-08-05 -> 2026-08-10: 5 days, whatever the payload claimed (7).
        XCTAssertEqual(beta.expiresInDays(now: now), 5)
    }

    func testHostValidityFollowsApiServerRules() {
        XCTAssertTrue(FeatureEnvsDirectory.isValidApiHost("api-x.example.com"))
        XCTAssertFalse(FeatureEnvsDirectory.isValidApiHost(""))
        XCTAssertFalse(FeatureEnvsDirectory.isValidApiHost("api-x.example.com/v1"))
        XCTAssertFalse(FeatureEnvsDirectory.isValidApiHost("https://api-x.example.com"))
    }

    /// `HTTPS://` is a valid scheme spelling; leaving it in place produced a host `ApiServer` refuses.
    func testBareHostStripsTheSchemeWhateverItsCase() {
        XCTAssertEqual(FeatureEnvsDirectory.bareHost(from: "HTTPS://api-x.example.com"), "api-x.example.com")
        XCTAssertEqual(FeatureEnvsDirectory.bareHost(from: "Http://api-x.example.com/"), "api-x.example.com")
    }

    // MARK: Request building and error reporting

    func testBuildsHttpsUrlFromTheBareHost() throws {
        let url = try FeatureEnvsDirectory.directoryUrl(host: "example.lambda-url.eu-west-3.on.aws",
                                                        token: "SECRET")
        XCTAssertEqual(url.scheme, "https")
        XCTAssertEqual(url.host, "example.lambda-url.eu-west-3.on.aws")
        XCTAssertEqual(url.query, "token=SECRET")
    }

    /// A host pasted with its scheme must still work rather than produce `https://https://…`.
    func testBuildsUrlEvenWhenTheHostWasPastedWithItsScheme() throws {
        let url = try FeatureEnvsDirectory.directoryUrl(host: "https://example.on.aws/",
                                                        token: "SECRET")
        XCTAssertEqual(url.scheme, "https")
        XCTAssertEqual(url.host, "example.on.aws")
    }

    func testMissingSecretsAreReportedAsNotConfigured() {
        for (host, token) in [("", "SECRET"), ("example.on.aws", "")] {
            XCTAssertThrowsError(try FeatureEnvsDirectory.directoryUrl(host: host, token: token)) { error in
                guard case .notConfigured = error as? FeatureEnvsError else {
                    return XCTFail("expected .notConfigured for host '\(host)', token '\(token)'")
                }
            }
        }
    }

    /// A present-but-malformed host used to be reported as "not configured", sending the developer
    /// looking for a secret that is in fact set.
    func testMalformedHostIsToldApartFromMissingSecrets() {
        XCTAssertThrowsError(try FeatureEnvsDirectory.directoryUrl(host: "not a host", token: "SECRET")) { error in
            guard case .invalidHost = error as? FeatureEnvsError else {
                return XCTFail("expected .invalidHost, got \(error)")
            }
        }
    }

    func testLoggableUrlDropsTheQueryCarryingTheToken() throws {
        let url = try FeatureEnvsDirectory.directoryUrl(host: "example.on.aws", token: "SECRET")
        let logged = FeatureEnvsDirectory.loggableUrl(url)
        XCTAssertEqual(logged, "https://example.on.aws/")
        XCTAssertFalse(logged.contains("SECRET"))
    }

    func testErrorMessagesPointAtTheRightFix() {
        XCTAssertTrue(FeatureEnvsError.unauthorized.userMessage.contains("OCTOPUS_FEATURE_ENVS_TOKEN"))
        XCTAssertTrue(FeatureEnvsError.notConfigured.userMessage.contains("OCTOPUS_FEATURE_ENVS_HOST"))
        XCTAssertFalse(FeatureEnvsError.badResponse(503).userMessage.isEmpty)
    }

    // MARK: Selection, expiry guard and persistence

    func testSelectionKeepsBareHostAndTicketFromEnv() throws {
        let env = try XCTUnwrap(try decodedFixture()
            .first { $0.name == "feat-beta" })
        let selection = FeatureEnvSelection(env: env, community: env.communities[0])
        XCTAssertEqual(selection.apiHost, "api-feat-beta.example.com")
        XCTAssertEqual(selection.ticket, "OCT-1000")
        XCTAssertEqual(selection.displayName, "OCT-1000")
        XCTAssertEqual(selection.apiKey, "key-c2")
        XCTAssertEqual(selection.expiresAt, env.expiresAt)
    }

    func testExpiryGuardUsesThePersistedDate() {
        let past = FeatureEnvSelection(envName: "e", ticket: nil, apiHost: "h",
                                       expiresAt: Date(timeIntervalSince1970: 1_000),
                                       communityId: "c", communityName: "n", apiKey: "k")
        let future = FeatureEnvSelection(envName: "e", ticket: nil, apiHost: "h",
                                         expiresAt: Date(timeIntervalSince1970: 4_000_000_000),
                                         communityId: "c", communityName: "n", apiKey: "k")
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        XCTAssertTrue(past.isExpired(now: now))
        XCTAssertFalse(future.isExpired(now: now))
    }

    /// `ApiServer.init` throws on a host carrying a scheme, a path or whitespace. A selection that
    /// cannot produce a valid endpoint must yield nil rather than crash the launch path.
    func testApiServerIsBuiltOnlyFromAValidBareHost() {
        let expiry = Date(timeIntervalSince1970: 4_000_000_000)
        let valid = FeatureEnvSelection(envName: "e", ticket: nil, apiHost: "api-x.example.com",
                                        expiresAt: expiry, communityId: "c", communityName: "n",
                                        apiKey: "k")
        XCTAssertEqual(valid.apiServer()?.host, "api-x.example.com")
        XCTAssertEqual(valid.apiServer()?.port, 443)

        for badHost in ["https://api-x.example.com", "api-x.example.com/path", "api x.example.com", ""] {
            let invalid = FeatureEnvSelection(envName: "e", ticket: nil, apiHost: badHost,
                                              expiresAt: expiry, communityId: "c", communityName: "n",
                                              apiKey: "k")
            XCTAssertNil(invalid.apiServer(), "\(badHost) should not produce an ApiServer")
        }
    }

    func testSdkConfigWithFeatureEnvRoundTripsThroughCodable() throws {
        let selection = FeatureEnvSelection(envName: "feat-x", ticket: "OCT-1", apiHost: "api-x.example.com",
                                            expiresAt: Date(timeIntervalSince1970: 1_800_000_000),
                                            communityId: "c", communityName: "Seed", apiKey: "k")
        let config = SDKConfig(authKind: .octopus).with(featureEnv: selection)
        let decoded = try JSONDecoder().decode(SDKConfig.self, from: try JSONEncoder().encode(config))
        XCTAssertEqual(decoded.featureEnv, selection)
        XCTAssertNil(decoded.with(featureEnv: nil).featureEnv)
    }

    /// Configs persisted before this feature must keep decoding.
    func testLegacySdkConfigWithoutFeatureEnvStillDecodes() throws {
        let legacy = try JSONEncoder().encode(LegacySDKConfig(authKind: .init(octopus: .init())))
        let decoded = try JSONDecoder().decode(SDKConfig.self, from: legacy)
        XCTAssertNil(decoded.featureEnv)
    }

    // MARK: Launch-argument resolution (`-featureEnvTicket`)

    func testResolvesByTicketAndTakesTheFirstCommunityByDefault() throws {
        let envs = try decodedFixture()
        let selection = try XCTUnwrap(FeatureEnvSelection.resolve(ticket: "OCT-1000", communityHint: nil,
                                                                 in: envs))
        XCTAssertEqual(selection.envName, "feat-beta")
        XCTAssertEqual(selection.communityId, "C2")
    }

    func testTicketMatchIsCaseInsensitive() throws {
        let envs = try decodedFixture()
        XCTAssertNotNil(FeatureEnvSelection.resolve(ticket: "oct-1000", communityHint: nil, in: envs))
    }

    /// An env whose `ticket` is null must stay reachable by its name, otherwise 3 of the 5 live envs
    /// could not be targeted from the command line at all.
    func testResolvesByEnvNameWhenTicketIsNull() throws {
        let envs = try decodedFixture()
        let selection = try XCTUnwrap(FeatureEnvSelection.resolve(ticket: "feat-alpha",
                                                                 communityHint: nil, in: envs))
        XCTAssertEqual(selection.communityId, "C1")
    }

    func testCommunityHintPicksByIdOrNameFragment() throws {
        let envs = try decodedFixture()
        let byId = try XCTUnwrap(FeatureEnvSelection.resolve(ticket: "OCT-1000", communityHint: "C3",
                                                            in: envs))
        XCTAssertEqual(byId.communityId, "C3")
        let byName = try XCTUnwrap(FeatureEnvSelection.resolve(ticket: "OCT-1000", communityHint: "sandbox b",
                                                              in: envs))
        XCTAssertEqual(byName.communityId, "C3")
    }

    func testUnknownTicketOrHintResolvesToNothing() throws {
        let envs = try decodedFixture()
        XCTAssertNil(FeatureEnvSelection.resolve(ticket: "OCT-9000", communityHint: nil, in: envs))
        XCTAssertNil(FeatureEnvSelection.resolve(ticket: "OCT-1000", communityHint: "nope", in: envs))
    }

    /// Mirrors what `SDKConfig` encoded to before `featureEnv` existed.
    private struct LegacySDKConfig: Encodable {
        struct AuthKind: Encodable {
            struct Octopus: Encodable { }
            let octopus: Octopus
        }
        let authKind: AuthKind
    }
}
