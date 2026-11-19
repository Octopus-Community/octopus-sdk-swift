//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import Foundation
import OctopusCore

/// What a popup of the SDK tells a banned member.
enum CommunityAccessDeniedBanMessage {
    /// The message to display for a ban.
    ///
    /// The server writes its message in the language of the member: it is displayed as it is. When it gives none,
    /// the message the connection carries is a sentence written in English for the host app: the SDK displays its
    /// own, localized, built from what the access says about the ban.
    /// - Parameters:
    ///   - userBannedMessage: the message of the ban the connection carries
    ///   - userConfig: the access to the community, which describes the ban when it is the reason of the refusal
    ///   - locale: the language the host app forces, `nil` to follow the system
    ///   - tone: the member's tone, which picks the version of the sentence that addresses the member
    static func displayable(userBannedMessage: String, userConfig: UserConfig?, locale: Locale?, tone: TextTone)
    -> DisplayableString {
        guard let userConfig, userConfig.accessDeniedMessage == nil,
              case let .accountBanned(details?) = userConfig.noAccessReason else {
            return .localizedString(userBannedMessage)
        }
        if let nickname = details.nickname {
            let key = tone.stringKey(formal: "CommunityAccessDenied.Banned.Text.Formal_nickname:%@_policyName:%@",
                                     informal: "CommunityAccessDenied.Banned.Text.Informal_nickname:%@_policyName:%@")
            return .localizedString(L10n(key, locale: locale, nickname, details.policyName))
        }
        let key = tone.stringKey(formal: "CommunityAccessDenied.Banned.TextWithoutNickname.Formal_policyName:%@",
                                 informal: "CommunityAccessDenied.Banned.TextWithoutNickname.Informal_policyName:%@")
        return .localizedString(L10n(key, locale: locale, details.policyName))
    }
}
