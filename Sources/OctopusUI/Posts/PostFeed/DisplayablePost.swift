//
//  Copyright © 2025 Octopus Community. All rights reserved.
//

import Foundation
import OctopusCore
import Combine

struct DisplayablePost: Equatable {
    enum Content: Equatable {
        case published(PostContent)
        case moderated(reasons: [DisplayableString])
    }

    struct PostContent: Equatable {
        struct BridgeInfo: Equatable {
            public let objectId: String
            public let catchPhrase: TranslatableText?
            public let ctaText: TranslatableText?
        }
        struct CustomAction: Equatable {
            let ctaText: TranslatableText
            let targetUrl: URL
        }
        /// The whole post text. Truncation is decided by the cell (whether it is expanded) and
        /// applied at render time, so no shortened copy is kept here.
        let text: TranslatableText
        let attachments: PostAttachmentsViewData
        let bridgeInfo: BridgeInfo?
        let customAction: CustomAction?
        fileprivate let _liveMeasuresPublisher: CurrentValueSubject<LiveMeasures, Never>
        var liveMeasures: AnyPublisher<LiveMeasures, Never> {
            _liveMeasuresPublisher.removeDuplicates().eraseToAnyPublisher()
        }
        var liveMeasuresValue: LiveMeasures {
            _liveMeasuresPublisher.value
        }

        let featuredComment: DisplayableFeedResponse?

        init(text: TranslatableText, attachments: PostAttachmentsViewData,
             bridgeInfo: BridgeInfo?, customAction: CustomAction?,
             featuredComment: DisplayableFeedResponse?,
             liveMeasuresPublisher: CurrentValueSubject<LiveMeasures, Never>) {
            self.text = text
            self.attachments = attachments
            self.bridgeInfo = bridgeInfo
            self.customAction = customAction
            self.featuredComment = featuredComment
            self._liveMeasuresPublisher = liveMeasuresPublisher
        }

        static func == (lhs: DisplayablePost.PostContent, rhs: DisplayablePost.PostContent) -> Bool {
            return lhs.text == rhs.text &&
            lhs.attachments == rhs.attachments &&
            lhs.bridgeInfo == rhs.bridgeInfo &&
            lhs.featuredComment == rhs.featuredComment
        }
    }
    let uuid: String
    let author: Author
    let relativeDate: String
    let topic: String?
    /// Identifier of the post's group (its `parentId`). Backs the "View group" menu entry.
    let groupId: String?
    let canBeDeleted: Bool
    let canBeModerated: Bool
    let canBeBlockedByUser: Bool
    let canBeOpened: Bool
    let canCreateChildren: Bool
    let content: Content
    let position: Int
    let isLast: Bool

    let displayEvents: CellDisplayEvents

    var hasFeaturedComment: Bool {
        switch content {
        case let .published(content): content.featuredComment != nil
        case .moderated: false
        }
    }

    var hasChildren: Bool {
        switch content {
        case let .published(content): content.liveMeasuresValue.aggregatedInfo.childCount > 0
        case .moderated: false
        }
    }
}

extension DisplayablePost {
    init(from post: Post,
         position: Int,
         isLast: Bool,
         gamificationLevels: [GamificationLevel],
         liveMeasuresPublisher: CurrentValueSubject<LiveMeasures, Never>,
         childLiveMeasuresPublisher: CurrentValueSubject<LiveMeasures, Never>?,
         thisUserProfileId: String?, topic: Topic?, dateFormatter: RelativeDateTimeFormatter,
         onAppear: @escaping () -> Void, onDisappear: @escaping () -> Void) {
        uuid = post.uuid
        self.position = position
        self.isLast = isLast
        author = .init(
            profile: post.author,
            gamificationLevel: gamificationLevels.first { $0.level == post.author?.gamificationLevel }
        )
        canCreateChildren = post.permissions.canCreateChildren

        switch post.status {

        case .published, .other:
            canBeOpened = true

            let bridgeInfo = post.clientObjectBridgeInfo.map {
                PostContent.BridgeInfo(objectId: $0.objectId, catchPhrase: $0.catchPhrase, ctaText: $0.ctaText)
            }
            let customAction = post.customAction.map {
                PostContent.CustomAction(ctaText: $0.ctaText, targetUrl: $0.targetUrl)
            }

            let featuredComment: DisplayableFeedResponse?
            if let comment = post.featuredComment, let childLiveMeasuresPublisher {
                featuredComment = DisplayableFeedResponse(
                    from: comment,
                    gamificationLevels: gamificationLevels,
                    ellipsizeText: true,
                    liveMeasurePublisher: childLiveMeasuresPublisher,
                    thisUserProfileId: thisUserProfileId,
                    dateFormatter: dateFormatter,
                    onAppearAction: {},
                    onDisappearAction: {}
                )
            } else {
                featuredComment = nil
            }

            content = .published(PostContent(
                text: post.text,
                attachments: PostAttachmentsViewData(from: post),
                bridgeInfo: bridgeInfo,
                customAction: customAction,
                featuredComment: featuredComment,
                liveMeasuresPublisher: liveMeasuresPublisher)
            )
            canBeDeleted = post.author != nil && post.author?.uuid == thisUserProfileId
            canBeModerated = post.author?.uuid != thisUserProfileId
            canBeBlockedByUser = author.canBeBlocked(currentUserId: thisUserProfileId)
        case let .moderated(reasons):
            canBeOpened = false
            content = .moderated(reasons: reasons.map { $0.displayableString })
            canBeDeleted = false
            canBeModerated = false
            // Moderated cells don't surface the more-menu, so blocking from them is not reachable.
            // Keep this `false` explicitly so the field stays consistent with canBeDeleted/canBeModerated
            // here rather than leaking an admin/self check that has no UI entry point.
            canBeBlockedByUser = false
        }
        relativeDate = dateFormatter.customLocalizedStructure(for: post.creationDate, relativeTo: Date())
        self.topic = topic?.name
        self.groupId = post.parentId

        displayEvents = CellDisplayEvents(onAppear: onAppear, onDisappear: onDisappear)
    }
}

extension DisplayablePost {
    var hasVideo: Bool { publishedAttachments?.hasVideo ?? false }

    var videoId: String? { publishedAttachments?.videoId }

    private var publishedAttachments: PostAttachmentsViewData? {
        guard case let .published(content) = content else { return nil }
        return content.attachments
    }
}
