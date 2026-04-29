//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import Foundation
import SwiftUI
import OctopusCore
import Combine

struct ResponseFeedItemView: View {
    @Environment(\.trackingApi) private var trackingApi
    @EnvironmentObject private var languageManager: LanguageManager

    let response: DisplayableFeedResponse
    var displayChildCount: Bool = true
    /// Optional card-level tap handler. `nil` (the default) means the card is not tappable as a
    /// whole — only the avatar, action bar, and "See N replies" row are interactive. Pass a
    /// closure when you want the full card to be tappable (e.g. the featured comment in
    /// `PostSummaryView` opens the parent post detail on card tap).
    var onCardTap: (() -> Void)?
    @Binding var zoomableImageInfo: ZoomableImageInfo?
    let displayResponseDetail: (_ id: String, _ reply: Bool) -> Void
    let displayProfile: (String) -> Void
    let deleteResponse: (String) -> Void
    let blockAuthor: (String) -> Void
    let reactionTapped: (ReactionKind?, String) -> Void
    let displayContentModeration: (String) -> Void

    @State private var groupedForAccessibility = true

    var body: some View {
        ResponseView(
            response: ResponseViewData(from: response),
            context: .summary(onCardTap: onCardTap),
            showsRepliesRow: displayChildCount,
            zoomableImageInfo: $zoomableImageInfo,
            reactionTapped: { reactionTapped($0, response.uuid) },
            displayProfile: displayProfile,
            deleteResponse: { deleteResponse(response.uuid) },
            blockAuthor: blockAuthor,
            openCreateReply: {
                trackingApi.emit(event: .replyButtonClicked(.init(commentId: response.uuid)))
                displayResponseDetail(response.uuid, true)
            },
            openRepliesList: {
                trackingApi.emit(event: .seeRepliesButtonClicked(.init(commentId: response.uuid)))
                displayResponseDetail(response.uuid, false)
            },
            displayContentModeration: displayContentModeration)
        // Accessibility grouping mirrors `PostSummaryView`: by default VoiceOver reads the
        // whole cell as a single element (using `accessibilityDescription`); the "Read
        // elements" custom action flips the toggle so individual children (author, date,
        // reactions, reply button, etc.) become focusable. Changing the `id` forces SwiftUI
        // to rebuild the subtree so the new accessibility tree is picked up.
        .id("\(response.kind)-\(response.uuid)-\(groupedForAccessibility)")
        .accessibilityElement(children: groupedForAccessibility ? .ignore : .contain)
        .accessibilityLabelInBundle(groupedForAccessibility ? accessibilityDescription : nil)
        .accessibilityAction(named: Text(
            groupedForAccessibility
                ? "Accessibility.Content.Action.ReadElements"
                : "Accessibility.Content.Action.ReadSummary",
            bundle: .module)) {
            groupedForAccessibility.toggle()
            refreshVoiceOverFocus(on: self)
        }
        .modify {
            if let authorId = response.author.profileId {
                $0.accessibilityAction(named: Text("Accessibility.Content.Action.ViewAuthor", bundle: .module)) {
                    displayProfile(authorId)
                }
            } else { $0 }
        }
        .modify {
            if response.kind.canReply {
                $0.accessibilityAction(named: Text("Accessibility.Content.Action.OpenDetail", bundle: .module)) {
                    displayResponseDetail(response.uuid, false)
                }
            } else { $0 }
        }
    }

    private var accessibilityDescription: LocalizedStringKey {
        let authorName = response.author.name.localizedString(locale: languageManager.overridenLocale)

        if let responseText = response.text {
            let text = responseText.getText(translated: true)
            let textToRead = "\(text)\(responseText.getIsEllipsized(translated: true) ? "..." : "")"
            if response.image != nil {
                return "Accessibility.Response.Summary.TextAndImage_author:\(authorName)_date:\(response.relativeDate)_text:\(textToRead)"
            } else {
                return "Accessibility.Response.Summary.TextOnly_author:\(authorName)_date:\(response.relativeDate)_text:\(textToRead)"
            }
        } else if response.image != nil {
            return "Accessibility.Response.Summary.Image_author:\(authorName)_date:\(response.relativeDate)"
        } else {
            return "Accessibility.Response.Summary.TextOnly_author:\(authorName)_date:\(response.relativeDate)_text:\("")"
        }
    }
}

#Preview("Text") {
    ResponseFeedItemView(
        response: .init(
            kind: .comment,
            uuid: "commentId",
            text: .init(text: .init(
                originalText: "Un texte",
                originalLanguage: nil)),
            image: nil,
            author: Author(
                profile: MinimalProfile(
                    uuid: "profileId",
                    nickname: "Bobby",
                    avatarUrl: URL(string: "https://randomuser.me/api/portraits/men/75.jpg")!,
                    gamificationLevel: 1),
                gamificationLevel: GamificationLevel(
                    level: 1, name: "", startAt: 0, nextLevelAt: 100,
                    badgeColor: DynamicColor(lightValue: "#FF0000", darkValue: "#FFFF00"),
                    badgeTextColor: DynamicColor(lightValue: "#FFFFFF", darkValue: "#000000"))),
            relativeDate: "2h. ago",
            canBeDeleted: false,
            canBeModerated: true,
            canBeBlockedByUser: true,
            _liveMeasuresPublisher: CurrentValueSubject(LiveMeasures(
                aggregatedInfo: .init(reactions: [
                    .init(reactionKind: .heart, count: 10),
                    .init(reactionKind: .clap, count: 5)
                ], childCount: 5, viewCount: 4, pollResult: nil),
                userInteractions: .empty)),
            displayEvents: .init(onAppear: {}, onDisappear: {})
        ),
        zoomableImageInfo: .constant(nil),
        displayResponseDetail: { _, _ in },
        displayProfile: { _ in },
        deleteResponse: { _ in },
        blockAuthor: { _ in },
        reactionTapped: { _, _ in },
        displayContentModeration: { _ in })
    .mockEnvironmentForPreviews()
}

