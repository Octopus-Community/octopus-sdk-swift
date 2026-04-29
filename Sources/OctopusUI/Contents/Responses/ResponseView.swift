//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import Combine
import SwiftUI
import OctopusCore

// MARK: - Main View

/// Shared comment/reply renderer used in both list (summary) and detail contexts.
/// Owns the delete-confirmation alert and the iOS 13 action-sheet state; delegates layout to
/// the private `ResponseContentView`.
struct ResponseView: View {
    @Environment(\.octopusTheme) private var theme

    let response: ResponseViewData
    let context: ResponseViewContext
    /// When false, the "See X replies" row is hidden even if childCount > 0. Used by callers
    /// that embed a response inside a compact container (e.g. featured comment in a post summary).
    let showsRepliesRow: Bool
    @Binding var zoomableImageInfo: ZoomableImageInfo?

    let reactionTapped: (ReactionKind?) -> Void
    let displayProfile: (String) -> Void
    let deleteResponse: () -> Void
    let blockAuthor: (String) -> Void
    let openCreateReply: () -> Void
    let openRepliesList: () -> Void
    let displayContentModeration: (String) -> Void

    @State private var displayDeleteAlert = false
    @State private var displayBlockAlert = false
    @State private var iOS13ActionSheetIsPresented = false

    init(
        response: ResponseViewData,
        context: ResponseViewContext,
        showsRepliesRow: Bool = true,
        zoomableImageInfo: Binding<ZoomableImageInfo?>,
        reactionTapped: @escaping (ReactionKind?) -> Void,
        displayProfile: @escaping (String) -> Void,
        deleteResponse: @escaping () -> Void,
        blockAuthor: @escaping (String) -> Void,
        openCreateReply: @escaping () -> Void,
        openRepliesList: @escaping () -> Void,
        displayContentModeration: @escaping (String) -> Void
    ) {
        self.response = response
        self.context = context
        self.showsRepliesRow = showsRepliesRow
        self._zoomableImageInfo = zoomableImageInfo
        self.reactionTapped = reactionTapped
        self.displayProfile = displayProfile
        self.deleteResponse = deleteResponse
        self.blockAuthor = blockAuthor
        self.openCreateReply = openCreateReply
        self.openRepliesList = openRepliesList
        self.displayContentModeration = displayContentModeration
    }

    var body: some View {
        ResponseContentView(
            response: response,
            context: context,
            showsRepliesRow: showsRepliesRow,
            zoomableImageInfo: $zoomableImageInfo,
            iOS13ActionSheetIsPresented: $iOS13ActionSheetIsPresented,
            onDelete: { displayDeleteAlert = true },
            onReport: { displayContentModeration(response.uuid) },
            onBlockAuthor: { displayBlockAlert = true },
            reactionTapped: reactionTapped,
            displayProfile: displayProfile,
            openCreateReply: openCreateReply,
            openRepliesList: openRepliesList)
        .destructiveConfirmationAlert(
            response.kind.deleteConfirmationKey,
            isPresented: $displayDeleteAlert,
            destructiveLabel: "Common.Delete",
            action: deleteResponse)
        .destructiveConfirmationAlert(
            "Block.Profile.Alert.Title",
            isPresented: $displayBlockAlert,
            destructiveLabel: "Common.Continue",
            action: {
                if let profileId = response.author.profileId {
                    blockAuthor(profileId)
                }
            },
            message: "Block.Profile.Alert.Message")
        .actionSheet(isPresented: $iOS13ActionSheetIsPresented) {
            ActionSheet(
                title: Text("ActionSheet.Title", bundle: .module),
                buttons: iOS13ActionSheetButtons)
        }
    }

    private var iOS13ActionSheetButtons: [ActionSheet.Button] {
        var buttons: [ActionSheet.Button] = []
        if response.canBeDeleted {
            buttons.append(.destructive(Text(response.kind.deleteButtonKey, bundle: .module)) {
                displayDeleteAlert = true
            })
        }
        if response.canBeModerated {
            buttons.append(.destructive(Text("Moderation.Content.Button", bundle: .module)) {
                displayContentModeration(response.uuid)
            })
        }
        if response.canBeBlockedByUser {
            buttons.append(.destructive(Text("Block.Profile.Button", bundle: .module)) {
                displayBlockAlert = true
            })
        }
        buttons.append(.cancel())
        return buttons
    }
}

