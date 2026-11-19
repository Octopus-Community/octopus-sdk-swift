//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import Foundation
import Testing
@testable import OctopusUI

/// The sentence telling a banned member who to write to underlines the address and opens a mail to it. The address
/// is typed by the community: whatever it holds, the sentence is displayed and the link never breaks the screen.
struct CommunityAccessDeniedBanAppealTests {
    private typealias Appeal = CommunityAccessDeniedBanAppeal

    @Test func theAddressAtTheEndSplitsTheSentence() {
        let parts = Appeal.parts(sentence: "To appeal this decision, contact a@b.co", email: "a@b.co")

        #expect(parts == .init(before: "To appeal this decision, contact ", email: "a@b.co", after: ""))
    }

    @Test func theAddressInTheMiddleSplitsTheSentence() {
        let parts = Appeal.parts(sentence: "Écrivez à a@b.co pour contester", email: "a@b.co")

        #expect(parts == .init(before: "Écrivez à ", email: "a@b.co", after: " pour contester"))
    }

    @Test func aSentenceWithoutTheAddressIsKeptWhole() {
        let parts = Appeal.parts(sentence: "To appeal this decision, contact us", email: "a@b.co")

        #expect(parts == .init(before: "To appeal this decision, contact us", email: "", after: ""))
    }

    @Test func aPlainAddressGivesItsMailtoURL() {
        #expect(Appeal.mailtoURL(for: "community-support@yourbrandname.com")?.absoluteString
                == "mailto:community-support@yourbrandname.com")
    }

    @Test func anAddressWithASpaceStillGivesAURL() throws {
        let url = try #require(Appeal.mailtoURL(for: "a b@c.co"))

        #expect(url.scheme == "mailto")
    }

    @Test func anEmptyAddressGivesNoURL() {
        #expect(Appeal.mailtoURL(for: "") == nil)
        #expect(Appeal.mailtoURL(for: "  ") == nil)
    }
}
