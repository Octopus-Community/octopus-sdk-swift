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
        enum Attachment: Equatable {
            case image(ImageMedia)
            case poll(DisplayablePoll)
        }
        let text: EllipsizableTranslatedText
        let attachment: Attachment?
        let bridgeCTA: (text: String, clientObjectId: String)?
        fileprivate let _liveMeasuresPublisher: CurrentValueSubject<LiveMeasures, Never>
        var liveMeasures: AnyPublisher<LiveMeasures, Never> {
            _liveMeasuresPublisher.removeDuplicates().eraseToAnyPublisher()
        }
        var liveMeasuresValue: LiveMeasures {
            _liveMeasuresPublisher.value
        }

        let featuredComment: DisplayableFeedResponse?

        init(text: TranslatableText, attachment: Attachment?,
             bridgeCTA: (text: String, clientObjectId: String)?,
             featuredComment: DisplayableFeedResponse?,
             liveMeasuresPublisher: CurrentValueSubject<LiveMeasures, Never>) {
            self.text = EllipsizableTranslatedText(text: text)
            self.attachment = attachment
            self.bridgeCTA = bridgeCTA
            self.featuredComment = featuredComment
            self._liveMeasuresPublisher = liveMeasuresPublisher
        }

        static func == (lhs: DisplayablePost.PostContent, rhs: DisplayablePost.PostContent) -> Bool {
            return lhs.text == rhs.text &&
            lhs.attachment == rhs.attachment &&
            lhs.bridgeCTA?.text == rhs.bridgeCTA?.text &&
            lhs.bridgeCTA?.clientObjectId == rhs.bridgeCTA?.clientObjectId &&
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

    let displayEvents: CellDisplayEvents

    var hasFeaturedComment: Bool {
        switch content {
        case let .published(content): content.featuredComment != nil
        case .moderated: false
        }
    }
}

extension DisplayablePost {
    init(from post: Post, liveMeasuresPublisher: CurrentValueSubject<LiveMeasures, Never>,
         childLiveMeasuresPublisher: CurrentValueSubject<LiveMeasures, Never>?,
         thisUserProfileId: String?, topic: Topic?, dateFormatter: RelativeDateTimeFormatter,
         onAppear: @escaping () -> Void, onDisappear: @escaping () -> Void) {
        uuid = post.uuid
        switch post.status {

        case .published, .other:
            canBeOpened = true

            let bridgeCTA: (text: String, clientObjectId: String)? = if let bridgeInfo = post.clientObjectBridgeInfo,
                                                                        let ctaText = bridgeInfo.ctaText {
                (text: ctaText.originalText, clientObjectId: bridgeInfo.objectId)
            } else {
                nil
            }

            let featuredComment: DisplayableFeedResponse?
            if let comment = post.featuredComment, let childLiveMeasuresPublisher {
                featuredComment = DisplayableFeedResponse(
                    from: comment,
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
                bridgeCTA: bridgeCTA,
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
        author = .init(profile: post.author)
        relativeDate = dateFormatter.customLocalizedStructure(for: post.creationDate, relativeTo: Date())
        self.topic = topic?.name ?? ""

        displayEvents = CellDisplayEvents(onAppear: onAppear, onDisappear: onDisappear)
    }
}

extension DisplayablePost.PostContent.Attachment {
    init?(from post: Post) {
        if let poll = post.poll {
            self = .poll(DisplayablePoll(from: poll))
        } else if let media = post.medias.first(where: { $0.kind == .image }),
                  let imageMedia = ImageMedia(from: media) {
            self = .image(imageMedia)
        } else {
            return nil
        }
    }
}
