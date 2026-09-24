//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import Foundation
import Testing
import OctopusCore
@testable import OctopusUI

/// Unit-tests for how a `Toast` is displayed, the two traits the Screen states spec added: the
/// lost-connection toast stays until the connection is back, and only the catch-all error offers a
/// retry. Everything else keeps fading on its own, with no CTA.
@Suite
struct DisplayableToastTests {
    @Test func theLostConnectionToastStaysUntilSomethingRemovesIt() {
        let toast = DisplayableToast(toast: .error(.noNetwork))

        #expect(toast.isPersistent)
        // No CTA: the content refreshes on its own once the connection is back.
        #expect(!toast.isRetriable)
    }

    @Test func theCatchAllErrorToastFadesAndOffersARetry() {
        let toast = DisplayableToast(toast: .error(.unknown))

        #expect(!toast.isPersistent)
        #expect(toast.isRetriable)
    }

    @Test func otherToastsAreNeitherPersistentNorRetriable() {
        let toast = DisplayableToast(toast: .userAction(.postCreated))

        #expect(!toast.isPersistent)
        #expect(!toast.isRetriable)
    }

    @Test func errorToastsAreCategorizedAsErrors() {
        // The category is what puts the toast at the top of the screen and paints it with the error color.
        #expect(DisplayableToast(toast: .error(.unknown)).category == .error)
        #expect(DisplayableToast(toast: .userAction(.postCreated)).category == .success)
    }
}
