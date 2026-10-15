//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import XCTest
@testable import OctopusSample

/// Settings › Appearance and Host app integration persist their choices: defaults on a fresh install, values
/// read back by a new store, and Reset configuration going back to a complete integration.
final class SettingsStoresTests: XCTestCase {
    private var defaults: UserDefaults!
    private var suiteName: String!

    override func setUp() {
        super.setUp()
        suiteName = "SettingsStoresTests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        defaults = nil
        super.tearDown()
    }

    // MARK: - Appearance

    func testAppearanceDefaultsToSystemAndNavy() {
        let store = SampleAppearanceStore(defaults: defaults)
        XCTAssertEqual(store.appearance, .system)
        XCTAssertEqual(store.themePreset, .octopusNavy)
        XCTAssertEqual(SampleAppearance.system.userInterfaceStyle, .unspecified)
        XCTAssertEqual(SampleAppearance.dark.userInterfaceStyle, .dark)
    }

    func testAppearanceChoicesAreReadBackAndReset() {
        let store = SampleAppearanceStore(defaults: defaults)
        store.set(appearance: .dark)
        store.set(themePreset: .sdkDefault)

        let reloaded = SampleAppearanceStore(defaults: defaults)
        XCTAssertEqual(reloaded.appearance, .dark)
        XCTAssertEqual(reloaded.themePreset, .sdkDefault)

        reloaded.reset()
        XCTAssertEqual(reloaded.appearance, .system)
        XCTAssertEqual(reloaded.themePreset, .octopusNavy)
        XCTAssertEqual(SampleAppearanceStore(defaults: defaults).appearance, .system)
    }

    func testAnUnknownStoredAppearanceFallsBackToTheDefault() {
        defaults.set("sepia", forKey: SampleAppearanceStore.appearanceKey)
        XCTAssertEqual(SampleAppearanceStore(defaults: defaults).appearance, .system)
    }

    // MARK: - Host integration

    func testHostIntegrationIsCompleteByDefault() {
        let store = HostIntegrationStore(defaults: defaults)
        XCTAssertTrue(store.isProfileEditWired)
        XCTAssertTrue(store.isGroupAccessDeniedWired)
        XCTAssertEqual(store.urlPolicy, .sampleRule)
    }

    func testHostIntegrationChoicesAreReadBackAndReset() {
        let store = HostIntegrationStore(defaults: defaults)
        store.setProfileEditWired(false)
        store.setGroupAccessDeniedWired(false)
        store.set(urlPolicy: .alwaysOctopus)

        let reloaded = HostIntegrationStore(defaults: defaults)
        XCTAssertFalse(reloaded.isProfileEditWired)
        XCTAssertFalse(reloaded.isGroupAccessDeniedWired)
        XCTAssertEqual(reloaded.urlPolicy, .alwaysOctopus)

        reloaded.reset()
        let afterReset = HostIntegrationStore(defaults: defaults)
        XCTAssertTrue(afterReset.isProfileEditWired)
        XCTAssertTrue(afterReset.isGroupAccessDeniedWired)
        XCTAssertEqual(afterReset.urlPolicy, .sampleRule)
    }

    func testURLPolicyIdsMatchTheAndroidTestTags() {
        XCTAssertEqual(HostURLPolicy.allCases.map(\.id), ["default", "app", "octopus"])
    }

    func testTheSampleRuleOpensTheContactLinkInTheAppAndLetsOctopusOpenTheRest() throws {
        let contact = try XCTUnwrap(URL(string: "https://www.octopuscommunity.com/contact"))
        let other = try XCTUnwrap(URL(string: "https://example.com/page"))

        guard case let .openInApp(target) = HostURLPolicy.sampleRule.decision(for: contact) else {
            return XCTFail("The contact link should open in the app")
        }
        XCTAssertEqual(target.scheme, "mailto")
        XCTAssertEqual(HostURLPolicy.sampleRule.decision(for: other), .letOctopusOpen)
    }

    func testTheForcedPoliciesIgnoreTheLink() throws {
        let contact = try XCTUnwrap(URL(string: "https://www.octopuscommunity.com/contact"))
        XCTAssertEqual(HostURLPolicy.alwaysApp.decision(for: contact), .openInApp(contact))
        XCTAssertEqual(HostURLPolicy.alwaysOctopus.decision(for: contact), .letOctopusOpen)
    }

    func testEntitlementsRoundTripThroughTheirStoredForm() {
        let set: Set<Entitlement> = [.verified, .premium]
        XCTAssertEqual(Entitlement.encode(set), ["customer:premium", "customer:verified"])
        XCTAssertEqual(Entitlement.decode(Entitlement.encode(set)), set)
        XCTAssertEqual(Entitlement.decode(nil), [])
        XCTAssertEqual(Entitlement.decode(["customer:moderator", "customer:retired"]), [.moderator])
    }
}
