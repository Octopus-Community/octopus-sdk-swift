//
//  Copyright © 2025 Octopus Community. All rights reserved.
//

import Foundation
import OctopusCore
import SwiftUI

struct DisplayableToast: Identifiable, Equatable {
    let toast: Toast
    let id = UUID()
    let message: DisplayableString
    var isManual = false

    init(toast: Toast) {
        self.toast = toast
        message = .localizationKey(toast.localizedKey)
    }
}

extension Toast {
    var localizedKey: LocalizedStringKey {
        switch self {
        case let .gamification(gamificationToast): gamificationToast.localizedKey
        }
    }

    func localizedString(locale: Locale?) -> String {
        switch self {
        case let .gamification(gamificationToast): gamificationToast.localizedString(locale: locale)
        }
    }
}

extension GamificationToast {
    var localizedKey: LocalizedStringKey {
        switch action {
        case .reaction: "Gamification.Toast.Reaction_points:\(formattedPoints)"
        case .vote: "Gamification.Toast.Vote_points:\(formattedPoints)"
        case .post: "Gamification.Toast.Post_points:\(formattedPoints)"
        case .comment: "Gamification.Toast.Comment_points:\(formattedPoints)"
        case .reply: "Gamification.Toast.Comment_points:\(formattedPoints)"
        case .postCommented: "Gamification.Toast.CommentedPost_points:\(formattedPoints)"
        case .profileCompleted: "Gamification.Toast.ProfileCompleted_points:\(formattedPoints)"
        case .dailySession: "Gamification.Toast.DailySession_points:\(formattedPoints)"
        }
    }

    func localizedString(locale: Locale?) -> String {
        switch action {
        case .reaction: L10n("Gamification.Toast.Reaction_points:%@", locale: locale, formattedPoints)
        case .vote: L10n("Gamification.Toast.Vote_points:%@", locale: locale, formattedPoints)
        case .post: L10n("Gamification.Toast.Post_points:%@", locale: locale, formattedPoints)
        case .comment: L10n("Gamification.Toast.Comment_points:%@", locale: locale, formattedPoints)
        case .reply: L10n("Gamification.Toast.Comment_points:%@", locale: locale, formattedPoints)
        case .postCommented: L10n("Gamification.Toast.PostCommented_points:%@", locale: locale, formattedPoints)
        case .profileCompleted: L10n("Gamification.Toast.ProfileCompleted_points:%@", locale: locale, formattedPoints)
        case .dailySession: L10n("Gamification.Toast.DailySession_points:%@", locale: locale, formattedPoints)
        }
    }
}
