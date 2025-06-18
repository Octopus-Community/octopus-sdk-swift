//
//  Copyright © 2025 Octopus Community. All rights reserved.
//

import Foundation
import OctopusCore

extension NotifAction.OctoScreen {
    var mainFlowScreen: MainFlowScreen {
        switch self {
        case let .postDetail(postId, commentToScrollTo, scrollToMostRecentComment):
                .postDetail(postId: postId,
                            comment: false,
                            commentToScrollTo: commentToScrollTo,
                            scrollToMostRecentComment: scrollToMostRecentComment)
        case let .commentDetail(commentId, replyToScrollTo):
                .commentDetail(commentId: commentId, displayGoToParentButton: true, reply: false,
                               replyToScrollTo: replyToScrollTo)
        }
    }
}