#Preview("Text and image") {
    ResponseFeedItemView(
        response: .init(
            kind: .comment,
            uuid: "commentId",
            text: .init(text: .init(
                originalText: "Un texte",
                originalLanguage: "fr",
                translatedText: "A text")),
            image: .init(
                url: URL(string: "https://picsum.photos/700/750")!,
                size: CGSize(width: 700, height: 750)),
            author: Author(
                profile: MinimalProfile(
                    uuid: "profileId",
                    nickname: "Bobby",
                    avatarUrl: URL(string: "https://randomuser.me/api/portraits/men/75.jpg")!,
                    gamificationLevel: 1),
                gamificationLevel: GamificationLevel(
                    level: 1, name: "", startAt: 0, nextLevelAt: 100,
                    badgeColor: DynamicColor(lightValue: "#FF0000", darkValue: "#FFFF00"),
                    badgeTextColor: DynamicColor(lightValue: "#FFFFFF", darkValue: "#000000"))),
            relativeDate: "2h. ago",
            canBeDeleted: false,
            canBeModerated: true,
            canBeBlockedByUser: true,
            _liveMeasuresPublisher: CurrentValueSubject(LiveMeasures(
                aggregatedInfo: .init(reactions: [
                    .init(reactionKind: .heart, count: 10),
                    .init(reactionKind: .clap, count: 5)
                ], childCount: 0, viewCount: 4, pollResult: nil),
                userInteractions: .empty)),
            displayEvents: .init(onAppear: {}, onDisappear: {})
        ),
        zoomableImageInfo: .constant(nil),
        displayResponseDetail: { _, _ in },
        displayProfile: { _ in },
        deleteResponse: { _ in },
        blockAuthor: { _ in },
        reactionTapped: { _, _ in },
        displayContentModeration: { _ in })
    .mockEnvironmentForPreviews()
}

#Preview("Image") {
    ResponseFeedItemView(
        response: .init(
            kind: .comment,
            uuid: "commentId",
            text: nil,
            image: .init(
                url: URL(string: "https://picsum.photos/700/750")!,
                size: CGSize(width: 700, height: 750)),
            author: Author(
                profile: MinimalProfile(
                    uuid: "profileId",
                    nickname: "Bobby",
                    avatarUrl: URL(string: "https://randomuser.me/api/portraits/men/75.jpg")!,
                    gamificationLevel: 1),
                gamificationLevel: GamificationLevel(
                    level: 1, name: "", startAt: 0, nextLevelAt: 100,
                    badgeColor: DynamicColor(lightValue: "#FF0000", darkValue: "#FFFF00"),
                    badgeTextColor: DynamicColor(lightValue: "#FFFFFF", darkValue: "#000000"))),
            relativeDate: "2h. ago",
            canBeDeleted: false,
            canBeModerated: true,
            canBeBlockedByUser: true,
            _liveMeasuresPublisher: CurrentValueSubject(LiveMeasures(
                aggregatedInfo: .init(reactions: [
                    .init(reactionKind: .heart, count: 10),
                    .init(reactionKind: .clap, count: 5)
                ], childCount: 5, viewCount: 4, pollResult: nil),
                userInteractions: .empty)),
            displayEvents: .init(onAppear: {}, onDisappear: {})
        ),
        zoomableImageInfo: .constant(nil),
        displayResponseDetail: { _, _ in },
        displayProfile: { _ in },
        deleteResponse: { _ in },
        blockAuthor: { _ in },
        reactionTapped: { _, _ in },
        displayContentModeration: { _ in })
    .mockEnvironmentForPreviews()
}

#Preview("No translation") {
    ResponseFeedItemView(
        response: .init(
            kind: .comment,
            uuid: "commentId",
            text: .init(text: .init(
                originalText: "Un texte",
                originalLanguage: nil)),
            image: .init(
                url: URL(string: "https://picsum.photos/700/750")!,
                size: CGSize(width: 700, height: 750)),
            author: Author(
                profile: MinimalProfile(
                    uuid: "profileId",
                    nickname: "Bobby",
                    avatarUrl: URL(string: "https://randomuser.me/api/portraits/men/75.jpg")!,
                    gamificationLevel: 1),
                gamificationLevel: GamificationLevel(
                    level: 1, name: "", startAt: 0, nextLevelAt: 100,
                    badgeColor: DynamicColor(lightValue: "#FF0000", darkValue: "#FFFF00"),
                    badgeTextColor: DynamicColor(lightValue: "#FFFFFF", darkValue: "#000000"))),
            relativeDate: "2h. ago",
            canBeDeleted: false,
            canBeModerated: true,
            canBeBlockedByUser: true,
            _liveMeasuresPublisher: CurrentValueSubject(LiveMeasures(
                aggregatedInfo: .init(reactions: [
                    .init(reactionKind: .heart, count: 10),
                    .init(reactionKind: .clap, count: 5)
                ], childCount: 5, viewCount: 4, pollResult: nil),
                userInteractions: .empty)),
            displayEvents: .init(onAppear: {}, onDisappear: {})
        ),
        zoomableImageInfo: .constant(nil),
        displayResponseDetail: { _, _ in },
        displayProfile: { _ in },
        deleteResponse: { _ in },
        blockAuthor: { _ in },
        reactionTapped: { _, _ in },
        displayContentModeration: { _ in })
    .mockEnvironmentForPreviews()
}
