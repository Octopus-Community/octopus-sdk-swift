//
//  Copyright © 2025 Octopus Community. All rights reserved.
//

import Foundation
import OctopusCore
import SwiftUI
import UIKit

struct DisplayableToast: Identifiable, Equatable {
    enum Category {
        case info
        case success
        case error
    }

    let toast: Toast
    let id = UUID()
    let message: DisplayableString
    let category: Category
    var isManual = false

    /// Whether the toast stays until something removes it, instead of fading after a few seconds.
    /// Only the lost-connection one does: it is the state itself, not a one-off notice.
    var isPersistent: Bool { toast == .error(.noNetwork) }

    /// Whether the toast offers a "Retry" CTA, when the screen gave the container something to retry.
    var isRetriable: Bool { toast == .error(.unknown) }

    /// The glyph the design puts before the wording. Only the lost-connection toast has one: it names
    /// a device state the member can recognise at a glance.
    var leadingIcon: UIImage? { toast == .error(.noNetwork) ? .Gen.toastNoNetwork : nil }

    init(toast: Toast) {
        self.toast = toast
        category = switch toast {
        case .gamification: .info
        case .userAction: .success
        case .error: .error
        }
        message = toast.message
    }
}

extension Toast {
    var message: DisplayableString {
        switch self {
        case let .gamification(gamificationToast): gamificationToast.message
        case let .userAction(userAction): .localizationKey(userAction.localizedKey)
        case let .error(error): error.message
        }
    }

    /// - Parameter tone: the member's tone, which picks the version of the texts that address the member.
    func localizedString(locale: Locale?, tone: TextTone) -> String {
        switch self {
        case let .gamification(gamificationToast): gamificationToast.localizedString(locale: locale, tone: tone)
        case let .userAction(userAction): userAction.localizedString(locale: locale)
        case let .error(error): error.localizedString(locale: locale, tone: tone)
        }
    }
}

extension GamificationToast {
    var message: DisplayableString {
        switch action {
        case .reaction:
            .tonedKey(formal: "Gamification.Toast.Reaction.Formal_points:\(formattedPoints)",
                      informal: "Gamification.Toast.Reaction.Informal_points:\(formattedPoints)")
        case .vote:
            .tonedKey(formal: "Gamification.Toast.Vote.Formal_points:\(formattedPoints)",
                      informal: "Gamification.Toast.Vote.Informal_points:\(formattedPoints)")
        case .post:
            .tonedKey(formal: "Gamification.Toast.Post.Formal_points:\(formattedPoints)",
                      informal: "Gamification.Toast.Post.Informal_points:\(formattedPoints)")
        case .comment, .reply:
            .tonedKey(formal: "Gamification.Toast.Comment.Formal_points:\(formattedPoints)",
                      informal: "Gamification.Toast.Comment.Informal_points:\(formattedPoints)")
        case .postCommented:
            .tonedKey(formal: "Gamification.Toast.CommentedPost.Formal_points:\(formattedPoints)",
                      informal: "Gamification.Toast.CommentedPost.Informal_points:\(formattedPoints)")
        case .profileCompleted:
            .tonedKey(formal: "Gamification.Toast.ProfileCompleted.Formal_points:\(formattedPoints)",
                      informal: "Gamification.Toast.ProfileCompleted.Informal_points:\(formattedPoints)")
        case .dailySession:
            .tonedKey(formal: "Gamification.Toast.DailySession.Formal_points:\(formattedPoints)",
                      informal: "Gamification.Toast.DailySession.Informal_points:\(formattedPoints)")
        }
    }

    func localizedString(locale: Locale?, tone: TextTone) -> String {
        let key = switch action {
        case .reaction:
            tone.stringKey(formal: "Gamification.Toast.Reaction.Formal_points:%@",
                           informal: "Gamification.Toast.Reaction.Informal_points:%@")
        case .vote:
            tone.stringKey(formal: "Gamification.Toast.Vote.Formal_points:%@",
                           informal: "Gamification.Toast.Vote.Informal_points:%@")
        case .post:
            tone.stringKey(formal: "Gamification.Toast.Post.Formal_points:%@",
                           informal: "Gamification.Toast.Post.Informal_points:%@")
        case .comment, .reply:
            tone.stringKey(formal: "Gamification.Toast.Comment.Formal_points:%@",
                           informal: "Gamification.Toast.Comment.Informal_points:%@")
        case .postCommented:
            tone.stringKey(formal: "Gamification.Toast.CommentedPost.Formal_points:%@",
                           informal: "Gamification.Toast.CommentedPost.Informal_points:%@")
        case .profileCompleted:
            tone.stringKey(formal: "Gamification.Toast.ProfileCompleted.Formal_points:%@",
                           informal: "Gamification.Toast.ProfileCompleted.Informal_points:%@")
        case .dailySession:
            tone.stringKey(formal: "Gamification.Toast.DailySession.Formal_points:%@",
                           informal: "Gamification.Toast.DailySession.Informal_points:%@")
        }
        return L10n(key, locale: locale, formattedPoints)
    }
}

extension UserActionToast {
    var localizedKey: LocalizedStringKey {
        switch self {
        case .postCreated: "Post.Toast.Create"
        }
    }

    func localizedString(locale: Locale?) -> String {
        switch self {
        case .postCreated: L10n("Post.Toast.Create", locale: locale)
        }
    }
}

extension ErrorToast {
    var message: DisplayableString {
        switch self {
        case .noNetwork: .noNetworkError
        case .unknown: .unknownError
        }
    }

    func localizedString(locale: Locale?, tone: TextTone) -> String {
        let key = switch self {
        case .noNetwork: tone.stringKey(formal: "Error.NoNetwork.Formal", informal: "Error.NoNetwork.Informal")
        case .unknown: tone.stringKey(formal: "Error.Unknown.Formal", informal: "Error.Unknown.Informal")
        }
        return L10n(key, locale: locale)
    }
}
