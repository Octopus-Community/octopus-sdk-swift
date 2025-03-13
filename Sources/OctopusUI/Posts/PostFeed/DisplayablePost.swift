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
        let text: String
        let image: ImageMedia?
        let textIsEllipsized: Bool
        let aggregatedInfo: AggregatedInfo
        let userInteractions: UserInteractions
        let liveMeasures: AnyPublisher<LiveMeasures, Never>

        static func == (lhs: DisplayablePost.PostContent, rhs: DisplayablePost.PostContent) -> Bool {
            return lhs.text == rhs.text &&
            lhs.image == rhs.image &&
            lhs.textIsEllipsized == rhs.textIsEllipsized &&
            lhs.aggregatedInfo == rhs.aggregatedInfo &&
            lhs.userInteractions == rhs.userInteractions
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
}

extension DisplayablePost {
    init(from post: Post, liveMeasurePublisher: AnyPublisher<LiveMeasures, Never>,
         thisUserProfileId: String?, topic: Topic?, dateFormatter: RelativeDateTimeFormatter,
         onAppear: @escaping () -> Void, onDisappear: @escaping () -> Void) {
        uuid = post.uuid
        switch post.status {

        case .published, .other:
            canBeOpened = true

            // Display max 200 chars and 4 new lines.
            let displayableText = String(post.text.prefix(200))
                .split(separator: "\n")
                .prefix(4)
                .joined(separator: "\n")

            content = .published(PostContent(
                text: displayableText,
                image: ImageMedia(from: post.medias.first(where: { $0.kind == .image })),
                textIsEllipsized: post.text != displayableText,
//                aggregatedInfo: post.aggregatedInfo,
//                userInteractions: post.userInteractions,
                aggregatedInfo: .empty,
                userInteractions: .empty,
                liveMeasures: liveMeasurePublisher)
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
