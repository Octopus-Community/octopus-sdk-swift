//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import Combine
import Foundation
import OctopusCore

extension PostViewData {
    init(from post: DisplayablePost) {
        self.uuid = post.uuid
        self.author = post.author
        self.relativeDate = post.relativeDate
        self.topic = post.topic
        self.canBeDeleted = post.canBeDeleted
        self.canBeModerated = post.canBeModerated
        self.canBeBlockedByUser = post.canBeBlockedByUser
        self.visiblePost = post.toVisiblePost

        switch post.content {
        case let .published(published):
            self.tags = []
            self.content = .published(PostPublishedContent(
                catchPhrase: published.bridgeInfo?.catchPhrase,
                text: published.text,
                attachment: Self.mapAttachment(published.attachment),
                cta: Self.mapCTA(bridgeInfo: published.bridgeInfo, customAction: published.customAction),
                liveMeasuresPublisher: published.liveMeasures,
                liveMeasuresValue: published.liveMeasuresValue
            ))
        case let .moderated(reasons):
            self.tags = [.moderated]
            self.content = .moderated(reasons: reasons)
        }
    }

    private static func mapAttachment(
        _ attachment: DisplayablePost.PostContent.Attachment?
    ) -> PostAttachmentViewData? {
        switch attachment {
        case let .image(image): return .image(image)
        case let .video(video): return .video(video)
        case let .poll(poll):   return .poll(poll)
        case .none:             return nil
        }
    }

    private static func mapCTA(
        bridgeInfo: DisplayablePost.PostContent.BridgeInfo?,
        customAction: DisplayablePost.PostContent.CustomAction?
    ) -> PostCTAViewData? {
        if let bridge = bridgeInfo, let ctaText = bridge.ctaText {
            return PostCTAViewData(text: ctaText, action: .bridge(objectId: bridge.objectId))
        }
        if let custom = customAction {
            return PostCTAViewData(text: custom.ctaText, action: .openURL(custom.targetUrl))
        }
        return nil
    }

    init(from post: PostDetailViewModel.Post) {
        self.uuid = post.uuid
        self.author = post.author
        self.relativeDate = post.relativeDate
        self.topic = post.topic
        // Detail-side is always a published post (moderated posts don't open detail),
        // so no `.moderated` tag. If that assumption ever changes, set it here.
        self.tags = []
        self.canBeDeleted = post.canBeDeleted
        self.canBeModerated = post.canBeModerated
        self.canBeBlockedByUser = post.canBeBlockedByUser
        self.visiblePost = post.toVisiblePost

        let liveMeasures = LiveMeasures(
            aggregatedInfo: post.aggregatedInfo,
            userInteractions: post.userInteractions)

        self.content = .published(PostPublishedContent(
            catchPhrase: post.catchPhrase,
            text: EllipsizableTranslatedText(text: post.text, ellipsize: false),
            attachment: Self.mapDetailAttachment(post.attachment),
            cta: Self.mapDetailCTA(bridgeCTA: post.bridgeCTA, customAction: post.customAction),
            liveMeasuresPublisher: Empty<LiveMeasures, Never>().eraseToAnyPublisher(),
            liveMeasuresValue: liveMeasures))
    }

    private static func mapDetailAttachment(
        _ attachment: PostDetailViewModel.Post.Attachment?
    ) -> PostAttachmentViewData? {
        switch attachment {
        case let .image(image): return .image(image)
        case let .video(video): return .video(video)
        case let .poll(poll):   return .poll(poll)
        case .none:             return nil
        }
    }

    private static func mapDetailCTA(
        bridgeCTA: PostDetailViewModel.Post.BridgeCTA?,
        customAction: PostDetailViewModel.Post.CustomAction?
    ) -> PostCTAViewData? {
        if let bridge = bridgeCTA {
            return PostCTAViewData(text: bridge.text, action: .bridge(objectId: bridge.clientObjectId))
        }
        if let custom = customAction {
            return PostCTAViewData(text: custom.ctaText, action: .openURL(custom.targetUrl))
        }
        return nil
    }
}
