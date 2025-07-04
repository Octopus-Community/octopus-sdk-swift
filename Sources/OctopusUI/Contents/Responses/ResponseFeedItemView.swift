//
//  Copyright © 2024 Octopus Community. All rights reserved.
//

import Foundation
import SwiftUI

struct ResponseFeedItemView: View {
    @Environment(\.octopusTheme) private var theme
    let response: DisplayableFeedResponse
    @Binding var zoomableImageInfo: ZoomableImageInfo?
    let displayResponseDetail: (String) -> Void
    let replyToResponse: (String) -> Void
    let displayProfile: (String) -> Void
    let deleteResponse: (String) -> Void
    let toggleLike: (String) -> Void
    let displayContentModeration: (String) -> Void

    @State private var openActions = false
    @State private var displayDeleteAlert = false

    @State private var liveMeasures: LiveMeasures = .init(aggregatedInfo: .empty, userInteractions: .empty)

    private let minAspectRatio: CGFloat = 4 / 5

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            OpenProfileButton(author: response.author, displayProfile: displayProfile) {
                AuthorAvatarView(avatar: response.author.avatar)
                    .frame(width: 32, height: 32)
            }
            VStack(spacing: 0) {
                VStack {
                    VStack(alignment: .leading) {
                        HStack(spacing: 4) {
                            AuthorAndDateHeaderView(author: response.author, relativeDate: response.relativeDate,
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
                                        Image(res: .more)
                                            .resizable()
                                            .frame(width: 24, height: 24)
                                            .foregroundColor(theme.colors.gray500)
                                    })
                                    .buttonStyle(.plain)
                                } else {
                                    Button(action: { openActions = true }) {
                                        Image(res: .more)
                                            .resizable()
                                            .frame(width: 24, height: 24)
                                            .foregroundColor(theme.colors.gray500)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                        if let text = response.text?.nilIfEmpty {
                            RichText(text)
                                .font(theme.fonts.body2)
                                .lineSpacing(4)
                                .foregroundColor(theme.colors.gray900)
                                .fixedSize(horizontal: false, vertical: true)
                        }

                    }
                    .padding(8)
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
                )

                let userInteractions = liveMeasures.userInteractions
                let aggregatedInfo = liveMeasures.aggregatedInfo
                HStack(spacing: 24) {
                    Button(action: { toggleLike(response.uuid) }) {
                        AggregateView(image: userInteractions.hasLiked ? .AggregatedInfo.likeActivated : .AggregatedInfo.like,
                                      imageForegroundColor: userInteractions.hasLiked ?
                                      theme.colors.like : theme.colors.gray700,
                                      count: aggregatedInfo.likeCount,
                                      nullDisplayValue: "Content.AggregatedInfo.Like")
                    }
                    .buttonStyle(.plain)

                    if response.kind.canReply {
                        Button(action: { replyToResponse(response.uuid) }) {
                            AggregateView(image: .AggregatedInfo.comment, count: 0,
                                          nullDisplayValue: "Content.AggregatedInfo.Answer")
                        }
                        .buttonStyle(.plain)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 8)
                .padding(.top, 6)
                .padding(.bottom, 8)

                if response.kind.canReply && aggregatedInfo.childCount > 0 {
                    Button(action: { displayResponseDetail(response.uuid) }) {
                        HStack {
                            Image(systemName: "arrow.right")
                            Text("Reply.See_count:\(aggregatedInfo.childCount)", bundle: .module)
                            Spacer()
                        }
                        .font(theme.fonts.caption1.weight(.semibold))
                        .foregroundColor(theme.colors.primary)
                        .contentShape(Rectangle())
                    }
                }
            }
        }
        .padding(.bottom, 10)
        .id("\(response.kind.identifierPrefix)-\(response.uuid)")
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
