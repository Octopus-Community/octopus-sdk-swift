//
//  Copyright © 2024 Octopus Community. All rights reserved.
//

import Foundation
import SwiftUI
import OctopusCore

struct ResponseFeedItemView: View {
    @Environment(\.octopusTheme) private var theme
    @EnvironmentObject private var translationStore: ContentTranslationPreferenceStore

    let response: DisplayableFeedResponse
    var displayChildCount: Bool = true
    var tapToOpenDetail: Bool = false
    @Binding var zoomableImageInfo: ZoomableImageInfo?
    let displayResponseDetail: (_ id: String, _ reply: Bool) -> Void
    let displayParentDetail: (String) -> Void
    let displayProfile: (String) -> Void
    let deleteResponse: (String) -> Void
    let reactionTapped: (ReactionKind?, String) -> Void
    let displayContentModeration: (String) -> Void

    @State private var openActions = false
    @State private var displayDeleteAlert = false

    @State private var liveMeasures: LiveMeasures?
    @State private var showReactionPicker = false

    @State private var groupedForAccessibility = true

    @Compat.ScaledMetric(relativeTo: .subheadline) var moreIconSize: CGFloat = 24 // subheadline to vary from 19 to 69
    @Compat.ScaledMetric(relativeTo: .largeTitle) var authorAvatarSize: CGFloat = 32 // title1 to vary from 29 to 54

    private let minAspectRatio: CGFloat = 4 / 5

    var displayTranslation: Bool { translationStore.displayTranslation(for: response.uuid) }

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            OpenProfileButton(author: response.author, displayProfile: displayProfile) {
                HStack {
                    AuthorAvatarView(avatar: response.author.avatar)
                        .frame(width: max(authorAvatarSize, 32), height: max(authorAvatarSize, 32))
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                }
                .frame(width: max(authorAvatarSize, 44), height: max(authorAvatarSize, 44), alignment: .top)
                // trailing padding is size of (button - 44) max 8. So when button is 44, it will be 0,
                // when button is big, it will be 8
                .padding(.trailing, min(max(authorAvatarSize, 32) - 32, 8))
            }
            .padding(.top, 8)

