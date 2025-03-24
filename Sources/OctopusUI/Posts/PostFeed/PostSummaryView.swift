//
//  Copyright © 2024 Octopus Community. All rights reserved.
//

import SwiftUI

struct PostSummaryView: View {
    @Environment(\.octopusTheme) private var theme

    let post: DisplayablePost
    let width: CGFloat
    let displayPostDetail: (String, Bool) -> Void
    let displayProfile: (String) -> Void
    let deletePost: (String) -> Void
    let toggleLike: (String) -> Void
    let displayContentModeration: (String) -> Void

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
                            HStack(spacing: 4) {
                                OpenProfileButton(author: post.author, displayProfile: displayProfile) {
                                    post.author.name.textView
                                        .font(theme.fonts.caption1)
                                        .fontWeight(.semibold)
                                        .foregroundColor(theme.colors.gray900)
                                }
                                Circle()
                                    .frame(width: 2, height: 2)
                                    .foregroundColor(theme.colors.gray900)
                                OpenDetailButton(post: post, displayPostDetail: { displayPostDetail($0, false) }) {
                                    HStack {
                                        Text(post.relativeDate)
                                            .font(theme.fonts.caption1)
                                            .fontWeight(.semibold)
                                            .foregroundColor(theme.colors.gray500)
                                        Spacer()
                                    }
                                }
                            }
                            HStack(spacing: 4) {
                                OpenDetailButton(post: post, displayPostDetail: { displayPostDetail($0, false) }) {
                                    HStack {
                                        Text(post.topic)
                                            .font(theme.fonts.caption2)
                                            .fontWeight(.semibold)
                                            .foregroundColor(theme.colors.primary)
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 4)
                                            .background(
                                                Capsule()
                                                    .foregroundColor(theme.colors.primaryLowContrast)
                                            )
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
                                        Image(.more)
                                            .resizable()
                                            .frame(width: 24, height: 24)
                                            .foregroundColor(theme.colors.gray500)
                                    }.frame(width: 32, height: 32)
                                })
                                .buttonStyle(.plain)
                            } else {
                                Button(action: { openActions = true }) {
                                    Image(.more)
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
                    OpenDetailButton(post: post, displayPostDetail: { displayPostDetail($0, false) }) {
                        PublishedContentView(content: postContent, width: width,
                                             childrenTapped: { displayPostDetail(post.uuid, true) },
                                             likeTapped: { toggleLike(post.uuid) })
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
    let childrenTapped: () -> Void
    let likeTapped: () -> Void
    private let minAspectRatio: CGFloat = 4 / 5

    @State private var liveMeasures: LiveMeasures = .init(aggregatedInfo: .empty, userInteractions: .empty)

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Group {
                if content.textIsEllipsized {
                    Text(verbatim: "\(content.text)... ")
                        .font(theme.fonts.body2)
                        .foregroundColor(theme.colors.gray900)
                    +
                    Text("Post.List.ReadMore", bundle: .module)
                        .font(theme.fonts.body2)
                        .bold()
                        .foregroundColor(theme.colors.gray900)
                } else {
                    Text(content.text)
                        .font(theme.fonts.body2)
                        .foregroundColor(theme.colors.gray900)
                }
            }
            .padding(.horizontal, 20)

            if let image = content.image {
                AsyncCachedImage(
                    url: image.url, cache: .content,
                    placeholder: {
                        theme.colors.gray200
                            .aspectRatio(
                                max(image.size.width/image.size.height, minAspectRatio),
                                contentMode: .fit)
                            .clipped()
                    },
                    content: { imageToDisplay in
                        imageToDisplay
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(maxHeight: width / minAspectRatio)
                            .clipped()
                            .allowsHitTesting(false) // weird bug on iOS 17 where it prevents opening the menu (...)
                    })
            }

            AggregatedInfoView(aggregatedInfo: liveMeasures.aggregatedInfo, userInteractions: liveMeasures.userInteractions,
                               childrenTapped: childrenTapped, likeTapped: likeTapped)
                .padding(.horizontal, 20)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .multilineTextAlignment(.leading)
        .onReceive(content.liveMeasures) {
            liveMeasures = $0
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

                Text("Post.List.ModeratedPost.Reason", bundle: .module).font(theme.fonts.caption1) + reasons.textView
                    .font(theme.fonts.caption1)
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
