//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import Combine
import XCTest
@testable import OctopusSample

/// Configuration: the key-derivation rule, the SSO user chips, the summaries, the Apply outcome line, and the
/// draft the Configuration screen turns into a persisted config.
@MainActor
final class SampleConfigTests: XCTestCase {
    private let pastedKey = "test-pasted-key-0123456789"
    private let featureEnv = FeatureEnvSelection(envName: "env-one", ticket: "TICKET-1", apiHost: "api.env.test",
                                                 expiresAt: Date().addingTimeInterval(86_400),
                                                 communityId: "community-1", communityName: "Env community",
                                                 apiKey: "test-feature-env-key-0123")

    // MARK: - Presets

    func testPresetsResolveFromForceLoginAndManagedFields() {
        XCTAssertEqual(AuthPreset.resolve(forceLogin: false, managedFields: []).id, AuthPreset.noManagedNoForced.id)
        XCTAssertEqual(AuthPreset.resolve(forceLogin: true, managedFields: []).id, AuthPreset.noManagedForced.id)
        XCTAssertEqual(AuthPreset.resolve(forceLogin: false, managedFields: SDKConfig.ProfileField.allCases).id,
                       AuthPreset.allManagedForced.id)
        XCTAssertEqual(AuthPreset.resolve(forceLogin: true, managedFields: [.nickname]).id,
                       AuthPreset.someManagedForced.id)
        XCTAssertEqual(AuthPreset.all.map(\.id), ["ssoNoManagedNoForced", "ssoNoManagedForced",
                                                  "ssoAllManagedForced", "ssoSomeManagedForced"])
    }

    func testOnlyTheDemoBackendShapesHaveACommunity() {
        XCTAssertTrue(AuthPreset.hasDemoCommunity(managedFields: []))
        XCTAssertTrue(AuthPreset.hasDemoCommunity(managedFields: SDKConfig.ProfileField.allCases))
        XCTAssertTrue(AuthPreset.hasDemoCommunity(managedFields: [.nickname, .picture]))
        XCTAssertFalse(AuthPreset.hasDemoCommunity(managedFields: [.bio]))
        XCTAssertFalse(AuthPreset.hasDemoCommunity(managedFields: [.picture]))
    }

    // MARK: - SSO user chips

    func testUserChipsAppendACustomStoredIdOnce() {
        XCTAssertEqual(SampleUserIds.picker(storedUserId: nil), SampleUserIds.predefined)
        XCTAssertEqual(SampleUserIds.picker(storedUserId: "qa-tester-ios"), SampleUserIds.predefined)
        XCTAssertEqual(SampleUserIds.picker(storedUserId: "  custom-user "), SampleUserIds.predefined + ["custom-user"])
        XCTAssertEqual(SampleUserIds.picker(storedUserId: "   "), SampleUserIds.predefined)
    }

    // MARK: - Summaries

    func testSummariesNameTheServerTheCommunityAndTheKeySource() {
        let demo = SDKConfig(authKind: .sso(appManagedFields: [], forceLoginOnStrongActions: false))
        XCTAssertEqual(SampleConfigSummary.serverEnvironment(demo), "Demo")
        XCTAssertEqual(SampleConfigSummary.community(demo), "Demo community")
        XCTAssertEqual(SampleConfigSummary.apiKeySource(demo), "Demo preset · \(AuthPreset.noManagedNoForced.label)")

        let custom = SDKConfig(authKind: demo.authKind, customServer: .init(host: "api.custom.test", port: 443),
                               customApiKey: pastedKey)
        XCTAssertEqual(SampleConfigSummary.serverEnvironment(custom), "Custom")
        XCTAssertEqual(SampleConfigSummary.community(custom), "Custom community")
        XCTAssertEqual(SampleConfigSummary.apiKeySource(custom), "Custom · test…6789")
        XCTAssertEqual(SampleConfigSummary.resolvedApiKey(custom, featureEnv: nil), pastedKey)

        let prod = SDKConfig(authKind: demo.authKind, customServer: .prod)
        XCTAssertEqual(SampleConfigSummary.serverEnvironment(prod), "Prod")

        let env = custom.with(featureEnv: featureEnv)
        XCTAssertEqual(SampleConfigSummary.serverEnvironment(env), "Feature env · TICKET-1")
        XCTAssertEqual(SampleConfigSummary.community(env), "Env community")
        XCTAssertEqual(SampleConfigSummary.resolvedApiKey(env, featureEnv: featureEnv), featureEnv.apiKey)
    }

