//
//  Copyright © 2025 Octopus Community. All rights reserved.
//

import Foundation
import Combine
import OctopusCore

struct DisplayableFeedResponse: Equatable {
    let kind: ResponseKind
    let uuid: String
    let text: EllipsizableTranslatedText?
    let image: ImageMedia?
    let author: Author
    let relativeDate: String
    let canBeDeleted: Bool
    let canBeModerated: Bool

    fileprivate let _liveMeasuresPublisher: CurrentValueSubject<LiveMeasures, Never>
    var liveMeasures: AnyPublisher<LiveMeasures, Never> {
        _liveMeasuresPublisher.removeDuplicates().eraseToAnyPublisher()
    }
    var liveMeasuresValue: LiveMeasures {
        _liveMeasuresPublisher.value
    }

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

    init(kind: ResponseKind,
         uuid: String,
         text: EllipsizableTranslatedText?,
         image: ImageMedia?,
         author: Author,
         relativeDate: String,
         canBeDeleted: Bool,
         canBeModerated: Bool,
         _liveMeasuresPublisher: CurrentValueSubject<LiveMeasures, Never>,
         displayEvents: CellDisplayEvents) {
        self.kind = kind
        self.uuid = uuid
        self.text = text
        self.image = image
        self.author = author
        self.relativeDate = relativeDate
        self.canBeDeleted = canBeDeleted
        self.canBeModerated = canBeModerated
        self._liveMeasuresPublisher = _liveMeasuresPublisher
        self.displayEvents = displayEvents
    }
}

extension DisplayableFeedResponse {
    init(from comment: Comment,
         gamificationLevels: [GamificationLevel],
         ellipsizeText: Bool = false,
         liveMeasurePublisher: CurrentValueSubject<LiveMeasures, Never>,
         thisUserProfileId: String?, dateFormatter: RelativeDateTimeFormatter,
         onAppearAction: @escaping () -> Void, onDisappearAction: @escaping () -> Void) {
        kind = .comment
        uuid = comment.uuid

        text = EllipsizableTranslatedText(text: comment.text, ellipsize: ellipsizeText)

        author = .init(
            profile: comment.author,
            gamificationLevel: gamificationLevels.first { $0.level == comment.author?.gamificationLevel }
        )
        relativeDate = dateFormatter.customLocalizedStructure(for: comment.creationDate, relativeTo: Date())
        image = ImageMedia(from: comment.medias.first(where: { $0.kind == .image }))
        canBeDeleted = comment.author != nil && comment.author?.uuid == thisUserProfileId
        canBeModerated = comment.author?.uuid != thisUserProfileId
        _liveMeasuresPublisher = liveMeasurePublisher
        displayEvents = CellDisplayEvents(onAppear: onAppearAction, onDisappear: onDisappearAction)
    }

    init(from reply: Reply,
         gamificationLevels: [GamificationLevel],
         liveMeasurePublisher: CurrentValueSubject<LiveMeasures, Never>,
         thisUserProfileId: String?, dateFormatter: RelativeDateTimeFormatter,
         onAppearAction: @escaping () -> Void, onDisappearAction: @escaping () -> Void) {
        kind = .reply
        uuid = reply.uuid
        text = EllipsizableTranslatedText(text: reply.text, ellipsize: false)
        author = .init(
            profile: reply.author,
            gamificationLevel: gamificationLevels.first { $0.level == reply.author?.gamificationLevel }
        )
        relativeDate = dateFormatter.customLocalizedStructure(for: reply.creationDate, relativeTo: Date())
        image = ImageMedia(from: reply.medias.first(where: { $0.kind == .image }))
        canBeDeleted = reply.author != nil && reply.author?.uuid == thisUserProfileId
        canBeModerated = reply.author?.uuid != thisUserProfileId
        _liveMeasuresPublisher = liveMeasurePublisher
        displayEvents = CellDisplayEvents(onAppear: onAppearAction, onDisappear: onDisappearAction)
    }
}
