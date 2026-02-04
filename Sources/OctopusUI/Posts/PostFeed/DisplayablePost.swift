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
        enum Attachment: Equatable {
            case image(ImageMedia)
            case video(VideoMedia)
            case poll(DisplayablePoll)
        }
        let text: EllipsizableTranslatedText
        let attachment: Attachment?
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

        init(text: TranslatableText, attachment: Attachment?,
             bridgeInfo: BridgeInfo?, customAction: CustomAction?,
             featuredComment: DisplayableFeedResponse?,
             liveMeasuresPublisher: CurrentValueSubject<LiveMeasures, Never>) {
            self.text = EllipsizableTranslatedText(text: text)
            self.attachment = attachment
            self.bridgeInfo = bridgeInfo
            self.customAction = customAction
            self.featuredComment = featuredComment
            self._liveMeasuresPublisher = liveMeasuresPublisher
        }

        static func == (lhs: DisplayablePost.PostContent, rhs: DisplayablePost.PostContent) -> Bool {
            return lhs.text == rhs.text &&
            lhs.attachment == rhs.attachment &&
            lhs.bridgeInfo == rhs.bridgeInfo &&
            lhs.featuredComment == rhs.featuredComment
        }
    }
    let uuid: String
    let author: Author
    let relativeDate: String
    let topic: String
    let canBeDeleted: Bool
    let canBeModerated: Bool
    let canBeOpened: Bool
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
                attachment: PostContent.Attachment(from: post),
                bridgeInfo: bridgeInfo,
                customAction: customAction,
                featuredComment: featuredComment,
                liveMeasuresPublisher: liveMeasuresPublisher)
            )
            canBeDeleted = post.author != nil && post.author?.uuid == thisUserProfileId
            canBeModerated = post.author?.uuid != thisUserProfileId
        case let .moderated(reasons):
            canBeOpened = false
            content = .moderated(reasons: reasons.map { $0.displayableString })
            canBeDeleted = false
            canBeModerated = false
        }
        author = .init(
            profile: post.author,
            gamificationLevel: gamificationLevels.first { $0.level == post.author?.gamificationLevel }
        )
        relativeDate = dateFormatter.customLocalizedStructure(for: post.creationDate, relativeTo: Date())
        self.topic = topic?.name ?? ""

        displayEvents = CellDisplayEvents(onAppear: onAppear, onDisappear: onDisappear)
    }
}

extension DisplayablePost.PostContent.Attachment {
    init?(from post: Post) {
        if let poll = post.poll {
            self = .poll(DisplayablePoll(from: poll))
        } else if let media = post.medias.first(where: { $0.kind == .video }),
                  let videoMedia = VideoMedia(from: media) {
            self = .video(videoMedia)
        } else if let media = post.medias.first(where: { $0.kind == .image }),
                  let imageMedia = ImageMedia(from: media) {
            self = .image(imageMedia)
        } else {
            return nil
        }
    }
}

extension DisplayablePost {
    var hasVideo: Bool {
        switch content {
        case let .published(content):
            switch content.attachment {
            case .video: return true
            default: return false
            }
        default: return false
        }
    }

    var videoId: String? {
        switch content {
        case let .published(content):
            switch content.attachment {
            case let .video(video): return video.videoId
            default: return nil
            }
        default: return nil
        }
    }
}
