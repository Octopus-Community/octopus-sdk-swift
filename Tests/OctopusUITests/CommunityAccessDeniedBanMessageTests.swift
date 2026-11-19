//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import Foundation
import Testing
@testable import OctopusCore
@testable import OctopusUI

/// What a popup of the SDK tells a banned member: the words of the server, which it writes in the member's
/// language, or, when it gives none, the sentence of the SDK in that language rather than the English one the host
/// app is given.
struct CommunityAccessDeniedBanMessageTests {
    private typealias BanMessage = CommunityAccessDeniedBanMessage

    @Test func theMessageOfTheServerIsDisplayedAsItIs() {
        let userConfig = UserConfig(canAccessCommunity: false, accessDeniedMessage: "Vous êtes banni.",
                                    noAccessReason: ban(nickname: "marie_l92"))

        #expect(BanMessage.displayable(userBannedMessage: "Vous êtes banni.", userConfig: userConfig, locale: Locale(identifier: "en"), tone: .formal)
                == .localizedString("Vous êtes banni."))
    }

    @Test func withoutAMessageOfTheServerTheSentenceOfTheSdkIsLocalized() {
        let userConfig = UserConfig(canAccessCommunity: false, accessDeniedMessage: nil,
                                    noAccessReason: ban(nickname: "marie_l92"))

        #expect(BanMessage.displayable(userBannedMessage: "English fallback", userConfig: userConfig, locale: Locale(identifier: "en"), tone: .formal)
                == .localizedString(
                    "Your account @marie_l92 was banned for breaking the \"Job applications\" policy."))
    }

    @Test func withoutANicknameTheSentenceDoesNotNameTheAccount() {
        let userConfig = UserConfig(canAccessCommunity: false, accessDeniedMessage: nil,
                                    noAccessReason: ban(nickname: nil))

        #expect(BanMessage.displayable(userBannedMessage: "English fallback", userConfig: userConfig, locale: Locale(identifier: "en"), tone: .formal)
                == .localizedString("Your account was banned for breaking the \"Job applications\" policy."))
    }

    /// A member of a community informal in their language is addressed informally ("Ton compte").
    @Test func theSentenceOfTheSdkFollowsTheToneOfTheMember() {
        let userConfig = UserConfig(canAccessCommunity: false, accessDeniedMessage: nil,
                                    noAccessReason: ban(nickname: "marie_l92"))
        let french = Locale(identifier: "fr")

        #expect(BanMessage.displayable(userBannedMessage: "x", userConfig: userConfig, locale: french, tone: .formal)
                == .localizedString(
                    "Votre compte @marie_l92 a été banni pour non-respect de la règle « Job applications »."))
        #expect(BanMessage.displayable(userBannedMessage: "x", userConfig: userConfig, locale: french, tone: .informal)
                == .localizedString(
                    "Ton compte @marie_l92 a été banni pour non-respect de la règle « Job applications »."))
    }

    /// The fields of a ban are typed by people: a format specifier in one is displayed, never read.
    @Test func banFieldsHoldingFormatSpecifiersAreKeptVerbatim() {
        let userConfig = UserConfig(
            canAccessCommunity: false, accessDeniedMessage: nil,
            noAccessReason: .accountBanned(.init(nickname: "100%@", policyName: "%d %1$@", policyDescription: "",
                                                 contactEmail: nil)))

        #expect(BanMessage.displayable(userBannedMessage: "x", userConfig: userConfig, locale: Locale(identifier: "en"), tone: .formal)
                == .localizedString("Your account @100%@ was banned for breaking the \"%d %1$@\" policy."))
    }

    /// A ban told by the failure of an exchange, or of a guest connection: the access says nothing about it.
    @Test(arguments: [
        nil,
        UserConfig(canAccessCommunity: true, accessDeniedMessage: nil),
        UserConfig(canAccessCommunity: false, accessDeniedMessage: nil, noAccessReason: .memberExcluded),
        UserConfig(canAccessCommunity: false, accessDeniedMessage: nil, noAccessReason: .accountBanned(nil))
    ])
    func aBanTheAccessDoesNotDescribeKeepsItsMessage(userConfig: UserConfig?) {
        #expect(BanMessage.displayable(userBannedMessage: "You have been banned", userConfig: userConfig, locale: Locale(identifier: "en"), tone: .formal)
                == .localizedString("You have been banned"))
    }

    private func ban(nickname: String?) -> CommunityNoAccessReason {
        .accountBanned(.init(nickname: nickname, policyName: "Job applications", policyDescription: "Desc",
                             contactEmail: nil))
    }
}