// MARK: - Content View (pure renderer)

private struct ResponseContentView: View {
    @Environment(\.octopusTheme) private var theme

    let response: ResponseViewData
    let context: ResponseViewContext
    let showsRepliesRow: Bool
    @Binding var zoomableImageInfo: ZoomableImageInfo?
    @Binding var iOS13ActionSheetIsPresented: Bool

    let onDelete: () -> Void
    let onReport: () -> Void
    let onBlockAuthor: () -> Void
    let reactionTapped: (ReactionKind?) -> Void
    let displayProfile: (String) -> Void
    let openCreateReply: () -> Void
    let openRepliesList: () -> Void

    @Compat.ScaledMetric(relativeTo: .largeTitle) private var avatarSize: CGFloat = 32

    var body: some View {
        let addCardBottomSpacing = response.image == nil && !(response.text?.hasTranslation ?? true)
        let avatarSide = max(avatarSize, 32)
        // Top extension matches the Figma `pt-[6px]` whitespace above the comment. The same
        // value is reused by `ResponseCardView`'s invisible top inset so the avatar and card
        // have a consistent 6pt tappable strip above their visible content.
        let avatarTopExtension: CGFloat = 6
        // Trailing extension is the Figma `gap-[12px]` between avatar and card; we fold it
        // into the avatar button's hit area so taps in the visual gap open the profile.
        let avatarTrailingExtension: CGFloat = 12
        // Apple's minimum tap target — the bottom extension below is sized to make the avatar
        // button at least this tall at default Dynamic Type (at larger sizes the avatar itself
        // already exceeds it, so no extra bottom padding is added).
        let minTapHeight: CGFloat = 44
        HStack(alignment: .top, spacing: 0) {
            // Hit-area extension — same trick as `ResponseCardView` and `AuthorAndDateHeaderView`:
            // the visible 32×32 avatar sits at the bottom-leading corner of a larger invisible
            // frame. The extra 6pt of height and 12pt of width become transparent-but-tappable,
            // so taps in the 6pt zone above, the 12pt gap to the right, and the bottom strip
            // that pads the button up to the 44pt tap target all open the profile.
            OpenProfileButton(author: response.author, displayProfile: displayProfile) {
                AuthorAvatarView(avatar: response.author.avatar)
                    .frame(width: avatarSide, height: avatarSide)
                    .padding(.top, avatarTopExtension)
                    .padding(.trailing, avatarTrailingExtension)
                    // Ensure the button is at least 44pt tall (Apple min tap target). Clamped
                    // to 0 so very large Dynamic Type avatars don't get negative padding.
                    .padding(.bottom, max(minTapHeight - avatarSide - avatarTopExtension, 0))
            }

            VStack(alignment: .leading, spacing: 0) {
                ResponseCardView {
                    ResponseHeaderView(
                        kind: response.kind,
                        author: response.author,
                        relativeDate: response.relativeDate,
                        canBeDeleted: response.canBeDeleted,
                        canBeModerated: response.canBeModerated,
                        canBeBlockedByUser: response.canBeBlockedByUser,
                        displayProfile: displayProfile,
                        onDelete: onDelete,
                        onReport: onReport,
                        onBlockAuthor: onBlockAuthor,
                        iOS13ActionSheetIsPresented: $iOS13ActionSheetIsPresented)

                    if let text = response.text {
                        ResponseTextContentView(contentId: response.uuid, text: text)

                        if text.hasTranslation {
                            ResponseTranslationToggleView(
                                contentId: response.uuid,
                                originalLanguage: text.originalLanguage,
                                contentKind: contentKindForTracking)
                        }
                    }

                    // Figma "Spaccing when no image" — 8pt spacer inside the card when nothing
                    // else supplies the bottom whitespace. An image sits flush against the
                    // card's bottom rounded corners, and the translation toggle already carries
                    // its own 10pt bottom padding — in either case the spacer is skipped.
                    if addCardBottomSpacing {
                        Color.clear.frame(height: 8)
                    }

                    if let image = response.image {
                        ResponseImageContentView(image: image, zoomableImageInfo: $zoomableImageInfo)
                    }
                }

                ResponseActionBarView(
                    kind: response.kind,
                    liveMeasuresPublisher: response.liveMeasuresPublisher,
                    initialLiveMeasures: response.liveMeasuresValue,
                    reactionTapped: reactionTapped,
                    openCreateReply: openCreateReply)

                // Never show the "See X replies" row in `.detail`: the replies are already
                // rendered inline below by CommentDetailRepliesView, so the row would be
                // redundant and tapping it would just re-open the screen we're already on.
                if case .summary = context,
                   showsRepliesRow,
                   response.kind == .comment,
                   response.liveMeasuresValue.aggregatedInfo.childCount > 0 {
                    ResponseSeeRepliesView(
                        childCount: response.liveMeasuresValue.aggregatedInfo.childCount,
                        onTap: openRepliesList)
                }
            }
        }
        .padding(.horizontal, theme.sizes.horizontalPadding)
        .modify { view in
            if case let .summary(onCardTap) = context, let onCardTap {
                view.contentShape(Rectangle())
                    .onTapGesture(perform: onCardTap)
            } else {
                view
            }
        }
    }