    func testApplyOutcomeSaysWhatTheTapDoes() {
        let demo = SDKConfig(authKind: .sso(appManagedFields: [], forceLoginOnStrongActions: false))
        let forced = demo.with(authKind: .sso(appManagedFields: [], forceLoginOnStrongActions: true))
        XCTAssertTrue(SampleConfigSummary.applyOutcome(persisted: nil, next: demo, userChanged: true,
                                                       appearanceChanged: false).hasPrefix("Starting the SDK · "))
        XCTAssertTrue(SampleConfigSummary.applyOutcome(persisted: demo, next: forced, userChanged: false,
                                                       appearanceChanged: false).hasPrefix("Applied · restarting"))
        XCTAssertEqual(SampleConfigSummary.applyOutcome(persisted: demo, next: demo, userChanged: true,
                                                        appearanceChanged: true),
                       "Applied · connecting the new user, no SDK restart needed")
        XCTAssertEqual(SampleConfigSummary.applyOutcome(persisted: demo, next: demo, userChanged: false,
                                                        appearanceChanged: true),
                       "Applied · no SDK restart needed")
        XCTAssertEqual(SampleConfigSummary.applyOutcome(persisted: demo, next: demo, userChanged: false,
                                                        appearanceChanged: false),
                       "Nothing to apply · the configuration is unchanged")
    }

    func testAConfigSavedBeforeTheNewFieldsStillDecodes() throws {
        let legacy = SDKConfig(authKind: .sso(appManagedFields: [.nickname], forceLoginOnStrongActions: true))
        let data = try JSONEncoder().encode(legacy)
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        XCTAssertEqual(Array(object.keys), ["authKind"])
        let decoded = try JSONDecoder().decode(SDKConfig.self, from: data)
        XCTAssertEqual(decoded, legacy)
        XCTAssertNil(decoded.customServer)
        XCTAssertNil(decoded.customApiKey)
    }

    func testForceLoginIsNotOfferedOnAPastedKey() {
        let demo = SDKConfig(authKind: .sso(appManagedFields: [], forceLoginOnStrongActions: false))
        XCTAssertTrue(FeatureToggles.isForceLoginAvailable(config: demo, internalDemoMode: true))
        var custom = demo
        custom.customApiKey = pastedKey
        XCTAssertFalse(FeatureToggles.isForceLoginAvailable(config: custom, internalDemoMode: true))
    }

    // MARK: - About

    func testInstallSourceReadsTheReceipt() {
        let sandbox = URL(fileURLWithPath: "/receipt/sandboxReceipt")
        let store = URL(fileURLWithPath: "/receipt/receipt")
        XCTAssertEqual(SampleInstallSource.detect(receiptURL: sandbox, fileExists: { _ in true }), .testFlight)
        XCTAssertEqual(SampleInstallSource.detect(receiptURL: store, fileExists: { _ in true }), .appStore)
        XCTAssertEqual(SampleInstallSource.detect(receiptURL: store, fileExists: { _ in false }), .development)
        XCTAssertEqual(SampleInstallSource.detect(receiptURL: nil), .development)
    }

    // MARK: - Configuration draft

    private func makeViewModel(saved: SDKConfig?, storedUserId: String? = nil,
                               isRevisit: Bool = true) -> ConfigViewModel {
        ConfigViewModel(isRevisit: isRevisit, savedConfig: { saved }, storedUserId: storedUserId,
                        appearance: .system, themePreset: .octopusNavy, featureEnvsConfigured: false,
                        unifiedProfile: Just(.switched(false)).eraseToAnyPublisher())
    }

    func testAFirstStartPreselectsTheDemoUserAndTheDemoServer() {
        let viewModel = makeViewModel(saved: nil, isRevisit: false)
        XCTAssertEqual(viewModel.ssoUserId, "ios-sample-user")
        XCTAssertEqual(viewModel.serverKind, .demo)
        XCTAssertEqual(viewModel.resolvedPreset.id, AuthPreset.noManagedNoForced.id)
        XCTAssertNil(viewModel.applyBlocker)
        XCTAssertFalse(viewModel.showsFeatureEnvOption)

        let revisit = makeViewModel(saved: SDKConfig(authKind: .sso(appManagedFields: [])))
        XCTAssertNil(revisit.ssoUserId)
        XCTAssertEqual(makeViewModel(saved: nil, storedUserId: "custom-user").ssoUserId, "custom-user")
    }