            VStack(spacing: 0) {
                VStack(spacing: 0) {
                    VStack(alignment: .leading, spacing: 0) {
                        HStack(alignment: .top, spacing: 4) {
                            AuthorAndDateHeaderView(author: response.author, relativeDate: response.relativeDate,
                                                    topPadding: 16, bottomPadding: 4,
                                                    displayProfile: displayProfile)
                            Spacer()
                            if response.canBeDeleted || response.canBeModerated {
                                if #available(iOS 14.0, *) {
                                    Menu(content: {
                                        if response.canBeDeleted {
                                            Button(action: { displayDeleteAlert = true }) {
                                                Label(L10n(response.kind.deleteButtonTextStr), systemImage: "trash")
                                            }
                                            .buttonStyle(.plain)
                                        }
                                        if response.canBeModerated {
                                            Button(action: { displayContentModeration(response.uuid) }) {
                                                Label(L10n("Moderation.Content.Button"), systemImage: "flag")
                                            }
                                            .buttonStyle(.plain)
                                        }
                                    }, label: {
                                        HStack {
                                            Image(res: .more)
                                                .resizable()
                                                .aspectRatio(contentMode: .fit)
                                                .frame(width: max(moreIconSize, 24), height: max(moreIconSize, 24))
                                                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .trailing)
                                                .foregroundColor(theme.colors.gray500)
                                                .accessibilityLabelInBundle("Accessibility.Common.More")
                                                .padding(.top, 8)
                                        }.frame(width: max(moreIconSize, 44), height: max(moreIconSize, 44))
                                    })
                                    .buttonStyle(.plain)
                                } else {
                                    Button(action: { openActions = true }) {
                                        Image(res: .more)
                                            .resizable()
                                            .frame(width: max(moreIconSize, 24), height: max(moreIconSize, 24))
                                            .foregroundColor(theme.colors.gray500)
                                            .accessibilityLabelInBundle("Accessibility.Common.More")
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }

                        if let translatableText = response.text,
                           let text = translatableText.getText(translated: displayTranslation).nilIfEmpty {
                            ButtonOrContent(
                                embedInButton: tapToOpenDetail,
                                action: { displayParentDetail(response.uuid ) }) {
                                    Group {
                                        if translatableText.getIsEllipsized(translated: displayTranslation) {
                                            Text(verbatim: "\(text)... ")
                                            +
                                            Text("Common.ReadMore", bundle: .module)
                                                .fontWeight(.medium)
                                                .foregroundColor(theme.colors.gray500)
                                        } else {
                                            RichText(text)
                                        }
                                    }
                                    .multilineTextAlignment(.leading)
                                    .contentShape(Rectangle())
                                }
                                .font(theme.fonts.body2)
                                .lineSpacing(4)
                                .foregroundColor(theme.colors.gray900)
                                .fixedSize(horizontal: false, vertical: true)
                                .buttonStyle(.plain)

                            if translatableText.hasTranslation {
                                ToggleTextTranslationButton(contentId: response.uuid,
                                                            originalLanguage: translatableText.originalLanguage)
                            } else {
                                Spacer().frame(height: 8)
                            }
                        } else {
                            Spacer().frame(height: 4)
                        }
                    }
                    .padding(.horizontal, 8)
                    if let image = response.image {
                        AsyncCachedImage(
                            url: image.url, cache: .content,
                            croppingRatio: minAspectRatio,
                            placeholder: {
                                theme.colors.gray200
                                    .aspectRatio(
                                        max(image.size.width/image.size.height, minAspectRatio),
                                        contentMode: .fit)
                                    .clipped()
                            },
                            content: { cachedImage in
                                Image(uiImage: cachedImage.ratioImage)
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .modify {
                                        if zoomableImageInfo?.url != image.url {
                                            $0.namespacedMatchedGeometryEffect(id: image.url, isSource: true)
                                        } else {
                                            $0
                                        }
                                    }
                                    .onTapGesture {
                                        withAnimation {
                                            zoomableImageInfo = .init(
                                                url: image.url,
                                                image: Image(uiImage: cachedImage.fullSizeImage))
                                        }
                                    }
                            })
                        .cornerRadius(12)
                    }
                }
                .frame(maxWidth: .infinity)
                .background(
                    RoundedRectangle(cornerSize: CGSize(width: 12, height: 12))
                        .foregroundColor(theme.colors.gray200)
                        .padding(.top, 8)
                )

                let userInteractions = liveMeasures?.userInteractions ?? response.liveMeasuresValue.userInteractions
                let aggregatedInfo = liveMeasures?.aggregatedInfo ?? response.liveMeasuresValue.aggregatedInfo
                ResponseReactionBarView(
                    userReaction: userInteractions.reaction,
                    canReply: response.kind.canReply,
                    reactions: aggregatedInfo.reactions,
                    reactionTapped: { reactionTapped($0, response.uuid) },
                    openCreateReply: { displayResponseDetail(response.uuid, true) }
                )

                if response.kind.canReply && displayChildCount && aggregatedInfo.childCount > 0 {
                    Button(action: { displayResponseDetail(response.uuid, false) }) {
                        HStack {
                            Image(systemName: "arrow.right")
                                .accessibilityHidden(true)
                            Text("Reply.See_count:\(aggregatedInfo.childCount)", bundle: .module)
                            Spacer()
                        }
                        .font(theme.fonts.caption1.weight(.semibold))
                        .foregroundColor(theme.colors.primary)
                        .contentShape(Rectangle())
                        .padding(.bottom, 27)
                    }
                }
            }
        }
        .id("\(response.kind.identifierPrefix)-\(response.uuid)-\(groupedForAccessibility)")
        .accessibilityElement(children: groupedForAccessibility ? .ignore : .contain)
        .accessibilityLabelInBundle(groupedForAccessibility ? accessibilityDescription : nil)
        .accessibilityAction(named: Text(groupedForAccessibility ? "Accessibility.Content.Action.ReadElements" : "Accessibility.Content.Action.ReadSummary", bundle: .module)) {
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
        .actionSheet(isPresented: $openActions) {
            ActionSheet(title: Text("ActionSheet.Title", bundle: .module), buttons: actionSheetContent)
        }
        .modify {
            if #available(iOS 15.0, *) {
                $0.alert(
                    Text(response.kind.deleteConfirmationTitle, bundle: .module),
                    isPresented: $displayDeleteAlert) {
                        Button(role: .cancel, action: {}, label: { Text("Common.Cancel", bundle: .module) })
                        Button(role: .destructive, action: { deleteResponse(response.uuid) },
                               label: { Text("Common.Delete", bundle: .module) })
                    }
            } else {
                $0.alert(isPresented: $displayDeleteAlert) {
                    Alert(title: Text(response.kind.deleteConfirmationTitle,
                                      bundle: .module),
                          primaryButton: .default(Text("Common.Cancel", bundle: .module)),
                          secondaryButton: .destructive(
                            Text("Common.Delete", bundle: .module),
                            action: { deleteResponse(response.uuid) }
                          )
                    )
                }
            }
        }
        .onReceive(response.liveMeasures) {
            liveMeasures = $0
        }
    }

    var actionSheetContent: [ActionSheet.Button] {
        var buttons: [ActionSheet.Button] = []
        if response.canBeDeleted {
            buttons.append(ActionSheet.Button.destructive(Text(response.kind.deleteButtonText, bundle: .module)) {
                displayDeleteAlert = true
            })
        }
        if response.canBeModerated {
            buttons.append(ActionSheet.Button.destructive(Text("Moderation.Content.Button", bundle: .module)) {
                displayContentModeration(response.uuid)
            })
        }

        buttons.append(.cancel())
        return buttons
    }

    var accessibilityDescription: LocalizedStringKey {
        let authorName = response.author.name.localizedString

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

private extension ResponseKind {
    var identifierPrefix: String {
        switch self {
        case .comment: "Comment"
        case .reply: "Reply"
        }
    }
    var deleteButtonText: LocalizedStringKey {
        switch self {
        case .comment: "Comment.Delete.Button"
        case .reply: "Reply.Delete.Button"
        }
    }

    var deleteButtonTextStr: String {
        switch self {
        case .comment: "Comment.Delete.Button"
        case .reply: "Reply.Delete.Button"
        }
    }

    var deleteConfirmationTitle: LocalizedStringKey {
        switch self {
        case .comment: "Comment.Delete.Confirmation.Title"
        case .reply: "Reply.Delete.Confirmation.Title"
        }
    }
}

import Combine
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
                    badgeColor: DynamicColor(hexLight: "#FF0000", hexDark: "#FFFF00"),
                    badgeTextColor: DynamicColor(hexLight: "#FFFFFF", hexDark: "#000000"))),
            relativeDate: "2h. ago",
            canBeDeleted: false,
            canBeModerated: true,
            _liveMeasuresPublisher: CurrentValueSubject(LiveMeasures(
                aggregatedInfo: .init(reactions: [
                    .init(reactionKind: .heart, count: 10),
                    .init(reactionKind: .clap, count: 5),
                ], childCount: 5, viewCount: 4, pollResult: nil),
                userInteractions: .empty)),
            displayEvents: .init(onAppear: {}, onDisappear: {})
        ),
        zoomableImageInfo: .constant(nil),
        displayResponseDetail: { _, _ in },
        displayParentDetail: { _ in },
        displayProfile: { _ in },
        deleteResponse: { _ in },
        reactionTapped: { _, _ in },
        displayContentModeration: { _ in })
    .mockContentTranslationPreferenceStore()
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
                    badgeColor: DynamicColor(hexLight: "#FF0000", hexDark: "#FFFF00"),
                    badgeTextColor: DynamicColor(hexLight: "#FFFFFF", hexDark: "#000000"))),
            relativeDate: "2h. ago",
            canBeDeleted: false,
            canBeModerated: true,
            _liveMeasuresPublisher: CurrentValueSubject(LiveMeasures(
                aggregatedInfo: .init(reactions: [
                    .init(reactionKind: .heart, count: 10),
                    .init(reactionKind: .clap, count: 5),
                ], childCount: 0, viewCount: 4, pollResult: nil),
                userInteractions: .empty)),
            displayEvents: .init(onAppear: {}, onDisappear: {})
        ),
        zoomableImageInfo: .constant(nil),
        displayResponseDetail: { _, _ in },
        displayParentDetail: { _ in },
        displayProfile: { _ in },
        deleteResponse: { _ in },
        reactionTapped: { _, _ in },
        displayContentModeration: { _ in })
    .mockContentTranslationPreferenceStore()
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
                    badgeColor: DynamicColor(hexLight: "#FF0000", hexDark: "#FFFF00"),
                    badgeTextColor: DynamicColor(hexLight: "#FFFFFF", hexDark: "#000000"))),
            relativeDate: "2h. ago",
            canBeDeleted: false,
            canBeModerated: true,
            _liveMeasuresPublisher: CurrentValueSubject(LiveMeasures(
                aggregatedInfo: .init(reactions: [
                    .init(reactionKind: .heart, count: 10),
                    .init(reactionKind: .clap, count: 5),
                ], childCount: 5, viewCount: 4, pollResult: nil),
                userInteractions: .empty)),
            displayEvents: .init(onAppear: {}, onDisappear: {})
        ),
        zoomableImageInfo: .constant(nil),
        displayResponseDetail: { _, _ in },
        displayParentDetail: { _ in },
        displayProfile: { _ in },
        deleteResponse: { _ in },
        reactionTapped: { _, _ in },
        displayContentModeration: { _ in })
    .mockContentTranslationPreferenceStore()
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
                    badgeColor: DynamicColor(hexLight: "#FF0000", hexDark: "#FFFF00"),
                    badgeTextColor: DynamicColor(hexLight: "#FFFFFF", hexDark: "#000000"))),
            relativeDate: "2h. ago",
            canBeDeleted: false,
            canBeModerated: true,
            _liveMeasuresPublisher: CurrentValueSubject(LiveMeasures(
                aggregatedInfo: .init(reactions: [
                    .init(reactionKind: .heart, count: 10),
                    .init(reactionKind: .clap, count: 5),
                ], childCount: 5, viewCount: 4, pollResult: nil),
                userInteractions: .empty)),
            displayEvents: .init(onAppear: {}, onDisappear: {})
        ),
        zoomableImageInfo: .constant(nil),
        displayResponseDetail: { _, _ in },
        displayParentDetail: { _ in },
        displayProfile: { _ in },
        deleteResponse: { _ in },
        reactionTapped: { _, _ in },
        displayContentModeration: { _ in })
    .mockContentTranslationPreferenceStore()
}
