//
//  Copyright © 2024 Octopus Community. All rights reserved.
//

import SwiftUI

struct PostSummaryView: View {
    @Environment(\.octopusTheme) private var theme

    let post: DisplayablePost
    let width: CGFloat
    @Binding var zoomableImageInfo: ZoomableImageInfo?
    let displayPostDetail: (_ postId: String, _ comment: Bool, _ scrollToLatestComment: Bool) -> Void
    let displayProfile: (String) -> Void
    let deletePost: (String) -> Void
    let toggleLike: (String) -> Void
    let voteOnPoll: (String, String) -> Bool
    let displayContentModeration: (String) -> Void
    let displayClientObject: ((String) -> Void)?

    @State private var openActions = false
    @State private var displayDeleteAlert = false

    var body: some View {
        VStack {
            VStack(alignment: .leading, spacing: 8) {
                Group { // group views to have the same horizontal padding
                    HStack {
                        OpenProfileButton(author: post.author, displayProfile: displayProfile) {
                            AuthorAvatarView(avatar: post.author.avatar)
                                .frame(width: 40, height: 40)
                        }

                        VStack(alignment: .leading, spacing: 4) {
                            AuthorAndDateHeaderView(author: post.author, relativeDate: post.relativeDate,
                                                    displayProfile: displayProfile)
                            HStack(spacing: 4) {
                                OpenDetailButton(
                                    post: post,
                                    displayPostDetail: { displayPostDetail($0, false, false) }) {
                                        HStack {
                                            Text(post.topic)
                                                .octopusBadgeStyle(.small, status: .off)
                                            Spacer()
                                        }
                                    }
                                if case .moderated = post.content {
                                    Text("Post.Status.Moderated", bundle: .module)
                                        .font(theme.fonts.caption2)
                                        .fontWeight(.semibold)
                                        .foregroundColor(theme.colors.error)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(
                                            Capsule()
                                                .foregroundColor(theme.colors.error.opacity(0.1))
                                        )
                                }
                            }
                        }
                        Spacer()
                        if post.canBeDeleted || post.canBeModerated {
                            if #available(iOS 14.0, *) {
                                Menu(content: {
                                    if post.canBeDeleted {
                                        Button(action: { displayDeleteAlert = true }) {
                                            Label(L10n("Post.Delete.Button"), systemImage: "trash")
                                        }
                                    }
                                    if post.canBeModerated {
                                        Button(action: { displayContentModeration(post.uuid) }) {
                                            Label(L10n("Moderation.Content.Button"), systemImage: "flag")
                                        }
                                    }
                                }, label: {
                                    VStack {
                                        Image(res: .more)
                                            .resizable()
                                            .frame(width: 24, height: 24)
                                            .foregroundColor(theme.colors.gray500)
                                    }.frame(width: 32, height: 32)
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
                }.padding(.horizontal, 20)

                switch post.content {
                case let .published(postContent):
                    OpenDetailButton(post: post, displayPostDetail: { displayPostDetail($0, false, false) }) {
                        PublishedContentView(
                            content: postContent, width: width,
                            zoomableImageInfo: $zoomableImageInfo,
                            childrenTapped: {
                                let comment = postContent.liveMeasuresValue.aggregatedInfo.childCount == 0
                                displayPostDetail(post.uuid, comment, true) },
                            likeTapped: { toggleLike(post.uuid) },
                            voteOnPoll: { voteOnPoll($0, post.uuid) },
                            displayClientObject: displayClientObject)
                    }
                case let .moderated(reasons):
                    ModeratedPostContentView(reasons: reasons)
                }
            }
            .padding(.top, 16)
            .padding(.bottom, 8)

            theme.colors.gray300
                .frame(height: 1)
        }
        .id("post-\(post.uuid)")
        .actionSheet(isPresented: $openActions) {
            ActionSheet(title: Text("ActionSheet.Title", bundle: .module), buttons: actionSheetContent)
        }
        .modify {
            if #available(iOS 15.0, *) {
                $0.alert(
                    Text("Post.Delete.Confirmation.Title", bundle: .module),
                    isPresented: $displayDeleteAlert) {
                        Button(role: .cancel, action: {}, label: { Text("Common.Cancel", bundle: .module) })
                        Button(role: .destructive, action: { deletePost(post.uuid) },
                               label: { Text("Common.Delete", bundle: .module) })
                    }
            } else {
                $0.alert(isPresented: $displayDeleteAlert) {
                    Alert(title: Text("Post.Delete.Confirmation.Title",
                                      bundle: .module),
                          primaryButton: .default(Text("Common.Cancel", bundle: .module)),
                          secondaryButton: .destructive(
                            Text("Common.Delete", bundle: .module),
                            action: { deletePost(post.uuid) }
                          )
                    )
                }
            }
        }
    }

    var actionSheetContent: [ActionSheet.Button] {
        var buttons: [ActionSheet.Button] = []
        if post.canBeDeleted {
            buttons.append(ActionSheet.Button.destructive(Text("Post.Delete.Button", bundle: .module)) {
                displayDeleteAlert = true
            })
        }
        if post.canBeModerated {
            buttons.append(ActionSheet.Button.destructive(Text("Moderation.Content.Button", bundle: .module)) {
                displayContentModeration(post.uuid)
            })
        }

        buttons.append(.cancel())
        return buttons
    }
}

private struct PublishedContentView: View {
    @Environment(\.octopusTheme) private var theme
    let content: DisplayablePost.PostContent

    let width: CGFloat
    @Binding var zoomableImageInfo: ZoomableImageInfo?
    let childrenTapped: () -> Void
    let likeTapped: () -> Void
    let voteOnPoll: (String) -> Bool
    let displayClientObject: ((String) -> Void)?
    private let minAspectRatio: CGFloat = 4 / 5

    @State private var liveMeasures: LiveMeasures?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Group {
                if content.textIsEllipsized {
                    Text(verbatim: "\(content.text)... ")
                    +
                    Text("Post.List.ReadMore", bundle: .module)
                        .bold()
                } else {
                    Text(content.text)
                }
            }
            .font(theme.fonts.body2)
            .foregroundColor(theme.colors.gray900)
            .contentShape(Rectangle())
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, 20)

            switch content.attachment {
            case let .image(image):
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
                            .modify {
                                if #available(iOS 15.0, *) {
                                    // put the tap in an overlay because it seems that the image touch area is not
                                    // clipped. Hence, it takes the tap over the text. When put in an overlay, it seems
                                    // to work correctly
                                    $0.overlay {
                                        Color.white.opacity(0.0001)
                                            .onTapGesture {
                                                withAnimation {
                                                    zoomableImageInfo = .init(
                                                        url: image.url,
                                                        image: Image(uiImage: cachedImage.fullSizeImage),
                                                        transitionImage: Image(uiImage: cachedImage.ratioImage))
                                                }
                                            }
                                    }
                                } else {
                                    $0.onTapGesture {
                                        withAnimation {
                                            zoomableImageInfo = .init(
                                                url: image.url,
                                                image: Image(uiImage: cachedImage.fullSizeImage))
                                        }
                                    }
                                }
                            }
                    })
            case let .poll(poll):
                PollView(poll: poll,
                         aggregatedInfo: liveMeasures?.aggregatedInfo ?? content.liveMeasuresValue.aggregatedInfo,
                         userInteractions: liveMeasures?.userInteractions ?? content.liveMeasuresValue.userInteractions,
                         vote: voteOnPoll)
                .padding(.horizontal, 20)
            case .none:
                EmptyView()
            }

            HStack {
                AggregatedInfoView(
                    aggregatedInfo: liveMeasures?.aggregatedInfo ?? content.liveMeasuresValue.aggregatedInfo,
                    userInteractions: liveMeasures?.userInteractions ?? content.liveMeasuresValue.userInteractions,
                    displayLabels: content.bridgeCTA == nil || displayClientObject == nil,
                    childrenTapped: childrenTapped, likeTapped: likeTapped)
                .layoutPriority(1)
                Spacer()
                if let bridgeCTA = content.bridgeCTA, let displayClientObject {
                    Button(action: { displayClientObject(bridgeCTA.clientObjectId) }) {
                        Text(bridgeCTA.text)
                            .lineLimit(1)
                    }
                    .buttonStyle(OctopusButtonStyle(.mid(.main)))
                }
            }
            .padding(.horizontal, 20)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .multilineTextAlignment(.leading)
        .onReceive(content.liveMeasures) { newLiveMeasures in
            guard newLiveMeasures != liveMeasures else { return }
            withAnimation {
                liveMeasures = newLiveMeasures
            }
        }
    }
}

private struct ModeratedPostContentView: View {
    @Environment(\.octopusTheme) private var theme
    let reasons: [DisplayableString]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Group {
                Text("Post.List.ModeratedPost.MainText", bundle: .module)
                    .font(theme.fonts.body2)
                    .fontWeight(.semibold)
                    .multilineTextAlignment(.leading)

                Group {
                    Text("Post.List.ModeratedPost.Reason", bundle: .module) + reasons.textView
                }.font(theme.fonts.caption1)
            }
            .padding(.horizontal, 20)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .multilineTextAlignment(.leading)
    }
}

private struct OpenDetailButton<Content: View>: View {
    let post: DisplayablePost
    let displayPostDetail: (String) -> Void
    @ViewBuilder let content: Content

    var body: some View {
        Button(action: {
            if post.canBeOpened {
                displayPostDetail(post.uuid)
            }
        }) {
            content
                .contentShape(Rectangle())
        }.buttonStyle(.plain)
    }
}
