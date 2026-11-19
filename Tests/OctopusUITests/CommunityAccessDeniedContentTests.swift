//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import Foundation
import SwiftUI
import Testing
@testable import OctopusCore
@testable import OctopusUI

/// What the access denied screen displays for each reason: a title of the SDK, the message of the server under it,
/// and the action the reason calls for.
struct CommunityAccessDeniedContentTests {
    private typealias Content = CommunityAccessDeniedContent
    private let bannedTitle = DisplayableString.tonedKey(formal: "CommunityAccessDenied.Banned.Title.Formal",
                                                         informal: "CommunityAccessDenied.Banned.Title.Informal")

    @Test(arguments: [
        (CommunityNoAccessReason.cohort, "CommunityAccessDenied.Cohort.Title", false, false),
        (.temporarilyDisabled, "CommunityAccessDenied.TemporarilyDisabled.Title", false, false),
        (.closed, "CommunityAccessDenied.Closed.Title", false, false),
        (.memberExcluded, "CommunityAccessDenied.Unavailable.Title", false, false),
        (.unknown, "CommunityAccessDenied.Unavailable.Title", false, false),
        // The title of a deleted account addresses the member: it comes in both tones.
        (.accountDeleted, "CommunityAccessDenied.Deleted.Title", true, true)
    ])
    func aReasonShowsItsTitleAndTheBackMessage(reason: CommunityNoAccessReason, titleKey: String, isToned: Bool,
                                               offersToAccessTheCommunity: Bool) {
        let content = Content(reason: reason, message: "Back msg")

        let title: DisplayableString = isToned
            ? .tonedKey(formal: LocalizedStringKey(titleKey + ".Formal"),
                        informal: LocalizedStringKey(titleKey + ".Informal"))
            : .localizationKey(LocalizedStringKey(titleKey))
        #expect(content.title == title)
        #expect(content.subtitle == .message("Back msg"))
        #expect(content.action == (offersToAccessTheCommunity ? .accessCommunity : nil))
    }

    @Test func aMissingOrEmptyBackMessageShowsTheTitleAlone() {
        #expect(Content(reason: .cohort, message: nil).subtitle == nil)
        #expect(Content(reason: .cohort, message: "").subtitle == nil)
    }

    /// A server that gives no reason still gives its message: it must keep being displayed.
    @Test func aMessageFromAServerWithoutReasonIsStillShown() throws {
        let content = try #require(Content(
            userConfig: UserConfig(canAccessCommunity: false, accessDeniedMessage: "Old back msg")))

        #expect(content.title == .localizationKey("CommunityAccessDenied.Unavailable.Title"))
        #expect(content.subtitle == .message("Old back msg"))
        #expect(content.action == nil)
    }

    @Test(arguments: [("marie_l92", "a@b.co"), ("marie_l92", nil), (nil, "a@b.co"), (nil, nil)]
          as [(String?, String?)])
    func aBanShowsItsSentenceInItsFourCombinations(nickname: String?, email: String?) {
        let content = Content(reason: ban(nickname: nickname, contactEmail: email), message: "Back msg")

        #expect(content.title == bannedTitle)
        #expect(content.subtitle == .ban(.init(nickname: nickname, policyName: "Job applications",
                                               contactEmail: email)))
    }

    @Test func knowMoreIsHiddenWithoutAPolicyDescription() {
        #expect(Content(reason: ban(policyDescription: ""), message: nil).action == nil)
    }

    @Test func knowMoreCarriesThePolicy() {
        #expect(Content(reason: ban(policyDescription: "L1\nL2"), message: nil).action
                == .knowMore(policyName: "Job applications", policyDescription: "L1\nL2"))
    }

    /// Right after launch the ban is known before its details are read: the title stands alone until then.
    @Test func aBanWhoseDetailsAreNotReadYetShowsItsTitleAlone() {
        let content = Content(reason: .accountBanned(nil), message: nil)

        #expect(content.title == bannedTitle)
        #expect(content.subtitle == nil)
        #expect(content.action == nil)
    }

    @Test func aDeletedAccountOffersToAccessTheCommunity() {
        #expect(Content(reason: .accountDeleted, message: nil).action == .accessCommunity)
        #expect(Content(reason: .accountDeleted, message: "Bye").action == .accessCommunity)
    }

    /// The fields of a ban are typed by people: they are displayed as they are, never read as a format or as
    /// markdown.
    @Test func banFieldsWithFormatOrMarkdownCharactersAreKeptVerbatim() {
        let reason = CommunityNoAccessReason.accountBanned(.init(
            nickname: "100%@_*x*", policyName: "[a](b) %d", policyDescription: "", contactEmail: nil))

        #expect(Content(reason: reason, message: nil).subtitle
                == .ban(.init(nickname: "100%@_*x*", policyName: "[a](b) %d", contactEmail: nil)))
    }

    @Test func aGrantedOrUnknownAccessHasNoContent() {
        #expect(Content(userConfig: nil) == nil)
        #expect(Content(userConfig: UserConfig(canAccessCommunity: true, accessDeniedMessage: nil)) == nil)
    }

    private func ban(nickname: String? = "marie_l92", policyDescription: String = "Desc",
                     contactEmail: String? = nil) -> CommunityNoAccessReason {
        .accountBanned(.init(nickname: nickname, policyName: "Job applications",
                             policyDescription: policyDescription, contactEmail: contactEmail))
    }
}
