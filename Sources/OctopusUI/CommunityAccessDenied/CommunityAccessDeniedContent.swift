//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import Foundation
import SwiftUI
import OctopusCore

/// What the access denied screen displays for a reason.
struct CommunityAccessDeniedContent: Equatable {
    /// What the sentences of a ban are made of.
    struct Ban: Equatable {
        let nickname: String?
        let policyName: String
        let contactEmail: String?
    }

    enum Subtitle: Equatable {
        /// The message of the server, displayed as it is.
        case message(String)
        /// The sentences the SDK writes about a ban.
        case ban(Ban)
    }

    enum Action: Equatable {
        /// Opens the text of the policy the banned account broke.
        case knowMore(policyName: String, policyDescription: String)
        /// Lets a member whose account was deleted access the community again.
        case accessCommunity
    }

    let title: DisplayableString
    let subtitle: Subtitle?
    let action: Action?

    init(reason: CommunityNoAccessReason, message: String?) {
        let messageSubtitle = message?.nilIfEmpty.map { Subtitle.message($0) }
        switch reason {
        case .cohort:
            title = .localizationKey("CommunityAccessDenied.Cohort.Title")
            subtitle = messageSubtitle
            action = nil
        case .temporarilyDisabled:
            title = .localizationKey("CommunityAccessDenied.TemporarilyDisabled.Title")
            subtitle = messageSubtitle
            action = nil
        case .closed:
            title = .localizationKey("CommunityAccessDenied.Closed.Title")
            subtitle = messageSubtitle
            action = nil
        case .memberExcluded, .unknown:
            title = .localizationKey("CommunityAccessDenied.Unavailable.Title")
            subtitle = messageSubtitle
            action = nil
        case let .accountBanned(details):
            title = .tonedKey(formal: "CommunityAccessDenied.Banned.Title.Formal",
                              informal: "CommunityAccessDenied.Banned.Title.Informal")
            if let details {
                // The SDK writes the sentences of a ban itself, whatever the message of the server
                subtitle = .ban(Ban(nickname: details.nickname, policyName: details.policyName,
                                    contactEmail: details.contactEmail))
                action = details.policyDescription.isEmpty ? nil : .knowMore(
                    policyName: details.policyName, policyDescription: details.policyDescription)
            } else {
                // Right after launch, until the details of the ban are read: the title stands alone
                subtitle = nil
                action = nil
            }
        case .accountDeleted:
            title = .tonedKey(formal: "CommunityAccessDenied.Deleted.Title.Formal",
                              informal: "CommunityAccessDenied.Deleted.Title.Informal")
            subtitle = messageSubtitle
            action = .accessCommunity
        }
    }

    /// The content for an access state, `nil` when the access is granted or not known.
    init?(userConfig: UserConfig?) {
        guard let userConfig, let reason = userConfig.noAccessReason else { return nil }
        self.init(reason: reason, message: userConfig.accessDeniedMessage)
    }
}
