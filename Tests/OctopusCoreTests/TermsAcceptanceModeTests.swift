//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import XCTest
import OctopusGrpcModels
@testable import OctopusCore

/// Terms-acceptance mode on `CommunityConfig` (explicit-consent feature).
/// Highest-priority invariant: until the backend/proto field lands, the mode defaults to
/// `.implicit` (today's behaviour — implicit acceptance, no consent sheet, no behaviour change).
final class TermsAcceptanceModeTests: XCTestCase {

    func testDefaultsToImplicitFromProtoConfig() {
        // No terms field on the proto yet ⇒ the mapper hardcodes `.implicit`.
        let config = Com_Octopuscommunity_ApiKeyConfig.with { $0.displayAccountAge = true }

        let community = CommunityConfig(from: config)

        XCTAssertEqual(community.termsAcceptanceMode, .implicit)
        XCTAssertFalse(community.termsAcceptanceMode.isExplicit)
    }

    func testIsExplicit() {
        XCTAssertFalse(TermsAcceptanceMode.implicit.isExplicit)
        XCTAssertTrue(TermsAcceptanceMode.explicitMultiCheckbox.isExplicit)
        XCTAssertTrue(TermsAcceptanceMode.explicitSingleCheckbox.isExplicit)
    }

    func testWithTermsAcceptanceModeReplacesOnlyThatField() {
        let base = CommunityConfig(from: Com_Octopuscommunity_ApiKeyConfig.with {
            $0.displayAccountAge = true
        })
        XCTAssertEqual(base.termsAcceptanceMode, .implicit) // precondition

        let updated = base.withTermsAcceptanceMode(.explicitMultiCheckbox)

        // Target field changed…
        XCTAssertEqual(updated.termsAcceptanceMode, .explicitMultiCheckbox)
        // …base left untouched (value semantics)…
        XCTAssertEqual(base.termsAcceptanceMode, .implicit)
        // …and every other field preserved.
        XCTAssertEqual(updated.forceLoginOnStrongActions, base.forceLoginOnStrongActions)
        XCTAssertEqual(updated.displayAccountAge, base.displayAccountAge)
        XCTAssertEqual(updated.contentOptions, base.contentOptions)
        XCTAssertEqual(updated.profileFieldsLock, base.profileFieldsLock)
        XCTAssertEqual(updated.displayConfig, base.displayConfig)
        XCTAssertEqual(updated.gamificationConfig, base.gamificationConfig)
    }

    func testWithTermsAcceptanceModeSingleCheckbox() {
        let base = CommunityConfig(from: Com_Octopuscommunity_ApiKeyConfig.with { _ in })
        let updated = base.withTermsAcceptanceMode(.explicitSingleCheckbox)
        XCTAssertEqual(updated.termsAcceptanceMode, .explicitSingleCheckbox)
        XCTAssertTrue(updated.termsAcceptanceMode.isExplicit)
    }
}