    func testPickingAPresetKeepsAMatchingSubset() {
        let saved = SDKConfig(authKind: .sso(appManagedFields: [.nickname], forceLoginOnStrongActions: true))
        let viewModel = makeViewModel(saved: saved)
        viewModel.applyAuthPreset(.someManagedForced)
        XCTAssertEqual(viewModel.managedFields, [.nickname])
        viewModel.applyAuthPreset(.noManagedNoForced)
        XCTAssertEqual(viewModel.managedFields, [])
        XCTAssertFalse(viewModel.forceLogin)
        viewModel.applyAuthPreset(.someManagedForced)
        XCTAssertEqual(viewModel.managedFields, [.nickname, .picture])
        XCTAssertTrue(viewModel.forceLogin)
    }

    func testApplyIsRefusedWithoutAMatchingCommunityOrAKey() {
        let viewModel = makeViewModel(saved: SDKConfig(authKind: .sso(appManagedFields: [.nickname])))
        viewModel.toggleManagedField(.nickname)
        viewModel.toggleManagedField(.bio)
        XCTAssertEqual(viewModel.applyBlocker, "No existing community to match this configuration")

        viewModel.setUseCustomCommunity()
        XCTAssertEqual(viewModel.applyBlocker, "Paste an API key")
        viewModel.customApiKey = "  \(pastedKey) "
        XCTAssertNil(viewModel.applyBlocker)

        viewModel.setServerKind(.custom)
        viewModel.customHost = "https://api.custom.test/path"
        XCTAssertEqual(viewModel.applyBlocker, "Enter a host and a port the SDK accepts")
        viewModel.customHost = "api.custom.test"
        XCTAssertNil(viewModel.applyBlocker)
    }

    func testTheConfigKeepsOnlyWhatTheChosenModeUses() {
        let saved = SDKConfig(authKind: .sso(appManagedFields: []), featureEnv: featureEnv)
        let viewModel = makeViewModel(saved: saved)
        XCTAssertEqual(viewModel.serverKind, .featureEnv)
        XCTAssertTrue(viewModel.showsFeatureEnvOption)
        XCTAssertEqual(viewModel.makeConfig(persisted: saved), saved)
        XCTAssertEqual(viewModel.communitySummary, "Feature env · test…0123")

        viewModel.setServerKind(.custom)
        viewModel.customHost = "api.custom.test"
        viewModel.customPort = "8443"
        viewModel.setUseCustomCommunity()
        viewModel.customApiKey = " \(pastedKey) "
        let custom = viewModel.makeConfig(persisted: saved)
        XCTAssertNil(custom.featureEnv)
        XCTAssertEqual(custom.customServer, SDKConfig.CustomServer(host: "api.custom.test", port: 8443))
        XCTAssertEqual(custom.customApiKey, pastedKey)
        XCTAssertEqual(viewModel.communitySummary, "Custom API key · test…6789")

        viewModel.setServerKind(.demo)
        viewModel.applyAuthPreset(.noManagedForced)
        let demo = viewModel.makeConfig(persisted: custom)
        XCTAssertNil(demo.customServer)
        XCTAssertNil(demo.customApiKey)
        XCTAssertEqual(demo.authKind, .sso(appManagedFields: [], forceLoginOnStrongActions: true))
        XCTAssertEqual(viewModel.confirmTarget, "default")
    }

    func testProdTargetsTheProdHostWithTheSameKeyAndIsReadBack() {
        let viewModel = makeViewModel(saved: SDKConfig(authKind: .sso(appManagedFields: [])))
        viewModel.setServerKind(.prod)
        XCTAssertNil(viewModel.applyBlocker)
        XCTAssertEqual(viewModel.confirmTarget, "api.8pus.io (PROD)")
        let prod = viewModel.makeConfig(persisted: nil)
        XCTAssertEqual(prod.customServer, SDKConfig.CustomServer(host: "api.8pus.io", port: 443))
        XCTAssertNil(prod.customApiKey)
        XCTAssertNil(prod.featureEnv)

        let reopened = makeViewModel(saved: prod)
        XCTAssertEqual(reopened.serverKind, .prod)
        XCTAssertEqual(reopened.makeConfig(persisted: prod), prod)
    }
}
