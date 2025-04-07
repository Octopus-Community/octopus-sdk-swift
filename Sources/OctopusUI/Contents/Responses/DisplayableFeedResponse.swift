//
//  Copyright © 2025 Octopus Community. All rights reserved.
//

import Foundation
import Combine
import OctopusCore

struct DisplayableFeedResponse: Equatable {
    let kind: ResponseKind
    let uuid: String
    let text: String?
    let image: ImageMedia?
    let author: Author
    let relativeDate: String
    let canBeDeleted: Bool
    let canBeModerated: Bool

    let liveMeasures: AnyPublisher<LiveMeasures, Never>

    let displayEvents: CellDisplayEvents

    static func == (lhs: DisplayableFeedResponse, rhs: DisplayableFeedResponse) -> Bool {
        return lhs.uuid == rhs.uuid &&
        lhs.text == rhs.text &&
        lhs.image == rhs.image &&
        lhs.author == rhs.author &&
        lhs.relativeDate == rhs.relativeDate &&
        lhs.canBeDeleted == rhs.canBeDeleted &&
        lhs.canBeModerated == rhs.canBeModerated
    }
}

extension DisplayableFeedResponse {
    init(from comment: Comment, liveMeasurePublisher: AnyPublisher<LiveMeasures, Never>,
         thisUserProfileId: String?, dateFormatter: RelativeDateTimeFormatter,
         onAppearAction: @escaping () -> Void, onDisappearAction: @escaping () -> Void) {
        kind = .comment
        uuid = comment.uuid
        text = comment.text
        author = .init(profile: comment.author)
        relativeDate = dateFormatter.customLocalizedStructure(for: comment.creationDate, relativeTo: Date())
        image = ImageMedia(from: comment.medias.first(where: { $0.kind == .image }))
        canBeDeleted = comment.author != nil && comment.author?.uuid == thisUserProfileId
        canBeModerated = comment.author?.uuid != thisUserProfileId
        liveMeasures = liveMeasurePublisher
        displayEvents = CellDisplayEvents(onAppear: onAppearAction, onDisappear: onDisappearAction)
    }

    init(from reply: Reply, liveMeasurePublisher: AnyPublisher<LiveMeasures, Never>,
         thisUserProfileId: String?, dateFormatter: RelativeDateTimeFormatter,
         onAppearAction: @escaping () -> Void, onDisappearAction: @escaping () -> Void) {
        kind = .reply
        uuid = reply.uuid
        text = reply.text
        author = .init(profile: reply.author)
        relativeDate = dateFormatter.customLocalizedStructure(for: reply.creationDate, relativeTo: Date())
        image = ImageMedia(from: reply.medias.first(where: { $0.kind == .image }))
        canBeDeleted = reply.author != nil && reply.author?.uuid == thisUserProfileId
        canBeModerated = reply.author?.uuid != thisUserProfileId
        liveMeasures = liveMeasurePublisher
        displayEvents = CellDisplayEvents(onAppear: onAppearAction, onDisappear: onDisappearAction)
    }
}
