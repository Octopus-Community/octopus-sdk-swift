//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import Foundation
import Combine
import OctopusCore

/// View-local representation of a post. Used by the shared `PostView` in both feed and detail.
struct PostViewData {
    let uuid: String
    let author: Author
    let relativeDate: String
    let topic: String
    let tags: [PostTag]
    let content: PostContent
    let canBeDeleted: Bool
    let canBeModerated: Bool
    let canBeBlockedByUser: Bool
    /// Visibility payload emitted via `VisibleItemsPreference` on the video view so that the
    /// enclosing scroll modifier (`postsVisibilityScrollView`) can auto-play the centered video.
    let visiblePost: VisiblePost
}

enum PostContent {
    case published(PostPublishedContent)
    case moderated(reasons: [DisplayableString])
}

struct PostPublishedContent {
    let catchPhrase: TranslatableText?
    let text: EllipsizableTranslatedText
    let attachment: PostAttachmentViewData?
    let cta: PostCTAViewData?
    let liveMeasuresPublisher: AnyPublisher<LiveMeasures, Never>
    /// Immediate snapshot of live measures so the first render is not empty.
    let liveMeasuresValue: LiveMeasures
}

enum PostAttachmentViewData {
    case image(ImageMedia)
    case video(VideoMedia)
    case poll(DisplayablePoll)
}

struct PostCTAViewData {
    let text: TranslatableText
    let action: Action

    enum Action {
        case bridge(objectId: String)
        case openURL(URL)
    }
}

enum PostTag: Equatable, Hashable {
    case moderated
}
