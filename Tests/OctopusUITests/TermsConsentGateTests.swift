//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import Testing
import OctopusCore
@testable import OctopusUI

/// The explicit terms-consent gate, used identically in `CreatePostViewModel`,
/// `CreateCommentViewModel` and `CreateReplyViewModel`'s `send()`:
///
/// ```
/// if termsAcceptanceMode.isExplicit, !userHasAcceptedCgu, !explicitConsentGivenThisSession {
///     displayConsentSheet = true   // present the sheet, don't publish
/// }
/// ```
///
/// The consent sheet is presented **iff** the community is in an explicit mode AND the user hasn't
/// already accepted the CGU AND hasn't just accepted in this session.
///
/// The VMs need a full `OctopusSDK` to instantiate, so — as in `CreatePostViewModelTests` — the
/// decision is mirrored here as a pure predicate and its truth table is pinned.
struct TermsConsentGateTests {

    /// Mirrors the gate condition shared by the three create view models' `send()`.
    private func shouldPresentConsentSheet(mode: TermsAcceptanceMode,
                                           userHasAcceptedCgu: Bool,
                                           consentGivenThisSession: Bool) -> Bool {
        mode.isExplicit && !userHasAcceptedCgu && !consentGivenThisSession
    }

    @Test func implicitNeverPresentsSheet() {
        for accepted in [true, false] {
            for consented in [true, false] {
                #expect(shouldPresentConsentSheet(mode: .implicit,
                                                  userHasAcceptedCgu: accepted,
                                                  consentGivenThisSession: consented) == false)
            }
        }
    }

    @Test(arguments: [TermsAcceptanceMode.explicitMultiCheckbox, .explicitSingleCheckbox])
    func explicitPresentsSheetOnFirstContribution(mode: TermsAcceptanceMode) {
        #expect(shouldPresentConsentSheet(mode: mode,
                                          userHasAcceptedCgu: false,
                                          consentGivenThisSession: false))
    }

    @Test(arguments: [TermsAcceptanceMode.explicitMultiCheckbox, .explicitSingleCheckbox])
    func explicitSkipsWhenUserAlreadyAcceptedCgu(mode: TermsAcceptanceMode) {
        #expect(shouldPresentConsentSheet(mode: mode,
                                          userHasAcceptedCgu: true,
                                          consentGivenThisSession: false) == false)
    }

    @Test(arguments: [TermsAcceptanceMode.explicitMultiCheckbox, .explicitSingleCheckbox])
    func explicitSkipsAfterAcceptingThisSession(mode: TermsAcceptanceMode) {
        // `acceptConsentAndSend()` sets `explicitConsentGivenThisSession = true`, so the re-entered
        // `send()` bypasses the gate and publishes.
        #expect(shouldPresentConsentSheet(mode: mode,
                                          userHasAcceptedCgu: false,
                                          consentGivenThisSession: true) == false)
    }
}
