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

    var localizedString: String {
        switch self {
        case let .gamification(gamificationToast): gamificationToast.localizedString
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

    var localizedString: String {
        switch action {
        case .reaction: L10n("Gamification.Toast.Reaction_points:%@", formattedPoints)
        case .vote: L10n("Gamification.Toast.Vote_points:%@", formattedPoints)
        case .post: L10n("Gamification.Toast.Post_points:%@", formattedPoints)
        case .comment: L10n("Gamification.Toast.Comment_points:%@", formattedPoints)
        case .reply: L10n("Gamification.Toast.Comment_points:%@", formattedPoints)
        case .postCommented: L10n("Gamification.Toast.PostCommented_points:%@", formattedPoints)
        case .profileCompleted: L10n("Gamification.Toast.ProfileCompleted_points:%@", formattedPoints)
        case .dailySession: L10n("Gamification.Toast.DailySession_points:%@", formattedPoints)
        }
    }
}
