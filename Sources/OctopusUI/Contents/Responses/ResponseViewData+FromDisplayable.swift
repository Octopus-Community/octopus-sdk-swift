//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import Foundation
import Combine
import OctopusCore

extension ResponseViewData {
    /// Summary-side mapping: feed list item (comment in post detail, reply in comment detail).
    init(from response: DisplayableFeedResponse) {
        self.uuid = response.uuid
        self.kind = response.kind
        self.author = response.author
        self.relativeDate = response.relativeDate
        self.text = response.text
        self.image = response.image
        self.canBeDeleted = response.canBeDeleted
        self.canBeModerated = response.canBeModerated
        self.canBeBlockedByUser = response.canBeBlockedByUser
        self.liveMeasuresPublisher = response.liveMeasures
        self.liveMeasuresValue = response.liveMeasuresValue
    }

    /// Detail-side mapping: the comment is the detail screen's header. No publisher upstream,
    /// so we expose a non-emitting publisher and a one-shot snapshot.
    init(from comment: CommentDetailViewModel.CommentDetail) {
        self.uuid = comment.uuid
        self.kind = .comment
        self.author = comment.author
        self.relativeDate = comment.relativeDate
        self.text = comment.text.map {
            EllipsizableTranslatedText(text: $0, ellipsize: false)
        }
        self.image = comment.image
        self.canBeDeleted = comment.canBeDeleted
        self.canBeModerated = comment.canBeModerated
        self.canBeBlockedByUser = comment.canBeBlockedByUser

        let snapshot = LiveMeasures(
            aggregatedInfo: comment.aggregatedInfo,
            userInteractions: comment.userInteractions)
        self.liveMeasuresPublisher = Empty<LiveMeasures, Never>().eraseToAnyPublisher()
        self.liveMeasuresValue = snapshot
    }
}