    private var contentKindForTracking: SdkEvent.ContentKind {
        switch response.kind {
        case .comment: .comment
        case .reply:   .reply
        }
    }
}

// MARK: - Previews

#Preview("Summary — comment") {
    ResponseView(
        response: ResponseViewData(from: ResponseView.Previews.sampleResponse(kind: .comment)),
        context: .summary(onCardTap: {}),
        zoomableImageInfo: .constant(nil),
        reactionTapped: { _ in },
        displayProfile: { _ in },
        deleteResponse: {},
        blockAuthor: { _ in },
        openCreateReply: {},
        openRepliesList: {},
        displayContentModeration: { _ in })
    .mockEnvironmentForPreviews()
}

#Preview("Summary — reply") {
    ResponseView(
        response: ResponseViewData(from: ResponseView.Previews.sampleResponse(kind: .reply)),
        context: .summary(onCardTap: {}),
        zoomableImageInfo: .constant(nil),
        reactionTapped: { _ in },
        displayProfile: { _ in },
        deleteResponse: {},
        blockAuthor: { _ in },
        openCreateReply: {},
        openRepliesList: {},
        displayContentModeration: { _ in })
    .mockEnvironmentForPreviews()
}

#Preview("Detail — comment") {
    ResponseView(
        response: ResponseViewData(from: ResponseView.Previews.sampleResponse(kind: .comment)),
        context: .detail,
        zoomableImageInfo: .constant(nil),
        reactionTapped: { _ in },
        displayProfile: { _ in },
        deleteResponse: {},
        blockAuthor: { _ in },
        openCreateReply: {},
        openRepliesList: {},
        displayContentModeration: { _ in })
    .mockEnvironmentForPreviews()
}

// Fixture helper for previews (not exposed outside ResponseView.swift).
extension ResponseView {
    enum Previews {
        static func sampleResponse(
            kind: ResponseKind,
            text: String? = "A short sample comment or reply used in SwiftUI previews.",
            canBeBlockedByUser: Bool = true
        ) -> DisplayableFeedResponse {
            let author = Author(
                profile: MinimalProfile(
                    uuid: "profile-preview",
                    nickname: "Antoine",
                    avatarUrl: URL(string: "https://randomuser.me/api/portraits/men/75.jpg")!,
                    gamificationLevel: 1),
                gamificationLevel: nil)

            let subject = CurrentValueSubject<LiveMeasures, Never>(
                LiveMeasures(
                    aggregatedInfo: .init(reactions: [
                        .init(reactionKind: .heart, count: 5)
                    ], childCount: kind == .comment ? 3 : 0, viewCount: 0, pollResult: nil),
                    userInteractions: .empty))

            let ellipsizable: EllipsizableTranslatedText? = text.flatMap {
                EllipsizableTranslatedText(text: TranslatableText(originalText: $0, originalLanguage: nil),
                                           ellipsize: false)
            }

            return DisplayableFeedResponse(
                kind: kind,
                uuid: "response-preview",
                text: ellipsizable,
                image: nil,
                author: author,
                relativeDate: "il y a 3 min.",
                canBeDeleted: true,
                canBeModerated: true,
                canBeBlockedByUser: canBeBlockedByUser,
                _liveMeasuresPublisher: subject,
                displayEvents: .init(onAppear: {}, onDisappear: {}))
        }
    }
}
